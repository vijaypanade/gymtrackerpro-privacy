// lib/services/athlete_profile_service.dart
// Derives an AthleteMemory snapshot from raw workout data.
// All inference is statistical — no user self-report.

import '../models/athlete_memory.dart';
import '../models/models.dart'    show HistoryEntry, StreakData, DayPlan;
import '../models/workout_log.dart';

class AthleteProfileService {
  AthleteProfileService._();

  /// Build a fresh AthleteMemory from observed training data.
  /// Pass [previous] to preserve topicCooldown + peak momentum across rebuilds.
  static AthleteMemory buildMemory({
    required List<WorkoutLog>   logs,
    required List<HistoryEntry> history,
    required StreakData          streak,
    required List<DayPlan>      weekPlan,
    required double             weeklyVolume,
    required double             previousWeeklyVolume,
    List<String>                recentPRExercises = const [],
    AthleteMemory?              previous,
  }) {
    final now    = DateTime.now();
    final cutoff30 = now.subtract(const Duration(days: 30));

    // ── Favorite lift ───────────────────────────────────────
    final exerciseCount = <String, int>{};
    for (final log in logs) {
      exerciseCount[log.exercise] = (exerciseCount[log.exercise] ?? 0) + 1;
    }
    final favoriteLift = exerciseCount.isEmpty
        ? ''
        : (exerciseCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
            .replaceAll('_', ' ');

    // ── Strongest / weakest muscle ──────────────────────────
    final muscleCount = <String, int>{};
    for (final log in logs.where((l) => l.date.isAfter(cutoff30))) {
      final m = log.muscleGroup ?? _muscleFromExercise(log.exercise);
      if (m.isNotEmpty) muscleCount[m] = (muscleCount[m] ?? 0) + 1;
    }

    String strongestMuscle = '';
    String weakestMuscle   = '';
    if (muscleCount.isNotEmpty) {
      final sorted = muscleCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      strongestMuscle = sorted.first.key;
      weakestMuscle   = sorted.last.key;
    }

    // ── Consistency score (last 30 days) ────────────────────
    final recentHistory = history.where((h) {
      final d = DateTime.tryParse(h.date);
      return d != null && d.isAfter(cutoff30);
    }).toList();
    final plannedDays = weekPlan.where((d) => !d.isRestDay).length;

    // Use the user's actual training tenure, not always 30 days.
    // A new user should not be penalised for the time before they started training.
    // effectiveDays = days from their oldest session in the window to today.
    final oldestInWindow = recentHistory.isNotEmpty
        ? DateTime.tryParse(recentHistory.last.date)
        : null;
    final effectiveDays = oldestInWindow != null
        ? now.difference(oldestInWindow).inDays.clamp(1, 30)
        : 1;

    final expected  = ((plannedDays / 7) * effectiveDays).round().clamp(1, 30);
    final completed = recentHistory.length.clamp(0, expected);
    final consistencyScore = ((completed / expected) * 100).round().clamp(0, 100);
    final missedWorkouts = (expected - completed).clamp(0, expected);

    // ── Muscle frequency map ────────────────────────────────
    final muscleFreq = <String, int>{};
    for (final entry in muscleCount.entries) {
      muscleFreq[entry.key] = entry.value;
    }

    // ── Average weekly volume (4-week rolling) ──────────────
    double avgWeeklyVolume = weeklyVolume;
    if (history.length >= 4) {
      // Sum volume from last 28 days of history
      final vol28 = history
          .where((h) {
            final d = DateTime.tryParse(h.date);
            return d != null && d.isAfter(now.subtract(const Duration(days: 28)));
          })
          .fold(0.0, (s, h) => s + h.totalVolume);
      avgWeeklyVolume = vol28 / 4;
    }

    // ── Fatigue pattern ─────────────────────────────────────
    final fatiguePattern = _detectFatiguePattern(history, streak);

    // ── Motivational triggers ────────────────────────────────
    final triggers = _detectMotivationalTriggers(
      streak:               streak,
      logs:                 logs,
      weeklyVolume:         weeklyVolume,
      previousWeeklyVolume: previousWeeklyVolume,
      recentHistory:        recentHistory,
    );

    // ── Long-term memory (Phase 5) ──────────────────────────
    final longestPhase = _longestConsecutiveDays(history);
    final fatigueCollapse = _fatigueCollapseAfterDays(history);

    // motivationSpikeExercises: exercises from logs around PR events
    final spikeExercises = recentPRExercises.isNotEmpty
        ? recentPRExercises.take(5).toList()
        : (previous?.motivationSpikeExercises ?? []);

    // bestMomentumScore: never decreases (preserve peak)
    final prevBest = previous?.bestMomentumScore ?? 0;

    return AthleteMemory(
      favoriteLift:              favoriteLift,
      weakestMuscle:             weakestMuscle,
      strongestMuscle:           strongestMuscle,
      consistencyScore:          consistencyScore,
      missedWorkoutsLast30:      missedWorkouts,
      avgWeeklyVolume:           avgWeeklyVolume,
      fatiguePattern:            fatiguePattern,
      motivationalTriggers:      triggers,
      muscleFrequency:           muscleFreq,
      topicCooldown:             previous?.topicCooldown ?? {},
      updatedAt:                 DateTime.now(),
      bestMomentumScore:         prevBest, // updated by provider after compute
      longestConsistencyPhase:   longestPhase,
      motivationSpikeExercises:  spikeExercises,
      fatigueCollapseAfterDays:  fatigueCollapse,
    );
  }

  // ── Fatigue pattern inference ─────────────────────────────
  static String _detectFatiguePattern(
      List<HistoryEntry> history, StreakData streak) {
    if (history.length < 6) return AthleteMemory.patternNormal;

    // Sort history by date ascending
    final sorted = List.of(history)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date) ?? DateTime(2000);
        final db = DateTime.tryParse(b.date) ?? DateTime(2000);
        return da.compareTo(db);
      });

    // Detect consecutive-day clusters and their lengths
    int maxConsecutive = 0;
    int current        = 1;
    int breakCount     = 0; // times user took 2+ day break
    int clusterCount   = 0; // number of 3+ day runs

    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1].date);
      final curr = DateTime.tryParse(sorted[i].date);
      if (prev == null || curr == null) continue;
      final gap = curr.difference(prev).inDays;

      if (gap <= 1) {
        current++;
        if (current > maxConsecutive) maxConsecutive = current;
      } else {
        if (current >= 3) clusterCount++;
        if (gap >= 2) breakCount++;
        current = 1;
      }
    }

    // 5+ consecutive days without performance drop → high volume tolerant
    if (maxConsecutive >= 5 && streak.longestStreak >= 7) {
      return AthleteMemory.patternHighVolumeTolerant;
    }
    // Consistent 3-day clusters followed by breaks → fatigues_after_3_days
    if (clusterCount >= 3 && breakCount >= clusterCount) {
      return AthleteMemory.patternFatiguesAfter3Days;
    }
    // Takes regular rest but maintains long streak → recovers_fast
    if (breakCount > 0 && streak.longestStreak >= 14) {
      return AthleteMemory.patternRecoversFast;
    }
    return AthleteMemory.patternNormal;
  }

  // ── Motivational trigger inference ───────────────────────
  static List<String> _detectMotivationalTriggers({
    required StreakData          streak,
    required List<WorkoutLog>    logs,
    required double              weeklyVolume,
    required double              previousWeeklyVolume,
    required List<HistoryEntry>  recentHistory,
  }) {
    final triggers = <String>[];

    // Streak-driven: streak was ever >= 7 days
    if (streak.longestStreak >= 7) triggers.add(AthleteMemory.triggerStreaks);

    // PR-driven: heavy compound presence in logs
    final heavyCompounds = ['bench_press', 'squat', 'deadlift',
        'overhead_press', 'barbell_row', 'pull_up'];
    final compoundCount = logs
        .where((l) => heavyCompounds.any((c) => l.exercise.contains(c)))
        .length;
    if (compoundCount >= 5) triggers.add(AthleteMemory.triggerStrength);

    // Volume-growth: 3+ consecutive weeks of volume increase — approximate
    if (previousWeeklyVolume > 0 && weeklyVolume > previousWeeklyVolume * 1.05) {
      triggers.add(AthleteMemory.triggerVolumeGrowth);
    }

    // PR-progress: recentHistory shows improving set counts (proxy for PRs)
    if (recentHistory.length >= 4) {
      final volumes = recentHistory
          .take(4)
          .map((h) => h.totalVolume)
          .toList();
      final rising = volumes.first < volumes.last;
      if (rising) triggers.add(AthleteMemory.triggerPR);
    }

    if (triggers.isEmpty) triggers.add(AthleteMemory.triggerConsistency);
    return triggers;
  }

  // ── Longest consecutive training days ────────────────────
  static int _longestConsecutiveDays(List<HistoryEntry> history) {
    if (history.length < 2) return history.length;
    final sorted = List.of(history)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date) ?? DateTime(2000);
        final db = DateTime.tryParse(b.date) ?? DateTime(2000);
        return da.compareTo(db);
      });
    int max = 1, current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1].date);
      final curr = DateTime.tryParse(sorted[i].date);
      if (prev == null || curr == null) continue;
      if (curr.difference(prev).inDays <= 1) {
        current++;
        if (current > max) max = current;
      } else {
        current = 1;
      }
    }
    return max;
  }

  // ── Days before fatigue collapse (typical cluster length) ─
  // Returns -1 if not detectable from history.
  static int _fatigueCollapseAfterDays(List<HistoryEntry> history) {
    if (history.length < 6) return -1;
    final sorted = List.of(history)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date) ?? DateTime(2000);
        final db = DateTime.tryParse(b.date) ?? DateTime(2000);
        return da.compareTo(db);
      });

    final clusterLengths = <int>[];
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1].date);
      final curr = DateTime.tryParse(sorted[i].date);
      if (prev == null || curr == null) continue;
      final gap = curr.difference(prev).inDays;
      if (gap <= 1) {
        current++;
      } else {
        if (current >= 2) clusterLengths.add(current);
        current = 1;
      }
    }
    if (current >= 2) clusterLengths.add(current);

    if (clusterLengths.length < 3) return -1;
    final sum = clusterLengths.fold(0, (a, b) => a + b);
    return (sum / clusterLengths.length).round();
  }

  // ── Muscle group from exercise key ───────────────────────
  static String _muscleFromExercise(String exercise) {
    final ex = exercise.toLowerCase();
    if (ex.contains('chest') || ex.contains('bench') || ex.contains('fly') ||
        ex.contains('push_up') || ex.contains('pec'))        return 'chest';
    if (ex.contains('back')   || ex.contains('row')    ||
        ex.contains('pulldown') || ex.contains('pull_up'))   return 'back';
    if (ex.contains('squat')  || ex.contains('leg')    ||
        ex.contains('lunge')  || ex.contains('deadlift'))    return 'legs';
    if (ex.contains('shoulder') || ex.contains('delt') ||
        ex.contains('press') && ex.contains('overhead'))     return 'shoulders';
    if (ex.contains('bicep')  || ex.contains('curl'))        return 'biceps';
    if (ex.contains('tricep') || ex.contains('dip') ||
        ex.contains('pushdown') || ex.contains('extension')) return 'triceps';
    if (ex.contains('core')   || ex.contains('plank') ||
        ex.contains('crunch') || ex.contains('ab'))          return 'core';
    if (ex.contains('calf')   || ex.contains('calve'))       return 'calves';
    return '';
  }
}
