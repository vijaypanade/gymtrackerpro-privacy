// lib/services/predictive_performance_service.dart
// Pure Dart — no Flutter imports.
// Forecasts near-future athlete states from recovery, trend, and adherence signals.
//
// SAFETY CONTRACT:
//   Predictions are probabilistic and observational — never deterministic.
//   No fake certainty, no medical framing, no manipulative urgency.
//   Never: "You will plateau." / "You are overtraining."
//   Always: coach-like, calm, future-oriented.

// ── Enums ─────────────────────────────────────────────────────────────────────

enum StreakBreakRisk { low, moderate, high }

enum OverloadReadiness { notReady, possible, elevated, prime }

enum RecoveryCollapseRisk { low, moderate, high }

enum ProjectedMomentum { declining, flat, building, peaking }

enum ProjectedFatigue { stable, accumulating, elevating, critical }

enum ProjectedConsistency { declining, inconsistent, stable, building }

// ── Display extension ─────────────────────────────────────────────────────────

extension OverloadReadinessX on OverloadReadiness {
  String get label => switch (this) {
    OverloadReadiness.prime    => 'PRIME',
    OverloadReadiness.elevated => 'ELEVATED',
    OverloadReadiness.possible => 'POSSIBLE',
    OverloadReadiness.notReady => 'LIMITED',
  };
}

// ── Output model ─────────────────────────────────────────────────────────────

class PredictiveSnapshot {
  /// 0–1 estimated probability that adaptation is stalling.
  final double plateauProbability;
  final StreakBreakRisk streakBreakRisk;
  final OverloadReadiness overloadReadiness;
  final RecoveryCollapseRisk recoveryCollapseRisk;
  final ProjectedMomentum projectedMomentum;
  final ProjectedFatigue projectedFatigue;
  final ProjectedConsistency projectedConsistency;
  /// "3–5 days" advisory or empty when no window is predicted.
  final String nextBestPRWindow;
  /// One-line training window summary.
  final String recommendedTrainingWindow;
  /// Primary observational insight — empty when no significant signal.
  final String predictiveInsight;
  final DateTime computedAt;

  const PredictiveSnapshot({
    required this.plateauProbability,
    required this.streakBreakRisk,
    required this.overloadReadiness,
    required this.recoveryCollapseRisk,
    required this.projectedMomentum,
    required this.projectedFatigue,
    required this.projectedConsistency,
    required this.nextBestPRWindow,
    required this.recommendedTrainingWindow,
    required this.predictiveInsight,
    required this.computedAt,
  });

  static PredictiveSnapshot get empty => PredictiveSnapshot(
    plateauProbability:        0.0,
    streakBreakRisk:           StreakBreakRisk.low,
    overloadReadiness:         OverloadReadiness.possible,
    recoveryCollapseRisk:      RecoveryCollapseRisk.low,
    projectedMomentum:         ProjectedMomentum.flat,
    projectedFatigue:          ProjectedFatigue.stable,
    projectedConsistency:      ProjectedConsistency.stable,
    nextBestPRWindow:          '',
    recommendedTrainingWindow: '',
    predictiveInsight:         '',
    computedAt:                DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Input contract ────────────────────────────────────────────────────────────

class PredictiveInput {
  // ── Recovery signals ─────────────────────────────────────────────────────
  final double recoveryScore;         // 0–100
  final bool   highFatigue;
  final bool   needsDeload;
  final String recoveryTrend;         // 'improving' | 'stable' | 'declining'

  // ── Athlete trend signals (ordinals — avoids import coupling) ─────────────
  /// MomentumLevel.index (0=declining … 3=peaking)
  final int    momentumLevel;
  /// PlateauRisk.index (0=none … 3=high)
  final int    plateauRiskLevel;
  /// OverreachingRisk.index (0=none … 3=high)
  final int    overreachingRiskLevel;
  /// FatigueTrend.index (0=improving … 3=suppressed)
  final int    fatigueTrendLevel;
  /// ConsistencyTrend.index (0=declining … 3=building)
  final int    consistencyTrendLevel;
  /// PRs completed per week, averaged over the last 4 weeks.
  final double progressionVelocity;

  // ── Adherence signals (ordinals) ──────────────────────────────────────────
  /// BurnoutRisk.index (0=none … 3=high)
  final int    burnoutRiskLevel;
  /// StreakFragility.index (0=resilient … 3=critical)
  final int    streakFragilityLevel;
  /// MotivationTrend.index (0=rising … 3=dropping)
  final int    motivationTrendLevel;
  /// IntimidationRisk.index (0=none … 3=high)
  final int    intimidationRiskLevel;
  final double comebackProbability;   // 0–1

  // ── Analytics signals ─────────────────────────────────────────────────────
  final double overTrainingRisk;      // 0–100
  final double fatigueIndex;          // 0–100
  final double weeklyImprovementPct;  // can be negative
  final bool   isOnPlateau;

  // ── Workout / memory signals ──────────────────────────────────────────────
  final double weeklyVolumeKg;
  final double previousWeeklyVolumeKg;
  final double avgWeeklyVolumeKg;
  final int    currentStreak;
  final int    daysSinceLastWorkout;
  final int    prsLast21Days;
  final int    totalWorkouts;
  final int    consistencyScore;      // 0–100
  final int    missedWorkoutsLast30;
  final DateTime now;

  const PredictiveInput({
    required this.recoveryScore,
    required this.highFatigue,
    required this.needsDeload,
    required this.recoveryTrend,
    required this.momentumLevel,
    required this.plateauRiskLevel,
    required this.overreachingRiskLevel,
    required this.fatigueTrendLevel,
    required this.consistencyTrendLevel,
    required this.progressionVelocity,
    required this.burnoutRiskLevel,
    required this.streakFragilityLevel,
    required this.motivationTrendLevel,
    required this.intimidationRiskLevel,
    required this.comebackProbability,
    required this.overTrainingRisk,
    required this.fatigueIndex,
    required this.weeklyImprovementPct,
    required this.isOnPlateau,
    required this.weeklyVolumeKg,
    required this.previousWeeklyVolumeKg,
    required this.avgWeeklyVolumeKg,
    required this.currentStreak,
    required this.daysSinceLastWorkout,
    required this.prsLast21Days,
    required this.totalWorkouts,
    required this.consistencyScore,
    required this.missedWorkoutsLast30,
    required this.now,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class PredictivePerformanceService {
  PredictivePerformanceService._();

  static PredictiveSnapshot compute(PredictiveInput i) {
    if (i.totalWorkouts < 5) return PredictiveSnapshot.empty;

    final bool volumeSpike = i.avgWeeklyVolumeKg > 0 &&
        i.weeklyVolumeKg > i.avgWeeklyVolumeKg * 1.25;

    // ── 1. Plateau probability ───────────────────────────────────────────
    final plateauProb = _plateauProbability(
      plateauRiskLevel:     i.plateauRiskLevel,
      isOnPlateau:          i.isOnPlateau,
      progressionVelocity:  i.progressionVelocity,
      weeklyImprovementPct: i.weeklyImprovementPct,
      consistencyTrend:     i.consistencyTrendLevel,
    );

    // ── 2. Recovery collapse risk ────────────────────────────────────────
    final collapse = _collapseRisk(
      overreachingLevel: i.overreachingRiskLevel,
      fatigueTrend:      i.fatigueTrendLevel,
      highFatigue:       i.highFatigue,
      overTrainingRisk:  i.overTrainingRisk,
      recoveryScore:     i.recoveryScore,
      volumeSpike:       volumeSpike,
      recoveryTrend:     i.recoveryTrend,
    );

    // ── 3. Overload readiness ────────────────────────────────────────────
    final overload = _overloadReadiness(
      recoveryScore:     i.recoveryScore,
      momentumLevel:     i.momentumLevel,
      highFatigue:       i.highFatigue,
      overreachingLevel: i.overreachingRiskLevel,
      fatigueTrend:      i.fatigueTrendLevel,
      needsDeload:       i.needsDeload,
      collapse:          collapse,
    );

    // ── 4. Streak break risk ─────────────────────────────────────────────
    final streakRisk = _streakBreakRisk(
      fragility:    i.streakFragilityLevel,
      motivTrend:   i.motivationTrendLevel,
      daysSince:    i.daysSinceLastWorkout,
      intimidation: i.intimidationRiskLevel,
      burnout:      i.burnoutRiskLevel,
    );

    // ── 5. Projected momentum (7–14 day) ─────────────────────────────────
    final projMomentum = _projectedMomentum(
      currentMomentum:   i.momentumLevel,
      overloadReadiness: overload,
      overreachingLevel: i.overreachingRiskLevel,
      fatigueTrend:      i.fatigueTrendLevel,
      burnout:           i.burnoutRiskLevel,
      recoveryTrend:     i.recoveryTrend,
    );

    // ── 6. Projected fatigue (7–14 day) ──────────────────────────────────
    final projFatigue = _projectedFatigue(
      overreachingLevel: i.overreachingRiskLevel,
      fatigueTrend:      i.fatigueTrendLevel,
      volumeSpike:       volumeSpike,
      highFatigue:       i.highFatigue,
    );

    // ── 7. Projected consistency (next 4 weeks) ───────────────────────────
    final projConsistency = _projectedConsistency(
      consistencyTrend: i.consistencyTrendLevel,
      burnout:          i.burnoutRiskLevel,
      motivTrend:       i.motivationTrendLevel,
      fragility:        i.streakFragilityLevel,
      daysSince:        i.daysSinceLastWorkout,
    );

    // ── 8. PR window prediction ───────────────────────────────────────────
    final prWindow = _prWindow(
      overload:            overload,
      projMomentum:        projMomentum,
      prsLast21:           i.prsLast21Days,
      progressionVelocity: i.progressionVelocity,
    );

    // ── 9. Training window advisory ───────────────────────────────────────
    final trainingWindow = _trainingWindow(overload);

    // ── 10. Primary predictive insight ────────────────────────────────────
    final insight = _insight(
      collapse:          collapse,
      plateauProb:       plateauProb,
      streakRisk:        streakRisk,
      overload:          overload,
      projMomentum:      projMomentum,
      projFatigue:       projFatigue,
      overreachingLevel: i.overreachingRiskLevel,
      daysSince:         i.daysSinceLastWorkout,
      prWindow:          prWindow,
    );

    return PredictiveSnapshot(
      plateauProbability:        plateauProb,
      streakBreakRisk:           streakRisk,
      overloadReadiness:         overload,
      recoveryCollapseRisk:      collapse,
      projectedMomentum:         projMomentum,
      projectedFatigue:          projFatigue,
      projectedConsistency:      projConsistency,
      nextBestPRWindow:          prWindow,
      recommendedTrainingWindow: trainingWindow,
      predictiveInsight:         insight,
      computedAt:                i.now,
    );
  }

  // ── Plateau probability ───────────────────────────────────────────────────

  static double _plateauProbability({
    required int    plateauRiskLevel,
    required bool   isOnPlateau,
    required double progressionVelocity,
    required double weeklyImprovementPct,
    required int    consistencyTrend,
  }) {
    final base = switch (plateauRiskLevel) {
      3 => 0.72,
      2 => 0.48,
      1 => 0.24,
      _ => 0.08,
    };

    double prob = base;
    if (isOnPlateau)               prob += 0.15;
    if (progressionVelocity < 0.5) prob += 0.10;
    if (weeklyImprovementPct < 0)  prob += 0.08;
    // Low consistency can mask plateau signals — reduce confidence slightly
    if (consistencyTrend <= 1)     prob -= 0.05;

    return prob.clamp(0.0, 0.95);
  }

  // ── Recovery collapse risk ────────────────────────────────────────────────

  static RecoveryCollapseRisk _collapseRisk({
    required int    overreachingLevel,
    required int    fatigueTrend,
    required bool   highFatigue,
    required double overTrainingRisk,
    required double recoveryScore,
    required bool   volumeSpike,
    required String recoveryTrend,
  }) {
    int signals = 0;
    if (overreachingLevel >= 2)       signals += 2;
    if (fatigueTrend >= 3) {
      signals += 2; // suppressed
    } else if (fatigueTrend >= 2)       signals++;    // accumulating
    if (highFatigue)                  signals++;
    if (overTrainingRisk > 65)        signals++;
    if (recoveryScore < 45)           signals++;
    if (volumeSpike)                  signals++;
    if (recoveryTrend == 'declining') signals++;

    if (signals >= 5) return RecoveryCollapseRisk.high;
    if (signals >= 2) return RecoveryCollapseRisk.moderate;
    return RecoveryCollapseRisk.low;
  }

  // ── Overload readiness ────────────────────────────────────────────────────

  static OverloadReadiness _overloadReadiness({
    required double             recoveryScore,
    required int                momentumLevel,
    required bool               highFatigue,
    required int                overreachingLevel,
    required int                fatigueTrend,
    required bool               needsDeload,
    required RecoveryCollapseRisk collapse,
  }) {
    if (needsDeload || collapse == RecoveryCollapseRisk.high) {
      return OverloadReadiness.notReady;
    }
    if (recoveryScore >= 85 &&
        momentumLevel >= 2 &&
        !highFatigue &&
        overreachingLevel <= 1 &&
        fatigueTrend <= 1) {
      return OverloadReadiness.prime;
    }
    if (recoveryScore >= 72 &&
        momentumLevel >= 2 &&
        !highFatigue &&
        overreachingLevel <= 1) {
      return OverloadReadiness.elevated;
    }
    if (recoveryScore >= 58 && overreachingLevel <= 1) {
      return OverloadReadiness.possible;
    }
    return OverloadReadiness.notReady;
  }

  // ── Streak break risk ─────────────────────────────────────────────────────

  static StreakBreakRisk _streakBreakRisk({
    required int fragility,
    required int motivTrend,
    required int daysSince,
    required int intimidation,
    required int burnout,
  }) {
    int signals = 0;
    if (fragility >= 3) {
      signals += 2; // critical
    } else if (fragility >= 2) signals++; // fragile
    if (motivTrend >= 3) {
      signals += 2; // dropping
    } else if (motivTrend >= 2) signals++; // dipping
    if (daysSince >= 3)    signals++;
    if (intimidation >= 2) signals++;
    if (burnout >= 2)      signals++;

    if (signals >= 4) return StreakBreakRisk.high;
    if (signals >= 2) return StreakBreakRisk.moderate;
    return StreakBreakRisk.low;
  }

  // ── Projected momentum (7–14 day window) ─────────────────────────────────

  static ProjectedMomentum _projectedMomentum({
    required int               currentMomentum,
    required OverloadReadiness overloadReadiness,
    required int               overreachingLevel,
    required int               fatigueTrend,
    required int               burnout,
    required String            recoveryTrend,
  }) {
    if (overreachingLevel >= 2 || fatigueTrend >= 3 || burnout >= 3) {
      return ProjectedMomentum.declining;
    }
    if (burnout >= 2 || (fatigueTrend >= 2 && recoveryTrend == 'declining')) {
      return ProjectedMomentum.declining;
    }
    if (overloadReadiness == OverloadReadiness.prime && currentMomentum >= 2) {
      return ProjectedMomentum.peaking;
    }
    if (overloadReadiness == OverloadReadiness.elevated || currentMomentum >= 2) {
      return ProjectedMomentum.building;
    }
    if (currentMomentum == 1 && recoveryTrend != 'declining') {
      return ProjectedMomentum.flat;
    }
    return ProjectedMomentum.declining;
  }

  // ── Projected fatigue (7–14 day window) ──────────────────────────────────

  static ProjectedFatigue _projectedFatigue({
    required int  overreachingLevel,
    required int  fatigueTrend,
    required bool volumeSpike,
    required bool highFatigue,
  }) {
    if (overreachingLevel >= 3 || (fatigueTrend >= 3 && highFatigue)) {
      return ProjectedFatigue.critical;
    }
    if (overreachingLevel >= 2 || (volumeSpike && fatigueTrend >= 2)) {
      return ProjectedFatigue.elevating;
    }
    if (overreachingLevel >= 1 || volumeSpike || fatigueTrend >= 2) {
      return ProjectedFatigue.accumulating;
    }
    return ProjectedFatigue.stable;
  }

  // ── Projected consistency (next 4 weeks) ─────────────────────────────────

  static ProjectedConsistency _projectedConsistency({
    required int consistencyTrend,
    required int burnout,
    required int motivTrend,
    required int fragility,
    required int daysSince,
  }) {
    if (burnout >= 3 || motivTrend >= 3) return ProjectedConsistency.declining;
    if (burnout >= 2 ||
        motivTrend >= 2 ||
        (fragility >= 2 && daysSince >= 3)) {
      return ProjectedConsistency.inconsistent;
    }
    if (consistencyTrend >= 3 && motivTrend <= 1) {
      return ProjectedConsistency.building;
    }
    if (consistencyTrend >= 2) return ProjectedConsistency.stable;
    return ProjectedConsistency.inconsistent;
  }

  // ── PR window prediction ──────────────────────────────────────────────────

  static String _prWindow({
    required OverloadReadiness overload,
    required ProjectedMomentum projMomentum,
    required int               prsLast21,
    required double            progressionVelocity,
  }) {
    if (overload == OverloadReadiness.notReady) return '';
    if (projMomentum == ProjectedMomentum.declining) return '';
    // Require a recent signal — recent PRs or decent velocity
    if (prsLast21 < 1 && progressionVelocity < 0.5) return '';

    if (overload == OverloadReadiness.prime &&
        projMomentum == ProjectedMomentum.peaking) {
      return '3–5 days';
    }
    if (overload == OverloadReadiness.prime ||
        projMomentum == ProjectedMomentum.peaking) {
      return '5–8 days';
    }
    if (overload == OverloadReadiness.elevated) return '7–10 days';
    return '';
  }

  // ── Training window advisory ──────────────────────────────────────────────

  static String _trainingWindow(OverloadReadiness overload) => switch (overload) {
    OverloadReadiness.prime    =>
        'Recovery and momentum are aligned. This week supports peak output.',
    OverloadReadiness.elevated =>
        'Conditions support progressive loading over the next 5–7 days.',
    OverloadReadiness.possible =>
        'Progression is possible — maintain consistency to extend the window.',
    OverloadReadiness.notReady =>
        'Allow recovery to stabilize before increasing intensity.',
  };

  // ── Primary predictive insight ────────────────────────────────────────────

  static String _insight({
    required RecoveryCollapseRisk collapse,
    required double               plateauProb,
    required StreakBreakRisk       streakRisk,
    required OverloadReadiness     overload,
    required ProjectedMomentum    projMomentum,
    required ProjectedFatigue     projFatigue,
    required int                  overreachingLevel,
    required int                  daysSince,
    required String               prWindow,
  }) {
    // ── Recovery collapse — highest priority ──────────────────────────────
    if (collapse == RecoveryCollapseRisk.high) {
      return 'Recent loading trends suggest recovery capacity is tightening.';
    }
    if (collapse == RecoveryCollapseRisk.moderate && overreachingLevel >= 2) {
      return 'Fatigue accumulation may blunt progression if volume continues rising.';
    }

    // ── Plateau signals ───────────────────────────────────────────────────
    if (plateauProb >= 0.65) {
      return 'Progression velocity is slowing. A stimulus change may prevent adaptation stall.';
    }
    if (plateauProb >= 0.42) {
      return 'Current progression velocity suggests adaptation is slowing.';
    }

    // ── Overload / PR window opportunity ──────────────────────────────────
    if (overload == OverloadReadiness.prime && prWindow.isNotEmpty) {
      return 'Recovery and momentum suggest a strong progression window approaching.';
    }
    if (overload == OverloadReadiness.elevated && prWindow.isNotEmpty) {
      return 'The next $prWindow may support aggressive progression.';
    }

    // ── Streak / behavioral risk ──────────────────────────────────────────
    if (streakRisk == StreakBreakRisk.high && daysSince >= 2) {
      return 'Training rhythm is becoming less stable.';
    }

    // ── Momentum outlook ──────────────────────────────────────────────────
    if (projMomentum == ProjectedMomentum.peaking) {
      return 'Current recovery trend supports higher output later this week.';
    }
    if (projMomentum == ProjectedMomentum.declining) {
      return 'Output trend is softening — protect recovery and review loading.';
    }

    // ── Fatigue projection ────────────────────────────────────────────────
    if (projFatigue == ProjectedFatigue.elevating) {
      return 'Fatigue accumulation may blunt progression if volume continues rising.';
    }

    // ── Positive building state ───────────────────────────────────────────
    if (overload == OverloadReadiness.possible &&
        projMomentum == ProjectedMomentum.building) {
      return 'Training conditions are building — consistency now compounds over the next 2–3 weeks.';
    }

    return ''; // no significant predictive signal — card stays hidden
  }
}
