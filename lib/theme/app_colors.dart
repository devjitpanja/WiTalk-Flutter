import 'package:flutter/material.dart';

/// Static dark-mode constants — kept for legacy use.
/// New widgets should use [BuildContext.colors] from theme_colors.dart instead.
class AppColors {
  // Dark theme (default) — matches RN darkTheme in colors.js
  static const Color background = Color(0xFF0D1017);
  static const Color surface = Color(0xFF0D1017);
  static const Color card = Color(0xFF0D1017);
  static const Color cardBackground = Color(0xFF1C1C1E);

  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFEBEBF5);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color subText = Color(0xFF8E8E93);

  static const Color headerBackground = Color(0xFF0D1017);
  static const Color headerText = Color(0xFFFFFFFF);

  static const Color border = Color(0xFF38383A);
  static const Color divider = Colors.transparent;
  static const Color placeholder = Color(0xFF8E8E93);

  static const Color primary = Color(0xFF0A84FF);
  static const Color accent = Color(0xFF0751DF);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF453A);
  static const Color danger = Color(0xFFFF453A);

  static const Color likeBackground = Color(0xFFD1001C);
  static const Color likeBorder = Color(0xFFE70000);

  static const Color followButtonBg = Color(0xFF3A3A3C);
  static const Color followButtonText = Color(0xFFFFFFFF);

  static const Color tabBarBg = Color(0xFF0D1017);
  static const Color tabBarActive = Color(0xFFFFFFFF);
  static const Color tabBarInactive = Color(0xFF8E8E93);
  static const Color tabBarFocused = Color(0xFF11151F);

  static const Color bottomSheetBg = Color(0xFF0D1017);
  static const Color modalBg = Color(0xCC000000);
  static const Color overlay = Color(0x80000000);

  static const Color primaryButton = Color(0xFF5B51F4);
  static const Color primaryButtonDisabled = Color(0xFF3D3A8C);
  static const Color secondaryButton = Color(0xFF11151F);
  static const Color secondaryButtonBorder = Color(0xFF5B51F4);

  // Auth screen specific
  static const Color authGradientTop = Color(0xFF1565C0);
  static const Color authGradientMid = Color(0xFF1976D2);
  static const Color authGradientBottom = Color(0xFF0D47A1);
}
