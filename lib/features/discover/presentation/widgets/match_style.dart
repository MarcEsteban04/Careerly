import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Color for a match score: green for strong, blue for decent, grey below.
Color matchColor(int score, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  if (score >= 75) return isDark ? AppColors.successDark : AppColors.success;
  if (score >= 50) return theme.colorScheme.primary;
  return theme.colorScheme.onSurfaceVariant;
}
