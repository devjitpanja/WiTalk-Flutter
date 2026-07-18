import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryButton,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.text,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.tabBarBg,
          selectedItemColor: AppColors.tabBarActive,
          unselectedItemColor: AppColors.tabBarInactive,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 0.5,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text),
          displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text),
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 18),
          titleMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 16),
          titleSmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.text, fontSize: 14),
          bodyLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.text, fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.textSecondary, fontSize: 14),
          bodySmall: TextStyle(fontFamily: 'Outfit', color: AppColors.textTertiary, fontSize: 12),
          labelLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryButton,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF007AFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF5B51F4),
          surface: Colors.white,
          error: Color(0xFFF44336),
        ),
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      );
}
