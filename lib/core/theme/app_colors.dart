import 'package:flutter/material.dart';

/// Brand palette, sampled from the Careerly logo. Screens should read colors
/// from `Theme.of(context)`; only brand surfaces (e.g. the login hero) use
/// these directly.
abstract final class AppColors {
  // Logo blues, from the tile's top-left highlight to its bottom-right shade.
  static const brand = Color(0xFF1C45DF);
  static const brandBright = Color(0xFF1D56F5);
  static const brandDeep = Color(0xFF1E29A8);
  static const brandNight = Color(0xFF0D1260);
  static const brandOnDark = Color(0xFF7D97FF);

  // Logo arrow and star.
  static const amber = Color(0xFFFBA335);
  static const gold = Color(0xFFFBC43E);

  static const lightBackground = Color(0xFFF6F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightField = Color(0xFFF2F4FA);
  static const lightOutline = Color(0xFFE2E6F0);
  static const lightText = Color(0xFF0F1430);
  static const lightTextMuted = Color(0xFF5E6378);

  static const darkBackground = Color(0xFF0A0C16);
  static const darkSurface = Color(0xFF12141F);
  static const darkField = Color(0xFF1B1E2C);
  static const darkOutline = Color(0xFF2A2E40);
  static const darkText = Color(0xFFF2F3F8);
  static const darkTextMuted = Color(0xFF9AA0B8);

  static const success = Color(0xFF067647);
  static const successDark = Color(0xFF47CD89);
  static const warning = Color(0xFFB54708);
  static const warningDark = Color(0xFFFDB022);

  static const error = Color(0xFFD92D20);
  static const errorDark = Color(0xFFF97066);
}
