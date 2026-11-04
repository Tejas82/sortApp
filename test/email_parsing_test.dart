import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sortapp/core/email_parsing.dart';
import 'package:sortapp/core/format.dart';

String b64url(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

void main() {
  test('prefers text/plain in a multipart message', () {
    final root = EmailPart(mimeType: 'multipart/alternative', parts: [
      EmailPart(mimeType: 'text/plain', data: b64url('Trip on Friday.\r\n\r\n\r\nBring lunch.')),
      EmailPart(mimeType: 'text/html', data: b64url('<p>ignored</p>')),
    ]);
    expect(extractBodyText(root), 'Trip on Friday.\n\nBring lunch.');
  });

  test('falls back to stripped HTML', () {
    final root = EmailPart(mimeType: 'multipart/mixed', parts: [
      EmailPart(mimeType: 'multipart/alternative', parts: [
        EmailPart(
            mimeType: 'text/html',
            data: b64url('<style>p{}</style><p>Cost: &pound;12</p><br>Due&nbsp;Monday')),
      ]),
    ]);
    expect(extractBodyText(root), 'Cost: £12\n\nDue Monday');
  });

  test('decodes unpadded base64url with non-ASCII text', () {
    expect(decodeBase64Url(b64url('Café – £5')), 'Café – £5');
  });

  test('query uses keywords when no senders are set', () {
    final q = buildGmailQuery(senders: [], days: 30);
    expect(q, startsWith('newer_than:30d -category:promotions'));
    expect(q, contains('school'));
  });

  test('query ORs the listed senders', () {
    final q = buildGmailQuery(senders: ['office@school.org.uk', ' club.com '], days: 14);
    expect(q, 'newer_than:14d -category:promotions -category:social '
        '{from:office@school.org.uk from:club.com}');
  });

  test('reply draft has threading headers and a Re: subject', () {
    final raw = buildReplyRaw(
      to: 'Office <office@school.org.uk>',
      subject: 'Trip consent',
      body: 'Yes, Mira can go.',
      inReplyTo: '<abc@mail>',
    );
    final decoded = utf8.decode(base64Url.decode(raw));
    expect(decoded, contains('To: Office <office@school.org.uk>'));
    expect(decoded, contains('Subject: Re: Trip consent'));
    expect(decoded, contains('In-Reply-To: <abc@mail>'));
    final body = decoded.split('\r\n\r\n').last;
    expect(utf8.decode(base64.decode(body)), 'Yes, Mira can go.');
  });

  test('senderName reads the display name', () {
    expect(senderName('"St Mary\'s Office" <office@stmarys.org.uk>'), "St Mary's Office");
    expect(senderName('plain@example.com'), 'plain@example.com');
  });

  test('formatWhen', () {
    final d = DateTime(2026, 11, 20, 9, 5);
    expect(formatWhen(d), 'Fri 20 Nov, 09:05');
    expect(formatWhen(d, allDay: true), 'Fri 20 Nov');
  });
}
