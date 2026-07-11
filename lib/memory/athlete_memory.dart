// lib/memory/athlete_memory.dart

/// Immutable long-term athlete memory.
///
/// This model stores long-term athlete characteristics only.
/// It does not compute recovery, analytics, or workout recommendations.
class AthleteMemory {
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

  const AthleteMemory({
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

  /// Sensible zero-state defaults for a first-time athlete.
  /// All EMA scores start at 0.0 so the first real workout has full weight.
  /// Mid-point values (0.5) are used for velocity fields whose true baseline
  /// is unknown until observed data arrives.
  factory AthleteMemory.defaults() => AthleteMemory(
        identityStage:           'beginner',
        experienceLevel:         'novice',
        consistencyScore:        0.0,
        recoveryVelocity:        0.5,
        progressionVelocity:     0.5,
        volumeTolerance:         0.5,
        preferredSessionDuration: const Duration(minutes: 60),
        preferredTrainingDays:   3,
        preferredTrainingTime:   'morning',
        adherenceScore:          0.0,
        reliabilityScore:        0.0,
        lastUpdated:             DateTime.fromMillisecondsSinceEpoch(0),
      );

  AthleteMemory copyWith({
    String? identityStage,
    String? experienceLevel,
    double? consistencyScore,
    double? recoveryVelocity,
    double? progressionVelocity,
    double? volumeTolerance,
    Duration? preferredSessionDuration,
    int? preferredTrainingDays,
    String? preferredTrainingTime,
    double? adherenceScore,
    double? reliabilityScore,
    DateTime? lastUpdated,
  }) {
    return AthleteMemory(
      identityStage: identityStage ?? this.identityStage,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      consistencyScore: consistencyScore ?? this.consistencyScore,
      recoveryVelocity: recoveryVelocity ?? this.recoveryVelocity,
      progressionVelocity: progressionVelocity ?? this.progressionVelocity,
      volumeTolerance: volumeTolerance ?? this.volumeTolerance,
      preferredSessionDuration:
          preferredSessionDuration ?? this.preferredSessionDuration,
      preferredTrainingDays:
          preferredTrainingDays ?? this.preferredTrainingDays,
      preferredTrainingTime: preferredTrainingTime ?? this.preferredTrainingTime,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
