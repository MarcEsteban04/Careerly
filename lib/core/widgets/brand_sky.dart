import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Careerly brand backdrop: logo-blue gradient, soft glows and twinkling
/// four-point stars echoing the star in the logo. Respects "reduce motion".
class BrandSky extends StatefulWidget {
  const BrandSky({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.starsBelowStatusBar = true,
    this.starOpacity = 1,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Keep stars out of the status bar area when drawn behind it.
  final bool starsBelowStatusBar;

  /// Dims the stars, e.g. behind dense content. 1 = full strength.
  final double starOpacity;

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandBright, AppColors.brandDeep, AppColors.brandNight],
    stops: [0, 0.55, 1],
  );

  @override
  State<BrandSky> createState() => _BrandSkyState();
}

class _BrandSkyState extends State<BrandSky>
    with SingleTickerProviderStateMixin {
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: BrandSky.gradient,
        borderRadius: widget.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SkyPainter(
                  _twinkle,
                  starOpacity: widget.starOpacity,
                  topInset: widget.starsBelowStatusBar
                      ? MediaQuery.paddingOf(context).top
                      : 0,
                ),
              ),
            ),
            widget.child,
          ],
        ),
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
  _SkyPainter(this.twinkle, {this.topInset = 0, this.starOpacity = 1})
      : super(repaint: twinkle);

  final Animation<double> twinkle;

  /// Status bar height; stars stay below it.
  final double topInset;

  final double starOpacity;

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
      final opacity =
          starOpacity * (star.gold ? 0.95 : 0.45) * (0.6 + 0.4 * wave);
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
      oldDelegate.topInset != topInset ||
      oldDelegate.starOpacity != starOpacity;
}
