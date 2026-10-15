import 'package:flutter/material.dart';

/// Full-width primary action that swaps its label for a spinner while busy.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? FilledButton.styleFrom(
              disabledBackgroundColor: Theme.of(context).colorScheme.primary,
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
                  color: onPrimary,
                ),
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}
