// lib/brain/policy/mission_selection_engine.dart

import '../../models/recovery_state.dart';
import '../../providers/analytics_provider.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adherence_intelligence_service.dart';
import '../../services/predictive_performance_service.dart';
import '../../services/training_adjustment_service.dart';
import '../models/workout_context.dart';

/// Mission selection engine for AthleteBrain.
///
/// This policy core returns exactly one mission based on deterministic
/// hard constraints, safety, recovery, risk, opportunity, behavior,
/// athlete identity, and preference.
class MissionSelectionEngine {
  const MissionSelectionEngine();

  MissionType selectMission({
    required RecoveryState recoveryState,
    required AnalyticsSnapshot analyticsSnapshot,
    required AthleteMemorySnapshot athleteMemorySnapshot,
    required PredictiveSnapshot predictiveSnapshot,
    required AdherenceProfile adherenceProfile,
    required TrainingAdjustment trainingAdjustment,
    required WorkoutContext workoutContext,
  }) {
    // 1. Hard Constraints
    if (_mustDeload(recoveryState, trainingAdjustment, predictiveSnapshot)) {
      return MissionType.deload;
    }

    if (_mustProtectRecovery(recoveryState, analyticsSnapshot, predictiveSnapshot)) {
      return MissionType.protectRecovery;
    }

    // 2. Safety
    if (_safetyFirst(recoveryState, analyticsSnapshot, trainingAdjustment)) {
      return MissionType.recoverySession;
    }

    // 3. Recovery
    if (_recoveryPriority(analyticsSnapshot, predictiveSnapshot, trainingAdjustment)) {
      return MissionType.recoverySession;
    }

    // 4. Risk
    if (_riskSignal(analyticsSnapshot, predictiveSnapshot, trainingAdjustment)) {
      return MissionType.volumeReduction;
    }

    // 5. Opportunity
    if (_opportunityWindow(recoveryState, analyticsSnapshot, predictiveSnapshot)) {
      return MissionType.pushPerformance;
    }

    // 6. Behavior
    if (_behaviorSignal(adherenceProfile, workoutContext)) {
      return MissionType.comeback;
    }

    // 7. Athlete Identity
    if (_identitySignal(athleteMemorySnapshot, workoutContext, adherenceProfile)) {
      return MissionType.technique;
    }

    if (_homeAdaptationSignal(workoutContext, trainingAdjustment)) {
      return MissionType.homeAdaptation;
    }

    // 8. Preference / default
    return MissionType.maintainConsistency;
  }

  bool _mustDeload(
    RecoveryState recoveryState,
    TrainingAdjustment trainingAdjustment,
    PredictiveSnapshot predictiveSnapshot,
  ) {
    return recoveryState.needsDeload ||
        trainingAdjustment.shouldDeload ||
        recoveryState.highFatigue ||
        predictiveSnapshot.recoveryCollapseRisk == RecoveryCollapseRisk.high;
  }

  bool _mustProtectRecovery(
    RecoveryState recoveryState,
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
  ) {
    return recoveryState.overallScore < 45.0 ||
        analyticsSnapshot.readinessScore < 35.0 ||
        recoveryState.isRecoverySuppressed ||
        predictiveSnapshot.recoveryCollapseRisk == RecoveryCollapseRisk.moderate;
  }

  bool _safetyFirst(
    RecoveryState recoveryState,
    AnalyticsSnapshot analyticsSnapshot,
    TrainingAdjustment trainingAdjustment,
  ) {
    return trainingAdjustment.shouldReduceAxialLoad ||
        analyticsSnapshot.fatigueIndex >= 70.0 ||
        recoveryState.primaryLimitingMuscle.isNotEmpty;
  }

  bool _recoveryPriority(
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
    TrainingAdjustment trainingAdjustment,
  ) {
    return analyticsSnapshot.recoveryTrend == 'declining' ||
        analyticsSnapshot.readinessScore < 55.0 ||
        predictiveSnapshot.projectedFatigue == ProjectedFatigue.accumulating ||
        predictiveSnapshot.projectedFatigue == ProjectedFatigue.critical ||
        trainingAdjustment.volumeMultiplier < 0.85;
  }

  bool _riskSignal(
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
    TrainingAdjustment trainingAdjustment,
  ) {
    return analyticsSnapshot.overtTrainingRisk >= 60.0 ||
        analyticsSnapshot.fatigueIndex >= 65.0 ||
        predictiveSnapshot.plateauProbability >= 0.7 ||
        predictiveSnapshot.projectedConsistency == ProjectedConsistency.declining ||
        trainingAdjustment.intensityMultiplier < 0.9;
  }

  bool _opportunityWindow(
    RecoveryState recoveryState,
    AnalyticsSnapshot analyticsSnapshot,
    PredictiveSnapshot predictiveSnapshot,
  ) {
    return recoveryState.isReadyToPush &&
        predictiveSnapshot.overloadReadiness == OverloadReadiness.prime &&
        analyticsSnapshot.weeklyImprovementPct >= 5.0;
  }

  bool _behaviorSignal(
    AdherenceProfile adherenceProfile,
    WorkoutContext workoutContext,
  ) {
    return adherenceProfile.comebackProbability >= 0.7 ||
        workoutContext.daysSinceLastWorkout >= 7 ||
        adherenceProfile.streakFragility == StreakFragility.critical;
  }

  bool _identitySignal(
    AthleteMemorySnapshot athleteMemorySnapshot,
    WorkoutContext workoutContext,
    AdherenceProfile adherenceProfile,
  ) {
    return athleteMemorySnapshot.consistencyScore < 40.0 ||
        athleteMemorySnapshot.progressionVelocity >= 0.65 &&
            athleteMemorySnapshot.consistencyScore >= 55.0 ||
        workoutContext.goal.toLowerCase().contains('technique') ||
        adherenceProfile.consistencyIdentity == ConsistencyIdentity.momentumAthlete;
  }

  bool _homeAdaptationSignal(
    WorkoutContext workoutContext,
    TrainingAdjustment trainingAdjustment,
  ) {
    final lowerGoal = workoutContext.goal.toLowerCase();
    final hasHomeSignal = workoutContext.todayExerciseCategories.any(
      (category) => category.toLowerCase().contains('home') ||
          category.toLowerCase().contains('bodyweight'),
    );

    return hasHomeSignal ||
        lowerGoal.contains('home') ||
        lowerGoal.contains('bodyweight') ||
        trainingAdjustment.volumeMultiplier < 0.95;
  }
}

enum MissionType {
  protectRecovery,
  maintainConsistency,
  pushPerformance,
  comeback,
  deload,
  volumeReduction,
  homeAdaptation,
  technique,
  recoverySession,
}

extension MissionTypeX on MissionType {
  String get label {
    switch (this) {
      case MissionType.protectRecovery:
        return 'Protect Recovery';
      case MissionType.maintainConsistency:
        return 'Maintain Consistency';
      case MissionType.pushPerformance:
        return 'Push Performance';
      case MissionType.comeback:
        return 'Comeback';
      case MissionType.deload:
        return 'Deload';
      case MissionType.volumeReduction:
        return 'Volume Reduction';
      case MissionType.homeAdaptation:
        return 'Home Adaptation';
      case MissionType.technique:
        return 'Technique';
      case MissionType.recoverySession:
        return 'Recovery Session';
    }
  }
}
