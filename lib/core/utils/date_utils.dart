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
}
