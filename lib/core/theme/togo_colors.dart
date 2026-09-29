import 'package:flutter/material.dart';

/// Palette fidèle à `globals.css` du web TogoAI.
abstract final class TogoColors {
  // Accent
  static const accentLight = Color(0xFF047857);
  static const accentDark = Color(0xFF059669);
  static const accentHoverLight = Color(0xFF065F46);
  static const accentHoverDark = Color(0xFF047857);
  static const accentSoftLight = Color(0x1F047857);
  static const accentSoftDark = Color(0x29059669);

  // Light
  static const bgAppLight = Color(0xFFFAF9F5);
  static const bgSidebarLight = Color(0xFFF3F2ED);
  static const bgCardLight = Color(0xFFFFFFFF);
  static const bgHoverLight = Color(0xFFEAE8E1);
  static const bgActiveLight = Color(0xFFDFDDD5);
  static const borderLight = Color(0xFFE5E4DD);
  static const textLight = Color(0xFF1F1E1D);
  static const textSecondaryLight = Color(0xFF666560);
  static const textTertiaryLight = Color(0xFF999892);

  // Dark
  static const bgAppDark = Color(0xFF181816);
  static const bgSidebarDark = Color(0xFF1E1E1C);
  static const bgCardDark = Color(0xFF252523);
  static const bgHoverDark = Color(0xFF2C2C29);
  static const bgActiveDark = Color(0xFF363532);
  static const borderDark = Color(0xFF2E2D2A);
  static const textDark = Color(0xFFF4F3EE);
  static const textSecondaryDark = Color(0xFF9E9D98);
  static const textTertiaryDark = Color(0xFF6E6D68);

  // Semantic
  static const dangerLight = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFEF4444);

  // Auth header gradient
  static const authGreenTop = Color(0xFF15623B);
  static const authGreenMid = Color(0xFF0C3C24);
  static const authGreenBottom = Color(0xFF052012);

  // Logo
  static const navy = Color(0xFF0F1F3D);

  // Chat
  static const chatUserBubbleLight = Color(0xFFEFECE6);
  static const chatUserBubbleDark = Color(0xFF2B2A27);
  static const sendDisabledLight = Color(0xFFD6D5CE);
  static const sendDisabledDark = Color(0xFF383733);
  static const inputBorderLight = Color(0xFFDFDED7);
  static const inputBorderDark = Color(0xFF3A3935);
}

/// Extension ThemeData pour tokens métier.
@immutable
class TogoTheme extends ThemeExtension<TogoTheme> {
  const TogoTheme({
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.bgApp,
    required this.bgSidebar,
    required this.bgCard,
    required this.bgHover,
    required this.bgActive,
    required this.border,
    required this.textSecondary,
    required this.textTertiary,
    required this.danger,
    required this.userBubble,
    required this.sendDisabled,
    required this.inputBorder,
  });

  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color bgApp;
  final Color bgSidebar;
  final Color bgCard;
  final Color bgHover;
  final Color bgActive;
  final Color border;
  final Color textSecondary;
  final Color textTertiary;
  final Color danger;
  final Color userBubble;
  final Color sendDisabled;
  final Color inputBorder;

  static const light = TogoTheme(
    accent: TogoColors.accentLight,
    accentHover: TogoColors.accentHoverLight,
    accentSoft: TogoColors.accentSoftLight,
    bgApp: TogoColors.bgAppLight,
    bgSidebar: TogoColors.bgSidebarLight,
    bgCard: TogoColors.bgCardLight,
    bgHover: TogoColors.bgHoverLight,
    bgActive: TogoColors.bgActiveLight,
    border: TogoColors.borderLight,
    textSecondary: TogoColors.textSecondaryLight,
    textTertiary: TogoColors.textTertiaryLight,
    danger: TogoColors.dangerLight,
    userBubble: TogoColors.chatUserBubbleLight,
    sendDisabled: TogoColors.sendDisabledLight,
    inputBorder: TogoColors.inputBorderLight,
  );

  static const dark = TogoTheme(
    accent: TogoColors.accentDark,
    accentHover: TogoColors.accentHoverDark,
    accentSoft: TogoColors.accentSoftDark,
    bgApp: TogoColors.bgAppDark,
    bgSidebar: TogoColors.bgSidebarDark,
    bgCard: TogoColors.bgCardDark,
    bgHover: TogoColors.bgHoverDark,
    bgActive: TogoColors.bgActiveDark,
    border: TogoColors.borderDark,
    textSecondary: TogoColors.textSecondaryDark,
    textTertiary: TogoColors.textTertiaryDark,
    danger: TogoColors.dangerDark,
    userBubble: TogoColors.chatUserBubbleDark,
    sendDisabled: TogoColors.sendDisabledDark,
    inputBorder: TogoColors.inputBorderDark,
  );

  @override
  TogoTheme copyWith({
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? bgApp,
    Color? bgSidebar,
    Color? bgCard,
    Color? bgHover,
    Color? bgActive,
    Color? border,
    Color? textSecondary,
    Color? textTertiary,
    Color? danger,
    Color? userBubble,
    Color? sendDisabled,
    Color? inputBorder,
  }) {
    return TogoTheme(
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      bgApp: bgApp ?? this.bgApp,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgCard: bgCard ?? this.bgCard,
      bgHover: bgHover ?? this.bgHover,
      bgActive: bgActive ?? this.bgActive,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      danger: danger ?? this.danger,
      userBubble: userBubble ?? this.userBubble,
      sendDisabled: sendDisabled ?? this.sendDisabled,
      inputBorder: inputBorder ?? this.inputBorder,
    );
  }

  @override
  TogoTheme lerp(ThemeExtension<TogoTheme>? other, double t) {
    if (other is! TogoTheme) return this;
    return TogoTheme(
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      bgApp: Color.lerp(bgApp, other.bgApp, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgHover: Color.lerp(bgHover, other.bgHover, t)!,
      bgActive: Color.lerp(bgActive, other.bgActive, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      sendDisabled: Color.lerp(sendDisabled, other.sendDisabled, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
    );
  }
}

extension TogoThemeX on BuildContext {
  TogoTheme get togo => Theme.of(this).extension<TogoTheme>()!;
}
