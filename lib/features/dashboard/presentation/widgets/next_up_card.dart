import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand_sky.dart';
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: BrandSky.gradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(event.kind.icon, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT UP · ${event.startsAt.countdownLabel().toUpperCase()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.outlined(
            tooltip: 'Mark done',
            onPressed: onDone,
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.event_available_outlined,
              color: colorScheme.primary,
            ),
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
          Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
        ],
      ),
    );
  }
}
