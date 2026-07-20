// lib/ai/maturity/recovery_presentation.dart
// Pure Dart — no Flutter imports.

import 'ai_maturity_phase.dart';

/// Surface-specific presentation copy for the Recovery Intelligence card.
///
/// The UI must never compute or derive these strings itself. This extension
/// is the single source of truth for maturity-dependent Recovery copy.
/// These labels belong only to this surface — Athlete Brain, Coach Insight,
/// AI Chat, and Notifications each have their own mappings.
///
/// Access via:
///   appProvider.aiMaturity.phase.recoveryTrendFallbackCopy
extension RecoveryPresentation on AIMaturityPhase {
  /// Shown in place of the trend arrow row when canShowTrendArrow is false.
  ///
  /// canShowTrendArrow requires Learning phase with ≥3 workouts, or Calibrated+.
  /// This copy is therefore only ever rendered during the very earliest
  /// Learning sessions (1–2 workouts). Empty string is a safe non-crashing
  /// fallback for phases where the trend row is always shown instead.
  String get recoveryTrendFallbackCopy => switch (this) {
    // Baseline: muscles list is empty → _OnboardingRecoveryCard is shown
    // before this code is reached, so this value is never rendered.
    AIMaturityPhase.baseline   => '',
    AIMaturityPhase.learning   => "I'm beginning to understand your recovery.",
    // Calibrated+: canShowTrendArrow is always true — else branch never renders.
    AIMaturityPhase.calibrated => '',
    AIMaturityPhase.predictive => '',
  };
}
