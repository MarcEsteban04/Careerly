import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// What a notice is about, which sets its icon, color and haptic.
enum IslandTone {
  info,
  success,
  error;

  /// A best guess from the wording, for call sites that only have text.
  static IslandTone guess(String message) {
    final m = message.toLowerCase();
    if (RegExp(r"couldn'?t|can'?t|failed|no .* found|not available|isn'?t available|"
            r'try again|error|first[,.]|required|invalid')
        .hasMatch(m)) {
      return IslandTone.error;
    }
    if (RegExp(r'saved|copied|marked|deleted|removed|updated|added|sent|'
            r'filled|moved|is on|set for|done|good luck|hid ')
        .hasMatch(m)) {
      return IslandTone.success;
    }
    return IslandTone.info;
  }
}

/// Dynamic-Island-style notices: a black pill under the status bar that
/// springs open into a capsule with an icon, the message and an optional
/// action, then folds back and disappears. Swipe it up or tap it to
/// dismiss. A newer notice replaces the current one.
abstract final class Island {
  static OverlayEntry? _entry;
  static final _key = GlobalKey<_IslandState>();

  static void show(
    BuildContext context,
    String message, {
    IslandTone? tone,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final resolved = tone ?? IslandTone.guess(message);
    final notice = _Notice(
      message: message,
      tone: resolved,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ??
          (actionLabel != null
              ? const Duration(seconds: 5)
              : Duration(milliseconds: 2600 + message.length * 25)),
    );

    final current = _key.currentState;
    if (_entry != null && current != null && current.mounted) {
      current.replace(notice);
    } else {
      _entry?.remove();
      _entry = OverlayEntry(
        builder: (_) => _Island(key: _key, notice: notice, onGone: _clear),
      );
      overlay.insert(_entry!);
    }

    switch (resolved) {
      case IslandTone.error:
        HapticFeedback.mediumImpact();
      case IslandTone.success:
        HapticFeedback.lightImpact();
      case IslandTone.info:
        HapticFeedback.selectionClick();
    }
  }

  /// Folds away the current notice, if any.
  static void hide() => _key.currentState?.dismiss();

  static void _clear() {
    _entry?.remove();
    _entry = null;
  }

  static void _forget(_IslandState state) {
    if (_key.currentState == null || identical(_key.currentState, state)) {
      _entry = null;
    }
  }
}

class _Notice {
  const _Notice({
    required this.message,
    required this.tone,
    required this.duration,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IslandTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  Color get color => switch (tone) {
        IslandTone.success => const Color(0xFF34C759),
        IslandTone.error => const Color(0xFFFF453A),
        IslandTone.info => AppColors.accent,
      };

  IconData get glyph =>
      icon ??
      switch (tone) {
        IslandTone.success => Icons.check_rounded,
        IslandTone.error => Icons.priority_high_rounded,
        IslandTone.info => Icons.notifications_none_rounded,
      };
}

class _Island extends StatefulWidget {
  const _Island({super.key, required this.notice, required this.onGone});

  final _Notice notice;
  final VoidCallback onGone;

  @override
  State<_Island> createState() => _IslandState();
}

class _IslandState extends State<_Island> with TickerProviderStateMixin {
  /// The resting pill, like the hardware island.
  static const _pillWidth = 124.0;
  static const _pillHeight = 36.0;

  late _Notice _notice = widget.notice;
  late final _shape = AnimationController(vsync: this);
  late final _countdown = AnimationController(vsync: this);
  Timer? _timer;
  double _drag = 0;
  bool _leaving = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_shape.isDismissed && !_leaving) _open();
  }

  @override
  void dispose() {
    // Torn down with its overlay (e.g. the app closing): forget it.
    Island._forget(this);
    _timer?.cancel();
    _shape.dispose();
    _countdown.dispose();
    super.dispose();
  }

  Duration _ms(int ms) => _reduceMotion ? Duration.zero : Duration(milliseconds: ms);

  void _open() {
    _leaving = false;
    _shape.animateTo(1, duration: _ms(520), curve: Curves.linear);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_notice.duration, dismiss);
    // The draining ring is decoration; with reduced motion it stays full.
    if (_notice.actionLabel != null && !_reduceMotion) {
      _countdown
        ..value = 1
        ..animateTo(0, duration: _notice.duration, curve: Curves.linear);
    } else {
      _countdown.value = 1;
    }
  }

  /// Swaps in a newer notice: the capsule settles to the new content.
  void replace(_Notice notice) {
    setState(() {
      _notice = notice;
      _drag = 0;
      _leaving = false;
    });
    if (_shape.value < 1) {
      _shape.animateTo(1, duration: _ms(420));
    } else {
      // A small "bump" so a repeat message still reads as new.
      _shape
        ..value = 0.82
        ..animateTo(1, duration: _ms(360));
    }
    _startTimer();
  }

  Future<void> dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _countdown.stop();
    await _shape.animateBack(0, duration: _ms(380), curve: Curves.linear);
    if (mounted) widget.onGone();
  }

  void _act() {
    final onAction = _notice.onAction;
    HapticFeedback.selectionClick();
    dismiss();
    onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final fullWidth = math.min(media.size.width - 24, 440.0);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: media.padding.top + 6,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = math.min(0, _drag + d.delta.dy)),
          onVerticalDragEnd: (d) {
            if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
              dismiss();
            } else {
              setState(() => _drag = 0);
            }
          },
          onTap: _notice.actionLabel == null ? dismiss : null,
          child: AnimatedBuilder(
            animation: _shape,
            builder: (context, _) {
              final v = _shape.value;
              // Opening overshoots a little, like a spring; closing doesn't.
              final open = _leaving
                  ? Curves.easeInCubic.transform(v)
                  : Curves.easeOutBack.transform(v);
              // The spring may overshoot, but only by a few pixels.
              final width = math.min(
                lerpDouble(_pillWidth, fullWidth, open)!,
                fullWidth + 10,
              );
              final content = Interval(_leaving ? 0.45 : 0.55, 1).transform(v);
              // Fades in as the pill appears; fully gone once folded.
              final presence = Interval(0, 0.25).transform(v);

              return Transform.translate(
                offset: Offset(0, _drag + (1 - presence) * -12),
                child: Opacity(
                  opacity: presence,
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    label: _notice.message,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: math.max(width, _pillWidth),
                        constraints: const BoxConstraints(minHeight: _pillHeight),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A0B),
                          borderRadius: BorderRadius.circular(
                            lerpDouble(_pillHeight / 2, 28, open.clamp(0, 1))!,
                          ),
                          border: isDark
                              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28 * presence),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            heightFactor: content,
                            // Laid out at full width while the capsule is
                            // still narrow, so text doesn't reflow as it grows.
                            child: UnconstrainedBox(
                              constrainedAxis: Axis.vertical,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: fullWidth,
                                child: Opacity(
                                  opacity: content,
                                  child: _Content(
                                    notice: _notice,
                                    countdown: _countdown,
                                    onAction: _act,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.notice,
    required this.countdown,
    required this.onAction,
  });

  final _Notice notice;
  final Animation<double> countdown;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notice.color;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        10,
        notice.actionLabel == null ? 20 : 10,
        10,
      ),
      child: Row(
        children: [
          // The glyph pops in a beat after the capsule opens.
          TweenAnimationBuilder<double>(
            key: ValueKey(notice),
            tween: Tween(begin: 0.4, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
              ),
              child: Icon(notice.glyph, size: 19, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notice.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (notice.actionLabel != null) ...[
            const SizedBox(width: 10),
            _ActionButton(
              label: notice.actionLabel!,
              color: color,
              countdown: countdown,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// The action pill, with a ring that drains as time runs out.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.countdown,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Animation<double> countdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 6, right: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 26,
                child: AnimatedBuilder(
                  animation: countdown,
                  builder: (context, _) => CustomPaint(
                    painter: _RingPainter(countdown.value, AppColors.accent),
                    child: Icon(
                      label.toLowerCase() == 'undo'
                          ? Icons.undo_rounded
                          : Icons.arrow_forward_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: 0.16);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final inset = rect.deflate(1.5);
    canvas.drawOval(inset, track);
    canvas.drawArc(inset, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
