import 'package:intl/intl.dart';

import '../../agenda/data/agenda_event.dart';
import '../../notifications/data/notifications.dart';

/// A reminder to show at [at].
class PlannedReminder {
  const PlannedReminder(this.notification, this.at);

  final AppNotification notification;
  final DateTime at;
}

/// Decides when to remind about each agenda item:
///
/// - Interview: the evening before (7 PM) and 1 hour before.
/// - Deadline: the morning before (9 AM) and the morning of.
/// - Follow-up and other: at the time set.
///
/// Times already past are skipped, as are done items.
abstract final class ReminderPlanner {
  static const eveningBefore = 19;
  static const morning = 9;

  static List<PlannedReminder> plan(
    Iterable<AgendaEvent> events, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final reminders = <PlannedReminder>[];

    for (final event in events) {
      if (event.isDone || !event.startsAt.isAfter(current)) continue;

      final time = DateFormat.jm().format(event.startsAt);
      final at = event.company == null ? '' : ' · ${event.company}';
      final payload = event.applicationId == null
          ? const OpenAgendaRoute().payload
          : OpenApplicationRoute(event.applicationId!).payload;

      void add(String slot, DateTime when, String title, String body) {
        if (!when.isAfter(current)) return;
        reminders.add(
          PlannedReminder(
            AppNotification(
              id: stableNotificationId('reminder:${event.id}:$slot'),
              channel: NotificationChannel.reminders,
              title: title,
              body: body,
              payload: payload,
            ),
            when,
          ),
        );
      }

      final day = DateTime(
        event.startsAt.year,
        event.startsAt.month,
        event.startsAt.day,
      );
      switch (event.kind) {
        case AgendaEventKind.interview:
          final evening = day
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: eveningBefore));
          add(
            'eve',
            evening,
            'Interview tomorrow at $time',
            '${event.title}$at. Open Careerly to run through your interview '
                'prep.',
          );
          add(
            'hour',
            event.startsAt.subtract(const Duration(hours: 1)),
            'Interview in 1 hour',
            '${event.title}$at at $time. You\'ve got this.',
          );
        case AgendaEventKind.deadline:
          add(
            'before',
            day
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: morning)),
            'Due tomorrow',
            '${event.title}$at',
          );
          final morningOf = day.add(const Duration(hours: morning));
          add(
            'day',
            morningOf.isBefore(event.startsAt) ? morningOf : event.startsAt,
            'Due today at $time',
            '${event.title}$at',
          );
        case AgendaEventKind.followUp:
          add(
            'at',
            event.startsAt,
            'Time to follow up',
            '${event.title}$at',
          );
        case AgendaEventKind.other:
          add('at', event.startsAt, event.title, 'Reminder$at at $time');
      }
    }
    return reminders;
  }
}
