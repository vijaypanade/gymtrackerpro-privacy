// lib/ai/maturity/athlete_brain_presentation.dart
// Pure Dart — no Flutter imports.

import 'ai_maturity_phase.dart';

/// Surface-specific presentation labels for the Athlete Brain card header.
///
/// The UI must never invent its own label strings. This extension is the
/// single source of truth for what the Athlete Brain header shows at each
/// maturity phase. These labels belong only to this surface — Recovery,
/// Coach Insight, AI Chat, and Notifications each have their own mappings.
///
/// Access via:
///   appProvider.aiMaturity.phase.athleteBrainHeaderLabel
extension AthleteBrainPresentation on AIMaturityPhase {
  /// Header label shown in the top-left of the active Athlete Brain card.
  ///
  /// Never shown at Baseline — _OnboardingBrainContent intercepts that path.
  /// Present here for exhaustive-switch safety only.
  String get athleteBrainHeaderLabel => switch (this) {
    AIMaturityPhase.baseline   => 'Athlete Brain',
    AIMaturityPhase.learning   => 'First Signal',
    AIMaturityPhase.calibrated => "Today's Signal",
    AIMaturityPhase.predictive => 'Performance Signal',
  };

  /// Subtitle shown inside _CalibratingFooter while canShowWhyToggle is false.
  ///
  /// Calibrated and Predictive never render _CalibratingFooter — the Why Toggle
  /// appears instead. Empty string is a safe non-crashing fallback for those phases.
  String get calibratingFooterCopy => switch (this) {
    // Baseline: handled by _OnboardingBrainContent; _CalibratingFooter is not
    // rendered, but the switch must be exhaustive.
    AIMaturityPhase.baseline   => 'Train to activate Athlete Brain.',
    AIMaturityPhase.learning   => 'Your AI is learning from each workout.',
    AIMaturityPhase.calibrated => '',
    AIMaturityPhase.predictive => '',
  };
}
