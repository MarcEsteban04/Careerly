import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The bar of main actions pinned to the bottom of a detail screen: a
/// surface with rounded top corners and a soft shadow, clear of the
/// system gesture area.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        border: isDark
            ? Border(top: BorderSide(color: theme.colorScheme.outline))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: child,
    );
  }
}
