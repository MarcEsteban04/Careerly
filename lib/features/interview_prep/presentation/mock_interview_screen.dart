import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/interview_coach.dart';
import '../data/interview_prep.dart';
import '../data/voice_input.dart';

/// Practice round: five likely questions, one at a time. She answers by
/// typing or speaking, gets scored feedback with a stronger answer, then
/// a summary at the end.
class MockInterviewScreen extends StatefulWidget {
  const MockInterviewScreen({
    super.key,
    required this.job,
    required this.prep,
    required this.coach,
    required this.resumeText,
    this.voice,
  });

  final JobContext job;
  final InterviewPrep prep;
  final InterviewCoach coach;

  /// The uploaded resume's text, or null if there's none.
  final Future<String?> Function() resumeText;

  /// Dictation; built on first use when null.
  final VoiceInput? voice;

  static const rounds = 5;

  /// Up to [rounds] questions, one of each kind first so practice covers
  /// behavioral, role and company questions.
  static List<InterviewQuestion> pickQuestions(List<InterviewQuestion> all) {
    final picked = <InterviewQuestion>[];
    for (final category in QuestionCategory.values) {
      final first = all.where((q) => q.category == category).firstOrNull;
      if (first != null) picked.add(first);
    }
    for (final question in all) {
      if (picked.length >= rounds) break;
      if (!picked.contains(question)) picked.add(question);
    }
    final order = {for (final (i, q) in all.indexed) q: i};
    return (picked.take(rounds).toList()
      ..sort((a, b) => order[a]!.compareTo(order[b]!)));
  }

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  late final _questions = MockInterviewScreen.pickQuestions(widget.prep.questions);
  late final VoiceInput _voice = widget.voice ?? VoiceInput();
  final _answer = TextEditingController();
  final _scores = <int>[];

  int _index = 0;
  AnswerFeedback? _feedback;
  bool _isReviewing = false;
  bool _isListening = false;
  bool _done = false;
  String? _error;

  /// Text typed before dictation started, so speech appends to it.
  String _beforeDictation = '';

  InterviewQuestion get _question => _questions[_index];

  @override
  void dispose() {
    if (_isListening) _voice.stop();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voice.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    _beforeDictation = _answer.text.trim();
    final started = await _voice.start(
      onWords: (words) {
        if (!mounted) return;
        _answer.text =
            [_beforeDictation, words].where((s) => s.isNotEmpty).join(' ');
        _answer.selection =
            TextSelection.collapsed(offset: _answer.text.length);
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    if (started) {
      HapticFeedback.selectionClick();
      setState(() => _isListening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Voice input isn't available. Allow the microphone, or type "
            'your answer.',
          ),
        ),
      );
    }
  }

  Future<void> _review() async {
    if (_isListening) {
      await _voice.stop();
      _isListening = false;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isReviewing = true;
      _error = null;
    });
    try {
      final feedback = await widget.coach.reviewAnswer(
        job: widget.job,
        question: _question,
        answer: _answer.text,
        resumeText: await widget.resumeText(),
      );
      if (!mounted) return;
      setState(() => _feedback = feedback);
    } catch (error) {
      if (mounted) setState(() => _error = writerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isReviewing = false);
    }
  }

  void _retry() => setState(() {
        _feedback = null;
        _answer.clear();
      });

  void _next() {
    _scores.add(_feedback!.score);
    setState(() {
      _feedback = null;
      _answer.clear();
      if (_index + 1 < _questions.length) {
        _index++;
      } else {
        _done = true;
      }
    });
  }

  void _restart() => setState(() {
        _scores.clear();
        _index = 0;
        _done = false;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    icon: Icons.close_rounded,
                    tooltip: 'End practice',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Mock interview',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: _done
                        ? null
                        : Text(
                            '${_index + 1}/${_questions.length}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (!_done)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_index + (_feedback == null ? 0 : 1)) /
                        _questions.length,
                    minHeight: 6,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: _done ? [_Summary(questions: _questions, scores: _scores)] : [
                  _QuestionCard(question: _question),
                  const SizedBox(height: AppSpacing.md),
                  if (_feedback == null) ...[
                    _AnswerField(
                      controller: _answer,
                      enabled: !_isReviewing,
                      isListening: _isListening,
                      onMic: _toggleVoice,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      FormBanner(message: _error!),
                    ],
                  ] else
                    _FeedbackView(feedback: _feedback!, answer: _answer.text),
                ],
              ),
            ),
            Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm + bottomInset,
              ),
              child: _actions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    if (_done) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _restart,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Practice again'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      );
    }
    if (_feedback != null) {
      final last = _index + 1 == _questions.length;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _retry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Try again'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: last ? 'See results' : 'Next question',
              icon: last ? Icons.flag_rounded : Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: _answer,
      builder: (context, _) => PrimaryButton(
        label: _isReviewing ? 'Reviewing your answer…' : 'Get feedback',
        icon: Icons.auto_awesome_rounded,
        isLoading: _isReviewing,
        onPressed: _answer.text.trim().length < 15 || _isReviewing
            ? null
            : _review,
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final InterviewQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      color: colorScheme.primary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${question.category.label.toUpperCase()} QUESTION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            question.question,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (question.why != null && question.why!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              question.why!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.enabled,
    required this.isListening,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isListening;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 6,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Answer as you would in the interview. Aim for about '
                'a minute when spoken.',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Material(
              color: isListening ? colorScheme.error : colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onMic : null,
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(
                    isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: colorScheme.onPrimary,
                    semanticLabel:
                        isListening ? 'Stop dictation' : 'Answer by voice',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isListening
                    ? 'Listening… speak your answer, then tap stop.'
                    : 'Tap the mic to answer out loud, like the real thing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isListening
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isListening ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Color _scoreColor(BuildContext context, num score) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (score >= 7) return isDark ? AppColors.successDark : AppColors.success;
  if (score >= 5) return isDark ? AppColors.warningDark : AppColors.warning;
  return Theme.of(context).colorScheme.error;
}

class _FeedbackView extends StatefulWidget {
  const _FeedbackView({required this.feedback, required this.answer});

  final AnswerFeedback feedback;
  final String answer;

  @override
  State<_FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<_FeedbackView> {
  bool _showYours = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final feedback = widget.feedback;
    final color = _scoreColor(context, feedback.score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${feedback.score}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '/10',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  semanticsLabel: 'Score ${feedback.score} out of 10',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  feedback.verdict,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (feedback.strengths.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Points(
            title: 'What worked',
            icon: Icons.check_circle_rounded,
            color: _scoreColor(context, 10),
            items: feedback.strengths,
          ),
        ],
        if (feedback.improvements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Points(
            title: 'Make it stronger',
            icon: Icons.trending_up_rounded,
            color: colorScheme.primary,
            items: feedback.improvements,
          ),
        ],
        if (feedback.betterAnswer.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'A stronger answer',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  feedback.betterAnswer,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => setState(() => _showYours = !_showYours),
          icon: Icon(
            _showYours ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          ),
          label: Text(_showYours ? 'Hide your answer' : 'Show your answer'),
        ),
        if (_showYours)
          Text(
            widget.answer,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.questions, required this.scores});

  final List<InterviewQuestion> questions;
  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final average =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final color = _scoreColor(context, average);
    final headline = average >= 7
        ? "You're ready. Keep it sharp."
        : average >= 5
            ? 'Solid start. A bit more practice will help.'
            : 'Good first run. Practice makes this easier.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: SizedBox.square(
            dimension: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: average / 10,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: average.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        TextSpan(
                          text: '\nAVERAGE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            children: [
              for (final (i, score) in scores.indexed)
                ListTile(
                  title: Text(
                    questions[i].question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor(context, score).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$score/10',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _scoreColor(context, score),
                        fontWeight: FontWeight.w700,
                      ),
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
