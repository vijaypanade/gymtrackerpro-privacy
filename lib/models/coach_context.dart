// lib/models/coach_context.dart
// Snapshot of athlete context assembled once per message generation.
// All fields are plain Dart — no Flutter, no provider deps.

class PREvent {
  final String   exercise;
  final double   weight;
  final int      reps;
  final DateTime date;
  final bool     isRepPR; // true = same weight, more reps; false = weight PR

  const PREvent({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    this.isRepPR = false,
  });

  String get display {
    if (weight <= 0) return '$reps reps';
    return '${weight % 1 == 0 ? weight.toInt() : weight}kg × $reps';
  }
}

class CoachContext {
  final int totalWorkouts;
  final int currentStreak;
  final int daysSinceLastWorkout;

  final double weeklyVolume;
  final double previousWeeklyVolume;

  final List<PREvent>       recentPRs;
  final Map<String, int>    muscleRecovery;   // muscle (lower) → 0–100
  final Map<String, int>    muscleLastDays;   // muscle (lower) → days since trained
  final List<String>        skippedMuscles;   // 14+ days untrained

  final bool   isDeloadWeek;
  final bool   isPlannedRestDay;
  final String goal;
  final String level;
  final int    age;

  const CoachContext({
    required this.totalWorkouts,
    required this.currentStreak,
    required this.daysSinceLastWorkout,
    required this.weeklyVolume,
    required this.previousWeeklyVolume,
    required this.recentPRs,
    required this.muscleRecovery,
    required this.muscleLastDays,
    required this.skippedMuscles,
    required this.isDeloadWeek,
    this.isPlannedRestDay = false,
    required this.goal,
    required this.level,
    required this.age,
  });

  bool get hasVolumeSpike =>
      previousWeeklyVolume > 0 && weeklyVolume > previousWeeklyVolume * 1.25;

  bool get hasVolumeDropSignificant =>
      previousWeeklyVolume > 0 && weeklyVolume < previousWeeklyVolume * 0.70;

  PREvent? get latestPR {
    if (recentPRs.isEmpty) return null;
    return recentPRs.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  // Lowest-recovery muscle below the alert threshold
  MapEntry<String, int>? get mostFatiguedMuscle {
    if (muscleRecovery.isEmpty) return null;
    final below = muscleRecovery.entries.where((e) => e.value < 50).toList();
    if (below.isEmpty) return null;
    below.sort((a, b) => a.value.compareTo(b.value));
    return below.first;
  }

  // Best-recovered muscle (first candidate for training)
  MapEntry<String, int>? get mostReadyMuscle {
    if (muscleRecovery.isEmpty) return null;
    final sorted = muscleRecovery.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }
}
