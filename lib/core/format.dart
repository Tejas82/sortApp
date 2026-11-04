const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Fri 20 Nov" or "Fri 20 Nov, 09:00".
String formatWhen(DateTime d, {bool allDay = false}) {
  final day = '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  if (allDay) return day;
  return '$day, ${_two(d.hour)}:${_two(d.minute)}';
}

/// Sender's display name from a `From` header: `"Jane" <a@b.com>` → Jane.
String senderName(String from) {
  final match = RegExp(r'^\s*"?([^"<]+?)"?\s*<').firstMatch(from);
  if (match != null) return match.group(1)!.trim();
  return from.trim();
}
