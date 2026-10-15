import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../applications/data/job_application.dart';
import '../../documents/data/career_document.dart';
import '../data/career_writer.dart';
import '../data/studio_controller.dart';
import 'document_screen.dart';
import 'widgets/generator_scaffold.dart';
import 'writer_error_message.dart';

/// Writes a cover letter for a job from the uploaded resume.
class CoverLetterScreen extends StatefulWidget {
  const CoverLetterScreen({
    super.key,
    required this.studio,
    required this.onUploadResume,
    this.job,
    this.trackedApplications = const [],
  });

  final StudioController studio;
  final Future<void> Function() onUploadResume;

  /// Prefills the job when opened from a posting or application.
  final JobContext? job;

  /// Offered as quick picks when no job was given.
  final List<JobApplication> trackedApplications;

  @override
  State<CoverLetterScreen> createState() => _CoverLetterScreenState();
}

class _CoverLetterScreenState extends State<CoverLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _roleController = TextEditingController(text: widget.job?.title);
  late final _companyController =
      TextEditingController(text: widget.job?.company);
  late final _descriptionController =
      TextEditingController(text: widget.job?.description);
  late String? _applicationId = widget.job?.applicationId;
  late final String? _location = widget.job?.location;

  LetterTone _tone = LetterTone.professional;
  LetterLength _length = LetterLength.standard;
  bool _isWorking = false;
  String? _error;

  @override
  void dispose() {
    _roleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pick(JobApplication application) => setState(() {
        _roleController.text = application.role;
        _companyController.text = application.company;
        _applicationId = application.id;
      });

  Future<void> _write() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });

    final job = JobContext(
      title: _roleController.text.trim(),
      company: _companyController.text.trim(),
      location: _location,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      applicationId: _applicationId,
    );
    try {
      final letter = await widget.studio.writeCoverLetter(
        job: job,
        tone: _tone,
        length: _length,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DocumentScreen.draft(
            studio: widget.studio,
            kind: DocumentKind.coverLetter,
            title: 'Cover letter · ${job.label}',
            content: letter.content,
            provider: letter.provider,
            applicationId: job.applicationId,
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

  static String? _required(String? value, String message) =>
      (value?.trim() ?? '').isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final ready = widget.studio.hasResumeText;
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Form(
      key: _formKey,
      child: GeneratorScaffold(
        title: 'Cover letter',
        headline: widget.job == null
            ? 'Write a cover letter that **gets read**'
            : 'Your letter to **${widget.job!.company}**',
        subtitle: 'Written from your resume and tailored to the job. Edit it '
            'before you send it.',
        actionLabel: 'Write cover letter',
        onAction: ready && !_isWorking ? _write : null,
        isWorking: _isWorking,
        errorMessage: _error,
        workingMessages: const [
          'Reading the job…',
          'Picking your most relevant experience…',
          'Drafting your opening…',
          'Polishing the closing…',
        ],
        children: [
          if (!ready) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: EmptyState(
                icon: Icons.upload_file_rounded,
                title: 'Upload your resume first',
                message: 'Cover letters are written from your real experience.',
                actionLabel: 'Upload resume',
                actionIcon: Icons.upload_rounded,
                onAction: () async {
                await widget.onUploadResume();
                if (mounted) setState(() {});
              },
              ),
            ),
          ] else ...[
            if (widget.job == null && widget.trackedApplications.isNotEmpty) ...[
              Text('From your tracker', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final application
                        in widget.trackedApplications.take(8)) ...[
                      PillChip(
                        label: '${application.role} · ${application.company}',
                        selected: _applicationId == application.id,
                        onTap: () => _pick(application),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Role',
                    child: TextFormField(
                      controller: _roleController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Job title'),
                      validator: (v) => _required(v, 'Enter the role'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: LabeledField(
                    label: 'Company',
                    child: TextFormField(
                      controller: _companyController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Company'),
                      validator: (v) => _required(v, 'Enter the company'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: 'Job description (recommended)',
              child: TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Paste the posting so the letter matches what '
                      'they ask for',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text('More detail here means a better-tailored letter.',
                style: hintStyle),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: 'Tone',
              child: ChoiceChipGroup<LetterTone>(
                values: LetterTone.values,
                selected: _tone,
                labelOf: (t) => t.label,
                onSelected: (t) => setState(() => _tone = t),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: 'Length',
              child: ChoiceChipGroup<LetterLength>(
                values: LetterLength.values,
                selected: _length,
                labelOf: (l) => '${l.label} · ${l.words}',
                onSelected: (l) => setState(() => _length = l),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
