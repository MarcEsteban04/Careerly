import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum FormBannerTone { error, success }

/// Inline, form-level message, e.g. wrong credentials or "check your inbox".
class FormBanner extends StatelessWidget {
  const FormBanner({
    super.key,
    required this.message,
    this.tone = FormBannerTone.error,
  });

  final String message;
  final FormBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (color, icon) = switch (tone) {
      FormBannerTone.error => (
          theme.colorScheme.error,
          Icons.error_outline_rounded,
        ),
      FormBannerTone.success => (
          isDark ? AppColors.successDark : AppColors.success,
          Icons.check_circle_outline_rounded,
        ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: color, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
