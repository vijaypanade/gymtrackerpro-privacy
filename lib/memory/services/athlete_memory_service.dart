// lib/memory/services/athlete_memory_service.dart

import '../athlete_memory.dart';
import '../builders/athlete_memory_builder.dart';
import '../models/athlete_baseline.dart';
import '../models/athlete_identity.dart';
import '../models/consistency_profile.dart';
import '../models/progression_profile.dart';
import '../models/recovery_profile.dart';
import '../snapshots/athlete_memory_snapshot.dart';

/// Service responsible for building AthleteMemory and providing snapshots.
///
/// This service is intentionally lightweight and contains no persistence,
/// no recovery computations, and no workout recommendations.
class AthleteMemoryService {
  const AthleteMemoryService();

  AthleteMemory build({
    required AthleteIdentity identity,
    required AthleteBaseline baseline,
    required ConsistencyProfile consistency,
    required RecoveryProfile recovery,
    required ProgressionProfile progression,
  }) {
    return const AthleteMemoryBuilder().build(
      identity:    identity,
      baseline:    baseline,
      consistency: consistency,
      recovery:    recovery,
      progression: progression,
    );
  }

  AthleteMemorySnapshot snapshot(AthleteMemory memory) {
    return AthleteMemorySnapshot(
      identityStage:             memory.identityStage,
      experienceLevel:           memory.experienceLevel,
      consistencyScore:          memory.consistencyScore,
      recoveryVelocity:          memory.recoveryVelocity,
      progressionVelocity:       memory.progressionVelocity,
      volumeTolerance:           memory.volumeTolerance,
      preferredSessionDuration:  memory.preferredSessionDuration,
      preferredTrainingDays:     memory.preferredTrainingDays,
      preferredTrainingTime:     memory.preferredTrainingTime,
      adherenceScore:            memory.adherenceScore,
      reliabilityScore:          memory.reliabilityScore,
      lastUpdated:               memory.lastUpdated,
    );
  }

  /// Returns a rebuilt AthleteMemory from the same underlying inputs.
  ///
  /// Purpose: create a new immutable AthleteMemory when the source inputs
  /// have been refreshed or recomputed.
  ///
  /// Expected inputs: existing AthleteMemory plus underlying identity,
  /// baseline, consistency, recovery, and progression models.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: remix or normalize the source inputs for a
  /// committed AthleteMemory update path.
  AthleteMemory rebuild({
    required AthleteMemory memory,
    required AthleteIdentity identity,
    required AthleteBaseline baseline,
    required ConsistencyProfile consistency,
    required RecoveryProfile recovery,
    required ProgressionProfile progression,
  }) {
    throw UnimplementedError('AthleteMemoryService.rebuild() is not implemented yet.');
  }

  /// Returns an updated AthleteMemory after a workout completion event.
  ///
  /// Purpose: produce a new AthleteMemory that reflects long-term
  /// consistency and progression changes from the workout.
  ///
  /// Expected inputs: current AthleteMemory plus workout metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: capture workout-driven athlete evolution without
  /// mutating the original memory.
  AthleteMemory updateAfterWorkout({
    required AthleteMemory memory,
    required int workoutDurationMinutes,
    required bool wasSuccessful,
    required int completedVolumeKg,
  }) {
    // EMA smoothing factor: small alpha keeps long-term memory stable.
    const double alpha = 0.05;

    // Normalize observed volume to [0,1] against a 20 000 kg ceiling.
    // Most sessions fall between 2 000–15 000 kg of total tonnage.
    const double volumeCeiling = 20000.0;
    final double observedVolume =
        (completedVolumeKg / volumeCeiling).clamp(0.0, 1.0);

    // Smooth preferredSessionDuration toward the observed duration.
    final double currentMinutes =
        memory.preferredSessionDuration.inSeconds / 60.0;
    final double smoothedMinutes =
        currentMinutes + alpha * (workoutDurationMinutes - currentMinutes);
    final Duration smoothedDuration =
        Duration(minutes: smoothedMinutes.round().clamp(10, 180));

    // Consistency and adherence only increase when workout was successful.
    final double consistencyDelta = wasSuccessful ? alpha : 0.0;
    final double adherenceDelta   = wasSuccessful ? alpha : 0.0;

    return memory.copyWith(
      consistencyScore: (memory.consistencyScore + consistencyDelta).clamp(0.0, 1.0),
      adherenceScore:   (memory.adherenceScore   + adherenceDelta).clamp(0.0, 1.0),
      reliabilityScore: (memory.reliabilityScore  + alpha).clamp(0.0, 1.0),
      preferredSessionDuration: smoothedDuration,
      volumeTolerance: (memory.volumeTolerance +
              alpha * (observedVolume - memory.volumeTolerance))
          .clamp(0.0, 1.0),
      lastUpdated: DateTime.now(),
    );
  }

  /// Returns an updated AthleteMemory after a recovery refresh event.
  ///
  /// Purpose: produce a new AthleteMemory that reflects recovery trend
  /// and resilience updates after a recovery refresh.
  ///
  /// Expected inputs: current AthleteMemory plus recovery refresh metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: incorporate long-term recovery profile evolution.
  AthleteMemory updateAfterRecoveryRefresh({
    required AthleteMemory memory,
    required Duration recoveryWindow,
    required double recoveryScore,
  }) {
    throw UnimplementedError('AthleteMemoryService.updateAfterRecoveryRefresh() is not implemented yet.');
  }

  /// Returns an updated AthleteMemory after a missed workout event.
  ///
  /// Purpose: produce a new AthleteMemory that reflects reliability and
  /// adherence consequences from a missed workout.
  ///
  /// Expected inputs: current AthleteMemory plus missed workout metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: update adherence and reliability tracking.
  AthleteMemory updateAfterMissedWorkout({
    required AthleteMemory memory,
    required DateTime missedWorkoutDate,
  }) {
    throw UnimplementedError('AthleteMemoryService.updateAfterMissedWorkout() is not implemented yet.');
  }

  /// Returns an updated AthleteMemory after a new personal record.
  ///
  /// Purpose: produce a new AthleteMemory that reflects progression and
  /// athlete development from a PR event.
  ///
  /// Expected inputs: current AthleteMemory plus PR metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: capture progression momentum and confidence.
  AthleteMemory updateAfterPR({
    required AthleteMemory memory,
    required String liftName,
    required double newWeightKg,
    required int newReps,
  }) {
    // Larger alpha for PR: a PR is a strong signal that the athlete
    // is in a productive overload window — weight it more than a routine workout.
    const double alpha = 0.10;
    // Smaller nudge for reliability: PRs confirm discipline but the signal
    // is narrower than sustained attendance.
    const double reliabilityAlpha = 0.03;

    return memory.copyWith(
      progressionVelocity: (memory.progressionVelocity +
              alpha * (1.0 - memory.progressionVelocity))
          .clamp(0.0, 1.0),
      reliabilityScore: (memory.reliabilityScore + reliabilityAlpha).clamp(0.0, 1.0),
      lastUpdated: DateTime.now(),
    );
  }

  /// Returns an updated AthleteMemory after a deload event.
  ///
  /// Purpose: produce a new AthleteMemory that reflects volume tolerance and
  /// recovery expectations after a deload.
  ///
  /// Expected inputs: current AthleteMemory plus deload metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: adjust long-term volume tolerance and recovery velocity.
  AthleteMemory updateAfterDeload({
    required AthleteMemory memory,
    required Duration deloadDuration,
    required double reducedVolumeKg,
  }) {
    throw UnimplementedError('AthleteMemoryService.updateAfterDeload() is not implemented yet.');
  }

  /// Returns an updated AthleteMemory after completing a training week.
  ///
  /// Purpose: produce a new AthleteMemory that reflects weekly consistency,
  /// training days, and overall athlete evolution.
  ///
  /// Expected inputs: current AthleteMemory plus week summary metadata.
  ///
  /// Expected output: new AthleteMemory.
  ///
  /// Future responsibility: roll weekly progress into long-term memory.
  AthleteMemory updateAfterWeekComplete({
    required AthleteMemory memory,
    required int completedWorkouts,
    required int totalVolumeKg,
    required bool includedDeload,
  }) {
    throw UnimplementedError('AthleteMemoryService.updateAfterWeekComplete() is not implemented yet.');
  }
}
