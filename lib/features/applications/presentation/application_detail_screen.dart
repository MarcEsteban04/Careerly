import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/tag_pill.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../agenda/presentation/widgets/agenda_tile.dart';
import '../../shell/data/workspace_controller.dart';
import '../data/job_application.dart';
import 'application_status_style.dart';
import 'widgets/company_avatar.dart';

/// Full view of one application: progress, details, its agenda and notes,
/// with actions to move it along, open the job post or delete it.
class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.controller,
    required this.agenda,
    required this.onWriteCoverLetter,
    required this.onTailorResume,
  });

  final String applicationId;
  final WorkspaceController controller;
  final AgendaRepository agenda;
  final ValueChanged<JobApplication> onWriteCoverLetter;
  final ValueChanged<JobApplication> onTailorResume;

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  int _tab = 0;
  bool _isUpdating = false;
  late final _notesController = TextEditingController(
    text: _application?.notes ?? '',
  );
  bool _isSavingNotes = false;

  JobApplication? get _application =>
      widget.controller.data?.applicationById(widget.applicationId);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeStatus(JobApplication application) async {
    final status = await showModalBottomSheet<ApplicationStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => _StatusSheet(current: application.status),
    );
    if (status == null || status == application.status || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      final updated = await widget.controller.applications
          .updateStatus(application, status);
      widget.controller.replaceApplication(updated);
      HapticFeedback.lightImpact();
      _showMessage('Moved to ${status.label}');
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _saveNotes(JobApplication application) async {
    FocusScope.of(context).unfocus();
    setState(() => _isSavingNotes = true);
    try {
      final updated = await widget.controller.applications
          .updateNotes(application.id, _notesController.text);
      widget.controller.replaceApplication(updated);
      _showMessage('Notes saved');
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
  }

  Future<void> _openJobPost(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showMessage("Couldn't open that link.");
  }

  Future<void> _addAgendaItem(JobApplication application) async {
    final created = await showAgendaEventFormSheet(
      context,
      repository: widget.agenda,
      applications: widget.controller.data?.applications ?? const [],
      initialApplicationId: application.id,
    );
    if (created == null) return;
    _showMessage('Added to your agenda');
    await widget.controller.load();
  }

  Future<void> _confirmDelete(JobApplication application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete application?'),
        content: Text(
          '${application.role} at ${application.company} will be removed. '
          'Linked agenda items stay but lose the link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await widget.controller.deleteApplication(application.id);
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${application.role}')),
      );
    }
  }

  Future<void> _showMore(JobApplication application) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (application.jobUrl != null)
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('Open job post'),
                  onTap: () => Navigator.of(context).pop('open'),
                ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Write a cover letter'),
                onTap: () => Navigator.of(context).pop('letter'),
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_high_rounded),
                title: const Text('Tailor my resume to this job'),
                onTap: () => Navigator.of(context).pop('tailor'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete application',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'open') await _openJobPost(application.jobUrl!);
    if (action == 'letter') widget.onWriteCoverLetter(application);
    if (action == 'tailor') widget.onTailorResume(application);
    if (action == 'delete') await _confirmDelete(application);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final application = _application;
        if (application == null) {
          // Deleted or not loaded; the pop after delete handles navigation.
          return const Scaffold(body: SizedBox.shrink());
        }
        return _buildScreen(context, application);
      },
    );
  }

  Widget _buildScreen(BuildContext context, JobApplication application) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Application',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.more_horiz_rounded,
                    tooltip: 'More',
                    onPressed: () => _showMore(application),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  120 + bottomInset,
                ),
                children: [
                  _Header(application: application),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedTabs(
                    labels: const ['Overview', 'Agenda', 'Notes'],
                    selectedIndex: _tab,
                    onSelected: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        0 => _Overview(
                            application: application,
                            onOpenJobPost: application.jobUrl == null
                                ? null
                                : () => _openJobPost(application.jobUrl!),
                          ),
                        1 => _buildAgenda(application),
                        _ => _buildNotes(application),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: colorScheme.surface,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm + bottomInset,
        ),
        child: PrimaryButton(
          label: 'Update status',
          icon: Icons.swap_vert_rounded,
          isLoading: _isUpdating,
          onPressed: () => _changeStatus(application),
        ),
      ),
    );
  }

  Widget _buildAgenda(JobApplication application) {
    final events = widget.controller.data?.upcoming
            .where((e) => e.applicationId == application.id)
            .toList() ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: events.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing scheduled',
                    message: 'Add interviews, follow-ups or deadlines for '
                        'this role.',
                  ),
                )
              : Column(
                  children: [
                    for (final event in events)
                      AgendaTile(
                        event: event,
                        onToggleDone: (done) async {
                          final error = await widget.controller
                              .setEventDone(event.id, isDone: done);
                          if (error != null) _showMessage(error);
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _addAgendaItem(application),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add interview or reminder'),
        ),
      ],
    );
  }

  Widget _buildNotes(JobApplication application) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notesController,
          minLines: 6,
          maxLines: 14,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Recruiter names, interview prep, questions to ask…',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _isSavingNotes ? null : () => _saveNotes(application),
          icon: _isSavingNotes
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Save notes'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.application});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = [
      application.company,
      if (application.location != null) application.location!,
    ].join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CompanyAvatar(company: application.company, size: 56),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.role,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            TagPill(
              label: application.status.label,
              leading: StatusDot(color: application.status.colorIn(theme)),
            ),
            if (application.salary != null)
              TagPill(label: application.salary!),
            if (application.appliedOn != null)
              TagPill(
                label:
                    'Applied ${DateFormat('MMM d').format(application.appliedOn!)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.application, required this.onOpenJobPost});

  final JobApplication application;
  final VoidCallback? onOpenJobPost;

  static const _stages = [
    ApplicationStatus.saved,
    ApplicationStatus.applied,
    ApplicationStatus.interviewing,
    ApplicationStatus.offer,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rejected = application.status == ApplicationStatus.rejected;
    final reached = rejected ? -1 : _stages.indexOf(application.status);
    final dateFormat = DateFormat('EEEE, MMM d, y');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (rejected)
          Text(
            'This application is closed.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else
          Row(
            children: [
              for (var i = 0; i < _stages.length; i++) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= reached
                              ? _stages[reached].colorIn(theme)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _stages[i].shortLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: i == reached
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight:
                              i == reached ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _stages.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Details', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        _DetailRow(
          icon: Icons.flag_outlined,
          label: 'Status',
          value: application.status.label,
        ),
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Applied on',
          value: application.appliedOn == null
              ? 'Not yet'
              : dateFormat.format(application.appliedOn!),
        ),
        _DetailRow(
          icon: Icons.place_outlined,
          label: 'Location',
          value: application.location ?? '—',
        ),
        _DetailRow(
          icon: Icons.payments_outlined,
          label: 'Salary',
          value: application.salary ?? '—',
        ),
        _DetailRow(
          icon: Icons.history_rounded,
          label: 'Added',
          value: dateFormat.format(application.createdAt),
        ),
        if (onOpenJobPost != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onOpenJobPost,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open job post'),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.current});

  final ApplicationStatus current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Text(
                'Move to…',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final status in ApplicationStatus.values)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                leading: Icon(status.icon, color: status.colorIn(theme)),
                title: Text(status.label),
                trailing: status == current
                    ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(status),
              ),
          ],
        ),
      ),
    );
  }
}
