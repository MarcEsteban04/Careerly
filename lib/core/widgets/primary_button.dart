import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Full-width primary action with a soft brand glow. Swaps its label for a
/// spinner while busy.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: isLoading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: colorScheme.primary,
              )
            : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? SizedBox.square(
                  key: const ValueKey('loading'),
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    if (icon != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(icon, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
