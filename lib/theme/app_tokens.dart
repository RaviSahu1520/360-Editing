import 'package:flutter/material.dart';

/// Spacing System - 4px base unit
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Border Radius - Consistent 3-scale system
class AppRadius {
  static const double rSmall = 8;
  static const double rMedium = 12;
  static const double rLarge = 16;

  static const BorderRadius allSmall = BorderRadius.all(Radius.circular(rSmall));
  static const BorderRadius allMedium = BorderRadius.all(Radius.circular(rMedium));
  static const BorderRadius allLarge = BorderRadius.all(Radius.circular(rLarge));
}

/// Motion System - Consistent animation timing
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration default_ = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 400);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve sharpCurve = Curves.easeOutQuart;
  static const Curve softCurve = Curves.easeOut;
}

/// Warm Neutral Color Palette
class AppColors {
  // Light Mode - Warm Cream & Grays
  static const Color lightSurface = Color(0xFFFAF9F6); // Warm cream
  static const Color lightSurfaceSubtle = Color(0xFFF1F0ED); // Slightly darker
  static const Color lightBorder = Color(0xFFE5E4E1); // Warm gray border
  static const Color lightBorderSubtle = Color(0xFFEBEAE7);
  static const Color lightText = Color(0xFF1C1C1E); // Near black
  static const Color lightTextSecondary = Color(0xFF636366); // Gray text
  static const Color lightTextTertiary = Color(0xFF8E8E93); // Light gray text

  // Dark Mode - Warm Charcoal
  static const Color darkSurface = Color(0xFF0D0D0D); // Near black
  static const Color darkSurfaceSubtle = Color(0xFF1C1C1E); // Raised surface
  static const Color darkSurfaceElevated = Color(0xFF252527); // Higher elevation
  static const Color darkBorder = Color(0xFF3A3A3C); // Border
  static const Color darkText = Color(0xFFFFFFFF); // White
  static const Color darkTextSecondary = Color(0xFFAEAEB2); // Gray text
  static const Color darkTextTertiary = Color(0xFF636366); // Dim text

  // Accent - Subtle Warm Blue (single accent only)
  static const Color accent = Color(0xFF3B82F6); // Blue 500
  static const Color accentDim = Color(0x1A3B82F6); // 10% opacity
  static const Color accentSubtle = Color(0xFFDBEAFE); // Blue 100

  // Semantic - Minimal colors, only when needed
  static const Color success = Color(0xFF22C55E);
  static const Color successSubtle = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSubtle = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSubtle = Color(0xFFFEF3C7);
}

/// Extension to get colors based on brightness
extension AppColorsExt on BuildContext {
  Color get surface =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface;

  Color get surfaceSubtle =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkSurfaceSubtle
          : AppColors.lightSurfaceSubtle;

  Color get surfaceElevated =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkSurfaceElevated
          : AppColors.lightSurface;

  Color get border =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkBorder
          : AppColors.lightBorder;

  Color get borderSubtle =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkBorder
          : AppColors.lightBorderSubtle;

  Color get textPrimary =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkText
          : AppColors.lightText;

  Color get textSecondary =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;

  Color get textTertiary =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextTertiary
          : AppColors.lightTextTertiary;
}
