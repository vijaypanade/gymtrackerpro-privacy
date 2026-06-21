// lib/services/athlete_memory_service.dart
// Pure Dart — no Flutter imports.
// Derives AthleteMemorySnapshot from observed training data.
//
// All inference is statistical — no user self-report required.
// Minimum viable dataset: 3 sessions. Confidence scales with session count.
//
// SAFETY CONTRACT:
//   Output language is observational and neutral.
//   No shame, no guilt. Never says "you failed" or "you are weak."
//   athlete_identity_summary is one calm, direct observational line.

import '../models/athlete_memory.dart';
import '../models/models.dart';
import '../models/workout_log.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Inferred preferred session style — derived from avg session volume + duration.
enum SessionStyle { longIntense, moderate, short, variable }

extension SessionStyleLabel on SessionStyle {
  String get label => switch (this) {
    SessionStyle.longIntense => 'Long & Intense',
    SessionStyle.moderate    => 'Moderate',
    SessionStyle.short       => 'Short & Focused',
    SessionStyle.variable    => 'Variable',
  };
}

/// Experience tier inferred from total session count + progression rate.
/// Used internally — not surfaced directly to the user.
enum ExperienceTier { beginner, developing, intermediate, advanced }

// ── Output model ──────────────────────────────────────────────────────────────

class AthleteMemorySnapshot {
  /// Top 3 most frequently logged exercises (last 60 days).
  final List<String> favoriteExercises;
  /// Exercises present in the week plan but rarely or never logged.
  final List<String> avoidedExercises;
  /// Exercises with a consistent upward volume or weight trend.
  final List<String> strongestMovements;
  /// Inferred from average session volume relative to the athlete's own baseline.
  final SessionStyle preferredSessionStyle;
  /// Muscle groups with historically low recovery scores or low training frequency.
  final List<String> recurringWeakPoints;
  /// Exercises showing clear month-over-month weight or volume progression.
  final List<String> progressionMovements;
  /// One calm observational line about the athlete's training identity.
  final String athleteIdentitySummary;
  /// Inferred experience tier — governs UI detail level.
  final ExperienceTier experienceTier;
  final DateTime computedAt;

  const AthleteMemorySnapshot({
    required this.favoriteExercises,
    required this.avoidedExercises,
    required this.strongestMovements,
    required this.preferredSessionStyle,
    required this.recurringWeakPoints,
    required this.progressionMovements,
    required this.athleteIdentitySummary,
    required this.experienceTier,
    required this.computedAt,
  });

  static AthleteMemorySnapshot get empty => AthleteMemorySnapshot(
    favoriteExercises:    const [],
    avoidedExercises:     const [],
    strongestMovements:   const [],
    preferredSessionStyle: SessionStyle.moderate,
    recurringWeakPoints:  const [],
    progressionMovements: const [],
    athleteIdentitySummary: '',
    experienceTier:       ExperienceTier.beginner,
    computedAt:           DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AthleteMemoryService {
  AthleteMemoryService._();

  static const int _minSessions = 3;

  /// Build an AthleteMemorySnapshot from observed training data.
  /// Returns [AthleteMemorySnapshot.empty] when insufficient data exists.
  static AthleteMemorySnapshot build({
    required List<WorkoutLog>   logs,
    required List<HistoryEntry> history,
    required StreakData          streak,
    required List<DayPlan>      weekPlan,
    required AthleteMemory      memory,
  }) {
    if (history.length < _minSessions || logs.isEmpty) {
      return AthleteMemorySnapshot.empty;
    }

    final now      = DateTime.now();
    final cutoff60 = now.subtract(const Duration(days: 60));
    final cutoff30 = now.subtract(const Duration(days: 30));

    final recentLogs = logs.where((l) => l.date.isAfter(cutoff60)).toList();

    // ── 1. Favorite exercises (top 3, last 60 days) ───────────────────────
    final exCount = <String, int>{};
    for (final l in recentLogs) {
      final name = l.exercise.replaceAll('_', ' ');
      exCount[name] = (exCount[name] ?? 0) + 1;
    }
    final favorites = (exCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => _capitalize(e.key))
        .toList();

    // ── 2. Avoided exercises (planned but rarely logged in 30 days) ───────
    final planned30Logs = logs.where((l) => l.date.isAfter(cutoff30)).map((l) => l.exercise).toSet();
    final avoided = <String>[];
    for (final day in weekPlan) {
      if (day.isRestDay) continue;
      for (final ex in day.exercises) {
        final key = ex.baseId;
        if (!planned30Logs.contains(key)) {
          final display = _capitalize(ex.name);
          if (!avoided.contains(display)) avoided.add(display);
        }
      }
    }

    // ── 3. Strongest movements (best progression, any time) ───────────────
    final strongestMovements = _detectProgressionMovements(logs, top: 3);

    // ── 4. Preferred session style ────────────────────────────────────────
    // Infer from average session volume relative to the 4-week rolling average
    final avgWeeklyVol = memory.avgWeeklyVolume;
    final weeklyVol    = recentLogs.fold(0.0, (s, l) => s + l.volume) / 8;
    final sessionStyle = _inferSessionStyle(avgWeeklyVol, weeklyVol, history);

    // ── 5. Recurring weak points (low frequency muscles, last 30 days) ────
    final muscleFreq = <String, int>{};
    for (final l in logs.where((l) => l.date.isAfter(cutoff30))) {
      final m = l.muscleGroup ?? '';
      if (m.isNotEmpty) muscleFreq[m] = (muscleFreq[m] ?? 0) + 1;
    }
    final weakPoints = _detectWeakPoints(muscleFreq, weekPlan);

    // ── 6. Progression movements (weight/vol trending up, last 60 days) ───
    final progressionMovements = _detectProgressionMovements(recentLogs, top: 3);

    // ── 7. Experience tier ────────────────────────────────────────────────
    final tier = _inferExperienceTier(streak.totalWorkouts, memory.avgWeeklyVolume);

    // ── 8. Identity summary ───────────────────────────────────────────────
    final summary = _buildIdentitySummary(
      tier:            tier,
      sessionStyle:    sessionStyle,
      favorites:       favorites,
      progressionMovements: progressionMovements,
      consistency:     memory.consistencyScore,
      weeklyVol:       weeklyVol,
      total:           streak.totalWorkouts,
    );

    return AthleteMemorySnapshot(
      favoriteExercises:     favorites,
      avoidedExercises:      avoided.take(3).toList(),
      strongestMovements:    strongestMovements,
      preferredSessionStyle: sessionStyle,
      recurringWeakPoints:   weakPoints.take(2).toList(),
      progressionMovements:  progressionMovements,
      athleteIdentitySummary: summary,
      experienceTier:        tier,
      computedAt:            now,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<String> _detectProgressionMovements(List<WorkoutLog> logs, {int top = 3}) {
    // Group by exercise, check if last 3 sessions show upward weight trend
    final byEx = <String, List<WorkoutLog>>{};
    for (final l in logs) {
      if (l.weight <= 0) continue;
      byEx.putIfAbsent(l.exercise, () => []).add(l);
    }
    final progressors = <String>[];
    for (final entry in byEx.entries) {
      final sessions = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (sessions.length < 3) continue;
      final recent = sessions.sublist(sessions.length >= 5 ? sessions.length - 5 : 0);
      // Simple upward trend: last weight >= first weight + 1 increment
      if (recent.last.weight >= recent.first.weight + 1.0) {
        progressors.add(_capitalize(entry.key.replaceAll('_', ' ')));
      }
    }
    return progressors.take(top).toList();
  }

  static SessionStyle _inferSessionStyle(
    double avgWeeklyVolume,
    double currentWeeklyVol,
    List<HistoryEntry> history,
  ) {
    if (avgWeeklyVolume <= 0 || history.length < 4) return SessionStyle.moderate;

    // High-variance volume across sessions → variable
    final vols = history
        .take(12)
        .map((h) => h.totalVolume)
        .toList();
    if (vols.length >= 4) {
      final avg  = vols.reduce((a, b) => a + b) / vols.length;
      final vari = vols.map((v) => (v - avg).abs()).reduce((a, b) => a + b) / vols.length;
      if (vari > avg * 0.40) return SessionStyle.variable;
    }

    final ratio = currentWeeklyVol / avgWeeklyVolume;
    if (ratio > 1.25) return SessionStyle.longIntense;
    if (ratio < 0.65) return SessionStyle.short;
    return SessionStyle.moderate;
  }

  static List<String> _detectWeakPoints(
    Map<String, int> muscleFreq,
    List<DayPlan> weekPlan,
  ) {
    // Muscles present in the week plan but rarely hit
    final plannedMuscles = <String>{};
    for (final day in weekPlan) {
      if (day.isRestDay) continue;
      for (final ex in day.exercises) {
        final cat = ex.category.toLowerCase();
        if (cat.isNotEmpty) plannedMuscles.add(cat);
      }
    }
    if (plannedMuscles.isEmpty || muscleFreq.isEmpty) return const [];

    final maxFreq = muscleFreq.values.isEmpty ? 1 : muscleFreq.values.reduce((a, b) => a > b ? a : b);
    return plannedMuscles
        .where((m) => (muscleFreq[m] ?? 0) < maxFreq * 0.35)
        .map(_capitalize)
        .toList();
  }

  static ExperienceTier _inferExperienceTier(int totalWorkouts, double avgWeeklyVol) {
    if (totalWorkouts < 15) return ExperienceTier.beginner;
    if (totalWorkouts < 50) return ExperienceTier.developing;
    if (totalWorkouts < 150 || avgWeeklyVol < 2000) return ExperienceTier.intermediate;
    return ExperienceTier.advanced;
  }

  static String _buildIdentitySummary({
    required ExperienceTier  tier,
    required SessionStyle    sessionStyle,
    required List<String>    favorites,
    required List<String>    progressionMovements,
    required int             consistency,
    required double          weeklyVol,
    required int             total,
  }) {
    if (total < _minSessions) return '';

    // High consistency + progression
    if (consistency >= 80 && progressionMovements.isNotEmpty) {
      final ex = progressionMovements.first;
      return 'Consistent athlete with measurable progression — $ex is trending upward.';
    }
    // Strong favorite signal
    if (favorites.isNotEmpty && sessionStyle == SessionStyle.longIntense) {
      return 'High-volume training style. ${favorites.first} is a reliable anchor movement.';
    }
    if (favorites.isNotEmpty && sessionStyle == SessionStyle.short) {
      return 'Focused training style — ${favorites.first} dominates short, dense sessions.';
    }
    // Tier-based identity
    switch (tier) {
      case ExperienceTier.beginner:
        return 'Early-phase athlete building foundational movement patterns.';
      case ExperienceTier.developing:
        return 'Developing athlete — consistency is driving adaptation.';
      case ExperienceTier.intermediate:
        return 'Intermediate athlete with established training habits.';
      case ExperienceTier.advanced:
        return 'Advanced athlete — session quality and recovery management are the priority.';
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
