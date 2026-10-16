import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tab_page.dart';
import '../../applications/data/job_application.dart';
import '../../documents/data/career_document.dart';
import '../../resume/data/resume_insights.dart';
import '../data/resume_versions.dart';
import '../data/studio_controller.dart';
import 'studio_tool.dart';
import 'widgets/resume_versions_list.dart';

/// Studio tab: the uploaded resume, AI tools, and saved documents.
class StudioScreen extends StatelessWidget {
  const StudioScreen({
    super.key,
    required this.studio,
    required this.onUploadResume,
    required this.onTool,
    required this.onOpenDocument,
    required this.applications,
    required this.onAtsCheck,
  });

  final StudioController studio;
  final Future<void> Function() onUploadResume;
  /// Opens one of the tools in the grid.
  final ValueChanged<StudioTool> onTool;
  final ValueChanged<CareerDocument> onOpenDocument;

  /// Tracked applications, for each resume version's results.
  final List<JobApplication> applications;

  /// Checks a resume version against a job.
  final ValueChanged<ResumeVersion> onAtsCheck;

  void _showMessage(BuildContext context, String text) =>
      Island.show(context, text);

  Future<void> _onVersionAction(
    BuildContext context,
    ResumeVersion version,
    ResumeVersionAction action,
  ) async {
    final doc = version.document;
    switch (action) {
      case ResumeVersionAction.open:
        if (doc != null) onOpenDocument(doc);
      case ResumeVersionAction.atsCheck:
        onAtsCheck(version);
      case ResumeVersionAction.duplicate:
        try {
          final copy = await studio.duplicate(
            title: version.isOriginal
                ? 'Resume · ${version.title}'
                : '${version.title} (copy)',
            content: await studio.resumeContent(version.id),
          );
          if (!context.mounted) return;
          _showMessage(context, 'Saved a copy you can edit');
          onOpenDocument(copy);
        } catch (error) {
          if (context.mounted) _showMessage(context, friendlyErrorMessage(error));
        }
      case ResumeVersionAction.rename:
        if (doc == null) return;
        final title = await _askTitle(context, doc.title);
        if (title == null || title.isEmpty || title == doc.title) return;
        try {
          await studio.rename(doc, title);
        } catch (error) {
          if (context.mounted) _showMessage(context, friendlyErrorMessage(error));
        }
      case ResumeVersionAction.delete:
        if (doc == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this version?'),
            content: Text(
              '"${doc.title}" will be removed. Applications it was sent with '
              'keep their record.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await studio.delete(doc);
        } catch (error) {
          if (context.mounted) _showMessage(context, friendlyErrorMessage(error));
        }
    }
  }

  static Future<String?> _askTitle(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename version'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Resume · Frontend'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final items = studio.items;
        final letters =
            items?.where((d) => d.kind == DocumentKind.coverLetter).toList() ??
            [];
        final resume = studio.profile().resume;
        final versions = ResumeVersion.build(
          original: resume,
          documents: items ?? const [],
          applications: applications,
        );

        return TabPage(
          title: 'Studio',
          subtitle: 'AI tools for every step of your search',
          onRefresh: studio.load,
          heroChild: _ResumeCard(
            resume: resume,
            hasText: studio.hasResumeText,
            onUpload: onUploadResume,
          ),
          children: [
            const SectionHeader(title: 'Tools'),
            _ToolGrid(onTool: onTool),
            const SizedBox(height: AppSpacing.xl),
            if (items == null && studio.error == null)
              const Center(child: CircularProgressIndicator())
            else if (items == null)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load your documents",
                  message: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  actionIcon: Icons.refresh_rounded,
                  onAction: studio.load,
                ),
              )
            else if (versions.isEmpty && letters.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: const EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'Nothing saved yet',
                  message:
                      'Enhanced resumes and cover letters you save show '
                      'up here, ready to share as PDF.',
                ),
              )
            else ...[
              if (versions.isNotEmpty) ...[
                const SectionHeader(title: 'Resume versions'),
                ResumeVersionsList(
                  versions: versions,
                  onAction: (version, action) =>
                      _onVersionAction(context, version, action),
                ),
                if (versions.length > 1 && versions.every((v) => v.sent == 0))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'When you apply with the application kit, Careerly '
                      'tracks which version gets interviews.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (letters.isNotEmpty) ...[
                const SectionHeader(title: 'Cover letters'),
                _DocumentList(documents: letters, onOpen: onOpenDocument),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// The uploaded resume as a card in the header, with upload/replace.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.resume,
    required this.hasText,
    required this.onUpload,
  });

  final ResumeInsights? resume;
  final bool hasText;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resume = this.resume;
    final needsUpload = resume == null || !hasText;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg - 4),
        border: Border.all(color: colorScheme.outline),
        boxShadow: AppShadows.card(theme.brightness),
      ),
      child: Row(
        children: [
          IconBadge(
            icon: needsUpload
                ? Icons.upload_file_rounded
                : Icons.description_rounded,
            size: 48,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsUpload ? 'Add your resume' : resume.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  needsUpload
                      ? resume == null
                            ? 'Upload a PDF to unlock AI writing.'
                            : 'Re-upload it so AI can work from the full text.'
                      : resume.headline ??
                            'Uploaded ${DateFormat('MMM d').format(resume.uploadedAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: Text(needsUpload ? 'Upload' : 'Replace'),
          ),
        ],
      ),
    );
  }
}

/// Every Studio tool, three to a row.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.onTool});

  final ValueChanged<StudioTool> onTool;

  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    const tools = StudioTool.values;
    return Column(
      children: [
        for (var start = 0; start < tools.length; start += _perRow) ...[
          if (start > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + _perRow; i++) ...[
                  if (i > start) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: i < tools.length
                        ? _ToolCard(tool: tools[i], onTap: () => onTool(tools[i]))
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final StudioTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tool.hint,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: tool.icon, accent: tool.accent, size: 38),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tool.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents, required this.onOpen});

  final List<CareerDocument> documents;
  final ValueChanged<CareerDocument> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (final (i, doc) in documents.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            ListTile(
              onTap: () => onOpen(doc),
              leading: IconBadge(
                icon: doc.kind == DocumentKind.resume
                    ? Icons.description_rounded
                    : Icons.mail_rounded,
                accent: Accent.blue,
                size: 40,
              ),
              title: Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                DateFormat('MMM d, y · h:mm a').format(doc.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
