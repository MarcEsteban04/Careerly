import 'package:flutter/material.dart';

/// Brand palette. Screens should read colors from `Theme.of(context)`,
/// not from here directly; this file only feeds the theme.
abstract final class AppColors {
  static const brand = Color(0xFF4F46E5);
  static const brandDeep = Color(0xFF3730A3);
  static const brandBright = Color(0xFF7C73F0);

  static const lightBackground = Color(0xFFF7F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightField = Color(0xFFF1F1F7);
  static const lightOutline = Color(0xFFE3E3EC);
  static const lightText = Color(0xFF14142B);
  static const lightTextMuted = Color(0xFF6B6B80);

  static const darkBackground = Color(0xFF0E0E16);
  static const darkSurface = Color(0xFF17171F);
  static const darkField = Color(0xFF1F1F2A);
  static const darkOutline = Color(0xFF2C2C3A);
  static const darkText = Color(0xFFF2F2F7);
  static const darkTextMuted = Color(0xFF9A9AAE);

  static const error = Color(0xFFD92D20);
  static const errorDark = Color(0xFFF97066);
}
