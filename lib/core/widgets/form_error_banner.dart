import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Inline, form-level error message (e.g. wrong credentials).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: error, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
