import 'dart:convert';

import '../models/action_item.dart';
import 'format.dart';

/// What the model returns for one action, before it becomes an [ActionItem].
class ExtractedAction {
  ExtractedAction({
    required this.type,
    required this.title,
    this.summary = '',
    this.child,
    this.start,
    this.end,
    this.allDay = false,
    this.deadline,
    this.location,
    this.suggestedReply,
    this.confidence = 0.5,
  });

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
  final double confidence;
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

String buildSystemPrompt({required DateTime today, required List<String> children}) {
  final date = isoDate(today);
  final weekday = _weekdays[today.weekday - 1];
  final kids = children.isEmpty ? 'unknown' : children.join(', ');
  return '''
You help a busy parent stay on top of messages from schools, nurseries and children's clubs.
Today is $weekday $date. The parent's children: $kids.

From the message, extract only things the parent must attend, do, decide, pay, reply to or prepare for.
Ignore newsletters, general news and marketing unless they contain such an action.

Return a JSON object: {"actions": [ ... ]}. Each action has:
- "type": one of "event", "deadline", "reply", "payment", "prep"
- "title": short and specific, max 60 characters (e.g. "Year 3 museum trip", "Return consent form")
- "summary": one sentence, max 160 characters, with any key details (cost, what to bring)
- "child": a name from the children list if the message is clearly about that child, else null
- "start": "YYYY-MM-DDTHH:MM" local time, or "YYYY-MM-DD" if there is no time, or null
- "end": same format or null
- "deadline": same format or null (when something must be done by)
- "location": string or null
- "suggested_reply": a short, polite reply the parent could send if a response is requested, else null
- "confidence": 0 to 1, how sure you are that the dates and details are correct

Resolve relative dates ("next Friday", "tomorrow") against today. Never invent a date that is not stated or clearly implied.
If there is nothing actionable, return {"actions": []}.''';
}

String buildUserPrompt({
  required String subject,
  required String from,
  required String body,
  String? sentDate,
}) {
  return 'From: $from\n'
      '${sentDate != null ? 'Sent: $sentDate\n' : ''}'
      'Subject: $subject\n\n'
      '$body';
}

/// Parses "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM[:SS]" into a local DateTime.
/// Returns the date and whether it was date-only.
(DateTime?, bool) parseLooseDate(Object? value) {
  if (value is! String) return (null, false);
  final s = value.trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return (null, false);
  final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return (null, false);
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return (local, dateOnly);
}

String? _str(Object? v, {int? max}) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return null;
  if (max != null && t.length > max) return t.substring(0, max);
  return t;
}

String _stripFences(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    s = s.replaceFirst(RegExp(r'```\s*$'), '');
  }
  return s.trim();
}

/// Turns the model's JSON reply into validated actions. Bad entries are
/// skipped rather than failing the whole message.
List<ExtractedAction> parseExtraction(String raw, {List<String> children = const []}) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(_stripFences(raw));
  } on FormatException {
    return [];
  }
  final list = decoded is Map ? decoded['actions'] : decoded;
  if (list is! List) return [];

  final known = {for (final c in children) c.toLowerCase(): c};
  final out = <ExtractedAction>[];
  for (final entry in list) {
    if (entry is! Map) continue;
    final title = _str(entry['title'], max: 80);
    if (title == null) continue;

    final (start, startDateOnly) = parseLooseDate(entry['start']);
    final (end, _) = parseLooseDate(entry['end']);
    final (deadline, _) = parseLooseDate(entry['deadline']);

    final rawChild = _str(entry['child']);
    final child = rawChild == null
        ? null
        : (known[rawChild.toLowerCase()] ?? (children.isEmpty ? rawChild : null));

    final conf = entry['confidence'];
    final confidence = conf is num ? conf.toDouble().clamp(0.0, 1.0).toDouble() : 0.5;

    out.add(ExtractedAction(
      type: actionTypeFromString(entry['type'] as String?),
      title: title,
      summary: _str(entry['summary'], max: 240) ?? '',
      child: child,
      start: start,
      end: end != null && start != null && end.isBefore(start) ? null : end,
      allDay: start == null || startDateOnly,
      deadline: deadline,
      location: _str(entry['location'], max: 160),
      suggestedReply: _str(entry['suggested_reply'], max: 1000),
      confidence: confidence,
    ));
  }
  return out;
}
