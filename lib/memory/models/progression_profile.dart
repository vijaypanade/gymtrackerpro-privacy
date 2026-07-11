// lib/memory/models/progression_profile.dart

/// Immutable progression-related athlete characteristics.
///
/// This model stores long-term progression trends only.
class ProgressionProfile {
  final double averageProgressionRate;
  final int plateauCyclesObserved;
  final int peakPerformanceWeeks;

  const ProgressionProfile({
    required this.averageProgressionRate,
    required this.plateauCyclesObserved,
    required this.peakPerformanceWeeks,
  });
}
