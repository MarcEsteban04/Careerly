import 'package:flutter/material.dart';

import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/mini_bar_chart.dart';
import '../../../applications/data/job_application.dart';
import '../../../applications/presentation/application_status_style.dart';

/// How the search is going: applications sent per week for the last
/// [weeks] weeks, and where every tracked role stands.
class MomentumCard extends StatelessWidget {
  const MomentumCard({
    super.key,
    required this.applications,
    required this.onOpenStage,
  });

  final List<JobApplication> applications;
  final ValueChanged<ApplicationStatus> onOpenStage;

  static const weeks = 8;

  /// Applications sent in each of the last [weeks] weeks, oldest first.
  static List<int> weeklySent(List<JobApplication> applications, DateTime now) {
    final thisWeek = now.startOfWeek;
    final counts = List.filled(weeks, 0);
    for (final a in applications) {
      if (a.status == ApplicationStatus.saved) continue;
      final day = (a.appliedOn ?? a.createdAt).startOfWeek;
      final ago = thisWeek.difference(day).inDays ~/ 7;
      if (ago >= 0 && ago < weeks) counts[weeks - 1 - ago]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final perWeek = weeklySent(applications, DateTime.now());
    final thisWeek = perWeek.last;
    final lastWeek = perWeek[weeks - 2];
    final change = thisWeek - lastWeek;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.insights_rounded,
                accent: Accent.violet,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your momentum',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      thisWeek == 1
                          ? '1 application sent this week'
                          : '$thisWeek applications sent this week',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (change != 0) _TrendChip(change: change),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (perWeek.every((n) => n == 0))
            Container(
              height: 56,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Mark a job as applied and your weekly bars start here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            MiniBarChart(
              values: perWeek,
              color: colorScheme.secondary,
              height: 56,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$weeks weeks ago',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                'This week',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.md),
          _Pipeline(applications: applications, onOpenStage: onOpenStage),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.change});

  final int change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = change > 0 ? Accent.emerald : Accent.amber;
    final tone = accent.colorIn(theme.brightness);

    return Semantics(
      label: '${change > 0 ? 'Up' : 'Down'} ${change.abs()} from last week',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              change > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 16,
              color: tone,
            ),
            const SizedBox(width: 4),
            Text(
              '${change > 0 ? '+' : '−'}${change.abs()}',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: tone, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A segmented bar of every stage, sized by how many roles sit in it, with
/// a tappable legend.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.applications, required this.onOpenStage});

  final List<JobApplication> applications;
  final ValueChanged<ApplicationStatus> onOpenStage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = {
      for (final status in ApplicationStatus.values)
        status: applications.where((a) => a.status == status).length,
    };
    final stages = [
      for (final status in ApplicationStatus.values)
        if (counts[status]! > 0) status,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pipeline',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, status) in stages.indexed) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: counts[status]!,
                    child: ColoredBox(color: status.colorIn(theme)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final status in stages)
              InkWell(
                onTap: () => onOpenStage(status),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: status.colorIn(theme),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${counts[status]}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
