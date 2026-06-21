// lib/utils/muscle_color_utils.dart
// Maps recovery score + animation state → fill color and opacity for SVG layers.
// Intentionally low opacities — SVG layers provide anatomical FORM,
// the MuscleGlowPainter provides cinematic DEPTH and luminescence.

import 'package:flutter/material.dart';

class MuscleColorUtils {
  MuscleColorUtils._();

  // Emerald-cyan blend: controlled and elegant (not neon gaming green).
  static const Color _readyColor =
      Color(0xFF1CB87A); // lerp(#22C55E, #06B6D4, 0.22) pre-computed

  // SVG fill color driven by recovery tier.
  static Color fillColor(double recovery) {
    if (recovery >= 80) return _readyColor;
    if (recovery >= 60) return const Color(0xFFF59E0B); // amber
    if (recovery >= 40) return const Color(0xFFEF4444); // red
    return const Color(0xFFDC2626);                      // deep red
  }

  // SVG layer fill opacity — intentionally restrained so glow painter dominates.
  // pulse: 0–1 animation value (fast 2600ms or slow 4500ms cycle).
  static double fillOpacity({
    required double recovery,
    required double pulse,
    required bool isActive,
    required double focusAmount,
    required bool isFocused, // this muscle is the focused one
  }) {
    if (recovery >= 99) return 0.0; // fully recovered — invisible

    final double base;
    final double pulseAmp;

    if (recovery >= 80) {
      base     = isActive ? 0.22 : 0.12;
      pulseAmp = isActive ? 0.06 : 0.025;
    } else if (recovery >= 60) {
      base     = isActive ? 0.30 : 0.18;
      pulseAmp = isActive ? 0.08 : 0.04;
    } else {
      base     = isActive ? 0.36 : 0.22;
      pulseAmp = isActive ? 0.10 : 0.05;
    }

    final dimFactor = 1.0 - focusAmount * (isFocused ? 0.0 : 0.75);
    return ((base + pulse * pulseAmp) * dimFactor).clamp(0.0, 1.0);
  }
}
