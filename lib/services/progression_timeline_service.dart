// lib/services/progression_timeline_service.dart
// Pure Dart — no Flutter imports.
// Builds longitudinal progression data for graphing + movement mastery scoring.
//
// Graph philosophy:
//   - Weekly datapoints (not per-session) — smooth trends, not noise
//   - PR markers annotated on timeline
//   - Recovery overlays: deload/comeback periods noted in labels
//
// Movement mastery:
//   Signals: consistency (logged this week?), progression (weight trending up),
//             stability (low variance), completion rate.
//   Score: 0–100 weighted average.

import '../models/workout_log.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class ProgressionDataPoint {
  /// ISO week start date.
  final DateTime weekStart;
  final double value;
  /// Non-null when a milestone should be annotated (e.g. 'PR', 'Deload', 'Comeback').
  final String? label;

  const ProgressionDataPoint({
    required this.weekStart,
    required this.value,
    this.label,
  });
}

enum ProgressionMetric { strengthEstimate, weeklyVolume, consistency, movementMastery }

extension ProgressionMetricLabel on ProgressionMetric {
  String get displayName => switch (this) {
    ProgressionMetric.strengthEstimate => 'Strength Trend',
    ProgressionMetric.weeklyVolume     => 'Volume',
    ProgressionMetric.consistency      => 'Consistency',
    ProgressionMetric.movementMastery  => 'Movement Mastery',
  };
}

class ExerciseMastery {
  final String exercise;
  /// 0–100 composite mastery score.
  final double masteryScore;
  /// 'improving' | 'stable' | 'inconsistent'
  final String trend;
  /// One observational insight line.
  final String insight;
  /// Number of logged sessions for this exercise.
  final int sessionCount;

  const ExerciseMastery({
    required this.exercise,
    required this.masteryScore,
    required this.trend,
    required this.insight,
    required this.sessionCount,
  });
}

class ProgressionTimeline {
  final ProgressionMetric metric;
  final List<ProgressionDataPoint> dataPoints;
  /// Populated when metric == movementMastery.
  final List<ExerciseMastery> movementMastery;

  const ProgressionTimeline({
    required this.metric,
    required this.dataPoints,
    this.movementMastery = const [],
  });

  bool get hasData => dataPoints.isNotEmpty;

  static ProgressionTimeline empty(ProgressionMetric m) =>
      ProgressionTimeline(metric: m, dataPoints: const []);
}

// ── Service ───────────────────────────────────────────────────────────────────

class ProgressionTimelineService {
  ProgressionTimelineService._();

  /// Build a weekly timeline for [metric] from raw workout logs.
  /// Returns at most 12 datapoints (3 months).
  static ProgressionTimeline buildTimeline(
    List<WorkoutLog> logs,
    ProgressionMetric metric, {
    int weeksBack = 12,
  }) {
    if (logs.isEmpty) return ProgressionTimeline.empty(metric);

    final now   = DateTime.now();
    final weeks = <DateTime, List<WorkoutLog>>{};

    // Build week buckets (Monday-anchored ISO weeks)
    for (int w = weeksBack - 1; w >= 0; w--) {
      final weekStart = _monday(now.subtract(Duration(days: w * 7)));
      weeks[weekStart] = [];
    }
    for (final log in logs) {
      final wk = _monday(log.date);
      if (weeks.containsKey(wk)) {
        weeks[wk]!.add(log);
      }
    }

    switch (metric) {
      case ProgressionMetric.weeklyVolume:
        return _buildVolumeTimeline(weeks);
      case ProgressionMetric.strengthEstimate:
        return _buildStrengthTimeline(weeks, logs);
      case ProgressionMetric.consistency:
        return _buildConsistencyTimeline(weeks);
      case ProgressionMetric.movementMastery:
        return ProgressionTimeline(
          metric:         metric,
          dataPoints:     const [],
          movementMastery: computeMastery(logs),
        );
    }
  }

  /// Compute movement mastery for the top [topN] most-logged exercises.
  static List<ExerciseMastery> computeMastery(List<WorkoutLog> logs, {int topN = 5}) {
    if (logs.isEmpty) return const [];

    // Group by exercise
    final byEx = <String, List<WorkoutLog>>{};
    for (final l in logs) {
      byEx.putIfAbsent(l.exercise, () => []).add(l);
    }

    // Rank by session count, take top N
    final sorted = byEx.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return sorted.take(topN).map((entry) {
      final sessions = entry.value..sort((a, b) => a.date.compareTo(b.date));
      return _scoreMastery(
        name:     _capitalize(entry.key.replaceAll('_', ' ')),
        sessions: sessions,
      );
    }).toList();
  }

  // ── Timeline builders ─────────────────────────────────────────────────────

  static ProgressionTimeline _buildVolumeTimeline(Map<DateTime, List<WorkoutLog>> weeks) {
    final points = <ProgressionDataPoint>[];
    for (final entry in weeks.entries) {
      final vol = entry.value.fold(0.0, (s, l) => s + l.volume);
      // Label weeks with notably high volume as potential overload markers
      String? lbl;
      if (points.isNotEmpty && vol > 0) {
        final prev = points.last.value;
        if (prev > 0 && vol > prev * 1.20) lbl = 'Volume spike';
        if (prev > 0 && vol < prev * 0.55 && vol > 0) lbl = 'Deload';
      }
      points.add(ProgressionDataPoint(weekStart: entry.key, value: vol, label: lbl));
    }
    return ProgressionTimeline(metric: ProgressionMetric.weeklyVolume, dataPoints: points);
  }

  static ProgressionTimeline _buildStrengthTimeline(
    Map<DateTime, List<WorkoutLog>> weeks,
    List<WorkoutLog> allLogs,
  ) {
    // Use Epley 1RM estimate for compound exercises only (weight > 0, reps > 0)
    final points = <ProgressionDataPoint>[];
    double prevPeak = 0;

    for (final entry in weeks.entries) {
      final compoundLogs = entry.value.where((l) => l.weight > 0 && l.reps > 0).toList();
      if (compoundLogs.isEmpty) {
        if (points.isNotEmpty) {
          points.add(ProgressionDataPoint(weekStart: entry.key, value: points.last.value));
        }
        continue;
      }
      // Peak Epley 1RM this week across all exercises
      final peak = compoundLogs.map((l) => _epley(l.weight, l.reps)).reduce((a, b) => a > b ? a : b);

      String? lbl;
      if (prevPeak > 0 && peak > prevPeak * 1.03) lbl = 'PR';
      if (prevPeak > 0 && peak > prevPeak * 1.08) lbl = 'PR ↑';

      points.add(ProgressionDataPoint(weekStart: entry.key, value: peak, label: lbl));
      if (peak > prevPeak) prevPeak = peak;
    }
    return ProgressionTimeline(metric: ProgressionMetric.strengthEstimate, dataPoints: points);
  }

  static ProgressionTimeline _buildConsistencyTimeline(Map<DateTime, List<WorkoutLog>> weeks) {
    // Consistency = did the athlete log at least one session this week? (binary → rolling 4-week %)
    final points = <ProgressionDataPoint>[];
    final activeFlags = <bool>[];

    for (final entry in weeks.entries) {
      activeFlags.add(entry.value.isNotEmpty);
      final lookback = activeFlags.length < 4 ? activeFlags : activeFlags.sublist(activeFlags.length - 4);
      final pct = (lookback.where((b) => b).length / lookback.length * 100).roundToDouble();
      String? lbl;
      if (pct == 100 && lookback.length == 4) lbl = '4-week streak';
      if (pct == 0   && lookback.length == 4) lbl = 'Gap';
      points.add(ProgressionDataPoint(weekStart: entry.key, value: pct, label: lbl));
    }
    return ProgressionTimeline(metric: ProgressionMetric.consistency, dataPoints: points);
  }

  // ── Mastery scoring ───────────────────────────────────────────────────────

  static ExerciseMastery _scoreMastery({
    required String          name,
    required List<WorkoutLog> sessions,
  }) {
    final n = sessions.length;

    // ── Consistency (0–100): weeks trained / total available weeks
    final firstDate = sessions.first.date;
    final daysSpan  = DateTime.now().difference(firstDate).inDays.clamp(7, 365);
    final weeksSpan = (daysSpan / 7).ceil();
    // Count distinct ISO weeks
    final trainedWeeks = sessions.map((l) => _monday(l.date)).toSet().length;
    final consistencyScore = ((trainedWeeks / weeksSpan) * 100).clamp(0.0, 100.0);

    // ── Progression (0–100): weight trend direction
    double progressionScore = 50.0; // neutral baseline
    final withWeight = sessions.where((l) => l.weight > 0 && l.reps > 0).toList();
    if (withWeight.length >= 3) {
      final first3avg = withWeight.take(3).map((l) => l.weight).reduce((a, b) => a + b) / 3;
      final last3avg  = withWeight.sublist(withWeight.length >= 5 ? withWeight.length - 3 : 0)
          .map((l) => l.weight).reduce((a, b) => a + b) /
          withWeight.sublist(withWeight.length >= 5 ? withWeight.length - 3 : 0).length;
      final delta = (last3avg - first3avg) / first3avg.clamp(0.01, double.infinity);
      progressionScore = (50 + delta * 250).clamp(0.0, 100.0);
    }

    // ── Stability (0–100): low variance = high stability
    double stabilityScore = 75.0;
    if (withWeight.length >= 4) {
      final weights = withWeight.map((l) => l.weight).toList();
      final avg     = weights.reduce((a, b) => a + b) / weights.length;
      final variance = weights.map((w) => (w - avg) * (w - avg)).reduce((a, b) => a + b) / weights.length;
      final cv = avg > 0 ? (variance.abs().clamp(0.0, double.infinity)) : 0.0;
      // Lower coefficient of variation = higher stability
      stabilityScore = (100 - (cv.clamp(0.0, 5000.0) / 50)).clamp(0.0, 100.0);
    }

    // ── Composite mastery score
    final masteryScore = (consistencyScore * 0.40 + progressionScore * 0.40 + stabilityScore * 0.20)
        .clamp(0.0, 100.0);

    // ── Trend string
    final String trend;
    if (progressionScore >= 65 && consistencyScore >= 55) {
      trend = 'improving';
    } else if (stabilityScore < 50) {
      trend = 'inconsistent';
    } else {
      trend = 'stable';
    }

    // ── Insight line
    final insight = _masteryInsight(name, trend, masteryScore, n);

    return ExerciseMastery(
      exercise:     name,
      masteryScore: masteryScore,
      trend:        trend,
      insight:      insight,
      sessionCount: n,
    );
  }

  static String _masteryInsight(String name, String trend, double score, int n) {
    if (n < 3) return '$name — too few sessions to assess mastery.';
    if (trend == 'improving' && score >= 75) {
      return '$name volume tolerance is increasing consistently.';
    }
    if (trend == 'improving') {
      return '$name is showing a positive progression trend.';
    }
    if (trend == 'inconsistent') {
      return '$name performance variance is high — consider load standardization.';
    }
    if (score >= 70) {
      return '$name is dialed in — stable and reproducible.';
    }
    return '$name is logged consistently. Progression is moderate.';
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Monday of the ISO week containing [date].
  static DateTime _monday(DateTime date) {
    final offset = date.weekday - 1; // Monday = 1
    final monday = date.subtract(Duration(days: offset));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Epley 1RM estimate: w × (1 + reps / 30).
  static double _epley(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
