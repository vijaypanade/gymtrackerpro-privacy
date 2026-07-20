// lib/ai/maturity/language_profile.dart
// Pure Dart — no Flutter imports.

import 'ai_maturity_phase.dart';

/// Defines the epistemic register the AI coach is permitted to use.
///
/// This governs HOW the AI speaks — the certainty of its claims — independently
/// of emotional tone, which belongs to CoachTone and AthleteIdentityStage.
///
/// LanguageProfile is a component of AIMaturityState. Surfaces and content
/// generators consume specific boolean flags; they must never switch on phase
/// directly.
class LanguageProfile {
  /// Whether any AI claim must be softened with hedging language.
  /// True at Baseline and Learning. False at Calibrated and above.
  final bool requiresHedging;

  /// Whether the AI may use confirmed pattern language.
  /// Examples: "You usually…", "Your body tends to…"
  final bool canUsePatternLanguage;

  /// Whether the AI may make forward projections.
  /// Examples: "I expect…", "Based on your trend…"
  final bool canUsePredictionLanguage;

  /// Whether the AI may address the athlete in second person.
  /// False at Baseline: "The recovery score suggests…" not "You're ready."
  final bool canAddressAthleteDirectly;

  /// Short label describing the current read quality.
  /// Used by calibration arcs, phase indicators, and future UI surfaces.
  final String phaseLabel;

  /// The canonical opening pattern for AI-generated coaching text at this phase.
  /// Empty string at Baseline — the AI has not earned an opener yet.
  final String openingStyle;

  /// Evidence prefix for citation references.
  /// Empty string at phases where citing personal history is premature.
  final String evidencePrefix;

  const LanguageProfile({
    required this.requiresHedging,
    required this.canUsePatternLanguage,
    required this.canUsePredictionLanguage,
    required this.canAddressAthleteDirectly,
    required this.phaseLabel,
    required this.openingStyle,
    required this.evidencePrefix,
  });

  /// Returns the canonical LanguageProfile for the given [phase].
  factory LanguageProfile.forPhase(AIMaturityPhase phase) => switch (phase) {
    AIMaturityPhase.baseline => const LanguageProfile(
      requiresHedging:            true,
      canUsePatternLanguage:      false,
      canUsePredictionLanguage:   false,
      canAddressAthleteDirectly:  false,
      phaseLabel:    'Just Getting Started',
      openingStyle:  '',
      evidencePrefix: '',
    ),
    AIMaturityPhase.learning => const LanguageProfile(
      requiresHedging:            true,
      canUsePatternLanguage:      false,
      canUsePredictionLanguage:   false,
      canAddressAthleteDirectly:  true,
      phaseLabel:    'Early Read',
      openingStyle:  "I've noticed",
      evidencePrefix: "I've been tracking",
    ),
    AIMaturityPhase.calibrated => const LanguageProfile(
      requiresHedging:            false,
      canUsePatternLanguage:      true,
      canUsePredictionLanguage:   false,
      canAddressAthleteDirectly:  true,
      phaseLabel:    "Today's Signal",
      openingStyle:  'You usually',
      evidencePrefix: 'Based on your history',
    ),
    AIMaturityPhase.predictive => const LanguageProfile(
      requiresHedging:            false,
      canUsePatternLanguage:      true,
      canUsePredictionLanguage:   true,
      canAddressAthleteDirectly:  true,
      phaseLabel:    'Strong Read',
      openingStyle:  'I expect',
      evidencePrefix: 'Based on your trend',
    ),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LanguageProfile) return false;
    return other.requiresHedging           == requiresHedging           &&
           other.canUsePatternLanguage      == canUsePatternLanguage      &&
           other.canUsePredictionLanguage   == canUsePredictionLanguage   &&
           other.canAddressAthleteDirectly  == canAddressAthleteDirectly  &&
           other.phaseLabel                 == phaseLabel                 &&
           other.openingStyle               == openingStyle               &&
           other.evidencePrefix             == evidencePrefix;
  }

  @override
  int get hashCode => Object.hash(
    requiresHedging,
    canUsePatternLanguage,
    canUsePredictionLanguage,
    canAddressAthleteDirectly,
    phaseLabel,
    openingStyle,
    evidencePrefix,
  );
}
