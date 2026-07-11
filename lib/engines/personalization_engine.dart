// lib/engines/personalization_engine.dart
// ─────────────────────────────────────────────────────────────────
// Deterministic behavioral pattern analysis.
// All methods are pure functions — no AI calls, no network, no state.
// Surfaces insights like "You train best on Wednesdays."
// ─────────────────────────────────────────────────────────────────

import '../models/workout_log.dart';

class PersonalizationEngine {
  PersonalizationEngine._();

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  // ── Best Training Day ─────────────────────────────────────────
  // Returns the weekday with the highest average volume over the last 60 days.
  static String? getBestDayInsight(List<WorkoutLog> logs) {
    if (logs.length < 6) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final vol = <int, double>{};
    final cnt = <int, int>{};
    for (final log in logs.where((l) => l.date.isAfter(cutoff))) {
      final wd = log.date.weekday - 1; // 0 = Monday
      vol[wd] = (vol[wd] ?? 0.0) + log.volume;
      cnt[wd] = (cnt[wd] ?? 0) + 1;
    }
    if (vol.isEmpty) return null;
    final avg = vol.map((d, v) => MapEntry(d, v / (cnt[d] ?? 1)));
    final best = avg.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (best.value < 100) return null;
    return 'You train best on ${_weekdays[best.key]}.';
  }

  // ── Post-Rest-Day Strength ─────────────────────────────────────
  // Compares volume on days following a rest day vs other days.
  static String? getRestDayEffectInsight(List<WorkoutLog> logs) {
    if (logs.length < 10) return null;
    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    double afterRest = 0, afterrestN = 0;
    double normal = 0, normalN = 0;

    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (gap >= 2) {
        afterRest += sorted[i].volume;
        afterrestN++;
      } else {
        normal += sorted[i].volume;
        normalN++;
      }
    }
    if (afterrestN < 2 || normalN < 2) return null;
    final avgRest   = afterRest / afterrestN;
    final avgNormal = normal / normalN;
    if (avgRest > avgNormal * 1.12) {
      return 'You perform stronger after rest days.';
    }
    return null;
  }

  // ── Push Strength Trend ───────────────────────────────────────
  // Detects improving trend for a specific muscle group.
  static String? getMuscleProgressInsight(
      List<WorkoutLog> logs, String muscle) {
    final relevant = logs
        .where((l) => l.exercise.contains(muscle.toLowerCase()))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (relevant.length < 4) return null;

    final recent = relevant.sublist(relevant.length - relevant.length ~/ 2);
    final older  = relevant.sublist(0, relevant.length ~/ 2);

    final recentAvg = recent.fold(0.0, (s, l) => s + l.weight) / recent.length;
    final olderAvg  = older.fold(0.0, (s, l) => s + l.weight) / older.length;

    if (olderAvg <= 0) return null;
    final pct = ((recentAvg - olderAvg) / olderAvg) * 100;

    final label = muscle[0].toUpperCase() + muscle.substring(1);
    if (pct >= 8) return '$label strength improving consistently.';
    if (pct <= -8) return '$label performance declining — check recovery.';
    return null;
  }

  // ── Weekly Consistency ────────────────────────────────────────
  // Returns a consistency streak insight if the user has trained
  // consistently for multiple consecutive weeks.
  static String? getConsistencyInsight(List<WorkoutLog> logs) {
    if (logs.isEmpty) return null;
    final now = DateTime.now();
    int consecutiveWeeks = 0;
    for (int w = 1; w <= 8; w++) {
      final weekStart = now.subtract(Duration(days: w * 7));
      final weekEnd   = now.subtract(Duration(days: (w - 1) * 7));
      final count = logs
          .where((l) => l.date.isAfter(weekStart) && l.date.isBefore(weekEnd))
          .map((l) => '${l.date.year}-${l.date.weekOfYear}')
          .toSet()
          .length;
      if (count >= 2) {
        consecutiveWeeks++;
      } else {
        break;
      }
    }
    if (consecutiveWeeks >= 4) {
      return 'You\'ve trained consistently for $consecutiveWeeks weeks.';
    }
    return null;
  }

  // ── Main Adaptive Coaching Insight ───────────────────────────
  // Returns the highest-priority behavioral insight for the AI banner.
  // Cycles through insights in priority order.
  static String getAdaptiveInsight({
    required List<WorkoutLog> logs,
    required int readiness,
    required double weeklyImprovementPct,
    required String topMuscle,
  }) {
    // Priority 1: readiness-aware coaching
    if (readiness > 0 && readiness <= 2) {
      return 'Low readiness detected. Reduce intensity today — quality over quantity.';
    }
    if (readiness >= 5) {
      return 'Peak readiness. Push harder today — body is primed for performance.';
    }

    // Priority 2: weekly trend
    if (weeklyImprovementPct >= 15) {
      return 'Volume up ${weeklyImprovementPct.toStringAsFixed(0)}% this week. '
          'Monitor recovery before pushing further.';
    }
    if (weeklyImprovementPct <= -15) {
      return 'Volume dropped this week. Comeback session will restore momentum.';
    }

    // Priority 3: behavioral pattern (rotates through available insights)
    final insights = <String>[];
    final best = getBestDayInsight(logs);
    if (best != null) insights.add(best);
    final rest = getRestDayEffectInsight(logs);
    if (rest != null) insights.add(rest);
    final consist = getConsistencyInsight(logs);
    if (consist != null) insights.add(consist);
    if (topMuscle.isNotEmpty) {
      final trend = getMuscleProgressInsight(logs, topMuscle);
      if (trend != null) insights.add(trend);
    }

    if (insights.isEmpty) return '';

    // Deterministic rotation: pick based on day of year
    final idx = DateTime.now().dayOfYear % insights.length;
    return insights[idx];
  }
}

// ── DateTime extension helpers ────────────────────────────────
extension _DateTimeExt on DateTime {
  int get weekOfYear {
    final jan1     = DateTime(year, 1, 1);
    final dayOfYear = difference(jan1).inDays;
    return (dayOfYear / 7).ceil();
  }

  int get dayOfYear {
    final jan1 = DateTime(year, 1, 1);
    return difference(jan1).inDays;
  }
}
