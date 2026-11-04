import '../models/action_item.dart';
import 'format.dart';

enum UrgencyBucket { overdue, today, thisWeek, later, noDate }

String bucketLabel(UrgencyBucket b) {
  switch (b) {
    case UrgencyBucket.overdue:
      return 'Overdue';
    case UrgencyBucket.today:
      return 'Today';
    case UrgencyBucket.thisWeek:
      return 'Next 7 days';
    case UrgencyBucket.later:
      return 'Later';
    case UrgencyBucket.noDate:
      return 'No date';
  }
}

/// Whole days from today to [d]; negative = in the past.
int daysUntil(DateTime d, DateTime now) =>
    dateOnly(d).difference(dateOnly(now)).inDays;

UrgencyBucket bucketFor(ActionItem item, DateTime now) {
  final key = item.keyDate;
  if (key == null) return UrgencyBucket.noDate;
  final days = daysUntil(key, now);
  // An event that already happened isn't "overdue"; a missed deadline is.
  if (days < 0) {
    return item.deadline != null ? UrgencyBucket.overdue : UrgencyBucket.later;
  }
  if (days == 0) return UrgencyBucket.today;
  if (days <= 7) return UrgencyBucket.thisWeek;
  return UrgencyBucket.later;
}

/// Sorts most urgent first: overdue, today, next 7 days, later, then undated
/// (replies and payments before other undated items).
List<ActionItem> sortByUrgency(Iterable<ActionItem> items, DateTime now) {
  int rank(ActionItem i) => bucketFor(i, now).index;
  int undatedRank(ActionItem i) =>
      i.type == ActionType.reply || i.type == ActionType.payment ? 0 : 1;
  final list = items.toList();
  list.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final ka = a.keyDate, kb = b.keyDate;
    if (ka != null && kb != null) return ka.compareTo(kb);
    final u = undatedRank(a).compareTo(undatedRank(b));
    if (u != 0) return u;
    return b.createdAt.compareTo(a.createdAt);
  });
  return list;
}
