import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Change this import to switch palettes ────────────────────────────────
import 'palette_tropiq.dart'; // swap to 'palette_original.dart' to revert
// ─────────────────────────────────────────────────────────────────────────

// Re-export design tokens so consumers only need one import.
export 'design_tokens.dart';

class AppColors {
  // Surfaces (from active palette)
  static const Color background = kBackground;
  static const Color surface = kSurface;
  static const Color surfaceLight = kSurfaceLight;
  static const Color card = kCard;
  static const Color divider = kDivider;

  // Text (from active palette)
  static const Color textPrimary = kTextPrimary;
  static const Color textSecondary = kTextSecondary;
  static const Color textMuted = kTextMuted;

  // Accent (from active palette)
  static const Color primary = kPrimary;
  static const Color accent = kAccent;

  // Aviation-specific (shared across all palettes)
  static const Color routeMagenta = Color(0xFFFF00FF);
  static const Color vfr = Color(0xFF00C853);
  static const Color mvfr = Color(0xFF2196F3);
  static const Color ifr = Color(0xFFFF1744);
  static const Color lifr = Color(0xFFE040FB);

  // Status (shared across all palettes)
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF29B6F6);

  // Semantic (shared across all palettes)
  static const Color starred = Color(0xFFFFCA28); // star/favourite icons
  static const Color scrim = Color(0x61000000); // overlay dim (~38%)

  // Tab bar (from active palette)
  static const Color tabBarBackground = kTabBarBackground;
  static const Color tabBarActive = kTabBarActive;
  static const Color tabBarInactive = kTabBarInactive;

  // Top toolbar (from active palette)
  static const Color toolbarBackground = kToolbarBackground;
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

      // ── App bar ──────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.toolbarBackground,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
      ),

      // ── Bottom nav ───────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.tabBarBackground,
        selectedItemColor: AppColors.tabBarActive,
        unselectedItemColor: AppColors.tabBarInactive,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      // ── Cards ────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      // ── Dividers ─────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
      ),

      // ── Tab bar ──────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),

      // ── Buttons ──────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Input fields ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
