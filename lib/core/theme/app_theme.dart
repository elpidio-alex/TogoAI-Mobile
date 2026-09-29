/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Configuration des thèmes Material 3 (clair et sombre) avec la police Google Fonts Inter, styles de boutons, formulaires et composants graphiques.
*/

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'togo_colors.dart';

/// Fabrique centrale du système de design Material 3 pour l'application TogoAI.
///
/// Génère les configurations de thèmes clair et sombre intégrant la typographie
/// moderne [GoogleFonts.inter], les styles de composants arrondis (boutons pill,
/// champs de formulaires arrondis) et l'extension de tokens [TogoTheme].
abstract final class AppTheme {
  /// Génère le thème visuel clair ([ThemeData]) de l'application TogoAI.
  ///
  /// Utilise un fond écru papier doux ([TogoColors.bgAppLight]) et un vert forêt ([TogoColors.accentLight]).
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

  /// Génère le thème visuel sombre ([ThemeData]) de l'application TogoAI.
  ///
  /// Utilise des tons anthracite profonds et chaleureux ([TogoColors.bgAppDark]) pour préserver les yeux et la batterie.
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

  /// Méthode d'assemblage commune paramétrée pour instancier un [ThemeData] Material 3 cohérent.
  ///
  /// Configure la hiérarchie typographique, les palettes ColorScheme, les rayons de courbure,
  /// les bordures de saisie et les états interactifs des contrôles.
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
