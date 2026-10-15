import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../documents/data/career_document.dart';
import '../data/career_writer.dart';
import '../data/studio_controller.dart';
import 'document_screen.dart';
import 'widgets/generator_scaffold.dart';
import 'writer_error_message.dart';

/// Rewrites the uploaded resume for a target role or a specific job.
class ResumeEnhanceScreen extends StatefulWidget {
  const ResumeEnhanceScreen({
    super.key,
    required this.studio,
    required this.suggestedRoles,
    required this.onUploadResume,
    this.job,
  });

  final StudioController studio;
  final List<String> suggestedRoles;
  final Future<void> Function() onUploadResume;

  /// When set, tailor the resume to this job instead of a role.
  final JobContext? job;

  @override
  State<ResumeEnhanceScreen> createState() => _ResumeEnhanceScreenState();
}

class _ResumeEnhanceScreenState extends State<ResumeEnhanceScreen> {
  late final _roleController = TextEditingController(
    text: widget.suggestedRoles.isEmpty ? '' : widget.suggestedRoles.first,
  );
  bool _isWorking = false;
  String? _error;

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _enhance() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      final job = widget.job;
      final role = _roleController.text.trim();
      final result = await widget.studio.enhanceResume(
        targetRole: job == null ? role : null,
        job: job,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DocumentScreen.draft(
            studio: widget.studio,
            kind: DocumentKind.resume,
            title: job != null
                ? 'Resume for ${job.label}'
                : role.isEmpty
                    ? 'Enhanced resume'
                    : 'Resume · $role',
            content: result.content,
            changes: result.changes,
            provider: result.provider,
            applicationId: job?.applicationId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _error = writerErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final ready = widget.studio.hasResumeText;

    return GeneratorScaffold(
      title: 'Enhance resume',
      headline: job == null
          ? 'Make your resume **stand out**'
          : 'Tailor your resume to **${job.company}**',
      subtitle: 'AI rewrites your uploaded resume with stronger, '
          'keyword-rich bullets. It never invents experience.',
      actionLabel: 'Enhance with AI',
      onAction: ready && !_isWorking ? _enhance : null,
      isWorking: _isWorking,
      errorMessage: _error,
      workingMessages: const [
        'Reading your resume…',
        'Finding your strongest achievements…',
        'Matching keywords to the role…',
        'Polishing every bullet…',
      ],
      children: [
        if (!ready)
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: EmptyState(
              icon: Icons.upload_file_rounded,
              title: 'Upload your resume first',
              message: 'Careerly enhances your real resume. Upload a PDF in '
                  'your career profile.',
              actionLabel: 'Upload resume',
              actionIcon: Icons.upload_rounded,
              onAction: () async {
                await widget.onUploadResume();
                if (mounted) setState(() {});
              },
            ),
          )
        else if (job != null)
          _JobCard(job: job)
        else ...[
          LabeledField(
            label: 'Target role',
            child: TextField(
              controller: _roleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Product Designer',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
            ),
          ),
          if (widget.suggestedRoles.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final role in widget.suggestedRoles)
                  PillChip(
                    label: role,
                    selected: _roleController.text == role,
                    onTap: () => setState(() => _roleController.text = role),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobContext job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.work_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: theme.textTheme.titleMedium),
                Text(
                  [job.company, if (job.location != null) job.location!]
                      .join('  •  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
