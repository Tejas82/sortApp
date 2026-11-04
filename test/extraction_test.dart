import 'package:flutter_test/flutter_test.dart';
import 'package:sortapp/core/extraction.dart';
import 'package:sortapp/models/action_item.dart';

void main() {
  group('parseExtraction', () {
    test('parses a typical school message reply', () {
      const raw = '''
{"actions": [
  {"type": "event", "title": "Year 3 museum trip", "summary": "Packed lunch needed",
   "child": "mira", "start": "2026-11-21T09:00", "end": "2026-11-21T15:00",
   "deadline": null, "location": "Science Museum", "suggested_reply": null, "confidence": 0.9},
  {"type": "payment", "title": "Pay £12 trip fee", "child": "Mira",
   "start": null, "deadline": "2026-11-17", "confidence": 0.8}
]}''';
      final out = parseExtraction(raw, children: ['Mira', 'Aarav']);
      expect(out, hasLength(2));

      final trip = out[0];
      expect(trip.type, ActionType.event);
      expect(trip.child, 'Mira'); // normalised to the known name
      expect(trip.start, DateTime(2026, 11, 21, 9));
      expect(trip.end, DateTime(2026, 11, 21, 15));
      expect(trip.allDay, isFalse);
      expect(trip.location, 'Science Museum');

      final fee = out[1];
      expect(fee.type, ActionType.payment);
      expect(fee.start, isNull);
      expect(fee.deadline, DateTime(2026, 11, 17));
      expect(fee.allDay, isTrue);
    });

    test('date-only start is all-day', () {
      final out = parseExtraction(
          '{"actions":[{"type":"event","title":"Non-uniform day","start":"2026-12-05"}]}');
      expect(out.single.allDay, isTrue);
      expect(out.single.start, DateTime(2026, 12, 5));
    });

    test('strips markdown fences and tolerates junk entries', () {
      const raw = '```json\n{"actions":[{"title":""},"oops",{"type":"weird","title":"Bring PE kit"}]}\n```';
      final out = parseExtraction(raw);
      expect(out, hasLength(1));
      expect(out.single.title, 'Bring PE kit');
      expect(out.single.type, ActionType.prep); // unknown types fall back to prep
    });

    test('unknown child is dropped when children are known', () {
      final out = parseExtraction(
          '{"actions":[{"type":"event","title":"Match","child":"Sam"}]}',
          children: ['Mira']);
      expect(out.single.child, isNull);
    });

    test('clamps confidence and drops an end before the start', () {
      final out = parseExtraction(
          '{"actions":[{"type":"event","title":"Disco","start":"2026-11-28T18:00",'
          '"end":"2026-11-28T17:00","confidence":3}]}');
      expect(out.single.confidence, 1.0);
      expect(out.single.end, isNull);
    });

    test('invalid JSON returns no actions', () {
      expect(parseExtraction('not json'), isEmpty);
      expect(parseExtraction('{"actions": "nope"}'), isEmpty);
    });
  });

  test('system prompt states today and the children', () {
    final p = buildSystemPrompt(today: DateTime(2026, 11, 4), children: ['Mira', 'Aarav']);
    expect(p, contains('Wednesday 2026-11-04'));
    expect(p, contains('Mira, Aarav'));
  });
}
