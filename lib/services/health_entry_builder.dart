// lib/services/health_entry_builder.dart
// Maps HealthWorkout → HistoryEntry.
//
// CONTRACT:
//   • HistoryEntry.id is ALWAYS IdHelper.uuid() — never the HealthKit UUID.
//   • The HealthKit UUID is stored as HistoryEntry.externalId for dedup.
//   • externalSource is always 'apple_health' for entries from this builder.
//   • xpEarned uses XPSystem.xpWorkoutComplete as the standard grant.

import '../models/health_models.dart';
import '../models/models.dart';
import '../utils/id_helper.dart';

class HealthEntryBuilder {
  HealthEntryBuilder._();

  /// The source identifier written to HistoryEntry.externalSource.
  static const String sourceId = 'apple_health';

  static HistoryEntry fromHealthWorkout(HealthWorkout workout) {
    return HistoryEntry(
      id:              IdHelper.uuid(),    // LiftOn UUID — never the HK UUID
      date:            workout.date,
      workoutName:     workout.workoutType,
      durationMinutes: workout.durationMinutes,
      totalVolume:     workout.totalEnergyKcal, // kcal used as volume proxy
      exerciseCount:   0,                 // not tracked in Apple Watch workouts
      setCount:        0,
      xpEarned:        XPSystem.xpWorkoutComplete,
      externalSource:  sourceId,
      externalId:      workout.externalId, // HK UUID — dedup anchor
    );
  }
}
