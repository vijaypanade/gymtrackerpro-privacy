// lib/models/coach_visual_state.dart
// Visual state system for the AI coach. Maps athlete data → design parameters.
// No Flutter deps except Color + IconData so it stays testable.

import 'package:flutter/material.dart';
import 'coach_context.dart';

// ════════════════════════════════════════════
// COACH VISUAL STATE
// ════════════════════════════════════════════
enum CoachVisualState {
  momentum,   // PR hit in last 24 h — gold glow, fast pulse
  recovery,   // muscle below 40% — cyan, slow breathing
  warning,    // volume spike — amber, restrained
  aggressive, // all muscles ready >75% — orange edge, tight
  calm,       // deload week — soft purple, very slow
  scientific, // beginner phase — blue, steady
  lockedIn,   // default premium state
}

// ════════════════════════════════════════════
// THEME DATA PER STATE
// ════════════════════════════════════════════
class CoachVisualTheme {
  final Color   accent;
  final Color   bg;
  final Color   iconBg;
  final IconData icon;
  final String  label;          // shown as chip next to "AI COACH"
  final int     pulsePeriodMs;  // AnimationController duration
  final double  glowMin;        // border/shadow alpha at anim=0
  final double  glowMax;        // border/shadow alpha at anim=1
  final FontWeight messageFontWeight;

  const CoachVisualTheme({
    required this.accent,
    required this.bg,
    required this.iconBg,
    required this.icon,
    required this.label,
    required this.pulsePeriodMs,
    required this.glowMin,
    required this.glowMax,
    required this.messageFontWeight,
  });

  static CoachVisualTheme forState(CoachVisualState state) {
    switch (state) {
      case CoachVisualState.momentum:
        return const CoachVisualTheme(
          accent:             Color(0xFFFFD700),
          bg:                 Color(0xFF0C0900),
          iconBg:             Color(0xFF1A1500),
          icon:               Icons.trending_up_rounded,
          label:              'MOMENTUM',
          pulsePeriodMs:      1100,
          glowMin:            0.14,
          glowMax:            0.32,
          messageFontWeight:  FontWeight.w600,
        );
      case CoachVisualState.recovery:
        return const CoachVisualTheme(
          accent:             Color(0xFF22D3EE),
          bg:                 Color(0xFF060C0D),
          iconBg:             Color(0xFF071215),
          icon:               Icons.self_improvement_rounded,
          label:              'RECOVERY',
          pulsePeriodMs:      2600,
          glowMin:            0.06,
          glowMax:            0.16,
          messageFontWeight:  FontWeight.w400,
        );
      case CoachVisualState.warning:
        return const CoachVisualTheme(
          accent:             Color(0xFFF59E0B),
          bg:                 Color(0xFF0C0A06),
          iconBg:             Color(0xFF140F04),
          icon:               Icons.show_chart_rounded,
          label:              'CAUTION',
          pulsePeriodMs:      1800,
          glowMin:            0.08,
          glowMax:            0.22,
          messageFontWeight:  FontWeight.w500,
        );
      case CoachVisualState.aggressive:
        return const CoachVisualTheme(
          accent:             Color(0xFFFF6B35),
          bg:                 Color(0xFF0D0806),
          iconBg:             Color(0xFF180D08),
          icon:               Icons.local_fire_department_rounded,
          label:              'PEAKED',
          pulsePeriodMs:      950,
          glowMin:            0.14,
          glowMax:            0.34,
          messageFontWeight:  FontWeight.w700,
        );
      case CoachVisualState.calm:
        return const CoachVisualTheme(
          accent:             Color(0xFFA78BFA),
          bg:                 Color(0xFF09080F),
          iconBg:             Color(0xFF0E0B18),
          icon:               Icons.waves_rounded,
          label:              'DELOAD',
          pulsePeriodMs:      3200,
          glowMin:            0.05,
          glowMax:            0.14,
          messageFontWeight:  FontWeight.w400,
        );
      case CoachVisualState.scientific:
        return const CoachVisualTheme(
          accent:             Color(0xFF60A5FA),
          bg:                 Color(0xFF060A0D),
          iconBg:             Color(0xFF080E16),
          icon:               Icons.analytics_rounded,
          label:              'BUILDING',
          pulsePeriodMs:      2200,
          glowMin:            0.07,
          glowMax:            0.18,
          messageFontWeight:  FontWeight.w500,
        );
      case CoachVisualState.lockedIn:
        return const CoachVisualTheme(
          accent:             Color(0xFFD4AF37),
          bg:                 Color(0xFF0D0C0A),
          iconBg:             Color(0xFF131100),
          icon:               Icons.hub_rounded,
          label:              'LIVE',
          pulsePeriodMs:      2000,
          glowMin:            0.06,
          glowMax:            0.16,
          messageFontWeight:  FontWeight.w500,
        );
    }
  }
}

// ════════════════════════════════════════════
// MOTION PRESETS
// ════════════════════════════════════════════
enum LiftOnMotion {
  subtleFloat,     // gentle vertical oscillation
  pulseGlow,       // alpha + blur repeating pulse
  calmFade,        // slow opacity transition
  tacticalReveal,  // fade + upward slide — message text entry
  momentumRise,    // scale + opacity — PR / stat entrance
}

// ════════════════════════════════════════════
// FACTORY — derives visual state from context
// ════════════════════════════════════════════
extension CoachVisualStateX on CoachVisualState {
  CoachVisualTheme get theme => CoachVisualTheme.forState(this);

  static CoachVisualState fromContext(CoachContext ctx) {
    // PR in last 24 h → high energy
    final pr = ctx.latestPR;
    if (pr != null && DateTime.now().difference(pr.date).inHours < 24) {
      return CoachVisualState.momentum;
    }
    // Volume spike → caution
    if (ctx.hasVolumeSpike) return CoachVisualState.warning;
    // Severe fatigue → recovery
    final fatigued = ctx.mostFatiguedMuscle;
    if (fatigued != null && fatigued.value < 40) return CoachVisualState.recovery;
    // Deload week
    if (ctx.isDeloadWeek) return CoachVisualState.calm;
    // Beginner
    if (ctx.totalWorkouts < 20) return CoachVisualState.scientific;
    // All muscles ≥ 75% recovered → push day
    if (ctx.muscleRecovery.isNotEmpty &&
        ctx.muscleRecovery.values.every((v) => v >= 75) &&
        ctx.totalWorkouts >= 20) {
      return CoachVisualState.aggressive;
    }
    return CoachVisualState.lockedIn;
  }
}
