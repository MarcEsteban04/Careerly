import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/voice/voice_input.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/hero_top_bar.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/island_toast.dart';
import '../../documents/presentation/widgets/markup_view.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/career_coach.dart';
import '../data/coach_history_store.dart';
import '../data/coach_message.dart';

/// Chat with an AI career coach that knows her profile, resume, tracked
/// jobs, agenda and goals. The conversation is kept on the phone.
class CoachScreen extends StatefulWidget {
  const CoachScreen({
    super.key,
    required this.coach,
    required this.history,
    required this.loadContext,
    this.voice,
    this.firstName,
  });

  final CareerCoach coach;
  final CoachHistoryStore history;

  /// Her current profile and search, read fresh for each question.
  final Future<CoachContext> Function() loadContext;
  final VoiceInput? voice;
  final String? firstName;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final VoiceInput _voice = widget.voice ?? VoiceInput();
  final _latestReply = GlobalKey();

  List<CoachMessage> _messages = const [];
  List<String> _starters = const [];
  bool _loaded = false;
  bool _thinking = false;
  bool _listening = false;

  /// The question that failed, offered to resend.
  String? _failed;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    if (_listening) _voice.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await widget.history.load();
    final context = await widget.loadContext();
    if (!mounted) return;
    setState(() {
      _messages = saved;
      _starters = CareerCoach.starters(context);
      _loaded = true;
    });
    _toBottom(animate: false);
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty || _thinking) return;
    if (_listening) await _toggleVoice();
    HapticFeedback.selectionClick();
    final history = _messages;
    setState(() {
      _messages = [
        ...history,
        CoachMessage(fromCoach: false, text: question, sentAt: DateTime.now()),
      ];
      _input.clear();
      _thinking = true;
      _failed = null;
    });
    _toBottom();

    try {
      final reply = await widget.coach.reply(
        question: question,
        context: await widget.loadContext(),
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          CoachMessage(
            fromCoach: true,
            text: reply.text,
            sentAt: DateTime.now(),
            suggestions: reply.suggestions,
            provider: reply.provider,
          ),
        ];
      });
      setState(() => _thinking = false);
      _revealReply();
      await widget.history.save(_messages);
    } catch (error) {
      if (!mounted) return;
      // Take the question back off so "Try again" can resend it.
      setState(() {
        _messages = history;
        _failed = question;
        _thinking = false;
      });
      _toBottom();
      Island.show(context, writerErrorMessage(error), tone: IslandTone.error);
    }
  }

  /// Brings the start of the newest reply to the top, so she reads it from
  /// the beginning instead of landing on its last line.
  void _revealReply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reply = _latestReply.currentContext;
      if (reply == null || !reply.mounted) return;
      Scrollable.ensureVisible(
        reply,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final before = _input.text.trim();
    final started = await _voice.start(
      onWords: (words) {
        final text = before.isEmpty ? words : '$before $words';
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (started) {
      HapticFeedback.lightImpact();
      setState(() => _listening = true);
    } else {
      Island.show(
        context,
        "Voice input isn't available. Allow the microphone, or type.",
        tone: IslandTone.error,
      );
    }
  }

  Future<void> _newChat() async {
    if (_messages.isEmpty) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text('This conversation will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New chat'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await widget.history.clear();
    setState(() {
      _messages = const [];
      _failed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _messages.lastOrNull;

    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: HeroTopBar(
              title: 'Career coach',
              trailing: CircleIconButton(
                icon: Icons.edit_square,
                tooltip: 'New chat',
                onPressed: _messages.isEmpty ? null : _newChat,
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && !_thinking
                    ? _Welcome(
                        firstName: widget.firstName,
                        starters: _starters,
                        onAsk: _send,
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        children: [
                          for (final message in _messages)
                            message.fromCoach
                                ? _CoachBubble(
                                    key: identical(message, last)
                                        ? _latestReply
                                        : null,
                                    message: message,
                                  )
                                : _MyBubble(text: message.text),
                          if (_thinking) const _Typing(),
                          if (_failed != null)
                            _RetryChip(onTap: () => _send(_failed)),
                          if (!_thinking &&
                              _failed == null &&
                              last != null &&
                              last.fromCoach &&
                              last.suggestions.isNotEmpty)
                            _Suggestions(
                              suggestions: last.suggestions,
                              onTap: _send,
                            ),
                        ],
                      ),
          ),
          _Composer(
            controller: _input,
            listening: _listening,
            sending: _thinking,
            enabled: widget.coach.isConfigured,
            onMic: _toggleVoice,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.firstName,
    required this.starters,
    required this.onAsk,
  });

  final String? firstName;
  final List<String> starters;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        const Center(
          child: IconBadge(
            icon: Icons.auto_awesome_rounded,
            accent: Accent.teal,
            size: 64,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          firstName == null
              ? "Hi, I'm your career coach"
              : "Hi $firstName, I'm your career coach",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'I know your profile, resume and the jobs you track. Ask me '
          'anything about your search.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final starter in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Material(
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: colorScheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onAsk(starter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          starter,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Coaching from AI. Double-check anything important.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MyBubble extends StatelessWidget {
  const _MyBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 56, bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: SelectableText(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({super.key, required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 32, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CoachAvatar(),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: MarkupView(content: message.text),
                ),
                Row(
                  children: [
                    if (message.provider != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, right: 2),
                        child: Text(
                          message.provider!,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Copy reply',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: message.text));
                        if (context.mounted) {
                          Island.show(context, 'Copied', tone: IslandTone.success);
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
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

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar();

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(top: 2),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: AppColors.accent,
        ),
      );
}

/// Three dots that rise in turn while the coach writes.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat.value = 0;
    } else if (!_beat.isAnimating) {
      _beat.repeat();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'The coach is writing',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            const _CoachAvatar(),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _beat,
                builder: (context, _) => Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Transform.translate(
                        offset: Offset(0, -4 * _bounce(_beat.value, i)),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.45 + 0.55 * _bounce(_beat.value, i),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Thinking…',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 0 → 1 → 0 for dot [i], each a third of a beat behind the last.
  static double _bounce(double t, int i) {
    final phase = (t - i * 0.18) % 1;
    return phase < 0.4 ? Curves.easeInOut.transform(1 - (phase - 0.2).abs() / 0.2) : 0;
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 38, top: AppSpacing.xxs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final suggestion in suggestions)
            ActionChip(
              label: Text(suggestion),
              onPressed: () => onTap(suggestion),
              backgroundColor: colorScheme.surface,
              side: BorderSide(color: Accent.teal.colorIn(theme.brightness)),
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: Accent.teal.colorIn(theme.brightness),
                fontWeight: FontWeight.w600,
              ),
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 38),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            onPressed: onTap,
            shape: const StadiumBorder(),
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.listening,
    required this.sending,
    required this.enabled,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool listening;
  final bool sending;
  final bool enabled;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSend = enabled && !sending && controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: listening
                    ? 'Listening…'
                    : enabled
                        ? 'Ask your coach…'
                        : 'Add an AI key to use the coach',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: listening ? 'Stop dictation' : 'Dictate',
            onPressed: enabled ? onMic : null,
            style: IconButton.styleFrom(
              backgroundColor: listening
                  ? Accent.rose.tintIn(theme.brightness)
                  : Colors.transparent,
            ),
            icon: Icon(
              listening ? Icons.stop_rounded : Icons.mic_none_rounded,
              color: listening ? Accent.rose.colorIn(theme.brightness) : null,
            ),
          ),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: canSend ? onSend : null,
            icon: sending
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
