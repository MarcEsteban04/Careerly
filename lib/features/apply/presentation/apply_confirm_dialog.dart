import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// The user's answer to "Did you apply?".
class ApplyConfirmation {
  const ApplyConfirmation({required this.followUp});

  /// Add a follow-up reminder a week from now.
  final bool followUp;
}

/// Asks, after the user returns from the application page, whether they
/// applied. Resolves to null for "Not yet".
Future<ApplyConfirmation?> showApplyConfirmDialog(
  BuildContext context, {
  required String jobLabel,
}) {
  return showDialog<ApplyConfirmation>(
    context: context,
    builder: (_) => _ApplyConfirmDialog(jobLabel: jobLabel),
  );
}

class _ApplyConfirmDialog extends StatefulWidget {
  const _ApplyConfirmDialog({required this.jobLabel});

  final String jobLabel;

  @override
  State<_ApplyConfirmDialog> createState() => _ApplyConfirmDialogState();
}

class _ApplyConfirmDialogState extends State<_ApplyConfirmDialog> {
  bool _followUp = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.task_alt_rounded, color: colorScheme.primary, size: 32),
      title: const Text('Did you apply?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.jobLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: _followUp,
              onChanged: (v) => setState(() => _followUp = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Remind me to follow up in a week'),
              dense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not yet'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () =>
              Navigator.of(context).pop(ApplyConfirmation(followUp: _followUp)),
          child: const Text('Yes, I applied'),
        ),
      ],
    );
  }
}
