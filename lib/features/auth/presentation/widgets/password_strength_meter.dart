import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum PasswordStrength { empty, weak, fair, good, strong }

/// Scores a password on length and character variety.
PasswordStrength passwordStrengthOf(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  if (password.length < 8) return PasswordStrength.weak;

  var score = 0;
  if (password.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

  return switch (score) {
    0 || 1 => PasswordStrength.fair,
    2 => PasswordStrength.good,
    _ => PasswordStrength.strong,
  };
}

/// Four-segment strength bar with a label, shown under a password field.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strength = passwordStrengthOf(password);

    final (filled, color, label) = switch (strength) {
      PasswordStrength.empty => (
          0,
          theme.colorScheme.outline,
          'Use 8+ characters with letters and numbers',
        ),
      PasswordStrength.weak => (1, theme.colorScheme.error, 'Too short'),
      PasswordStrength.fair => (
          2,
          isDark ? AppColors.warningDark : AppColors.warning,
          'Fair',
        ),
      PasswordStrength.good => (3, theme.colorScheme.primary, 'Good'),
      PasswordStrength.strong => (
          4,
          isDark ? AppColors.successDark : AppColors.success,
          'Strong',
        ),
    };

    return Semantics(
      label: 'Password strength: $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < filled ? color : theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: strength == PasswordStrength.empty
                  ? theme.colorScheme.onSurfaceVariant
                  : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
