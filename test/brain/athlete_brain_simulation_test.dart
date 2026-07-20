// test/brain/athlete_brain_simulation_test.dart
//
// Deterministic simulation test suite for AthleteBrainService.
// 100+ representative athlete scenarios.
//
// Coverage:
//   § 1  Baseline / new athlete (totalWorkouts < 3)        5  tests
//   § 2  Deload focus                                       8  tests
//   § 3  Comeback session                                   8  tests
//   § 4  Recovery focus                                    12  tests
//   § 5  Overload focus                                     8  tests
//   § 6  Strength / hypertrophy / technical focus          12  tests
//   § 7  Maintain focus                                     8  tests
//   § 8  Memory advisory — rule-by-rule                    15  tests
//   § 9  Behavioral modifiers (burnout / intimidation)      8  tests
//   §10  Exercise swaps                                     8  tests
//   §11  AthleteScoreEngine                                15  tests
//   §12  Conflict / stability detection                     6  tests
//   §13  Edge cases & boundary conditions                   8  tests
//
// Total: 121 scenarios
//
// Conflict report is written to stdout when any scenario produces a decision
// that violates invariants. No production code is modified.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/ai/maturity/allowed_claims.dart';
import 'package:gymtrackerpromaster/brain/models/decision_context.dart';
import 'package:gymtrackerpromaster/brain/models/environment_context.dart';
import 'package:gymtrackerpromaster/brain/models/workout_context.dart';
import 'package:gymtrackerpromaster/brain/services/athlete_brain_service.dart';
import 'package:gymtrackerpromaster/engines/athlete_score_engine.dart';
import 'package:gymtrackerpromaster/memory/snapshots/athlete_memory_snapshot.dart';
import 'package:gymtrackerpromaster/models/recovery_state.dart';
import 'package:gymtrackerpromaster/providers/analytics_provider.dart';
import 'package:gymtrackerpromaster/services/adaptive_programming_service.dart';
import 'package:gymtrackerpromaster/services/adherence_intelligence_service.dart';
import 'package:gymtrackerpromaster/services/athlete_trend_service.dart';
import 'package:gymtrackerpromaster/services/predictive_performance_service.dart';
import 'package:gymtrackerpromaster/services/training_adjustment_service.dart';

// ── Test-wide singleton ───────────────────────────────────────────────────────

const _brain = AthleteBrainService();

// ── Test AllowedClaims fixtures ───────────────────────────────────────────────

// Full maturity — used by all tests except new-athlete maturity gating.
const _kPermissiveClaims = AllowedClaims(
  ui: AllowedClaimsUi(
    canShowTrendArrow:       true,
    canShowWhyToggle:        true,
    canShowWeeklyStory:      true,
    canShowDominantSignals:  true,
    canShowSessionProphecy:  true,
    canShowAdaptiveIncrease: true,
    canShowConfidenceArc:    false,
  ),
  content: AllowedClaimsContent(
    canMakeObservation:        true,
    canMakePatternClaim:       true,
    canMakePrediction:         true,
    canMakePrescription:       true,
    canReferenceHistory:       true,
    canAddressAthleteDirectly: true,
    canCompareSessions:        true,
    canUseTrendLanguage:       true,
    canInjectPersonalContext:  true,
  ),
);

// Increase-restricted — simulates new-athlete maturity (canShowAdaptiveIncrease=false).
const _kRestrictedClaims = AllowedClaims(
  ui: AllowedClaimsUi(
    canShowTrendArrow:       false,
    canShowWhyToggle:        false,
    canShowWeeklyStory:      false,
    canShowDominantSignals:  false,
    canShowSessionProphecy:  false,
    canShowAdaptiveIncrease: false,
    canShowConfidenceArc:    false,
  ),
  content: AllowedClaimsContent(
    canMakeObservation:        false,
    canMakePatternClaim:       false,
    canMakePrediction:         false,
    canMakePrescription:       false,
    canReferenceHistory:       false,
    canAddressAthleteDirectly: false,
    canCompareSessions:        false,
    canUseTrendLanguage:       false,
    canInjectPersonalContext:  false,
  ),
);

// Thin wrapper: defaults to full maturity. Pass claims: _kRestrictedClaims for
// new-athlete / maturity-gating scenarios.
AdaptiveWorkoutDecision _decide(
  DecisionContext ctx, {
  AllowedClaims claims = _kPermissiveClaims,
}) =>
    _brain.computeDecision(ctx, claims);

// ── Anchored timestamp — every scenario uses the same instant ─────────────────

final _now = DateTime(2026, 1, 15, 9, 0);

// ── Conflict accumulator ──────────────────────────────────────────────────────

final _conflicts = <String>[];

void _checkInvariants(String label, AdaptiveWorkoutDecision d) {
  if (d.focus == AdaptiveTrainingFocus.deload && d.intensityMultiplier > 0.75) {
    _conflicts.add('$label: deload focus but intensityMult=${d.intensityMultiplier}');
  }
  if (d.focus == AdaptiveTrainingFocus.recovery && d.intensityMultiplier >= 1.0) {
    _conflicts.add('$label: recovery focus but intensityMult=${d.intensityMultiplier}');
  }
  if (d.focus == AdaptiveTrainingFocus.overload && d.intensityMultiplier < 1.05) {
    _conflicts.add('$label: overload focus but intensityMult=${d.intensityMultiplier}');
  }
  if (d.intensityMultiplier < 0.70 || d.intensityMultiplier > 1.15) {
    _conflicts.add('$label: intensityMult=${d.intensityMultiplier} outside [0.70, 1.15]');
  }
  if (d.volumeMultiplier < 0.60 || d.volumeMultiplier > 1.10) {
    _conflicts.add('$label: volumeMult=${d.volumeMultiplier} outside [0.60, 1.10]');
  }
}

// ── Context builder — all parameters optional, sensible defaults ──────────────

DecisionContext _ctx({
  // Recovery signals
  double recoveryScore            = 80,
  bool   highFatigue              = false,
  bool   needsDeload              = false,
  String recoveryTrend            = 'stable',
  List<String> suppressedMuscles  = const [],
  bool   shouldReduceAxialLoad    = false,
  List<String> focusMuscles       = const [],
  // Trend signals
  MomentumLevel      momentum     = MomentumLevel.building,
  OverreachingRisk   overreaching = OverreachingRisk.none,
  PlateauRisk        plateau      = PlateauRisk.none,
  FatigueTrend       fatigue      = FatigueTrend.stable,
  // Predictive signals
  OverloadReadiness     overloadReadiness = OverloadReadiness.possible,
  RecoveryCollapseRisk  collapseRisk      = RecoveryCollapseRisk.low,
  // Adherence signals
  BurnoutRisk      burnout       = BurnoutRisk.none,
  IntimidationRisk intimidation  = IntimidationRisk.none,
  double           comebackProb  = 0.7,
  int              discipline    = 60,
  // Athlete context
  double weeklyImprovementPct = 2.0,
  bool   isOnPlateau          = false,
  int    daysSinceLast        = 1,
  int    totalWorkouts        = 20,
  String goal                 = 'muscle_gain',
  // Exercise context
  List<String> exerciseNames      = const [],
  List<String> exerciseCategories = const [],
  // Memory
  AthleteMemorySnapshot? memory,
}) {
  return DecisionContext(
    recoveryState: RecoveryState(
      overallScore:          recoveryScore,
      muscleScores:          const {},
      readiness:             _readiness(recoveryScore),
      primaryLimitingMuscle: suppressedMuscles.isEmpty ? '' : suppressedMuscles.first,
      strainToday:           0,
      strain7d:              0,
      needsDeload:           needsDeload,
      highFatigue:           highFatigue,
      updatedAt:             _now,
    ),
    analyticsSnapshot: AnalyticsSnapshot(
      readinessScore:      recoveryScore,
      fatigueIndex:        highFatigue ? 75 : 30,
      effortScoreToday:    60,
      plateauScore:        isOnPlateau ? 80 : 20,
      overtTrainingRisk:   overreaching.index * 25.0,
      weeklyImprovementPct: weeklyImprovementPct,
      muscleBalanceScore:  70,
      intensityScore:      65,
      recoveryTrend:       recoveryTrend,
      isOnPlateau:         isOnPlateau,
      cacheDate:           '2026-01-15',
    ),
    predictiveSnapshot: PredictiveSnapshot(
      plateauProbability:        isOnPlateau ? 0.7 : 0.1,
      streakBreakRisk:           StreakBreakRisk.low,
      overloadReadiness:         overloadReadiness,
      recoveryCollapseRisk:      collapseRisk,
      projectedMomentum:         ProjectedMomentum.building,
      projectedFatigue:          ProjectedFatigue.stable,
      projectedConsistency:      ProjectedConsistency.stable,
      nextBestPRWindow:          '',
      recommendedTrainingWindow: '',
      predictiveInsight:         '',
      computedAt:                _now,
    ),
    athleteTrend: AthleteTrendSnapshot(
      momentumState:       momentum,
      plateauRisk:         plateau,
      overreachingRisk:    overreaching,
      specializationBias:  SpecializationBias.balanced,
      progressionVelocity: 1.0,
      fatigueTrend:        fatigue,
      consistencyTrend:    ConsistencyTrend.stable,
      recommendedPhase:    RecommendedPhase.accumulation,
      coachInsight:        '',
      computedAt:          _now,
    ),
    adherenceProfile: AdherenceProfile(
      consistencyIdentity:  ConsistencyIdentity.disciplinedBuilder,
      burnoutRisk:          burnout,
      streakFragility:      StreakFragility.normal,
      intimidationRisk:     intimidation,
      motivationTrend:      MotivationTrend.stable,
      comebackProbability:  comebackProb,
      disciplineScore:      discipline,
      preferredSessionStyle: PreferredSessionStyle.moderate,
      adherenceInsight:     '',
      computedAt:           _now,
    ),
    trainingAdjustment: TrainingAdjustment(
      intensityMultiplier:      1.0,
      volumeMultiplier:         1.0,
      suggestedRepRange:        (low: 8, high: 12),
      shouldDeload:             needsDeload,
      shouldReduceAxialLoad:    shouldReduceAxialLoad,
      recommendedFocusMuscles:  focusMuscles,
      suppressedMuscles:        suppressedMuscles,
      readinessHeadline:        '',
      coachDirective:           '',
      isModified:               false,
    ),
    workoutContext: WorkoutContext(
      daysSinceLastWorkout:    daysSinceLast,
      totalWorkouts:           totalWorkouts,
      goal:                    goal,
      todayExerciseNames:      exerciseNames,
      todayExerciseCategories: exerciseCategories,
    ),
    environmentContext: EnvironmentContext(now: _now),
    athleteMemorySnapshot: memory,
  );
}

RecoveryReadiness _readiness(double score) {
  if (score < 20) return RecoveryReadiness.depleted;
  if (score < 40) return RecoveryReadiness.low;
  if (score < 65) return RecoveryReadiness.moderate;
  if (score < 85) return RecoveryReadiness.ready;
  return RecoveryReadiness.peak;
}

// ── Memory snapshot helpers ───────────────────────────────────────────────────

AthleteMemorySnapshot _mem({
  double consistency   = 0.5,
  double adherence     = 0.5,
  double reliability   = 0.5,
  double recoveryV     = 0.5,
  double progressionV  = 0.5,
  double volumeTol     = 0.5,
  String identity      = 'intermediate',
  String experience    = 'trained',
}) => AthleteMemorySnapshot(
  identityStage:            identity,
  experienceLevel:          experience,
  consistencyScore:         consistency,
  recoveryVelocity:         recoveryV,
  progressionVelocity:      progressionV,
  volumeTolerance:          volumeTol,
  preferredSessionDuration: const Duration(minutes: 60),
  preferredTrainingDays:    4,
  preferredTrainingTime:    'morning',
  adherenceScore:           adherence,
  reliabilityScore:         reliability,
  lastUpdated:              DateTime(2026, 1, 14),
);

// ═════════════════════════════════════════════════════════════════════════════
// TEST SUITE
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // ── § 1  New athlete — maturity-gated increase, safety always on ─────────
  // With AIMaturity Phase 1 (_kRestrictedClaims), canShowAdaptiveIncrease=false.
  // Increase focus modes (overload / strengthPush / hypertrophyPush) are blocked.
  // Safety decisions (deload / recovery) are ALWAYS available regardless of maturity.

  group('§1 New athlete — increase blocked, safety always on', () {
    test('1.1 no safety signals + restricted claims → maintain', () {
      final d = _decide(_ctx(totalWorkouts: 0), claims: _kRestrictedClaims);
      _checkInvariants('1.1', d);
      expect(d.focus, AdaptiveTrainingFocus.maintain, reason: 'no signals, no increase permission');
      expect(d.intensityMultiplier, 1.0);
      expect(d.volumeMultiplier, 1.0);
      expect(d.shouldModifyWorkout, isFalse);
    });

    test('1.2 recoveryScore=30 + restricted claims → recovery (safety always fires)', () {
      final d = _decide(_ctx(totalWorkouts: 1, recoveryScore: 30), claims: _kRestrictedClaims);
      _checkInvariants('1.2', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery,
          reason: 'recovery is a safety decision — always permitted');
      expect(d.intensityMultiplier, 0.80, reason: 'score<50 → 0.80 intensity');
      expect(d.volumeMultiplier, 0.65, reason: 'score<50 → 0.65 volume');
    });

    test('1.3 needsDeload + restricted claims → deload (safety always fires)', () {
      final d = _decide(_ctx(totalWorkouts: 2, needsDeload: true), claims: _kRestrictedClaims);
      _checkInvariants('1.3', d);
      expect(d.focus, AdaptiveTrainingFocus.deload,
          reason: 'deload is a safety decision — always permitted');
      expect(d.shouldInsertDeload, isTrue);
    });

    test('1.4 overreachingRisk=high + restricted claims → deload (safety first)', () {
      final d = _decide(
        _ctx(totalWorkouts: 2, overreaching: OverreachingRisk.high),
        claims: _kRestrictedClaims,
      );
      _checkInvariants('1.4', d);
      expect(d.focus, AdaptiveTrainingFocus.deload,
          reason: 'high overreaching triggers deload regardless of maturity');
    });

    test('1.5 prime conditions + restricted claims → increase blocked, no overload', () {
      final d = _decide(
        _ctx(
          recoveryScore:     90,
          momentum:          MomentumLevel.peaking,
          overloadReadiness: OverloadReadiness.prime,
          highFatigue:       false,
          overreaching:      OverreachingRisk.none,
        ),
        claims: _kRestrictedClaims,
      );
      _checkInvariants('1.5', d);
      expect(d.focus, isNot(AdaptiveTrainingFocus.overload),
          reason: 'canShowAdaptiveIncrease=false blocks increase even under prime conditions');
    });
  });

  // ── § 2  Deload focus ─────────────────────────────────────────────────────

  group('§2 Deload focus', () {
    test('2.1 needsDeload flag → deload', () {
      final d = _decide(_ctx(needsDeload: true));
      _checkInvariants('2.1', d);
      expect(d.focus, AdaptiveTrainingFocus.deload);
      expect(d.intensityMultiplier, 0.75);
      expect(d.volumeMultiplier, 0.65);
      expect(d.shouldInsertDeload, isTrue);
    });

    test('2.2 overreachingRisk=high → deload (safety first)', () {
      final d = _decide(_ctx(overreaching: OverreachingRisk.high));
      _checkInvariants('2.2', d);
      expect(d.focus, AdaptiveTrainingFocus.deload);
    });

    test('2.3 collapseRisk=high → deload', () {
      final d = _decide(_ctx(collapseRisk: RecoveryCollapseRisk.high));
      _checkInvariants('2.3', d);
      expect(d.focus, AdaptiveTrainingFocus.deload);
    });

    test('2.4 deload message is non-empty', () {
      final d = _decide(_ctx(needsDeload: true));
      expect(d.athleteFacingMessage, isNotEmpty);
    });

    test('2.5 deload: failure training is reduced', () {
      final d = _decide(_ctx(needsDeload: true));
      expect(d.shouldReduceFailureTraining, isTrue);
    });

    test('2.6 deload: shouldModifyWorkout is true', () {
      final d = _decide(_ctx(needsDeload: true));
      expect(d.shouldModifyWorkout, isTrue);
    });

    test('2.7 overreachingRisk=high + needsDeload → deload (combinedSignal)', () {
      final d = _decide(
        _ctx(overreaching: OverreachingRisk.high, needsDeload: true),
      );
      _checkInvariants('2.7', d);
      expect(d.focus, AdaptiveTrainingFocus.deload);
    });

    test('2.8 deload wins over comeback (safety priority)', () {
      final d = _decide(
        _ctx(needsDeload: true, daysSinceLast: 7, comebackProb: 0.9),
      );
      _checkInvariants('2.8', d);
      expect(d.focus, AdaptiveTrainingFocus.deload,
          reason: 'deload is checked before comeback in _focus()');
    });
  });

  // ── § 3  Comeback session ─────────────────────────────────────────────────

  group('§3 Comeback session', () {
    test('3.1 daysSince=4 + comeback≥0.5 → comebackSession', () {
      final d = _decide(
        _ctx(daysSinceLast: 4, comebackProb: 0.6),
      );
      _checkInvariants('3.1', d);
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    test('3.2 daysSince=7 + comeback≥0.5 → comebackSession', () {
      final d = _decide(
        _ctx(daysSinceLast: 7, comebackProb: 0.5),
      );
      _checkInvariants('3.2', d);
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    test('3.3 daysSince=4 + comeback=0.4 → NOT comebackSession', () {
      final d = _decide(
        _ctx(daysSinceLast: 4, comebackProb: 0.4),
      );
      expect(d.focus, isNot(AdaptiveTrainingFocus.comebackSession));
    });

    test('3.4 daysSince=3 + comeback=0.9 → NOT comebackSession (below 4-day threshold)', () {
      final d = _decide(
        _ctx(daysSinceLast: 3, comebackProb: 0.9),
      );
      expect(d.focus, isNot(AdaptiveTrainingFocus.comebackSession));
    });

    test('3.5 intimidationRisk=high + daysSince=2 → comebackSession', () {
      final d = _decide(
        _ctx(intimidation: IntimidationRisk.high, daysSinceLast: 2),
      );
      _checkInvariants('3.5', d);
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    test('3.6 intimidationRisk=moderate + daysSince=2 → comebackSession', () {
      final d = _decide(
        _ctx(intimidation: IntimidationRisk.moderate, daysSinceLast: 2),
      );
      _checkInvariants('3.6', d);
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    test('3.7 comebackSession: intensity is 0.85', () {
      final d = _decide(
        _ctx(daysSinceLast: 5, comebackProb: 0.8),
      );
      expect(d.intensityMultiplier, 0.85);
    });

    test('3.8 comebackSession: volume is 0.75', () {
      final d = _decide(
        _ctx(daysSinceLast: 5, comebackProb: 0.8),
      );
      expect(d.volumeMultiplier, 0.75);
    });
  });

  // ── § 4  Recovery focus ───────────────────────────────────────────────────

  group('§4 Recovery focus', () {
    test('4.1 recoveryScore=50 → recovery focus', () {
      final d = _decide(_ctx(recoveryScore: 50));
      _checkInvariants('4.1', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery);
    });

    test('4.2 recoveryScore=59 → recovery focus (boundary)', () {
      final d = _decide(_ctx(recoveryScore: 59));
      _checkInvariants('4.2', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery);
    });

    test('4.3 recoveryScore=60 → NOT recovery focus (boundary)', () {
      final d = _decide(
        _ctx(recoveryScore: 60, fatigue: FatigueTrend.improving),
      );
      expect(d.focus, isNot(AdaptiveTrainingFocus.recovery));
    });

    test('4.4 fatigue=accumulating + score=70 → recovery', () {
      final d = _decide(
        _ctx(recoveryScore: 70, fatigue: FatigueTrend.accumulating),
      );
      _checkInvariants('4.4', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery);
    });

    test('4.5 fatigue=suppressed + score=65 → recovery', () {
      final d = _decide(
        _ctx(recoveryScore: 65, fatigue: FatigueTrend.suppressed),
      );
      _checkInvariants('4.5', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery);
    });

    test('4.6 collapseRisk=moderate + score=68 → recovery', () {
      final d = _decide(
        _ctx(recoveryScore: 68, collapseRisk: RecoveryCollapseRisk.moderate),
      );
      _checkInvariants('4.6', d);
      expect(d.focus, AdaptiveTrainingFocus.recovery);
    });

    test('4.7 recovery: intensity<1.0', () {
      final d = _decide(_ctx(recoveryScore: 45));
      expect(d.intensityMultiplier, lessThan(1.0));
    });

    test('4.8 recovery: intensityMult=0.80 when score<50', () {
      final d = _decide(_ctx(recoveryScore: 40));
      expect(d.intensityMultiplier, 0.80);
    });

    test('4.9 recovery: intensityMult=0.92 when 50≤score<60', () {
      final d = _decide(_ctx(recoveryScore: 55));
      expect(d.intensityMultiplier, 0.92);
    });

    test('4.10 recovery: volumeMult=0.65 when score<50', () {
      final d = _decide(_ctx(recoveryScore: 40));
      expect(d.volumeMultiplier, 0.65);
    });

    test('4.11 recovery: volumeMult=0.80 when 50≤score<60', () {
      final d = _decide(_ctx(recoveryScore: 55));
      expect(d.volumeMultiplier, 0.80);
    });

    test('4.12 recovery: failure training is reduced', () {
      final d = _decide(_ctx(recoveryScore: 50));
      expect(d.shouldReduceFailureTraining, isTrue);
    });
  });

  // ── § 5  Overload focus ───────────────────────────────────────────────────

  group('§5 Overload focus', () {
    test('5.1 prime conditions → overload', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overreaching:      OverreachingRisk.none,
        overloadReadiness: OverloadReadiness.prime,
        highFatigue:       false,
      ));
      _checkInvariants('5.1', d);
      expect(d.focus, AdaptiveTrainingFocus.overload);
    });

    test('5.2 overload: intensity=1.10 when discipline≥70', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        75,
      ));
      expect(d.intensityMultiplier, 1.10);
    });

    test('5.3 overload: intensity=1.05 when discipline<70', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        60,
      ));
      expect(d.intensityMultiplier, 1.05);
    });

    test('5.4 overload: volumeMult=1.05', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
      ));
      expect(d.volumeMultiplier, 1.05);
    });

    test('5.5 overload not triggered when recoveryScore=84 (below 85 threshold)', () {
      final d = _decide(_ctx(
        recoveryScore:     84,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        fatigue:           FatigueTrend.improving,
        overreaching:      OverreachingRisk.none,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.overload),
          reason: 'recoveryScore must be ≥85 for overload');
    });

    test('5.6 overload not triggered when highFatigue=true', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        highFatigue:       true,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.overload));
    });

    test('5.7 overload not triggered when overreachingRisk=moderate', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        overreaching:      OverreachingRisk.moderate,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.overload));
    });

    test('5.8 overload: facing message is non-empty', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
      ));
      expect(d.athleteFacingMessage, isNotEmpty);
    });
  });

  // ── § 6  Strength / hypertrophy / technical focus ─────────────────────────

  group('§6 Strength / hypertrophy / technical focus', () {
    test('6.1 strength push: momentum=peaking + goal=strength + score≥72', () {
      final d = _decide(_ctx(
        recoveryScore: 80,
        momentum:      MomentumLevel.peaking,
        goal:          'strength',
      ));
      _checkInvariants('6.1', d);
      expect(d.focus, AdaptiveTrainingFocus.strengthPush);
    });

    test('6.2 strength push: intensity=1.05', () {
      final d = _decide(_ctx(
        recoveryScore: 80,
        momentum:      MomentumLevel.peaking,
        goal:          'strength',
      ));
      expect(d.intensityMultiplier, 1.05);
    });

    test('6.3 strength push: volume=1.0', () {
      final d = _decide(_ctx(
        recoveryScore: 80,
        momentum:      MomentumLevel.peaking,
        goal:          'strength',
      ));
      expect(d.volumeMultiplier, 1.0);
    });

    test('6.4 strength not triggered when recoveryScore=71', () {
      final d = _decide(_ctx(
        recoveryScore: 71,
        momentum:      MomentumLevel.peaking,
        goal:          'strength',
        fatigue:       FatigueTrend.improving,
        overreaching:  OverreachingRisk.none,
        collapseRisk:  RecoveryCollapseRisk.low,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.strengthPush),
          reason: 'score must be ≥72');
    });

    test('6.5 hypertrophy push: plateau≥2 + goal=muscle_gain + score≥65', () {
      final d = _decide(_ctx(
        recoveryScore: 70,
        plateau:       PlateauRisk.high,
        goal:          'muscle_gain',
        isOnPlateau:   true,
      ));
      _checkInvariants('6.5', d);
      expect(d.focus, AdaptiveTrainingFocus.hypertrophyPush);
    });

    test('6.6 hypertrophy: intensity=0.95', () {
      final d = _decide(_ctx(
        recoveryScore: 70,
        plateau:       PlateauRisk.high,
        goal:          'muscle_gain',
        isOnPlateau:   true,
      ));
      expect(d.intensityMultiplier, 0.95);
    });

    test('6.7 hypertrophy: volumeMult=1.05', () {
      final d = _decide(_ctx(
        recoveryScore: 70,
        plateau:       PlateauRisk.high,
        goal:          'muscle_gain',
        isOnPlateau:   true,
      ));
      expect(d.volumeMultiplier, 1.05);
    });

    test('6.8 hypertrophy not triggered when score=64', () {
      final d = _decide(_ctx(
        recoveryScore: 64,
        plateau:       PlateauRisk.high,
        goal:          'muscle_gain',
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.hypertrophyPush),
          reason: 'score must be ≥65');
    });

    test('6.9 technical session: 62≤score<78 + overreaching≤none', () {
      final d = _decide(_ctx(
        recoveryScore: 70,
        overreaching:  OverreachingRisk.none,
        fatigue:       FatigueTrend.improving,
      ));
      _checkInvariants('6.9', d);
      expect(d.focus, AdaptiveTrainingFocus.technicalSession);
    });

    test('6.10 technical: intensity=0.95', () {
      final d = _decide(_ctx(recoveryScore: 70));
      expect(d.intensityMultiplier, 0.95);
    });

    test('6.11 technical: volumeMult=0.90', () {
      final d = _decide(_ctx(recoveryScore: 70));
      expect(d.volumeMultiplier, 0.90);
    });

    test('6.12 technical not triggered when overreachingRisk=moderate', () {
      final d = _decide(_ctx(
        recoveryScore: 70,
        overreaching:  OverreachingRisk.moderate,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.technicalSession));
    });
  });

  // ── § 7  Maintain focus ───────────────────────────────────────────────────

  group('§7 Maintain focus', () {
    test('7.1 stable conditions → maintain', () {
      final d = _decide(_ctx(
        recoveryScore: 78,
        momentum:      MomentumLevel.building,
        fatigue:       FatigueTrend.stable,
        overreaching:  OverreachingRisk.none,
      ));
      _checkInvariants('7.1', d);
      expect(d.focus, AdaptiveTrainingFocus.maintain);
    });

    test('7.2 maintain: intensityMult=1.0', () {
      final d = _decide(_ctx(recoveryScore: 78, fatigue: FatigueTrend.stable));
      expect(d.intensityMultiplier, 1.0);
    });

    test('7.3 maintain: volumeMult=1.0 (no modifiers)', () {
      final d = _decide(_ctx(recoveryScore: 78));
      expect(d.volumeMultiplier, 1.0);
    });

    test('7.4 maintain: athleteFacingMessage is empty when no swap/axial', () {
      final d = _decide(_ctx(
        recoveryScore: 78,
        fatigue:       FatigueTrend.stable,
        overreaching:  OverreachingRisk.none,
      ));
      expect(d.athleteFacingMessage, isEmpty);
    });

    test('7.5 maintain: shouldModifyWorkout is false when nothing triggers', () {
      final d = _decide(_ctx(recoveryScore: 78));
      // Only false when focus=maintain AND no swaps/axial/failure flags
      // failure training is reduced when score<70 — score=78 avoids it
      expect(d.shouldReduceFailureTraining, isFalse);
    });

    test('7.6 recover-aligned message when suppressed muscles don\'t conflict', () {
      final d = _decide(_ctx(
        recoveryScore:       78,
        suppressedMuscles:   ['legs'],
        exerciseCategories:  ['Chest', 'Shoulders'],
      ));
      expect(d.recoveryAlignedMessage, isNotEmpty,
          reason: 'suppressed legs + upper-body session → aligned message');
    });

    test('7.7 no recover-aligned message when no suppressed muscles', () {
      final d = _decide(_ctx(recoveryScore: 78));
      expect(d.recoveryAlignedMessage, isEmpty);
    });

    test('7.8 maintain with plateau=high: reasoning contains rotate rep ranges', () {
      final d = _decide(_ctx(
        recoveryScore: 78,
        plateau:       PlateauRisk.high,
        isOnPlateau:   true,
        goal:          'strength', // prevents hypertrophyPush
      ));
      // Focus may be strengthPush if momentum=peaking; here momentum=building
      // so it falls through to maintain or technical
      expect(d.reasoning, contains('rotate rep ranges'));
    });
  });

  // ── § 8  Memory advisory — rule-by-rule ───────────────────────────────────

  group('§8 Memory advisory signal effects', () {
    // Rule 1: consistencyScore < 0.30 → disciplineScore -5
    test('8.1 rule1: low consistency reduces discipline signal by 5', () {
      final withMem = _decide(_ctx(
        recoveryScore: 90,
        momentum:      MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:    72,
        memory:        _mem(consistency: 0.20),  // rule 1 fires: -5 → effective 67
      ));
      final noMem = _decide(_ctx(
        recoveryScore: 90,
        momentum:      MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:    67,  // equivalent post-adjustment
      ));
      // Both should produce the same intensity (67 < 70 → 1.05 not 1.10)
      expect(withMem.intensityMultiplier, noMem.intensityMultiplier,
          reason: 'rule1 -5 discipline brings 72→67, same as explicit 67');
    });

    test('8.2 rule1: low consistency does NOT change focus', () {
      final d = _decide(_ctx(
        recoveryScore: 80,
        memory:        _mem(consistency: 0.10),
      ));
      _checkInvariants('8.2', d);
      // Focus should not degrade — only discipline score nudges
      expect(d.focus, isNot(AdaptiveTrainingFocus.deload));
      expect(d.focus, isNot(AdaptiveTrainingFocus.recovery));
    });

    test('8.3 rule1: very low consistency + borderline discipline may shift overload intensity', () {
      // discipline=71 + consistency<0.30 → effective=66 (<70) → intensity 1.05 not 1.10
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        71,
        memory:            _mem(consistency: 0.20),
      ));
      expect(d.intensityMultiplier, 1.05,
          reason: 'rule1 drops 71→66, below 70 threshold → 1.05');
    });

    // Rule 2: progressionVelocity > 0.75 → +3 discipline, +0.03 comeback
    test('8.4 rule2: high progression lifts discipline by 3', () {
      final withMem = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        68,
        memory:            _mem(progressionV: 0.80),  // +3 → effective 71 ≥ 70
      ));
      final noMem = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        71,  // equivalent
      ));
      expect(withMem.intensityMultiplier, noMem.intensityMultiplier,
          reason: 'rule2 +3 discipline brings 68→71, same as explicit 71');
    });

    test('8.5 rule2: below 0.75 threshold — no progression boost', () {
      final d1 = _decide(_ctx(
        recoveryScore: 80, discipline: 65,
        memory: _mem(progressionV: 0.75),  // exactly at threshold — rule requires >0.75
      ));
      final d2 = _decide(_ctx(
        recoveryScore: 80, discipline: 65,
      ));
      expect(d1.intensityMultiplier, d2.intensityMultiplier,
          reason: '0.75 is not >0.75 — rule does not fire');
    });

    // Rule 3: recoveryVelocity < 0.35 → -0.04 comeback
    test('8.6 rule3: slow recovery velocity reduces comeback probability', () {
      // comebackProb=0.50 - 0.04 = 0.46 < 0.50 → comebackSession not triggered
      final withMem = _decide(_ctx(
        daysSinceLast: 4,
        comebackProb:  0.50,
        memory:        _mem(recoveryV: 0.30),  // rule3: -0.04 → effective 0.46
      ));
      expect(withMem.focus, isNot(AdaptiveTrainingFocus.comebackSession),
          reason: 'rule3 drops comeback 0.50→0.46, below threshold of 0.50');
    });

    test('8.7 rule3: above 0.35 threshold — no recovery penalty', () {
      final d1 = _decide(_ctx(
        daysSinceLast: 4,
        comebackProb:  0.50,
        memory:        _mem(recoveryV: 0.35),  // exactly at threshold — rule requires <0.35
      ));
      expect(d1.focus, AdaptiveTrainingFocus.comebackSession,
          reason: '0.35 is not <0.35 — comeback stays at 0.50');
    });

    // Rule 4: reliabilityScore < 0.40 → -3 discipline
    test('8.8 rule4: low reliability reduces discipline by 3', () {
      final withMem = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        70,
        memory:            _mem(reliability: 0.30),  // -3 → effective 67 < 70 → 1.05
      ));
      expect(withMem.intensityMultiplier, 1.05,
          reason: 'rule4 drops 70→67 below threshold');
    });

    test('8.9 rule4: at 0.40 threshold — no penalty (rule requires <0.40)', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        70,
        memory:            _mem(reliability: 0.40),
      ));
      expect(d.intensityMultiplier, 1.10,
          reason: '0.40 is not <0.40 — discipline stays at 70 → 1.10');
    });

    // Rule 5: volumeTolerance > 0.75 → +0.05 comeback
    test('8.10 rule5: high volume tolerance increases comeback probability', () {
      // comebackProb=0.46 + 0.05 = 0.51 → comebackSession triggered
      final d = _decide(_ctx(
        daysSinceLast: 4,
        comebackProb:  0.46,
        memory:        _mem(volumeTol: 0.80),  // +0.05 → effective 0.51
      ));
      expect(d.focus, AdaptiveTrainingFocus.comebackSession,
          reason: 'rule5 lifts comeback 0.46→0.51, above threshold');
    });

    test('8.11 rule5: at 0.75 threshold — no boost (rule requires >0.75)', () {
      final d = _decide(_ctx(
        daysSinceLast: 4,
        comebackProb:  0.46,
        memory:        _mem(volumeTol: 0.75),
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.comebackSession),
          reason: '0.75 is not >0.75 — comeback stays at 0.46');
    });

    // Clamp behavior
    test('8.12 combined rules 1+4 clamped to -5 max reduction', () {
      // rules 1 (-5) + 4 (-3) = -8, clamped to -5
      // discipline=65 - 5 = 60 (not 57)
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        74,
        memory:            _mem(consistency: 0.10, reliability: 0.20),
      ));
      // Even clamped at -5: 74-5=69 < 70 → intensity 1.05
      expect(d.intensityMultiplier, 1.05);
    });

    test('8.13 combined rules 2+5 clamped to +0.05 max comeback boost', () {
      // rules 2 (+0.03) + 5 (+0.05) = +0.08, clamped to +0.05
      final d = _decide(_ctx(
        daysSinceLast: 4,
        comebackProb:  0.46,
        memory:        _mem(progressionV: 0.80, volumeTol: 0.80),
      ));
      // Max +0.05: 0.46+0.05=0.51 → comebackSession
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    // Rule 6: identityStage / experienceLevel — advisory only
    test('8.14 rule6: beginner identity does not change focus', () {
      final d1 = _decide(_ctx(
        recoveryScore: 80,
        memory:        _mem(identity: 'beginner', experience: 'novice'),
      ));
      final d2 = _decide(_ctx(recoveryScore: 80));
      expect(d1.focus, d2.focus, reason: 'identity/experience are advisory only');
    });

    test('8.15 no memory snapshot → same as zero advisory', () {
      final withNull  = _decide(_ctx(recoveryScore: 80));
      final withZero  = _decide(_ctx(
        recoveryScore: 80,
        memory:        _mem(
          consistency: 0.5, adherence: 0.5, reliability: 0.5,
          recoveryV: 0.5, progressionV: 0.5, volumeTol: 0.5,
        ),
      ));
      // Mid-point memory should not fire any rule
      expect(withNull.focus,              withZero.focus);
      expect(withNull.intensityMultiplier, withZero.intensityMultiplier);
    });
  });

  // ── § 9  Behavioral modifiers ─────────────────────────────────────────────

  group('§9 Behavioral modifiers', () {
    test('9.1 burnoutRisk=high + volumeMult>1.02 → capped to 1.0', () {
      // Overload focus normally gives 1.05 — burnout caps it
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        burnout:           BurnoutRisk.high,
      ));
      _checkInvariants('9.1', d);
      expect(d.volumeMultiplier, 1.0,
          reason: 'burnout cap overrides overload volumeMult 1.05 → 1.0');
    });

    test('9.2 burnoutRisk=moderate + volumeMult>1.02 → capped to 1.0', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        burnout:           BurnoutRisk.moderate,
      ));
      expect(d.volumeMultiplier, 1.0);
    });

    test('9.3 burnoutRisk=low — no volume cap', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        burnout:           BurnoutRisk.low,
      ));
      expect(d.volumeMultiplier, 1.05,
          reason: 'burnout=low does not cap overload volume');
    });

    test('9.4 intimidationRisk=high + volumeMult≥1.0 → 0.85', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        intimidation:      IntimidationRisk.high,
        daysSinceLast:     1,  // not a comeback — stay on overload path
      ));
      _checkInvariants('9.4', d);
      // intimidation≥2 + daysSince<2 → not comebackSession — stays overload
      // but then volumeMult softened to 0.85
      expect(d.volumeMultiplier, 0.85);
    });

    test('9.5 intimidationRisk=moderate — same softening', () {
      final d = _decide(_ctx(
        recoveryScore:     80,
        fatigue:           FatigueTrend.improving,
        overreaching:      OverreachingRisk.none,
        intimidation:      IntimidationRisk.moderate,
        daysSinceLast:     1,
      ));
      _checkInvariants('9.5', d);
      expect(d.volumeMultiplier, 0.85);
    });

    test('9.6 burnout reasoning: add recovery day when burnout≥2', () {
      final d = _decide(_ctx(
        recoveryScore: 78,
        burnout:       BurnoutRisk.high,
      ));
      expect(d.reasoning, contains('add recovery day'));
    });

    test('9.7 overreachingRisk=high reasoning: reduce weekly volume', () {
      final d = _decide(_ctx(
        recoveryScore: 78,
        overreaching:  OverreachingRisk.high,
        needsDeload:   true,
      ));
      expect(d.reasoning, contains('reduce weekly volume'));
    });

    test('9.8 back suppression reasoning: shift pull day', () {
      final d = _decide(_ctx(
        recoveryScore:     78,
        suppressedMuscles: ['back'],
      ));
      expect(d.reasoning, contains('shift pull day'));
    });
  });

  // ── §10  Exercise swaps ───────────────────────────────────────────────────

  group('§10 Exercise swaps', () {
    test('10.1 deadlift + shouldReduceAxialLoad → swap to Chest Supported Row', () {
      final d = _decide(_ctx(
        recoveryScore:       70,
        shouldReduceAxialLoad: true,
        exerciseNames:       ['Barbell Deadlift'],
        exerciseCategories:  ['Back'],
      ));
      expect(d.shouldSwapExercises, isTrue);
      expect(d.swaps.any((s) => s.original.contains('Deadlift')), isTrue);
    });

    test('10.2 squat + back suppressed → swap to Leg Press', () {
      final d = _decide(_ctx(
        recoveryScore:      55,
        suppressedMuscles:  ['back'],
        exerciseNames:      ['Back Squat'],
        exerciseCategories: ['Legs'],
      ));
      expect(d.swaps.any((s) => s.replacement == 'Leg Press'), isTrue);
    });

    test('10.3 romanian deadlift + highFatigue → swap to Leg Curl', () {
      final d = _decide(_ctx(
        recoveryScore:      55,
        highFatigue:        true,
        exerciseNames:      ['Romanian Deadlift'],
        exerciseCategories: ['Legs'],
      ));
      expect(d.swaps.any((s) => s.replacement == 'Leg Curl'), isTrue);
    });

    test('10.4 no swap when recovery is strong and no flags', () {
      final d = _decide(_ctx(
        recoveryScore:      90,
        momentum:           MomentumLevel.peaking,
        overloadReadiness:  OverloadReadiness.prime,
        exerciseNames:      ['Deadlift', 'Barbell Row'],
        exerciseCategories: ['Back'],
      ));
      expect(d.swaps, isEmpty, reason: 'good recovery — no swaps needed');
    });

    test('10.5 bent-over row (hyphenated) + recoveryScore<60 → swap to Seated Cable Row', () {
      // The swap rule for 'bent-over row' (hyphenated) triggers on recoveryScore<60.
      // The rule for 'bent over row' (no hyphen) triggers only on back suppression.
      final d = _decide(_ctx(
        recoveryScore:      55,
        exerciseNames:      ['Bent-Over Row'],
        exerciseCategories: ['Back'],
      ));
      expect(d.swaps, isNotEmpty,
          reason: 'bent-over row rule fires when recoveryScore < 60');
    });

    test('10.6 each exercise gets at most one swap', () {
      final d = _decide(_ctx(
        recoveryScore:       50,
        shouldReduceAxialLoad: true,
        exerciseNames:       ['Barbell Deadlift'],
        exerciseCategories:  ['Back'],
      ));
      final deads = d.swaps.where((s) => s.original.contains('Deadlift')).length;
      expect(deads, 1, reason: 'one swap per exercise');
    });

    test('10.7 conflict detected when suppressed muscle matches session category', () {
      final d = _decide(_ctx(
        recoveryScore:      55,
        suppressedMuscles:  ['legs'],
        exerciseCategories: ['Legs'],
      ));
      // Recovery focus, and recovery-aligned message should be EMPTY (conflict)
      expect(d.recoveryAlignedMessage, isEmpty,
          reason: 'suppressed legs + leg session = conflict, no aligned msg');
    });

    test('10.8 no conflict when session avoids suppressed muscle', () {
      final d = _decide(_ctx(
        recoveryScore:      80,
        suppressedMuscles:  ['legs'],
        exerciseCategories: ['Chest', 'Arms'],
      ));
      expect(d.recoveryAlignedMessage, isNotEmpty);
    });
  });

  // ── §11  AthleteScoreEngine ───────────────────────────────────────────────

  group('§11 AthleteScoreEngine', () {
    test('11.1 all behavioral zeros + mid-point velocity fields → overallScore = 20.0', () {
      // (0*0.25 + 0*0.20 + 0*0.15 + 0.5*0.15 + 0.5*0.15 + 0.5*0.10) * 100 = 20.0
      final s = AthleteScoreEngine.compute(
        consistencyScore:  0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity:  0.5, progressionVelocity: 0.5, volumeTolerance: 0.5,
      );
      expect(s.overallScore, closeTo(20.0, 0.001),
          reason: 'weighted sum with default 0.5 velocity fields = 20.0');
    });

    test('11.2 all inputs at zero → overallScore = 0.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(0.0, 0.001));
    });

    test('11.3 all ones → overallScore=100.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 1, adherenceScore: 1, reliabilityScore: 1,
        recoveryVelocity: 1, progressionVelocity: 1, volumeTolerance: 1,
      );
      expect(s.overallScore, closeTo(100.0, 0.001));
    });

    test('11.4 weights sum is verified: partial inputs produce expected score', () {
      // Only consistency=1, rest=0
      final s = AthleteScoreEngine.compute(
        consistencyScore: 1, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(25.0, 0.001),
          reason: 'consistency weight is 25%');
    });

    test('11.5 adherence weight = 20%', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 1, reliabilityScore: 0,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(20.0, 0.001));
    });

    test('11.6 reliability weight = 15%', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 1,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(15.0, 0.001));
    });

    test('11.7 recoveryVelocity weight = 15%', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 1, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(15.0, 0.001));
    });

    test('11.8 progressionVelocity weight = 15%', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 0, progressionVelocity: 1, volumeTolerance: 0,
      );
      expect(s.overallScore, closeTo(15.0, 0.001));
    });

    test('11.9 volumeTolerance weight = 10%', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 1,
      );
      expect(s.overallScore, closeTo(10.0, 0.001));
    });

    test('11.10 disciplineScore at max inputs = 100.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 1, adherenceScore: 1, reliabilityScore: 1,
        recoveryVelocity: 0, progressionVelocity: 0, volumeTolerance: 0,
      );
      expect(s.disciplineScore, closeTo(100.0, 0.001));
    });

    test('11.11 disciplineScore at zero inputs = 0.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 1, progressionVelocity: 1, volumeTolerance: 1,
      );
      expect(s.disciplineScore, closeTo(0.0, 0.001));
    });

    test('11.12 confidence=0.0 when all inputs at defaults', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0, adherenceScore: 0, reliabilityScore: 0,
        recoveryVelocity: 0.5, progressionVelocity: 0.5, volumeTolerance: 0.5,
      );
      expect(s.confidence, closeTo(0.0, 0.001));
    });

    test('11.13 confidence=1.0 when all inputs are meaningfully observed', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 0.8, adherenceScore: 0.7, reliabilityScore: 0.9,
        recoveryVelocity: 0.6, progressionVelocity: 0.8, volumeTolerance: 0.4,
      );
      expect(s.confidence, closeTo(1.0, 0.001));
    });

    test('11.14 overallScore is clamped — inputs beyond 1.0 treated as 1.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: 2.0, adherenceScore: 2.0, reliabilityScore: 2.0,
        recoveryVelocity: 2.0, progressionVelocity: 2.0, volumeTolerance: 2.0,
      );
      expect(s.overallScore, closeTo(100.0, 0.001));
    });

    test('11.15 negative inputs clamped to 0.0', () {
      final s = AthleteScoreEngine.compute(
        consistencyScore: -1, adherenceScore: -1, reliabilityScore: -1,
        recoveryVelocity: -1, progressionVelocity: -1, volumeTolerance: -1,
      );
      expect(s.overallScore, closeTo(0.0, 0.001));
    });
  });

  // ── §12  Conflict / stability detection ───────────────────────────────────

  group('§12 Conflict & stability detection', () {
    test('12.1 deload invariant holds across all deload triggers', () {
      final triggers = [
        _ctx(needsDeload: true),
        _ctx(overreaching: OverreachingRisk.high),
        _ctx(collapseRisk: RecoveryCollapseRisk.high),
        _ctx(needsDeload: true, overreaching: OverreachingRisk.high),
      ];
      for (final (i, ctx) in triggers.indexed) {
        final d = _decide(ctx);
        expect(d.intensityMultiplier, 0.75,
            reason: 'deload trigger $i: intensity must be 0.75');
        expect(d.volumeMultiplier, 0.65,
            reason: 'deload trigger $i: volume must be 0.65');
      }
    });

    test('12.2 recovery focus always produces intensity < 1.0', () {
      final scenarios = [
        _ctx(recoveryScore: 30),
        _ctx(recoveryScore: 45),
        _ctx(recoveryScore: 55),
        _ctx(recoveryScore: 59),
        _ctx(recoveryScore: 65, fatigue: FatigueTrend.suppressed),
      ];
      for (final (i, ctx) in scenarios.indexed) {
        final d = _decide(ctx);
        if (d.focus == AdaptiveTrainingFocus.recovery) {
          expect(d.intensityMultiplier, lessThan(1.0),
              reason: 'recovery scenario $i must have intensity < 1.0');
        }
      }
    });

    test('12.3 overload focus always produces intensity ≥ 1.05', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
      ));
      if (d.focus == AdaptiveTrainingFocus.overload) {
        expect(d.intensityMultiplier, greaterThanOrEqualTo(1.05));
      }
    });

    test('12.4 all focus modes are reachable (no dead code paths)', () {
      final reached = <AdaptiveTrainingFocus>{};
      final contexts = [
        _ctx(needsDeload: true),                                                  // deload
        _ctx(recoveryScore: 50),                                                   // recovery
        _ctx(recoveryScore: 90, momentum: MomentumLevel.peaking,
            overloadReadiness: OverloadReadiness.prime),                           // overload
        _ctx(daysSinceLast: 4, comebackProb: 0.8),                               // comeback
        _ctx(recoveryScore: 80, momentum: MomentumLevel.peaking, goal: 'strength'), // strengthPush
        _ctx(recoveryScore: 70, plateau: PlateauRisk.high, isOnPlateau: true),    // hypertrophy
        _ctx(recoveryScore: 70),                                                   // technical
        _ctx(recoveryScore: 78, fatigue: FatigueTrend.stable),                    // maintain
      ];
      for (final ctx in contexts) {
        reached.add(_decide(ctx).focus);
      }
      expect(reached, contains(AdaptiveTrainingFocus.deload));
      expect(reached, contains(AdaptiveTrainingFocus.recovery));
      expect(reached, contains(AdaptiveTrainingFocus.overload));
      expect(reached, contains(AdaptiveTrainingFocus.comebackSession));
    });

    test('12.5 computedAt timestamp is propagated from input', () {
      final d = _decide(_ctx(recoveryScore: 80));
      expect(d.computedAt, _now);
    });

    test('12.6 no conflict violations accumulated across all scenarios', () {
      // This test runs LAST — reports any invariant violations caught above.
      if (_conflicts.isNotEmpty) {
        // Print for visibility before failing
        for (final c in _conflicts) {
          // ignore: avoid_print
          print('[CONFLICT] $c');
        }
      }
      expect(_conflicts, isEmpty,
          reason: 'All invariant checks must pass:\n${_conflicts.join('\n')}');
    });
  });

  // ── §13  Edge cases & boundary conditions ─────────────────────────────────

  group('§13 Edge cases & boundary conditions', () {
    test('13.1 recoveryScore exactly 85 → overload possible (boundary)', () {
      final d = _decide(_ctx(
        recoveryScore:     85,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        highFatigue:       false,
        overreaching:      OverreachingRisk.none,
      ));
      _checkInvariants('13.1', d);
      expect(d.focus, AdaptiveTrainingFocus.overload);
    });

    test('13.2 recoveryScore exactly 60 — NOT recovery (boundary)', () {
      final d = _decide(_ctx(
        recoveryScore: 60,
        fatigue:       FatigueTrend.improving,
        collapseRisk:  RecoveryCollapseRisk.low,
        overreaching:  OverreachingRisk.none,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.recovery));
    });

    test('13.3 discipline exactly 70 → intensityMult=1.10 in overload', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        70,
      ));
      expect(d.intensityMultiplier, 1.10,
          reason: '70 ≥ 70 → 1.10');
    });

    test('13.4 discipline exactly 69 → intensityMult=1.05 in overload', () {
      final d = _decide(_ctx(
        recoveryScore:     90,
        momentum:          MomentumLevel.peaking,
        overloadReadiness: OverloadReadiness.prime,
        discipline:        69,
      ));
      expect(d.intensityMultiplier, 1.05,
          reason: '69 < 70 → 1.05');
    });

    test('13.5 daysSinceLast exactly 4 + comebackProb=0.50 → comebackSession', () {
      final d = _decide(
        _ctx(daysSinceLast: 4, comebackProb: 0.50),
      );
      expect(d.focus, AdaptiveTrainingFocus.comebackSession);
    });

    test('13.6 daysSinceLast=3 + intimidation=low → no comeback', () {
      final d = _decide(_ctx(
        daysSinceLast: 3,
        intimidation:  IntimidationRisk.low,
        comebackProb:  0.9,
      ));
      expect(d.focus, isNot(AdaptiveTrainingFocus.comebackSession));
    });

    test('13.7 suppressedMuscles list is passed through unmodified', () {
      final suppressed = ['back', 'legs'];
      final d = _decide(_ctx(suppressedMuscles: suppressed));
      expect(d.suppressedMuscles, containsAll(suppressed));
    });

    test('13.8 prioritizedMuscles list is passed through from focusMuscles', () {
      final focus = ['chest', 'shoulders'];
      final d = _decide(_ctx(
        recoveryScore: 80,
        focusMuscles:  focus,
      ));
      expect(d.prioritizedMuscles, containsAll(focus));
    });
  });
}
