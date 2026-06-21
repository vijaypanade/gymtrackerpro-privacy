// lib/models/unified_coach_insight.dart
// One dominant insight per session state — replaces competing card surfaces.
// Consumed by CoachInsightOrchestrator; rendered by _CoachInsightCard.

import 'package:flutter/material.dart';

enum CoachInsightSeverity {
  critical,  // deload, depleted — amber, high visual weight
  elevated,  // suppressed muscle, comeback, high fatigue — gold/amber
  standard,  // post-workout, peak readiness, locked-in — color varies
  quiet,     // stable adapting, rest day — muted
}

class UnifiedCoachInsight {
  final String title;       // primary message (2–3 sentences max)
  final String secondary;   // supporting context (momentum / recovery follow-up)
  final String badge;       // compact state tag: RECOVERY WINDOW, PRIMED, etc.
  final CoachInsightSeverity severity;
  final Color accentColor;  // drives left beam, badge tint, dot

  const UnifiedCoachInsight({
    required this.title,
    required this.secondary,
    required this.badge,
    required this.severity,
    required this.accentColor,
  });

  bool get isEmpty => title.isEmpty;

  static const UnifiedCoachInsight empty = UnifiedCoachInsight(
    title:       '',
    secondary:   '',
    badge:       '',
    severity:    CoachInsightSeverity.quiet,
    accentColor: Color(0xFF6B7280),
  );
}
