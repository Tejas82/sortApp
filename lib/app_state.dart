import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/email_parsing.dart';
import 'core/extraction.dart';
import 'core/urgency.dart';
import 'models/action_item.dart';
import 'models/settings.dart';
import 'services/google_service.dart';
import 'services/llm_service.dart';
import 'services/storage_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    StorageService? storage,
    GoogleService? google,
    LlmService? llm,
  })  : storage = storage ?? StorageService(),
        google = google ?? GoogleService(),
        llm = llm ?? LlmService();

  final StorageService storage;
  final GoogleService google;
  final LlmService llm;

  static const _buildTimeKey = String.fromEnvironment('OPENAI_API_KEY');

  AppSettings settings = AppSettings();
  final List<ActionItem> _actions = [];
  Set<String> _processed = {};

  bool ready = false;
  bool syncing = false;
  int syncDone = 0;
  int syncTotal = 0;
  String? lastError;
  DateTime? lastSync;

  GoogleSignInAccount? get account => google.account;
  bool get gmailConnected => google.isSignedIn;
  String get apiKey =>
      settings.openAiKey.isNotEmpty ? settings.openAiKey : _buildTimeKey;
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  List<ActionItem> activeActions([DateTime? now]) {
    final t = now ?? DateTime.now();
    return sortByUrgency(_actions.where((a) => a.isActive(t)), t);
  }

  List<ActionItem> get doneActions => _actions
      .where((a) => a.status == ActionStatus.done)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> init() async {
    await storage.init();
    settings = storage.loadSettings();
    _actions
      ..clear()
      ..addAll(storage.loadActions());
    _processed = storage.loadProcessedIds();
    await google.signInSilently();
    ready = true;
    notifyListeners();
  }

  // ---- Settings -----------------------------------------------------------

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    await storage.saveSettings(settings);
    notifyListeners();
  }

  Future<void> completeOnboarding() =>
      updateSettings((s) => s.onboarded = true);

  // ---- Google -------------------------------------------------------------

  Future<bool> connectGmail() async {
    lastError = null;
    try {
      final acc = await google.signIn();
      notifyListeners();
      return acc != null;
    } catch (e) {
      lastError = 'Google sign-in failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectGmail() async {
    await google.signOut();
    notifyListeners();
  }

  /// Reads new school and club emails and extracts actions from each.
  /// Returns the number of new actions.
  Future<int> sync() async {
    if (syncing) return 0;
    if (!gmailConnected) {
      lastError = 'Connect Gmail to read school and club emails.';
      notifyListeners();
      return 0;
    }
    if (!hasApiKey) {
      lastError = 'Add your OpenAI API key in Settings first.';
      notifyListeners();
      return 0;
    }

    syncing = true;
    lastError = null;
    syncDone = 0;
    syncTotal = 0;
    notifyListeners();

    var added = 0;
    try {
      final query = buildGmailQuery(
          senders: settings.senders, days: settings.lookbackDays);
      final ids = await google.listMessageIds(query);
      final fresh = ids.where((id) => !_processed.contains(id)).toList();
      syncTotal = fresh.length;
      notifyListeners();

      for (final id in fresh) {
        try {
          final email = await google.getMessage(id);
          final extracted = await llm.extract(
            apiKey: apiKey,
            model: settings.model,
            subject: email.subject,
            from: email.from,
            body: email.body,
            sentDate: email.date,
            children: settings.children,
          );
          added += _addExtracted(
            extracted,
            messageId: email.id,
            threadId: email.threadId,
            subject: email.subject,
            from: email.from,
            messageIdHeader: email.messageIdHeader,
          );
          _processed.add(id);
        } on LlmException catch (e) {
          // A bad key or quota error will fail every message; stop early.
          lastError = e.message;
          break;
        } catch (e) {
          debugPrint('Skipping message $id: $e');
          _processed.add(id);
        }
        syncDone++;
        notifyListeners();
      }
      lastSync = DateTime.now();
    } catch (e) {
      lastError = 'Sync failed: $e';
    } finally {
      await storage.saveActions(_actions);
      await storage.saveProcessedIds(_processed);
      syncing = false;
      notifyListeners();
    }
    return added;
  }

  /// Zero-trust trial: extract actions from text the parent pasted.
  Future<int> extractFromPaste(String text, {String subject = 'Pasted message'}) async {
    lastError = null;
    final extracted = await llm.extract(
      apiKey: apiKey,
      model: settings.model,
      subject: subject,
      from: 'Pasted by you',
      body: text,
      children: settings.children,
    );
    final added = _addExtracted(
      extracted,
      messageId: 'paste-${DateTime.now().millisecondsSinceEpoch}',
      subject: subject,
      from: '',
    );
    await storage.saveActions(_actions);
    notifyListeners();
    return added;
  }

  int _addExtracted(
    List<ExtractedAction> extracted, {
    required String messageId,
    required String subject,
    required String from,
    String? threadId,
    String? messageIdHeader,
  }) {
    var added = 0;
    for (var i = 0; i < extracted.length; i++) {
      final x = extracted[i];
      if (_isDuplicate(x)) continue;
      _actions.add(ActionItem(
        id: '$messageId-$i',
        messageId: messageId,
        threadId: threadId,
        type: x.type,
        title: x.title,
        summary: x.summary,
        child: x.child,
        start: x.start,
        end: x.end,
        allDay: x.allDay,
        deadline: x.deadline,
        location: x.location,
        suggestedReply: x.suggestedReply,
        confidence: x.confidence,
        sourceSubject: subject,
        sourceFrom: from,
        sourceMessageIdHeader: messageIdHeader,
      ));
      added++;
    }
    return added;
  }

  /// Same event from several emails (reminder after reminder): same title,
  /// child and key date already in the feed.
  bool _isDuplicate(ExtractedAction x) {
    final key = x.deadline ?? x.start;
    String day(DateTime? d) => d == null ? '' : '${d.year}-${d.month}-${d.day}';
    return _actions.any((a) =>
        a.title.toLowerCase() == x.title.toLowerCase() &&
        a.child == x.child &&
        day(a.keyDate) == day(key));
  }

  // ---- Actions ------------------------------------------------------------

  void _replace(ActionItem updated) {
    final i = _actions.indexWhere((a) => a.id == updated.id);
    if (i >= 0) _actions[i] = updated;
  }

  /// Notifies first so the UI updates in the same frame (a swiped-away
  /// card must leave the list immediately), then saves.
  Future<void> _persist() async {
    notifyListeners();
    await storage.saveActions(_actions);
  }

  /// Adds the (possibly edited) action to Google Calendar.
  Future<void> addToCalendar(ActionItem edited) async {
    _replace(edited);
    await google.addToCalendar(edited);
    edited.addedToCalendar = true;
    if (edited.type == ActionType.event || edited.type == ActionType.deadline) {
      edited.status = ActionStatus.done;
    }
    await _persist();
  }

  Future<void> saveReplyDraft(ActionItem item, String text) async {
    await google.createReplyDraft(item, text);
    item.draftSaved = true;
    if (item.type == ActionType.reply) item.status = ActionStatus.done;
    await _persist();
  }

  Future<void> markDone(ActionItem item) async {
    item.status = ActionStatus.done;
    await _persist();
  }

  Future<void> reopen(ActionItem item) async {
    item.status = ActionStatus.open;
    item.snoozedUntil = null;
    await _persist();
  }

  Future<void> dismiss(ActionItem item, {bool wrong = false}) async {
    item.status = ActionStatus.dismissed;
    item.markedWrong = wrong;
    await _persist();
  }

  Future<void> snooze(ActionItem item, Duration d) async {
    item.status = ActionStatus.snoozed;
    item.snoozedUntil = DateTime.now().add(d);
    await _persist();
  }

  /// Wipes actions, history and settings from this device.
  Future<void> deleteAllData() async {
    await google.signOut();
    await storage.clearAll();
    _actions.clear();
    _processed = {};
    settings = AppSettings();
    notifyListeners();
  }
}
