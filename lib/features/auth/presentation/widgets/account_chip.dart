import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/remembered_account_store.dart';

/// Shows the remembered account with a way to switch to a different email.
class AccountChip extends StatelessWidget {
  const AccountChip({
    super.key,
    required this.account,
    required this.onChange,
    this.enabled = true,
  });

  final RememberedAccount account;
  final VoidCallback onChange;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = account.name;
    final initial = (name ?? account.email).characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                Text(
                  account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: name == null
                      ? theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)
                      : theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: enabled ? onChange : null,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
