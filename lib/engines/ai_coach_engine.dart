import '../models/workout_log.dart';
import 'analytics_engine.dart';

class AnalyticsEngineX {
  AnalyticsEngineX._();

  static bool shouldDeload({
    required List<WorkoutLog> logs,
    required int streak,
    required int totalWorkouts,
    required double fatigue,
    required double readiness,
    required double plateau,
    required String trainingAge,
  }) {
    if (logs.isEmpty || totalWorkouts < 6) return false;

    final age = trainingAge.toLowerCase().trim();
    final isNovice = age == 'novice' || age == 'beginner';
    final isAdvanced = age == 'advanced' || age == 'elite';

    final acwr = AnalyticsEngine.computeACWR(logs: logs);

    if (acwr.ratio > 1.5) return true;
    if (acwr.ratio > 1.3 && fatigue > 65) return true;

    if (streak > 21 && fatigue > 50) return true;
    if (streak >= 14 && fatigue > 60) return true;

    if (isNovice) {
      return fatigue > 80 || (fatigue > 70 && readiness < 40);
    }

    if (fatigue > 75 && readiness < 50) return true;
    if (readiness < 40 && fatigue > 60) return true;

    if (plateau > 70 && logs.length >= 12) {
      if (isAdvanced || fatigue > 55) return true;
    }

    if (isAdvanced) {
      final oldest = logs
          .map((l) => l.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final weeksTrained =
          DateTime.now().difference(oldest).inDays / 7.0;

      if (weeksTrained >= 4 && fatigue > 50) return true;
    }

    if (_volumeDroppingTrend(logs)) return true;

    return false;
  }

  static bool _volumeDroppingTrend(List<WorkoutLog> logs) {
    if (logs.length < 3) return false;

    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    final v1 = _sessionVolume(sorted[0]);
    final v2 = _sessionVolume(sorted[1]);
    final v3 = _sessionVolume(sorted[2]);

    if (v2 <= 0 || v3 <= 0) return false;

    final drop1 = (v2 - v1) / v2;
    final drop2 = (v3 - v2) / v3;

    return drop1 > 0.20 && drop2 > 0.20;
  }

  static double _sessionVolume(WorkoutLog l) {
    final reps = l.reps > 0 ? l.reps : 1;
    return l.weight * reps;
  }
}