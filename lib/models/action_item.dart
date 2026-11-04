/// One thing a parent needs to do, attend, decide, pay or prepare for,
/// extracted from a single message.
enum ActionType { event, deadline, reply, payment, prep }

enum ActionStatus { open, done, dismissed, snoozed }

ActionType actionTypeFromString(String? value) {
  switch ((value ?? '').toLowerCase().trim()) {
    case 'event':
      return ActionType.event;
    case 'deadline':
      return ActionType.deadline;
    case 'reply':
      return ActionType.reply;
    case 'payment':
      return ActionType.payment;
    default:
      return ActionType.prep;
  }
}

ActionStatus _statusFromString(String? value) {
  for (final s in ActionStatus.values) {
    if (s.name == value) return s;
  }
  return ActionStatus.open;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

class ActionItem {
  ActionItem({
    required this.id,
    required this.messageId,
    required this.type,
    required this.title,
    this.summary = '',
    this.threadId,
    this.child,
    this.start,
    this.end,
    this.allDay = false,
    this.deadline,
    this.location,
    this.suggestedReply,
    this.confidence = 1.0,
    this.sourceSubject = '',
    this.sourceFrom = '',
    this.sourceMessageIdHeader,
    this.status = ActionStatus.open,
    this.snoozedUntil,
    this.addedToCalendar = false,
    this.draftSaved = false,
    this.markedWrong = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  /// Gmail message id, or `paste-<timestamp>` for pasted text.
  final String messageId;
  final String? threadId;
  final ActionType type;
  final String title;
  final String summary;
  final String? child;
  final DateTime? start;
  final DateTime? end;
  final bool allDay;
  final DateTime? deadline;
  final String? location;
  final String? suggestedReply;

  /// 0–1: how sure the model is that the dates and details are right.
  final double confidence;
  final String sourceSubject;

  /// Raw `From` header of the source email, used as the reply recipient.
  final String sourceFrom;

  /// RFC 2822 `Message-ID` of the source email, for threading replies.
  final String? sourceMessageIdHeader;
  final DateTime createdAt;

  ActionStatus status;
  DateTime? snoozedUntil;
  bool addedToCalendar;
  bool draftSaved;
  bool markedWrong;

  bool get fromGmail => !messageId.startsWith('paste-');

  /// The date that decides how urgent this is.
  DateTime? get keyDate => deadline ?? start;

  bool get needsCheck => confidence < 0.6;

  bool get canAddToCalendar => keyDate != null;

  bool get canReply => fromGmail && sourceFrom.isNotEmpty;

  /// Open, or snoozed until a time that has passed.
  bool isActive(DateTime now) {
    if (status == ActionStatus.open) return true;
    if (status == ActionStatus.snoozed) {
      return snoozedUntil == null || !snoozedUntil!.isAfter(now);
    }
    return false;
  }

  ActionItem copyWith({
    String? title,
    String? summary,
    DateTime? start,
    DateTime? end,
    bool clearEnd = false,
    bool? allDay,
    DateTime? deadline,
    String? location,
    String? child,
  }) {
    return ActionItem(
      id: id,
      messageId: messageId,
      threadId: threadId,
      type: type,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      child: child ?? this.child,
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
      allDay: allDay ?? this.allDay,
      deadline: deadline ?? this.deadline,
      location: location ?? this.location,
      suggestedReply: suggestedReply,
      confidence: confidence,
      sourceSubject: sourceSubject,
      sourceFrom: sourceFrom,
      sourceMessageIdHeader: sourceMessageIdHeader,
      status: status,
      snoozedUntil: snoozedUntil,
      addedToCalendar: addedToCalendar,
      draftSaved: draftSaved,
      markedWrong: markedWrong,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'messageId': messageId,
        'threadId': threadId,
        'type': type.name,
        'title': title,
        'summary': summary,
        'child': child,
        'start': start?.toIso8601String(),
        'end': end?.toIso8601String(),
        'allDay': allDay,
        'deadline': deadline?.toIso8601String(),
        'location': location,
        'suggestedReply': suggestedReply,
        'confidence': confidence,
        'sourceSubject': sourceSubject,
        'sourceFrom': sourceFrom,
        'sourceMessageIdHeader': sourceMessageIdHeader,
        'status': status.name,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'addedToCalendar': addedToCalendar,
        'draftSaved': draftSaved,
        'markedWrong': markedWrong,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        id: j['id'] as String,
        messageId: j['messageId'] as String,
        threadId: j['threadId'] as String?,
        type: actionTypeFromString(j['type'] as String?),
        title: (j['title'] as String?) ?? '',
        summary: (j['summary'] as String?) ?? '',
        child: j['child'] as String?,
        start: _date(j['start']),
        end: _date(j['end']),
        allDay: (j['allDay'] as bool?) ?? false,
        deadline: _date(j['deadline']),
        location: j['location'] as String?,
        suggestedReply: j['suggestedReply'] as String?,
        confidence: ((j['confidence'] as num?) ?? 1).toDouble(),
        sourceSubject: (j['sourceSubject'] as String?) ?? '',
        sourceFrom: (j['sourceFrom'] as String?) ?? '',
        sourceMessageIdHeader: j['sourceMessageIdHeader'] as String?,
        status: _statusFromString(j['status'] as String?),
        snoozedUntil: _date(j['snoozedUntil']),
        addedToCalendar: (j['addedToCalendar'] as bool?) ?? false,
        draftSaved: (j['draftSaved'] as bool?) ?? false,
        markedWrong: (j['markedWrong'] as bool?) ?? false,
        createdAt: _date(j['createdAt']),
      );
}
