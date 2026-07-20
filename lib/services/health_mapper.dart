// lib/services/health_mapper.dart
// Maps HealthDataPoint → HealthWorkout?
//
// CONTRACT:
//   • Returns null for any malformed, negative-duration, or invalid input.
//   • A null return NEVER aborts the batch — HealthSyncEngine filters nulls.
//   • This class must NEVER create HistoryEntry objects.
//   • Boundary ends here: output is HealthWorkout, not HistoryEntry.

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/health_models.dart';

class HealthMapper {
  HealthMapper._();

  /// Convert a single [HealthDataPoint] to [HealthWorkout].
  /// Returns null if the data point is malformed or invalid:
  ///   - wrong type (not WORKOUT)
  ///   - wrong value type
  ///   - negative or zero duration
  ///   - dateFrom is after dateTo
  ///   - any unexpected exception during mapping
  static HealthWorkout? toHealthWorkout(HealthDataPoint point) {
    try {
      if (point.type != HealthDataType.WORKOUT) return null;

      final value = point.value;
      if (value is! WorkoutHealthValue) return null;

      if (point.dateFrom.isAfter(point.dateTo)) return null;

      final durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
      if (durationMinutes <= 0) return null;

      // uuid is always a String in health v12.2.1 (defaults to "" when absent).
      // Fall back to millisecond timestamp when uuid is empty to guarantee uniqueness.
      final externalId = point.uuid.isNotEmpty
          ? point.uuid
          : point.dateFrom.millisecondsSinceEpoch.toString();

      final energyKcal = (value.totalEnergyBurned ?? 0).toDouble();

      return HealthWorkout(
        externalId:      externalId,
        workoutType:     _activityName(value.workoutActivityType),
        startTime:       point.dateFrom,
        durationMinutes: durationMinutes,
        totalEnergyKcal: energyKcal,
      );
    } catch (e) {
      debugPrint('health_mapper: skipping malformed point: $e');
      return null;
    }
  }

  // ── Activity name mapping ─────────────────────────────────────────────────

  static String _activityName(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
      case HealthWorkoutActivityType.RUNNING_TREADMILL:
        return 'Running';
      case HealthWorkoutActivityType.WALKING:
      case HealthWorkoutActivityType.WALKING_TREADMILL:
        return 'Walking';
      case HealthWorkoutActivityType.BIKING: // BIKING covers iOS "Cycling" per health pkg
        return 'Cycling';
      case HealthWorkoutActivityType.SWIMMING:
      case HealthWorkoutActivityType.SWIMMING_POOL:
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
        return 'Swimming';
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
      case HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.WEIGHTLIFTING:
        return 'Strength Training';
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
        return 'HIIT';
      case HealthWorkoutActivityType.YOGA:
        return 'Yoga';
      case HealthWorkoutActivityType.HIKING:
        return 'Hiking';
      case HealthWorkoutActivityType.ROWING:
      case HealthWorkoutActivityType.ROWING_MACHINE:
        return 'Rowing';
      case HealthWorkoutActivityType.ELLIPTICAL:
        return 'Elliptical';
      case HealthWorkoutActivityType.STAIR_CLIMBING:
      case HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE:
        return 'Stair Climbing';
      case HealthWorkoutActivityType.PILATES:
        return 'Pilates';
      case HealthWorkoutActivityType.CORE_TRAINING:
        return 'Core Training';
      case HealthWorkoutActivityType.CROSS_TRAINING:
      case HealthWorkoutActivityType.MIXED_CARDIO:
        return 'Cross Training';
      case HealthWorkoutActivityType.BOXING:
      case HealthWorkoutActivityType.KICKBOXING:
      case HealthWorkoutActivityType.MARTIAL_ARTS:
        return 'Martial Arts';
      case HealthWorkoutActivityType.TENNIS:
        return 'Tennis';
      case HealthWorkoutActivityType.BASKETBALL:
        return 'Basketball';
      case HealthWorkoutActivityType.SOCCER:
        return 'Soccer';
      case HealthWorkoutActivityType.GOLF:
        return 'Golf';
      case HealthWorkoutActivityType.CLIMBING:
      case HealthWorkoutActivityType.ROCK_CLIMBING:
        return 'Climbing';
      case HealthWorkoutActivityType.DANCING:
      case HealthWorkoutActivityType.CARDIO_DANCE:
        return 'Dance';
      case HealthWorkoutActivityType.JUMP_ROPE:
        return 'Jump Rope';
      case HealthWorkoutActivityType.CALISTHENICS:
        return 'Calisthenics';
      case HealthWorkoutActivityType.STEP_TRAINING:
        return 'Step Training';
      case HealthWorkoutActivityType.FLEXIBILITY:
      case HealthWorkoutActivityType.COOLDOWN:
        return 'Flexibility';
      case HealthWorkoutActivityType.TAI_CHI:
      case HealthWorkoutActivityType.MIND_AND_BODY:
        return 'Mind & Body';
      case HealthWorkoutActivityType.CROSS_COUNTRY_SKIING:
      case HealthWorkoutActivityType.DOWNHILL_SKIING:
      case HealthWorkoutActivityType.SNOWBOARDING:
        return 'Winter Sports';
      case HealthWorkoutActivityType.SURFING:
      case HealthWorkoutActivityType.WATER_FITNESS:
      case HealthWorkoutActivityType.WATER_SPORTS:
        return 'Water Sports';
      case HealthWorkoutActivityType.BARRE:
        return 'Barre';
      case HealthWorkoutActivityType.SKATING:
        return 'Skating';
      case HealthWorkoutActivityType.VOLLEYBALL:
        return 'Volleyball';
      case HealthWorkoutActivityType.BASEBALL:
        return 'Baseball';
      case HealthWorkoutActivityType.AMERICAN_FOOTBALL:
        return 'American Football';
      case HealthWorkoutActivityType.RUGBY:
        return 'Rugby';
      case HealthWorkoutActivityType.CRICKET:
        return 'Cricket';
      case HealthWorkoutActivityType.HANDBALL:
        return 'Handball';
      case HealthWorkoutActivityType.BADMINTON:
        return 'Badminton';
      case HealthWorkoutActivityType.SQUASH:
        return 'Squash';
      case HealthWorkoutActivityType.RACQUETBALL:
        return 'Racquetball';
      case HealthWorkoutActivityType.PICKLEBALL:
        return 'Pickleball';
      case HealthWorkoutActivityType.TABLE_TENNIS:
        return 'Table Tennis';
      case HealthWorkoutActivityType.FENCING:
        return 'Fencing';
      case HealthWorkoutActivityType.GYMNASTICS:
        return 'Gymnastics';
      case HealthWorkoutActivityType.TRACK_AND_FIELD:
        return 'Track & Field';
      case HealthWorkoutActivityType.SAILING:
        return 'Sailing';
      default:
        return 'Apple Watch Workout';
    }
  }
}
