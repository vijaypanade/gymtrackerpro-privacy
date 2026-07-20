// lib/ai/maturity/ai_maturity_phase.dart
// Pure Dart — no Flutter imports.

/// The four observable phases of AI maturity.
///
/// Each phase represents a qualitatively different coaching relationship.
/// Phases advance based on evidence accumulation and confidence; they never
/// advance on elapsed time alone.
enum AIMaturityPhase {
  /// No personal data. AI reports raw scores only.
  baseline,

  /// First observations forming. AI uses tentative, evidenced language.
  learning,

  /// Patterns confirmed across enough training cycles.
  /// AI makes direct personal claims anchored to specific evidence.
  calibrated,

  /// Sufficient trend history for forward projection.
  /// AI can anticipate needs before the athlete notices them.
  predictive;

  /// Human-readable label for logging, instrumentation, and future UI use.
  String get label => switch (this) {
    AIMaturityPhase.baseline   => 'Baseline',
    AIMaturityPhase.learning   => 'Learning',
    AIMaturityPhase.calibrated => 'Calibrated',
    AIMaturityPhase.predictive => 'Predictive',
  };

  /// Returns true if this phase is at or beyond [minimum].
  bool isAtLeast(AIMaturityPhase minimum) => index >= minimum.index;
}
