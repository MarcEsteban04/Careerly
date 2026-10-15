import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picker_field.dart';
import '../data/applications_repository.dart';
import '../data/job_application.dart';
import 'application_status_style.dart';

/// Opens the "new application" form. Resolves to the created application, or
/// null if dismissed.
Future<JobApplication?> showApplicationFormSheet(
  BuildContext context, {
  required ApplicationsRepository repository,
}) {
  return showFormSheet<JobApplication>(
    context,
    child: _ApplicationForm(repository: repository),
  );
}

class _ApplicationForm extends StatefulWidget {
  const _ApplicationForm({required this.repository});

  final ApplicationsRepository repository;

  @override
  State<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<_ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _salaryController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkController = TextEditingController();

  ApplicationStatus _status = ApplicationStatus.applied;
  DateTime _appliedOn = DateTime.now();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _salaryController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _appliedOn,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _appliedOn = picked);
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    try {
      final application = await widget.repository.create(
        company: _companyController.text.trim(),
        role: _roleController.text.trim(),
        status: _status,
        location: optional(_locationController),
        salary: optional(_salaryController),
        jobUrl: optional(_linkController),
        appliedOn: _status == ApplicationStatus.saved ? null : _appliedOn,
      );
      if (mounted) Navigator.of(context).pop(application);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = friendlyErrorMessage(error);
        });
      }
    }
  }

  static String? _required(String? value, String message) =>
      (value?.trim() ?? '').isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'New application',
        subtitle: 'Track a role you saved or applied for.',
        submitLabel: 'Save application',
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onSubmit: _submit,
        children: [
          LabeledField(
            label: 'Company',
            child: TextFormField(
              controller: _companyController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Acme Inc.',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (v) => _required(v, 'Enter the company'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Role',
            child: TextFormField(
              controller: _roleController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Product Designer',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
              validator: (v) => _required(v, 'Enter the role'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Status',
            child: ChoiceChipGroup<ApplicationStatus>(
              values: ApplicationStatus.values,
              selected: _status,
              labelOf: (s) => s.label,
              iconOf: (s) => s.icon,
              onSelected: (s) => setState(() => _status = s),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _status == ApplicationStatus.saved
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: LabeledField(
                      label: 'Applied on',
                      child: PickerField(
                        icon: Icons.calendar_today_outlined,
                        value: DateFormat('EEEE, MMM d, y').format(_appliedOn),
                        onTap: _pickDate,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Salary (optional)',
            child: TextFormField(
              controller: _salaryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: r'e.g. $4,000/month',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Location (optional)',
            child: TextFormField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Remote, Manila',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Job link (optional)',
            child: TextFormField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'https://',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}
