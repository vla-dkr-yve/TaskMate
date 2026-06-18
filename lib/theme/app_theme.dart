import 'package:flutter/material.dart';

// Status colors (done/undone/archived) stay consistent across both themes.
abstract class AppTheme {

  // Status colors (same in both modes)
  static const Color statusDone     = Color(0xFF4CAF50);
  static const Color statusUndone   = Color(0xFFEF5350);
  static const Color statusArchived = Color(0xFF9E9E9E);

  static const Color statusDoneBg     = Color(0xFFE8F5E9);
  static const Color statusUndoneBg   = Color(0xFFFFEBEE);
  static const Color statusArchivedBg = Color(0xFFF5F5F5);

  static const Color statusDoneBgDark     = Color(0xFF1B3A1F);
  static const Color statusUndoneBgDark   = Color(0xFF3B1515);
  static const Color statusArchivedBgDark = Color(0xFF2A2A2A);

  // Light palette
  static const Color bgLight       = Color(0xFFF2F2F2);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFF7F7F7);
  static const Color textLight     = Color(0xFF0D0D0D);
  static const Color textSecLight  = Color(0xFF6B6B6B);
  static const Color dividerLight  = Color(0xFFE0E0E0);

  // Dark palette
  static const Color bgDark       = Color(0xFF1C1C1E);
  static const Color surfaceDark  = Color(0xFF2C2C2E);
  static const Color surface2Dark = Color(0xFF3A3A3C);
  static const Color textDark     = Color(0xFFFFFFFF);
  static const Color textSecDark  = Color(0xFFABABAB);
  static const Color dividerDark  = Color(0xFF3A3A3C);

  // Funcs
  static Color bg(BuildContext ctx)       => _d(ctx) ? bgDark       : bgLight;
  static Color surface(BuildContext ctx)  => _d(ctx) ? surfaceDark  : surfaceLight;
  static Color surface2(BuildContext ctx) => _d(ctx) ? surface2Dark : surface2Light;
  static Color text(BuildContext ctx)     => _d(ctx) ? textDark     : textLight;
  static Color textSec(BuildContext ctx)  => _d(ctx) ? textSecDark  : textSecLight;
  static Color divider(BuildContext ctx)  => _d(ctx) ? dividerDark  : dividerLight;

  static Color taskBg(BuildContext ctx, {required bool isDone, required bool isArchived}) {
    if (isArchived) return _d(ctx) ? statusArchivedBgDark : statusArchivedBg;
    if (isDone)     return _d(ctx) ? statusDoneBgDark     : statusDoneBg;
    return _d(ctx) ? statusUndoneBgDark : statusUndoneBg;
  }

  static Color taskAccent({required bool isDone, required bool isArchived}) {
    if (isArchived) return statusArchived;
    if (isDone)     return statusDone;
    return statusUndone;
  }

  static bool _d(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ThemeData factories
  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    cardColor: surfaceLight,
    dividerColor: dividerLight,
    colorScheme: const ColorScheme.light(
      surface: surfaceLight,
      onSurface: textLight,
      primary: Color(0xFF0D0D0D),
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgLight,
      foregroundColor: textLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: textLight,
      unselectedItemColor: textSecLight,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0D0D0D),
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2Light,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: textLight, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: textSecLight, fontSize: 15),
    ),
    useMaterial3: false,
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    cardColor: surfaceDark,
    dividerColor: dividerDark,
    colorScheme: const ColorScheme.dark(
      surface: surfaceDark,
      onSurface: textDark,
      primary: Colors.white,
      onPrimary: Color(0xFF0D0D0D),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: textDark,
      unselectedItemColor: textSecDark,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0D0D0D),
      elevation: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2Dark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: textSecDark, fontSize: 15),
    ),
    useMaterial3: false,
  );
}
