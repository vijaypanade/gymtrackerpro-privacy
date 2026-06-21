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
            ? 'Two to three sets at this load before progressing.'
            : 'Consolidate before advancing — strength requires exposure, not just peaks.';
        return '$name PR — ${pr.display}. $tip';
      case CoachTone.supportive:
        return '$name PR — ${pr.display}. That\'s a measurable improvement. Build on it next session.';
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
        ? 'Your pattern shows fatigue after high-volume clusters.'
        : 'Recovery becomes the bottleneck now, not motivation.';

    switch (tone) {
      case CoachTone.aggressive:
        return 'Volume up $pct% this week. $fatigueNote Protect sleep and protein intake.';
      case CoachTone.elite:
        return 'Weekly volume jumped $pct%. $fatigueNote';
      case CoachTone.scientific:
        return 'Volume increase of $pct% detected. ACWR elevation suggests recovery priority — reduce intensity by 15–20% today.';
      case CoachTone.supportive:
        return 'Training volume jumped $pct% this week. Good progress — match it with extra recovery today.';
      case CoachTone.disciplined:
        return v == 0
            ? 'Volume spiked $pct%. More isn\'t always better — manage it.'
            : 'Volume up $pct% — quality over quantity from here.';
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
      return '${_cap(muscle)} is your least-trained group and hasn\'t been hit in $daysStr. '
          'Address it early in today\'s session before fatigue sets in.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return '${_cap(muscle)} untrained $daysStr. Hit $hint today — no excuses.';
      case CoachTone.elite:
        return '${_cap(muscle)} neglected $daysStr. Imbalance limits total output — prioritise $hint.';
      case CoachTone.scientific:
        return '${_cap(muscle)} hasn\'t been trained in $daysStr. Schoenfeld recommends 2×/week minimum — fit it in today.';
      case CoachTone.supportive:
        return '${_cap(muscle)} hasn\'t been trained in $daysStr. Adding $hint today keeps your plan balanced.';
      case CoachTone.disciplined:
        return v == 0
            ? '${_cap(muscle)} untrained $daysStr. It doesn\'t improve without work.'
            : '${_cap(muscle)} skipped $daysStr. Add $hint before it compounds further.';
    }
  }

  static String _streakRiskMessage(
    int streak, CoachTone tone, AthleteMemory? memory, int v,
  ) {
    final isStreakDriven = memory?.motivationalTriggers.contains(AthleteMemory.triggerStreaks) ?? false;

    if (isStreakDriven) {
      return '$streak-day streak at risk — your data shows consistency is what drives your progress. Even 20 minutes keeps it alive.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return '$streak-day streak. Don\'t let one off-day erase it.';
      case CoachTone.elite:
        return '$streak-day streak at risk. Even a short session protects the adaptation momentum.';
      case CoachTone.scientific:
        return '$streak-day streak at risk. Neural adaptations accumulate with frequency — short sessions count.';
      case CoachTone.supportive:
        return '$streak-day streak — you\'re building a real habit. A short workout today keeps it intact.';
      case CoachTone.disciplined:
        return v == 0
            ? '$streak days of consistency at risk. Do something — anything.'
            : '$streak-day streak. Protect it. Even 15 minutes matters.';
    }
  }

  static String _deloadMessage(CoachTone tone, AthleteMemory? memory, int v) {
    final fatigues = memory?.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days;
    if (fatigues) {
      return 'Volume dropped this week — your pattern shows you need this. '
          'Nervous system recovery is catching up. Extend the deload by one more day.';
    }

    switch (tone) {
      case CoachTone.aggressive:
        return v == 0
            ? 'Deload week. Drop to 40% volume — come back sharper next week.'
            : 'Four-week mesocycle complete. Deload, then push harder.';
      case CoachTone.elite:
        return 'Mesocycle complete — deload this week (40% volume) for full neural recovery before the next progression block.';
      case CoachTone.scientific:
        return 'Zourdos protocol: week four is deload week. Reduce volume 40%, maintain intensity. Supercompensation peaks in 5–7 days.';
      case CoachTone.supportive:
        return 'Your body is ready for a recovery week. Drop the volume — it\'s part of the process, not a step back.';
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
    final alt = altMuscle != null ? 'Target ${altMuscle.toLowerCase()} instead.' : 'Use today as active recovery.';

    final readiness = score >= 65 ? 'still elevated'
        : score >= 45 ? 'suppressed'
        : 'depleted';
    switch (tone) {
      case CoachTone.aggressive:
        return '$muscle is $readiness — loading it limits adaptation. $alt';
      case CoachTone.elite:
        return '$muscle recovery not complete — loading it now trades adaptation for injury risk. $alt';
      case CoachTone.scientific:
        return '$muscle repair is incomplete — below the threshold for safe heavy loading. $alt';
      case CoachTone.supportive:
        return '$muscle needs more time. $alt Training smart means knowing when to pull back.';
      case CoachTone.disciplined:
        return v == 0
            ? '$muscle is $readiness. Train what\'s ready — not what feels good.'
            : '$muscle is $readiness. $alt';
    }
  }

  static String _behavioralMessage(
    CoachContext ctx, AthleteMemory memory, CoachTone tone, int v,
  ) {
    // Pattern: user misses workouts repeatedly
    if (memory.missedWorkoutsLast30 >= 4 && ctx.daysSinceLastWorkout >= 2) {
      final pattern = memory.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days
          ? 'You tend to lose momentum after high-volume clusters. '
          : '';
      return '${pattern}Short workout today beats the perfect workout tomorrow. '
          'Your consistency score is ${memory.consistencyScore}% — bring it up.';
    }

    // Pattern: user responds well to PRs
    if (memory.motivationalTriggers.contains(AthleteMemory.triggerPR) &&
        memory.favoriteLift.isNotEmpty) {
      final lift = _fmtExercise(memory.favoriteLift);
      return 'Your ${lift.isNotEmpty ? lift : "compound"} numbers are driving your consistency. '
          'Lean into heavy compounds this week to keep momentum.';
    }

    // Pattern: user trains aggressively when motivated
    if (memory.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days &&
        ctx.weeklyVolume > memory.avgWeeklyVolume * 1.2) {
      return 'You push volume hard when motivated — recovery is now the growth limiter. '
          'Throttle back 10–15% today to protect next week\'s output.';
    }

    // Pattern: beginner phase
    if (ctx.totalWorkouts < 20) {
      return 'Consistency matters more than intensity right now. '
          'Your nervous system is still adapting — show up, not just when motivated.';
    }

    // Pattern: high volume tolerance — acknowledge it
    if (memory.fatiguePattern == AthleteMemory.patternHighVolumeTolerant &&
        ctx.currentStreak >= 7) {
      return v == 0
          ? 'You respond well to moderate-to-high volume and frequent exposure. Keep the frequency — vary the intensity.'
          : 'Your training pattern shows high tolerance for consecutive sessions. '
              'Use that — but monitor sleep and appetite as early fatigue signals.';
    }

    return '';
  }

  static String _nearMissMessage(
    CoachContext ctx, AthleteMemory memory, CoachTone tone, int v,
  ) {
    final daysMissed = ctx.daysSinceLastWorkout;
    final consistency = memory.consistencyScore;

    if (daysMissed >= 5) {
      return 'Momentum dipped — rebuild rhythm quickly before inactivity normalizes. '
          'Start with a short session today. No load targets.';
    }
    if (memory.fatiguePattern == AthleteMemory.patternFatiguesAfter3Days) {
      return 'Your pattern: high output, then a gap. Recovery window reset. '
          'Rebuild gradually — don\'t rush back to peak volume.';
    }
    switch (v) {
      case 0:
        return 'Two missed days is the inflection point. '
            'One session today prevents the rhythm from resetting.';
      case 1:
        return 'Consistency at $consistency% — don\'t let the gap widen. '
            'Short session now costs less than a full reset later.';
      default:
        return 'Recovery window has opened. Return gradually — '
            'intensity follows consistency, not the other way.';
    }
  }

  static String _momentumMessage(
    CoachContext ctx, AthleteMemory memory, int v,
  ) {
    final streak = ctx.currentStreak;
    final longest = memory.longestConsistencyPhase;

    if (streak >= longest && longest >= 10) {
      return 'Longest consistency phase on record. '
          'Your training discipline is becoming structural — protect it.';
    }
    if (memory.bestMomentumScore > 70 && streak >= 7) {
      return switch (v) {
        0 => 'Current consistency is your strongest performance adaptation right now.',
        1 => 'Momentum has been climbing for $streak consecutive days. '
            'This is when adaptation compounds fastest.',
        _ => '$streak days of discipline. Your body is in the optimal adaptation window.',
      };
    }
    return 'Consistency phase is stabilizing. '
        'The training discipline is becoming reliable.';
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
        message: '$name PR is locked in. Recovery starts now — protein and sleep '
            'will consolidate the adaptation.',
        topic: topic,
      );
    }

    // ── Fatigued muscle was trained — reflective framing ─────────────────
    final fatigued = ctx.mostFatiguedMuscle;
    if (fatigued != null && fatigued.value < 45) {
      final muscle = _cap(fatigued.key);
      return (
        message: '$muscle loading stayed within session limits today. '
            'Recovery should stabilize within 24–36h.',
        topic: topic,
      );
    }

    // ── Volume notable this week ──────────────────────────────────────────
    if (ctx.hasVolumeSpike) {
      return (
        message: 'Volume is accumulating well this week. '
            'Protein synthesis peaks in the next 24–48h — recovery is the work now.',
        topic: topic,
      );
    }

    // ── Deload week complete ──────────────────────────────────────────────
    if (ctx.isDeloadWeek) {
      return (
        message: 'Deload session complete. '
            'Full adaptation should peak in the next 3–5 days.',
        topic: topic,
      );
    }

    // ── Tone-calibrated default ───────────────────────────────────────────
    switch (tone) {
      case CoachTone.aggressive:
        return (
          message: 'Session logged. Now execute recovery — eat, sleep, repeat.',
          topic: topic,
        );
      case CoachTone.elite:
        return (
          message: v == 0
              ? 'Good session. The adaptation window is open — protect it with quality sleep tonight.'
              : 'Session complete. What happens in the next 24h determines how this converts to strength.',
          topic: topic,
        );
      case CoachTone.scientific:
        return (
          message: v == 0
              ? 'Session logged. Muscle protein synthesis is elevated for the next 24–48h — match it with adequate protein intake.'
              : 'Training stimulus applied. Recovery is now the rate-limiting factor for adaptation.',
          topic: topic,
        );
      case CoachTone.supportive:
        return (
          message: v == 0
              ? 'Good session today. Rest, eat well, and the work you just did compounds overnight.'
              : 'Training done — that\'s one more session in the pattern. Recovery carries it forward.',
          topic: topic,
        );
      case CoachTone.disciplined:
        return (
          message: 'Session complete. Recovery is part of the discipline — treat it the same way.',
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
