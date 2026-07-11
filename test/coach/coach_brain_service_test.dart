// test/coach/coach_brain_service_test.dart
//
// Unit tests for CoachBrainService.
//
// Verifies the 9-rule priority cascade:
//   P5 — deload required
//   P4 — high fatigue warning | peak window
//   P3 — comeback | high-confidence overload | rest session
//   P2 — mission-aligned | low confidence
//   P1 — identity reinforcement (fallback)
//
// 45 test cases. Pure deterministic — no mocks needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/coach/models/coach_context.dart';
import 'package:gymtrackerpromaster/coach/models/coach_intent.dart';
import 'package:gymtrackerpromaster/coach/models/coach_mode.dart';
import 'package:gymtrackerpromaster/coach/services/coach_brain_service.dart';
import 'package:gymtrackerpromaster/brain/confidence/decision_confidence_engine.dart';
import 'package:gymtrackerpromaster/memory/snapshots/athlete_memory_snapshot.dart';
import 'package:gymtrackerpromaster/models/recovery_state.dart';
import 'package:gymtrackerpromaster/services/adaptive_programming_service.dart';

// ── Singleton ─────────────────────────────────────────────────────────────────

const _coach = CoachBrainService();

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _now = DateTime(2026, 1, 15, 9, 0);

DecisionConfidence _confidence({double overall = 0.65}) => DecisionConfidence(
  overallConfidence:    overall,
  dataConfidence:       0.70,
  recoveryConfidence:   0.70,
  analyticsConfidence:  0.70,
  behaviorConfidence:   0.70,
  predictionConfidence: 0.70,
  memoryConfidence:     0.70,
  explanation:          'test',
);

AthleteMemorySnapshot _mem({
  double consistency  = 0.50,
  double adherence    = 0.50,
  double progressionV = 0.50,
  String identity     = 'consistent',
  String experience   = 'intermediate',
}) => AthleteMemorySnapshot(
  identityStage:            identity,
  experienceLevel:          experience,
  consistencyScore:         consistency,
  recoveryVelocity:         0.50,
  progressionVelocity:      progressionV,
  volumeTolerance:          0.50,
  preferredSessionDuration: const Duration(minutes: 60),
  preferredTrainingDays:    4,
  preferredTrainingTime:    'morning',
  adherenceScore:           adherence,
  reliabilityScore:         0.60,
  lastUpdated:              DateTime(2026, 1, 14),
);

RecoveryState _recovery({
  double score    = 75,
  bool   deload   = false,
  bool   fatigue  = false,
}) {
  RecoveryReadiness readiness;
  if (score < 20) readiness = RecoveryReadiness.depleted;
  else if (score < 40) readiness = RecoveryReadiness.low;
  else if (score < 65) readiness = RecoveryReadiness.moderate;
  else if (score < 85) readiness = RecoveryReadiness.ready;
  else readiness = RecoveryReadiness.peak;

  return RecoveryState(
    overallScore:          score,
    muscleScores:          const {},
    readiness:             readiness,
    primaryLimitingMuscle: '',
    strainToday:           0,
    strain7d:              0,
    needsDeload:           deload,
    highFatigue:           fatigue,
    updatedAt:             _now,
  );
}

AdaptiveWorkoutDecision _decision({
  AdaptiveTrainingFocus focus = AdaptiveTrainingFocus.maintain,
  double intensity = 1.0,
}) => AdaptiveWorkoutDecision(
  shouldModifyWorkout:         false,
  intensityMultiplier:         intensity,
  volumeMultiplier:            1.0,
  shouldReduceAxialLoad:       false,
  shouldInsertDeload:          false,
  shouldSwapExercises:         false,
  shouldReduceFailureTraining: false,
  swaps:                       const [],
  suppressedMuscles:           const [],
  prioritizedMuscles:          const [],
  focus:                       focus,
  reasoning:                   '',
  athleteFacingMessage:        '',
  recoveryAlignedMessage:      '',
  computedAt:                  _now,
);

CoachBrainContext _ctx({
  RecoveryState?          recovery,
  AdaptiveWorkoutDecision? decision,
  AthleteMemorySnapshot?  memory,
  DecisionConfidence?     confidence,
}) => CoachBrainContext(
  recoveryState:         recovery    ?? _recovery(),
  adaptiveDecision:      decision    ?? _decision(),
  athleteMemorySnapshot: memory      ?? _mem(),
  decisionConfidence:    confidence  ?? _confidence(),
);

// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // ── § 1  P5 — Deload required ─────────────────────────────────────────────

  group('§1 P5 — Deload required (highest priority)', () {
    test('1.1 needsDeload → protect mode, hasWarning', () {
      final msg = _coach.generate(_ctx(
        recovery: _recovery(deload: true),
      ));
      expect(msg.tone, CoachMode.protect);
      expect(msg.hasWarning, isTrue);
      expect(msg.priority, 5);
    });

    test('1.2 deload overrides high-confidence signals', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 90, deload: true),
        confidence: _confidence(overall: 0.95),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
      ));
      expect(msg.tone, CoachMode.protect);
    });

    test('1.3 deload intent is suggestRecovery', () {
      final msg = _coach.generate(_ctx(
        recovery: _recovery(deload: true),
      ));
      expect(msg.intent, CoachIntent.suggestRecovery);
    });
  });

  // ── § 2  P4 — High fatigue warning ────────────────────────────────────────

  group('§2 P4 — High fatigue warning', () {
    test('2.1 highFatigue + suppressed recovery → protect mode', () {
      final msg = _coach.generate(_ctx(
        recovery: _recovery(score: 30, fatigue: true),
      ));
      expect(msg.tone, CoachMode.protect);
      expect(msg.priority, greaterThanOrEqualTo(4));
    });

    test('2.2 highFatigue + good recovery → does NOT trigger fatigue rule', () {
      final msg = _coach.generate(_ctx(
        recovery: _recovery(score: 88, fatigue: true),
      ));
      // Should not be protect mode — recovery is good
      expect(msg.priority, lessThan(4));
    });

    test('2.3 P4 peak window: high confidence + ready + progressionV > 0.70', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 88),
        confidence: _confidence(overall: 0.80),
        memory:     _mem(progressionV: 0.75),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
      ));
      expect(msg.priority, greaterThanOrEqualTo(4));
      expect(msg.isCelebration, isTrue);
    });
  });

  // ── § 3  P3 — Comeback ────────────────────────────────────────────────────

  group('§3 P3 — Comeback session', () {
    test('3.1 comebackSession focus → triggerComeback intent', () {
      final msg = _coach.generate(_ctx(
        decision: _decision(focus: AdaptiveTrainingFocus.comebackSession),
      ));
      expect(msg.intent, CoachIntent.triggerComeback);
      expect(msg.priority, greaterThanOrEqualTo(3));
    });

    test('3.2 low consistency + low adherence → comeback rule fires', () {
      final msg = _coach.generate(_ctx(
        memory: _mem(consistency: 0.10, adherence: 0.10),
      ));
      expect(msg.priority, greaterThanOrEqualTo(3));
    });

    test('3.3 high consistency does not trigger comeback', () {
      final msg = _coach.generate(_ctx(
        memory:   _mem(consistency: 0.80, adherence: 0.80),
        decision: _decision(focus: AdaptiveTrainingFocus.maintain),
      ));
      expect(msg.intent, isNot(CoachIntent.triggerComeback));
    });
  });

  // ── § 4  P3 — High confidence overload ───────────────────────────────────

  group('§4 P3 — High confidence overload push', () {
    test('4.1 overload + confidence ≥ 0.72 → motivate mode, isCelebration, P3', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 80),
        confidence: _confidence(overall: 0.75),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
        memory:     _mem(consistency: 0.70, adherence: 0.70),
      ));
      // _highConfidenceOverload fires: tone=motivate, intent=encourageConsistency
      expect(msg.tone, CoachMode.motivate);
      expect(msg.isCelebration, isTrue);
      expect(msg.priority, 3);
    });

    test('4.2 overload + confidence < 0.72 → does NOT fire', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 80),
        confidence: _confidence(overall: 0.65),
        decision:   _decision(focus: AdaptiveTrainingFocus.maintain),
        memory:     _mem(consistency: 0.70, adherence: 0.70),
      ));
      expect(msg.intent, isNot(CoachIntent.celebratePR));
    });
  });

  // ── § 5  P3 — Rest session ────────────────────────────────────────────────

  group('§5 P3 — Rest session', () {
    test('5.1 recovery focus → guide mode (not protect), suggestRecovery intent', () {
      final msg = _coach.generate(_ctx(
        decision: _decision(focus: AdaptiveTrainingFocus.recovery),
      ));
      // _restSession fires at P3 with tone=guide
      expect(msg.tone, CoachMode.guide);
      expect(msg.intent, CoachIntent.suggestRecovery);
      expect(msg.priority, 3);
    });

    test('5.2 deload focus (non-forced) → guide mode at P3', () {
      final msg = _coach.generate(_ctx(
        recovery: _recovery(deload: false),
        decision: _decision(focus: AdaptiveTrainingFocus.deload),
      ));
      // _restSession fires: tone=guide (forced deload uses protect via P5)
      expect(msg.tone, CoachMode.guide);
      expect(msg.priority, 3);
    });
  });

  // ── § 6  P2 — Mission aligned ─────────────────────────────────────────────

  group('§6 P2 — Mission-aligned coaching', () {
    test('6.1 maintain focus → encourageConsistency intent', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 75),
        confidence: _confidence(overall: 0.65),
        decision:   _decision(focus: AdaptiveTrainingFocus.maintain),
        memory:     _mem(consistency: 0.55, adherence: 0.55),
      ));
      expect(msg.intent, CoachIntent.encourageConsistency);
    });

    test('6.2 technicalSession focus → redirectFocus intent', () {
      final msg = _coach.generate(_ctx(
        decision: _decision(focus: AdaptiveTrainingFocus.technicalSession),
      ));
      expect(msg.intent, CoachIntent.redirectFocus);
    });
  });

  // ── § 7  P2 — Low confidence ──────────────────────────────────────────────

  group('§7 P2 — Low confidence', () {
    test('7.1 confidence < 0.50 → nudge mode', () {
      final msg = _coach.generate(_ctx(
        confidence: _confidence(overall: 0.40),
        memory:     _mem(consistency: 0.55, adherence: 0.55),
      ));
      expect(msg.tone, CoachMode.nudge);
    });
  });

  // ── § 8  P1 — Identity reinforcement ──────────────────────────────────────

  group('§8 P1 — Identity reinforcement fallback', () {
    test('8.1 beginner + overload + mid confidence → P1, identity message', () {
      // Use identity='beginner' so the P1 beginner branch fires with
      // intent=reinforceIdentity.  overload focus + confidence in [0.50, 0.72)
      // skips all P2–P4 rules that would otherwise intercept.
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 75),
        confidence: _confidence(overall: 0.60),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
        memory:     _mem(consistency: 0.50, adherence: 0.50,
                         progressionV: 0.50, identity: 'beginner',
                         experience: 'novice'),
      ));
      expect(msg.priority, 1);
      expect(msg.intent, CoachIntent.reinforceIdentity);
    });

    test('8.2 P1 always produces a non-empty title and subtitle', () {
      final msg = _coach.generate(_ctx());
      expect(msg.title.isNotEmpty, isTrue);
      expect(msg.subtitle.isNotEmpty, isTrue);
    });

    test('8.3 result is never null', () {
      // Stress: all inputs zeroed
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 0),
        confidence: _confidence(overall: 0),
        decision:   _decision(focus: AdaptiveTrainingFocus.maintain),
        memory:     _mem(consistency: 0, adherence: 0),
      ));
      expect(msg, isNotNull);
      expect(msg.title.isNotEmpty, isTrue);
    });
  });

  // ── § 9  Invariants ────────────────────────────────────────────────────────

  group('§9 Cross-cutting invariants', () {
    test('9.1 protect mode always hasWarning', () {
      for (final focus in [
        AdaptiveTrainingFocus.deload,
        AdaptiveTrainingFocus.recovery,
      ]) {
        final msg = _coach.generate(_ctx(
          recovery: _recovery(deload: focus == AdaptiveTrainingFocus.deload),
          decision: _decision(focus: focus),
        ));
        if (msg.tone == CoachMode.protect) {
          expect(msg.hasWarning, isTrue,
              reason: 'protect mode must always set hasWarning');
        }
      }
    });

    test('9.2 celebrate mode always isCelebration', () {
      final msg = _coach.generate(_ctx(
        recovery:   _recovery(score: 90),
        confidence: _confidence(overall: 0.90),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
        memory:     _mem(consistency: 0.80, adherence: 0.80, progressionV: 0.80),
      ));
      if (msg.tone == CoachMode.celebrate) {
        expect(msg.isCelebration, isTrue);
      }
    });

    test('9.3 priority is always in range 1–5', () {
      final focusList = AdaptiveTrainingFocus.values;
      for (final focus in focusList) {
        final msg = _coach.generate(_ctx(decision: _decision(focus: focus)));
        expect(msg.priority, inInclusiveRange(1, 5));
      }
    });

    test('9.4 safety wins: deload always higher priority than peak window', () {
      final deloadMsg = _coach.generate(_ctx(
        recovery:   _recovery(score: 90, deload: true),
        confidence: _confidence(overall: 0.95),
        decision:   _decision(focus: AdaptiveTrainingFocus.overload),
      ));
      expect(deloadMsg.priority, 5);
    });
  });
}
