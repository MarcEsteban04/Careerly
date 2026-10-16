import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/agenda_event.dart';
import '../agenda_event_style.dart';

/// The next seven days, today in ink, with a dot for each
/// thing planned that day (up to three).
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.events, required this.today});

  final List<AgendaEvent> events;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = today.dateOnly;
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];

    return Row(
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _Day(day: day, isToday: i == 0, theme: theme, events: [
            for (final e in events)
              if (!e.isDone && e.startsAt.isSameDay(day)) e,
          ])),
        ],
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.isToday,
    required this.theme,
    required this.events,
  });

  final DateTime day;
  final bool isToday;
  final ThemeData theme;
  final List<AgendaEvent> events;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final foreground =
        isToday ? colorScheme.onPrimary : colorScheme.onSurface;
    final label = '${DateFormat('EEEE').format(day)}, '
        '${events.isEmpty ? 'nothing planned' : '${events.length} planned'}';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isToday ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isToday ? null : Border.all(color: colorScheme.outline),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('E').format(day).substring(0, 2).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday
                    ? foreground.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final e in events.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? AppColors.accent : e.kind.accent.deep,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
