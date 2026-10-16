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
import '../../agenda/data/agenda_event.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/presentation/agenda_event_form_sheet.dart';
import '../../agenda/presentation/widgets/agenda_tile.dart';
import '../../shell/data/workspace_controller.dart';
import '../data/application_event.dart';
import '../data/job_application.dart';
import 'application_form_sheet.dart';
import 'application_status_style.dart';
import 'status_picker_sheet.dart';
import 'widgets/company_avatar.dart';

/// Full view of one application: progress, details, its agenda and notes,
/// with actions to move it along, open the job post or delete it.
class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.controller,
    required this.agenda,
    required this.events,
    required this.onWriteCoverLetter,
    required this.onTailorResume,
    required this.onInterviewPrep,
    required this.onWriteMessage,
    required this.onAtsCheck,
    required this.onApply,
  });

  /// Checks her resume against this job.
  final ValueChanged<JobApplication> onAtsCheck;

  /// Opens the message writer; [followUp] when a follow-up is due.
  final void Function(JobApplication application, {bool followUp})
      onWriteMessage;

  final String applicationId;
  final WorkspaceController controller;
  final AgendaRepository agenda;
  final ValueChanged<JobApplication> onWriteCoverLetter;
  final ValueChanged<JobApplication> onTailorResume;
  final ValueChanged<JobApplication> onInterviewPrep;

  /// Opens the application kit for this job.
  final ValueChanged<JobApplication> onApply;
  final ApplicationEventsRepository events;

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
    final status = await showStatusPicker(
      context,
      current: application.status,
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
      // Many options: size to them and scroll if the screen is short.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit details'),
                onTap: () => Navigator.of(context).pop('edit'),
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
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('ATS check for my resume'),
                onTap: () => Navigator.of(context).pop('ats'),
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Prepare for the interview'),
                onTap: () => Navigator.of(context).pop('prep'),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Write a message'),
                subtitle: const Text('Follow-up, thank-you or offer reply'),
                onTap: () => Navigator.of(context).pop('message'),
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
    if (action == 'ats') widget.onAtsCheck(application);
    if (action == 'prep') widget.onInterviewPrep(application);
    if (action == 'message') widget.onWriteMessage(application);
    if (action == 'edit') await _editDetails(application);
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
                  if (_followUpDue(application)) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ActionCard(
                      icon: Icons.forward_to_inbox_rounded,
                      title: 'Time to follow up',
                      subtitle: 'Careerly can draft a short, friendly email '
                          'for you.',
                      onTap: () =>
                          widget.onWriteMessage(application, followUp: true),
                    ),
                  ],
                  if (application.status == ApplicationStatus.interviewing) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ActionCard(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Prepare for your interview',
                      subtitle: 'Likely questions, answers from your resume, '
                          'and a mock interview.',
                      onTap: () => widget.onInterviewPrep(application),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedTabs(
                    labels: const ['Overview', 'Timeline', 'Agenda', 'Notes'],
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
                            onSetFollowUp: () => _setFollowUp(application),
                            onOpenJobPost: application.jobUrl == null
                                ? null
                                : () => _openJobPost(application.jobUrl!),
                          ),
                        1 => _buildTimeline(application),
                        2 => _buildAgenda(application),
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
        child: Row(
          children: [
            if (application.jobUrl != null && !application.isApplied) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onApply(application),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Apply'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Update status',
                icon: Icons.swap_vert_rounded,
                isLoading: _isUpdating,
                onPressed: () => _changeStatus(application),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDetails(JobApplication application) async {
    final updated = await showApplicationFormSheet(
      context,
      repository: widget.controller.applications,
      existing: application,
    );
    if (updated == null || !mounted) return;
    widget.controller.replaceApplication(updated);
    _showMessage('Details updated');
  }

  /// Sets (or clears) the follow-up date and adds a reminder for it.
  Future<void> _setFollowUp(JobApplication application) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Follow up on',
      initialDate: application.followUpOn ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    try {
      final updated =
          await widget.controller.applications.setFollowUp(application.id, picked);
      await widget.agenda.create(
        kind: AgendaEventKind.followUp,
        title: 'Follow up with ${application.company}',
        startsAt: DateTime(picked.year, picked.month, picked.day, 10),
        applicationId: application.id,
      );
      widget.controller.replaceApplication(updated);
      await widget.controller.load();
      _showMessage('Follow-up set for ${DateFormat('EEE, MMM d').format(picked)}');
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    }
  }

  Widget _buildTimeline(JobApplication application) {
    return FutureBuilder<List<ApplicationEvent>>(
      // Refetch whenever the application changes (e.g. a new status).
      key: ValueKey(application.updatedAt),
      future: widget.events.fetchFor(application.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.history_rounded,
              title: 'Timeline unavailable',
              message: isMissingSchemaError(error)
                  ? 'Run the latest database migration to record status '
                      'history.'
                  : friendlyErrorMessage(error),
            ),
          );
        }
        final events = snapshot.data ?? const [];
        if (events.isEmpty) {
          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: const EmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Status changes from now on appear here.',
            ),
          );
        }
        return _Timeline(events: events);
      },
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

/// Whether the follow-up date has come for an application still waiting.
bool _followUpDue(JobApplication application) {
  final due = application.followUpOn;
  if (due == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return !due.isAfter(today) &&
      (application.status == ApplicationStatus.applied ||
          application.status == ApplicationStatus.interviewing);
}

/// A highlighted next step, e.g. interview prep or a due follow-up.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      color: colorScheme.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
        ],
      ),
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
  const _Overview({
    required this.application,
    required this.onOpenJobPost,
    required this.onSetFollowUp,
  });

  final JobApplication application;
  final VoidCallback? onOpenJobPost;
  final VoidCallback onSetFollowUp;

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
        if (application.source != null)
          _DetailRow(
            icon: Icons.travel_explore_rounded,
            label: 'Found via',
            value: application.source!,
          ),
        InkWell(
          onTap: onSetFollowUp,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Row(
            children: [
              Expanded(
                child: _DetailRow(
                  icon: Icons.notifications_active_outlined,
                  label: 'Follow up',
                  value: application.followUpOn == null
                      ? 'Set a date'
                      : dateFormat.format(application.followUpOn!),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (application.jobDescription != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Job posting', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          _ExpandableText(application.jobDescription!),
        ],
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

/// Vertical timeline of an application's history, newest first.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<ApplicationEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final format = DateFormat('MMM d, y · h:mm a');

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? (events[i].toStatus?.colorIn(theme) ??
                                  colorScheme.primary)
                              : colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: events[i].toStatus?.colorIn(theme) ??
                                colorScheme.outline,
                            width: 2,
                          ),
                        ),
                      ),
                      if (i < events.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          events[i].description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: i == 0 ? FontWeight.w600 : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          format.format(events[i].createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final long = widget.text.length > 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: !long || _expanded ? null : 6,
          overflow: !long || _expanded ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}
