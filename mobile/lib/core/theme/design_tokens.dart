import 'package:flutter/material.dart';
import 'app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Spacing — 4px base scale
// ─────────────────────────────────────────────────────────────────────────────

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ─────────────────────────────────────────────────────────────────────────────
// Border Radius
// ─────────────────────────────────────────────────────────────────────────────

class AppRadius {
  static const double sm = 6; // chips, badges, small tags
  static const double md = 10; // buttons, cards, inputs
  static const double lg = 14; // bottom sheets, modals
  static const double xl = 20; // large overlays
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography — semantic text styles
//
// Usage: Text('Hello', style: AppText.heading)
// Override color: Text('Hello', style: AppText.heading.copyWith(color: ...))
// ─────────────────────────────────────────────────────────────────────────────

class AppText {
  /// Screen/page titles — 18px semibold
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Section/card headings — 15px semibold
  static const heading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Primary body text — 14px regular
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Secondary body text — 14px regular, muted
  static const bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Small body text — 13px regular
  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Caption/metadata — 12px regular
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  /// Section labels — 12px semibold, wider tracking (ALL CAPS)
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  /// Tiny overline — 11px semibold, wide tracking
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.textMuted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shadows — two elevation levels
// ─────────────────────────────────────────────────────────────────────────────

class AppShadows {
  static const subtle = [
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const elevated = [
    BoxShadow(
      color: Color(0x50000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
