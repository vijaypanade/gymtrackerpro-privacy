// lib/services/narrative_orchestrator.dart
//
// Centralized Narrative Intelligence Orchestrator — Phase 25.
//
// ONE source of truth for all contextual AI messaging on the home screen.
// Every message is phase-gated so the app never says contradictory things:
//
//   POST-WORKOUT  → recovery framing only, never "avoid X" or "train Y"
//   PRE-WORKOUT   → protective coaching, readiness signals, progression cues
//   NEXT-DAY      → transition from recovery to planning
//   REST-DAY      → restoration language
//   COMEBACK      → gentle re-entry, no pressure
//
// Pure static utility — no Flutter, no Provider, no state.
// AppProvider builds NarrativeContext from its sub-providers and calls build().

import 'dart:developer' as dev;

// ── Phase — where the athlete is in the training lifecycle ───────────────────

enum NarrativePhase {
  preWorkout,   // no workout started today, or workout was yesterday+
  postWorkout,  // plan completed today (daysSince == 0 && isCompleted)
  nextDay,      // daysSince == 1 — transitioning from yesterday's session
  restDay,      // today is a planned rest day
  comeback,     // 4+ days inactive, has prior training history
}

// ── Tone — emotional register of the message ─────────────────────────────────

enum NarrativeTone {
  protect,    // high fatigue / overtrained — dial it back
  push,       // peak readiness — go for it
  recover,    // post-workout adaptation window — rest and eat
  celebrate,  // PR or milestone — acknowledge achievement
  coach,      // general guidance — steady, calm
  stabilize,  // moderate fatigue — train but manage load
}

// ── Message — what gets surfaced to the home screen ──────────────────────────

class NarrativeMessage {
  final String label; // small-caps category tag (e.g. "Recovery Window")
  final String body;  // one or two sentence insight text
  final NarrativeTone tone;
  final NarrativePhase phase;

  const NarrativeMessage({
    required this.label,
    required this.body,
    required this.tone,
    required this.phase,
  });

  bool get isEmpty => body.isEmpty;

  static const NarrativeMessage empty = NarrativeMessage(
    label: '',
    body: '',
    tone: NarrativeTone.coach,
    phase: NarrativePhase.preWorkout,
  );
}

// ── Context — snapshot assembled by AppProvider ───────────────────────────────

class NarrativeContext {
  final NarrativePhase phase;

  // Recovery
  final bool   recoverySuppressed; // readiness depleted or low
  final bool   recoveryImproving;  // readiness ready or peak
  final bool   highFatigue;
  final bool   needsDeload;
  final double overallRecovery;    // 0–100
  final String limitingMuscle;    // '' if none

  // Muscles
  final List<String> trainedToday;      // categories from today's completed plan
  final List<String> suppressedMuscles; // score < 60
  final List<String> readyMuscles;      // score >= 80

  // Training signals
  final bool prToday;
  final bool isDropoutRisk;
  final bool isLockedIn;
  final bool isRising;
  final int  momentumScore; // 0–100
  final int  daysSince;

  // Sleep signals — populated only when Health Connect data is available.
  // Both default to safe no-data values so existing call sites need no change.
  final double sleepHours;   // last night's sleep in hours; 0.0 = no data
  final bool   hasSleepData; // false when HC not connected or returned no record

  // Session performance — populated only when plan.isCompleted && history available.
  // All default to zero/false so pre-workout and other phases are unaffected.
  final double sessionVolumeKg;    // kg total volume (weight × reps); 0.0 = no weight exercises
  final int    sessionSetCount;    // done set count; 0 = no data
  final double previousVolumeKg;  // last same-name session volume; 0.0 = not found
  final bool   hasPreviousSession; // true when previousVolumeKg is meaningful

  const NarrativeContext({
    required this.phase,
    required this.recoverySuppressed,
    required this.recoveryImproving,
    required this.highFatigue,
    required this.needsDeload,
    required this.overallRecovery,
    required this.limitingMuscle,
    required this.trainedToday,
    required this.suppressedMuscles,
    required this.readyMuscles,
    required this.prToday,
    required this.isDropoutRisk,
    required this.isLockedIn,
    required this.isRising,
    required this.momentumScore,
    required this.daysSince,
    this.sleepHours      = 0.0,
    this.hasSleepData    = false,
    this.sessionVolumeKg    = 0.0,
    this.sessionSetCount    = 0,
    this.previousVolumeKg   = 0.0,
    this.hasPreviousSession = false,
  });

  NarrativeContext copyWith({
    NarrativePhase? phase,
    bool? recoverySuppressed,
    bool? recoveryImproving,
    bool? highFatigue,
    bool? needsDeload,
    double? overallRecovery,
    String? limitingMuscle,
    List<String>? trainedToday,
    List<String>? suppressedMuscles,
    List<String>? readyMuscles,
    bool? prToday,
    bool? isDropoutRisk,
    bool? isLockedIn,
    bool? isRising,
    int? momentumScore,
    int? daysSince,
    double? sleepHours,
    bool? hasSleepData,
    double? sessionVolumeKg,
    int? sessionSetCount,
    double? previousVolumeKg,
    bool? hasPreviousSession,
  }) => NarrativeContext(
    phase:              phase              ?? this.phase,
    recoverySuppressed: recoverySuppressed ?? this.recoverySuppressed,
    recoveryImproving:  recoveryImproving  ?? this.recoveryImproving,
    highFatigue:        highFatigue        ?? this.highFatigue,
    needsDeload:        needsDeload        ?? this.needsDeload,
    overallRecovery:    overallRecovery    ?? this.overallRecovery,
    limitingMuscle:     limitingMuscle     ?? this.limitingMuscle,
    trainedToday:       trainedToday       ?? this.trainedToday,
    suppressedMuscles:  suppressedMuscles  ?? this.suppressedMuscles,
    readyMuscles:       readyMuscles       ?? this.readyMuscles,
    prToday:            prToday            ?? this.prToday,
    isDropoutRisk:      isDropoutRisk      ?? this.isDropoutRisk,
    isLockedIn:         isLockedIn         ?? this.isLockedIn,
    isRising:           isRising           ?? this.isRising,
    momentumScore:      momentumScore      ?? this.momentumScore,
    daysSince:          daysSince          ?? this.daysSince,
    sleepHours:         sleepHours         ?? this.sleepHours,
    hasSleepData:       hasSleepData       ?? this.hasSleepData,
    sessionVolumeKg:    sessionVolumeKg    ?? this.sessionVolumeKg,
    sessionSetCount:    sessionSetCount    ?? this.sessionSetCount,
    previousVolumeKg:   previousVolumeKg   ?? this.previousVolumeKg,
    hasPreviousSession: hasPreviousSession ?? this.hasPreviousSession,
  );
}

// ── Orchestrator ──────────────────────────────────────────────────────────────

class NarrativeOrchestrator {
  NarrativeOrchestrator._();

  /// Main entry. Call this from AppProvider — returns the phase-appropriate message.
  static NarrativeMessage build(NarrativeContext ctx) {
    final msg = _route(ctx);
    dev.log(
      'phase=${ctx.phase.name} '
      'trained=${ctx.trainedToday} '
      'suppressed=${ctx.suppressedMuscles} '
      'recovery=${ctx.overallRecovery.toStringAsFixed(0)} '
      'message="${msg.body}"',
      name: 'Narrative',
    );
    return msg;
  }

  // ── Phase router ─────────────────────────────────────────────────────────

  static NarrativeMessage _route(NarrativeContext ctx) {
    switch (ctx.phase) {
      case NarrativePhase.postWorkout:
        return _postWorkout(ctx);
      case NarrativePhase.restDay:
        return _restDay(ctx);
      case NarrativePhase.comeback:
        return _comeback(ctx);
      case NarrativePhase.nextDay:
        return _nextDay(ctx);
      case NarrativePhase.preWorkout:
        return _preWorkout(ctx);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATE C — POST-WORKOUT
  // CRITICAL: never say "avoid X" or "train a different muscle group".
  // The session happened. Frame recovery as the active, productive phase.
  // ════════════════════════════════════════════════════════════════════════
  static NarrativeMessage _postWorkout(NarrativeContext ctx) {
    final trained = ctx.trainedToday;

    // PR achieved today — acknowledge specifically, then recovery
    if (ctx.prToday && trained.isNotEmpty) {
      return NarrativeMessage(
        label: 'Session Complete',
        body: '${_cap(trained.first)} PR locked in. Recovery cycle started — '
            'sleep and protein consolidate the adaptation.',
        tone: NarrativeTone.celebrate,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Two muscle groups trained — name them
    if (trained.length >= 2) {
      final names = trained.take(2).map(_cap).join(' + ');
      return NarrativeMessage(
        label: 'Recovery Window',
        body: '$names session complete. Recovery demand elevated — '
            'protein synthesis is active for the next 24–48h.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Single muscle group
    if (trained.length == 1) {
      return NarrativeMessage(
        label: 'Recovery Window',
        body: '${_cap(trained.first)} recovery cycle initiated. '
            'Adaptation builds in the next 24–48h — sleep and nutrition complete it.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Session complete but muscle categories unknown
    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Recovery Window',
        body: 'Training stress recorded. Recovery is the active phase now — '
            'restoration drives the adaptation.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    return const NarrativeMessage(
      label: 'Recovery Window',
      body: 'Session complete. Adaptation is underway — '
          'protect it with quality sleep and adequate protein tonight.',
      tone: NarrativeTone.recover,
      phase: NarrativePhase.postWorkout,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATE D — NEXT DAY
  // Yesterday's muscles may still be suppressed. Transition from recovery
  // to planning. "Avoid X today" is now valid again.
  // ════════════════════════════════════════════════════════════════════════
  static NarrativeMessage _nextDay(NarrativeContext ctx) {
    final limiting = ctx.limitingMuscle;

    // Still heavily suppressed — direct guidance
    if (limiting.isNotEmpty && ctx.overallRecovery < 50) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} recovery remains elevated from yesterday. '
            'Alternative loading today protects the adaptation.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Moderate suppression — softer recommendation
    if (limiting.isNotEmpty) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} fatigue still present. '
            'A different stimulus today keeps progression moving without overloading recovery.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Multiple suppressed muscles
    if (ctx.suppressedMuscles.isNotEmpty) {
      final names = ctx.suppressedMuscles.take(2).map(_cap).join(' and ');
      return NarrativeMessage(
        label: 'Recovery',
        body: '$names still rebuilding from yesterday. '
            'A different focus today keeps momentum without overloading recovery.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Good recovery — ready to push again
    if (ctx.overallRecovery >= 75) {
      return const NarrativeMessage(
        label: 'Ready',
        body: 'Recovery is solid after yesterday\'s session. '
            'Progressive loading is appropriate today.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.nextDay,
      );
    }

    // Moderate — let existing logic handle it
    return NarrativeMessage.empty;
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATE A — PRE-WORKOUT
  // Today's session hasn't started. Protective coaching, readiness signals,
  // progression cues — all valid here.
  // ════════════════════════════════════════════════════════════════════════
  static NarrativeMessage _preWorkout(NarrativeContext ctx) {
    final limiting = ctx.limitingMuscle;

    // Severe recovery suppression — prioritize the warning
    if (limiting.isNotEmpty && ctx.overallRecovery < 40) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} fatigue is elevated. '
            'Reducing axial loading today protects recovery quality and long-term adaptation.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Moderate suppression with a named muscle — softer guidance
    if (limiting.isNotEmpty && ctx.overallRecovery < 60) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} recovery still elevated. '
            'A different stimulus today keeps progression moving without overloading the tissue.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // High fatigue across multiple muscles
    if (ctx.highFatigue) {
      return const NarrativeMessage(
        label: 'Recovery Focus',
        body: 'Fatigue is building across primary muscle groups. '
            'Controlled, technical training today maintains momentum safely.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Deload week — load management
    if (ctx.needsDeload) {
      return const NarrativeMessage(
        label: 'Recovery Focus',
        body: 'Training load has been accumulating. '
            'A lighter session today lets the body consolidate the gains from recent weeks.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Peak readiness with a ready muscle — push opportunity
    if (ctx.readyMuscles.isNotEmpty && ctx.overallRecovery >= 82) {
      return NarrativeMessage(
        label: 'Progression',
        body: '${_cap(ctx.readyMuscles.first)} is fully recovered — '
            'good conditions for a progressive loading session today.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Locked-in momentum — reinforce the habit
    if (ctx.isLockedIn) {
      return const NarrativeMessage(
        label: 'Momentum',
        body: 'Consistency is accelerating. '
            'Each session compounds — protect the rhythm.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Rising momentum with PR energy
    if (ctx.isRising && ctx.prToday) {
      return const NarrativeMessage(
        label: 'Momentum',
        body: 'Momentum is climbing. Recent PRs and consistent volume are working.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Return empty → AppProvider falls through to existing priority cascade
    return NarrativeMessage.empty;
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATE E — REST DAY
  // Intentional rest. No pressure. Recovery is the training.
  // ════════════════════════════════════════════════════════════════════════
  static NarrativeMessage _restDay(NarrativeContext ctx) {
    if (ctx.isLockedIn) {
      return const NarrativeMessage(
        label: 'Rest Day',
        body: 'Strategic recovery is part of the training plan. '
            'Muscles adapt and strengthen during rest — this session counts.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.restDay,
      );
    }

    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Rest Day',
        body: 'Recovery systems active. '
            'Tissue is rebuilding — sleep and nutrition are the work today.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.restDay,
      );
    }

    return const NarrativeMessage(
      label: 'Rest Day',
      body: 'Adaptation happens between sessions. '
          'Strategic rest improves long-term progression — the plan accounts for it.',
      tone: NarrativeTone.recover,
      phase: NarrativePhase.restDay,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATE F — COMEBACK
  // 4+ days inactive. Supportive restart framing. No pressure.
  // ════════════════════════════════════════════════════════════════════════
  static NarrativeMessage _comeback(NarrativeContext ctx) {
    final days = ctx.daysSince;

    if (days >= 10) {
      return const NarrativeMessage(
        label: 'Comeback',
        body: 'Recovery capacity is fully restored. '
            'A controlled return today — start lighter than you think you need to.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.comeback,
      );
    }

    if (days >= 7) {
      return const NarrativeMessage(
        label: 'Comeback',
        body: 'Training rhythm can restart today. '
            'A single session resets the pattern — controlled effort beats catching up aggressively.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.comeback,
      );
    }

    // 4–6 days
    return const NarrativeMessage(
      label: 'Comeback',
      body: 'One session today rebuilds the rhythm. '
          'Consistency compounds — the gap is smaller than it feels.',
      tone: NarrativeTone.coach,
      phase: NarrativePhase.comeback,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PLANNER MESSAGES — distinct copy for the planner top banner.
  // The planner is viewed before, during, and after a session.
  // Routing is done externally (AppProvider.plannerNarrative).
  // ════════════════════════════════════════════════════════════════════════

  /// POST-WORKOUT planner copy.
  /// Never instructs "avoid X today" — the session is already done.
  static NarrativeMessage postWorkoutPlannerMessage(NarrativeContext ctx) {
    final trained = ctx.trainedToday;

    // ── Session stat helpers ───────────────────────────────────────────────
    // Formats volume: ≥1000 kg → tonnes ("2.3t"), otherwise kg ("450 kg").
    String fmtVol(double v) =>
        v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}t' : '${v.round()} kg';

    final double vol     = ctx.sessionVolumeKg;
    final int    sets    = ctx.sessionSetCount;
    final bool   hasVol  = vol > 0;
    final bool   hasSets = sets > 0;

    // Stat line combines set count, volume, and vs-previous comparison.
    // Empty string when no weight data is available (bodyweight / cardio only).
    String statLine = '';
    if (hasSets && hasVol) {
      final base = '$sets sets • ${fmtVol(vol)}';
      if (ctx.hasPreviousSession && ctx.previousVolumeKg > 0) {
        final pct = (vol - ctx.previousVolumeKg) / ctx.previousVolumeKg * 100;
        final absPct = pct.abs().round();
        if (absPct >= 1) {
          final dir = pct >= 0 ? 'up' : 'down';
          statLine = '$base — $dir $absPct% vs last session';
        } else {
          statLine = base;
        }
      } else {
        statLine = base;
      }
    } else if (hasSets) {
      statLine = '$sets sets completed';
    }

    // Injects stat line between the session-name line and the recovery note.
    // No stat line → messages collapse to the original 1-line format.
    String body(String header, String recovery) => statLine.isNotEmpty
        ? '$header\n$statLine.\n$recovery'
        : '$header $recovery';

    // ── PR locked in — acknowledge first ─────────────────────────────────
    if (ctx.prToday && trained.isNotEmpty) {
      return NarrativeMessage(
        label: 'Session Complete',
        body: body(
          '${_cap(trained.first)} PR locked in.',
          'Recovery cycle started — sleep and protein consolidate the adaptation.',
        ),
        tone: NarrativeTone.celebrate,
        phase: NarrativePhase.postWorkout,
      );
    }

    // ── Two or more muscle groups trained ─────────────────────────────────
    if (trained.length >= 2) {
      final names = trained.take(2).map(_cap).join(' + ');
      return NarrativeMessage(
        label: 'Recovery Window',
        body: body(
          '$names complete.',
          'Recovery demand elevated — prioritize protein intake and quality sleep tonight.',
        ),
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // ── Single muscle group ───────────────────────────────────────────────
    if (trained.length == 1) {
      return NarrativeMessage(
        label: 'Recovery Window',
        body: body(
          '${_cap(trained.first)} session logged.',
          'Protein synthesis elevated — sleep and nutrition complete the adaptation.',
        ),
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // ── Session done but muscle category unknown ──────────────────────────
    if (ctx.recoverySuppressed) {
      return NarrativeMessage(
        label: 'Recovery Window',
        body: body(
          'High training load accumulated.',
          'Recovery window active — sleep and nutrition are the work now.',
        ),
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    return NarrativeMessage(
      label: 'Recovery Window',
      body: body(
        'Session complete.',
        'Recovery window active for the next 24–48h — '
        'protein synthesis elevated. Prioritize sleep and nutrition.',
      ),
      tone: NarrativeTone.recover,
      phase: NarrativePhase.postWorkout,
    );
  }

  /// PRE-WORKOUT planner copy — readiness signals, load guidance.
  /// Returns empty when no strong recovery signal exists (caller uses aiSuggestion).
  /// Fallback path: fires only when _workoutFocusMessage returned empty (no title).
  static NarrativeMessage preWorkoutPlannerMessage(NarrativeContext ctx) {
    final limiting = ctx.limitingMuscle;

    // Sleep helpers — only used when HC data is present and plausible.
    final bool sleepKnown  = ctx.hasSleepData && ctx.sleepHours >= 1.0;
    final String sleepStr  = sleepKnown ? ctx.sleepHours.toStringAsFixed(1) : '';
    final bool poorSleep   = sleepKnown && ctx.sleepHours < 6.0;
    final bool strongSleep = sleepKnown && ctx.sleepHours >= 8.0;

    if (limiting.isNotEmpty && ctx.overallRecovery < 40) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} fatigue is elevated — '
            'reducing axial loading today protects adaptation quality.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (limiting.isNotEmpty && ctx.overallRecovery < 60) {
      return NarrativeMessage(
        label: 'Recovery',
        body: '${_cap(limiting)} still recovering. '
            'Alternative loading maintains progression without overloading the tissue.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.highFatigue) {
      return const NarrativeMessage(
        label: 'Readiness',
        body: 'Fatigue accumulating across primary muscle groups. '
            'Volume management today protects training quality and adaptation.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.needsDeload) {
      return const NarrativeMessage(
        label: 'Load Management',
        body: 'Accumulated training stress suggests a lighter session. '
            'Quality movement over maximal load today.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // ≥75% recovery + at least one ready muscle — sleep-aware variants.
    if (ctx.readyMuscles.isNotEmpty && ctx.overallRecovery >= 75) {
      final readyList = ctx.readyMuscles.take(2).toList();
      final muscles   = readyList.map(_cap).join(' and ');
      final plural    = readyList.length > 1 ? 'are' : 'is';
      final score     = ctx.overallRecovery.round();

      if (poorSleep) {
        // Good recovery score but sleep limits neurological peak — soften push.
        return NarrativeMessage(
          label: 'Readiness',
          body: 'Sleep logged at ${sleepStr}h. '
              'Recovery supports productive training — '
              'focus on execution quality over maximal loading today.',
          tone: NarrativeTone.stabilize,
          phase: NarrativePhase.preWorkout,
        );
      }

      if (ctx.overallRecovery >= 85) {
        if (strongSleep) {
          return NarrativeMessage(
            label: 'Prime Window',
            body: 'Sleep at $sleepStr h. $muscles $plural fully recovered at $score% — '
                'strong recovery foundation supports full training intensity today.',
            tone: NarrativeTone.push,
            phase: NarrativePhase.preWorkout,
          );
        }
        return NarrativeMessage(
          label: 'Prime Window',
          body: '$muscles $plural fully recovered at $score%. '
              'Add 1 extra set on your main movement — '
              'recovery markers support full training intensity today.',
          tone: NarrativeTone.push,
          phase: NarrativePhase.preWorkout,
        );
      }

      if (strongSleep) {
        return NarrativeMessage(
          label: 'Progression',
          body: 'Sleep at ${sleepStr}h. $muscles $plural recovered well — '
              'good conditions for consistent loading today.',
          tone: NarrativeTone.push,
          phase: NarrativePhase.preWorkout,
        );
      }
      return NarrativeMessage(
        label: 'Progression',
        body: '$muscles $plural recovered well. '
            'Good conditions for consistent loading — '
            'push where form allows and keep quality high.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Sub-75% recovery with poor sleep — surface the sleep signal as the dominant note.
    if (poorSleep) {
      return NarrativeMessage(
        label: 'Readiness',
        body: 'Sleep logged at ${sleepStr}h. '
            'Recovery supports training — focus on execution quality today.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    return NarrativeMessage.empty;
  }

  /// ACTIVE WORKOUT planner copy — execution guidance, pacing, effort coaching.
  static NarrativeMessage activeWorkoutMessage(NarrativeContext ctx) {
    if (ctx.highFatigue) {
      return const NarrativeMessage(
        label: 'Execution',
        body: 'Pacing this session protects performance quality. '
            'Prioritise technique and controlled effort over maximal load.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Execution',
        body: 'Monitor effort closely — tissue is still in recovery phase. '
            'Quality reps over failure sets today.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.readyMuscles.isNotEmpty) {
      return NarrativeMessage(
        label: 'Execution',
        body: '${_cap(ctx.readyMuscles.first)} is loaded and ready — '
            'push the intensity on key compound sets.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    return const NarrativeMessage(
      label: 'Execution',
      body: 'Focus on execution quality. '
          'Controlled tempo and effort compound over time.',
      tone: NarrativeTone.coach,
      phase: NarrativePhase.preWorkout,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
