// lib/services/coach_insight_orchestrator.dart
// Produces ONE dominant UnifiedCoachInsight from all available intelligence signals.
//
// Priority chain:
//   P0 — critical recovery / overload (deload, depleted)
//   P1 — workout phase (post-workout, comeback, rest day)
//   P2 — pre-workout readiness (peak, suppressed, high fatigue)
//   P3 — momentum signals (locked-in, rising, at-risk)
//   P4 — stable / adapting default

import 'package:flutter/material.dart';
import '../models/unified_coach_insight.dart';
import '../models/momentum_state.dart';
import '../models/recovery_state.dart';
import 'narrative_orchestrator.dart'; // NarrativeContext, NarrativePhase

class CoachInsightOrchestrator {
  CoachInsightOrchestrator._();

  // ── Accent palette ────────────────────────────────────────────────────────
  static const _cyan   = Color(0xFF22D3EE); // rising momentum
  static const _green  = Color(0xFF22C55E); // peak readiness, locked-in
  static const _amber  = Color(0xFFF59E0B); // post-workout, critical fatigue
  static const _gold   = Color(0xFFD4AF37); // protected training, PR
  static const _orange = Color(0xFFFF6B35); // locked-in momentum
  static const _blue   = Color(0xFF60A5FA); // rest day, comeback
  static const _muted  = Color(0xFF6B7280); // default adapting

  static UnifiedCoachInsight compute({
    required NarrativeContext ctx,
    required MomentumState momentum,
    required RecoveryState recovery,
  }) {
    // ── P0: Critical overload / deload ────────────────────────────────────
    if (recovery.needsDeload) {
      return UnifiedCoachInsight(
        title:      'Accumulated strain exceeds recovery capacity. '
                    'A reduced-volume week now maximises long-term adaptation.',
        secondary:  _momentumSecondary(momentum),
        badge:      'DELOAD PHASE',
        severity:   CoachInsightSeverity.critical,
        accentColor: _amber,
      );
    }

    if (recovery.readiness == RecoveryReadiness.depleted &&
        recovery.highFatigue) {
      final lm = recovery.primaryLimitingMuscle;
      final note = lm.isNotEmpty
          ? '${_cap(lm)} fatigue is the primary constraint. '
          : 'Multiple muscle groups are under-recovered. ';
      return UnifiedCoachInsight(
        title:      '${note}Training demand exceeds current recovery — '
                    'reduce stimulus and prioritise sleep.',
        secondary:  _momentumSecondary(momentum),
        badge:      'UNDER-RECOVERED',
        severity:   CoachInsightSeverity.critical,
        accentColor: _amber,
      );
    }

    // ── P1a: Post-workout ────────────────────────────────────────────────
    if (ctx.phase == NarrativePhase.postWorkout) {
      return _postWorkout(ctx, momentum);
    }

    // ── P1b: Comeback ────────────────────────────────────────────────────
    if (ctx.phase == NarrativePhase.comeback) {
      return UnifiedCoachInsight(
        title:      'Consistency rebuilding. One quality session today '
                    'restores the performance rhythm.',
        secondary:  momentum.atRisk
                      ? 'Momentum recovering — show up again tomorrow.'
                      : _momentumSecondary(momentum),
        badge:      'COMEBACK',
        severity:   CoachInsightSeverity.elevated,
        accentColor: _blue,
      );
    }

    // ── P1c: Rest day ────────────────────────────────────────────────────
    if (ctx.phase == NarrativePhase.restDay) {
      return UnifiedCoachInsight(
        title:      'Planned recovery day. Muscles rebuild and adapt during '
                    'rest — passive recovery is part of the training stimulus.',
        secondary:  momentum.lockedIn
                      ? 'Performance rhythm remains intact.'
                      : 'Quality sleep tonight supports tomorrow\'s session.',
        badge:      'REST DAY',
        severity:   CoachInsightSeverity.quiet,
        accentColor: _blue,
      );
    }

    // ── P2: Pre-workout readiness signals ─────────────────────────────────

    // Peak recovery window — green-light day
    if (recovery.readiness == RecoveryReadiness.peak) {
      final ready = ctx.readyMuscles.isNotEmpty ? ctx.readyMuscles.first : '';
      final muscleNote = ready.isNotEmpty
          ? '${_cap(ready)} primed for high-stimulus training. '
          : 'Full recovery achieved across primary movers. ';
      return UnifiedCoachInsight(
        title:      'Recovery trending upward. High-quality training window '
                    'detected. ${muscleNote}Volume tolerance remains stable.',
        secondary:  _momentumSecondary(momentum),
        badge:      'PRIMED',
        severity:   CoachInsightSeverity.standard,
        accentColor: _green,
      );
    }

    // Suppressed limiting muscle — protective programming indicated
    if (ctx.recoverySuppressed && ctx.limitingMuscle.isNotEmpty) {
      final m = _cap(ctx.limitingMuscle);
      return UnifiedCoachInsight(
        title:      '$m fatigue still elevated. Today\'s session protects '
                    'progression while managing joint and spinal stress.',
        secondary:  'Movement quality prioritised over load.',
        badge:      'PROTECTED TRAINING',
        severity:   CoachInsightSeverity.elevated,
        accentColor: _gold,
      );
    }

    // High fatigue without a specific limiting muscle
    if (ctx.highFatigue) {
      return const UnifiedCoachInsight(
        title:      'Fatigue accumulating across primary muscle groups. '
                    'Controlled, quality movement today outperforms heavy load.',
        secondary:  'Stimulus remains effective — effort governs adaptation, '
                    'not absolute weight.',
        badge:      'HIGH FATIGUE',
        severity:   CoachInsightSeverity.elevated,
        accentColor: _amber,
      );
    }

    // ── P3: Momentum signals ──────────────────────────────────────────────

    if (momentum.lockedIn) {
      return const UnifiedCoachInsight(
        title:      'Consistency is accelerating. Protect the rhythm — '
                    'this is where adaptation compounds.',
        secondary:  'Volume tolerance and recovery efficiency trending upward.',
        badge:      'LOCKED IN',
        severity:   CoachInsightSeverity.standard,
        accentColor: _orange,
      );
    }

    if (momentum.rising) {
      return const UnifiedCoachInsight(
        title:      'Training momentum is climbing faster than baseline. '
                    'Progressive overload is taking effect.',
        secondary:  'Recovery markers support continued progression.',
        badge:      'PROGRESSING',
        severity:   CoachInsightSeverity.standard,
        accentColor: _cyan,
      );
    }

    if (momentum.atRisk && !momentum.workedOutToday) {
      return const UnifiedCoachInsight(
        title:      'Consistency rhythm has been disrupted. One session today '
                    'restores the adaptation cycle.',
        secondary:  'Momentum responds faster to action than to additional rest.',
        badge:      'MOMENTUM AT RISK',
        severity:   CoachInsightSeverity.elevated,
        accentColor: _amber,
      );
    }

    // ── P4: Stable / adapting default ────────────────────────────────────
    final readyNote = ctx.readyMuscles.isNotEmpty
        ? '${_cap(ctx.readyMuscles.first)} is primed for stimulus. '
        : '';
    return UnifiedCoachInsight(
      title:      '${readyNote}Training system stable and responsive. '
                  'Recovery markers support consistent progression.',
      secondary:  _momentumSecondary(momentum),
      badge:      _stateLabel(recovery, momentum),
      severity:   CoachInsightSeverity.quiet,
      accentColor: _muted,
    );
  }

  // ── Post-workout sub-cases ────────────────────────────────────────────────
  static UnifiedCoachInsight _postWorkout(
    NarrativeContext ctx,
    MomentumState momentum,
  ) {
    final trained   = ctx.trainedToday;
    final secondary = momentum.lockedIn || momentum.rising
        ? 'Momentum climbing — consistency compounds the adaptation.'
        : momentum.workedOutToday && momentum.score >= 60
            ? 'Performance rhythm intact — consecutive sessions accelerate progress.'
            : 'Adaptation window active.';

    if (ctx.prToday && trained.isNotEmpty) {
      return UnifiedCoachInsight(
        title:      '${_cap(trained.first)} PR locked in. Recovery demand '
                    'elevated — protein synthesis active for the next 24–48h.',
        secondary:  secondary,
        badge:      'PR ACHIEVED',
        severity:   CoachInsightSeverity.elevated,
        accentColor: _gold,
      );
    }

    if (trained.length >= 2) {
      final a = _cap(trained[0]);
      final b = _cap(trained[1]);
      return UnifiedCoachInsight(
        title:      '$a + $b session complete. Recovery demand elevated — '
                    'prioritise protein and quality sleep.',
        secondary:  secondary,
        badge:      'RECOVERY WINDOW',
        severity:   CoachInsightSeverity.standard,
        accentColor: _amber,
      );
    }

    if (trained.isNotEmpty) {
      return UnifiedCoachInsight(
        title:      '${_cap(trained.first)} session logged. Protein synthesis '
                    'elevated — sleep and nutrition complete the adaptation.',
        secondary:  secondary,
        badge:      'RECOVERY WINDOW',
        severity:   CoachInsightSeverity.standard,
        accentColor: _amber,
      );
    }

    return UnifiedCoachInsight(
      title:      'Session complete. Adaptation window active for the next '
                  '24–48h. Protein and sleep drive the rebuild.',
      secondary:  secondary,
      badge:      'RECOVERY WINDOW',
      severity:   CoachInsightSeverity.standard,
      accentColor: _amber,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _momentumSecondary(MomentumState m) {
    if (m.lockedIn)         return 'Performance rhythm at peak consistency.';
    if (m.rising)           return 'Momentum trending above baseline.';
    if (m.atRisk)           return 'Momentum at risk — one session stabilises the trajectory.';
    if (m.workedOutToday)   return 'Consistency maintained — adaptation is accumulating.';
    return 'Consistent training builds compounding adaptation.';
  }

  static String _stateLabel(RecoveryState r, MomentumState m) {
    if (r.readiness == RecoveryReadiness.ready)    return 'MOVEMENT EFFICIENT';
    if (r.readiness == RecoveryReadiness.moderate) return 'ADAPTING';
    if (r.readiness == RecoveryReadiness.low)      return 'RECOVERING';
    if (m.workedOutToday)                          return 'ACTIVE';
    return 'ADAPTING';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
