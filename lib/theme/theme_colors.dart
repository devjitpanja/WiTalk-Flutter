import 'package:flutter/material.dart';

/// Theme-aware color set — mirrors RN lightTheme / darkTheme from colors.js.
/// Use [BuildContext.colors] in widgets; never hardcode hex values.
class ThemeColors {
  final Color background;
  final Color surface;
  final Color card;
  final Color cardBackground;

  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color subText;

  final Color headerBackground;
  final Color headerText;

  final Color border;
  final Color divider;
  final Color placeholder;

  final Color primary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color danger;

  final Color likeBackground;
  final Color likeBorder;

  final Color followButtonBg;
  final Color followButtonText;

  final Color tabBarBg;
  final Color tabBarActive;
  final Color tabBarInactive;
  final Color tabBarFocused;

  final Color bottomSheetBg;
  final Color modalBg;
  final Color overlay;

  final Color primaryButton;
  final Color primaryButtonDisabled;
  final Color secondaryButton;
  final Color secondaryButtonBorder;

  // Post interaction pill buttons (match RN PostCard)
  final Color interactionButtonBg;
  final Color interactionButtonBorder;
  final Color interactionLikedBg;   // red background when liked
  final Color interactionLikedBorder;
  final Color likeColor;            // icon colour when liked (white in RN)
  final Color iconTint;             // default icon tint on pill buttons

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardBackground,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.subText,
    required this.headerBackground,
    required this.headerText,
    required this.border,
    required this.divider,
    required this.placeholder,
    required this.primary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.danger,
    required this.likeBackground,
    required this.likeBorder,
    required this.followButtonBg,
    required this.followButtonText,
    required this.tabBarBg,
    required this.tabBarActive,
    required this.tabBarInactive,
    required this.tabBarFocused,
    required this.bottomSheetBg,
    required this.modalBg,
    required this.overlay,
    required this.primaryButton,
    required this.primaryButtonDisabled,
    required this.secondaryButton,
    required this.secondaryButtonBorder,
    required this.interactionButtonBg,
    required this.interactionButtonBorder,
    required this.interactionLikedBg,
    required this.interactionLikedBorder,
    required this.likeColor,
    required this.iconTint,
  });
}

extension ThemeColorsX on BuildContext {
  ThemeColors get colors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }
}

// ── Dark theme — matches RN darkTheme ────────────────────────────────────────
const _dark = ThemeColors(
  background:           Color(0xFF0D1017),
  surface:              Color(0xFF0D1017),
  card:                 Color(0xFF0D1017),
  cardBackground:       Color(0xFF1C1C1E),

  text:                 Color(0xFFFFFFFF),
  textSecondary:        Color(0xFFEBEBF5),
  textTertiary:         Color(0xFF8E8E93),
  subText:              Color(0xFF8E8E93),

  headerBackground:     Color(0xFF0D1017),
  headerText:           Color(0xFFFFFFFF),

  border:               Color(0xFF38383A),
  divider:              Colors.transparent,
  placeholder:          Color(0xFF8E8E93),

  primary:              Color(0xFF0A84FF),
  accent:               Color(0xFF0751DF),
  success:              Color(0xFF30D158),
  warning:              Color(0xFFFF9F0A),
  error:                Color(0xFFFF453A),
  danger:               Color(0xFFFF453A),

  likeBackground:       Color(0xFFD1001C),
  likeBorder:           Color(0xFFE70000),

  followButtonBg:       Color(0xFF3A3A3C),
  followButtonText:     Color(0xFFFFFFFF),

  tabBarBg:             Color(0xFF0D1017),
  tabBarActive:         Color(0xFFFFFFFF),
  tabBarInactive:       Color(0xFF8E8E93),
  tabBarFocused:        Color(0xFF11151F),

  bottomSheetBg:        Color(0xFF0D1017),
  modalBg:              Color(0xCC000000),
  overlay:              Color(0x80000000),

  primaryButton:        Color(0xFF5B51F4),
  primaryButtonDisabled:Color(0xFF3D3A8C),
  secondaryButton:      Color(0xFF11151F),
  secondaryButtonBorder:Color(0xFF5B51F4),

  // RN darkTheme: interactionButtonBg transparent, interactedButtonBg red
  interactionButtonBg:     Colors.transparent,
  interactionButtonBorder: Color(0xFF38383A),
  interactionLikedBg:      Color(0xFFD1001C),   // rgba(209,0,28,1)
  interactionLikedBorder:  Color(0xFFD1001C),
  likeColor:               Colors.white,         // RN: like '#ffffff'
  iconTint:                Color(0xFF8E8E93),    // textTertiary used as icon tint
);

// ── Light theme — matches RN lightTheme ──────────────────────────────────────
const _light = ThemeColors(
  background:           Color(0xFFFFFFFF),
  surface:              Color(0xFFFFFFFF),
  card:                 Color(0xFFFFFFFF),
  cardBackground:       Color(0xFFF9F9F9),

  text:                 Color(0xFF000000),
  textSecondary:        Color(0xFF666666),
  textTertiary:         Color(0xFF999999),
  subText:              Color(0xFF999999),

  headerBackground:     Color(0xFFFFFFFF),
  headerText:           Color(0xFF000000),

  border:               Color(0xFFE0E0E0),
  divider:              Color(0xFFDFDFDF),
  placeholder:          Color(0xFF999999),

  primary:              Color(0xFF007AFF),
  accent:               Color(0xFF0751DF),
  success:              Color(0xFF4CAF50),
  warning:              Color(0xFFFF9800),
  error:                Color(0xFFF44336),
  danger:               Color(0xFFFF3A30),

  likeBackground:       Color(0x1AF40D11),
  likeBorder:           Color(0xFFF40D11),

  followButtonBg:       Color(0xFFEBEBEB),
  followButtonText:     Color(0xFF000000),

  tabBarBg:             Color(0xFFFFFFFF),
  tabBarActive:         Color(0xFF000000),
  tabBarInactive:       Color(0xFF000000),
  tabBarFocused:        Color(0xFFF0F0F0),

  bottomSheetBg:        Color(0xFFFFFFFF),
  modalBg:              Color(0x80000000),
  overlay:              Color(0x4D000000),

  primaryButton:        Color(0xFF5B51F4),
  primaryButtonDisabled:Color(0xFF9A93E8),
  secondaryButton:      Color(0xFFF0F0F0),
  secondaryButtonBorder:Color(0xFF5B51F4),

  // RN lightTheme: interactionButtonBg transparent
  interactionButtonBg:     Colors.transparent,
  interactionButtonBorder: Color(0xFFE0E0E0),
  interactionLikedBg:      Color(0xFFD1001C),   // same red as dark
  interactionLikedBorder:  Color(0xFFB40036),
  likeColor:               Colors.white,         // RN: like '#ffffff'
  iconTint:                Color(0xFF999999),    // textTertiary for light
);
