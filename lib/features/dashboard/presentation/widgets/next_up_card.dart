import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../agenda/data/agenda_event.dart';
import '../../../agenda/presentation/agenda_event_style.dart';

/// Spotlight on the very next agenda item, with a countdown and a quick
/// "done" action. Invites scheduling something when the agenda is clear.
class NextUpCard extends StatelessWidget {
  const NextUpCard({
    super.key,
    required this.event,
    required this.onDone,
    required this.onSchedule,
    required this.onSeeAgenda,
  });

  final AgendaEvent? event;
  final VoidCallback onDone;
  final VoidCallback onSchedule;
  final VoidCallback onSeeAgenda;

  @override
  Widget build(BuildContext context) {
    final event = this.event;
    return event == null ? _buildClear(context) : _buildEvent(context, event);
  }

  Widget _buildEvent(BuildContext context, AgendaEvent event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final details = [
      '${event.startsAt.relativeDayLabel()}, ${event.startsAt.timeLabel}',
      if (event.company != null) event.company!,
    ].join(' · ');

    return AppCard(
      onTap: onSeeAgenda,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _DateBlock(date: event.startsAt),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Accent.teal.tintIn(theme.brightness),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'NEXT UP · ${event.startsAt.countdownLabel().toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Accent.teal.colorIn(theme.brightness),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      event.kind.icon,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filledTonal(
            tooltip: 'Mark done',
            onPressed: onDone,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: colorScheme.primary,
            ),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildClear(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onSchedule,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.event_available_rounded,
            accent: Accent.teal,
            size: 52,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're all clear",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Schedule an interview, follow-up or deadline.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.add_circle_rounded, color: colorScheme.primary, size: 28),
        ],
      ),
    );
  }
}

/// A calendar-page style block: month over the day number.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.raised(theme.brightness),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          Text(
            '${date.day}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
