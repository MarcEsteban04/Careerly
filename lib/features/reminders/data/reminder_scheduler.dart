import 'package:flutter/foundation.dart';

import '../../agenda/data/agenda_event.dart';
import '../../notifications/data/notification_settings.dart';
import '../../notifications/data/notifications.dart';
import 'reminder_planner.dart';

/// Keeps the device's scheduled reminders in step with the agenda.
class ReminderScheduler {
  ReminderScheduler({required this.notifications, required this.settings});

  final Notifications notifications;
  final NotificationSettings settings;

  /// The most recent sync; later syncs wait for it so they never interleave.
  Future<void> _last = Future.value();

  /// Schedules reminders for [events] and cancels ones no longer needed.
  /// Never throws: reminders are a nice-to-have.
  Future<void> sync(List<AgendaEvent> events) =>
      _last = _last.then((_) => _sync(events));

  Future<void> _sync(List<AgendaEvent> events) async {
    try {
      final enabled = await settings.remindersEnabled();
      final planned = enabled ? ReminderPlanner.plan(events) : const [];
      final wanted = {for (final r in planned) r.notification.id};

      // Job alerts are shown right away, never scheduled, so every pending
      // notification is a reminder.
      for (final id in await notifications.scheduledIds()) {
        if (!wanted.contains(id)) await notifications.cancel(id);
      }
      for (final reminder in planned) {
        await notifications.schedule(reminder.notification, reminder.at);
      }
    } catch (e) {
      debugPrint('Reminder sync failed: $e');
    }
  }
}
