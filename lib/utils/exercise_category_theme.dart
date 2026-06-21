// lib/utils/exercise_category_theme.dart
// Centralised category tint colours for exercise tiles.
// Keep tints ultra-subtle (≤6% alpha) so the dark theme dominates.

import 'package:flutter/material.dart';

abstract final class ExerciseCategoryTheme {
  // Raw hue per muscle group — NOT the category accent colours from AppColors.
  // These are slightly warmer/cooler so they read as "identity" not "status".
  static const _hue = <String, Color>{
    'Chest':     Color(0xFFFF3B30), // iOS red
    'Back':      Color(0xFF0A84FF), // iOS blue
    'Legs':      Color(0xFF30D158), // iOS green
    'Shoulders': Color(0xFFFF9F0A), // iOS orange
    'Arms':      Color(0xFFBF5AF2), // iOS purple
    'Core':      Color(0xFFFFD60A), // iOS yellow
    'Cardio':    Color(0xFF32ADE6), // iOS cyan
  };

  /// Very faint category tint for tile background.
  static Color backgroundColor(
    String muscle, {
    bool selected = false,
    required Color accent,
  }) {
    final base = _hue[muscle] ?? accent;
    return selected
        ? base.withValues(alpha: 0.11)
        : base.withValues(alpha: 0.045);
  }

  /// Subtle border matching category identity.
  static Color borderColor(
    String muscle, {
    bool selected = false,
    required Color accent,
  }) {
    final base = _hue[muscle] ?? accent;
    return selected
        ? base.withValues(alpha: 0.48)
        : base.withValues(alpha: 0.12);
  }

  /// Width of the left-side category stripe in grouped section headers.
  static Color stripeColor(String muscle, {required Color accent}) =>
      _hue[muscle] ?? accent;
}
