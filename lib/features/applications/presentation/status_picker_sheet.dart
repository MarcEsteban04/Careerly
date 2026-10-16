import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/job_application.dart';
import 'application_status_style.dart';

/// "Move to…" a stage. [current] gets a check mark; null when moving
/// several applications at once.
Future<ApplicationStatus?> showStatusPicker(
  BuildContext context, {
  ApplicationStatus? current,
  String title = 'Move to…',
}) =>
    showModalBottomSheet<ApplicationStatus>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final status in ApplicationStatus.values)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    leading: Icon(status.icon, color: status.colorIn(theme)),
                    title: Text(status.label),
                    trailing: status == current
                        ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(status),
                  ),
              ],
            ),
          ),
        );
      },
    );
