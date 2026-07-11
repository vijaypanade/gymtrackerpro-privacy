// lib/memory/services/athlete_memory_evolution_engine.dart

import '../athlete_memory.dart';
import '../events/deload_completed_event.dart';
import '../events/missed_workout_event.dart';
import '../events/pr_achieved_event.dart';
import '../events/recovery_refresh_event.dart';
import '../events/week_completed_event.dart';
import '../events/workout_completed_event.dart';

/// Deterministic evolution engine for AthleteMemory.
///
/// Evolves a single immutable AthleteMemory instance with one immutable event.
class AthleteMemoryEvolutionEngine {
  static const double minScore = 0.0;
  static const double maxScore = 1.0;

  static const double consistencyWorkoutDelta = 0.025;
  static const double adherenceWorkoutDelta = 0.020;
  static const double reliabilityWorkoutDelta = 0.010;

  static const double consistencyMissedDelta = -0.040;
  static const double reliabilityMissedDelta = -0.035;
  static const double adherenceMissedDelta = -0.015;

  static const double progressionPrDelta = 0.035;
  static const double recoverySmoothingFactor = 0.15;
  static const double volumeToleranceDeloadDelta = 0.020;

  static const double weekExperienceSmoothingFactor = 0.10;
  static const double identityStageThresholdVelocity = 0.6;
  static const double identityStageThresholdConsistency = 0.65;

  static AthleteMemory evolveWithWorkout(
    AthleteMemory memory,
    WorkoutCompletedEvent event,
  ) {
    final double newConsistency = _clamp(memory.consistencyScore + consistencyWorkoutDelta);
    final double newAdherence = _clamp(memory.adherenceScore + adherenceWorkoutDelta);
    final double newReliability = _clamp(memory.reliabilityScore + reliabilityWorkoutDelta);

    return memory.copyWith(
      consistencyScore: newConsistency,
      adherenceScore: newAdherence,
      reliabilityScore: newReliability,
      lastUpdated: event.completedAt,
    );
  }

  static AthleteMemory evolveWithMissedWorkout(
    AthleteMemory memory,
    MissedWorkoutEvent event,
  ) {
    final double newConsistency = _clamp(memory.consistencyScore + consistencyMissedDelta);
    final double newReliability = _clamp(memory.reliabilityScore + reliabilityMissedDelta);
    final double newAdherence = _clamp(memory.adherenceScore + adherenceMissedDelta);

    return memory.copyWith(
      consistencyScore: newConsistency,
      reliabilityScore: newReliability,
      adherenceScore: newAdherence,
      lastUpdated: event.missedAt,
    );
  }

  static AthleteMemory evolveWithPR(
    AthleteMemory memory,
    PRAchievedEvent event,
  ) {
    final double newProgression = _clamp(memory.progressionVelocity + progressionPrDelta);
    final String newIdentity = _advanceIdentityStage(
      memory.identityStage,
      newProgression,
      memory.consistencyScore,
    );

    return memory.copyWith(
      progressionVelocity: newProgression,
      identityStage: newIdentity,
      lastUpdated: event.achievedAt,
    );
  }

  static AthleteMemory evolveWithRecoveryRefresh(
    AthleteMemory memory,
    RecoveryRefreshEvent event,
  ) {
    final double targetRecovery = _clamp(event.recoveryScore);
    final double newRecovery = _smooth(memory.recoveryVelocity, targetRecovery, recoverySmoothingFactor);

    return memory.copyWith(
      recoveryVelocity: newRecovery,
      lastUpdated: event.refreshedAt,
    );
  }

  static AthleteMemory evolveWithDeload(
    AthleteMemory memory,
    DeloadCompletedEvent event,
  ) {
    final double newVolumeTolerance = _clamp(memory.volumeTolerance + volumeToleranceDeloadDelta);

    return memory.copyWith(
      volumeTolerance: newVolumeTolerance,
      lastUpdated: event.completedAt,
    );
  }

  static AthleteMemory evolveWithWeekCompleted(
    AthleteMemory memory,
    WeekCompletedEvent event,
  ) {
    final double completionRatio = event.totalWorkouts > 0
        ? event.successfulWorkouts / event.totalWorkouts
        : 0.0;
    final double weekConsistency = _clamp(event.averageIntensity * 0.1 + completionRatio * 0.6);
    final double newConsistency = _smooth(memory.consistencyScore, weekConsistency, weekExperienceSmoothingFactor);
    final double newReliability = _smooth(memory.reliabilityScore, completionRatio, weekExperienceSmoothingFactor);

    final String newExperience = _recomputeExperienceLevel(memory.experienceLevel, event.totalWorkouts, event.averageIntensity);
    final String newIdentity = _recomputeIdentityStage(
      memory.identityStage,
      newConsistency,
      memory.progressionVelocity,
    );

    return memory.copyWith(
      consistencyScore: _clamp(newConsistency),
      reliabilityScore: _clamp(newReliability),
      experienceLevel: newExperience,
      identityStage: newIdentity,
      lastUpdated: event.weekEndingAt,
    );
  }

  static double _clamp(double value) {
    if (value.isNaN) {
      return minScore;
    }
    if (value < minScore) {
      return minScore;
    }
    if (value > maxScore) {
      return maxScore;
    }
    return value;
  }

  static double _smooth(double current, double target, double alpha) {
    return _clamp(current + (target - current) * alpha);
  }

  static String _advanceIdentityStage(
    String currentStage,
    double progressionVelocity,
    double consistencyScore,
  ) {
    if (progressionVelocity >= identityStageThresholdVelocity &&
        consistencyScore >= identityStageThresholdConsistency) {
      switch (currentStage) {
        case 'novice':
          return 'intermediate';
        case 'intermediate':
          return 'advanced';
        case 'advanced':
          return 'elite';
        default:
          return currentStage;
      }
    }
    return currentStage;
  }

  static String _recomputeExperienceLevel(
    String currentLevel,
    int totalWorkouts,
    double averageIntensity,
  ) {
    if (totalWorkouts >= 8 && averageIntensity >= 0.7) {
      return 'experienced';
    }
    if (totalWorkouts >= 5) {
      return 'practiced';
    }
    return currentLevel;
  }

  static String _recomputeIdentityStage(
    String currentStage,
    double consistencyScore,
    double progressionVelocity,
  ) {
    if (consistencyScore >= 0.75 && progressionVelocity >= 0.55) {
      return _advanceIdentityStage(currentStage, progressionVelocity, consistencyScore);
    }
    return currentStage;
  }
}
