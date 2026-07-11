// lib/engines/correlation_engine.dart
// ─────────────────────────────────────────────────────────────────
// Recovery ↔ Training correlation intelligence.
// All methods are deterministic — no AI calls, no network.
// Surfaces insights like "High volume correlates with lower readiness."
// ─────────────────────────────────────────────────────────────────

import '../models/workout_log.dart';

class CorrelationEngine {
  CorrelationEngine._();

  // ── Consecutive-day fatigue detection ────────────────────────
  // Detects if training consecutive push/legs days correlates
  // with reduced volume in the following session.
  static String? getConsecutiveDayWarning(List<WorkoutLog> logs) {
    if (logs.length < 8) return null;
    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    int consecutiveDrops = 0;
    for (int i = 1; i < sorted.length - 1; i++) {
      final gap = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (gap == 1) {
        final nextGap = sorted[i + 1].date.difference(sorted[i].date).inDays;
        if (nextGap <= 1 && sorted[i + 1].volume < sorted[i].volume * 0.85) {
          consecutiveDrops++;
        }
      }
    }
    if (consecutiveDrops >= 2) {
      return 'Recovery drops after consecutive training days. '
          'Build in rest days for best results.';
    }
    return null;
  }

  // ── Optimal session gap ───────────────────────────────────────
  // Finds whether 1-day or 2-day gaps produce better performance.
  static String? getOptimalGapInsight(List<WorkoutLog> logs) {
    if (logs.length < 10) return null;
    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    double vol1 = 0, vol1N = 0;
    double vol2 = 0, vol2N = 0;

    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (gap == 1) { vol1 += sorted[i].volume; vol1N++; }
      if (gap == 2) { vol2 += sorted[i].volume; vol2N++; }
    }
    if (vol1N < 2 || vol2N < 2) return null;

    final avg1 = vol1 / vol1N;
    final avg2 = vol2 / vol2N;

    if (avg2 > avg1 * 1.1) {
      return 'Best sessions follow a 2-day gap. '
          'Recovery time is paying off.';
    }
    return null;
  }

  // ── Volume → readiness correlation ───────────────────────────
  // Checks if high-volume weeks are followed by lower readiness scores.
  // Requires readiness history paired with logs.
  static String? getVolumeReadinessInsight({
    required List<WorkoutLog> logs,
    required int currentReadiness,
    required double weeklyVolumeKg,
  }) {
    if (currentReadiness <= 0 || logs.length < 5) return null;
    // If this week has high volume AND readiness is low, surface the correlation
    final avgVol = logs.isNotEmpty
        ? logs.fold(0.0, (s, l) => s + l.volume) / logs.length
        : 0.0;
    if (weeklyVolumeKg > avgVol * 1.3 && currentReadiness <= 2) {
      return 'High volume this week correlates with lower readiness. '
          'Consider a lighter session today.';
    }
    return null;
  }

  // ── Main correlation insight ──────────────────────────────────
  // Returns the most relevant correlation-based insight.
  static String? getMainInsight({
    required List<WorkoutLog> logs,
    required int currentReadiness,
    required double weeklyVolumeKg,
  }) {
    final volReadiness = getVolumeReadinessInsight(
      logs:            logs,
      currentReadiness: currentReadiness,
      weeklyVolumeKg:  weeklyVolumeKg,
    );
    if (volReadiness != null) return volReadiness;

    final gap = getOptimalGapInsight(logs);
    if (gap != null) return gap;

    final consecutive = getConsecutiveDayWarning(logs);
    return consecutive;
  }
}
