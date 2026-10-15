import 'package:intl/intl.dart';

extension CareerlyDateUtils on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  /// Monday of this date's week.
  DateTime get startOfWeek => dateOnly.subtract(Duration(days: weekday - 1));

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// `yyyy-MM-dd`, for Postgres `date` columns.
  String toDateString() => DateFormat('yyyy-MM-dd').format(this);

  /// "Today", "Tomorrow", or e.g. "Thu, Oct 16".
  String relativeDayLabel([DateTime? now]) {
    final today = (now ?? DateTime.now()).dateOnly;
    final difference = dateOnly.difference(today).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(this);
  }

  /// e.g. "2:30 PM".
  String get timeLabel => DateFormat.jm().format(this);

  /// Short past-time label such as "30 min ago", "5 hr ago" or "3 days ago".
  String agoLabel([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final elapsed = reference.difference(this);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
    final days = reference.dateOnly.difference(dateOnly).inDays;
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    return DateFormat('MMM d, y').format(this);
  }

  /// Short countdown such as "in 45 min", "in 5 hr" or "in 3 days".
  String countdownLabel([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final remaining = difference(reference);
    if (remaining.isNegative) return 'Now';
    if (remaining.inMinutes < 60) return 'in ${remaining.inMinutes} min';
    if (remaining.inHours < 24) return 'in ${remaining.inHours} hr';
    final days = dateOnly.difference(reference.dateOnly).inDays;
    return days == 1 ? 'Tomorrow' : 'in $days days';
  }
}
