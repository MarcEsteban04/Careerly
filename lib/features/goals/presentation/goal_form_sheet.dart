import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../data/goal.dart';
import '../data/goals_repository.dart';

/// Opens the "new goal" form. Resolves to the created goal, or null.
Future<Goal?> showGoalFormSheet(
  BuildContext context, {
  required GoalsRepository repository,
}) {
  return showFormSheet<Goal>(
    context,
    child: _GoalForm(repository: repository),
  );
}

typedef _Suggestion = ({String title, int target, GoalPeriod period});

class _GoalForm extends StatefulWidget {
  const _GoalForm({required this.repository});

  final GoalsRepository repository;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  static const List<_Suggestion> _suggestions = [
    (title: 'Apply to jobs', target: 5, period: GoalPeriod.weekly),
    (title: 'Reach out to recruiters', target: 3, period: GoalPeriod.weekly),
    (title: 'Practice interviews', target: 2, period: GoalPeriod.weekly),
    (title: 'Finish a portfolio project', target: 1, period: GoalPeriod.monthly),
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController(text: '5');

  GoalPeriod _period = GoalPeriod.weekly;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _apply(_Suggestion suggestion) {
    setState(() {
      _titleController.text = suggestion.title;
      _targetController.text = '${suggestion.target}';
      _period = suggestion.period;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final goal = await widget.repository.create(
        title: _titleController.text.trim(),
        target: int.parse(_targetController.text),
        period: _period,
      );
      if (mounted) Navigator.of(context).pop(goal);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = friendlyErrorMessage(error);
        });
      }
    }
  }

  static String? _validateTarget(String? value) {
    final target = int.tryParse(value ?? '');
    if (target == null || target < 1) return 'Enter a number above 0';
    if (target > 10000) return 'Keep it under 10,000';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'New goal',
        subtitle: 'Small, regular targets keep the search moving.',
        submitLabel: 'Create goal',
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onSubmit: _submit,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final suggestion in _suggestions)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: Text(suggestion.title),
                  onPressed: () => _apply(suggestion),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LabeledField(
            label: 'Goal',
            child: TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Apply to jobs',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Name your goal' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Target',
            child: TextFormField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'How many?',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              validator: _validateTarget,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Timeframe',
            child: ChoiceChipGroup<GoalPeriod>(
              values: GoalPeriod.values,
              selected: _period,
              labelOf: (p) => p.label,
              onSelected: (p) => setState(() => _period = p),
            ),
          ),
        ],
      ),
    );
  }
}
