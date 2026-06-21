// lib/models/momentum_state.dart
// Momentum score — quantifies training consistency and trajectory.
// Computed from streak, missed sessions, PRs, recovery, volume trend.
// Score 0–100. Not shown raw to user — drives AI tone + card state.

import 'coach_context.dart';
import 'athlete_memory.dart';

class MomentumState {
  final int  score;           // 0–100
  final bool atRisk;          // 2+ days inactive (not rest day) — never when worked out today
  final bool rising;          // trending up with recent PRs
  final bool lockedIn;        // score >= 75 + streak >= 5
  final bool isRestDay;       // today is a planned rest day
  final bool workedOutToday;  // session completed today

  const MomentumState({
    required this.score,
    required this.atRisk,
    required this.rising,
    required this.lockedIn,
    this.isRestDay = false,
    this.workedOutToday = false,
  });

  static const MomentumState neutral = MomentumState(
    score: 50, atRisk: false, rising: false, lockedIn: false, workedOutToday: false,
  );

  static MomentumState compute({
    required CoachContext ctx,
    required AthleteMemory memory,
  }) {
    double raw = 0;

    // ── Streak (0–25 pts) ─────────────────────────────────
    final s = ctx.currentStreak;
    raw += (s >= 14 ? 25.0 : s >= 7 ? 20.0 : s >= 3 ? 14.0 : s * 2.0)
        .clamp(0.0, 25.0);

    // ── Consistency score (0–25 pts) ──────────────────────
    raw += (memory.consistencyScore * 0.25).clamp(0.0, 25.0);

    // ── Recent PRs within 7 days (0–15 pts) ──────────────
    final recentPRCount = ctx.recentPRs
        .where((p) => DateTime.now().difference(p.date).inDays <= 7)
        .length;
    raw += (recentPRCount * 5.0).clamp(0.0, 15.0);

    // ── Average muscle recovery (0–15 pts) ────────────────
    if (ctx.muscleRecovery.isNotEmpty) {
      final avg = ctx.muscleRecovery.values.fold(0, (a, b) => a + b) /
          ctx.muscleRecovery.length;
      raw += (avg * 0.15).clamp(0.0, 15.0);
    }

    // ── Volume trend (0–10 pts) ───────────────────────────
    if (ctx.previousWeeklyVolume > 0) {
      final delta = ctx.weeklyVolume / ctx.previousWeeklyVolume;
      if (delta >= 1.05 && delta <= 1.25) raw += 10; // healthy growth
      else if (delta >= 0.85)             raw += 5;  // stable
    }

    // ── Penalties ─────────────────────────────────────────
    // Missed workouts in last 30 days
    raw -= (memory.missedWorkoutsLast30 * 2.0).clamp(0.0, 20.0);

    // Days inactive
    final inactivePenalty =
        ((ctx.daysSinceLastWorkout - 1) * 5.0).clamp(0.0, 15.0);
    raw -= inactivePenalty;

    final score = raw.round().clamp(0, 100);

    final workedOutToday = ctx.daysSinceLastWorkout == 0;

    // Planned rest day — don't penalise inactivity, it's intentional
    final inactiveRisk = ctx.isPlannedRestDay
        ? false
        : ctx.daysSinceLastWorkout >= 2;
    // AT RISK = only inactivity, never when the user already trained today
    final atRisk   = !workedOutToday && (score < 40 || inactiveRisk);
    final rising   = score >= 60 && recentPRCount > 0 && !atRisk;
    final lockedIn = score >= 75 && ctx.currentStreak >= 5;

    return MomentumState(
      score:          score,
      atRisk:         atRisk,
      rising:         rising,
      lockedIn:       lockedIn,
      isRestDay:      ctx.isPlannedRestDay,
      workedOutToday: workedOutToday,
    );
  }

  // ── Display helpers ───────────────────────────────────────
  String get statusLabel {
    if (isRestDay)              return 'REST DAY';
    if (lockedIn)               return 'LOCKED IN';
    if (rising)                 return 'RISING';
    if (workedOutToday)         return score >= 60 ? 'BUILDING' : 'ACTIVE';
    if (atRisk)                 return 'AT RISK';
    if (score >= 60)            return 'BUILDING';
    return 'RECOVERING';
  }

  String get narrativeLine {
    if (isRestDay) {
      return 'Rest is part of the plan. Muscles rebuild while you recover.';
    }
    if (lockedIn) {
      return 'Consistency is accelerating. Protect the rhythm.';
    }
    if (rising) {
      return 'Momentum is climbing faster than baseline.';
    }
    if (workedOutToday && score < 40) {
      return 'Session done. Show up again tomorrow — that\'s how momentum builds.';
    }
    if (workedOutToday) {
      return 'Good session. Consistency compounds — keep going.';
    }
    if (atRisk && score < 25) {
      return 'Getting back on track — one session changes everything.';
    }
    if (atRisk) {
      return 'A session today keeps the rhythm intact.';
    }
    if (score >= 60) {
      return 'Current consistency is your strongest adaptation.';
    }
    return 'Recovery and habit are building momentum.';
  }

  // Color signal for UI (as int for serialization-free passing)
  // 0 = neutral gold, 1 = cyan rising, 2 = amber risk, 3 = orange locked
  int get colorSignal {
    if (isRestDay)      return 0; // neutral gold — rest is intentional
    if (lockedIn)       return 3;
    if (rising)         return 1;
    if (workedOutToday) return 0; // gold — positive action taken today
    if (atRisk)         return 2;
    return 0;
  }
}
