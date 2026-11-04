import 'dart:convert';

/// A minimal MIME tree, decoupled from the googleapis types so the parsing
/// logic can be unit tested.
class EmailPart {
  const EmailPart({
    this.mimeType = '',
    this.data,
    this.parts = const [],
  });

  final String mimeType;

  /// Base64url-encoded body data, as returned by the Gmail API.
  final String? data;
  final List<EmailPart> parts;
}

/// Keywords used when the parent hasn't listed any school or club senders.
const autoDetectKeywords = <String>[
  'school',
  'nursery',
  'academy',
  'PTA',
  'PTFA',
  'club',
  'term',
  'trip',
  '"parents evening"',
  '"non-uniform"',
  'kit',
  'fixture',
  'training',
  'homework',
  'consent',
];

/// Gmail search query for messages worth reading.
String buildGmailQuery({required List<String> senders, required int days}) {
  final base = 'newer_than:${days}d -category:promotions -category:social';
  final cleaned = senders.map((s) => s.trim()).where((s) => s.isNotEmpty);
  if (cleaned.isEmpty) {
    return '$base {${autoDetectKeywords.join(' ')}}';
  }
  return '$base {${cleaned.map((s) => 'from:$s').join(' ')}}';
}

String decodeBase64Url(String data) {
  var normalized = data.replaceAll('-', '+').replaceAll('_', '/');
  normalized = normalized.replaceAll(RegExp(r'\s'), '');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return utf8.decode(base64.decode(normalized), allowMalformed: true);
}

/// Picks the most readable text from a message: text/plain if present,
/// otherwise text/html with tags stripped.
String extractBodyText(EmailPart root) {
  final plain = _findFirst(root, 'text/plain');
  if (plain != null && plain.data != null) {
    return normalizeWhitespace(decodeBase64Url(plain.data!));
  }
  final html = _findFirst(root, 'text/html');
  if (html != null && html.data != null) {
    return htmlToText(decodeBase64Url(html.data!));
  }
  if (root.data != null) {
    final text = decodeBase64Url(root.data!);
    return root.mimeType.contains('html')
        ? htmlToText(text)
        : normalizeWhitespace(text);
  }
  return '';
}

EmailPart? _findFirst(EmailPart part, String mime) {
  if (part.mimeType.toLowerCase() == mime && part.data != null) return part;
  for (final child in part.parts) {
    final found = _findFirst(child, mime);
    if (found != null) return found;
  }
  return null;
}

String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(
      RegExp(r'<(style|script)[^>]*>.*?</\1>',
          caseSensitive: false, dotAll: true),
      ' ');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(
      RegExp(r'</(p|div|li|tr|h[1-6])>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&pound;': '£',
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  return normalizeWhitespace(s);
}

String normalizeWhitespace(String s) {
  final lines = s
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .toList();
  final out = <String>[];
  for (final l in lines) {
    if (l.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(l);
  }
  return out.join('\n').trim();
}

String truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// Encodes a header value as RFC 2047 when it isn't plain ASCII.
String encodeHeader(String value) {
  final ascii = value.codeUnits.every((c) => c < 128);
  if (ascii) return value;
  return '=?UTF-8?B?${base64.encode(utf8.encode(value))}?=';
}

/// Builds a base64url `raw` reply message for the Gmail drafts API.
String buildReplyRaw({
  required String to,
  required String subject,
  required String body,
  String? inReplyTo,
}) {
  final subj = subject.trim().toLowerCase().startsWith('re:')
      ? subject.trim()
      : 'Re: ${subject.trim()}';
  final headers = <String>[
    'To: $to',
    'Subject: ${encodeHeader(subj)}',
    if (inReplyTo != null && inReplyTo.isNotEmpty) 'In-Reply-To: $inReplyTo',
    if (inReplyTo != null && inReplyTo.isNotEmpty) 'References: $inReplyTo',
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset="UTF-8"',
    'Content-Transfer-Encoding: base64',
  ];
  final raw = '${headers.join('\r\n')}\r\n\r\n${base64.encode(utf8.encode(body))}';
  return base64Url.encode(utf8.encode(raw));
}
