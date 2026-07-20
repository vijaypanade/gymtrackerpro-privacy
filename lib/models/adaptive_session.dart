// lib/models/adaptive_session.dart
// RFC-006: Runtime Adaptive Session — in-memory only. Never persisted to Hive.
// Created when user taps "Start Adaptive Workout"; cleared at day boundary.

class AdaptiveSet {
  final String originalSetId;
  final double adaptedWeight; // intensity-adjusted, rounded via WeightRounder (equipment-aware)
  final int    adaptedReps;   // unchanged in V1
  final bool   isOptional;    // excess sets trimmed by volumeMultiplier

  /// The original ExSet.weight at the moment startAdaptiveSession() was called.
  /// Captured once and never updated — immutable planning intent.
  /// Used by the done handler to write WorkoutLog.plannedWeight.
  final double plannedWeight;

  const AdaptiveSet({
    required this.originalSetId,
    required this.adaptedWeight,
    required this.adaptedReps,
    required this.isOptional,
    required this.plannedWeight,
  });
}

class AdaptiveExercise {
  final String exerciseId;
  final List<AdaptiveSet> sets;

  const AdaptiveExercise({required this.exerciseId, required this.sets});
}

class AdaptiveSession {
  final String dayKey;               // "YYYY-MM-DD"
  final double intensityMultiplier;
  final double volumeMultiplier;
  final double confidence;           // 0.0–1.0
  final List<String> reasons;
  final List<AdaptiveExercise> exercises;
  final DateTime createdAt;

  const AdaptiveSession({
    required this.dayKey,
    required this.intensityMultiplier,
    required this.volumeMultiplier,
    required this.confidence,
    required this.reasons,
    required this.exercises,
    required this.createdAt,
  });

  // Returns null for bodyweight / cardio exercises — caller skips adaptation.
  AdaptiveSet? setFor(String exerciseId, String setId) {
    for (final ex in exercises) {
      if (ex.exerciseId != exerciseId) continue;
      for (final s in ex.sets) {
        if (s.originalSetId == setId) return s;
      }
    }
    return null;
  }
}
