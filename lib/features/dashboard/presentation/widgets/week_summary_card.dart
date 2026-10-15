import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Brand-gradient card with this week's headline numbers and a nudge.
class WeekSummaryCard extends StatelessWidget {
  const WeekSummaryCard({
    super.key,
    required this.appliedThisWeek,
    required this.interviewsNextWeek,
    required this.offers,
  });

  final int appliedThisWeek;
  final int interviewsNextWeek;
  final int offers;

  String get _message {
    if (offers > 0) return 'You have an offer on the table. Well earned.';
    if (interviewsNextWeek > 0) {
      return interviewsNextWeek == 1
          ? 'One interview coming up. You\'ve got this.'
          : '$interviewsNextWeek interviews coming up. You\'ve got this.';
    }
    if (appliedThisWeek > 0) {
      return 'Nice momentum: $appliedThisWeek sent this week.';
    }
    return "Let's get your first application in this week.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandBright,
            AppColors.brandDeep,
            AppColors.brandNight,
          ],
          stops: [0, 0.6, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'This week',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(value: appliedThisWeek, label: 'Applied'),
              _divider(),
              _Stat(value: interviewsNextWeek, label: 'Interviews'),
              _divider(),
              _Stat(value: offers, label: 'Offers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
