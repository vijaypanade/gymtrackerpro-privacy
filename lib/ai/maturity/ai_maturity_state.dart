// lib/ai/maturity/ai_maturity_state.dart
// Pure Dart — no Flutter imports.

import 'ai_maturity_phase.dart';
import 'language_profile.dart';
import 'allowed_claims.dart';

/// Immutable snapshot of the AI's current maturity level.
///
/// This is the single product contract consumed by every AI surface.
/// No surface may implement its own threshold logic. All capability
/// and language decisions derive from [allowedClaims] and [languageProfile].
///
/// Access via AppProvider:
///   appProvider.aiMaturity.phase
///   appProvider.aiMaturity.allowedClaims.ui.canShowWhyToggle
///   appProvider.aiMaturity.allowedClaims.content.canMakePatternClaim
///   appProvider.aiMaturity.languageProfile.openingStyle
class AIMaturityState {
  /// The current maturity phase. Governs the AI's authority level.
  final AIMaturityPhase phase;

  /// Progress toward the next phase, expressed as 0.0–1.0.
  /// Used by calibration progress indicators (e.g. AthleteBrain arc).
  /// Always 1.0 at [AIMaturityPhase.predictive].
  final double progressPct;

  /// The confidence score that fed this evaluation (0.0–1.0).
  /// Echoed here for transparency and logging — not for direct UI use.
  final double overallConfidence;

  /// The epistemic language register the AI is currently permitted to use.
  final LanguageProfile languageProfile;

  /// The complete capability set — UI visibility and content language claims.
  final AllowedClaims allowedClaims;

  const AIMaturityState({
    required this.phase,
    required this.progressPct,
    required this.overallConfidence,
    required this.languageProfile,
    required this.allowedClaims,
  });

  /// Safe zero-data fallback.
  ///
  /// Returned when the engine has not yet evaluated or when evaluation
  /// produces a pathological result. Maximally conservative — everything
  /// disabled. Surfaces receiving this state behave as if the athlete
  /// just opened the app for the first time.
  static const AIMaturityState baseline = AIMaturityState(
    phase:             AIMaturityPhase.baseline,
    progressPct:       0.0,
    overallConfidence: 0.0,
    languageProfile: LanguageProfile(
      requiresHedging:           true,
      canUsePatternLanguage:     false,
      canUsePredictionLanguage:  false,
      canAddressAthleteDirectly: false,
      phaseLabel:    'Just Getting Started',
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
    ),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AIMaturityState) return false;
    return other.phase             == phase             &&
           other.progressPct       == progressPct       &&
           other.overallConfidence == overallConfidence &&
           other.languageProfile   == languageProfile   &&
           other.allowedClaims     == allowedClaims;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    progressPct,
    overallConfidence,
    languageProfile,
    allowedClaims,
  );
}
