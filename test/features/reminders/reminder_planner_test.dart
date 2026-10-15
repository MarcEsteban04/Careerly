import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/notifications/data/notifications.dart';
import 'package:careerly/features/reminders/data/reminder_planner.dart';

void main() {
  final now = DateTime(2026, 10, 16, 12);

  AgendaEvent event(
    AgendaEventKind kind,
    DateTime startsAt, {
    String id = 'e1',
    bool isDone = false,
    String? applicationId,
  }) =>
      AgendaEvent(
        id: id,
        kind: kind,
        title: 'Final round',
        startsAt: startsAt,
        isDone: isDone,
        applicationId: applicationId,
        company: 'Acme',
      );

  test('interviews get the evening before and an hour before', () {
    final reminders = ReminderPlanner.plan(
      [event(AgendaEventKind.interview, DateTime(2026, 10, 18, 14))],
      now: now,
    );

    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 17, 19),
      DateTime(2026, 10, 18, 13),
    ]);
    // intl puts a narrow no-break space before "PM".
    expect(
      reminders.first.notification.title,
      matches(RegExp(r'^Interview tomorrow at 2:00\sPM$', unicode: true)),
    );
    expect(reminders.last.notification.title, 'Interview in 1 hour');
    expect(reminders.first.notification.channel, NotificationChannel.reminders);
  });

  test('deadlines get the morning before and the morning of', () {
    final reminders = ReminderPlanner.plan(
      [event(AgendaEventKind.deadline, DateTime(2026, 10, 20, 17))],
      now: now,
    );

    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 19, 9),
      DateTime(2026, 10, 20, 9),
    ]);
  });

  test('skips past times, done items and the past', () {
    final reminders = ReminderPlanner.plan(
      [
        // Tonight: the "evening before" already passed.
        event(AgendaEventKind.interview, DateTime(2026, 10, 16, 18)),
        event(
          AgendaEventKind.followUp,
          DateTime(2026, 10, 17, 10),
          id: 'e2',
          isDone: true,
        ),
        event(AgendaEventKind.other, DateTime(2026, 10, 15, 10), id: 'e3'),
      ],
      now: now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.at, DateTime(2026, 10, 16, 17));
  });

  test('ids are stable and taps open the linked application', () {
    List<int> ids() => ReminderPlanner.plan(
          [
            event(
              AgendaEventKind.followUp,
              DateTime(2026, 10, 17, 10),
              applicationId: 'a1',
            ),
          ],
          now: now,
        ).map((r) => r.notification.id).toList();

    expect(ids(), ids());
    final reminder = ReminderPlanner.plan(
      [
        event(
          AgendaEventKind.followUp,
          DateTime(2026, 10, 17, 10),
          applicationId: 'a1',
        ),
      ],
      now: now,
    ).single;
    final route = NotificationRoute.parse(reminder.notification.payload);
    expect(route, isA<OpenApplicationRoute>());
    expect((route! as OpenApplicationRoute).applicationId, 'a1');
  });
}
