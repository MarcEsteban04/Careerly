import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../applications/data/job_application.dart';
import '../../applications/presentation/widgets/company_avatar.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/widgets/generator_scaffold.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/interview_coach.dart';
import '../data/interview_prep.dart';
import '../data/interview_prep_repository.dart';

/// AI interview kit for one application: company brief, what they'll look
/// for, likely questions with practice answers, questions to ask, tips.
/// Opens the saved kit, or builds one right away if there isn't one.
class InterviewPrepScreen extends StatefulWidget {
  const InterviewPrepScreen({
    super.key,
    required this.application,
    required this.coach,
    required this.repository,
    required this.profile,
    required this.resumeText,
    required this.onUploadResume,
    this.interviewAt,
  });

  final JobApplication application;
  final InterviewCoach coach;
  final InterviewPrepRepository repository;
  final CareerProfile Function() profile;

  /// The uploaded resume's text, or null if there's none.
  final Future<String?> Function() resumeText;
  final Future<void> Function() onUploadResume;

  /// When the interview is, if it's on the agenda.
  final DateTime? interviewAt;

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  InterviewPrep? _prep;
  bool _isLoadingSaved = true;
  bool _isWorking = false;
  bool _hasResume = true;
  String? _error;

  /// Set when the kit couldn't be stored, e.g. the table is missing.
  String? _saveNotice;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    InterviewPrep? saved;
    try {
      saved = await widget.repository.fetch(widget.application.id);
    } catch (e) {
      debugPrint('Interview prep unavailable: $e');
    }
    if (!mounted) return;
    setState(() {
      _prep = saved;
      _isLoadingSaved = false;
    });
    if (saved == null) _generate();
  }

  Future<void> _generate() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      final resume = await widget.resumeText();
      final application = widget.application;
      final prep = await widget.coach.prepare(
        job: JobContext(
          title: application.role,
          company: application.company,
          location: application.location,
          description: application.jobDescription,
          applicationId: application.id,
        ),
        profile: widget.profile(),
        resumeText: resume,
      );
      if (!mounted) return;
      setState(() {
        _prep = prep;
        _hasResume = resume != null;
      });
      await _save(prep);
    } catch (error) {
      if (mounted) setState(() => _error = writerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _save(InterviewPrep prep) async {
    String? notice;
    try {
      await widget.repository.save(widget.application.id, prep);
    } catch (error) {
      notice = isMissingSchemaError(error)
          ? 'Run the latest database migration to keep this kit for next '
              'time.'
          : "Couldn't save this kit. It stays here until you leave.";
    }
    if (mounted) setState(() => _saveNotice = notice);
  }

  Future<void> _uploadResume() async {
    await widget.onUploadResume();
    if (!mounted) return;
    final resume = await widget.resumeText();
    if (mounted && resume != null) {
      setState(() => _hasResume = true);
      _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final prep = _prep;

    return GeneratorScaffold(
      title: 'Interview prep',
      headline: 'Get ready for **${application.company}**',
      subtitle: '${application.role}. Likely questions, answers from your '
          'resume, and what to ask them.',
      actionLabel: prep == null ? 'Prepare me' : 'Make a fresh kit',
      onAction: _isLoadingSaved ? null : _generate,
      isWorking: _isWorking,
      errorMessage: _error,
      workingMessages: [
        'Looking up ${application.company}…',
        'Reading the job post…',
        'Picking questions they\'re likely to ask…',
        'Drafting answers from your resume…',
      ],
      children: [
        _JobCard(application: application, interviewAt: widget.interviewAt),
        if (!_hasResume) ...[
          const SizedBox(height: AppSpacing.sm),
          _ResumeNudge(onUpload: _uploadResume),
        ],
        if (_saveNotice != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FormBanner(message: _saveNotice!, tone: FormBannerTone.info),
        ],
        if (_isLoadingSaved)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (prep != null && !_isWorking) _PrepContent(prep: prep),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.application, this.interviewAt});

  final JobApplication application;
  final DateTime? interviewAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final at = interviewAt;

    return AppCard(
      child: Row(
        children: [
          CompanyAvatar(company: application.company),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.role,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      at == null
                          ? Icons.event_busy_outlined
                          : Icons.event_available_rounded,
                      size: 16,
                      color: at == null
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        at == null
                            ? 'No interview on your agenda yet'
                            : 'Interview ${DateFormat('EEE, MMM d · h:mm a').format(at)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: at == null
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.primary,
                          fontWeight: at == null ? null : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeNudge extends StatelessWidget {
  const _ResumeNudge({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Add your resume so answers use your real experience.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onUpload, child: const Text('Upload')),
        ],
      ),
    );
  }
}

class _PrepContent extends StatefulWidget {
  const _PrepContent({required this.prep});

  final InterviewPrep prep;

  @override
  State<_PrepContent> createState() => _PrepContentState();
}

class _PrepContentState extends State<_PrepContent> {
  QuestionCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prep = widget.prep;
    final categories = {for (final q in prep.questions) q.category};
    final questions = [
      for (final q in prep.questions)
        if (_filter == null || q.category == _filter) q,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prep.companyBrief.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'About the company'),
          AppCard(
            child: Text(prep.companyBrief, style: theme.textTheme.bodyMedium),
          ),
        ],
        if (prep.focusAreas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: "What they'll look for"),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final area in prep.focusAreas)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    area,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Likely questions (${prep.questions.length})'),
        if (categories.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PillChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final category in QuestionCategory.values)
                  if (categories.contains(category)) ...[
                    const SizedBox(width: AppSpacing.xs),
                    PillChip(
                      label: category.label,
                      selected: _filter == category,
                      onTap: () => setState(() => _filter = category),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final (i, question) in questions.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _QuestionCard(
            key: ValueKey(question.question),
            number: prep.questions.indexOf(question) + 1,
            question: question,
          ),
        ],
        if (prep.questionsToAsk.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Questions to ask them'),
          _ListCard(items: prep.questionsToAsk, numbered: true),
        ],
        if (prep.tips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Tips'),
          _ListCard(items: prep.tips),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'Made by ${prep.provider} · '
          '${DateFormat('MMM d, h:mm a').format(prep.createdAt)}. '
          'Check company facts before the interview.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A question with its suggested answer hidden, so it can be practiced.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.number,
    required this.question,
  });

  final int number;
  final InterviewQuestion question;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final question = widget.question;

    return AppCard(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Q${widget.number}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  question.category.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            question.question,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (question.why != null && question.why!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              question.why!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _showAnswer
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      question.answer,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                _showAnswer
                    ? Icons.visibility_off_outlined
                    : Icons.lightbulb_outline_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _showAnswer ? 'Hide answer' : 'Try it, then show answer',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.items, this.numbered = false});

  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: numbered
                      ? Text(
                          '${i + 1}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: colorScheme.primary,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(item, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
