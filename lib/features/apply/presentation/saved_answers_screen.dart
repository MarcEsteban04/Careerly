import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/hero_top_bar.dart';
import '../../../core/widgets/scroll_aware_status_bar.dart';
import '../../../core/widgets/tag_pill.dart';
import '../data/answer_library.dart';

/// The answers Careerly remembers from application forms: edit one to
/// change how it's answered next time, or delete it.
class SavedAnswersScreen extends StatefulWidget {
  const SavedAnswersScreen({super.key, required this.library});

  final AnswerLibrary library;

  @override
  State<SavedAnswersScreen> createState() => _SavedAnswersScreenState();
}

class _SavedAnswersScreenState extends State<SavedAnswersScreen> {
  List<SavedAnswer>? _answers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final answers = await widget.library.load();
    if (mounted) setState(() => _answers = answers);
  }

  Future<void> _replace(List<SavedAnswer> answers) async {
    setState(() => _answers = answers);
    await widget.library.save(answers);
  }

  Future<void> _edit(SavedAnswer answer) async {
    final updated = await showFormSheet<String>(
      context,
      child: _EditAnswer(answer: answer),
    );
    if (updated == null || !mounted) return;
    await _replace([
      for (final a in _answers!)
        identical(a, answer)
            ? SavedAnswer(
                question: a.question,
                answer: updated,
                company: a.company,
                updatedAt: DateTime.now(),
              )
            : a,
    ]);
  }

  Future<void> _delete(SavedAnswer answer) async {
    final before = _answers!;
    await _replace([for (final a in before) if (!identical(a, answer)) a]);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Answer deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _replace(before)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answers = _answers;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: ScrollAwareStatusBar(
        threshold: 80,
        child: ListView(
          padding: EdgeInsets.only(bottom: AppSpacing.xl + bottom),
          children: [
            HeroHeader(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HeroTopBar(title: 'Saved answers'),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Answers you approved on application forms. Fill with '
                    'Careerly suggests them first, so you answer the same '
                    'way every time. They stay on this phone.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: answers == null
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : answers.isEmpty
                      ? const AppCard(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.lg,
                          ),
                          child: EmptyState(
                            icon: Icons.bookmark_border_rounded,
                            title: 'No saved answers yet',
                            message: 'When you fill a form with Careerly, the '
                                'answers you keep are saved here.',
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final answer in answers) ...[
                              _AnswerCard(
                                answer: answer,
                                onEdit: () => _edit(answer),
                                onDelete: () => _delete(answer),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedAnswer answer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  answer.question,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              IconButton(
                tooltip: 'Delete answer',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              answer.answer,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
          if (answer.company != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TagPill(
              label: 'Only for ${answer.company}',
              leading: const Icon(Icons.apartment_rounded, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditAnswer extends StatefulWidget {
  const _EditAnswer({required this.answer});

  final SavedAnswer answer;

  @override
  State<_EditAnswer> createState() => _EditAnswerState();
}

class _EditAnswerState extends State<_EditAnswer> {
  late final _controller = TextEditingController(text: widget.answer.answer);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Edit answer',
      subtitle: widget.answer.question,
      submitLabel: 'Save answer',
      onSubmit: () {
        final text = _controller.text.trim();
        if (text.isNotEmpty) Navigator.of(context).pop(text);
      },
      children: [
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 10,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
