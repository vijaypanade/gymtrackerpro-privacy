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

  // Protein habit memory — ProteinIntelligence finisher source, already
  // confidence-gated and cooldown-gated by AppProvider. '' = stay silent.
  final String proteinFinisher;

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
    this.proteinFinisher    = '',
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
    String? proteinFinisher,
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
    proteinFinisher:    proteinFinisher    ?? this.proteinFinisher,
  );
}

// ── Orchestrator ──────────────────────────────────────────────────────────────

class NarrativeOrchestrator {
  NarrativeOrchestrator._();

  // Day-rotated wording — the same situation on consecutive days should
  // never read identically. Rotation index changes daily.
  static int get _day =>
      DateTime.now().difference(DateTime(2024)).inDays;

  static String _daily(List<String> variants) =>
      variants[_day % variants.length];

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

    // Remembered protein habit — provider passes it only when the habit is
    // reliable and the cooldown allows. Never invented, often silent.
    final habit = ctx.proteinFinisher;
    final proteinNote = habit.isNotEmpty
        ? '${_cap(habit)} usually finishes your day. That still fits today.'
        : '';

    // PR achieved today — acknowledge specifically, then recovery
    if (ctx.prToday && trained.isNotEmpty) {
      return NarrativeMessage(
        label: 'Session Complete',
        body: '${_cap(trained.first)} PR locked in. Protein and sleep tonight.',
        tone: NarrativeTone.celebrate,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Two muscle groups trained — name them
    if (trained.length >= 2) {
      final names = trained.take(2).map(_cap).join(' + ');
      return NarrativeMessage(
        label: 'Recovery Window',
        body: '$names done. Eat well, sleep well.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Single muscle group
    if (trained.length == 1) {
      return NarrativeMessage(
        label: 'Recovery Window',
        body: proteinNote.isNotEmpty
            ? '${_cap(trained.first)} done. $proteinNote'
            : '${_cap(trained.first)} worked hard today. Rest and protein finish the job.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // Session complete but muscle categories unknown
    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Recovery Window',
        body: 'Session done. Recovery is the work now.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    return NarrativeMessage(
      label: 'Recovery Window',
      body: proteinNote.isNotEmpty
          ? 'Session complete. $proteinNote'
          : 'Session complete. Sleep and protein tonight.',
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
        body: _daily([
          '${_cap(limiting)} is still recovering. Train around it today.',
          '${_cap(limiting)} needs one more day. Work something else.',
          '${_cap(limiting)} is almost back. Not yet, though.',
        ]),
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Moderate suppression — softer recommendation
    if (limiting.isNotEmpty) {
      return NarrativeMessage(
        label: 'Recovery',
        body: _daily([
          '${_cap(limiting)} needs another day. Work something else.',
          '${_cap(limiting)} is close. Give it one more day.',
          'Leave ${limiting.toLowerCase()} alone today. Everything else is open.',
        ]),
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Multiple suppressed muscles
    if (ctx.suppressedMuscles.isNotEmpty) {
      final names = ctx.suppressedMuscles.take(2).map(_cap).join(' and ');
      return NarrativeMessage(
        label: 'Recovery',
        body: '$names still rebuilding. Shift focus today.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.nextDay,
      );
    }

    // Good recovery — ready to push again
    if (ctx.overallRecovery >= 75) {
      return const NarrativeMessage(
        label: 'Ready',
        body: 'Recovery looks good. Ready to push today.',
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
        body: _daily([
          '${_cap(limiting)} is still recovering. Go easy on it today.',
          '${_cap(limiting)} needs more time. Keep it light.',
          'Still early for ${limiting.toLowerCase()}. Go easy there.',
        ]),
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Moderate suppression with a named muscle — softer guidance
    if (limiting.isNotEmpty && ctx.overallRecovery < 60) {
      return NarrativeMessage(
        label: 'Recovery',
        body: _daily([
          '${_cap(limiting)} needs more time. Train around it.',
          '${_cap(limiting)} is getting there. One more easy day.',
          '${_cap(limiting)} is almost ready. Not today.',
        ]),
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // High fatigue across multiple muscles
    if (ctx.highFatigue) {
      return NarrativeMessage(
        label: 'Recovery Focus',
        body: _daily([
          'Fatigue is building. Keep today controlled.',
          'The body is asking for less. Listen to it today.',
          'Still carrying fatigue. Lighter work today.',
        ]),
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Deload week — load management
    if (ctx.needsDeload) {
      return const NarrativeMessage(
        label: 'Recovery Focus',
        body: 'You\'ve been pushing for weeks. Go lighter today.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Peak readiness with a ready muscle — push opportunity
    if (ctx.readyMuscles.isNotEmpty && ctx.overallRecovery >= 82) {
      return NarrativeMessage(
        label: 'Progression',
        body: '${_cap(ctx.readyMuscles.first)} is fresh. Good day to push it.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Locked-in momentum — reinforce the habit
    if (ctx.isLockedIn) {
      return const NarrativeMessage(
        label: 'Momentum',
        body: 'You\'re in a rhythm. Protect it.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Rising momentum with PR energy
    if (ctx.isRising && ctx.prToday) {
      return const NarrativeMessage(
        label: 'Momentum',
        body: 'Momentum is climbing. It\'s working.',
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
        body: 'Rest day. Muscles grow now — this counts.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.restDay,
      );
    }

    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Rest Day',
        body: 'Body is rebuilding. Sleep and food are the work today.',
        tone: NarrativeTone.recover,
        phase: NarrativePhase.restDay,
      );
    }

    return NarrativeMessage(
      label: 'Rest Day',
      body: _daily([
        'Rest day. The plan accounts for it.',
        'Rest day. Nothing to do here.',
        'Scheduled rest. It counts as training.',
      ]),
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
        body: 'You\'re fully rested. Start lighter than you think.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.comeback,
      );
    }

    if (days >= 7) {
      return const NarrativeMessage(
        label: 'Comeback',
        body: 'One session resets the rhythm. Don\'t try to catch up.',
        tone: NarrativeTone.coach,
        phase: NarrativePhase.comeback,
      );
    }

    // 4–6 days
    return const NarrativeMessage(
      label: 'Comeback',
      body: 'The gap is smaller than it feels. One session today.',
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

    // Planner owns "what changed" — session stats only.
    // Recovery/protein guidance lives on the home narrative (single owner).
    String body(String header) =>
        statLine.isNotEmpty ? '$header\n$statLine.' : header;

    // ── PR locked in — acknowledge first ─────────────────────────────────
    if (ctx.prToday && trained.isNotEmpty) {
      return NarrativeMessage(
        label: 'Session Complete',
        body: body('${_cap(trained.first)} PR locked in.'),
        tone: NarrativeTone.celebrate,
        phase: NarrativePhase.postWorkout,
      );
    }

    // ── Two or more muscle groups trained ─────────────────────────────────
    if (trained.length >= 2) {
      final names = trained.take(2).map(_cap).join(' + ');
      return NarrativeMessage(
        label: 'Session Complete',
        body: body('$names complete.'),
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    // ── Single muscle group ───────────────────────────────────────────────
    if (trained.length == 1) {
      return NarrativeMessage(
        label: 'Session Complete',
        body: body('${_cap(trained.first)} session logged.'),
        tone: NarrativeTone.recover,
        phase: NarrativePhase.postWorkout,
      );
    }

    return NarrativeMessage(
      label: 'Session Complete',
      body: body('Session complete.'),
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
    final bool poorSleep   = sleepKnown && ctx.sleepHours < 6.0;
    final bool strongSleep = sleepKnown && ctx.sleepHours >= 8.0;

    if (limiting.isNotEmpty && ctx.overallRecovery < 40) {
      return NarrativeMessage(
        label: 'Recovery',
        body: _daily([
          '${_cap(limiting)} is working through it. Keep it out of today\'s plan.',
          'Skip heavy ${limiting.toLowerCase()} work today.',
          '${_cap(limiting)} sits this one out.',
        ]),
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (limiting.isNotEmpty && ctx.overallRecovery < 60) {
      return NarrativeMessage(
        label: 'Recovery',
        body: _daily([
          'Plan around ${limiting.toLowerCase()} today.',
          '${_cap(limiting)} gets a lighter role today.',
          'Keep ${limiting.toLowerCase()} easy in today\'s plan.',
        ]),
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.highFatigue) {
      return const NarrativeMessage(
        label: 'Readiness',
        body: 'Fatigue is building. Keep today controlled.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.needsDeload) {
      return const NarrativeMessage(
        label: 'Load Management',
        body: 'You\'ve earned a lighter day. Keep it clean.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    // ≥75% recovery + at least one ready muscle — sleep-aware variants.
    if (ctx.readyMuscles.isNotEmpty && ctx.overallRecovery >= 75) {
      final readyList = ctx.readyMuscles.take(2).toList();
      final muscles   = readyList.map(_cap).join(' and ');
      final plural    = readyList.length > 1 ? 'are' : 'is';

      if (poorSleep) {
        // Good recovery score but sleep limits neurological peak — soften push.
        return const NarrativeMessage(
          label: 'Readiness',
          body: 'Short sleep last night. Keep quality high, loads moderate.',
          tone: NarrativeTone.stabilize,
          phase: NarrativePhase.preWorkout,
        );
      }

      if (ctx.overallRecovery >= 85) {
        if (strongSleep) {
          return NarrativeMessage(
            label: 'Prime Window',
            body: 'Sleep helped. $muscles $plural ready — good day to push.',
            tone: NarrativeTone.push,
            phase: NarrativePhase.preWorkout,
          );
        }
        return NarrativeMessage(
          label: 'Prime Window',
          body: '$muscles $plural ready. Add a set on your main lift.',
          tone: NarrativeTone.push,
          phase: NarrativePhase.preWorkout,
        );
      }

      if (strongSleep) {
        return NarrativeMessage(
          label: 'Progression',
          body: 'Sleep helped today. $muscles $plural ready to work.',
          tone: NarrativeTone.push,
          phase: NarrativePhase.preWorkout,
        );
      }
      return NarrativeMessage(
        label: 'Progression',
        body: '$muscles $plural recovered well. Push where form allows.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    // Sub-75% recovery with poor sleep — surface the sleep signal as the dominant note.
    if (poorSleep) {
      return const NarrativeMessage(
        label: 'Readiness',
        body: 'Short sleep last night. Keep today clean and controlled.',
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
        body: 'Pace yourself today. Technique over load.',
        tone: NarrativeTone.stabilize,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.recoverySuppressed) {
      return const NarrativeMessage(
        label: 'Execution',
        body: 'Still recovering. Quality reps, no failure sets.',
        tone: NarrativeTone.protect,
        phase: NarrativePhase.preWorkout,
      );
    }

    if (ctx.readyMuscles.isNotEmpty) {
      return NarrativeMessage(
        label: 'Execution',
        body: '${_cap(ctx.readyMuscles.first)} is ready. Push the big sets.',
        tone: NarrativeTone.push,
        phase: NarrativePhase.preWorkout,
      );
    }

    return const NarrativeMessage(
      label: 'Execution',
      body: 'Clean reps. Controlled tempo. That\'s the session.',
      tone: NarrativeTone.coach,
      phase: NarrativePhase.preWorkout,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
