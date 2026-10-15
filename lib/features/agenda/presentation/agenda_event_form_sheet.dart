import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/choice_chip_group.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picker_field.dart';
import '../../applications/data/job_application.dart';
import '../data/agenda_event.dart';
import '../data/agenda_repository.dart';
import 'agenda_event_style.dart';

/// Opens the interview or reminder form: new, or editing [existing]. [applications] populate the
/// optional "related application" picker.
Future<AgendaEvent?> showAgendaEventFormSheet(
  BuildContext context, {
  required AgendaRepository repository,
  required List<JobApplication> applications,
  String? initialApplicationId,
  AgendaEvent? existing,
}) {
  return showFormSheet<AgendaEvent>(
    context,
    child: _AgendaEventForm(
      repository: repository,
      applications: applications,
      initialApplicationId: initialApplicationId,
      existing: existing,
    ),
  );
}

class _AgendaEventForm extends StatefulWidget {
  const _AgendaEventForm({
    required this.repository,
    required this.applications,
    this.initialApplicationId,
    this.existing,
  });

  final AgendaRepository repository;
  final List<JobApplication> applications;
  final String? initialApplicationId;
  final AgendaEvent? existing;

  @override
  State<_AgendaEventForm> createState() => _AgendaEventFormState();
}

class _AgendaEventFormState extends State<_AgendaEventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController =
      TextEditingController(text: widget.existing?.title);

  late AgendaEventKind _kind = widget.existing?.kind ?? AgendaEventKind.interview;
  late DateTime _date =
      widget.existing?.startsAt ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = widget.existing == null
      ? const TimeOfDay(hour: 10, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.startsAt);
  late String? _applicationId =
      widget.existing?.applicationId ?? widget.initialApplicationId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Past items being edited keep their date selectable.
      firstDate: _date.isBefore(now) ? _date : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final existing = widget.existing;
      final event = existing == null
          ? await widget.repository.create(
              kind: _kind,
              title: _titleController.text.trim(),
              startsAt: _startsAt,
              applicationId: _applicationId,
            )
          : await widget.repository.update(
              existing.id,
              kind: _kind,
              title: _titleController.text.trim(),
              startsAt: _startsAt,
              applicationId: _applicationId,
            );
      if (mounted) Navigator.of(context).pop(event);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = friendlyErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final applications = widget.applications;

    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'New interview or reminder',
        subtitle: 'It will show up in your "Up next" agenda.',
        submitLabel: 'Add to agenda',
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onSubmit: _submit,
        children: [
          LabeledField(
            label: 'Type',
            child: ChoiceChipGroup<AgendaEventKind>(
              values: AgendaEventKind.values,
              selected: _kind,
              labelOf: (k) => k.label,
              iconOf: (k) => k.icon,
              onSelected: (k) => setState(() => _kind = k),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Title',
            child: TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: _kind.titleHint,
                prefixIcon: Icon(_kind.icon),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Enter a title' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'When',
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PickerField(
                    icon: Icons.calendar_today_outlined,
                    value: DateFormat('EEE, MMM d').format(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 2,
                  child: PickerField(
                    icon: Icons.schedule_rounded,
                    value: _time.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ),
          if (applications.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: 'Related application (optional)',
              child: DropdownButtonFormField<String?>(
                initialValue: _applicationId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final application in applications)
                    DropdownMenuItem(
                      value: application.id,
                      child: Text(
                        '${application.company} · ${application.role}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _applicationId = id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
