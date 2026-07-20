// lib/utils/app_typography.dart
//
// RFC-TYPOGRAPHY-001 — platform-aware typography scale.
//
// The iOS readability pass raised most font sizes by +1/+2sp (a near-uniform
// +7–8%). On Android that reads oversized. Rather than forking ~300 text
// styles per platform, ONE optical factor is applied to all text on Android,
// restoring the pre-pass compact scale within ±0.5sp while preserving the
// visual hierarchy exactly. iOS is untouched (factor 1.0).
//
// This is the ONLY place in the codebase allowed to make a platform decision
// about typography. Widgets never check Platform — they keep declaring their
// iOS-tuned sizes and the scaler applied in MaterialApp.builder (main.dart)
// resolves the platform.
//
// The system accessibility text scale is respected: the platform factor
// multiplies it rather than replacing it.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppTypography {
  AppTypography._();

  /// Android optical factor. 0.93 maps the iOS pass back to its pre-pass
  /// Android values: 14→13.0, 13→12.1, 12→11.2, 10→9.3 (≈ the -1sp body /
  /// -1sp secondary / -2sp heading targets of RFC-TYPOGRAPHY-001).
  static const double _androidFactor = 0.93;

  static double get platformTextFactor =>
      defaultTargetPlatform == TargetPlatform.android ? _androidFactor : 1.0;

  /// The effective text scaler for the app — system accessibility scale
  /// multiplied by the platform factor. Hooked once in MaterialApp.builder.
  static TextScaler scalerFor(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    if (defaultTargetPlatform != TargetPlatform.android) return system;
    return TextScaler.linear(system.scale(1.0) * _androidFactor);
  }
}
