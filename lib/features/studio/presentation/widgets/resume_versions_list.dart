import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/resume_versions.dart';

enum ResumeVersionAction { open, atsCheck, rename, duplicate, delete }

/// Every resume version with how it has done: sends, interviews, and a
/// badge on the best performer.
class ResumeVersionsList extends StatelessWidget {
  const ResumeVersionsList({
    super.key,
    required this.versions,
    required this.onAction,
  });

  final List<ResumeVersion> versions;
  final void Function(ResumeVersion version, ResumeVersionAction action)
      onAction;

  @override
  Widget build(BuildContext context) {
    final best = ResumeVersion.best(versions);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (final (i, version) in versions.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            _VersionRow(
              version: version,
              isBest: version.id == best?.id,
              onAction: (action) => onAction(version, action),
            ),
          ],
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.isBest,
    required this.onAction,
  });

  final ResumeVersion version;
  final bool isBest;
  final ValueChanged<ResumeVersionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final success = isDark ? AppColors.successDark : AppColors.success;
    final stats = version.sent == 0
        ? 'Not sent yet'
        : '${version.sent == 1 ? 'Sent once' : 'Sent ${version.sent}×'}'
            ' · ${version.interviews == 1 ? '1 interview' : '${version.interviews} interviews'}';

    return ListTile(
      onTap: () => onAction(
        version.isOriginal
            ? ResumeVersionAction.atsCheck
            : ResumeVersionAction.open,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: version.isOriginal
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Icon(
          version.isOriginal
              ? Icons.upload_file_rounded
              : Icons.description_outlined,
          size: 20,
          color: version.isOriginal
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        version.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              version.isOriginal
                  ? 'Original upload · $stats'
                  : '${DateFormat('MMM d').format(version.createdAt)} · $stats',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (isBest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 12, color: success),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Best performer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      trailing: PopupMenuButton<ResumeVersionAction>(
        tooltip: 'More for ${version.title}',
        onSelected: onAction,
        itemBuilder: (context) => [
          if (!version.isOriginal)
            const PopupMenuItem(
              value: ResumeVersionAction.open,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Open and edit'),
              ),
            ),
          const PopupMenuItem(
            value: ResumeVersionAction.atsCheck,
            child: ListTile(
              leading: Icon(Icons.fact_check_outlined),
              title: Text('ATS check for a job'),
            ),
          ),
          PopupMenuItem(
            value: ResumeVersionAction.duplicate,
            child: ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(
                version.isOriginal ? 'Make an editable copy' : 'Duplicate',
              ),
            ),
          ),
          if (!version.isOriginal) ...[
            const PopupMenuItem(
              value: ResumeVersionAction.rename,
              child: ListTile(
                leading: Icon(Icons.drive_file_rename_outline_rounded),
                title: Text('Rename'),
              ),
            ),
            PopupMenuItem(
              value: ResumeVersionAction.delete,
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
