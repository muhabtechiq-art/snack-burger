import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';

/// ثيم موحّد لواجهة المنيو — خردلي + أحمر مطفي + أبيض.
abstract final class CustomerMenuTheme {
  static const Color mustard = Color(0xFFF6D21E);
  static const Color mustardSoft = Color(0xFFF9E675);
  static const Color mustardDeep = Color(0xFFE8C547);
  static const Color mutedRed = Color(0xFF9B2335);
  static const Color mutedRedDark = Color(0xFF7A1C2A);
  static const Color surfaceWhite = Color(0xFFFFFBF7);
  static const Color ink = Color(0xFF1E1712);
  static const Color inkMuted = Color(0xFF5C4F47);

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 28;
  static const double radiusXl = 32;

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 20);

  static ThemeData buildTheme(TenantPalette palette) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceWhite,
      colorScheme: ColorScheme.light(
        primary: mutedRed,
        onPrimary: Colors.white,
        secondary: mustard,
        onSecondary: ink,
        surface: surfaceWhite,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mutedRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: mutedRed.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: mutedRed.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: mutedRed, width: 1.5),
        ),
        prefixIconColor: mutedRed,
        suffixIconColor: mutedRed,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          color: ink,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyMedium: TextStyle(
          color: inkMuted,
          height: 1.45,
        ),
      ),
    );
  }
}
