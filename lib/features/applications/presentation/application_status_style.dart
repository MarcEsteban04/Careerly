import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/job_application.dart';

extension ApplicationStatusStyle on ApplicationStatus {
  Color colorIn(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return switch (this) {
      ApplicationStatus.saved => theme.colorScheme.onSurfaceVariant,
      ApplicationStatus.applied => theme.colorScheme.secondary,
      ApplicationStatus.interviewing =>
        isDark ? AppColors.warningDark : AppColors.warning,
      ApplicationStatus.offer =>
        isDark ? AppColors.successDark : AppColors.success,
      ApplicationStatus.rejected => theme.colorScheme.error,
    };
  }

  IconData get icon => switch (this) {
        ApplicationStatus.saved => Icons.bookmark_outline_rounded,
        ApplicationStatus.applied => Icons.send_rounded,
        ApplicationStatus.interviewing => Icons.forum_outlined,
        ApplicationStatus.offer => Icons.celebration_outlined,
        ApplicationStatus.rejected => Icons.block_rounded,
      };
}

/// Small colored label for an application's status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.colorIn(theme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
