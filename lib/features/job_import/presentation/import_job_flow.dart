import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/theme/app_spacing.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/application_form_sheet.dart';
import '../data/job_post_reader.dart';

/// Reads a shared job link or post, then opens the tracker form filled in
/// with what was found. Resolves to the saved application, or null.
Future<JobApplication?> importSharedJob(
  BuildContext context, {
  required String shared,
  required JobPostReader reader,
  required ApplicationsRepository applications,
}) async {
  final outcome = await showDialog<_ReadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReadingDialog(reader: reader, shared: shared),
  );
  if (outcome == null || !context.mounted) return null;

  final url = JobPostReader.firstUrl(shared);
  final fallback = ApplicationPrefill(
    jobUrl: url,
    source: url == null ? null : JobPostReader.sourceFor(url),
  );
  final (prefill, notice) = switch (outcome) {
    _Read(:final draft) => (
        ApplicationPrefill(
          company: draft.company,
          role: draft.role,
          location: draft.location,
          salary: draft.salary,
          jobUrl: draft.url,
          source: draft.source,
          jobDescription: draft.description,
        ),
        draft.notice ??
            (draft.hasBasics
                ? null
                : 'Some details were missing from the post. Fill in the rest.'),
      ),
    _Failed(:final error) => (
        fallback,
        switch (error) {
          NotAJobException() =>
            "That doesn't look like a job post. Add the details yourself.",
          AiUnavailableException(allOutOfQuota: true) =>
            "The AI is out of credit, so the post couldn't be read. Add the "
                'details yourself.',
          _ => "Couldn't read that post. Add the details yourself.",
        },
      ),
  };

  return showApplicationFormSheet(
    context,
    repository: applications,
    prefill: prefill,
    notice: notice,
  );
}

/// Asks for a job link or post text, starting with the clipboard's link.
Future<String?> showPasteJobDialog(BuildContext context) async {
  final clipboard = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  final initial =
      clipboard != null && JobPostReader.firstUrl(clipboard) != null
          ? clipboard.trim()
          : '';
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => _PasteDialog(initial: initial),
  );
}

sealed class _ReadOutcome {
  const _ReadOutcome();
}

class _Read extends _ReadOutcome {
  const _Read(this.draft);

  final JobPostDraft draft;
}

class _Failed extends _ReadOutcome {
  const _Failed(this.error);

  final Object error;
}

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({required this.reader, required this.shared});

  final JobPostReader reader;
  final String shared;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    _ReadOutcome outcome;
    try {
      outcome = _Read(await widget.reader.read(widget.shared));
    } catch (error) {
      debugPrint('Reading shared job failed: $error');
      outcome = _Failed(error);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = JobPostReader.firstUrl(widget.shared);

    return AlertDialog(
      content: Row(
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading the job post…', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  url == null
                      ? 'Pulling out the role and details.'
                      : 'From ${JobPostReader.sourceFor(url)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog({required this.initial});

  final String initial;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a job from a link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste a link from LinkedIn, JobStreet, OnlineJobs.ph or anywhere else, '
            'or paste the post itself.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: widget.initial.isEmpty,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'https://',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tip: in any app, tap Share on a job and choose Careerly.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            child: const Text('Read job'),
          ),
        ),
      ],
    );
  }
}
