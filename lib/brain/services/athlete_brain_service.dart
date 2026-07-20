// lib/brain/services/athlete_brain_service.dart
//
// AthleteBrain V1 — soft memory advisory layer.
// Memory signals nudge ONLY the behavioral adherence inputs (disciplineScore,
// comebackProbability) by at most ±5 % of their valid range. They never
// touch recovery or analytics signals, and they never override hard safety
// constraints produced by RecoveryEngine or AnalyticsEngine.

import 'package:flutter/foundation.dart';

import '../../ai/maturity/allowed_claims.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adaptive_programming_service.dart';
import '../../services/adherence_intelligence_service.dart';
import '../models/biometric_context.dart';
import '../models/decision_context.dart';
import '../models/decision_state.dart';

// ── Memory advisory value object ──────────────────────────────────────────────

/// Encapsulates the soft adjustments derived from AthleteMemorySnapshot.
///
/// Both fields are bounded to ±5 % of their AdaptiveInput field ranges:
///   disciplineScoreDelta    → int,    range [−5, +5]  (field: 0–100)
///   comebackProbabilityDelta → double, range [−0.05, +0.05] (field: 0–1)
///
/// Hard safety signals (recoveryScore, highFatigue, needsDeload, plateau /
/// fatigue trend levels, suppressed muscles) are never adjusted.
class _MemoryAdvisory {
  final int    disciplineScoreDelta;
  final double comebackProbabilityDelta;

  const _MemoryAdvisory({
    required this.disciplineScoreDelta,
    required this.comebackProbabilityDelta,
  });

  const _MemoryAdvisory.zero()
      : disciplineScoreDelta    = 0,
        comebackProbabilityDelta = 0.0;

  bool get isZero =>
      disciplineScoreDelta == 0 && comebackProbabilityDelta == 0.0;
}

class AthleteBrainService {
  const AthleteBrainService();

  AdaptiveWorkoutDecision computeDecision(
    DecisionContext context,
    AllowedClaims allowedClaims,
  ) {
    final validated = _validateContext(context);
    final normalized = _normalizeContext(validated);
    final input = _preparePolicyInput(normalized, allowedClaims);

    AdaptiveWorkoutDecision result;
    try {
      result = AdaptiveProgrammingService.compute(input);
    } catch (error, stackTrace) {
      debugPrint(
        'AthleteBrainService.computeDecision failed: $error\n$stackTrace',
      );
      return AdaptiveWorkoutDecision.baseline;
    }

    // Prepend biometric attribution when a primary suppression signal exists.
    final biometrics = context.biometricContext;
    if (biometrics != null && result.athleteFacingMessage.isNotEmpty) {
      final prefix = _biometricPrefix(biometrics);
      if (prefix.isNotEmpty) {
        debugPrint('[AthleteBrain] biometric attribution: $prefix');
        return result.copyWith(
          athleteFacingMessage: '$prefix ${result.athleteFacingMessage}',
        );
      }
    }
    return result;
  }

  String _biometricPrefix(BiometricContext b) {
    switch (b.primarySignal) {
      case BiometricSignal.hrv:
        final pct = ((b.hrv! - b.hrvBaseline!) / b.hrvBaseline!);
        return pct < -0.25
            ? 'Your recovery data dropped a lot overnight —'
            : 'Your recovery data is a little lower than usual —';
      case BiometricSignal.rhr:
        return 'Your heart rate is higher than usual today (${b.rhr!.round()} bpm) —';
      case BiometricSignal.sleep:
        final hrs = b.sleepHours.toStringAsFixed(1);
        return 'You only slept ${hrs}h last night —';
      case BiometricSignal.none:
        return '';
    }
  }

  DecisionContext _validateContext(DecisionContext context) {
    // Clamp RecoveryState numeric fields to their contract bounds [0, 100].
    final rs                  = context.recoveryState;
    final clampedOverall      = rs.overallScore.clamp(0.0, 100.0);
    final clampedStrainToday  = rs.strainToday.clamp(0.0, 100.0);
    final clampedStrain7d     = rs.strain7d.clamp(0.0, 100.0);
    final needsRecoveryFix    = clampedOverall    != rs.overallScore ||
                                clampedStrainToday != rs.strainToday  ||
                                clampedStrain7d    != rs.strain7d;
    final validRecovery = needsRecoveryFix
        ? rs.copyWith(
            overallScore: clampedOverall,
            strainToday:  clampedStrainToday,
            strain7d:     clampedStrain7d,
          )
        : rs;

    // Clamp AdherenceProfile behavioral signals to their contract bounds.
    final ap               = context.adherenceProfile;
    final clampedDiscipline = ap.disciplineScore.clamp(0, 100);
    final clampedComeback   = ap.comebackProbability.clamp(0.0, 1.0);
    final needsAdherenceFix = clampedDiscipline != ap.disciplineScore ||
                              clampedComeback   != ap.comebackProbability;
    final validAdherence = needsAdherenceFix
        ? AdherenceProfile(
            consistencyIdentity:   ap.consistencyIdentity,
            burnoutRisk:           ap.burnoutRisk,
            streakFragility:       ap.streakFragility,
            intimidationRisk:      ap.intimidationRisk,
            motivationTrend:       ap.motivationTrend,
            comebackProbability:   clampedComeback,
            disciplineScore:       clampedDiscipline,
            preferredSessionStyle: ap.preferredSessionStyle,
            adherenceInsight:      ap.adherenceInsight,
            computedAt:            ap.computedAt,
          )
        : ap;

    if (needsRecoveryFix || needsAdherenceFix) {
      debugPrint(
        '[AthleteBrain] _validateContext clamped out-of-range values — '
        'overall:${rs.overallScore}→$clampedOverall '
        'discipline:${ap.disciplineScore}→$clampedDiscipline '
        'comeback:${ap.comebackProbability.toStringAsFixed(3)}'
        '→${clampedComeback.toStringAsFixed(3)}',
      );
    }

    if (!needsRecoveryFix && !needsAdherenceFix) return context;

    return DecisionContext(
      recoveryState:         validRecovery,
      analyticsSnapshot:     context.analyticsSnapshot,
      predictiveSnapshot:    context.predictiveSnapshot,
      athleteTrend:          context.athleteTrend,
      adherenceProfile:      validAdherence,
      trainingAdjustment:    context.trainingAdjustment,
      workoutContext:        context.workoutContext,
      environmentContext:    context.environmentContext,
      athleteMemorySnapshot: context.athleteMemorySnapshot,
      biometricContext:      context.biometricContext,
    );
  }

  DecisionState _normalizeContext(DecisionContext context) {
    // Builds the DecisionState passed to AdaptiveProgrammingService.
    // All numeric fields arrive pre-validated from _validateContext.
    final memSnap = context.athleteMemorySnapshot;
    if (memSnap != null) {
      debugPrint(
        '[AthleteBrain] memory advisory — '
        'identity:${memSnap.identityStage} '
        'experience:${memSnap.experienceLevel} '
        'consistency:${memSnap.consistencyScore.toStringAsFixed(2)} '
        'progression:${memSnap.progressionVelocity.toStringAsFixed(2)} '
        'recovery:${memSnap.recoveryVelocity.toStringAsFixed(2)} '
        'adherence:${memSnap.adherenceScore.toStringAsFixed(2)} '
        'reliability:${memSnap.reliabilityScore.toStringAsFixed(2)} '
        'volume:${memSnap.volumeTolerance.toStringAsFixed(2)}',
      );
    }
    return DecisionState(
      recoveryState:        context.recoveryState,
      analyticsSnapshot:    context.analyticsSnapshot,
      predictiveSnapshot:   context.predictiveSnapshot,
      athleteTrend:         context.athleteTrend,
      adherenceProfile:     context.adherenceProfile,
      trainingAdjustment:   context.trainingAdjustment,
      workoutContext:       context.workoutContext,
      environmentContext:   context.environmentContext,
      athleteMemorySnapshot: memSnap,
    );
  }

  AdaptiveInput _preparePolicyInput(DecisionState state, AllowedClaims allowedClaims) {
    return _toAdaptiveInput(state, allowedClaims);
  }

  AdaptiveInput _toAdaptiveInput(DecisionState state, AllowedClaims allowedClaims) {
    // Compute soft memory advisory — zero when no snapshot is available.
    final advisory = state.athleteMemorySnapshot != null
        ? _computeMemoryAdvisory(state.athleteMemorySnapshot!)
        : const _MemoryAdvisory.zero();

    if (!advisory.isZero) {
      debugPrint(
        '[AthleteBrain] memory advisory applied — '
        'disciplineDelta:${advisory.disciplineScoreDelta >= 0 ? '+' : ''}${advisory.disciplineScoreDelta} '
        'comebackDelta:${advisory.comebackProbabilityDelta >= 0 ? '+' : ''}${advisory.comebackProbabilityDelta.toStringAsFixed(3)}',
      );
    }

    // ── Safety signals — never modified by memory ─────────────────────────────
    // recoveryScore, highFatigue, needsDeload, recoveryTrend, suppressedMuscles,
    // shouldReduceAxialLoad, overreachingRiskLevel, plateauRiskLevel,
    // fatigueTrendLevel, weeklyImprovementPct, isOnPlateau.

    // ── Behavioral adherence signals — soft memory nudge applied ─────────────
    final rawDiscipline = state.adherenceProfile.disciplineScore;
    final advisedDiscipline =
        (rawDiscipline + advisory.disciplineScoreDelta).clamp(0, 100).toInt();

    final rawComeback = state.adherenceProfile.comebackProbability;
    final advisedComeback =
        (rawComeback + advisory.comebackProbabilityDelta).clamp(0.0, 1.0);

    return AdaptiveInput(
      // ── Recovery (unchanged) ─────────────────────────────────────────────
      recoveryScore:             state.recoveryState.overallScore,
      highFatigue:               state.recoveryState.highFatigue,
      needsDeload:               state.recoveryState.needsDeload,
      recoveryTrend:             state.analyticsSnapshot.recoveryTrend,
      suppressedMuscles:         state.trainingAdjustment.suppressedMuscles,
      shouldReduceAxialLoad:     state.trainingAdjustment.shouldReduceAxialLoad,
      recommendedFocusMuscles:   state.trainingAdjustment.recommendedFocusMuscles,
      // ── Trend (unchanged — analytics always wins) ────────────────────────
      momentumLevel:             state.athleteTrend.momentumState.index,
      overreachingRiskLevel:     state.athleteTrend.overreachingRisk.index,
      plateauRiskLevel:          state.athleteTrend.plateauRisk.index,
      fatigueTrendLevel:         state.athleteTrend.fatigueTrend.index,
      // ── Predictive (unchanged) ───────────────────────────────────────────
      overloadReadinessLevel:    state.predictiveSnapshot.overloadReadiness.index,
      recoveryCollapseRiskLevel: state.predictiveSnapshot.recoveryCollapseRisk.index,
      // ── Adherence — soft memory nudge ±5 % ──────────────────────────────
      burnoutRiskLevel:          state.adherenceProfile.burnoutRisk.index,
      intimidationRiskLevel:     state.adherenceProfile.intimidationRisk.index,
      comebackProbability:       advisedComeback,
      disciplineScore:           advisedDiscipline,
      // ── Analytics (unchanged) ────────────────────────────────────────────
      weeklyImprovementPct:      state.analyticsSnapshot.weeklyImprovementPct,
      isOnPlateau:               state.analyticsSnapshot.isOnPlateau,
      // ── Context (unchanged) ──────────────────────────────────────────────
      daysSinceLastWorkout:      state.workoutContext.daysSinceLastWorkout,
      goal:                      state.workoutContext.goal,
      todayExerciseNames:        state.workoutContext.todayExerciseNames,
      todayExerciseCategories:   state.workoutContext.todayExerciseCategories,
      now:                       state.environmentContext.now,
      // ── AI maturity trust gates ─────────────────────────────────────────
      canShowAdaptiveIncrease:   allowedClaims.ui.canShowAdaptiveIncrease,
      canMakePrediction:         allowedClaims.content.canMakePrediction,
    );
  }

  // ── Memory advisory computation ───────────────────────────────────────────

  /// Derives soft behavioral nudges from the athlete's long-term memory.
  ///
  /// Each rule maps one memory signal to at most a ±5 % adjustment on an
  /// adherence field. Multiple rules may fire simultaneously; the totals are
  /// hard-clamped to [−5, +5] and [−0.05, +0.05] respectively before use.
  ///
  /// Rules (all advisory — never override safety):
  ///  1. consistencyScore < 0.30  → discourage aggressive missions (−5 discipline)
  ///  2. progressionVelocity > 0.75 → lift opportunity signal (+3 discipline, +0.03 comeback)
  ///  3. recoveryVelocity < 0.35  → reduce behavioral confidence (−0.04 comeback)
  ///  4. reliabilityScore < 0.40  → soften aggressive push (−3 discipline)
  ///  5. volumeTolerance > 0.75   → allow higher volume confidence (+0.05 comeback)
  ///  6. identityStage / experienceLevel → advisory only, no numeric adjustment.
  _MemoryAdvisory _computeMemoryAdvisory(AthleteMemorySnapshot mem) {
    int    disciplineDelta = 0;
    double comebackDelta   = 0.0;

    // Rule 1 — low consistency: bias toward maintain, not growth.
    if (mem.consistencyScore < 0.30) {
      disciplineDelta -= 5;
    }

    // Rule 2 — strong progression momentum: lift opportunity signal.
    if (mem.progressionVelocity > 0.75) {
      disciplineDelta += 3;
      comebackDelta   += 0.03;
    }

    // Rule 3 — slow recovery velocity: athlete historically takes longer to
    // bounce back — reduce behavioral confidence without touching RecoveryEngine.
    if (mem.recoveryVelocity < 0.35) {
      comebackDelta -= 0.04;
    }

    // Rule 4 — low reliability: athlete has low follow-through signal —
    // soften the push toward aggressive missions.
    if (mem.reliabilityScore < 0.40) {
      disciplineDelta -= 3;
    }

    // Rule 5 — high volume tolerance: athlete handles volume well historically —
    // allow a slight positive confidence bias on comeback estimates.
    if (mem.volumeTolerance > 0.75) {
      comebackDelta += 0.05;
    }

    // Rule 6 — identityStage / experienceLevel: advisory only, no adjustment.
    // These values are available in DecisionState for future policy use.

    // Clamp totals to ±5 % bounds before returning.
    return _MemoryAdvisory(
      disciplineScoreDelta:     disciplineDelta.clamp(-5, 5),
      comebackProbabilityDelta: comebackDelta.clamp(-0.05, 0.05),
    );
  }
}
