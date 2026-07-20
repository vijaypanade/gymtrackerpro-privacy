// lib/services/adaptive_session_service.dart
// RFC-006: Builds an in-memory AdaptiveSession from today's planner data +
// computed training multipliers. Pure function — no side effects.

import '../models/models.dart';
import '../models/adaptive_session.dart';
import '../services/exercise_intelligence.dart';
import '../services/training_adjustment_service.dart';

class AdaptiveSessionService {
  AdaptiveSessionService._();

  static AdaptiveSession build({
    required DayPlan day,
    required TrainingAdjustment adjustment,
    required double confidence, // 0.0–1.0 from DecisionConfidenceEngine
    required List<String> dominantSignals,
    required String dayKey,
  }) {
    final effIntensity = _scaleByConfidence(adjustment.intensityMultiplier, confidence);
    final effVolume    = _scaleByConfidence(adjustment.volumeMultiplier, confidence);

    final exercises = day.exercises.map((ex) {
      // Skip bodyweight and cardio — weight is irrelevant.
      if (ex.bodyweight || ex.unit != 'kg') {
        return AdaptiveExercise(
          exerciseId: ex.id,
          sets: ex.sets.map((s) => AdaptiveSet(
            originalSetId: s.id,
            adaptedWeight: s.weight,
            adaptedReps:   s.reps,
            isOptional:    false,
            plannedWeight: s.weight,
          )).toList(),
        );
      }

      final totalSets  = ex.sets.length;
      final targetSets = (totalSets * effVolume).round().clamp(1, totalSets);

      final sets = ex.sets.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;

        // Never re-adjust a set the user already logged.
        if (s.done) {
          return AdaptiveSet(
            originalSetId: s.id,
            adaptedWeight: s.weight,
            adaptedReps:   s.reps,
            isOptional:    false,
            plannedWeight: s.weight,
          );
        }

        final raw     = s.weight * effIntensity;
        final rounded = WeightRounder.round(raw, ex.equipment);
        final clamped = rounded.clamp(0.0, 500.0);

        return AdaptiveSet(
          originalSetId: s.id,
          adaptedWeight: clamped,
          adaptedReps:   s.reps,
          isOptional:    i >= targetSets,
          plannedWeight: s.weight,  // original ExSet.weight captured at session start
        );
      }).toList();

      return AdaptiveExercise(exerciseId: ex.id, sets: sets);
    }).toList();

    return AdaptiveSession(
      dayKey:               dayKey,
      intensityMultiplier:  effIntensity,
      volumeMultiplier:     effVolume,
      confidence:           confidence,
      reasons:              dominantSignals,
      exercises:            exercises,
      createdAt:            DateTime.now(),
    );
  }

  // Confidence scaling:
  //   ≥ 0.72 (high)   → full multiplier
  //   ≥ 0.55 (medium) → half-strength adjustment
  //   <  0.55 (low)   → no adjustment (1.0)
  static double _scaleByConfidence(double mult, double confidence) {
    if (confidence >= 0.72) return mult;
    if (confidence >= 0.55) return 1.0 + (mult - 1.0) * 0.5;
    return 1.0;
  }
}
