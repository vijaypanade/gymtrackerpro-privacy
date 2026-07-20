// lib/ai/maturity/ai_maturity_engine.dart
// Pure Dart — no Flutter imports.

import 'ai_maturity_input.dart';
import 'ai_maturity_phase.dart';
import 'ai_maturity_state.dart';
import 'allowed_claims.dart';
import 'language_profile.dart';

/// Pure, stateless AI maturity evaluator.
///
/// [evaluate] maps current athlete signals to the complete [AIMaturityState]
/// that governs every AI surface. It is the single source of truth for all
/// phase boundaries and claim thresholds.
///
/// No provider dependencies. No Flutter imports. No side effects.
/// Identical inputs always produce identical outputs.
///
/// This engine is designed to replace the 13+ independent
/// `if (totalWorkouts < X)` and `if (confidence > Y)` checks distributed
/// across the codebase. Phase 1 (this file) builds the infrastructure in
/// shadow mode. Phase 2 will migrate surfaces one by one.
class AIMaturityEngine {
  const AIMaturityEngine();

  // ── Phase advancement thresholds ─────────────────────────────────────────
  //
  // These are the single source of truth. No other file may define
  // phase boundaries. When a threshold changes, it changes here only.

  /// First workout unlocks Learning.
  static const int _learningFloor = 1;

  /// Minimum sessions for pattern claims to be credible.
  /// At 10 workouts on a 3-day split, each major muscle has been trained
  /// 3–4 times — the minimum for the analytics engine's personal computation.
  static const int    _calibratedWorkoutFloor = 10;
  static const double _calibratedConfFloor    = 0.55;

  /// Minimum sessions for reliable trend projection.
  /// Confidence and consistency must BOTH hold — the conjunction is intentional.
  /// A sporadic athlete at 40 workouts does not earn predictions.
  static const int    _predictiveWorkoutFloor = 40;
  static const double _predictiveConfFloor    = 0.70;
  static const int    _predictiveConsFloor    = 60; // consistencyScore 0–100

  // ── Sub-phase claim thresholds ────────────────────────────────────────────
  //
  // Some capabilities unlock within Learning before the full Calibrated gate
  // is met. These are evidence-based minimums, not phase gates.

  /// Minimum workouts to show a directional trend arrow.
  static const int _trendArrowFloor = 3;

  /// Minimum workouts for Weekly Story to be meaningful.
  static const int _weeklyStoryFloor = 5;

  /// Minimum workouts before the AI may cite a prior session.
  static const int _referenceHistoryFloor = 2;

  /// Minimum workouts before "I've noticed…" observations are earned.
  static const int _observationFloor = 3;

  /// Minimum workouts before personal history may be injected into AI Chat.
  static const int _injectContextFloor = 3;

  /// Minimum workouts before session comparison is meaningful.
  static const int _compareSessionsFloor = 4;

  // ── Phase maintenance floors (informational — decay not yet active) ───────
  //
  // These define the confidence levels below which a phase would regress.
  // Declared here so the future decay implementation has named references
  // to modify rather than discovering magic numbers in business logic.
  // Maintenance floors are lower than advancement floors to prevent thrashing.

  // ignore: unused_field
  static const double _calibratedMaintenance = 0.40;
  // ignore: unused_field
  static const double _predictiveMaintenance = 0.55;

  // ═════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═════════════════════════════════════════════════════════════════════════

  /// Evaluates [input] and returns the complete [AIMaturityState].
  ///
  /// Never throws. Returns [AIMaturityState.baseline] on any pathological input.
  AIMaturityState evaluate(AIMaturityInput input) {
    try {
      final phase       = _derivePhase(input);
      final progressPct = _computeProgress(input, phase);
      final lang        = LanguageProfile.forPhase(phase);
      final claims      = _buildClaims(input, phase);

      return AIMaturityState(
        phase:             phase,
        progressPct:       progressPct,
        overallConfidence: input.overallConfidence.clamp(0.0, 1.0),
        languageProfile:   lang,
        allowedClaims:     claims,
      );
    } catch (_) {
      return AIMaturityState.baseline;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PHASE DERIVATION
  // ═════════════════════════════════════════════════════════════════════════

  AIMaturityPhase _derivePhase(AIMaturityInput input) {
    // Baseline: no workouts yet — AI has nothing personal to offer.
    if (input.totalWorkouts < _learningFloor) {
      return AIMaturityPhase.baseline;
    }

    // Predictive: all three gates must hold simultaneously.
    // Workout count sets the floor. Confidence and consistency gate quality.
    if (input.totalWorkouts    >= _predictiveWorkoutFloor &&
        input.overallConfidence >= _predictiveConfFloor   &&
        input.consistencyScore  >= _predictiveConsFloor) {
      return AIMaturityPhase.predictive;
    }

    // Calibrated: count and confidence both required.
    // Confidence gate prevents a sporadic athlete from earning pattern claims
    // simply by logging enough workouts over a long period.
    if (input.totalWorkouts    >= _calibratedWorkoutFloor &&
        input.overallConfidence >= _calibratedConfFloor) {
      return AIMaturityPhase.calibrated;
    }

    // Learning: anything above zero that has not reached Calibrated.
    return AIMaturityPhase.learning;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PROGRESS TOWARD NEXT PHASE
  // ═════════════════════════════════════════════════════════════════════════

  double _computeProgress(AIMaturityInput input, AIMaturityPhase phase) {
    switch (phase) {
      case AIMaturityPhase.baseline:
        return 0.0;

      case AIMaturityPhase.learning:
        // Blended progress: workout count (60%) + confidence (40%).
        // Confidence contribution prevents a user at 9 workouts with zero
        // confidence from showing a nearly-full arc.
        final workoutProgress = (input.totalWorkouts - _learningFloor) /
            (_calibratedWorkoutFloor - _learningFloor).toDouble();
        final confProgress = input.overallConfidence / _calibratedConfFloor;
        final blended = (workoutProgress * 0.6 + confProgress * 0.4)
            .clamp(0.0, 0.99); // cap at 0.99 until the phase actually advances
        return blended;

      case AIMaturityPhase.calibrated:
        // Blended progress toward Predictive: workout count (50%) + confidence (50%).
        final workoutProgress = input.totalWorkouts / _predictiveWorkoutFloor.toDouble();
        final confProgress = input.overallConfidence / _predictiveConfFloor;
        final blended = (workoutProgress * 0.5 + confProgress * 0.5)
            .clamp(0.0, 0.99);
        return blended;

      case AIMaturityPhase.predictive:
        return 1.0;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ALLOWED CLAIMS
  // ═════════════════════════════════════════════════════════════════════════

  AllowedClaims _buildClaims(AIMaturityInput input, AIMaturityPhase phase) {
    final bool isLearningPlus   = phase.isAtLeast(AIMaturityPhase.learning);
    final bool isCalibratedPlus = phase.isAtLeast(AIMaturityPhase.calibrated);
    final bool isPredictivePlus = phase.isAtLeast(AIMaturityPhase.predictive);
    final int  n                = input.totalWorkouts;

    return AllowedClaims(
      ui: AllowedClaimsUi(
        // Trend arrow: Calibrated+ OR Learning with enough sessions.
        canShowTrendArrow:
            isCalibratedPlus || (isLearningPlus && n >= _trendArrowFloor),

        // "Why this?" expansion requires confirmed dominant signals.
        canShowWhyToggle: isCalibratedPlus,

        // Weekly Story: meaningful once a real pattern of sessions exists.
        canShowWeeklyStory: isLearningPlus && n >= _weeklyStoryFloor,

        // Dominant signals: Calibrated only — signals must be confirmed patterns.
        canShowDominantSignals: isCalibratedPlus,

        // SessionProphecyCard: Predictive only.
        // Wrong prophecy destroys trust faster than silence does.
        canShowSessionProphecy: isPredictivePlus,

        // Adaptive load INCREASES require Calibrated.
        // "We increased your bench" implies the AI knows the athlete well
        // enough to push them. Decreases are handled separately and
        // do not require this flag.
        canShowAdaptiveIncrease: isCalibratedPlus,

        // Calibration arc: shown during Learning only.
        // It communicates "almost there" — once at Calibrated, it disappears.
        canShowConfidenceArc: isLearningPlus && !isCalibratedPlus,
      ),
      content: AllowedClaimsContent(
        // Observations require enough sessions to have something to notice.
        canMakeObservation: isLearningPlus && n >= _observationFloor,

        // Pattern claims require confirmed regularity — Calibrated only.
        canMakePatternClaim: isCalibratedPlus,

        // Predictions require forward-projection capability — Predictive only.
        canMakePrediction: isPredictivePlus,

        // Prescriptions ("reduce today's volume") require Calibrated.
        // The AI must know the athlete well enough to direct their training.
        canMakePrescription: isCalibratedPlus,

        // History citation requires a minimum number of prior sessions.
        canReferenceHistory: isLearningPlus && n >= _referenceHistoryFloor,

        // Second-person address ("you") is permitted from Learning onward.
        canAddressAthleteDirectly: isLearningPlus,

        // Session comparison requires enough similar sessions to compare.
        canCompareSessions: isLearningPlus && n >= _compareSessionsFloor,

        // Trend language ("improving", "declining") requires Calibrated.
        // In Learning the direction may be noise rather than a real trend.
        canUseTrendLanguage: isCalibratedPlus,

        // AI Chat personal context injection requires a minimum history.
        // Below this floor the system prompt warns the LLM that data is thin.
        canInjectPersonalContext: isLearningPlus && n >= _injectContextFloor,
      ),
    );
  }
}
