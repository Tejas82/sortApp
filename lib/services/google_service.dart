import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;

import '../core/email_parsing.dart';
import '../models/action_item.dart';

class FetchedEmail {
  FetchedEmail({
    required this.id,
    required this.threadId,
    required this.subject,
    required this.from,
    required this.body,
    this.date,
    this.messageIdHeader,
  });

  final String id;
  final String? threadId;
  final String subject;
  final String from;
  final String body;
  final String? date;
  final String? messageIdHeader;
}

class GoogleException implements Exception {
  GoogleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Gmail in, Google Calendar out.
///
/// Scopes are requested incrementally: Gmail at sign-in, Calendar only the
/// first time the parent adds an event (activation step 5 in the PRD).
class GoogleService {
  static const gmailReadonly = 'https://www.googleapis.com/auth/gmail.readonly';
  static const gmailCompose = 'https://www.googleapis.com/auth/gmail.compose';
  static const calendarEvents = 'https://www.googleapis.com/auth/calendar.events';

  final GoogleSignIn _signIn = GoogleSignIn(scopes: [gmailReadonly]);

  GoogleSignInAccount? get account => _signIn.currentUser;
  bool get isSignedIn => _signIn.currentUser != null;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _signIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() => _signIn.signIn();

  Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      await _signIn.signOut();
    }
  }

  Future<bool> _ensureScope(String scope) async {
    if (!isSignedIn) throw GoogleException('Connect your Google account first.');
    return _signIn.requestScopes([scope]);
  }

  Future<AuthClient> _client() async {
    final client = await _signIn.authenticatedClient();
    if (client == null) throw GoogleException('Google sign-in expired. Reconnect in Settings.');
    return client;
  }

  /// Message ids matching [query], newest first.
  Future<List<String>> listMessageIds(String query, {int max = 40}) async {
    final api = gmail.GmailApi(await _client());
    final res = await api.users.messages.list('me', q: query, maxResults: max);
    return (res.messages ?? []).map((m) => m.id).whereType<String>().toList();
  }

  Future<FetchedEmail> getMessage(String id) async {
    final api = gmail.GmailApi(await _client());
    final msg = await api.users.messages.get('me', id, format: 'full');
    final headers = msg.payload?.headers ?? const <gmail.MessagePartHeader>[];
    String? header(String name) {
      for (final h in headers) {
        if ((h.name ?? '').toLowerCase() == name.toLowerCase()) return h.value;
      }
      return null;
    }

    final body = msg.payload == null ? '' : extractBodyText(_toPart(msg.payload!));
    return FetchedEmail(
      id: id,
      threadId: msg.threadId,
      subject: header('Subject') ?? '(no subject)',
      from: header('From') ?? '',
      date: header('Date'),
      messageIdHeader: header('Message-ID') ?? header('Message-Id'),
      body: body.isEmpty ? (msg.snippet ?? '') : body,
    );
  }

  EmailPart _toPart(gmail.MessagePart p) => EmailPart(
        mimeType: p.mimeType ?? '',
        data: p.body?.data,
        parts: (p.parts ?? const <gmail.MessagePart>[]).map(_toPart).toList(),
      );

  /// Saves a reply as a Gmail draft in the original thread. Nothing is sent:
  /// the parent reviews and sends it from Gmail.
  Future<void> createReplyDraft(ActionItem item, String text) async {
    if (!await _ensureScope(gmailCompose)) {
      throw GoogleException('Permission to create Gmail drafts was not granted.');
    }
    final api = gmail.GmailApi(await _client());
    final raw = buildReplyRaw(
      to: item.sourceFrom,
      subject: item.sourceSubject,
      body: text,
      inReplyTo: item.sourceMessageIdHeader,
    );
    await api.users.drafts.create(
      gmail.Draft(message: gmail.Message(raw: raw, threadId: item.threadId)),
      'me',
    );
  }

  /// Adds the action to the primary calendar with a popup reminder the day
  /// before. Returns the event's web link.
  Future<String?> addToCalendar(ActionItem item) async {
    if (!await _ensureScope(calendarEvents)) {
      throw GoogleException('Permission to add calendar events was not granted.');
    }
    final api = cal.CalendarApi(await _client());
    final event = buildCalendarEvent(item);
    final created = await api.events.insert(event, 'primary');
    return created.htmlLink;
  }
}

/// Maps an action to a Calendar event. Deadlines become all-day "Due:"
/// events; events keep their times when known.
cal.Event buildCalendarEvent(ActionItem item) {
  final isDeadlineOnly = item.start == null && item.deadline != null;
  final when = item.start ?? item.deadline!;
  final allDay = isDeadlineOnly || item.allDay;

  final cal.EventDateTime start;
  final cal.EventDateTime end;
  if (allDay) {
    final day = DateTime(when.year, when.month, when.day);
    final endDay = item.end != null && !isDeadlineOnly
        ? DateTime(item.end!.year, item.end!.month, item.end!.day)
        : day;
    start = cal.EventDateTime(date: day);
    // Calendar's all-day end date is exclusive.
    end = cal.EventDateTime(date: endDay.add(const Duration(days: 1)));
  } else {
    start = cal.EventDateTime(dateTime: when);
    end = cal.EventDateTime(
        dateTime: item.end ?? when.add(const Duration(hours: 1)));
  }

  final prefix = isDeadlineOnly ? 'Due: ' : '';
  final childTag = item.child != null ? ' (${item.child})' : '';
  final description = [
    if (item.summary.isNotEmpty) item.summary,
    if (item.sourceSubject.isNotEmpty) 'From: ${item.sourceSubject}',
    'Added by Sortapp',
  ].join('\n\n');

  return cal.Event(
    summary: '$prefix${item.title}$childTag',
    description: description,
    location: item.location,
    start: start,
    end: end,
    reminders: cal.EventReminders(
      useDefault: false,
      overrides: [
        cal.EventReminder(method: 'popup', minutes: 24 * 60),
        if (!allDay) cal.EventReminder(method: 'popup', minutes: 60),
      ],
    ),
  );
}
