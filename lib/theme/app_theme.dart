import 'package:flutter/material.dart';

// All hex values are sourced from RN colors.js lightTheme / darkTheme.

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1017),
        primaryColor: const Color(0xFF0A84FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF),
          secondary: Color(0xFF5B51F4),
          surface: Color(0xFF0D1017),
          error: Color(0xFFFF453A),
        ),
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1017),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFFFFFFFF),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D1017),
          selectedItemColor: Color(0xFFFFFFFF),
          unselectedItemColor: Color(0xFF8E8E93),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF38383A),
          thickness: 0.5,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
          displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
          titleLarge:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), fontSize: 18),
          titleMedium:  TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), fontSize: 16),
          titleSmall:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFFFFFFFF), fontSize: 14),
          bodyLarge:    TextStyle(fontFamily: 'Outfit', color: Color(0xFFFFFFFF), fontSize: 16),
          bodyMedium:   TextStyle(fontFamily: 'Outfit', color: Color(0xFFEBEBF5), fontSize: 14),
          bodySmall:    TextStyle(fontFamily: 'Outfit', color: Color(0xFF8E8E93), fontSize: 12),
          labelLarge:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'Outfit'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF38383A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF38383A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0A84FF)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B51F4),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primaryColor: const Color(0xFF007AFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF5B51F4),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFF44336),
        ),
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF000000),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF000000),
          unselectedItemColor: Color(0xFF000000),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFDFDFDF),
          thickness: 0.5,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFF000000)),
          displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFF000000)),
          titleLarge:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFF000000), fontSize: 18),
          titleMedium:  TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFF000000), fontSize: 16),
          titleSmall:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFF000000), fontSize: 14),
          bodyLarge:    TextStyle(fontFamily: 'Outfit', color: Color(0xFF000000), fontSize: 16),
          bodyMedium:   TextStyle(fontFamily: 'Outfit', color: Color(0xFF666666), fontSize: 14),
          bodySmall:    TextStyle(fontFamily: 'Outfit', color: Color(0xFF999999), fontSize: 12),
          labelLarge:   TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFF000000), fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          hintStyle: const TextStyle(color: Color(0xFF999999), fontFamily: 'Outfit'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF007AFF)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B51F4),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF9A93E8),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      );
}
