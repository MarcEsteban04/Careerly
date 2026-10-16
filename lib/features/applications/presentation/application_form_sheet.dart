import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picker_field.dart';
import '../data/applications_repository.dart';
import '../data/job_application.dart';
import 'application_status_style.dart';

/// Details to start a new application with, e.g. read from a shared job
/// post.
class ApplicationPrefill {
  const ApplicationPrefill({
    this.company,
    this.role,
    this.location,
    this.salary,
    this.jobUrl,
    this.source,
    this.jobDescription,
  });

  final String? company;
  final String? role;
  final String? location;
  final String? salary;
  final String? jobUrl;
  final String? source;
  final String? jobDescription;
}

/// Opens the application form: new (optionally from [prefill]), or editing
/// [existing]. [notice] explains a prefill, e.g. that a post couldn't be
/// read. Resolves to the saved application, or null if dismissed.
Future<JobApplication?> showApplicationFormSheet(
  BuildContext context, {
  required ApplicationsRepository repository,
  JobApplication? existing,
  ApplicationPrefill? prefill,
  String? notice,
}) {
  return showFormSheet<JobApplication>(
    context,
    child: _ApplicationForm(
      repository: repository,
      existing: existing,
      prefill: prefill,
      notice: notice,
    ),
  );
}

class _ApplicationForm extends StatefulWidget {
  const _ApplicationForm({
    required this.repository,
    this.existing,
    this.prefill,
    this.notice,
  });

  final ApplicationsRepository repository;
  final JobApplication? existing;
  final ApplicationPrefill? prefill;
  final String? notice;

  @override
  State<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<_ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _companyController = TextEditingController(
    text: widget.existing?.company ?? widget.prefill?.company,
  );
  late final _roleController = TextEditingController(
    text: widget.existing?.role ?? widget.prefill?.role,
  );
  late final _salaryController = TextEditingController(
    text: widget.existing?.salary ?? widget.prefill?.salary,
  );
  late final _locationController = TextEditingController(
    text: widget.existing?.location ?? widget.prefill?.location,
  );
  late final _linkController = TextEditingController(
    text: widget.existing?.jobUrl ?? widget.prefill?.jobUrl,
  );

  // A job found elsewhere usually hasn't been applied to yet.
  late ApplicationStatus _status = widget.existing?.status ??
      (widget.prefill == null
          ? ApplicationStatus.applied
          : ApplicationStatus.saved);
  late DateTime _appliedOn = widget.existing?.appliedOn ?? DateTime.now();

  bool get _isEditing => widget.existing != null;
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
      final existing = widget.existing;
      final appliedOn = _status == ApplicationStatus.saved ? null : _appliedOn;
      final application = existing == null
          ? await widget.repository.create(
              company: _companyController.text.trim(),
              role: _roleController.text.trim(),
              status: _status,
              location: optional(_locationController),
              salary: optional(_salaryController),
              jobUrl: optional(_linkController),
              appliedOn: appliedOn,
              source: widget.prefill?.source,
              jobDescription: widget.prefill?.jobDescription,
            )
          : await widget.repository.updateDetails(
              existing.id,
              ApplicationDetails(
                company: _companyController.text.trim(),
                role: _roleController.text.trim(),
                location: optional(_locationController),
                salary: optional(_salaryController),
                jobUrl: optional(_linkController),
                appliedOn: appliedOn,
              ),
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
        title: _isEditing
            ? 'Edit details'
            : widget.prefill == null
                ? 'New application'
                : 'Track this job',
        subtitle: widget.prefill == null
            ? 'Track a role you saved or applied for.'
            : 'Check the details, then save it to your tracker.',
        submitLabel: 'Save application',
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onSubmit: _submit,
        children: [
          if (widget.notice != null) ...[
            FormBanner(message: widget.notice!, tone: FormBannerTone.info),
            const SizedBox(height: AppSpacing.md),
          ],
          LabeledField(
            label: 'Company',
            child: TextFormField(
              controller: _companyController,
              autofocus: !_isEditing && widget.prefill == null,
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
          // Status changes go through "Update status" so the timeline
          // records them.
          if (!_isEditing)
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
                hintText: 'e.g. ₱30,000/month',
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
