// lib/services/athlete_trend_service.dart
// Pure Dart — no Flutter imports.
// Detects long-term training trends from history, recovery, and memory signals.

import 'dart:math';
import '../models/coach_context.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum PlateauRisk { none, low, moderate, high }

enum OverreachingRisk { none, low, moderate, high }

enum SpecializationBias {
  balanced,
  upperDominant,
  pushDominant,
  pullDominant,
  lowerDominant,
  posteriorChainNeglected,
  coreNeglected,
}

enum MomentumLevel { declining, flat, building, peaking }

enum RecommendedPhase {
  accumulation,
  intensification,
  deload,
  recovery,
  hypertrophyPush,
  strengthPush,
  maintenance,
}

enum FatigueTrend { improving, stable, accumulating, suppressed }

enum ConsistencyTrend { declining, inconsistent, stable, building }

// ── Display extensions (pure Dart, no Flutter) ────────────────────────────────

extension MomentumLevelX on MomentumLevel {
  String get label => switch (this) {
    MomentumLevel.peaking   => 'PEAKING',
    MomentumLevel.building  => 'BUILDING',
    MomentumLevel.flat      => 'STEADY',
    MomentumLevel.declining => 'DECLINING',
  };
}

extension RecommendedPhaseX on RecommendedPhase {
  String get label => switch (this) {
    RecommendedPhase.accumulation    => 'Building Phase',
    RecommendedPhase.intensification => 'Push Week',
    RecommendedPhase.deload          => 'Light Week',
    RecommendedPhase.recovery        => 'Recovery Focus',
    RecommendedPhase.hypertrophyPush => 'Growth Focus',
    RecommendedPhase.strengthPush    => 'Strength Push',
    RecommendedPhase.maintenance     => 'Consistency',
  };
}

// ── Output model ─────────────────────────────────────────────────────────────

class AthleteTrendSnapshot {
  final MomentumLevel      momentumState;
  final PlateauRisk        plateauRisk;
  final OverreachingRisk   overreachingRisk;
  final SpecializationBias specializationBias;
  /// PRs completed per week, averaged over the last 4 weeks.
  final double             progressionVelocity;
  final FatigueTrend       fatigueTrend;
  final ConsistencyTrend   consistencyTrend;
  final RecommendedPhase   recommendedPhase;
  /// One-line observational coach insight — pick the most salient signal.
  final String             coachInsight;
  final DateTime           computedAt;

  const AthleteTrendSnapshot({
    required this.momentumState,
    required this.plateauRisk,
    required this.overreachingRisk,
    required this.specializationBias,
    required this.progressionVelocity,
    required this.fatigueTrend,
    required this.consistencyTrend,
    required this.recommendedPhase,
    required this.coachInsight,
    required this.computedAt,
  });

  static AthleteTrendSnapshot get empty => AthleteTrendSnapshot(
    momentumState:       MomentumLevel.flat,
    plateauRisk:         PlateauRisk.none,
    overreachingRisk:    OverreachingRisk.none,
    specializationBias:  SpecializationBias.balanced,
    progressionVelocity: 0.0,
    fatigueTrend:        FatigueTrend.stable,
    consistencyTrend:    ConsistencyTrend.stable,
    recommendedPhase:    RecommendedPhase.maintenance,
    coachInsight:        '',
    computedAt:          DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Input contract ────────────────────────────────────────────────────────────

class AthleteTrendInput {
  final List<PREvent>    recentPRs;
  final double           weeklyVolumeKg;
  final double           previousWeeklyVolumeKg;
  /// Rolling 4-week average from AthleteMemory.
  final double           avgWeeklyVolumeKg;
  /// 0–100 from AthleteMemory.
  final int              consistencyScore;
  final int              missedWorkoutsLast30;
  /// muscle name (lowercase) → sessions in last 30 days.
  final Map<String, int> muscleFrequency;
  final double           recoveryScore;
  /// 'improving' | 'stable' | 'declining'
  final String           recoveryTrend;
  final double           fatigueIndex;
  /// 0–100 from AnalyticsProvider.
  final double           plateauScore;
  final double           overTrainingRisk;
  final double           weeklyImprovementPct;
  final bool             isOnPlateau;
  final int              currentStreak;
  final int              totalWorkouts;
  final bool             needsDeload;
  final bool             highFatigue;
  final DateTime         now;

  const AthleteTrendInput({
    required this.recentPRs,
    required this.weeklyVolumeKg,
    required this.previousWeeklyVolumeKg,
    required this.avgWeeklyVolumeKg,
    required this.consistencyScore,
    required this.missedWorkoutsLast30,
    required this.muscleFrequency,
    required this.recoveryScore,
    required this.recoveryTrend,
    required this.fatigueIndex,
    required this.plateauScore,
    required this.overTrainingRisk,
    required this.weeklyImprovementPct,
    required this.isOnPlateau,
    required this.currentStreak,
    required this.totalWorkouts,
    required this.needsDeload,
    required this.highFatigue,
    required this.now,
  });
}

// ── Muscle groupings ──────────────────────────────────────────────────────────

const _kUpperMuscles = ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'arms'];
const _kLowerMuscles = ['legs', 'calves', 'glutes', 'hamstrings', 'quads'];
const _kPushMuscles  = ['chest', 'shoulders', 'triceps'];
const _kPullMuscles  = ['back', 'biceps'];
const _kCoreMuscles  = ['core', 'abs'];

// ── Service ───────────────────────────────────────────────────────────────────

class AthleteTrendService {
  AthleteTrendService._();

  static AthleteTrendSnapshot compute(AthleteTrendInput i) {
    final now = i.now;

    // ── PR velocity (last 4 weeks) ────────────────────────────────────────
    final cut4w  = now.subtract(const Duration(days: 28));
    final cut21  = now.subtract(const Duration(days: 21));
    final cut42  = now.subtract(const Duration(days: 42));

    final prsLast4Weeks = i.recentPRs.where((p) => p.date.isAfter(cut4w)).length;
    final prsRecent     = i.recentPRs.where((p) => p.date.isAfter(cut21)).length;
    final prsOlder      = i.recentPRs
        .where((p) => p.date.isAfter(cut42) && !p.date.isAfter(cut21))
        .length;

    final progressionVelocity = prsLast4Weeks / 4.0;

    // ── Volume signals ────────────────────────────────────────────────────
    final prevVol = max(i.previousWeeklyVolumeKg, 1.0);
    final currVol = i.weeklyVolumeKg;
    final avgVol  = max(i.avgWeeklyVolumeKg, 1.0);

    final volumeRising = currVol > prevVol * 1.05;
    final volumeFlat   = i.previousWeeklyVolumeKg > 0 &&
        (currVol - prevVol).abs() / prevVol < 0.10;
    final volumeSpike  = i.previousWeeklyVolumeKg > 0 && currVol > prevVol * 1.25;
    final volAboveAvg  = currVol > avgVol * 1.05;

    // ── Trend computations ────────────────────────────────────────────────
    final plateau = _plateau(
      prsLast21:        prsRecent,
      volumeFlat:       volumeFlat,
      consistencyScore: i.consistencyScore,
      plateauScore:     i.plateauScore,
      isOnPlateau:      i.isOnPlateau,
      totalWorkouts:    i.totalWorkouts,
    );

    final overreaching = _overreaching(
      volumeSpike:      volumeSpike,
      recoveryTrend:    i.recoveryTrend,
      recoveryScore:    i.recoveryScore,
      highFatigue:      i.highFatigue,
      overTrainingRisk: i.overTrainingRisk,
    );

    final momentum = _momentum(
      prsRecent:        prsRecent,
      prsOlder:         prsOlder,
      volumeRising:     volumeRising,
      volAboveAvg:      volAboveAvg,
      consistencyScore: i.consistencyScore,
      recoveryScore:    i.recoveryScore,
    );

    final bias         = _bias(i.muscleFrequency);
    final fatigueTrend = _fatigueTrend(i.recoveryScore, i.highFatigue,
        i.recoveryTrend, i.fatigueIndex);
    final consistency  = _consistency(i.consistencyScore,
        i.missedWorkoutsLast30, i.currentStreak);
    final phase        = _phase(i.needsDeload, overreaching, plateau,
        momentum, i.weeklyImprovementPct, volumeFlat);
    final insight      = _insight(momentum, plateau, overreaching, bias,
        consistency, fatigueTrend);

    return AthleteTrendSnapshot(
      momentumState:       momentum,
      plateauRisk:         plateau,
      overreachingRisk:    overreaching,
      specializationBias:  bias,
      progressionVelocity: progressionVelocity,
      fatigueTrend:        fatigueTrend,
      consistencyTrend:    consistency,
      recommendedPhase:    phase,
      coachInsight:        insight,
      computedAt:          now,
    );
  }

  // ── Plateau ───────────────────────────────────────────────────────────────
  static PlateauRisk _plateau({
    required int    prsLast21,
    required bool   volumeFlat,
    required int    consistencyScore,
    required double plateauScore,
    required bool   isOnPlateau,
    required int    totalWorkouts,
  }) {
    if (totalWorkouts < 10) return PlateauRisk.none;

    int signals = 0;
    if (prsLast21 == 0)                              signals++;
    if (volumeFlat)                                  signals++;
    if (consistencyScore >= 60 && prsLast21 == 0)   signals++; // consistent but stuck
    if (isOnPlateau)                                 signals++;
    if (plateauScore >= 60)                          signals++;

    if (signals >= 4) return PlateauRisk.high;
    if (signals >= 2) return PlateauRisk.moderate;
    if (signals >= 1) return PlateauRisk.low;
    return PlateauRisk.none;
  }

  // ── Overreaching ──────────────────────────────────────────────────────────
  static OverreachingRisk _overreaching({
    required bool   volumeSpike,
    required String recoveryTrend,
    required double recoveryScore,
    required bool   highFatigue,
    required double overTrainingRisk,
  }) {
    final declining  = recoveryTrend == 'declining';
    final suppressed = highFatigue || recoveryScore < 45;

    if (volumeSpike && declining && suppressed) return OverreachingRisk.high;
    if ((volumeSpike && declining) || overTrainingRisk > 65) {
      return OverreachingRisk.moderate;
    }
    if (volumeSpike || (declining && suppressed)) return OverreachingRisk.low;
    return OverreachingRisk.none;
  }

  // ── Momentum ──────────────────────────────────────────────────────────────
  static MomentumLevel _momentum({
    required int    prsRecent,
    required int    prsOlder,
    required bool   volumeRising,
    required bool   volAboveAvg,
    required int    consistencyScore,
    required double recoveryScore,
  }) {
    final highConsistency = consistencyScore >= 75;
    final goodRecovery    = recoveryScore >= 65;

    if (prsRecent >= 2 && volumeRising && goodRecovery) {
      return MomentumLevel.peaking;
    }
    if ((prsRecent >= 1 && volumeRising) ||
        (prsRecent >= 1 && highConsistency) ||
        (volAboveAvg && highConsistency && goodRecovery)) {
      return MomentumLevel.building;
    }
    if (consistencyScore < 45 ||
        (prsRecent == 0 && !volumeRising && !highConsistency)) {
      return MomentumLevel.declining;
    }
    return MomentumLevel.flat;
  }

  // ── Specialization bias ───────────────────────────────────────────────────
  static SpecializationBias _bias(Map<String, int> freq) {
    if (freq.isEmpty) return SpecializationBias.balanced;

    int upper = 0, lower = 0, push = 0, pull = 0, core = 0;
    for (final e in freq.entries) {
      final m = e.key.toLowerCase();
      final v = e.value;
      if (_kUpperMuscles.contains(m)) upper += v;
      if (_kLowerMuscles.contains(m)) lower += v;
      if (_kPushMuscles.contains(m))  push  += v;
      if (_kPullMuscles.contains(m))  pull  += v;
      if (_kCoreMuscles.contains(m))  core  += v;
    }

    final total = max(upper + lower, 1);

    if (lower == 0 && upper > 0)             return SpecializationBias.upperDominant;
    if (upper > lower * 2.5)                 return SpecializationBias.upperDominant;
    if (lower > upper * 2.5)                 return SpecializationBias.lowerDominant;
    if (pull > 0 && push > pull * 2.2)       return SpecializationBias.pushDominant;
    if (push > 0 && pull > push * 2.2)       return SpecializationBias.pullDominant;
    if (lower > 0 && total / lower > 4.0)    return SpecializationBias.posteriorChainNeglected;
    if (core == 0 && total > 8)              return SpecializationBias.coreNeglected;
    return SpecializationBias.balanced;
  }

  // ── Fatigue trend ─────────────────────────────────────────────────────────
  static FatigueTrend _fatigueTrend(
      double score, bool high, String trend, double fatigue) {
    if (score < 45 || high)                              return FatigueTrend.suppressed;
    if (trend == 'declining' && fatigue > 50)            return FatigueTrend.accumulating;
    if (trend == 'improving' && fatigue < 40)            return FatigueTrend.improving;
    return FatigueTrend.stable;
  }

  // ── Consistency trend ─────────────────────────────────────────────────────
  static ConsistencyTrend _consistency(
      int score, int missed, int streak) {
    if (score >= 80 && streak >= 3) return ConsistencyTrend.building;
    if (score >= 60)                return ConsistencyTrend.stable;
    if (score >= 40)                return ConsistencyTrend.inconsistent;
    return ConsistencyTrend.declining;
  }

  // ── Recommended phase ─────────────────────────────────────────────────────
  static RecommendedPhase _phase(
    bool              needsDeload,
    OverreachingRisk  overreaching,
    PlateauRisk       plateau,
    MomentumLevel     momentum,
    double            weeklyImprovePct,
    bool              volumeFlat,
  ) {
    if (needsDeload)                                         return RecommendedPhase.deload;
    if (overreaching == OverreachingRisk.high)               return RecommendedPhase.recovery;
    if (plateau == PlateauRisk.high && volumeFlat)           return RecommendedPhase.intensification;
    if (plateau == PlateauRisk.moderate && weeklyImprovePct < 3) {
      return RecommendedPhase.hypertrophyPush;
    }
    if (momentum == MomentumLevel.peaking)                   return RecommendedPhase.strengthPush;
    if (momentum == MomentumLevel.building)                  return RecommendedPhase.accumulation;
    return RecommendedPhase.maintenance;
  }

  // ── Coach insight copy ────────────────────────────────────────────────────
  // Priority: overreaching > plateau > momentum > fatigue > consistency > bias
  static String _insight(
    MomentumLevel      momentum,
    PlateauRisk        plateau,
    OverreachingRisk   overreaching,
    SpecializationBias bias,
    ConsistencyTrend   consistency,
    FatigueTrend       fatigue,
  ) {
    switch (overreaching) {
      case OverreachingRisk.high:
        return 'Fatigue accumulation is rising across recent weeks.';
      case OverreachingRisk.moderate:
        return 'Output is rising faster than recovery. Watch the fatigue.';
      default:
        break;
    }
    switch (plateau) {
      case PlateauRisk.high:
        return 'Execution is consistent, but progression has flattened. A volume rotation may help.';
      case PlateauRisk.moderate:
        return 'Progress is slowing. Introducing new stimulus could restart adaptation.';
      default:
        break;
    }
    switch (momentum) {
      case MomentumLevel.peaking:
        return 'Momentum is building. Recovery and output are aligning well.';
      case MomentumLevel.building:
        return 'Positive trend forming. Consistency and output are up.';
      case MomentumLevel.declining:
        return 'Consistency has dropped over the last few weeks.';
      default:
        break;
    }
    if (fatigue == FatigueTrend.suppressed) {
      return 'Fatigue is elevated. Prioritize recovery before adding load.';
    }
    if (fatigue == FatigueTrend.accumulating) {
      return 'Fatigue is accumulating over recent sessions. Monitor recovery.';
    }
    switch (bias) {
      case SpecializationBias.upperDominant:
        return 'Upper body volume is dominating. Consider adding lower work.';
      case SpecializationBias.pushDominant:
        return 'Push volume outweighs pull. Rear chain work will balance this.';
      case SpecializationBias.pullDominant:
        return 'Pull volume is high relative to push. Balance with pressing work.';
      case SpecializationBias.lowerDominant:
        return 'Lower body volume is dominant. Upper work may be undertrained.';
      case SpecializationBias.posteriorChainNeglected:
        return 'Posterior chain is getting less attention than the rest of the plan.';
      case SpecializationBias.coreNeglected:
        return 'Core work is absent from recent training. Worth adding for stability.';
      default:
        break;
    }
    if (consistency == ConsistencyTrend.building) {
      return "Consistency is the strongest it's been recently. Keep building.";
    }
    return 'Training is on track. Maintain the current approach.';
  }
}
