import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../applications/data/job_application.dart';
import '../../../applications/presentation/application_status_style.dart';

/// Distribution bar and per-stage counts for active applications.
class PipelineCard extends StatelessWidget {
  const PipelineCard({super.key, required this.countOf});

  final int Function(ApplicationStatus status) countOf;

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
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final stage in _stages)
                Expanded(
                  child: Semantics(
                    label: '${counts[stage]} ${stage.label}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${counts[stage]}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: stage.colorIn(theme),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                stage.shortLabel,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
