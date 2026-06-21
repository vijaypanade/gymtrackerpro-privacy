// lib/engines/adaptive_schedule_engine.dart
// Pure Dart — no Flutter imports.
// Converts RecoveryState into WorkoutReadinessProfile.
//
// Design contract:
//   • RecoveryEngine owns fatigue computation (unchanged).
//   • AdaptiveScheduleEngine owns scheduling decisions (frequency, volume).
//   • AIProvider/Gemini owns exercise selection within the constraints we produce.

import '../models/recovery_state.dart';
import '../models/workout_readiness_profile.dart';

class AdaptiveScheduleEngine {
  AdaptiveScheduleEngine._();

  // ── Public API ────────────────────────────────────────────────────────────

  static WorkoutReadinessProfile compute({
    required RecoveryState recoveryState,
    required int selectedDays,
    required String level,
    required String goal,
    required int totalWorkouts,
  }) {
    final score    = recoveryState.overallScore;
    final isDeload = recoveryState.needsDeload;

    final effective      = _effectiveDays(score, selectedDays, isDeload);
    final volumePercent  = _volumePercentByMuscle(recoveryState.muscleScores);
    final confidence     = _confidenceScore(totalWorkouts);
    final explanation    = _readinessExplanation(score, isDeload);
    final slots          = _muscleSlots(volumePercent, recoveryState.muscleScores, level, isDeload);

    return WorkoutReadinessProfile(
      overallScore:          score,
      effectiveDaysThisWeek: effective,
      confidenceScore:       confidence,
      readinessExplanation:  explanation,
      isDeloadWeek:          isDeload,
      volumePercentByMuscle: Map.unmodifiable(volumePercent),
      muscleSlots:           List.unmodifiable(slots),
    );
  }

  // ── Effective training days ───────────────────────────────────────────────
  //
  // Reduces frequency when systemic recovery is suppressed.
  // Never goes below 2 — keeps training consistent while reducing load.

  static int _effectiveDays(double score, int selectedDays, bool isDeload) {
    int days;
    if (score >= 70) {
      days = selectedDays;
    } else if (score >= 50) {
      days = selectedDays - 1;
    } else if (score >= 30) {
      days = selectedDays - 2;
    } else {
      days = 2;
    }
    if (isDeload) days -= 1;
    return days.clamp(2, selectedDays); // never exceed user's selection; never below 2
  }

  // ── Volume percent by muscle ──────────────────────────────────────────────
  //
  // Continuous scaling replaces the binary suppress/don't pattern.
  // Keys come from RecoveryEngine.muscleScores — same canonical names.

  static Map<String, double> _volumePercentByMuscle(
      Map<String, double> muscleScores) {
    final result = <String, double>{};
    for (final entry in muscleScores.entries) {
      result[entry.key] = _scoreToVolumePercent(entry.value);
    }
    return result;
  }

  static double _scoreToVolumePercent(double score) {
    if (score >= 80) return 1.00;
    if (score >= 65) return 0.85;
    if (score >= 50) return 0.65;
    if (score >= 35) return 0.40;
    return 0.00;
  }

  // ── Confidence score ──────────────────────────────────────────────────────
  //
  // Workout-history-only model: caps at 20 workouts for full calibration.
  // 0 workouts → 0%, 10 workouts → 50%, 20+ workouts → 100%.

  static int _confidenceScore(int totalWorkouts) {
    final double workoutProgress = (totalWorkouts / 20).clamp(0.0, 1.0);
    return (workoutProgress * 100).round().clamp(0, 100);
  }

  // ── Readiness explanation ─────────────────────────────────────────────────
  //
  // Generated deterministically in Dart — not delegated to AI.
  // Deload override takes priority over score-based copy.

  static String _readinessExplanation(double score, bool isDeload) {
    if (isDeload) {
      return 'Recovery indicators suggest a deload week.';
    }
    if (score >= 70) {
      return 'All major muscles are recovered — this is your best window to push.';
    }
    if (score >= 50) {
      return 'Some muscles need additional recovery. Training volume has been adjusted.';
    }
    if (score >= 30) {
      return 'Accumulated fatigue detected. Training frequency has been reduced this week.';
    }
    return 'High fatigue detected. Prioritise recovery and lighter sessions.';
  }

  // ── Muscle slots ──────────────────────────────────────────────────────────
  //
  // targetSets = round(baseSets × effectivePercent)
  // baseSets is level-aware: Beginner 8, Intermediate 12, Advanced 16.
  // When isDeload, volumePercent is halved before applying baseSets.
  // Sorted highest recovery first so Gemini schedules best-recovered muscles first.

  static List<MuscleSlot> _muscleSlots(
    Map<String, double> volumePercent,
    Map<String, double> muscleScores,
    String level,
    bool isDeload,
  ) {
    final int baseSets = switch (level.toLowerCase()) {
      'beginner'     => 8,
      'advanced'     => 16,
      _              => 12, // intermediate (default)
    };

    final entries = volumePercent.entries
        .where((e) => e.value > 0.0) // exclude fully suppressed muscles
        .toList()
      ..sort((a, b) {
        final scoreA = muscleScores[a.key] ?? 0.0;
        final scoreB = muscleScores[b.key] ?? 0.0;
        return scoreB.compareTo(scoreA); // highest recovery first
      });

    return entries
        .map((e) {
          final effectivePercent = isDeload ? e.value * 0.50 : e.value;
          return MuscleSlot(
            muscle:     e.key,
            targetSets: (baseSets * effectivePercent).round(),
          );
        })
        .toList();
  }
}
