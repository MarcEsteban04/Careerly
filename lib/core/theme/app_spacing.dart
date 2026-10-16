import 'package:flutter/material.dart';

/// 4-pt spacing and radius scale used across the app.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Quiet elevation: white cards lift just off the off-white page in light
/// mode; dark mode relies on borders instead.
abstract final class AppShadows {
  static List<BoxShadow> card(Brightness brightness) =>
      brightness == Brightness.dark
          ? const []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ];

  /// A slightly stronger lift for floating controls, e.g. a primary
  /// button or a selected segment.
  static List<BoxShadow> raised(Brightness brightness) =>
      brightness == Brightness.dark
          ? const []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ];
}
