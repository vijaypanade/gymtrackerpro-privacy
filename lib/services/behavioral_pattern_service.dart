// lib/services/behavioral_pattern_service.dart
// Pure Dart — no Flutter imports.
// Derives behavioral tendencies from observed training history.
// Used for planner shaping, coach tone calibration, and emotional retention.
//
// SAFETY CONTRACT:
//   Language is observational, never shame-based.
//   "comeback latency" is a behavioral observation, not a judgment.
//   retentionInsightLine focuses on rhythm preservation, not guilt.
//   isAtRiskOfDropout is internal signal — never surfaced as-is to the user.

import '../models/models.dart';

// ── Output model ──────────────────────────────────────────────────────────────

class BehavioralPattern {
  /// Estimated typical session length based on history.
  final int preferredSessionDurationMins;

  /// Average gap in days between sessions when returning after a break.
  final int comebackLatencyDays;

  /// Muscle groups that tend to be absent from recent training.
  final List<String> skippedMuscleTendencies;

  /// Human-readable description of training rhythm, e.g. "3–4 sessions/week".
  final String consistencyRhythm;

  /// Calm, warm retention insight — shown when athlete shows dropout signals.
  final String retentionInsightLine;

  /// True when gap exceeds 1.5x their typical comeback latency — used as
  /// a signal to surface retention messaging, not exposed directly to user.
  final bool isAtRiskOfDropout;

  const BehavioralPattern({
    required this.preferredSessionDurationMins,
    required this.comebackLatencyDays,
    required this.skippedMuscleTendencies,
    required this.consistencyRhythm,
    required this.retentionInsightLine,
    required this.isAtRiskOfDropout,
  });

  static const BehavioralPattern empty = BehavioralPattern(
    preferredSessionDurationMins: 45,
    comebackLatencyDays:          2,
    skippedMuscleTendencies:      [],
    consistencyRhythm:            '',
    retentionInsightLine:         '',
    isAtRiskOfDropout:            false,
  );
}

// ── Input contract ─────────────────────────────────────────────────────────────

class BehavioralPatternInput {
  final List<HistoryEntry> history;
  final int    daysSinceLastWorkout;
  final int    currentStreak;
  final int    totalWorkouts;
  final List<String> skippedMuscleGroups;
  final DateTime now;

  const BehavioralPatternInput({
    required this.history,
    required this.daysSinceLastWorkout,
    required this.currentStreak,
    required this.totalWorkouts,
    required this.skippedMuscleGroups,
    required this.now,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class BehavioralPatternService {
  BehavioralPatternService._();

  static const int _minHistory = 4;

  static BehavioralPattern compute(BehavioralPatternInput i) {
    if (i.history.length < _minHistory || i.totalWorkouts < _minHistory) {
      return BehavioralPattern.empty;
    }

    // ── 1. Preferred session duration ──────────────────────────────────────
    final durations = i.history
        .where((h) => h.durationMinutes > 5)
        .map((h) => h.durationMinutes)
        .toList();
    final avgDuration = durations.isEmpty
        ? 45
        : (durations.reduce((a, b) => a + b) / durations.length).round();

    // ── 2. Consistency rhythm (sessions per week over last 4 weeks) ────────
    final cutoff28 = i.now.subtract(const Duration(days: 28));
    final recentCount = i.history.where((h) {
      final d = DateTime.tryParse(h.date);
      return d != null && d.isAfter(cutoff28);
    }).length;
    final sessionsPerWeek = recentCount / 4.0;
    final rhythm = _rhythmLabel(sessionsPerWeek);

    // ── 3. Comeback latency ────────────────────────────────────────────────
    final comebackDays = _computeComebackLatency(i.history);

    // ── 4. Dropout risk ────────────────────────────────────────────────────
    final isAtRisk = i.daysSinceLastWorkout >= (comebackDays * 1.6).round() &&
        i.currentStreak == 0 &&
        i.totalWorkouts > 5;

    // ── 5. Skipped tendencies ──────────────────────────────────────────────
    final skipped = i.skippedMuscleGroups
        .map((m) => _capitalize(m))
        .take(2)
        .toList();

    // ── 6. Retention insight ───────────────────────────────────────────────
    final retention = _buildRetentionLine(
      daysSince:       i.daysSinceLastWorkout,
      comebackLatency: comebackDays,
      avgDuration:     avgDuration,
      isAtRisk:        isAtRisk,
      sessionsPerWeek: sessionsPerWeek,
      currentStreak:   i.currentStreak,
    );

    return BehavioralPattern(
      preferredSessionDurationMins: avgDuration,
      comebackLatencyDays:          comebackDays,
      skippedMuscleTendencies:      skipped,
      consistencyRhythm:            rhythm,
      retentionInsightLine:         retention,
      isAtRiskOfDropout:            isAtRisk,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _computeComebackLatency(List<HistoryEntry> history) {
    final dates = history
        .map((h) => DateTime.tryParse(h.date))
        .whereType<DateTime>()
        .toList()
      ..sort();

    if (dates.length < 3) return 2;

    final gaps = <int>[];
    for (int j = 1; j < dates.length; j++) {
      final gap = dates[j].difference(dates[j - 1]).inDays;
      // Only meaningful gaps — ignore same-day and extreme absences
      if (gap >= 2 && gap <= 10) gaps.add(gap);
    }

    if (gaps.isEmpty) return 2;
    return (gaps.reduce((a, b) => a + b) / gaps.length).round().clamp(1, 7);
  }

  static String _rhythmLabel(double sessionsPerWeek) {
    if (sessionsPerWeek >= 5) return '5+ sessions/week';
    if (sessionsPerWeek >= 4) return '4–5 sessions/week';
    if (sessionsPerWeek >= 3) return '3–4 sessions/week';
    if (sessionsPerWeek >= 2) return '2–3 sessions/week';
    return '1–2 sessions/week';
  }

  static String _buildRetentionLine({
    required int    daysSince,
    required int    comebackLatency,
    required int    avgDuration,
    required bool   isAtRisk,
    required double sessionsPerWeek,
    required int    currentStreak,
  }) {
    // Dropout risk — warm, low-guilt comeback nudge
    if (isAtRisk) {
      final shortMins = (avgDuration * 0.5).round().clamp(15, 30);
      return 'Even a $shortMins-minute session today keeps your rhythm alive. Showing up is the work.';
    }

    // Gap is growing but not yet at risk
    if (daysSince >= 3 && daysSince < (comebackLatency * 1.6).round()) {
      return 'A lighter session still protects all the progress you\'ve built. Rhythm matters more than duration.';
    }

    // Good streak — affirm without pressuring
    if (currentStreak >= 5 && daysSince <= 1) {
      return 'Strong training rhythm. Recovery quality is the differentiator at this stage.';
    }

    // Active and consistent
    if (sessionsPerWeek >= 3 && daysSince <= 1) {
      return 'Consistency is the only strategy that compounds. You\'re doing it right.';
    }

    // Post-session (just trained)
    if (daysSince == 0) {
      return 'Each session deposits. What you did today is working even when you\'re not in the gym.';
    }

    return 'Staying within your natural training rhythm makes the next session feel easy.';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
