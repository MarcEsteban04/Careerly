import 'package:flutter/material.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/form_field_info.dart';

/// Shows the proposed answers before anything touches the page. Each can
/// be edited or left out; resolves to the answers to fill, or null.
Future<List<FieldAnswer>?> showFillReviewSheet(
  BuildContext context, {
  required List<FieldAnswer> answers,
  required int leftForYou,
  required bool detailsMissing,
  required VoidCallback onAddDetails,
}) {
  return showModalBottomSheet<List<FieldAnswer>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FillReview(
      answers: answers,
      leftForYou: leftForYou,
      detailsMissing: detailsMissing,
      onAddDetails: onAddDetails,
    ),
  );
}

class _FillReview extends StatefulWidget {
  const _FillReview({
    required this.answers,
    required this.leftForYou,
    required this.detailsMissing,
    required this.onAddDetails,
  });

  final List<FieldAnswer> answers;
  final int leftForYou;
  final bool detailsMissing;
  final VoidCallback onAddDetails;

  @override
  State<_FillReview> createState() => _FillReviewState();
}

class _FillReviewState extends State<_FillReview> {
  late final _included = {for (final a in widget.answers) a.field.id: true};
  late final _controllers = {
    for (final a in widget.answers)
      if (!a.field.kind.hasOptions)
        a.field.id: TextEditingController(text: a.value),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<FieldAnswer> get _chosen => [
        for (final a in widget.answers)
          if (_included[a.field.id]!)
            _controllers[a.field.id] == null
                ? a
                : a.withValue(_controllers[a.field.id]!.text.trim()),
      ].where((a) => a.value.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = _chosen.length;
    final drafted =
        widget.answers.where((a) => a.source == AnswerSource.ai).length;
    final reused =
        widget.answers.where((a) => a.source == AnswerSource.library).length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check before filling',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    '${widget.answers.length} answers ready',
                    if (reused > 0) '$reused saved',
                    if (drafted > 0) '$drafted drafted by AI',
                    if (widget.leftForYou > 0) '${widget.leftForYou} left for you',
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (widget.detailsMissing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormBanner(
                    tone: FormBannerTone.info,
                    message: 'Add your application details (phone, links, '
                        'school) so Careerly can fill more of the form.',
                  ),
                  TextButton(
                    onPressed: widget.onAddDetails,
                    child: const Text('Add application details'),
                  ),
                ],
              ),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: widget.answers.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _AnswerTile(
                answer: widget.answers[i],
                included: _included[widget.answers[i].field.id]!,
                controller: _controllers[widget.answers[i].field.id],
                onIncluded: (value) => setState(
                  () => _included[widget.answers[i].field.id] = value,
                ),
                onEdited: () => setState(() {}),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: count == 1 ? 'Fill 1 field' : 'Fill $count fields',
                  icon: Icons.auto_awesome_rounded,
                  onPressed:
                      count == 0 ? null : () => Navigator.of(context).pop(_chosen),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Careerly fills the page but never submits it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.included,
    required this.controller,
    required this.onIncluded,
    required this.onEdited,
  });

  final FieldAnswer answer;
  final bool included;

  /// Null for select and radio answers, which aren't free text.
  final TextEditingController? controller;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final long = answer.field.kind == FormFieldKind.textarea;

    return Opacity(
      opacity: included ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    answer.field.displayLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                if (answer.source != AnswerSource.details)
                  _SourceBadge(source: answer.source),
                Checkbox(
                  value: included,
                  semanticLabel: 'Fill "${answer.field.displayLabel}"',
                  onChanged: (value) => onIncluded(value ?? false),
                ),
              ],
            ),
            if (controller == null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  answer.value,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TextField(
                  controller: controller,
                  enabled: included,
                  minLines: 1,
                  maxLines: long ? 8 : 2,
                  maxLength: answer.field.maxLength,
                  onChanged: (_) => onEdited(),
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "AI draft" or "Saved answer", so she knows what to read closely.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final AnswerSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = source == AnswerSource.ai ? Accent.teal : Accent.violet;

    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.tintIn(theme.brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        source == AnswerSource.ai ? 'AI draft' : 'Saved answer',
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent.colorIn(theme.brightness),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
