import '../models/workout_log.dart';
import 'analytics_engine.dart';

class AnalyticsEngineX {
  AnalyticsEngineX._();

  static bool shouldDeload({
    required List<WorkoutLog> logs,
    required int streak,
    required int totalWorkouts,
  }) {
    if (totalWorkouts < 12) return false;
    if (logs.length < 6) return false;

    final last5 = logs.reversed.take(5).toList();
    final avgVol = last5
            .map((l) => l.weight * l.reps)
            .fold(0.0, (a, b) => a + b) /
        last5.length;

    final plateau = AnalyticsEngine.computePlateauScore(logs: logs);
    final improvement = AnalyticsEngine.computeWeeklyImprovement(logs: logs);

    if (streak >= 14 && (plateau >= 60 || improvement < -10)) return true;
    if (streak >= 7  && improvement < -15) return true;
    if (avgVol < 5000 && plateau >= 70 && streak >= 4) return true;

    return false;
  }
}
