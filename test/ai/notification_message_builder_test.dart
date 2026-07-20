// test/ai/notification_message_builder_test.dart
//
// Test matrix for RFC-AI-MATURITY-PHASE-2 Step 8.
//
// Verifies that NotificationMessageBuilder respects AIMaturityState for
// every claim-gated notification surface. Three maturity fixtures cover:
//   _kBaseline   — 0 workouts, all claims disabled
//   _kObsUnlocked — observation permitted, pattern + adaptive still locked
//   _kFullyAdaptive — all claims permitted (calibrated athlete)

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/ai/maturity/ai_maturity_phase.dart';
import 'package:gymtrackerpromaster/ai/maturity/ai_maturity_state.dart';
import 'package:gymtrackerpromaster/ai/maturity/allowed_claims.dart';
import 'package:gymtrackerpromaster/ai/maturity/language_profile.dart';
import 'package:gymtrackerpromaster/ai/notifications/notification_message_builder.dart';

// ── Maturity fixtures ─────────────────────────────────────────────────────────

/// Level 0 — brand-new athlete, no data collected.
/// All claim gates are false. Mirrors AIMaturityState.baseline.
const _kBaseline = AIMaturityState.baseline;

/// Observation unlocked — early learning phase.
/// canMakeObservation is true; pattern and adaptive remain locked.
const _kObsUnlocked = AIMaturityState(
  phase:             AIMaturityPhase.learning,
  progressPct:       0.4,
  overallConfidence: 0.45,
  languageProfile: LanguageProfile(
    requiresHedging:           true,
    canUsePatternLanguage:     false,
    canUsePredictionLanguage:  false,
    canAddressAthleteDirectly: false,
    phaseLabel:    'Learning',
    openingStyle:  '',
    evidencePrefix: '',
  ),
  allowedClaims: AllowedClaims(
    ui: AllowedClaimsUi(
      canShowTrendArrow:       false,
      canShowWhyToggle:        false,
      canShowWeeklyStory:      false,
      canShowDominantSignals:  false,
      canShowSessionProphecy:  false,
      canShowAdaptiveIncrease: false,
      canShowConfidenceArc:    true,
    ),
    content: AllowedClaimsContent(
      canMakeObservation:        true,
      canMakePatternClaim:       false,
      canMakePrediction:         false,
      canMakePrescription:       false,
      canReferenceHistory:       false,
      canAddressAthleteDirectly: false,
      canCompareSessions:        false,
      canUseTrendLanguage:       false,
      canInjectPersonalContext:  false,
    ),
  ),
);

/// Fully adaptive — calibrated athlete, all relevant claims unlocked.
const _kFullyAdaptive = AIMaturityState(
  phase:             AIMaturityPhase.calibrated,
  progressPct:       1.0,
  overallConfidence: 0.82,
  languageProfile: LanguageProfile(
    requiresHedging:           false,
    canUsePatternLanguage:     true,
    canUsePredictionLanguage:  true,
    canAddressAthleteDirectly: true,
    phaseLabel:    'Calibrated',
    openingStyle:  '',
    evidencePrefix: '',
  ),
  allowedClaims: AllowedClaims(
    ui: AllowedClaimsUi(
      canShowTrendArrow:       true,
      canShowWhyToggle:        true,
      canShowWeeklyStory:      true,
      canShowDominantSignals:  true,
      canShowSessionProphecy:  false,
      canShowAdaptiveIncrease: true,
      canShowConfidenceArc:    false,
    ),
    content: AllowedClaimsContent(
      canMakeObservation:        true,
      canMakePatternClaim:       true,
      canMakePrediction:         false,
      canMakePrescription:       true,
      canReferenceHistory:       true,
      canAddressAthleteDirectly: true,
      canCompareSessions:        true,
      canUseTrendLanguage:       true,
      canInjectPersonalContext:  true,
    ),
  ),
);

// ── Helpers ───────────────────────────────────────────────────────────────────

// Represents a consistent athlete (high score, typical mid-session gap)
// so the pattern-claim branch is reachable when the gate permits.
NotificationMessage _momentum(AIMaturityState m, {
  int daysMissed       = 2,
  int previousStreak   = 10,
  int consistencyScore = 75,
}) => NotificationMessageBuilder.momentumProtection(
  daysMissed:       daysMissed,
  previousStreak:   previousStreak,
  consistencyScore: consistencyScore,
  aiMaturity:       m,
);

NotificationMessage _recovery(AIMaturityState m, {int readiness = 5}) =>
    NotificationMessageBuilder.recoveryReady(readiness: readiness, aiMaturity: m);

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── §1 Baseline (Level 0 — 0 workouts) ─────────────────────────────────────
  group('§1 Baseline maturity — all claim gates locked', () {
    test('1.1 momentum: no pattern claim — returns neutral DATA reminder', () {
      final msg = _momentum(_kBaseline);
      expect(msg.title, isNot('You usually train around now.'));
      expect(msg.title, isNot(contains('usually')));
    });

    test('1.2 momentum: high consistency score still blocked without permission', () {
      // Even if consistencyScore >= 60, no pattern claim should fire.
      final msg = _momentum(_kBaseline, consistencyScore: 90);
      expect(msg.title, isNot('You usually train around now.'));
    });

    test('1.3 recovery readiness 5: "Good day to push." blocked — uses DATA body', () {
      final msg = _recovery(_kBaseline, readiness: 5);
      expect(msg.body, isNot('Good day to push.'));
      expect(msg.body, 'A session fits today.');
    });

    test('1.4 recovery readiness 4: "Recovery looks good." blocked — uses DATA title', () {
      final msg = _recovery(_kBaseline, readiness: 4);
      expect(msg.title, isNot('Recovery looks good.'));
      expect(msg.title, 'Ready to train.');
    });

    test('1.5 recovery readiness < 4: not surfaced by caller — builder still returns valid message', () {
      // Builder itself has no guard at readiness < 4 (caller guards).
      // This verifies the builder does not crash on any readiness value.
      expect(() => _recovery(_kBaseline, readiness: 3), returnsNormally);
    });
  });

  // ── §2 Observation unlocked (early learning — 2–3 workouts) ────────────────
  group('§2 Observation unlocked — pattern + adaptive still locked', () {
    test('2.1 momentum: no pattern claim ("You usually…") — consistency gate blocked', () {
      final msg = _momentum(_kObsUnlocked, consistencyScore: 80);
      expect(msg.title, isNot('You usually train around now.'));
    });

    test('2.2 recovery readiness 4: observation title allowed', () {
      final msg = _recovery(_kObsUnlocked, readiness: 4);
      expect(msg.title, 'Recovery looks good.');
      expect(msg.body, "Today's workout fits.");
    });

    test('2.3 recovery readiness 5: title is "Fully recovered." but body is DATA (no adaptive increase yet)', () {
      final msg = _recovery(_kObsUnlocked, readiness: 5);
      expect(msg.title, 'Fully recovered.');
      expect(msg.body, 'A session fits today.'); // adaptive locked
      expect(msg.body, isNot('Good day to push.'));
    });
  });

  // ── §3 Fully adaptive (calibrated athlete) ─────────────────────────────────
  group('§3 Fully adaptive — all relevant claims unlocked', () {
    test('3.1 momentum: pattern claim fires for consistent athlete', () {
      final msg = _momentum(_kFullyAdaptive,
          daysMissed: 2, previousStreak: 3, consistencyScore: 75);
      expect(msg.title, 'You usually train around now.');
      expect(msg.body, 'A short session fits.');
    });

    test('3.2 momentum: high daysMissed overrides pattern — factual tone first', () {
      final msg = _momentum(_kFullyAdaptive, daysMissed: 5);
      expect(msg.title, 'A few days off.');
    });

    test('3.3 momentum: previousStreak >= 7 + daysMissed >= 2 overrides pattern', () {
      final msg = _momentum(_kFullyAdaptive,
          daysMissed: 3, previousStreak: 10, consistencyScore: 90);
      expect(msg.title, 'Missed a couple of days.');
    });

    test('3.4 recovery readiness 5: full adaptive message', () {
      final msg = _recovery(_kFullyAdaptive, readiness: 5);
      expect(msg.title, 'Fully recovered.');
      expect(msg.body, 'Good day to push.');
    });

    test('3.5 recovery readiness 4: observation message', () {
      final msg = _recovery(_kFullyAdaptive, readiness: 4);
      expect(msg.title, 'Recovery looks good.');
      expect(msg.body, "Today's workout fits.");
    });
  });

  // ── §4 Data-only branches always fire regardless of maturity ───────────────
  group('§4 DATA branches — unaffected by maturity level', () {
    for (final m in [_kBaseline, _kObsUnlocked, _kFullyAdaptive]) {
      test('4.1 momentum daysMissed >= 4 returns DATA message regardless of maturity', () {
        final msg = _momentum(m, daysMissed: 4);
        expect(msg.title, 'A few days off.');
        expect(msg.body, 'One session resets the rhythm.');
      });

      test('4.2 momentum previousStreak >= 7 + daysMissed >= 2 returns DATA message', () {
        final msg = _momentum(m,
            daysMissed: 2, previousStreak: 8, consistencyScore: 20);
        expect(msg.title, 'Missed a couple of days.');
      });
    }
  });

  // ── §5 Pattern-claim gate boundary ─────────────────────────────────────────
  group('§5 Pattern-claim boundary — consistencyScore threshold', () {
    test('5.1 score == 59 + fully-adaptive maturity: no pattern claim fires', () {
      final msg = _momentum(_kFullyAdaptive,
          daysMissed: 2, previousStreak: 3, consistencyScore: 59);
      expect(msg.title, isNot('You usually train around now.'));
    });

    test('5.2 score == 60 + fully-adaptive maturity: pattern claim fires', () {
      final msg = _momentum(_kFullyAdaptive,
          daysMissed: 2, previousStreak: 3, consistencyScore: 60);
      expect(msg.title, 'You usually train around now.');
    });

    test('5.3 score == 60 + baseline maturity: still blocked', () {
      final msg = _momentum(_kBaseline,
          daysMissed: 2, previousStreak: 3, consistencyScore: 60);
      expect(msg.title, isNot('You usually train around now.'));
    });
  });

  // ── §6 NotificationCategory tags ───────────────────────────────────────────
  group('§6 Category tags are correctly assigned', () {
    test('6.1 momentum daysMissed >= 4 → consistency category', () {
      expect(_momentum(_kBaseline, daysMissed: 5).category.name, 'consistency');
    });

    test('6.2 momentum fallback "No session yet." → reminder category', () {
      expect(_momentum(_kBaseline, daysMissed: 1, previousStreak: 0,
          consistencyScore: 0).category.name, 'reminder');
    });

    test('6.3 recovery ready → recovery category', () {
      expect(_recovery(_kFullyAdaptive, readiness: 5).category.name, 'recovery');
      expect(_recovery(_kBaseline, readiness: 4).category.name, 'recovery');
    });
  });
}
