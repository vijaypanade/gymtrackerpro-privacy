// lib/services/exercise_intelligence.dart
// Deterministic workout intelligence — no AI dependency.
// Handles: equipment-aware weight rounding, volume allocation,
//          rep-range targeting, inter-session progressive overload,
//          intra-workout next-set advice, 1RM estimation.

import '../models/workout_log.dart';

// ─── Rep Range ────────────────────────────────────────────────────────────────
class RepRange {
  final int min;
  final int max;
  const RepRange(this.min, this.max);

  /// Middle of the range — used as the default rep target for initial sets.
  int get mid => ((min + max) / 2).round();
}

// ─── Equipment-Aware Weight Rounder ──────────────────────────────────────────
class WeightRounder {
  WeightRounder._();

  /// Round [raw] to the nearest valid gym increment for [equipment].
  ///
  ///   barbell / machine → 5 kg
  ///   dumbbell / cable  → 2.5 kg
  ///   bodyweight / ''   → 2.5 kg (smallest safe step)
  ///
  /// Passing an empty string is valid and intentional: persisted exercises
  /// that predate the equipment field default to the dumbbell step — the
  /// smallest available increment, which is always the safest fallback.
  /// Call sites must NOT inline-guard this — let WeightRounder own the default.
  static double round(double raw, String equipment) {
    if (raw <= 0) return 0;
    final step    = _step(equipment.toLowerCase().trim());
    final snapped = (raw / step).round() * step;
    return snapped < step ? step : snapped; // floor at one minimum increment
  }

  /// How much weight to add per successful progressive overload attempt.
  /// Empty [equipment] falls back to the dumbbell step (2.5 kg).
  static double progressionStep(String equipment, String movement) {
    switch (equipment.toLowerCase().trim()) {
      case 'barbell': return movement == 'compound' ? 5.0 : 2.5;
      case 'dumbbell': return 2.5;
      case 'cable':   return 2.5;
      case 'machine': return 5.0;
      default:        return 2.5; // '', 'bodyweight', unknown
    }
  }

  static double _step(String eq) {
    switch (eq) {
      case 'barbell': return 5.0;
      case 'machine': return 5.0;
      default:        return 2.5; // dumbbell, cable, bodyweight, '' (unknown)
    }
  }
}

// ─── Volume Allocator ─────────────────────────────────────────────────────────
/// Science-backed per-session set / rep allocation.
/// Compounds receive more sets; later isolations receive fewer.
/// Session totals stay within evidence-based volume caps.
class VolumeAllocator {
  VolumeAllocator._();

  /// Working-set caps per session (total sets across all exercises).
  static const Map<String, ({int min, int max})> sessionCap = {
    'beginner':     (min: 10, max: 14),
    'intermediate': (min: 14, max: 18),
    'advanced':     (min: 16, max: 22),
  };

  /// Sets assigned to exercise at zero-indexed [position] in the session.
  ///
  ///  position 0 (primary compound)  → 4–5 sets
  ///  position 1 (secondary compound) → 3–4 sets
  ///  position 2+ (compound or isolation) → 3 sets
  ///  position 4+ (finishing isolation) → 2 sets
  static int setsForPosition({
    required int    position,
    required String movement,  // 'compound' | 'isolation'
    required String level,
    required String goal,
  }) {
    final isCompound = movement == 'compound';
    final isAdvanced = level == 'advanced';
    final isStrength = goal == 'strength';

    if (position == 0 && isCompound) {
      return (isStrength || isAdvanced) ? 5 : 4;
    }
    if (position == 1 && isCompound) return isAdvanced ? 4 : 3;
    if (isCompound)                  return 3;
    if (position <= 3)               return 3;
    return 2; // finishing isolation
  }

  /// Rep-range target for exercise at [position].
  /// [gender]: 'female' shifts isolation upper bound +2 reps (fatigue resistance advantage).
  static RepRange repRange({
    required int    position,
    required String movement,
    required String goal,
    String          gender = '',
  }) {
    final isCompound  = movement == 'compound';
    // Female physiology: more type-I fibers → higher rep capacity on isolations.
    // Sources: Staron 2000, Hunter 2014, NSCA essentials.
    final repShift = (gender.toLowerCase() == 'female' && !isCompound) ? 2 : 0;

    switch (goal) {
      case 'strength':
        if (isCompound && position == 0) return const RepRange(3, 5);
        if (isCompound)                  return const RepRange(4, 8);
        return RepRange(8, 12 + repShift);

      case 'muscle_gain':
        if (isCompound && position == 0) return const RepRange(6, 10);
        if (isCompound)                  return const RepRange(8, 12);
        if (position <= 2)               return RepRange(10, 15 + repShift);
        return RepRange(12, 20 + repShift);

      case 'fat_loss':
        if (isCompound && position == 0) return const RepRange(10, 15);
        if (isCompound)                  return const RepRange(12, 15);
        return RepRange(15, 20 + repShift);

      default: // recomp / general
        return isCompound ? const RepRange(8, 12) : RepRange(10, 15 + repShift);
    }
  }
}

// ─── Progression Engine — inter-session ───────────────────────────────────────
/// History-based suggestion for what to do NEXT SESSION on a given exercise.
/// Fully deterministic — no randomness, no network calls.
class ProgressionEngine {
  ProgressionEngine._();

  /// Suggest weight and reps for the next session of [exerciseKey].
  static ProgressionResult suggest({
    required String           exerciseKey,
    required List<WorkoutLog> allLogs,
    required String           goal,
    required String           equipment,
    required String           movement,
  }) {
    final key  = exerciseKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final logs = allLogs.where((l) => l.normalizedExercise == key).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (logs.isEmpty) return ProgressionResult.noHistory();

    final step   = WeightRounder.progressionStep(equipment, movement);
    final target = _targetRange(goal, movement == 'compound');
    final last   = logs.first;
    final lastW  = WeightRounder.round(last.weight, equipment);

    // One session — use Epley 1RM to project optimal working weight.
    // Epley: 1RM = w × (1 + reps/30).  Working weight = 1RM / (1 + targetReps/30).
    if (logs.length == 1) {
      final oneRM       = _epleyOneRM(lastW, last.reps);
      final projectedW  = WeightRounder.round(
        oneRM / (1 + target.mid / 30.0),
        equipment,
      );
      final diff        = (projectedW - lastW).abs();
      // Only recommend a weight change if it's at least one increment away.
      if (diff >= step && projectedW > 0) {
        final dir = projectedW > lastW ? ProgressionType.increase : ProgressionType.decrease;
        return ProgressionResult(
          suggestedWeight: projectedW,
          targetReps:      target.mid,
          message:         '1RM ≈ ${oneRM.toStringAsFixed(0)}kg → ${projectedW}kg × ${target.min}–${target.max} reps',
          type:            dir,
        );
      }
      return ProgressionResult(
        suggestedWeight: lastW,
        targetReps:      target.mid,
        message:         'Match last session — aim for ${target.min}–${target.max} reps',
        type:            ProgressionType.maintain,
      );
    }

    final exceeded = last.reps >= target.max;
    final hitRange = last.reps >= target.min;

    // Crushed the top — add load
    if (exceeded) {
      final newW = WeightRounder.round(lastW + step, equipment);
      return ProgressionResult(
        suggestedWeight: newW,
        targetReps:      target.min,
        message:         'Add load → ${newW}kg × ${target.min}–${target.mid} reps',
        type:            ProgressionType.increase,
      );
    }

    // In range — hold weight and add one rep
    if (hitRange) {
      return ProgressionResult(
        suggestedWeight: lastW,
        targetReps:      last.reps + 1,
        message:         'Same weight — push for ${last.reps + 1} reps',
        type:            ProgressionType.maintain,
      );
    }

    // Missed range two sessions in a row → back off
    if (logs.length >= 2 && logs[1].reps < target.min) {
      final reduced = WeightRounder.round(lastW - step, equipment);
      final safe    = reduced > 0 ? reduced : lastW;
      return ProgressionResult(
        suggestedWeight: safe,
        targetReps:      target.max,
        message:         'Back to ${safe}kg — build quality reps first',
        type:            ProgressionType.decrease,
      );
    }

    // Single miss — hold and retry
    return ProgressionResult(
      suggestedWeight: lastW,
      targetReps:      target.max,
      message:         'Same weight — hit ${target.max} clean reps',
      type:            ProgressionType.maintain,
    );
  }

  // ── Intra-workout: advice after each completed set ────────────────────────
  /// After finishing a set, decide what to suggest for the NEXT set.
  static NextSetHint nextSet({
    required double   completedWeight,
    required int      completedReps,
    required RepRange targetRange,
    required String   equipment,
    required String   movement,
  }) {
    final step = WeightRounder.progressionStep(equipment, movement);
    final w    = WeightRounder.round(completedWeight, equipment);

    // Well above top of range — bump weight now
    if (completedReps >= targetRange.max + 2) {
      final next = WeightRounder.round(w + step, equipment);
      return NextSetHint(
        suggestedWeight: next,
        targetReps:      targetRange.min,
        advice:          '⬆️ ${next}kg × ${targetRange.min} reps',
        type:            SetHintType.increase,
      );
    }

    // At top of range — progress weight
    if (completedReps >= targetRange.max) {
      final next = WeightRounder.round(w + step, equipment);
      return NextSetHint(
        suggestedWeight: next,
        targetReps:      targetRange.min,
        advice:          'Progress → ${next}kg × ${targetRange.min} reps',
        type:            SetHintType.increase,
      );
    }

    // In target zone — hold weight, add one rep
    if (completedReps >= targetRange.min) {
      return NextSetHint(
        suggestedWeight: w,
        targetReps:      completedReps + 1,
        advice:          'Same weight — push ${completedReps + 1} reps',
        type:            SetHintType.maintain,
      );
    }

    // Well below range (struggling) — suggest dropping weight
    if (completedReps <= targetRange.min - 3) {
      final reduced = WeightRounder.round(w - step, equipment);
      final safe    = reduced > 0 ? reduced : w;
      return NextSetHint(
        suggestedWeight: safe,
        targetReps:      targetRange.max,
        advice:          '⬇️ Drop to ${safe}kg — ${targetRange.min}–${targetRange.max} reps',
        type:            SetHintType.decrease,
      );
    }

    // Slightly below — hold and retry target
    return NextSetHint(
      suggestedWeight: w,
      targetReps:      targetRange.max,
      advice:          'Same weight — ${targetRange.max} clean reps',
      type:            SetHintType.maintain,
    );
  }

  static RepRange _targetRange(String goal, bool isCompound) {
    switch (goal) {
      case 'strength':    return isCompound ? const RepRange(3, 5)   : const RepRange(6, 10);
      case 'muscle_gain': return isCompound ? const RepRange(6, 10)  : const RepRange(10, 15);
      case 'fat_loss':    return isCompound ? const RepRange(10, 15) : const RepRange(12, 20);
      default:            return const RepRange(8, 12);
    }
  }

  // Epley 1RM formula: w × (1 + reps/30)
  static double _epleyOneRM(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }
}

// ─── Result Types ─────────────────────────────────────────────────────────────
enum ProgressionType { increase, maintain, decrease }
enum SetHintType     { increase, maintain, decrease }

class ProgressionResult {
  final double          suggestedWeight;
  final int             targetReps;
  final String          message;
  final ProgressionType type;
  final bool            hasHistory;

  const ProgressionResult({
    required this.suggestedWeight,
    required this.targetReps,
    required this.message,
    required this.type,
    this.hasHistory = true,
  });

  factory ProgressionResult.noHistory() => const ProgressionResult(
    suggestedWeight: 0,
    targetReps:      0,
    message:         'First session — start light, focus on form',
    type:            ProgressionType.maintain,
    hasHistory:      false,
  );
}

class NextSetHint {
  final double      suggestedWeight;
  final int         targetReps;
  final String      advice;
  final SetHintType type;

  const NextSetHint({
    required this.suggestedWeight,
    required this.targetReps,
    required this.advice,
    required this.type,
  });
}
