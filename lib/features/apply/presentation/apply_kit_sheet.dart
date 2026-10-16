import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../documents/data/career_document.dart';
import '../../documents/data/document_markup.dart';
import '../../documents/data/document_pdf.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/data/studio_controller.dart';

/// What the user chose to send.
class ApplyKitChoice {
  const ApplyKitChoice({this.resumeDocumentId, this.coverLetterDocumentId});

  final String? resumeDocumentId;
  final String? coverLetterDocumentId;
}

/// What the kit sheet resolved to.
sealed class ApplyKitResult {
  const ApplyKitResult();
}

/// Open the application page with these documents.
class OpenApplication extends ApplyKitResult {
  const OpenApplication(this.choice);
  final ApplyKitChoice choice;
}

/// Go write a cover letter first.
class WriteCoverLetterFirst extends ApplyKitResult {
  const WriteCoverLetterFirst();
}

/// The "application kit": pick the resume and cover letter to send, get
/// them as PDF or text, then open the application page.
Future<ApplyKitResult?> showApplyKitSheet(
  BuildContext context, {
  required StudioController studio,
  required JobContext job,
}) {
  return showModalBottomSheet<ApplyKitResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ApplyKit(studio: studio, job: job),
  );
}

class _ResumeOption {
  const _ResumeOption(this.id, this.label, this.subtitle);

  final String id;
  final String label;
  final String subtitle;
}

class _ApplyKit extends StatefulWidget {
  const _ApplyKit({required this.studio, required this.job});

  final StudioController studio;
  final JobContext job;

  @override
  State<_ApplyKit> createState() => _ApplyKitState();
}

class _ApplyKitState extends State<_ApplyKit> {
  late final List<_ResumeOption> _resumes = _resumeOptions();
  late final List<CareerDocument> _letters = _letterOptions();
  late String? _resumeId = _resumes.isEmpty ? null : _resumes.first.id;
  late String? _letterId = _letters.isEmpty ? null : _letters.first.id;
  String? _busyId;

  List<_ResumeOption> _resumeOptions() {
    final studio = widget.studio;
    final original = studio.profile().resume;
    final job = widget.job;
    final saved = (studio.items ?? const <CareerDocument>[])
        .where((d) => d.kind == DocumentKind.resume)
        .toList()
      // Resumes tailored to this job or company first.
      ..sort((a, b) => _relevance(b, job).compareTo(_relevance(a, job)));
    return [
      for (final doc in saved) _ResumeOption(doc.id, doc.title, 'Enhanced'),
      if (original?.textDocumentId != null)
        _ResumeOption(original!.textDocumentId!, original.fileName, 'Original'),
    ];
  }

  List<CareerDocument> _letterOptions() {
    final job = widget.job;
    return (widget.studio.items ?? const <CareerDocument>[])
        .where((d) => d.kind == DocumentKind.coverLetter)
        .where((d) => _relevance(d, job) > 0)
        .toList()
      ..sort((a, b) => _relevance(b, job).compareTo(_relevance(a, job)));
  }

  static int _relevance(CareerDocument doc, JobContext job) {
    if (job.applicationId != null && doc.applicationId == job.applicationId) {
      return 3;
    }
    final title = doc.title.toLowerCase();
    if (title.contains(job.company.toLowerCase())) return 2;
    if (title.contains(job.title.toLowerCase())) return 1;
    return 0;
  }

  Future<void> _sharePdf(String id, String title) async {
    setState(() => _busyId = id);
    try {
      final content = await _content(id);
      await DocumentPdf.share(
        title: title,
        bytes: await DocumentPdf.build(content),
      );
    } catch (_) {
      _toast("Couldn't create the PDF.");
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _copy(String id) async {
    try {
      final content = await _content(id);
      await Clipboard.setData(ClipboardData(text: markupToPlainText(content)));
      _toast('Copied. Paste it into the application form.');
    } catch (_) {
      _toast("Couldn't copy that document.");
    }
  }

  Future<String> _content(String id) async {
    for (final doc in widget.studio.items ?? const <CareerDocument>[]) {
      if (doc.id == id) return doc.content;
    }
    return widget.studio.resumeText();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your application kit',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            widget.job.label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StepLabel(number: 1, text: 'Resume to send'),
          if (_resumes.isEmpty)
            _Hint(
              'No resume yet. Upload one in Studio to attach it here.',
            )
          else
            for (final option in _resumes)
              _DocumentChoice(
                title: option.label,
                subtitle: option.subtitle,
                selected: _resumeId == option.id,
                busy: _busyId == option.id,
                onSelect: () => setState(() => _resumeId = option.id),
                onPdf: () => _sharePdf(option.id, option.label),
                onCopy: () => _copy(option.id),
              ),
          const SizedBox(height: AppSpacing.md),
          _StepLabel(number: 2, text: 'Cover letter'),
          for (final letter in _letters)
            _DocumentChoice(
              title: letter.title,
              subtitle: 'Saved in Studio',
              selected: _letterId == letter.id,
              busy: _busyId == letter.id,
              onSelect: () => setState(() => _letterId = letter.id),
              onPdf: () => _sharePdf(letter.id, letter.title),
              onCopy: () => _copy(letter.id),
            ),
          if (_letters.isNotEmpty)
            _DocumentChoice(
              title: 'No cover letter',
              selected: _letterId == null,
              onSelect: () => setState(() => _letterId = null),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(const WriteCoverLetterFirst()),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _letters.isEmpty
                  ? 'Write a cover letter for this job'
                  : 'Write a new one',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StepLabel(number: 3, text: 'Apply on their site'),
          _Hint(
            'Tap PDF to save a document for upload, or Copy to paste it. '
            "When you come back, Careerly will ask if you applied and track it.",
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Open application page',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => Navigator.of(context).pop(
              OpenApplication(
                ApplyKitChoice(
                  resumeDocumentId: _resumeId,
                  coverLetterDocumentId: _letterId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
      );
}

class _DocumentChoice extends StatelessWidget {
  const _DocumentChoice({
    required this.title,
    required this.selected,
    required this.onSelect,
    this.subtitle,
    this.busy = false,
    this.onPdf,
    this.onCopy,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onPdf;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.06)
            : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xxs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onCopy != null)
                  IconButton(
                    tooltip: 'Copy text',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                if (onPdf != null)
                  IconButton(
                    tooltip: 'Save or share PDF',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onPdf,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
