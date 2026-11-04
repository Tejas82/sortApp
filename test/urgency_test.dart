import 'package:flutter_test/flutter_test.dart';
import 'package:sortapp/core/urgency.dart';
import 'package:sortapp/models/action_item.dart';
import 'package:sortapp/services/google_service.dart';

ActionItem item(String id,
        {ActionType type = ActionType.event, DateTime? start, DateTime? deadline, bool allDay = false}) =>
    ActionItem(id: id, messageId: 'm', type: type, title: id, start: start, deadline: deadline, allDay: allDay);

void main() {
  final now = DateTime(2026, 11, 4, 21);

  test('buckets by key date', () {
    expect(bucketFor(item('a', deadline: DateTime(2026, 11, 3)), now), UrgencyBucket.overdue);
    expect(bucketFor(item('b', start: DateTime(2026, 11, 3)), now), UrgencyBucket.later);
    expect(bucketFor(item('c', start: DateTime(2026, 11, 4, 23)), now), UrgencyBucket.today);
    expect(bucketFor(item('d', start: DateTime(2026, 11, 11)), now), UrgencyBucket.thisWeek);
    expect(bucketFor(item('e', start: DateTime(2026, 11, 20)), now), UrgencyBucket.later);
    expect(bucketFor(item('f'), now), UrgencyBucket.noDate);
  });

  test('sorts overdue first, then by date, then undated replies', () {
    final list = sortByUrgency([
      item('undated-prep', type: ActionType.prep),
      item('later', start: DateTime(2026, 11, 30)),
      item('undated-reply', type: ActionType.reply),
      item('soon', start: DateTime(2026, 11, 6)),
      item('overdue', deadline: DateTime(2026, 11, 1)),
      item('today', deadline: DateTime(2026, 11, 4)),
    ], now);
    expect(list.map((e) => e.id).toList(),
        ['overdue', 'today', 'soon', 'later', 'undated-reply', 'undated-prep']);
  });

  test('snoozed items come back after the snooze ends', () {
    final i = item('x')
      ..status = ActionStatus.snoozed
      ..snoozedUntil = DateTime(2026, 11, 5);
    expect(i.isActive(now), isFalse);
    expect(i.isActive(DateTime(2026, 11, 5, 1)), isTrue);
  });

  test('action JSON round-trips', () {
    final i = item('rt', start: DateTime(2026, 11, 21, 9), deadline: DateTime(2026, 11, 17))
      ..status = ActionStatus.snoozed;
    final back = ActionItem.fromJson(i.toJson());
    expect(back.start, i.start);
    expect(back.deadline, i.deadline);
    expect(back.status, ActionStatus.snoozed);
  });

  group('calendar event', () {
    test('deadline-only becomes an all-day Due: event with exclusive end', () {
      final e = buildCalendarEvent(item('Return form', type: ActionType.deadline, deadline: DateTime(2026, 11, 17)));
      expect(e.summary, 'Due: Return form');
      expect(e.start!.date, DateTime(2026, 11, 17));
      expect(e.end!.date, DateTime(2026, 11, 18));
    });

    test('timed event defaults to one hour with two reminders', () {
      final e = buildCalendarEvent(item('Disco', start: DateTime(2026, 11, 28, 18)));
      expect(e.start!.dateTime, DateTime(2026, 11, 28, 18));
      expect(e.end!.dateTime, DateTime(2026, 11, 28, 19));
      expect(e.reminders!.overrides, hasLength(2));
    });
  });
}
