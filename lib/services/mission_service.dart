// lib/services/mission_service.dart
// Adaptive daily mission generation. Zero fluff — tactical and specific.
// Priority: fatigue → near-miss → beginner → skipped muscle →
//           high momentum → volume spike → consistency → default

import '../models/coach_context.dart';
import '../models/athlete_memory.dart';
import '../models/daily_mission.dart';
import '../models/momentum_state.dart';
import '../models/athlete_identity.dart';

class MissionService {
  MissionService._();

  static CoachMission build({
    required CoachContext      ctx,
    required AthleteMemory     memory,
    required MomentumState     momentum,
    required AthleteIdentityStage identity,
  }) {
    // ── Severe fatigue → protect recovery ─────────────────
    final fatigued = ctx.mostFatiguedMuscle;
    if (fatigued != null && fatigued.value < 35) {
      final muscle = _cap(fatigued.key);
      final ready  = ctx.mostReadyMuscle;
      final alt = ready != null && ready.key != fatigued.key
          ? 'Focus on ${_cap(ready.key).toLowerCase()} instead.'
          : 'Keep the session under 45 minutes.';
      return CoachMission(
        title:       'Protect recovery.',
        description: '$muscle is at ${fatigued.value}% — avoid loading it. $alt',
        type:        CoachMissionType.recovery,
        muscleTarget: ready?.key ?? '',
      );
    }

    // ── Momentum at risk → minimum viable session ─────────
    if (momentum.atRisk && ctx.daysSinceLastWorkout >= 2 &&
        memory.missedWorkoutsLast30 >= 3) {
      return const CoachMission(
        title:       'Short session. Preserve the habit.',
        description: 'Any session beats none. 20 minutes rebuilds rhythm faster than a full reset.',
        type:        CoachMissionType.habit,
        targetSets:  6,
      );
    }

    // ── Near-miss: streak broken recently ─────────────────
    if (ctx.daysSinceLastWorkout >= 2 && ctx.currentStreak == 0 &&
        memory.consistencyScore >= 50) {
      return const CoachMission(
        title:       'Rebuild rhythm.',
        description: 'Momentum dipped — one session resets the pattern. Start light, finish complete.',
        type:        CoachMissionType.habit,
        targetSets:  8,
      );
    }

    // ── Beginner phase → 3 quality sets ───────────────────
    if (identity.isEarlyPhase) {
      return CoachMission(
        title:       'Complete 3 quality sets.',
        description: 'Focus on form over load. Nervous system adaptation is the goal right now.',
        type:        CoachMissionType.consistency,
        targetSets:  3,
      );
    }

    // ── Skipped muscle ─────────────────────────────────────
    if (ctx.skippedMuscles.isNotEmpty) {
      final muscle = ctx.skippedMuscles.first;
      final days   = ctx.muscleLastDays[muscle.toLowerCase()] ?? 14;
      final hint   = _exerciseHint(muscle);
      return CoachMission(
        title:       'Reintroduce ${_cap(muscle).toLowerCase()} volume.',
        description: '${_cap(muscle)} untrained $days days. Add $hint early — before fatigue accumulates.',
        type:        CoachMissionType.strength,
        muscleTarget: muscle,
      );
    }

    // ── High momentum + all muscles ready → push session ──
    if (momentum.lockedIn && ctx.muscleRecovery.isNotEmpty &&
        ctx.muscleRecovery.values.every((v) => v >= 70)) {
      final favLift = memory.favoriteLift.isNotEmpty
          ? _fmtExercise(memory.favoriteLift)
          : 'compound lifts';
      return CoachMission(
        title:       'Maintain rhythm — don\'t chase failure.',
        description: 'Full recovery across all muscles. Push $favLift but stop at technical failure, not absolute.',
        type:        CoachMissionType.strength,
        muscleTarget: memory.strongestMuscle,
      );
    }

    // ── Volume spike → control intensity ──────────────────
    if (ctx.hasVolumeSpike) {
      return const CoachMission(
        title:       'Quality over quantity today.',
        description: 'Volume elevated this week. Reduce intensity 15–20% — protect output for next session.',
        type:        CoachMissionType.volume,
      );
    }

    // ── Deload week ────────────────────────────────────────
    if (ctx.isDeloadWeek) {
      return const CoachMission(
        title:       'Deload: 40% volume, full intensity.',
        description: 'Supercompensation peaks in 5–7 days. Maintain movement patterns, drop sets.',
        type:        CoachMissionType.recovery,
      );
    }

    // ── Streak at risk but still active ───────────────────
    if (ctx.currentStreak >= 3 && ctx.daysSinceLastWorkout == 1) {
      return CoachMission(
        title:       '${ctx.currentStreak}-day streak. Protect it.',
        description: 'Consistency is compounding. Even a reduced session keeps adaptation momentum.',
        type:        CoachMissionType.habit,
        targetSets:  memory.consistencyScore < 60 ? 6 : 0,
      );
    }

    // ── Consistency default ────────────────────────────────
    final sets = _defaultSets(identity);
    return CoachMission(
      title:       'Complete today\'s session.',
      description: 'Execute $sets working sets with full range of motion. '
          '${identity.isAdvanced ? "Quality of execution matters more than load." : ""}',
      type:         CoachMissionType.consistency,
      targetSets:   sets,
    );
  }

  static int _defaultSets(AthleteIdentityStage id) {
    switch (id) {
      case AthleteIdentityStage.beginner:    return 9;
      case AthleteIdentityStage.developing:  return 12;
      case AthleteIdentityStage.consistent:  return 15;
      case AthleteIdentityStage.disciplined: return 18;
      case AthleteIdentityStage.elite:       return 20;
    }
  }

  static String _exerciseHint(String muscle) {
    const hints = <String, String>{
      'chest':     'barbell bench or dumbbell fly',
      'back':      'rows or pull-ups',
      'legs':      'squats or Romanian deadlifts',
      'shoulders': 'overhead press or lateral raises',
      'biceps':    'barbell curls or hammer curls',
      'triceps':   'dips or pushdowns',
      'core':      'planks or cable crunches',
      'calves':    'standing calf raises',
    };
    return hints[muscle.toLowerCase()] ?? muscle.toLowerCase();
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _fmtExercise(String key) =>
      key.replaceAll('_', ' ').trim();
}
