import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Section title with an optional trailing action, e.g. "Up next   + Add" or
/// "Recent   See all >".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.trailingIcon = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  /// Put the icon after the label (e.g. a chevron for "See all").
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(actionIcon, size: 18);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!trailingIcon) ...[icon, const SizedBox(width: 4)],
                  Text(actionLabel!),
                  if (trailingIcon) ...[const SizedBox(width: 2), icon],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
