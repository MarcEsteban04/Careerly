import 'package:flutter/material.dart';

/// Palette. Screens should read colors from `Theme.of(context)`; the few
/// brand surfaces that sit outside the color scheme (header wash, nav bar)
/// read these directly.
abstract final class AppColors {
  // Primary blue, in the family of the logo's tile.
  static const brand = Color(0xFF2563EB);
  static const brandOnDark = Color(0xFF6E9BFF);

  /// Near-black for selected chips and the nav bar.
  static const ink = Color(0xFF111318);

  // Soft wash behind headers.
  static const washTop = Color(0xFFD8E5FF);
  static const washBottom = Color(0xFFF6F9FF);
  static const washTopDark = Color(0xFF15213D);
  static const washBottomDark = Color(0xFF0B0C10);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFF3F4F6);
  static const lightOutline = Color(0xFFE6E7EB);
  static const lightText = Color(0xFF111318);
  static const lightTextMuted = Color(0xFF6B7280);

  static const darkBackground = Color(0xFF0B0C10);
  static const darkSurface = Color(0xFF121318);
  static const darkMuted = Color(0xFF1C1E25);
  static const darkOutline = Color(0xFF282A33);
  static const darkText = Color(0xFFF3F4F6);
  static const darkTextMuted = Color(0xFF9CA3AF);
  static const darkNav = Color(0xFF1C1E25);

  static const success = Color(0xFF067647);
  static const successDark = Color(0xFF47CD89);
  static const warning = Color(0xFFB54708);
  static const warningDark = Color(0xFFFDB022);

  static const error = Color(0xFFD92D20);
  static const errorDark = Color(0xFFF97066);
}
