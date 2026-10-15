import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A form field with its label placed above it, which reads more clearly
/// than a floating label.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
