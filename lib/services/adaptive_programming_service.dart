// lib/services/adaptive_programming_service.dart
// Pure Dart — no Flutter imports.
// Generates session-level adaptive programming decisions from existing intelligence signals.
//
// SAFETY CONTRACT:
//   Advisory only — NEVER modifies the week plan automatically.
//   Language is tactical, calm, coach-like. Never medical framing.
//   Swaps are suggestions, not commands.
//   Never: "You must." / "You are overtrained." / "Stop training."
//   Always: observational, athlete-empowering, coach-like.

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AdaptiveTrainingFocus {
  overload,
  maintain,
  recovery,
  deload,
  hypertrophyPush,
  strengthPush,
  technicalSession,
  comebackSession,
}

extension AdaptiveTrainingFocusX on AdaptiveTrainingFocus {
  String get label => switch (this) {
    AdaptiveTrainingFocus.overload         => 'Push Session',
    AdaptiveTrainingFocus.maintain         => '',
    AdaptiveTrainingFocus.recovery         => 'Recovery Session',
    AdaptiveTrainingFocus.deload           => 'Light Session',
    AdaptiveTrainingFocus.hypertrophyPush  => 'Growth Focus',
    AdaptiveTrainingFocus.strengthPush     => 'Strength Push',
    AdaptiveTrainingFocus.technicalSession => 'Skill Focus',
    AdaptiveTrainingFocus.comebackSession  => 'Comeback Session',
  };
}

// ── Exercise swap ─────────────────────────────────────────────────────────────

class ExerciseSwap {
  final String original;
  final String replacement;
  final String reason;

  const ExerciseSwap({
    required this.original,
    required this.replacement,
    required this.reason,
  });
}

// ── Output model ──────────────────────────────────────────────────────────────

class AdaptiveWorkoutDecision {
  final bool   shouldModifyWorkout;
  final double intensityMultiplier;
  final double volumeMultiplier;
  final bool   shouldReduceAxialLoad;
  final bool   shouldInsertDeload;
  final bool   shouldSwapExercises;
  final bool   shouldReduceFailureTraining;
  final List<ExerciseSwap> swaps;
  final List<String> suppressedMuscles;
  final List<String> prioritizedMuscles;
  final AdaptiveTrainingFocus focus;
  /// Internal reasoning — weekly program recommendations. Not shown to athlete.
  final String reasoning;
  /// One tactical explanation for the athlete — empty when no modification.
  final String athleteFacingMessage;
  /// Calm contextual insight shown when suppressed muscles exist but don't
  /// conflict with today's planned exercises. Empty when irrelevant.
  final String recoveryAlignedMessage;
  final DateTime computedAt;

  const AdaptiveWorkoutDecision({
    required this.shouldModifyWorkout,
    required this.intensityMultiplier,
    required this.volumeMultiplier,
    required this.shouldReduceAxialLoad,
    required this.shouldInsertDeload,
    required this.shouldSwapExercises,
    required this.shouldReduceFailureTraining,
    required this.swaps,
    required this.suppressedMuscles,
    required this.prioritizedMuscles,
    required this.focus,
    required this.reasoning,
    required this.athleteFacingMessage,
    required this.recoveryAlignedMessage,
    required this.computedAt,
  });

  AdaptiveWorkoutDecision copyWith({String? athleteFacingMessage}) =>
      AdaptiveWorkoutDecision(
        shouldModifyWorkout:         shouldModifyWorkout,
        intensityMultiplier:         intensityMultiplier,
        volumeMultiplier:            volumeMultiplier,
        shouldReduceAxialLoad:       shouldReduceAxialLoad,
        shouldInsertDeload:          shouldInsertDeload,
        shouldSwapExercises:         shouldSwapExercises,
        shouldReduceFailureTraining: shouldReduceFailureTraining,
        swaps:                       swaps,
        suppressedMuscles:           suppressedMuscles,
        prioritizedMuscles:          prioritizedMuscles,
        focus:                       focus,
        reasoning:                   reasoning,
        athleteFacingMessage:        athleteFacingMessage ?? this.athleteFacingMessage,
        recoveryAlignedMessage:      recoveryAlignedMessage,
        computedAt:                  computedAt,
      );

  static AdaptiveWorkoutDecision get baseline => AdaptiveWorkoutDecision(
    shouldModifyWorkout:         false,
    intensityMultiplier:         1.0,
    volumeMultiplier:            1.0,
    shouldReduceAxialLoad:       false,
    shouldInsertDeload:          false,
    shouldSwapExercises:         false,
    shouldReduceFailureTraining: false,
    swaps:                       const [],
    suppressedMuscles:           const [],
    prioritizedMuscles:          const [],
    focus:                       AdaptiveTrainingFocus.maintain,
    reasoning:                   '',
    athleteFacingMessage:        '',
    recoveryAlignedMessage:      '',
    computedAt:                  DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Input contract ────────────────────────────────────────────────────────────

class AdaptiveInput {
  // ── Recovery signals ─────────────────────────────────────────────────────
  final double recoveryScore;           // 0–100
  final bool   highFatigue;
  final bool   needsDeload;
  final String recoveryTrend;           // 'improving' | 'stable' | 'declining'
  /// Muscles with recovery score < 45 (from TrainingAdjustment).
  final List<String> suppressedMuscles;
  /// From TrainingAdjustment.shouldReduceAxialLoad.
  final bool   shouldReduceAxialLoad;
  /// From TrainingAdjustment.recommendedFocusMuscles (recovery >= 80).
  final List<String> recommendedFocusMuscles;

  // ── Trend signals (ordinals — avoids import coupling) ─────────────────────
  /// MomentumLevel.index (0=declining … 3=peaking)
  final int momentumLevel;
  /// OverreachingRisk.index (0=none … 3=high)
  final int overreachingRiskLevel;
  /// PlateauRisk.index (0=none … 3=high)
  final int plateauRiskLevel;
  /// FatigueTrend.index (0=improving … 3=suppressed)
  final int fatigueTrendLevel;

  // ── Predictive signals (ordinals) ─────────────────────────────────────────
  /// OverloadReadiness.index (0=notReady … 3=prime)
  final int overloadReadinessLevel;
  /// RecoveryCollapseRisk.index (0=low … 2=high)
  final int recoveryCollapseRiskLevel;

  // ── Adherence signals ─────────────────────────────────────────────────────
  /// BurnoutRisk.index (0=none … 3=high)
  final int    burnoutRiskLevel;
  /// IntimidationRisk.index (0=none … 3=high)
  final int    intimidationRiskLevel;
  /// 0–1 probability the athlete will return after absence
  final double comebackProbability;
  /// 0–100 composite behavioral discipline score
  final int    disciplineScore;

  // ── Athlete context ───────────────────────────────────────────────────────
  final double weeklyImprovementPct;
  final bool   isOnPlateau;
  final int    daysSinceLastWorkout;
  /// 'muscle_gain' | 'strength' | 'endurance' | 'fat_loss'
  final String goal;

  // ── AI maturity trust gates ────────────────────────────────────────────────
  /// Whether the AI has earned enough trust to recommend increasing workload.
  /// Source: aiMaturity.allowedClaims.ui.canShowAdaptiveIncrease
  /// When false, increase-focused modes (overload, strengthPush, hypertrophyPush)
  /// fall back to conservative alternatives. Reductions are never gated.
  final bool canShowAdaptiveIncrease;
  /// Whether the AI may make forward projections about the athlete's performance.
  /// Source: aiMaturity.allowedClaims.content.canMakePrediction
  /// Any future prediction language in generated messages must check this flag.
  final bool canMakePrediction;

  // ── Exercise context ──────────────────────────────────────────────────────
  /// Today's planned exercise names — used for swap matching.
  final List<String> todayExerciseNames;
  /// Today's planned exercise categories (Title Case) — used for conflict
  /// detection against suppressed muscle keys (lowercase).
  final List<String> todayExerciseCategories;

  final DateTime now;

  const AdaptiveInput({
    required this.recoveryScore,
    required this.highFatigue,
    required this.needsDeload,
    required this.recoveryTrend,
    required this.suppressedMuscles,
    required this.shouldReduceAxialLoad,
    required this.recommendedFocusMuscles,
    required this.momentumLevel,
    required this.overreachingRiskLevel,
    required this.plateauRiskLevel,
    required this.fatigueTrendLevel,
    required this.overloadReadinessLevel,
    required this.recoveryCollapseRiskLevel,
    required this.burnoutRiskLevel,
    required this.intimidationRiskLevel,
    required this.comebackProbability,
    required this.disciplineScore,
    required this.weeklyImprovementPct,
    required this.isOnPlateau,
    required this.daysSinceLastWorkout,
    required this.goal,
    required this.todayExerciseNames,
    required this.todayExerciseCategories,
    required this.now,
    required this.canShowAdaptiveIncrease,
    required this.canMakePrediction,
  });
}

// ── Swap rule ─────────────────────────────────────────────────────────────────

typedef _SwapTrigger = bool Function(AdaptiveInput);

class _SwapRule {
  final String       originalPattern;
  final String       replacement;
  final String       reason;
  final _SwapTrigger trigger;
  const _SwapRule(this.originalPattern, this.replacement, this.reason, this.trigger);
}

List<_SwapRule> _buildSwapRules() => [
  _SwapRule('deadlift',          'Chest Supported Row',  'Removes spinal loading',
      (i) => i.shouldReduceAxialLoad || i.suppressedMuscles.contains('back')),
  _SwapRule('barbell row',       'Cable Row',            'Lower axial stress',
      (i) => i.shouldReduceAxialLoad || i.recoveryScore < 60),
  _SwapRule('bent over row',     'Chest Supported Row',  'Reduces spinal loading',
      (i) => i.shouldReduceAxialLoad || i.suppressedMuscles.contains('back')),
  _SwapRule('bent-over row',     'Seated Cable Row',     'Lower posterior chain stress',
      (i) => i.shouldReduceAxialLoad || i.recoveryScore < 60),
  _SwapRule('romanian deadlift', 'Leg Curl',             'Lower fatigue demand',
      (i) => i.highFatigue || i.fatigueTrendLevel >= 2),
  _SwapRule('rdl',               'Leg Curl',             'Lower fatigue demand',
      (i) => i.highFatigue || i.fatigueTrendLevel >= 2),
  _SwapRule('good morning',      'Cable Pull-Through',   'Removes spinal load',
      (i) => i.shouldReduceAxialLoad || i.suppressedMuscles.contains('back')),
  _SwapRule('pendlay row',       'Seated Cable Row',     'Reduces axial demand',
      (i) => i.shouldReduceAxialLoad || i.recoveryScore < 60),
  _SwapRule('squat',             'Leg Press',            'Reduces spinal compression',
      (i) => i.shouldReduceAxialLoad || i.suppressedMuscles.contains('back')),
];

// ── Service ───────────────────────────────────────────────────────────────────

class AdaptiveProgrammingService {
  AdaptiveProgrammingService._();

  static final List<_SwapRule> _kSwapRules = _buildSwapRules();

  static AdaptiveWorkoutDecision compute(AdaptiveInput i) {
    // ── 1. Focus mode ─────────────────────────────────────────────────────
    final focus = _focus(i);

    // ── 2–3. Multipliers ──────────────────────────────────────────────────
    final intensityMult  = _intensityMult(focus, i);
    double volumeMult    = _volumeMult(focus, i);

    // ── 4. Axial load flag ────────────────────────────────────────────────
    final reduceAxial = i.shouldReduceAxialLoad ||
        i.suppressedMuscles.contains('back') ||
        (i.recoveryScore < 60 && i.fatigueTrendLevel >= 2);

    // ── 5. Failure training flag ──────────────────────────────────────────
    final reduceFailure = i.recoveryScore < 70 ||
        i.fatigueTrendLevel >= 2 ||
        focus == AdaptiveTrainingFocus.recovery ||
        focus == AdaptiveTrainingFocus.deload;

    // ── 6. Deload flag ────────────────────────────────────────────────────
    final insertDeload = focus == AdaptiveTrainingFocus.deload;

    // ── 7. Exercise swaps ─────────────────────────────────────────────────
    final swaps  = _generateSwaps(i);
    final doSwap = swaps.isNotEmpty;

    // ── 8. Behavioral volume modifiers ────────────────────────────────────
    // Burnout-prone: cap volume spike even when recovery looks high
    if (i.burnoutRiskLevel >= 2 && volumeMult > 1.02) volumeMult = 1.0;
    // Intimidation risk: soften volume for accessibility
    if (i.intimidationRiskLevel >= 2 && volumeMult >= 1.0) volumeMult = 0.85;

    // ── 9. Weekly recommendations (internal reasoning) ────────────────────
    final reasonParts = <String>[];
    if (i.overreachingRiskLevel >= 2)             reasonParts.add('reduce weekly volume');
    if (i.plateauRiskLevel >= 2 && i.isOnPlateau) reasonParts.add('rotate rep ranges');
    if (i.burnoutRiskLevel >= 2)                  reasonParts.add('add recovery day');
    if (i.suppressedMuscles.contains('back'))     reasonParts.add('shift pull day');
    final reasoning = reasonParts.isEmpty
        ? '' : 'Weekly: ${reasonParts.join(', ')}.';

    // ── 10. Athlete-facing message ────────────────────────────────────────
    final message = _athleteFacingMessage(focus, i, reduceAxial, swaps);

    // ── 11. shouldModifyWorkout ───────────────────────────────────────────
    final modified = focus != AdaptiveTrainingFocus.maintain ||
        doSwap || reduceAxial || reduceFailure || insertDeload;

    // ── 12. Recovery-aligned message (non-conflicting path) ───────────────
    // Suppressed muscles exist but today's session already avoids them —
    // surface a calm confirmation instead of a warning.
    final recoveryAligned = i.suppressedMuscles.isNotEmpty &&
            !_conflictsWithToday(i.suppressedMuscles, i.todayExerciseCategories)
        ? _recoveryAlignedMsg(i.suppressedMuscles, i.todayExerciseCategories)
        : '';

    return AdaptiveWorkoutDecision(
      shouldModifyWorkout:         modified && message.isNotEmpty,
      intensityMultiplier:         intensityMult,
      volumeMultiplier:            volumeMult,
      shouldReduceAxialLoad:       reduceAxial,
      shouldInsertDeload:          insertDeload,
      shouldSwapExercises:         doSwap,
      shouldReduceFailureTraining: reduceFailure,
      swaps:                       swaps,
      suppressedMuscles:           List.unmodifiable(i.suppressedMuscles),
      prioritizedMuscles:          List.unmodifiable(i.recommendedFocusMuscles),
      focus:                       focus,
      reasoning:                   reasoning,
      athleteFacingMessage:        message,
      recoveryAlignedMessage:      recoveryAligned,
      computedAt:                  i.now,
    );
  }

  // ── Focus detection ───────────────────────────────────────────────────────

  static AdaptiveTrainingFocus _focus(AdaptiveInput i) {
    // 1. Deload — safety first (mesocycle complete or collapse risk)
    if (i.needsDeload || i.overreachingRiskLevel >= 3 || i.recoveryCollapseRiskLevel >= 2) {
      return AdaptiveTrainingFocus.deload;
    }
    // 2. Comeback — absence + still likely to return
    if (i.daysSinceLastWorkout >= 4 && i.comebackProbability >= 0.5) {
      return AdaptiveTrainingFocus.comebackSession;
    }
    // Intimidation-driven session simplification
    if (i.intimidationRiskLevel >= 2 && i.daysSinceLastWorkout >= 2) {
      return AdaptiveTrainingFocus.comebackSession;
    }
    // 3. Recovery — suppressed or accumulating fatigue
    if (i.recoveryScore < 60 ||
        (i.fatigueTrendLevel >= 2 && i.recoveryScore < 72) ||
        (i.recoveryCollapseRiskLevel >= 1 && i.recoveryScore < 70)) {
      return AdaptiveTrainingFocus.recovery;
    }
    // 4. Overload — prime conditions; requires canShowAdaptiveIncrease
    if (i.canShowAdaptiveIncrease &&
        i.recoveryScore >= 85 &&
        i.momentumLevel >= 2 &&
        !i.highFatigue &&
        i.overreachingRiskLevel <= 1 &&
        i.overloadReadinessLevel >= 3) {
      return AdaptiveTrainingFocus.overload;
    }
    // 5. Strength push — peaking momentum + strength goal; requires canShowAdaptiveIncrease
    if (i.canShowAdaptiveIncrease &&
        i.momentumLevel >= 3 && i.goal == 'strength' && i.recoveryScore >= 72) {
      return AdaptiveTrainingFocus.strengthPush;
    }
    // 6. Hypertrophy push — plateau + muscle gain goal; requires canShowAdaptiveIncrease
    if (i.canShowAdaptiveIncrease &&
        i.plateauRiskLevel >= 2 && i.goal == 'muscle_gain' && i.recoveryScore >= 65) {
      return AdaptiveTrainingFocus.hypertrophyPush;
    }
    // 7. Technical session — moderate recovery zone
    if (i.recoveryScore >= 62 && i.recoveryScore < 78 && i.overreachingRiskLevel <= 1) {
      return AdaptiveTrainingFocus.technicalSession;
    }
    return AdaptiveTrainingFocus.maintain;
  }

  // ── Intensity multiplier ──────────────────────────────────────────────────

  static double _intensityMult(AdaptiveTrainingFocus focus, AdaptiveInput i) =>
      switch (focus) {
        AdaptiveTrainingFocus.overload         => i.disciplineScore >= 70 ? 1.10 : 1.05,
        AdaptiveTrainingFocus.maintain         => 1.0,
        AdaptiveTrainingFocus.recovery         => i.recoveryScore < 50 ? 0.80 : 0.92,
        AdaptiveTrainingFocus.deload           => 0.75,
        AdaptiveTrainingFocus.hypertrophyPush  => 0.95,
        AdaptiveTrainingFocus.strengthPush     => 1.05,
        AdaptiveTrainingFocus.technicalSession => 0.95,
        AdaptiveTrainingFocus.comebackSession  => 0.85,
      };

  // ── Volume multiplier ─────────────────────────────────────────────────────

  static double _volumeMult(AdaptiveTrainingFocus focus, AdaptiveInput i) =>
      switch (focus) {
        AdaptiveTrainingFocus.overload         => 1.05,
        AdaptiveTrainingFocus.maintain         => 1.0,
        AdaptiveTrainingFocus.recovery         => i.recoveryScore < 50 ? 0.65 : 0.80,
        AdaptiveTrainingFocus.deload           => 0.65,
        AdaptiveTrainingFocus.hypertrophyPush  => 1.05,
        AdaptiveTrainingFocus.strengthPush     => 1.0,
        AdaptiveTrainingFocus.technicalSession => 0.90,
        AdaptiveTrainingFocus.comebackSession  => 0.75,
      };

  // ── Exercise swap generation ──────────────────────────────────────────────

  static List<ExerciseSwap> _generateSwaps(AdaptiveInput i) {
    // Skip when conditions are good — no swaps needed
    if (!i.shouldReduceAxialLoad &&
        i.suppressedMuscles.isEmpty &&
        i.recoveryScore >= 70 &&
        !i.highFatigue &&
        i.fatigueTrendLevel < 2) {
      return const [];
    }

    final result = <ExerciseSwap>[];
    for (final name in i.todayExerciseNames) {
      final lower = name.toLowerCase();
      for (final rule in _kSwapRules) {
        if (lower.contains(rule.originalPattern) && rule.trigger(i)) {
          if (!result.any((s) => s.original == name)) {
            result.add(ExerciseSwap(
              original:    name,
              replacement: rule.replacement,
              reason:      rule.reason,
            ));
          }
          break; // one swap per exercise
        }
      }
    }
    return result;
  }

  // ── Conflict detection ────────────────────────────────────────────────────

  /// True when any suppressed muscle overlaps with today's exercise categories.
  /// Compares case-insensitively: 'legs' vs 'Legs', etc.
  static bool _conflictsWithToday(
      List<String> suppressed, List<String> categories) {
    final lowerCats = categories.map((c) => c.toLowerCase()).toSet();
    return suppressed.any((m) => lowerCats.contains(m.toLowerCase()));
  }

  /// Calm confirmation surfaced when recovery conditions don't conflict with
  /// today's planned session. Never shown alongside a warning.
  static String _recoveryAlignedMsg(
      List<String> suppressed, List<String> categories) {
    const legSet   = {'legs', 'quads', 'hamstrings', 'glutes', 'calves'};
    const upperSet = {'chest', 'back', 'shoulders', 'arms'};
    final hasLeg   = suppressed.any(legSet.contains);
    final hasUpper = suppressed.any(upperSet.contains);
    if (hasLeg && !hasUpper) {
      return "Your legs are still recovering — great time to work on upper body today.";
    }
    if (hasUpper && !hasLeg) {
      return "Your upper body is still recovering — today's lower body session gives it time to rest.";
    }
    return "Your body's recovery looks good for today's session.";
  }

  // ── Athlete-facing message ────────────────────────────────────────────────

  static String _athleteFacingMessage(
    AdaptiveTrainingFocus focus,
    AdaptiveInput         i,
    bool                  reduceAxial,
    List<ExerciseSwap>    swaps,
  ) {
    switch (focus) {
      case AdaptiveTrainingFocus.overload:
        return "You're feeling great today — push harder than usual, your body is ready for it.";

      case AdaptiveTrainingFocus.recovery:
        if (i.suppressedMuscles.contains('back') &&
            _conflictsWithToday(['back'], i.todayExerciseCategories)) {
          return "Your back is still recovering — switching to exercises that take pressure off it today.";
        }
        if (i.suppressedMuscles.any(
                (m) => ['legs', 'quads', 'hamstrings', 'glutes'].contains(m)) &&
            _conflictsWithToday(
                ['legs', 'quads', 'hamstrings', 'glutes'], i.todayExerciseCategories)) {
          return "Your legs are still tired — let's work upper body or use machines instead today.";
        }
        // Suppressed muscles don't affect today's session — no false warning.
        if (i.suppressedMuscles.isNotEmpty &&
            !_conflictsWithToday(i.suppressedMuscles, i.todayExerciseCategories)) {
          return '';
        }
        return "Your body needs a bit more time to recover. Stop each set a little early and focus on good form.";

      case AdaptiveTrainingFocus.deload:
        return 'Easy day today — use lighter weights and just focus on moving well.';

      case AdaptiveTrainingFocus.comebackSession:
        return i.daysSinceLastWorkout >= 4
            ? "Great that you're back — just a short session today to get your body moving again. Every session counts."
            : "Just showing up today is a win — even a short workout is enough. Let's do this.";

      case AdaptiveTrainingFocus.hypertrophyPush:
        return "Good time to try doing more reps than usual — your body is ready for a new challenge.";

      case AdaptiveTrainingFocus.strengthPush:
        return "Great day to go heavier than usual — your body is well-rested and ready for it.";

      case AdaptiveTrainingFocus.technicalSession:
        return "You're a bit tired today — focus on doing each rep with good form rather than going heavy.";

      case AdaptiveTrainingFocus.maintain:
        // Only show message if modifications are still needed despite maintain focus
        if (reduceAxial || swaps.isNotEmpty) {
          return "I've adjusted today's session slightly based on how your body is recovering.";
        }
        return '';
    }
  }
}
