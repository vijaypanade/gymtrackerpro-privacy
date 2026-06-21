// lib/services/progression_service.dart
// PR tracking and progression hint logic extracted from WorkoutProvider.
// All methods are static — pass the current logs list as first argument.

import '../models/models.dart';
import '../models/workout_log.dart';
import '../services/exercise_intelligence.dart';

// ═══════════════════════════════════════════════════════════════
// PR RESULT
// ═══════════════════════════════════════════════════════════════
enum PROutcome { pr, match, drop, first }

class PRResult {
  final PROutcome outcome;
  final double    newWeight;
  final int       newReps;
  final double    prevWeight;
  final int       prevReps;
  final double    improvePct;

  const PRResult({
    required this.outcome,
    required this.newWeight,
    required this.newReps,
    required this.prevWeight,
    required this.prevReps,
    required this.improvePct,
  });

  bool get isPR    => outcome == PROutcome.pr || outcome == PROutcome.first;
  bool get isMatch => outcome == PROutcome.match;
  bool get isDrop  => outcome == PROutcome.drop;
  bool get isFirst => outcome == PROutcome.first;

  String get uxMessage {
    switch (outcome) {
      case PROutcome.first: return '🎉 First rep logged! Every journey starts here.';
      case PROutcome.pr:    return '🔥 You\'re getting stronger!';
      case PROutcome.match: return '💪 Consistency builds strength. Keep pushing.';
      case PROutcome.drop:  return '📈 Recovery matters — come back stronger.';
    }
  }

  String get improvementStr {
    if (outcome == PROutcome.first) return '🎉 First ever!';
    if (improvePct == 0) return 'No change 🔁';
    if (improvePct > 0) return '+${improvePct.toStringAsFixed(1)}% 🔥';
    return '${improvePct.toStringAsFixed(1)}%';
  }
}

// ═══════════════════════════════════════════════════════════════
// SET PROGRESSION HINT
// ═══════════════════════════════════════════════════════════════
class SetProgressionHint {
  final String message;
  final double nextWeight;
  final int    targetReps;

  const SetProgressionHint({
    required this.message,
    required this.nextWeight,
    required this.targetReps,
  });
}

// ═══════════════════════════════════════════════════════════════
// PROGRESSION SERVICE
// ═══════════════════════════════════════════════════════════════
abstract final class ProgressionService {
  static List<WorkoutLog> _logsFor(List<WorkoutLog> logs, String key) =>
      logs.where((l) => l.exercise == key).toList();

  static double getPR(List<WorkoutLog> logs, String key, String unit) {
    final ex = logs
        .where((l) => l.exercise == key && l.weight >= 0 && l.weight <= 500)
        .toList();

    if (ex.isEmpty) return 0;

    WorkoutLog best = ex.first;

    for (final l in ex.skip(1)) {
      final current = unit == 'reps'
          ? l.reps.toDouble()
          : unit == 'min'
              ? l.minutes.toDouble()
              : l.weight;

      final bestVal = unit == 'reps'
          ? best.reps.toDouble()
          : unit == 'min'
              ? best.minutes.toDouble()
              : best.weight;

      if (current > bestVal) {
        best = l;
      } else if (unit == 'kg' &&
                 l.weight == best.weight &&
                 l.reps > best.reps) {
        best = l;
      }
    }

    return unit == 'reps'
        ? best.reps.toDouble()
        : unit == 'min'
            ? best.minutes.toDouble()
            : best.weight;
  }

  static int getPRReps(List<WorkoutLog> logs, String key) {
    final ex = _logsFor(logs, key);
    if (ex.isEmpty) return 0;
    WorkoutLog best = ex.first;

    for (final l in ex.skip(1)) {
      if (l.weight > best.weight) {
        best = l;
      } else if (l.weight == best.weight && l.reps > best.reps) {
        best = l;
      }
    }

    return best.reps;
  }

  static String? getPRDate(List<WorkoutLog> logs, String key, String unit) {
    final ex = _logsFor(logs, key);
    if (ex.isEmpty) return null;
    WorkoutLog best = ex.first;
    for (final l in ex.skip(1)) {
      final current = unit == 'reps'
          ? l.reps.toDouble()
          : unit == 'min' ? l.minutes.toDouble() : l.weight;
      final bestVal = unit == 'reps'
          ? best.reps.toDouble()
          : unit == 'min' ? best.minutes.toDouble() : best.weight;
      if (current > bestVal) best = l;
    }
    return '${best.date.day}/${best.date.month}/${best.date.year}';
  }

  static bool isNewPR(
    List<WorkoutLog> logs,
    String key,
    double weight,
    int reps,
    String unit, {
    int minutes = 0,
  }) {
    final ex = _logsFor(logs, key);
    if (ex.isEmpty) return true;
    final prevPR = getPR(logs, key, unit);
    final current = unit == 'reps'
        ? reps.toDouble()
        : unit == 'min' ? minutes.toDouble() : weight;
    return current > prevPR;
  }

  static PRResult checkPRResult(
    List<WorkoutLog> logs,
    String key,
    double weight,
    int reps,
    String unit,
  ) {
    final matching = _logsFor(logs, key);
    if (matching.isEmpty) {
      return PRResult(
        outcome: PROutcome.first,
        newWeight: weight, newReps: reps,
        prevWeight: 0, prevReps: 0, improvePct: 0,
      );
    }

    final prevValue = getPR(logs, key, unit);
    final prevReps  = getPRReps(logs, key);
    final currentValue = unit == 'reps' ? reps.toDouble() : weight;

    if (currentValue > prevValue ||
        (currentValue == prevValue && reps > prevReps)) {
      final pct = prevValue > 0
          ? ((currentValue - prevValue) / prevValue * 100)
          : 5.0;
      return PRResult(
        outcome: PROutcome.pr,
        newWeight: weight, newReps: reps,
        prevWeight: prevValue, prevReps: prevReps,
        improvePct: pct.clamp(0, 999),
      );
    }

    if ((currentValue - prevValue).abs() < 0.01 && reps == prevReps) {
      return PRResult(
        outcome: PROutcome.match,
        newWeight: weight, newReps: reps,
        prevWeight: prevValue, prevReps: prevReps,
        improvePct: 0,
      );
    }

    final dropPct = prevValue > 0
        ? ((prevValue - currentValue) / prevValue * 100)
        : 0.0;
    return PRResult(
      outcome: PROutcome.drop,
      newWeight: weight, newReps: reps,
      prevWeight: prevValue, prevReps: prevReps,
      improvePct: -dropPct.clamp(0.0, 100.0),
    );
  }

  static String? nearMissMessage(
    List<WorkoutLog> logs,
    String exerciseKey,
    String unit,
  ) {
    final pr = getPR(logs, exerciseKey, unit);
    if (pr <= 0) return null;
    final ex = _logsFor(logs, exerciseKey);
    if (ex.length < 2) return null;
    ex.sort((a, b) => b.date.compareTo(a.date));
    final latest = ex.first;
    final latestVal = unit == 'reps'
        ? latest.reps.toDouble()
        : unit == 'min' ? latest.minutes.toDouble() : latest.weight;
    final gap = pr - latestVal;
    if (gap <= 0) return null;
    final gapPct = gap / pr;
    if (gapPct <= 0.05) {
      return unit == 'reps'
          ? '🎯 Just ${gap.toInt()} reps away from your PR!'
          : '🎯 Only ${gap.toStringAsFixed(1)} ${unit == 'min' ? 'min' : 'kg'} away!';
    }
    if (gapPct <= 0.10) {
      return '📈 Within 10% of your PR. Push next time!';
    }
    return null;
  }

  static String? predictNextPR(
    List<WorkoutLog> logs,
    String exerciseKey,
    String unit,
  ) {
    final ex = _logsFor(logs, exerciseKey);

    if (ex.length < 3 || unit != 'kg') return null;

    ex.sort((a, b) => b.date.compareTo(a.date));

    final recent = ex.take(3).toList();

    double avgWeight = 0;
    double avgReps   = 0;

    for (final l in recent) {
      avgWeight += l.weight;
      avgReps   += l.reps;
    }

    avgWeight /= recent.length;
    avgReps   /= recent.length;

    final currentPR = getPR(logs, exerciseKey, unit);

    if (currentPR <= 0) return null;

    final projected =
        (currentPR * 1.025).clamp(currentPR + 1, currentPR + 5);

    final projectedRounded = (projected / 2.5).round() * 2.5;

    return '📈 Predicted next PR: ${projectedRounded.toStringAsFixed(1)}kg × ${avgReps.round()} likely within 7 days';
  }

  static SetProgressionHint analyzeProgression(
    PlannedExercise ex, {
    String goal      = 'muscle_gain',
    String equipment = 'dumbbell',
    String movement  = 'isolation',
  }) {
    final validSets = ex.sets.where((s) => s.reps > 0).toList();

    if (validSets.isEmpty) {
      return SetProgressionHint(
        message:    'Start your first set 💪',
        nextWeight: ex.bodyweight ? 0 : WeightRounder.round(20.0, equipment),
        targetReps: 10,
      );
    }

    final last = validSets.last;

    if (ex.bodyweight) {
      if (last.reps >= 15) {
        return SetProgressionHint(
          message:    '🔥 Increase reps or add difficulty!',
          nextWeight: 0,
          targetReps: (last.reps + 2).clamp(1, 50),
        );
      }
      return SetProgressionHint(
        message:    '💪 Keep pushing reps',
        nextWeight: 0,
        targetReps: (last.reps + 1).clamp(1, 50),
      );
    }

    final targetRange = VolumeAllocator.repRange(
      position: 0,
      movement: movement,
      goal:     goal,
    );
    final hint = ProgressionEngine.nextSet(
      completedWeight: last.weight,
      completedReps:   last.reps,
      targetRange:     targetRange,
      equipment:       equipment,
      movement:        movement,
    );

    return SetProgressionHint(
      message:    hint.advice,
      nextWeight: hint.suggestedWeight.clamp(0.0, 500.0),
      targetReps: hint.targetReps.clamp(1, 50),
    );
  }
}
