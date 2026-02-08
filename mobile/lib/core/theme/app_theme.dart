import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary dark cockpit theme
  static const Color background = Color(0xFF1A1D23);
  static const Color surface = Color(0xFF242830);
  static const Color surfaceLight = Color(0xFF2E323A);
  static const Color card = Color(0xFF2A2E36);
  static const Color divider = Color(0xFF3A3E46);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B4BC);
  static const Color textMuted = Color(0xFF6E7280);

  // Accent
  static const Color primary = Color(0xFF4A90D9);
  static const Color accent = Color(0xFF5BA8F5);

  // Aviation-specific
  static const Color routeMagenta = Color(0xFFFF00FF);
  static const Color vfr = Color(0xFF00C853);
  static const Color mvfr = Color(0xFF2196F3);
  static const Color ifr = Color(0xFFFF1744);
  static const Color lifr = Color(0xFFE040FB);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF29B6F6);

  // Tab bar
  static const Color tabBarBackground = Color(0xFF1E2128);
  static const Color tabBarActive = Color(0xFFFFFFFF);
  static const Color tabBarInactive = Color(0xFF6E7280);

  // Top toolbar
  static const Color toolbarBackground = Color(0xFF2A2E36);
}

class AppTheme {
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.toolbarBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.tabBarBackground,
        selectedItemColor: AppColors.tabBarActive,
        unselectedItemColor: AppColors.tabBarInactive,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
