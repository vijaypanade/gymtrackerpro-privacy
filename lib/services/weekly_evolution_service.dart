// lib/services/weekly_evolution_service.dart
// Pure Dart — no Flutter imports.
// Aggregates existing intelligence signals into a weekly training phase snapshot.
//
// FOUNDATION RULE: NEVER duplicates calculations from:
//   AdaptiveProgrammingService, PredictiveSnapshot, AthleteMemorySnapshot,
//   AdherenceProfile, RecoveryState, AthleteTrendSnapshot, TrainingAdjustment.
// Input receives all signals as primitive types (int ordinals, doubles, strings).
//
// SAFETY CONTRACT:
//   advisory only — never auto-edits the week plan.
//   language is calm, tactical, coach-like.
//   DO NOT trigger deload from a single bad session.
//   DO NOT use fear-based messaging.
//   One clear recommendation per adjustment — not a list of warnings.

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Training phase at the weekly level — governs load, intensity, and volume posture.
enum WeeklyPhase {
  accumulation,    // building load progressively toward a peak
  overload,        // prime conditions — push compounds and volume
  stabilization,   // neutral — maintain quality without chasing gains
  recovery,        // suppressed recovery — protect tissue, maintain movement
  deload,          // mesocycle reset — technical focus, low load
  rebound,         // returning after absence — gradual re-entry
  intensification, // momentum + recovery aligned — strength/PR focus
}

extension WeeklyPhaseX on WeeklyPhase {
  String get label => switch (this) {
    WeeklyPhase.accumulation    => 'Accumulation',
    WeeklyPhase.overload        => 'Overload Week',
    WeeklyPhase.stabilization   => '',          // neutral — hidden from UI
    WeeklyPhase.recovery        => 'Recovery Week',
    WeeklyPhase.deload          => 'Deload Week',
    WeeklyPhase.rebound         => 'Comeback Phase',
    WeeklyPhase.intensification => 'Intensity Block',
  };

  String get color => switch (this) {
    WeeklyPhase.accumulation    => 'blue',
    WeeklyPhase.overload        => 'green',
    WeeklyPhase.stabilization   => 'muted',
    WeeklyPhase.recovery        => 'gold',
    WeeklyPhase.deload          => 'muted',
    WeeklyPhase.rebound         => 'gold',
    WeeklyPhase.intensification => 'green',
  };
}

// ── Adjustment types ──────────────────────────────────────────────────────────

enum WeeklyAdjustmentType {
  reduceVolume,
  increaseVolume,
  shiftFrequency,
  rotateExercise,
  reduceAxialLoad,
  addRecoveryDay,
  increaseIntensity,
  technicalFocus,
  restoreConsistency,
  reduceHingeLoading,   // leg/back hinge fatigue — swap to hip-dominant or machine
  swapMovement,         // plateau or suppressed muscle — specific exercise rotation
  recoveryEmphasis,     // broad recovery signal — protect momentum, reduce total stress
}

enum AdjustmentPriority { low, moderate, high }

// ── Models ────────────────────────────────────────────────────────────────────

/// Specific, movement-level intervention — more granular than WeeklyAdjustment.
/// Language: calm coaching, never command-style.
class SmartIntervention {
  final WeeklyAdjustmentType type;
  final String message; // one-line athlete-facing coaching message

  const SmartIntervention({required this.type, required this.message});
}

class WeeklyAdjustment {
  final WeeklyAdjustmentType type;
  final String title;
  final String reasoning;
  final AdjustmentPriority priority;
  final String athleteFacingMessage;

  const WeeklyAdjustment({
    required this.type,
    required this.title,
    required this.reasoning,
    required this.priority,
    required this.athleteFacingMessage,
  });
}

class WeeklyEvolutionSnapshot {
  final WeeklyPhase phase;

  /// 0–100 composite readiness this week (recovery + momentum + discipline).
  final double readinessScore;
  /// 0–100 progression velocity index (volume trend + PR rate + movement progress).
  final double progressionScore;
  /// 0–100 accumulated fatigue pressure (fatigue trend + overreaching risk).
  final double fatiguePressure;
  /// 0–100 behavioral stability (discipline − burnout signal).
  final double adherenceStability;

  final bool recommendDeload;
  final bool recommendOverload;
  final bool recommendExerciseRotation;
  final bool recommendFrequencyShift;

  /// Muscles with low training frequency or suppressed recovery.
  final List<String> laggingMuscles;
  /// Exercises or muscle groups showing consistent upward progression.
  final List<String> emergingStrengths;

  /// Prioritised list — sorted HIGH → LOW. At most 4 adjustments.
  final List<WeeklyAdjustment> adjustments;

  /// Movement-level smart interventions — specific coaching for muscle-level issues.
  final List<SmartIntervention> smartInterventions;

  /// Short tactical sentence for the week.
  final String weeklyInsight;
  /// Longer, observational athlete narrative about the training trajectory.
  final String athleteNarrative;

  final DateTime computedAt;

  const WeeklyEvolutionSnapshot({
    required this.phase,
    required this.readinessScore,
    required this.progressionScore,
    required this.fatiguePressure,
    required this.adherenceStability,
    required this.recommendDeload,
    required this.recommendOverload,
    required this.recommendExerciseRotation,
    required this.recommendFrequencyShift,
    required this.laggingMuscles,
    required this.emergingStrengths,
    required this.adjustments,
    required this.smartInterventions,
    required this.weeklyInsight,
    required this.athleteNarrative,
    required this.computedAt,
  });

  static WeeklyEvolutionSnapshot get baseline => WeeklyEvolutionSnapshot(
    phase:                     WeeklyPhase.stabilization,
    readinessScore:            60.0,
    progressionScore:          50.0,
    fatiguePressure:           30.0,
    adherenceStability:        70.0,
    recommendDeload:           false,
    recommendOverload:         false,
    recommendExerciseRotation: false,
    recommendFrequencyShift:   false,
    laggingMuscles:            const [],
    emergingStrengths:         const [],
    adjustments:               const [],
    smartInterventions:        const [],
    weeklyInsight:             '',
    athleteNarrative:          '',
    computedAt:                DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// The highest-priority adjustment (null if adjustments is empty).
  WeeklyAdjustment? get topAdjustment =>
      adjustments.isEmpty ? null : adjustments.first;
}

// ── Input contract ─────────────────────────────────────────────────────────────

class WeeklyEvolutionInput {
  // ── Recovery ─────────────────────────────────────────────────────────────
  final double recoveryScore;        // 0–100
  final bool   highFatigue;
  final bool   needsDeload;
  final bool   shouldReduceAxialLoad;
  final List<String> suppressedMuscles;

  // ── Trend signals (ordinals) ──────────────────────────────────────────────
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
  /// 0–100 behavioral discipline score
  final int    disciplineScore;
  /// 0–1 probability athlete will return if currently absent
  final double comebackProbability;

  // ── Athlete context ───────────────────────────────────────────────────────
  final double weeklyImprovementPct;
  final bool   isOnPlateau;
  final int    daysSinceLastWorkout;
  final int    totalWorkouts;
  final int    recentPRCount;         // PRs logged in last 21 days
  final String goal;

  // ── Athlete memory signals (from AthleteMemorySnapshot) ───────────────────
  final List<String> progressionMovements;
  final List<String> recurringWeakPoints;
  final List<String> favoriteExercises;

  // ── Adaptive session decision (from AdaptiveWorkoutDecision) ─────────────
  /// AdaptiveTrainingFocus.index
  final int adaptiveFocusIndex;

  final DateTime now;

  const WeeklyEvolutionInput({
    required this.recoveryScore,
    required this.highFatigue,
    required this.needsDeload,
    required this.shouldReduceAxialLoad,
    required this.suppressedMuscles,
    required this.momentumLevel,
    required this.overreachingRiskLevel,
    required this.plateauRiskLevel,
    required this.fatigueTrendLevel,
    required this.overloadReadinessLevel,
    required this.recoveryCollapseRiskLevel,
    required this.burnoutRiskLevel,
    required this.disciplineScore,
    required this.comebackProbability,
    required this.weeklyImprovementPct,
    required this.isOnPlateau,
    required this.daysSinceLastWorkout,
    required this.totalWorkouts,
    required this.recentPRCount,
    required this.goal,
    required this.progressionMovements,
    required this.recurringWeakPoints,
    required this.favoriteExercises,
    required this.adaptiveFocusIndex,
    required this.now,
  });
}

// ── Exercise rotation table ───────────────────────────────────────────────────

const Map<String, String> _kRotations = {
  'bench press':             'Incline Dumbbell Press',
  'incline bench press':     'Low-to-High Cable Fly',
  'barbell row':             'Chest Supported Row',
  'lat pulldown':            'Neutral-Grip Pulldown',
  'pull up':                 'Lat Pulldown',
  'deadlift':                'Romanian Deadlift',
  'romanian deadlift':       'Leg Curl',
  'squat':                   'Hack Squat or Bulgarian Split Squat',
  'overhead press':          'Dumbbell Shoulder Press',
  'barbell curl':            'Hammer Curl',
  'dumbbell curl':           'Incline Dumbbell Curl',
  'tricep pushdown':         'Overhead Tricep Extension',
};

// ── Service ───────────────────────────────────────────────────────────────────

class WeeklyEvolutionService {
  WeeklyEvolutionService._();

  /// Minimum sessions before weekly evolution generates meaningful output.
  static const int _minSessions = 5;

  static WeeklyEvolutionSnapshot compute(WeeklyEvolutionInput i) {
    if (i.totalWorkouts < _minSessions) return WeeklyEvolutionSnapshot.baseline;

    // ── 1. Composite scores ───────────────────────────────────────────────
    final readiness  = _readinessScore(i);
    final progression = _progressionScore(i);
    final fatigue    = _fatiguePressure(i);
    final adherence  = _adherenceStability(i);

    // ── 2. Phase detection ────────────────────────────────────────────────
    final phase = _detectPhase(i, readiness, fatigue);

    // ── 3. Lagging muscles ────────────────────────────────────────────────
    final lagging = <String>{
      ...i.suppressedMuscles,
      ...i.recurringWeakPoints,
    }.take(3).toList();

    // ── 4. Emerging strengths ─────────────────────────────────────────────
    final emerging = i.progressionMovements.take(3).toList();

    // ── 5. Recommendations ────────────────────────────────────────────────
    final recDeload   = i.needsDeload ||
        (i.recoveryCollapseRiskLevel >= 2 && fatigue >= 70) ||
        (i.plateauRiskLevel >= 2 && i.isOnPlateau && fatigue >= 65);

    final recOverload = !recDeload &&
        readiness >= 80 &&
        i.overloadReadinessLevel >= 3 &&
        i.momentumLevel >= 2 &&
        fatigue < 40;

    final recRotation = i.isOnPlateau &&
        i.plateauRiskLevel >= 2 &&
        i.favoriteExercises.isNotEmpty;

    final recFreqShift = lagging.isNotEmpty && !recDeload;

    // ── 6. Adjustment list ────────────────────────────────────────────────
    final adjustments = _buildAdjustments(i, phase, lagging, recOverload);

    // ── 7. Smart interventions ────────────────────────────────────────────
    final smartInterventions = _buildSmartInterventions(i, phase, lagging);

    // ── 8. Narrative + insight ────────────────────────────────────────────
    final narrative = _buildNarrative(
        phase, i, lagging, emerging, progression, fatigue);
    final insight   = _buildInsight(phase, i, lagging);

    return WeeklyEvolutionSnapshot(
      phase:                     phase,
      readinessScore:            readiness,
      progressionScore:          progression,
      fatiguePressure:           fatigue,
      adherenceStability:        adherence,
      recommendDeload:           recDeload,
      recommendOverload:         recOverload,
      recommendExerciseRotation: recRotation,
      recommendFrequencyShift:   recFreqShift,
      laggingMuscles:            lagging,
      emergingStrengths:         emerging,
      adjustments:               adjustments,
      smartInterventions:        smartInterventions,
      weeklyInsight:             insight,
      athleteNarrative:          narrative,
      computedAt:                i.now,
    );
  }

  // ── Score calculators ─────────────────────────────────────────────────────

  static double _readinessScore(WeeklyEvolutionInput i) {
    final r = (i.recoveryScore * 0.45) +
        ((i.momentumLevel / 3.0) * 100 * 0.30) +
        (i.disciplineScore * 0.25);
    return r.clamp(0.0, 100.0);
  }

  static double _progressionScore(WeeklyEvolutionInput i) {
    // Normalize weekly improvement: 0% maps to 50, ±30% = full range
    final base = ((i.weeklyImprovementPct + 30) / 60.0 * 100).clamp(0.0, 100.0);
    // Boost from progression movements (each adds 5, max +20)
    final boost = (i.progressionMovements.length * 5).clamp(0, 20).toDouble();
    // PR bonus
    final prBonus = (i.recentPRCount * 4).clamp(0, 16).toDouble();
    return (base + boost + prBonus).clamp(0.0, 100.0);
  }

  static double _fatiguePressure(WeeklyEvolutionInput i) {
    final recoveryComponent  = ((100 - i.recoveryScore) * 0.40);
    final fatigueTrendComp   = (i.fatigueTrendLevel * 15.0);
    final overreachingComp   = (i.overreachingRiskLevel * 12.0);
    final collapseComp       = (i.recoveryCollapseRiskLevel * 8.0);
    return (recoveryComponent + fatigueTrendComp + overreachingComp + collapseComp)
        .clamp(0.0, 100.0);
  }

  static double _adherenceStability(WeeklyEvolutionInput i) {
    final burnoutPenalty = i.burnoutRiskLevel * 18.0;
    final base = (i.disciplineScore * 0.65) +
        ((3 - i.burnoutRiskLevel) / 3.0 * 100 * 0.35);
    return (base - burnoutPenalty).clamp(0.0, 100.0);
  }

  // ── Phase detection ───────────────────────────────────────────────────────

  static WeeklyPhase _detectPhase(
    WeeklyEvolutionInput i,
    double readiness,
    double fatigue,
  ) {
    // 1. Deload: accumulated multi-session fatigue signals
    if (i.needsDeload ||
        (i.recoveryCollapseRiskLevel >= 2 && fatigue >= 65) ||
        (i.overreachingRiskLevel >= 3)) {
      return WeeklyPhase.deload;
    }
    // 2. Rebound: returning after absence
    if (i.daysSinceLastWorkout >= 5 && i.comebackProbability >= 0.50) {
      return WeeklyPhase.rebound;
    }
    // 3. Recovery: suppressed recovery or high fatigue trend
    if (i.recoveryScore < 58 ||
        (i.fatigueTrendLevel >= 2 && i.recoveryScore < 72)) {
      return WeeklyPhase.recovery;
    }
    // 4. Overload: prime conditions across all signals
    if (readiness >= 82 &&
        i.overloadReadinessLevel >= 3 &&
        i.momentumLevel >= 2 &&
        !i.highFatigue &&
        fatigue < 35 &&
        i.overreachingRiskLevel <= 1) {
      return WeeklyPhase.overload;
    }
    // 5. Intensification: momentum + strength-goal alignment
    if (i.momentumLevel >= 3 &&
        i.goal == 'strength' &&
        i.recoveryScore >= 72 &&
        i.disciplineScore >= 65) {
      return WeeklyPhase.intensification;
    }
    // 6. Accumulation: stable, building upward
    if (readiness >= 62 && fatigue < 55 && i.weeklyImprovementPct >= -5) {
      return WeeklyPhase.accumulation;
    }
    return WeeklyPhase.stabilization;
  }

  // ── Adjustment builder ────────────────────────────────────────────────────

  static List<WeeklyAdjustment> _buildAdjustments(
    WeeklyEvolutionInput     i,
    WeeklyPhase              phase,
    List<String>             lagging,
    bool                     recOverload,
  ) {
    final list = <WeeklyAdjustment>[];

    // ── HIGH priority: safety & recovery ────────────────────────────────
    if (i.overreachingRiskLevel >= 2 || phase == WeeklyPhase.deload) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.reduceVolume,
        title: 'Reduce Weekly Volume',
        reasoning: 'Overreaching signals indicate recovery cannot keep pace with training load.',
        priority: AdjustmentPriority.high,
        athleteFacingMessage: 'Scale back total sets this week — your body needs space to recover before it can grow.',
      ));
    }

    if (i.recoveryCollapseRiskLevel >= 2 || i.needsDeload) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.addRecoveryDay,
        title: 'Add Recovery Day',
        reasoning: 'Recovery collapse risk is elevated — an extra rest day prevents regression.',
        priority: AdjustmentPriority.high,
        athleteFacingMessage: 'Swap one training day for a walk or rest this week — recovery is part of the process.',
      ));
    }

    if (i.burnoutRiskLevel >= 2) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.restoreConsistency,
        title: 'Simplify Sessions',
        reasoning: 'Burnout risk is elevated — session complexity reduction protects long-term adherence.',
        priority: AdjustmentPriority.high,
        athleteFacingMessage: 'Shorter, simpler sessions this week. Showing up is the work — volume can wait.',
      ));
    }

    // ── MODERATE priority: optimization ──────────────────────────────────
    if (i.shouldReduceAxialLoad || i.suppressedMuscles.contains('back')) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.reduceAxialLoad,
        title: 'Shift to Supported Pull Movements',
        reasoning: 'Axial load pressure is elevated — chest-supported variations protect the posterior chain.',
        priority: AdjustmentPriority.moderate,
        athleteFacingMessage: 'Swap bent-over rows for chest-supported or cable variations through the week.',
      ));
    }

    if (i.isOnPlateau && i.plateauRiskLevel >= 2) {
      list.add(WeeklyAdjustment(
        type: WeeklyAdjustmentType.rotateExercise,
        title: 'Rotate Primary Movements',
        reasoning: 'Plateau probability is elevated — exercise variation restores progression stimulus.',
        priority: AdjustmentPriority.moderate,
        athleteFacingMessage: _rotationMessage(i.favoriteExercises),
      ));
    }

    if (lagging.isNotEmpty) {
      final muscle = _capitalize(lagging.first);
      list.add(WeeklyAdjustment(
        type: WeeklyAdjustmentType.shiftFrequency,
        title: 'Increase $muscle Frequency',
        reasoning: '$muscle is undertrained relative to other muscle groups this week.',
        priority: AdjustmentPriority.moderate,
        athleteFacingMessage: 'Add a secondary $muscle stimulus — even one extra set per session shifts the balance.',
      ));
    }

    if (i.fatigueTrendLevel >= 2 && phase == WeeklyPhase.recovery) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.technicalFocus,
        title: 'Prioritize Movement Quality',
        reasoning: 'Fatigue trend is elevated — technical focus reduces injury risk and builds robustness.',
        priority: AdjustmentPriority.moderate,
        athleteFacingMessage: 'Leave 2–3 reps in reserve this week. Controlled technique protects you more than max effort right now.',
      ));
    }

    // ── LOW priority: growth opportunities ───────────────────────────────
    if (recOverload || phase == WeeklyPhase.overload) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.increaseVolume,
        title: 'Capitalize on Overload Window',
        reasoning: 'Prime readiness conditions — a moderate volume increase accelerates adaptation.',
        priority: AdjustmentPriority.low,
        athleteFacingMessage: 'Your body is ready for more. Add one extra working set to your main exercises this week.',
      ));
    }

    if (phase == WeeklyPhase.intensification || phase == WeeklyPhase.overload) {
      list.add(const WeeklyAdjustment(
        type: WeeklyAdjustmentType.increaseIntensity,
        title: 'Push Compound Loads',
        reasoning: 'Momentum and recovery alignment supports heavier working sets.',
        priority: AdjustmentPriority.low,
        athleteFacingMessage: 'Good conditions to push compound lifts heavier — aim for 2–3 sets above your usual working weight.',
      ));
    }

    // Sort HIGH → MODERATE → LOW, deduplicate by type
    list.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    final seen = <WeeklyAdjustmentType>{};
    final deduped = list.where((a) => seen.add(a.type)).take(4).toList();
    return deduped;
  }

  // ── Narrative builder ──────────────────────────────────────────────────────

  static String _buildNarrative(
    WeeklyPhase          phase,
    WeeklyEvolutionInput i,
    List<String>         lagging,
    List<String>         emerging,
    double               progression,
    double               fatigue,
  ) {
    // Base phase narrative
    final base = switch (phase) {
      WeeklyPhase.accumulation =>
          'Training load is building progressively — your body is adapting to increasing stimulus.',
      WeeklyPhase.overload =>
          'Recovery and progression trends support a higher-output training week.',
      WeeklyPhase.stabilization =>
          'Training rhythm is stable. Maintain quality and let adaptation consolidate.',
      WeeklyPhase.recovery =>
          'Recovery is the priority this week — movement quality over maximal load.',
      WeeklyPhase.deload =>
          'This week should prioritize recovery capacity over progression pressure.',
      WeeklyPhase.rebound =>
          'Momentum is rebuilding steadily — this week sets the foundation for the next block.',
      WeeklyPhase.intensification =>
          'Momentum and recovery are aligned for compound strength focus this week.',
    };

    // Modifier: lagging muscle
    String modifier = '';
    if (lagging.isNotEmpty && !i.needsDeload) {
      final m = _capitalize(lagging.first);
      modifier = ' $m progression has slowed relative to other groups — a secondary stimulus this week would help.';
    } else if (emerging.isNotEmpty && phase == WeeklyPhase.overload) {
      modifier = ' ${emerging.first} momentum is particularly strong — prioritize it on well-recovered days.';
    } else if (i.isOnPlateau && i.plateauRiskLevel >= 2 && phase != WeeklyPhase.deload) {
      modifier = ' Consider rotating primary movement variations to restore progression stimulus.';
    }

    return base + modifier;
  }

  static String _buildInsight(
    WeeklyPhase          phase,
    WeeklyEvolutionInput i,
    List<String>         lagging,
  ) {
    if (phase == WeeklyPhase.deload) {
      return 'Reduce load to 60–70% this week and focus on movement mechanics.';
    }
    if (phase == WeeklyPhase.overload || phase == WeeklyPhase.intensification) {
      return 'Push compound loads on well-recovered days — this week is built for it.';
    }
    if (phase == WeeklyPhase.recovery) {
      return 'Leave 2 reps in reserve on all working sets and skip failure sets this week.';
    }
    if (phase == WeeklyPhase.rebound) {
      return 'Start at 70–80% of previous loads and rebuild momentum gradually.';
    }
    if (lagging.isNotEmpty) {
      return '${_capitalize(lagging.first)} is undertrained — add one extra set per session this week.';
    }
    return 'Consistent effort this week compounds into long-term progression.';
  }

  // ── Smart interventions ───────────────────────────────────────────────────

  static List<SmartIntervention> _buildSmartInterventions(
    WeeklyEvolutionInput i,
    WeeklyPhase          phase,
    List<String>         lagging,
  ) {
    final list = <SmartIntervention>[];

    // Hinge load reduction — leg/back suppression signals
    if (i.suppressedMuscles.contains('legs') || i.suppressedMuscles.contains('back')) {
      final muscle = i.suppressedMuscles.contains('legs') ? 'Leg' : 'Back';
      list.add(SmartIntervention(
        type:    WeeklyAdjustmentType.reduceHingeLoading,
        message: '$muscle demand is elevated. Hip-dominant or machine variations reduce spinal load today.',
      ));
    }

    // Axial load — back recovery
    if (i.shouldReduceAxialLoad) {
      list.add(const SmartIntervention(
        type:    WeeklyAdjustmentType.swapMovement,
        message: 'Swap heavy rows for chest-supported or cable variations to protect posterior-chain recovery.',
      ));
    }

    // Recovery emphasis — broad fatigue
    if (i.highFatigue && i.recoveryScore < 55 && phase == WeeklyPhase.recovery) {
      list.add(const SmartIntervention(
        type:    WeeklyAdjustmentType.recoveryEmphasis,
        message: 'A lower-intensity session today preserves momentum while recovery continues.',
      ));
    }

    // Volume accumulating faster than recovery
    if (i.overreachingRiskLevel >= 2 && i.fatigueTrendLevel >= 2) {
      list.add(const SmartIntervention(
        type:    WeeklyAdjustmentType.recoveryEmphasis,
        message: 'Volume is accumulating faster than recovery. Fewer sets, higher quality is the approach this week.',
      ));
    }

    // Dedup by type and cap at 3
    final seen = <WeeklyAdjustmentType>{};
    return list.where((s) => seen.add(s.type)).take(3).toList();
  }

  // ── Rotation message ──────────────────────────────────────────────────────

  static String _rotationMessage(List<String> favorites) {
    for (final fav in favorites) {
      final lower = fav.toLowerCase();
      for (final entry in _kRotations.entries) {
        if (lower.contains(entry.key)) {
          return 'Try ${entry.value} as a variation for ${_capitalize(fav)} this week.';
        }
      }
    }
    return 'Rotate to a variation of your primary movement pattern to unlock new adaptation.';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
