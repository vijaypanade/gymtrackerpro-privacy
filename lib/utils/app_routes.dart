// lib/utils/app_routes.dart — Phase 3
// Premium page transitions — used throughout the app
import 'package:flutter/material.dart';
import 'app_constants.dart';

/// Right-to-left slide (standard push) — snappier curve
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:        (_, __, ___) => page,
  transitionDuration: AppDurations.slow,
  reverseTransitionDuration: AppDurations.normal,
  transitionsBuilder: (_, anim, sec, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
    return SlideTransition(
      position: Tween<Offset>(
          begin: const Offset(0.08, 0), end: Offset.zero)
          .animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);

/// Bottom-to-top slide (modal / sheet push)
Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:        (_, __, ___) => page,
  transitionDuration: AppDurations.slow,
  reverseTransitionDuration: AppDurations.normal,
  transitionsBuilder: (_, anim, __, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(
          begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(curved),
      child: child,
    );
  },
);

/// Fade + scale (lightweight overlays / dialogs)
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:        (_, __, ___) => page,
  transitionDuration: AppDurations.normal,
  reverseTransitionDuration: AppDurations.fast,
  transitionsBuilder: (_, anim, __, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);

/// Hero-style scale from center (for celebration / full-screen modals)
Route<T> scaleRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:        (_, __, ___) => page,
  transitionDuration: AppDurations.slow,
  reverseTransitionDuration: AppDurations.normal,
  transitionsBuilder: (_, anim, __, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
    return ScaleTransition(
      scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
      child: FadeTransition(opacity: anim, child: child),
    );
  },
);
