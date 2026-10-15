import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../applications/data/job_application.dart';
import '../../../applications/presentation/application_status_style.dart';

/// Distribution bar plus a tappable tile per active stage.
class PipelineCard extends StatelessWidget {
  const PipelineCard({
    super.key,
    required this.countOf,
    required this.onStageTap,
  });

  final int Function(ApplicationStatus status) countOf;
  final ValueChanged<ApplicationStatus> onStageTap;

  static const _stages = [
    ApplicationStatus.saved,
    ApplicationStatus.applied,
    ApplicationStatus.interviewing,
    ApplicationStatus.offer,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final counts = {for (final s in _stages) s: countOf(s)};
    final active = counts.values.fold(0, (sum, c) => sum + c);
    final rejected = countOf(ApplicationStatus.rejected);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$active',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    active == 1 ? 'active application' : 'active applications',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                if (rejected > 0)
                  Text(
                    '$rejected closed',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: active == 0
                    ? ColoredBox(color: colorScheme.outlineVariant)
                    : Row(
                        children: [
                          for (final stage in _stages)
                            if (counts[stage]! > 0)
                              Expanded(
                                flex: counts[stage]!,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 2),
                                  color: stage.colorIn(theme),
                                ),
                              ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final stage in _stages)
                Expanded(
                  child: _StageTile(
                    stage: stage,
                    count: counts[stage]!,
                    onTap: () => onStageTap(stage),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.stage,
    required this.count,
    required this.onTap,
  });

  final ApplicationStatus stage;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = stage.colorIn(theme);

    return Semantics(
      button: true,
      label: '$count ${stage.label}. Show these applications',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(stage.icon, size: 17, color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
              ),
              Text(
                stage.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
