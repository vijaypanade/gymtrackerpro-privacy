// lib/utils/app_spacing.dart
// Centralised 8-pt spacing system — single source of truth.
// Replaces all per-screen _S classes.
import 'package:flutter/material.dart';

abstract final class AppSpacing {
  AppSpacing._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xxl = 24.0;
  static const double h   = 32.0;

  // Vertical gaps
  static const vGap4  = SizedBox(height: xs);
  static const vGap8  = SizedBox(height: sm);
  static const vGap12 = SizedBox(height: md);
  static const vGap16 = SizedBox(height: lg);
  static const vGap20 = SizedBox(height: xl);
  static const vGap24 = SizedBox(height: xxl);
  static const vGap32 = SizedBox(height: h);

  // Horizontal gaps
  static const hGap4  = SizedBox(width: xs);
  static const hGap8  = SizedBox(width: sm);
  static const hGap12 = SizedBox(width: md);
  static const hGap16 = SizedBox(width: lg);
}
