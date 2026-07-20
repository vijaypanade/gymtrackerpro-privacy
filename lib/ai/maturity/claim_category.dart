// lib/ai/maturity/claim_category.dart
// Pure Dart — no Flutter imports.

/// Canonical vocabulary for AI authority levels across all LiftOn surfaces.
///
/// Every AI-generated claim belongs to exactly one category. This enum
/// establishes the shared language across generators, prompt builders,
/// and future validators — without creating a full registry or runtime
/// enforcement mechanism.
///
/// Usage: prompt builders annotate their injection sections with the
/// corresponding category so the epistemic level of each claim is explicit
/// in the code and readable to the next engineer.
///
/// Claim authority increases monotonically from [data] to [validation].
/// A surface must never emit a claim at a level it has not yet earned.
enum ClaimCategory {
  /// A raw numerical or factual signal. No AI interpretation required.
  ///
  /// Examples: recovery score 72%, 14 sessions logged, 3-day streak.
  /// Gate: always permitted — facts are never speculative.
  data,

  /// A tentative first-person observation from limited evidence.
  ///
  /// Examples: "I've noticed your recovery improving this week."
  /// Gate: [AllowedClaimsContent.canMakeObservation]
  observation,

  /// A confirmed personal pattern across multiple training cycles.
  ///
  /// Examples: "You usually recover faster after pull workouts."
  /// Gate: [AllowedClaimsContent.canMakePatternClaim]
  pattern,

  /// A forward projection beyond the current data window.
  ///
  /// Examples: "I expect this week to be a strong push period."
  /// Gate: [AllowedClaimsContent.canMakePrediction]
  prediction,

  /// A direct actionable recommendation derived from personal context.
  ///
  /// Examples: "Reduce today's volume — recovery is suppressed."
  /// Gate: [AllowedClaimsContent.canMakePrescription]
  prescription,

  /// An acknowledged improvement or confirmed personal milestone.
  ///
  /// Examples: "You've improved your consistency meaningfully."
  /// Gate: [AllowedClaimsContent.canMakePatternClaim] (requires confirmed evidence)
  validation,
}
