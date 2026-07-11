// lib/services/coach_message_service.dart
// Reactive, data-driven coach messages. Runs 100% offline, zero latency.
// Phase 3: Tone-aware, memory-personalized, with topic cooldown for variety.
//
// Priority: PR → volume spike → skipped muscle → streak risk → deload
//           → recovery alert → adaptive behavioral → (empty = fall to Gemini)
//
// Message rules:
//   • Max 2 sentences
//   • No motivational fluff ("Great job!", "Keep going!")
//   • Specific numbers — weight, days, %, streak
//   • Tactical: tells the user WHAT TO DO, not how to feel
//   • Tone calibrated to athlete type

import '../models/coach_context.dart';
import '../models/athlete_memory.dart';

// ── Surface context — governs message framing layer ───────────────────────────
// PRE_WORKOUT: tactical guidance, warnings allowed.
// POST_WORKOUT: reflective summary, recovery framing, NO warning tone.
// RECOVERY:     calm, rest-focused language.
// COMEBACK:     supportive restart framing, zero pressure.
enum CoachSurfaceContext {
  preWorkout,
  inWorkout,
  postWorkout,
  recovery,
  comeback,
}

// Return type — caller records the topic to drive cooldown
typedef CoachMessage = ({String message, String topic});

class CoachMessageService {
  CoachMessageService._();

  // ── Topic key constants ───────────────────────────────────
  static const String topicPR            = 'pr';
  static const String topicVolumeSpike   = 'volume_spike';
  static const String topicSkippedMuscle = 'skipped_muscle';
  static const String topicStreakRisk    = 'streak_risk';
  static const String topicDeload        = 'deload';
  static const String topicRecovery      = 'recovery_alert';
  static const String topicBehavioral    = 'behavioral';
  static const String topicNearMiss      = 'near_miss';
  static const String topicMomentum      = 'momentum';

  // ── Main entry — returns (message, topic) or empty ───────
  static CoachMessage buildWithTopic(
    CoachContext ctx, {
    AthleteMemory?      memory,
    CoachTone           tone          = CoachTone.scientific,
    Set<String>         cooldown      = const {},
    CoachSurfaceContext surfaceContext = CoachSurfaceContext.preWorkout,
  }) {
    final v = _rotation; // 0–2, changes daily for variant selection

    // ── Post-workout: reflective framing only, no warnings ──────────────
    if (surfaceContext == CoachSurfaceContext.postWorkout) {
      return _postWorkoutMessage(ctx, memory: memory, tone: tone, v: v);
    }

    // ── 1. Personal Record ────────────────────────────────
    if (!cooldown.contains(topicPR)) {
      final pr = ctx.latestPR;
      if (pr != null && DateTime.now().difference(pr.date).inHours < 24) {
        return (message: _prMessage(pr, tone, memory, v), topic: topicPR);
      }
    }

    // ── 2. Volume spike ───────────────────────────────────
    if (!cooldown.contains(topicVolumeSpike) &&
        ctx.hasVolumeSpike && ctx.weeklyVolume > 500) {
      final pct = ((ctx.weeklyVolume / ctx.previousWeeklyVolume - 1) * 100).round();
      return (message: _volumeSpikeMessage(pct, tone, memory, v), topic: topicVolumeSpike);
    }

    // ── 3. Skipped muscle ─────────────────────────────────
    if (!cooldown.contains(topicSkippedMuscle) &&
        ctx.skippedMuscles.isNotEmpty && ctx.totalWorkouts >= 5) {
      final muscle = ctx.skippedMuscles.first;
      final days   = ctx.muscleLastDays[muscle.toLowerCase()];
      if (days == null || days >= 7) {
        return (
          message: _skippedMessage(muscle, days, tone, memory, v),
          topic: topicSkippedMuscle,
        );
      }
    }

    // ── 4. Streak risk ────────────────────────────────────
    if (!cooldown.contains(topicStreakRisk) &&
        ctx.currentStreak >= 3 && ctx.daysSinceLastWorkout == 1) {
      return (message: _streakRiskMessage(ctx.currentStreak, tone, memory, v), topic: topicStreakRisk);
    }

    // ── 5. Deload ─────────────────────────────────────────
    if (!cooldown.contains(topicDeload) && ctx.isDeloadWeek) {
      return (message: _deloadMessage(tone, memory, v), topic: topicDeload);
    }

    // ── 6. Recovery alert ─────────────────────────────────
    if (!cooldown.contains(topicRecovery)) {
      final fatigued = ctx.mostFatiguedMuscle;
      if (fatigued != null && fatigued.value < 40) {
        final ready = ctx.mostReadyMuscle;
        return (
          message: _recoveryMessage(fatigued, ready, tone, memory, v),
          topic: topicRecovery,
        );
      }
    }

    // ── 7. Near-miss recovery (broke streak recently) ────────
    if (!cooldown.contains(topicNearMiss) &&
        ctx.daysSinceLastWorkout >= 2 &&
        ctx.currentStreak == 0 &&
        memory != null && memory.consistencyScore >= 45) {
      return (message: _nearMissMessage(ctx, memory, tone, v), topic: topicNearMiss);
    }

    // ── 8. Momentum identity reinforcement ───────────────────
    if (!cooldown.contains(topicMomentum) && memory != null &&
        memory.longestConsistencyPhase >= 7 &&
        ctx.currentStreak >= 5) {
      return (message: _momentumMessage(ctx, memory, v), topic: topicMomentum);
    }

    // ── 9. Adaptive behavioral ────────────────────────────
    if (!cooldown.contains(topicBehavioral) && memory != null) {
      final msg = _behavioralMessage(ctx, memory, tone, v);
      if (msg.isNotEmpty) {
        return (message: msg, topic: topicBehavioral);
      }
    }

    return (message: '', topic: '');
  }

  /// Convenience wrapper that ignores the topic (for callers that don't need it).
  static String buildReactiveMessage(
    CoachContext ctx, {
    AthleteMemory?      memory,
    CoachTone           tone          = CoachTone.scientific,
    Set<String>         cooldown      = const {},
    CoachSurfaceContext surfaceContext = CoachSurfaceContext.preWorkout,
  }) =>
      buildWithTopic(ctx,
        memory:        memory,
        tone:          tone,
        cooldown:      cooldown,
        surfaceContext: surfaceContext,
      ).message;

  // ── Day-based rotation 0–2 ───────────────────────────────
  static int get _rotation =>
      DateTime.now().difference(DateTime(2024)).inDays % 3;

  // ═════════════════════════════════════════════════════════
  // MESSAGE BUILDERS — each returns a 1–2 sentence string
  // ═════════════════════════════════════════════════════════

  static String _prMessage(
    PREvent pr, CoachTone tone, AthleteMemory? memory, int v,
  ) {
    final name = _fmtExercise(pr.exercise);
    final isFavorite = memory != null &&
        memory.favoriteLift.isNotEmpty &&
        pr.exercise.toLowerCase().contains(memory.favoriteLift.replaceAll(' ', '_'));

    if (pr.isRepPR) {
      final next = pr.reps + 2;
      switch (v) {
        case 0: return '$name rep PR — ${pr.display}. Target $next reps before adding load.';
        case 1: return '$name rep PR. ${pr.display} is now your baseline — extend it by 2 reps next session.';
        default:
          return isFavorite
              ? 'Rep PR on your favorite lift: $name — ${pr.display}. Reps before weight.'
              : '$name rep PR — ${pr.display}. Hold this weight for $next reps, then progress.';
      }
    }

    switch (tone) {
      case CoachTone.aggressive:
        return '$name PR — ${pr.display}. Consolidate for one session, then push it again.';
      case CoachTone.elite:
        return '$name PR — ${pr.display}. Build volume at this load before chasing higher singles.';
      case CoachTone.scientific:
        final tip = v == 0
            ? 'A few sets at this load before moving up.'
            : 'Stay at this weight a little longer.';
        return '$name PR — ${pr.display}. $tip';
      case CoachTone.supportive:
        return '$name PR — ${pr.display}. Good lift. Build on it.';
      case CoachTone.disciplined:
        return isFavorite
            ? 'PR on $name — ${pr.display}. Consistent showing up made this happen.'
            : '$name PR — ${pr.display}. Reward of consistent training.';
    }
  }

  static String _volumeSpikeMessage(
    int pct, CoachTone tone, AthleteMemory? memory, int v,
  ) {
    final fatigueNote = memory?.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days
        ? 'You tend to fade after big weeks.'
        : 'Recovery matters more than motivation now.';

    switch (tone) {
      case CoachTone.aggressive:
        return 'Volume up $pct%. Protect sleep and protein.';
      case CoachTone.elite:
        return 'Volume up $pct%. $fatigueNote';
      case CoachTone.scientific:
        return 'Volume up $pct%. Ease off a little today.';
      case CoachTone.supportive:
        return 'Volume up $pct%. Match it with extra recovery.';
      case CoachTone.disciplined:
        return v == 0
            ? 'Volume up $pct%. More isn\'t always better.'
            : 'Volume up $pct%. Quality over quantity from here.';
    }
  }

  static String _skippedMessage(
    String muscle, int? days, CoachTone tone, AthleteMemory? memory, int v,
  ) {
    final daysStr = days != null ? '$days days' : 'too long';
    final hint    = _exerciseHint(muscle);

    // If this is the user's weakest muscle, acknowledge the pattern
    final isKnownWeak = memory != null &&
        memory.weakestMuscle.toLowerCase() == muscle.toLowerCase();

    if (isKnownWeak) {
      return '${_cap(muscle)} hasn\'t been trained in $daysStr. Hit it early today.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return '${_cap(muscle)} untrained $daysStr. Hit $hint today.';
      case CoachTone.elite:
        return '${_cap(muscle)} skipped $daysStr. Start with $hint today.';
      case CoachTone.scientific:
        return '${_cap(muscle)} hasn\'t been trained in $daysStr. Twice a week keeps it growing.';
      case CoachTone.supportive:
        return '${_cap(muscle)} hasn\'t been trained in $daysStr. $hint keeps things balanced.';
      case CoachTone.disciplined:
        return v == 0
            ? '${_cap(muscle)} untrained $daysStr. It won\'t improve without work.'
            : '${_cap(muscle)} skipped $daysStr. Add $hint today.';
    }
  }

  static String _streakRiskMessage(
    int streak, CoachTone tone, AthleteMemory? memory, int v,
  ) {
    final isStreakDriven = memory?.motivationalTriggers.contains(AthleteMemory.triggerStreaks) ?? false;

    if (isStreakDriven) {
      return '$streak-day streak at risk. Twenty minutes keeps it alive.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return '$streak-day streak. Don\'t let one off-day erase it.';
      case CoachTone.elite:
        return '$streak-day streak at risk. A short session keeps it alive.';
      case CoachTone.scientific:
        return '$streak-day streak at risk. Short sessions count.';
      case CoachTone.supportive:
        return '$streak-day streak. A short workout keeps it intact.';
      case CoachTone.disciplined:
        return v == 0
            ? '$streak days at risk. Do something today.'
            : '$streak-day streak. Even 15 minutes matters.';
    }
  }

  static String _deloadMessage(CoachTone tone, AthleteMemory? memory, int v) {
    final fatigues = memory?.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days;
    if (fatigues) {
      return 'Volume dropped this week. Your body needs it. Take one more easy day.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return v == 0
            ? 'Deload week. Come back sharper next week.'
            : 'Four hard weeks done. Deload, then push again.';
      case CoachTone.elite:
        return 'Deload week. Drop the volume, keep the habit.';
      case CoachTone.scientific:
        return 'Deload week. Lighter loads now, stronger next week.';
      case CoachTone.supportive:
        return 'Your body earned a lighter week. It\'s part of the process.';
      case CoachTone.disciplined:
        return 'Deload week. Lower the volume, keep showing up.';
    }
  }

  static String _recoveryMessage(
    MapEntry<String, int> fatigued,
    MapEntry<String, int>? ready,
    CoachTone tone,
    AthleteMemory? memory,
    int v,
  ) {
    final muscle   = _cap(fatigued.key);
    final score    = fatigued.value;
    final altMuscle = ready != null && ready.key != fatigued.key
        ? _cap(ready.key)
        : null;
    final alt = altMuscle != null ? 'Train ${altMuscle.toLowerCase()} instead.' : 'Take it easy today.';

    final readiness = score >= 65 ? 'nearly ready'
        : score >= 45 ? 'still recovering'
        : 'worn out';
    switch (tone) {
      case CoachTone.aggressive:
        return '$muscle is $readiness. $alt';
      case CoachTone.elite:
        return '$muscle needs more time. $alt';
      case CoachTone.scientific:
        return '$muscle isn\'t ready for heavy work. $alt';
      case CoachTone.supportive:
        return '$muscle needs more time. $alt';
      case CoachTone.disciplined:
        return v == 0
            ? '$muscle is $readiness. Train what\'s ready.'
            : '$muscle is $readiness. $alt';
    }
  }

  static String _behavioralMessage(
    CoachContext ctx, AthleteMemory memory, CoachTone tone, int v,
  ) {
    // Pattern: user misses workouts repeatedly
    if (memory.missedWorkoutsLast30 >= 4 && ctx.daysSinceLastWorkout >= 2) {
      return 'A short workout today beats a perfect one tomorrow.';
    }

    // Pattern: user responds well to PRs
    if (memory.motivationalTriggers.contains(AthleteMemory.triggerPR) &&
        memory.favoriteLift.isNotEmpty) {
      final lift = _fmtExercise(memory.favoriteLift);
      return '${_cap(lift.isNotEmpty ? lift : "compounds")} keeps you consistent. Lean into it this week.';
    }

    // Pattern: user trains aggressively when motivated
    if (memory.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days &&
        ctx.weeklyVolume > memory.avgWeeklyVolume * 1.2) {
      return 'Big volume lately. Pull back a little today.';
    }

    // Pattern: beginner phase
    if (ctx.totalWorkouts < 20) {
      return 'Consistency beats intensity right now. Just keep showing up.';
    }

    // Pattern: high volume tolerance — acknowledge it
    if (memory.fatiguePattern == AthleteMemory.patternHighVolumeTolerant &&
        ctx.currentStreak >= 7) {
      return v == 0
          ? 'Frequent training suits you. Keep the frequency, vary the effort.'
          : 'Back-to-back sessions suit you. Watch sleep and appetite.';
    }

    return '';
  }

  static String _nearMissMessage(
    CoachContext ctx, AthleteMemory memory, CoachTone tone, int v,
  ) {
    final daysMissed = ctx.daysSinceLastWorkout;

    if (daysMissed >= 5) {
      return 'Been a few days. Start with a short session today.';
    }
    if (memory.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days) {
      return 'You\'re rested now. Ease back in — no need to rush.';
    }
    switch (v) {
      case 0:
        return 'Two days off. One session today keeps the rhythm.';
      case 1:
        return 'Don\'t let the gap widen. A short session today is enough.';
      default:
        return 'You\'re rested. Ease back in today.';
    }
  }

  static String _momentumMessage(
    CoachContext ctx, AthleteMemory memory, int v,
  ) {
    final streak = ctx.currentStreak;
    final longest = memory.longestConsistencyPhase;

    if (streak >= longest && longest >= 10) {
      return 'Your longest run yet. Protect it.';
    }
    if (memory.bestMomentumScore > 70 && streak >= 7) {
      return switch (v) {
        0 => '$streak days straight. This is where it counts.',
        1 => '$streak days in a row. The work is compounding.',
        _ => '$streak days of showing up. Keep the rhythm.',
      };
    }
    return 'You\'re settling into a rhythm. Keep it going.';
  }

  // ── Post-workout reflective messages ─────────────────────
  // Tone rules:
  //   • Reflective — the workout happened; frame what comes next.
  //   • No warning language ("only 5% recovery", "reduce load").
  //   • No streak pressure.
  //   • Frame recovery as active, positive, physiologically grounded.
  static CoachMessage _postWorkoutMessage(
    CoachContext ctx, {
    AthleteMemory? memory,
    CoachTone tone = CoachTone.scientific,
    int v = 0,
  }) {
    const topic = 'post_workout';

    // ── PR just hit — acknowledge specifically ────────────────────────────
    final pr = ctx.latestPR;
    if (pr != null && DateTime.now().difference(pr.date).inHours < 2) {
      final name = _fmtExercise(pr.exercise);
      return (
        message: '$name PR locked in. Nothing more to prove today.',
        topic: topic,
      );
    }

    // ── Fatigued muscle was trained — reflective framing ─────────────────
    final fatigued = ctx.mostFatiguedMuscle;
    if (fatigued != null && fatigued.value < 45) {
      final muscle = _cap(fatigued.key);
      return (
        message: '$muscle worked hard today. Give it a day or two.',
        topic: topic,
      );
    }

    // ── Volume notable this week ──────────────────────────────────────────
    if (ctx.hasVolumeSpike) {
      return (
        message: 'Big week so far. Recovery is the work now.',
        topic: topic,
      );
    }

    // ── Deload week complete ──────────────────────────────────────────────
    if (ctx.isDeloadWeek) {
      return (
        message: 'Deload session done. You\'ll feel it pay off soon.',
        topic: topic,
      );
    }

    // ── Tone-calibrated default ───────────────────────────────────────────
    switch (tone) {
      case CoachTone.aggressive:
        return (
          message: 'Session logged. Tomorrow builds on it.',
          topic: topic,
        );
      case CoachTone.elite:
        return (
          message: v == 0
              ? 'Good session. Nothing more needed today.'
              : 'Session done. The next 24 hours matter.',
          topic: topic,
        );
      case CoachTone.scientific:
        return (
          message: v == 0
              ? 'Session logged. The work is done.'
              : 'Good work. The rest happens on its own.',
          topic: topic,
        );
      case CoachTone.supportive:
        return (
          message: v == 0
              ? 'Good session. The work compounds.'
              : 'One more session done. It adds up.',
          topic: topic,
        );
      case CoachTone.disciplined:
        return (
          message: 'Session done. Recovery is part of the discipline.',
          topic: topic,
        );
    }
  }

  // ── Helpers ──────────────────────────────────────────────

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

  static String _fmtExercise(String key) =>
      key.replaceAll('_', ' ').trim();

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
