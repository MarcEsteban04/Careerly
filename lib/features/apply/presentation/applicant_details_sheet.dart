import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picker_field.dart';
import '../data/applicant_details.dart';

/// Edits the details application forms ask for. Resolves to the saved
/// details, or null if closed without saving.
Future<ApplicantDetails?> showApplicantDetailsSheet(
  BuildContext context, {
  required ApplicantDetailsStore store,
}) {
  return showFormSheet<ApplicantDetails>(
    context,
    child: _DetailsForm(store: store),
  );
}

class _DetailsForm extends StatefulWidget {
  const _DetailsForm({required this.store});

  final ApplicantDetailsStore store;

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _linkedin = TextEditingController();
  final _portfolio = TextEditingController();
  final _github = TextEditingController();
  final _salary = TextEditingController();
  final _availability = TextEditingController();
  final _school = TextEditingController();
  final _degree = TextEditingController();
  final _graduationYear = TextEditingController();
  final _other = TextEditingController();
  DateTime? _birthday;
  bool _loaded = false;
  bool _isSaving = false;
  String? _error;

  List<TextEditingController> get _all => [
        _phone,
        _address,
        _city,
        _linkedin,
        _portfolio,
        _github,
        _salary,
        _availability,
        _school,
        _degree,
        _graduationYear,
        _other,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _phone.text = d.phone ?? '';
      _address.text = d.address ?? '';
      _city.text = d.city ?? '';
      _linkedin.text = d.linkedin ?? '';
      _portfolio.text = d.portfolio ?? '';
      _github.text = d.github ?? '';
      _salary.text = d.expectedSalary ?? '';
      _availability.text = d.availability ?? '';
      _school.text = d.school ?? '';
      _degree.text = d.degree ?? '';
      _graduationYear.text = d.graduationYear ?? '';
      _other.text = d.other ?? '';
      _birthday = d.birthday == null ? null : DateTime.tryParse(d.birthday!);
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Birthday',
      initialDate: _birthday ?? DateTime(now.year - 22),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 15),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final details = ApplicantDetails(
      phone: text(_phone),
      address: text(_address),
      city: text(_city),
      birthday: _birthday == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_birthday!),
      linkedin: text(_linkedin),
      portfolio: text(_portfolio),
      github: text(_github),
      expectedSalary: text(_salary),
      availability: text(_availability),
      school: text(_school),
      degree: text(_degree),
      graduationYear: text(_graduationYear),
      other: text(_other),
    );
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.store.save(details);
      if (mounted) Navigator.of(context).pop(details);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = friendlyErrorMessage(error);
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: LabeledField(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            minLines: 1,
            maxLines: maxLines,
            textInputAction:
                maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
          ),
        ),
      );

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Application details',
      subtitle: 'Careerly uses these to fill in job application forms. '
          'They stay on this phone.',
      submitLabel: 'Save details',
      isSubmitting: _isSaving,
      errorMessage: _error,
      onSubmit: _loaded ? _save : () {},
      children: [
        _group('Contact'),
        _field('Mobile number', _phone,
            hint: 'e.g. 0917 123 4567',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone),
        _field('Address', _address,
            hint: 'Street, barangay', icon: Icons.home_outlined),
        _field('City', _city,
            hint: 'e.g. Malolos, Bulacan', icon: Icons.location_city_outlined),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: LabeledField(
            label: 'Birthday',
            child: PickerField(
              icon: Icons.cake_outlined,
              value: _birthday == null
                  ? 'Not set'
                  : DateFormat('MMMM d, y').format(_birthday!),
              onTap: _pickBirthday,
            ),
          ),
        ),
        _group('Links'),
        _field('LinkedIn', _linkedin,
            hint: 'linkedin.com/in/…',
            icon: Icons.link_rounded,
            keyboard: TextInputType.url),
        _field('Portfolio or website', _portfolio,
            hint: 'https://…',
            icon: Icons.language_rounded,
            keyboard: TextInputType.url),
        _field('GitHub', _github,
            hint: 'github.com/…',
            icon: Icons.code_rounded,
            keyboard: TextInputType.url),
        _group('Work'),
        _field('Expected salary', _salary,
            hint: 'e.g. ₱50,000 a month', icon: Icons.payments_outlined),
        _field('Availability', _availability,
            hint: 'e.g. Immediately, or 2 weeks after an offer',
            icon: Icons.event_available_outlined),
        _group('Education'),
        _field('School', _school,
            hint: 'e.g. Bulacan State University', icon: Icons.school_outlined),
        _field('Degree', _degree,
            hint: 'e.g. BS Information Technology',
            icon: Icons.workspace_premium_outlined),
        _field('Graduation year', _graduationYear,
            hint: 'e.g. 2026',
            icon: Icons.calendar_today_outlined,
            keyboard: TextInputType.number),
        _group('Anything else'),
        _field('Other details', _other,
            hint: 'e.g. Willing to relocate: Yes. Has a laptop and stable internet.',
            icon: Icons.notes_rounded,
            maxLines: 4),
      ],
    );
  }
}
