// lib/ai/maturity/ai_maturity_input.dart
// Pure Dart — no Flutter imports.

/// All signals consumed by [AIMaturityEngine.evaluate].
///
/// Every field uses a value already available in AppProvider.
/// Fields not yet established in a given session default to safe
/// conservative values — the engine handles every combination without
/// throwing.
class AIMaturityInput {
  /// Total workouts ever completed.
  ///
  /// Primary minimum floor signal. No phase beyond Baseline is possible
  /// without a workout count above the phase's floor.
  final int totalWorkouts;

  /// Synthesised confidence from DecisionConfidenceEngine (0.0–1.0).
  ///
  /// Defaults to 0.0 when no brain data has been computed yet (totalWorkouts == 0).
  /// This is the primary quality gate that separates Calibrated from Learning
  /// for athletes with the same workout count but different data richness.
  final double overallConfidence;

  /// Athlete consistency score (0–100) from AthleteMemory.
  ///
  /// Reflects regularity of training as a percentage of planned sessions
  /// completed over the past 30 days. Gate for Predictive phase — sporadic
  /// athletes do not reach Predictive regardless of workout count.
  final int consistencyScore;

  /// Whether a personal HRV baseline has been established from health data.
  ///
  /// True only after sufficient Apple Watch or compatible sensor readings.
  /// Informs whether biometric-grounded recovery claims are supportable.
  final bool hrvBaselineAvailable;

  /// Days elapsed since the last completed workout.
  ///
  /// Included for the future maturity decay mechanism. In Phase 1 this
  /// field is recorded but not yet used to regress phase. The decay
  /// logic will compare this against phase-specific recency windows.
  final int daysSinceLastWorkout;

  const AIMaturityInput({
    required this.totalWorkouts,
    this.overallConfidence    = 0.0,
    this.consistencyScore     = 0,
    this.hrvBaselineAvailable = false,
    this.daysSinceLastWorkout = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AIMaturityInput) return false;
    return other.totalWorkouts        == totalWorkouts        &&
           other.overallConfidence    == overallConfidence    &&
           other.consistencyScore     == consistencyScore     &&
           other.hrvBaselineAvailable == hrvBaselineAvailable &&
           other.daysSinceLastWorkout == daysSinceLastWorkout;
  }

  @override
  int get hashCode => Object.hash(
    totalWorkouts,
    overallConfidence,
    consistencyScore,
    hrvBaselineAvailable,
    daysSinceLastWorkout,
  );
}
