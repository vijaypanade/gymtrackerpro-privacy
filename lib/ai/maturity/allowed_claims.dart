// lib/ai/maturity/allowed_claims.dart
// Pure Dart — no Flutter imports.

/// UI-level capability set — governs widget visibility.
///
/// Each flag answers: "Is it appropriate to show this element at the current
/// maturity level?" These are binary show/hide decisions, not content decisions.
///
/// Consumed by display surfaces. Never touch raw threshold data.
class AllowedClaimsUi {
  /// Whether trend arrows (improving / declining) may be shown.
  final bool canShowTrendArrow;

  /// Whether the "Why this?" toggle may appear on Athlete Brain.
  /// Requires dominant signals to be confirmed — Calibrated+ only.
  final bool canShowWhyToggle;

  /// Whether the Weekly Story CTA is meaningful enough to display.
  final bool canShowWeeklyStory;

  /// Whether the dominant signals list may appear in the Brain expansion panel.
  final bool canShowDominantSignals;

  /// Whether SessionProphecyCard may appear in the planner.
  /// Requires full predictive confidence — wrong prophecy destroys trust.
  final bool canShowSessionProphecy;

  /// Whether Adaptive Sessions may INCREASE load (not just reduce).
  /// Increases imply the AI knows the athlete well enough to push them.
  /// Reductions are always permitted; they are handled outside this flag.
  final bool canShowAdaptiveIncrease;

  /// Whether the calibration progress arc should be shown.
  /// Shown during Learning to communicate progress toward Calibrated.
  /// Hidden at Calibrated and above — the arc has served its purpose.
  final bool canShowConfidenceArc;

  const AllowedClaimsUi({
    required this.canShowTrendArrow,
    required this.canShowWhyToggle,
    required this.canShowWeeklyStory,
    required this.canShowDominantSignals,
    required this.canShowSessionProphecy,
    required this.canShowAdaptiveIncrease,
    required this.canShowConfidenceArc,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AllowedClaimsUi) return false;
    return other.canShowTrendArrow       == canShowTrendArrow       &&
           other.canShowWhyToggle        == canShowWhyToggle        &&
           other.canShowWeeklyStory      == canShowWeeklyStory      &&
           other.canShowDominantSignals  == canShowDominantSignals  &&
           other.canShowSessionProphecy  == canShowSessionProphecy  &&
           other.canShowAdaptiveIncrease == canShowAdaptiveIncrease &&
           other.canShowConfidenceArc    == canShowConfidenceArc;
  }

  @override
  int get hashCode => Object.hash(
    canShowTrendArrow,
    canShowWhyToggle,
    canShowWeeklyStory,
    canShowDominantSignals,
    canShowSessionProphecy,
    canShowAdaptiveIncrease,
    canShowConfidenceArc,
  );
}

/// Content-level capability set — governs what language the AI may use.
///
/// Each flag answers: "Is the AI currently permitted to make this type of
/// statement?" These govern the epistemic register of generated text —
/// whether from templates, rule engines, or AI models.
///
/// Every generated claim must be validated against the appropriate flag
/// before reaching any display surface.
class AllowedClaimsContent {
  /// Whether the AI may report a tentative observation.
  /// Example: "I've noticed your recovery has improved this week."
  final bool canMakeObservation;

  /// Whether the AI may state a confirmed personal pattern.
  /// Example: "You usually recover faster after pull workouts."
  final bool canMakePatternClaim;

  /// Whether the AI may make a forward projection.
  /// Example: "I expect tomorrow to be a strong push day."
  final bool canMakePrediction;

  /// Whether the AI may issue a direct prescription.
  /// Example: "Reduce today's volume — recovery is at 62."
  final bool canMakePrescription;

  /// Whether the AI may cite a specific past session.
  /// Example: "After last Thursday's session…"
  final bool canReferenceHistory;

  /// Whether the AI may address the athlete in second person ("you" / "your").
  /// At Baseline: "The score suggests…" not "You're ready."
  final bool canAddressAthleteDirectly;

  /// Whether the AI may compare this session to a prior similar one.
  /// Example: "This is lighter than your average for chest day."
  final bool canCompareSessions;

  /// Whether the AI may use directional trend language.
  /// Example: "improving", "declining" — requires confirmed trend data.
  final bool canUseTrendLanguage;

  /// Whether personal training history may be injected into AI Chat context.
  /// False at Baseline: the AI must not generate pattern claims from thin data.
  final bool canInjectPersonalContext;

  const AllowedClaimsContent({
    required this.canMakeObservation,
    required this.canMakePatternClaim,
    required this.canMakePrediction,
    required this.canMakePrescription,
    required this.canReferenceHistory,
    required this.canAddressAthleteDirectly,
    required this.canCompareSessions,
    required this.canUseTrendLanguage,
    required this.canInjectPersonalContext,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AllowedClaimsContent) return false;
    return other.canMakeObservation        == canMakeObservation        &&
           other.canMakePatternClaim       == canMakePatternClaim       &&
           other.canMakePrediction         == canMakePrediction         &&
           other.canMakePrescription       == canMakePrescription       &&
           other.canReferenceHistory       == canReferenceHistory       &&
           other.canAddressAthleteDirectly == canAddressAthleteDirectly &&
           other.canCompareSessions        == canCompareSessions        &&
           other.canUseTrendLanguage       == canUseTrendLanguage       &&
           other.canInjectPersonalContext  == canInjectPersonalContext;
  }

  @override
  int get hashCode => Object.hash(
    canMakeObservation,
    canMakePatternClaim,
    canMakePrediction,
    canMakePrescription,
    canReferenceHistory,
    canAddressAthleteDirectly,
    canCompareSessions,
    canUseTrendLanguage,
    canInjectPersonalContext,
  );
}

/// The complete capability contract for the current AI maturity state.
///
/// Split into [ui] (widget visibility) and [content] (language permission)
/// namespaces so call sites immediately communicate their intent.
///
/// Usage at a surface:
///   if (appProvider.aiMaturity.allowedClaims.ui.canShowWhyToggle) { … }
///   if (appProvider.aiMaturity.allowedClaims.content.canMakePatternClaim) { … }
class AllowedClaims {
  final AllowedClaimsUi      ui;
  final AllowedClaimsContent content;

  const AllowedClaims({
    required this.ui,
    required this.content,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AllowedClaims) return false;
    return other.ui == ui && other.content == content;
  }

  @override
  int get hashCode => Object.hash(ui, content);
}
