// lib/memory/snapshots/athlete_memory_snapshot.dart

/// Immutable snapshot of athlete memory for downstream consumption.
///
/// This object exposes only high-level athlete identity characteristics.
class AthleteMemorySnapshot {
  final String identityStage;
  final String experienceLevel;
  final double consistencyScore;
  final double recoveryVelocity;
  final double progressionVelocity;
  final double volumeTolerance;
  final Duration preferredSessionDuration;
  final int preferredTrainingDays;
  final String preferredTrainingTime;
  final double adherenceScore;
  final double reliabilityScore;
  final DateTime lastUpdated;

  const AthleteMemorySnapshot({
    required this.identityStage,
    required this.experienceLevel,
    required this.consistencyScore,
    required this.recoveryVelocity,
    required this.progressionVelocity,
    required this.volumeTolerance,
    required this.preferredSessionDuration,
    required this.preferredTrainingDays,
    required this.preferredTrainingTime,
    required this.adherenceScore,
    required this.reliabilityScore,
    required this.lastUpdated,
  });

  /// Zero-state snapshot used when no EMA memory has been established yet.
  /// Mirrors AthleteMemory.defaults() so both objects stay in sync.
  factory AthleteMemorySnapshot.defaults() => AthleteMemorySnapshot(
        identityStage:            'beginner',
        experienceLevel:          'novice',
        consistencyScore:         0.0,
        recoveryVelocity:         0.5,
        progressionVelocity:      0.5,
        volumeTolerance:          0.5,
        preferredSessionDuration: const Duration(minutes: 60),
        preferredTrainingDays:    3,
        preferredTrainingTime:    'morning',
        adherenceScore:           0.0,
        reliabilityScore:         0.0,
        lastUpdated:              DateTime.fromMillisecondsSinceEpoch(0),
      );
}
