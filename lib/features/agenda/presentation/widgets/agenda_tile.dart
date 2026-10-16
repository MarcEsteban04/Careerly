import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../data/agenda_event.dart';
import '../agenda_event_style.dart';

/// One agenda row: time, a badge in the kind's color, title, details, and
/// a done checkbox. The day is shown by the group heading.
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
    final muted = colorScheme.onSurfaceVariant;
    final details = [
      event.kind.label,
      if (event.company != null) event.company!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('h:mm').format(event.startsAt),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: event.isDone ? muted : null,
                    ),
                  ),
                  Text(
                    DateFormat('a').format(event.startsAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: event.isDone ? 0.5 : 1,
              child: Tooltip(
                message: event.kind.label,
                child: IconBadge(
                  icon: event.kind.icon,
                  accent: event.kind.accent,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          event.isDone ? TextDecoration.lineThrough : null,
                      color: event.isDone ? muted : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
