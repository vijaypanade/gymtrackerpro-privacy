// lib/services/ghost_copy_service.dart
// Ghost Copy — carries last week's plan into this week with progressive weights.
//
// Rules:
//   gap = 1 week  → weight + 2.5 kg (progressive overload)
//   gap = 2 weeks → same weight (skipped last week — no progression)
//   gap = 3+ weeks → weight × 0.90 (comeback — ease back in)
//   no log found  → keep existing set weight, no tag

import '../models/models.dart';
import '../models/workout_log.dart';

class GhostCopyService {
  GhostCopyService._();

  /// Returns true if there is enough history to ghost-copy.
  static bool canGhostCopy(List<DayPlan> plan, List<WorkoutLog> logs) =>
      logs.isNotEmpty &&
      plan.any((d) => !d.isRestDay && d.exercises.isNotEmpty);

  /// Resets completion state for the new week and applies ghost weights.
  /// Call this after the weekly completion-state reset.
  static void applyGhostWeights({
    required List<DayPlan> weekPlan,
    required List<WorkoutLog> logs,
  }) {
    final now = DateTime.now();
    for (final day in weekPlan) {
      if (day.isRestDay) continue;
      for (final ex in day.exercises) {
        _applyToExercise(ex, logs, now);
      }
    }
  }

  static void _applyToExercise(
    PlannedExercise ex,
    List<WorkoutLog> logs,
    DateTime now,
  ) {
    // Reset ghost state first
    ex.ghostWeekGap    = 0;
    ex.previousWeight  = 0;

    // Bodyweight / cardio — no weight conversion
    if (ex.unit != 'kg') return;

    final log = _findMostRecentLog(ex.baseId, ex.name, logs);
    if (log == null || log.weight <= 0) return;

    final gapDays  = now.difference(log.date).inDays;
    final gapWeeks = (gapDays / 7).ceil().clamp(1, 99);

    ex.ghostWeekGap   = gapWeeks;
    ex.previousWeight = log.weight;  // show actual last-session weight in UI

    // RFC-006: use plannedWeight as the progressive overload baseline so a
    // temporary adaptive deload (e.g. 95 kg) never permanently reduces the
    // next week's target (which should progress from 100 kg).
    final baseline = log.plannedWeight ?? log.weight;
    final target = _targetWeight(baseline, gapWeeks);
    for (final s in ex.sets) {
      s.weight = target;
    }
  }

  static double _targetWeight(double last, int gapWeeks) {
    final double raw;
    if (gapWeeks == 1) {
      raw = last + 2.5;          // progressive overload
    } else if (gapWeeks == 2) {
      raw = last;                // held — no increase
    } else {
      raw = last * 0.90;         // comeback — 10% reduction
    }
    // Round to nearest 0.5 kg (matches real dumbbell/plate increments)
    return (raw * 2).roundToDouble() / 2;
  }

  static WorkoutLog? _findMostRecentLog(
    String baseId,
    String name,
    List<WorkoutLog> logs,
  ) {
    final normName = _norm(name);
    final normBase = _norm(baseId);

    WorkoutLog? best;
    for (final log in logs) {
      final normLog = log.normalizedExercise;
      if (normLog == normName || normLog == normBase) {
        if (best == null || log.date.isAfter(best.date)) {
          best = log;
        }
      }
    }
    return best;
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  // ── UI helpers ───────────────────────────────────────────────────────────

  /// Returns the tag label for a given weekGap.
  /// Empty string = no tag to show.
  static String tagLabel(int weekGap) {
    switch (weekGap) {
      case 0:  return '';
      case 1:  return '↑ +2.5 kg target';
      case 2:  return '↩ Skipped last week';
      default: return '⚠ Coming back — ease in';
    }
  }

  static bool showTag(int weekGap) => weekGap >= 2;
}
