import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/agenda_event.dart';
import '../agenda_event_style.dart';

/// One agenda row: date badge, title, details, and a done checkbox.
class AgendaTile extends StatelessWidget {
  const AgendaTile({
    super.key,
    required this.event,
    required this.onToggleDone,
    this.onTap,
  });

  final AgendaEvent event;
  final ValueChanged<bool> onToggleDone;

  /// Opens the item for editing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = event.startsAt.isSameDay(DateTime.now());
    final badgeColor = isToday ? colorScheme.primary : colorScheme.onSurface;
    // The date badge and day heading already show the day; the icon shows
    // the kind.
    final details = [
      event.startsAt.timeLabel,
      if (event.company != null) event.company!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: isToday
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(event.startsAt).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '${event.startsAt.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: event.kind.label,
                        child: Icon(
                          event.kind.icon,
                          size: 16,
                          color: colorScheme.primary,
                          semanticLabel: event.kind.label,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: event.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: event.isDone
                                ? colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: event.isDone,
              shape: const CircleBorder(),
              semanticLabel: 'Mark "${event.title}" done',
              onChanged: (value) => onToggleDone(value ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
