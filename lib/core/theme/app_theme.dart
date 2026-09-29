import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'togo_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        extension: TogoTheme.light,
        scaffold: TogoColors.bgAppLight,
        surface: TogoColors.bgCardLight,
        onSurface: TogoColors.textLight,
        secondaryText: TogoColors.textSecondaryLight,
        border: TogoColors.borderLight,
        accent: TogoColors.accentLight,
        accentHover: TogoColors.accentHoverLight,
        danger: TogoColors.dangerLight,
        inputFill: TogoColors.bgCardLight,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        extension: TogoTheme.dark,
        scaffold: TogoColors.bgAppDark,
        surface: TogoColors.bgCardDark,
        onSurface: TogoColors.textDark,
        secondaryText: TogoColors.textSecondaryDark,
        border: TogoColors.borderDark,
        accent: TogoColors.accentDark,
        accentHover: TogoColors.accentHoverDark,
        danger: TogoColors.dangerDark,
        inputFill: TogoColors.bgCardDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required TogoTheme extension,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
    required Color secondaryText,
    required Color border,
    required Color accent,
    required Color accentHover,
    required Color danger,
    required Color inputFill,
  }) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      textTheme: base,
      extensions: [extension],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: secondaryText),
        labelStyle: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : null,
        ),
        side: BorderSide(color: secondaryText),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: accentHover,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}
