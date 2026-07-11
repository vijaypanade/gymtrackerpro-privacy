// lib/memory/models/athlete_baseline.dart

/// Immutable baseline statistics for an athlete.
///
/// Used by AthleteMemory to capture long-term training baseline values.
class AthleteBaseline {
  final double baseStrengthKg;
  final double baseWorkloadKg;
  final int baseWeeklyTrainingDays;

  const AthleteBaseline({
    required this.baseStrengthKg,
    required this.baseWorkloadKg,
    required this.baseWeeklyTrainingDays,
  });
}
