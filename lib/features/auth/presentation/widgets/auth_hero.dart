import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Brand header for the auth screens: logo-blue gradient, soft glows and
/// twinkling four-point stars echoing the star in the logo.
///
/// [compact] shrinks it while the keyboard is open.
class AuthHero extends StatefulWidget {
  const AuthHero({
    super.key,
    this.compact = false,
    this.bottomInset = 0,
    this.minHeight = 0,
  });

  final bool compact;

  /// Content is centered vertically within at least this height.
  final double minHeight;

  /// Extra bottom padding so content clears a panel overlapping the hero.
  final double bottomInset;

  static const background = AppColors.brandNight;

  @override
  State<AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<AuthHero>
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'assets/icons/careerly_logo.png';

  late final _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _twinkle
        ..stop()
        ..value = 0.25;
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final logoSize = compact ? 52.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: widget.minHeight),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandBright,
            AppColors.brandDeep,
            AuthHero.background,
          ],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SkyPainter(
                _twinkle,
                topInset: MediaQuery.paddingOf(context).top,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                compact ? AppSpacing.md : AppSpacing.xxl,
                AppSpacing.lg,
                (compact ? AppSpacing.lg : AppSpacing.xxl) + widget.bottomInset,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(logoSize * 0.26),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.22),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        _logoAsset,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Careerly logo',
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                    Text(
                      'Careerly',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: compact
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                'Your career, in motion.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.size, this.phase, {this.gold = false});

  final double x;
  final double y;
  final double size;
  final double phase;
  final bool gold;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.twinkle, {this.topInset = 0}) : super(repaint: twinkle);

  final Animation<double> twinkle;

  /// Status bar height; stars stay below it.
  final double topInset;

  static const _stars = [
    _Star(0.12, 0.22, 7, 0.0),
    _Star(0.86, 0.16, 11, 0.35, gold: true),
    _Star(0.74, 0.62, 6, 0.6),
    _Star(0.20, 0.70, 9, 0.2, gold: true),
    _Star(0.50, 0.10, 5, 0.8),
    _Star(0.93, 0.48, 5, 0.45),
    _Star(0.06, 0.46, 4, 0.7),
    _Star(0.34, 0.36, 4, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _glow(canvas, Offset(size.width * 0.85, size.height * 0.1),
        size.width * 0.6, Colors.white.withValues(alpha: 0.10));
    _glow(canvas, Offset(size.width * 0.1, size.height * 0.95),
        size.width * 0.55, AppColors.amber.withValues(alpha: 0.10));

    for (final star in _stars) {
      final wave = math.sin((twinkle.value + star.phase) * math.pi * 2);
      final opacity = (star.gold ? 0.95 : 0.45) * (0.6 + 0.4 * wave);
      final color =
          (star.gold ? AppColors.gold : Colors.white).withValues(alpha: opacity);
      _sparkle(
        canvas,
        Offset(
          size.width * star.x,
          topInset + (size.height - topInset) * star.y,
        ),
        star.size * (0.9 + 0.1 * wave),
        color,
      );
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  /// Four-point star with concave sides, like the one in the logo.
  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final pinch = r * 0.18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + pinch, c.dy - pinch, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + pinch, c.dy + pinch, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - pinch, c.dy + pinch, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - pinch, c.dy - pinch, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.topInset != topInset;
}
