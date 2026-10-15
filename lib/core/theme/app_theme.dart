import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static const _fontFamily = 'Inter';

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        muted: AppColors.lightMuted,
        outline: AppColors.lightOutline,
        text: AppColors.lightText,
        textMuted: AppColors.lightTextMuted,
        primary: AppColors.brand,
        onPrimary: Colors.white,
        error: AppColors.error,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        muted: AppColors.darkMuted,
        outline: AppColors.darkOutline,
        text: AppColors.darkText,
        textMuted: AppColors.darkTextMuted,
        primary: AppColors.brandOnDark,
        onPrimary: AppColors.darkBackground,
        error: AppColors.errorDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color muted,
    required Color outline,
    required Color text,
    required Color textMuted,
    required Color primary,
    required Color onPrimary,
    required Color error,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,
      surfaceContainerHighest: muted,
      outline: outline,
      outlineVariant: outline,
      error: error,
    );

    final baseText = ThemeData(brightness: brightness, fontFamily: _fontFamily)
        .textTheme
        .apply(bodyColor: text, displayColor: text);

    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.25,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: border(outline),
        enabledBorder: border(outline),
        disabledBorder: border(outline),
        focusedBorder: border(primary, 1.5),
        errorBorder: border(error),
        focusedErrorBorder: border(error, 1.5),
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
          side: BorderSide(color: outline),
          foregroundColor: text,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: outline,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
