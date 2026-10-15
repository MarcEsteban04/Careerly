import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../data/career_profile.dart';

/// Edits the career profile that powers job search and match scores.
/// Resolves to true when saved.
Future<bool> showCareerProfileSheet(
  BuildContext context, {
  required CareerProfile initial,
  required Future<void> Function(CareerProfile profile) onSave,
}) async {
  final saved = await showFormSheet<bool>(
    context,
    child: _CareerProfileForm(initial: initial, onSave: onSave),
  );
  return saved ?? false;
}

class _CareerProfileForm extends StatefulWidget {
  const _CareerProfileForm({required this.initial, required this.onSave});

  final CareerProfile initial;
  final Future<void> Function(CareerProfile profile) onSave;

  @override
  State<_CareerProfileForm> createState() => _CareerProfileFormState();
}

class _CareerProfileFormState extends State<_CareerProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _rolesController =
      TextEditingController(text: widget.initial.targetRoles.join(', '));
  late final _skillsController =
      TextEditingController(text: widget.initial.skills.join(', '));
  late final _yearsController = TextEditingController(
    text: widget.initial.yearsOfExperience?.toString() ?? '',
  );
  late final _locationController =
      TextEditingController(text: widget.initial.location ?? '');
  late WorkSetup _workSetup = widget.initial.workSetup;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _rolesController.dispose();
    _skillsController.dispose();
    _yearsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  static List<String> _split(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final location = _locationController.text.trim();
    try {
      await widget.onSave(
        CareerProfile(
          targetRoles: _split(_rolesController.text),
          skills: _split(_skillsController.text),
          yearsOfExperience: int.tryParse(_yearsController.text),
          location: location.isEmpty ? null : location,
          workSetup: _workSetup,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = friendlyErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'Career profile',
        subtitle: 'Used to search for jobs and score how well each one fits.',
        submitLabel: 'Save profile',
        isSubmitting: _isSaving,
        errorMessage: _errorMessage,
        onSubmit: _submit,
        children: [
          LabeledField(
            label: 'Roles you want',
            child: TextFormField(
              controller: _rolesController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. UI Designer, Product Designer',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
              validator: (v) => _split(v ?? '').isEmpty
                  ? 'Add at least one role you want'
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text('Separate with commas. The first one is searched by default.',
              style: hintStyle),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Skills',
            child: TextFormField(
              controller: _skillsController,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Figma, UX research, HTML, Canva',
                prefixIcon: Icon(Icons.auto_awesome_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Experience',
                  child: TextFormField(
                    controller: _yearsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Years',
                      prefixIcon: Icon(Icons.timeline_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LabeledField(
                  label: 'City',
                  child: TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Manila',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Work setup',
            child: ChoiceChipGroup<WorkSetup>(
              values: WorkSetup.values,
              selected: _workSetup,
              labelOf: (s) => s.label,
              onSelected: (s) => setState(() => _workSetup = s),
            ),
          ),
        ],
      ),
    );
  }
}
