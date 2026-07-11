// lib/memory/builders/athlete_memory_builder.dart

import '../athlete_memory.dart';
import '../models/athlete_baseline.dart';
import '../models/athlete_identity.dart';
import '../models/consistency_profile.dart';
import '../models/progression_profile.dart';
import '../models/recovery_profile.dart';

/// Builds immutable AthleteMemory instances.
///
/// This builder is intentionally lightweight and contains no persistence,
/// no recovery computations, and no analytics logic.
class AthleteMemoryBuilder {
  const AthleteMemoryBuilder();

  AthleteMemory build({
    required AthleteIdentity identity,
    required AthleteBaseline baseline,
    required ConsistencyProfile consistency,
    required RecoveryProfile recovery,
    required ProgressionProfile progression,
  }) {
    return AthleteMemory(
      identityStage:            identity.athleteId,
      experienceLevel:          identity.preferredName,
      consistencyScore:         consistency.averageWorkoutsPerWeek.toDouble(),
      recoveryVelocity:         recovery.averageRecoveryScore,
      progressionVelocity:      progression.averageProgressionRate,
      volumeTolerance:          baseline.baseWorkloadKg,
      preferredSessionDuration: const Duration(minutes: 60),
      preferredTrainingDays:    baseline.baseWeeklyTrainingDays,
      preferredTrainingTime:    identity.primaryGoal,
      adherenceScore:           consistency.longestStreak.toDouble(),
      reliabilityScore:         consistency.missedWorkoutsLast30Days.toDouble(),
      lastUpdated:              DateTime.now(),
    );
  }
}
