// lib/brain/confidence/decision_confidence_engine.dart

import '../../models/recovery_state.dart';
import '../../providers/analytics_provider.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adherence_intelligence_service.dart';
import '../../services/predictive_performance_service.dart';
import '../models/decision_context.dart';
import '../policy/mission_selection_engine.dart';

/// Deterministic confidence scoring for AthleteBrain decisions.
///
/// This engine produces a pure score without AI, persistence, provider
/// dependencies, or UI coupling.
class DecisionConfidenceEngine {
  const DecisionConfidenceEngine();

  DecisionConfidence score({
    required DecisionContext decisionContext,
    required MissionType missionType,
    required RecoveryState recoveryState,
    required AnalyticsSnapshot analyticsSnapshot,
    required AthleteMemorySnapshot athleteMemorySnapshot,
    required PredictiveSnapshot predictiveSnapshot,
    required AdherenceProfile adherenceProfile,
  }) {
    final double dataConfidence = _computeDataConfidence(
      decisionContext,
      analyticsSnapshot,
      athleteMemorySnapshot,
    );

    final double recoveryConfidence = _computeRecoveryConfidence(recoveryState);
    final double analyticsConfidence = _computeAnalyticsConfidence(analyticsSnapshot);
    final double behaviorConfidence = _computeBehaviorConfidence(adherenceProfile);
    final double predictionConfidence = _computePredictionConfidence(predictiveSnapshot);
    final double memoryConfidence = _computeMemoryConfidence(athleteMemorySnapshot);

    final double agreementBonus = _signalAgreementBonus(
      recoveryState,
      analyticsSnapshot,
      predictiveSnapshot,
      adherenceProfile,
      athleteMemorySnapshot,
    );

    final double conflictPenalty = _conflictPenalty(
      recoveryState,
      analyticsSnapshot,
      predictiveSnapshot,
      adherenceProfile,
      athleteMemorySnapshot,
    );

    final double overallConfidence = _clamp(
      dataConfidence * 0.20 +
          recoveryConfidence * 0.18 +
          analyticsConfidence * 0.16 +
          behaviorConfidence * 0.14 +
          predictionConfidence * 0.16 +
          memoryConfidence * 0.16 +
          agreementBonus -
          conflictPenalty,
    );

    final String explanation = _buildExplanation(
      missionType: missionType,
      dataConfidence: dataConfidence,
      recoveryConfidence: recoveryConfidence,
      analyticsConfidence: analyticsConfidence,
      behaviorConfidence: behaviorConfidence,
      predictionConfidence: predictionConfidence,
      memoryConfidence: memoryConfidence,
      agreementBonus: agreementBonus,
      conflictPenalty: conflictPenalty,
    );

    return DecisionConfidence(
      overallConfidence: overallConfidence,
      dataConfidence: dataConfidence,
      recoveryConfidence: recoveryConfidence,
      analyticsConfidence: analyticsConfidence,
      behaviorConfidence: behaviorConfidence,
      predictionConfidence: predictionConfidence,
      memoryConfidence: memoryConfidence,
      explanation: explanation,
    );
  }

  double _computeDataConfidence(
    DecisionContext context,
    AnalyticsSnapshot analyticsSnapshot,
    AthleteMemorySnapshot athleteMemorySnapshot,
  ) {
    const double freshWeight = 0.6;
    const double memoryWeight = 0.4;

    final DateTime now = context.environmentContext.now;
    final double analyticsFreshness = _computeAnalyticsFreshness(
      analyticsSnapshot.cacheDate,
      now,
    );
    final double memoryFreshness = _computeMemoryFreshness(
      athleteMemorySnapshot.lastUpdated,
      now,
    );

    return _clamp(analyticsFreshness * freshWeight + memoryFreshness * memoryWeight);
  }

  double _computeAnalyticsFreshness(String cacheDate, DateTime now) {
    if (cacheDate.isEmpty) return 0.45;
    final DateTime? parsed = DateTime.tryParse(cacheDate);
    if (parsed == null) return 0.55;
    final daysOld = now.difference(parsed).inDays;
    if (daysOld <= 1) return 1.0;
    if (daysOld <= 3) return 0.9;
    if (daysOld <= 7) return 0.7;
    return 0.45;
  }

  double _computeMemoryFreshness(DateTime lastUpdated, DateTime now) {
    final daysOld = now.difference(lastUpdated).inDays;
    if (daysOld <= 1) return 1.0;
    if (daysOld <= 3) return 0.85;
    if (daysOld <= 7) return 0.65;
    return 0.45;
  }

  double _computeRecoveryConfidence(RecoveryState recoveryState) {
    const double base = 0.30;
    final double readiness = switch (recoveryState.readiness) {
      RecoveryReadiness.peak => 1.0,
      RecoveryReadiness.ready => 0.9,
      RecoveryReadiness.moderate => 0.75,
      RecoveryReadiness.low => 0.55,
      RecoveryReadiness.depleted => 0.30,
    };

    final double fatiguePenalty = recoveryState.highFatigue ? 0.15 : 0.0;
    final double deloadPenalty = recoveryState.needsDeload ? 0.10 : 0.0;

    return _clamp(base + readiness * 0.60 - fatiguePenalty - deloadPenalty);
  }

  double _computeAnalyticsConfidence(AnalyticsSnapshot analyticsSnapshot) {
    final double readiness = analyticsSnapshot.readinessScore / 100.0;
    final double fatigue = 1.0 - (analyticsSnapshot.fatigueIndex / 100.0);
    final double trend = analyticsSnapshot.recoveryTrend == 'stable' ? 1.0 :
        analyticsSnapshot.recoveryTrend == 'improving' ? 0.95 : 0.75;
    final double plateauPenalty = analyticsSnapshot.isOnPlateau ? 0.10 : 0.0;

    return _clamp(readiness * 0.45 + fatigue * 0.35 + trend * 0.20 - plateauPenalty);
  }

  double _computeBehaviorConfidence(AdherenceProfile adherenceProfile) {
    final double discipline = adherenceProfile.disciplineScore.clamp(0, 100) / 100.0;
    final double streak = switch (adherenceProfile.streakFragility) {
      StreakFragility.resilient => 1.0,
      StreakFragility.normal => 0.85,
      StreakFragility.fragile => 0.65,
      StreakFragility.critical => 0.40,
    };
    final double motivation = switch (adherenceProfile.motivationTrend) {
      MotivationTrend.rising => 1.0,
      MotivationTrend.stable => 0.85,
      MotivationTrend.dipping => 0.65,
      MotivationTrend.dropping => 0.45,
    };

    return _clamp(discipline * 0.55 + streak * 0.25 + motivation * 0.20);
  }

  double _computePredictionConfidence(PredictiveSnapshot predictiveSnapshot) {
    final double momentum = switch (predictiveSnapshot.projectedMomentum) {
      ProjectedMomentum.peaking => 1.0,
      ProjectedMomentum.building => 0.9,
      ProjectedMomentum.flat => 0.75,
      ProjectedMomentum.declining => 0.55,
    };
    final double fatigue = switch (predictiveSnapshot.projectedFatigue) {
      ProjectedFatigue.stable => 1.0,
      ProjectedFatigue.accumulating => 0.8,
      ProjectedFatigue.elevating => 0.6,
      ProjectedFatigue.critical => 0.35,
    };
    final double consistency = switch (predictiveSnapshot.projectedConsistency) {
      ProjectedConsistency.building => 1.0,
      ProjectedConsistency.stable => 0.85,
      ProjectedConsistency.inconsistent => 0.6,
      ProjectedConsistency.declining => 0.4,
    };
    final double riskPenalty = predictiveSnapshot.recoveryCollapseRisk == RecoveryCollapseRisk.high ? 0.15 : 0.0;

    return _clamp(momentum * 0.40 + fatigue * 0.35 + consistency * 0.25 - riskPenalty);
  }

  double _computeMemoryConfidence(AthleteMemorySnapshot athleteMemorySnapshot) {
    final double consistency = athleteMemorySnapshot.consistencyScore / 100.0;
    final double reliability = athleteMemorySnapshot.reliabilityScore / 100.0;
    final double adherence = athleteMemorySnapshot.adherenceScore / 100.0;
    final double stability = (consistency + reliability + adherence) / 3.0;

    return _clamp(stability * 0.9 + 0.1);
  }

  double _signalAgreementBonus(
    RecoveryState recoveryState,
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
    AdherenceProfile adherenceProfile,
    AthleteMemorySnapshot athleteMemorySnapshot,
  ) {
    final bool recoveryStable = recoveryState.readiness == RecoveryReadiness.ready ||
        recoveryState.readiness == RecoveryReadiness.peak;
    final bool analyticsGood = analyticsSnapshot.readinessScore >= 60.0 &&
        analyticsSnapshot.fatigueIndex <= 45.0;
    final bool memoryReliable = athleteMemorySnapshot.reliabilityScore >= 60.0;
    final bool behaviorStable = adherenceProfile.burnoutRisk == BurnoutRisk.none &&
        adherenceProfile.consistencyIdentity != ConsistencyIdentity.burnoutProne;
    final bool predictiveSupport = predictiveSnapshot.projectedMomentum == ProjectedMomentum.building ||
        predictiveSnapshot.projectedMomentum == ProjectedMomentum.peaking;

    final int agreementCount = <bool>[
      recoveryStable,
      analyticsGood,
      memoryReliable,
      behaviorStable,
      predictiveSupport,
    ].where((v) => v).length;

    return _clamp(agreementCount * 0.04);
  }

  double _conflictPenalty(
    RecoveryState recoveryState,
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
    AdherenceProfile adherenceProfile,
    AthleteMemorySnapshot athleteMemorySnapshot,
  ) {
    double penalty = 0.0;

    if (recoveryState.isRecoverySuppressed && analyticsSnapshot.readinessScore >= 70.0) {
      penalty += 0.10;
    }
    if (predictiveSnapshot.overloadReadiness == OverloadReadiness.prime &&
        recoveryState.readiness.index <= RecoveryReadiness.moderate.index) {
      penalty += 0.12;
    }
    if (adherenceProfile.comebackProbability >= 0.7 &&
        athleteMemorySnapshot.consistencyScore < 45.0) {
      penalty += 0.08;
    }
    if (athleteMemorySnapshot.reliabilityScore < 40.0 &&
        analyticsSnapshot.fatigueIndex < 30.0) {
      penalty += 0.06;
    }
    if (predictiveSnapshot.plateauProbability >= 0.7 &&
        analyticsSnapshot.weeklyImprovementPct >= 5.0) {
      penalty += 0.05;
    }

    return penalty.clamp(0.0, 0.25);
  }

  String _buildExplanation({
    required MissionType missionType,
    required double dataConfidence,
    required double recoveryConfidence,
    required double analyticsConfidence,
    required double behaviorConfidence,
    required double predictionConfidence,
    required double memoryConfidence,
    required double agreementBonus,
    required double conflictPenalty,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Mission: ${missionType.label}.');
    buffer.writeln('Data confidence is ${_format(dataConfidence)} based on recency and source freshness.');
    buffer.writeln('Recovery confidence is ${_format(recoveryConfidence)} from readiness and fatigue signals.');
    buffer.writeln('Analytics confidence is ${_format(analyticsConfidence)} from trend and plateau alignment.');
    buffer.writeln('Behavior confidence is ${_format(behaviorConfidence)} from adherence and motivation.');
    buffer.writeln('Prediction confidence is ${_format(predictionConfidence)} from momentum and risk signals.');
    buffer.writeln('Memory confidence is ${_format(memoryConfidence)} from long-term consistency and reliability.');
    if (agreementBonus > 0.0) {
      buffer.writeln('Signal agreement adds ${_format(agreementBonus)}.');
    }
    if (conflictPenalty > 0.0) {
      buffer.writeln('Conflicting signals subtract ${_format(conflictPenalty)}.');
    }
    return buffer.toString().trim();
  }

  double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();

  String _format(double value) => '${(value * 100).roundToDouble().toStringAsFixed(0)}%';
}

/// Immutable decision confidence output.
class DecisionConfidence {
  final double overallConfidence;
  final double dataConfidence;
  final double recoveryConfidence;
  final double analyticsConfidence;
  final double behaviorConfidence;
  final double predictionConfidence;
  final double memoryConfidence;
  final String explanation;

  const DecisionConfidence({
    required this.overallConfidence,
    required this.dataConfidence,
    required this.recoveryConfidence,
    required this.analyticsConfidence,
    required this.behaviorConfidence,
    required this.predictionConfidence,
    required this.memoryConfidence,
    required this.explanation,
  });
}
