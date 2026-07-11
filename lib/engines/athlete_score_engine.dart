// lib/engines/athlete_score_engine.dart
//
// Pure deterministic scoring engine. No AI, no Provider, no Firebase, no UI.
// All inputs are normalized [0, 1]. Output scores are scaled to [0, 100].
//
// Weights:
//   Consistency    25 %
//   Adherence      20 %
//   Reliability    15 %
//   Recovery       15 %
//   Progression    15 %
//   VolumeTolerance 10 %

// ── Output ────────────────────────────────────────────────────────────────────

/// Immutable composite score derived from AthleteMemorySnapshot signals.
///
/// All score fields are in [0, 100].
/// confidence reflects how many signals have meaningful data (moved off zero).
class AthleteScore {
  /// Weighted composite of all six input signals.
  final double overallScore;

  /// Discipline composite: consistency (25 %) + adherence (20 %) + reliability (15 %).
  final double disciplineScore;

  /// Recovery composite: recoveryVelocity (15 %).
  /// Isolated so callers can track the recovery dimension independently.
  final double recoveryScore;

  /// Progression composite: progressionVelocity (15 %).
  final double progressionScore;

  /// Consistency dimension score — direct pass-through scaled to 0–100.
  final double consistencyScore;

  /// Fraction of input signals that have moved off their default zero/mid
  /// baseline, expressed as 0–1. A score of 1.0 means all six inputs carry
  /// meaningful observed data.
  final double confidence;

  const AthleteScore({
    required this.overallScore,
    required this.disciplineScore,
    required this.recoveryScore,
    required this.progressionScore,
    required this.consistencyScore,
    required this.confidence,
  });

  @override
  String toString() =>
      'AthleteScore(overall:${overallScore.toStringAsFixed(1)} '
      'discipline:${disciplineScore.toStringAsFixed(1)} '
      'recovery:${recoveryScore.toStringAsFixed(1)} '
      'progression:${progressionScore.toStringAsFixed(1)} '
      'consistency:${consistencyScore.toStringAsFixed(1)} '
      'confidence:${confidence.toStringAsFixed(2)})';
}

// ── Engine ────────────────────────────────────────────────────────────────────

/// Computes AthleteScore from normalized [0, 1] memory signals.
///
/// Static — no state, no side effects. Suitable for calling on every frame
/// if needed; all operations are O(1) arithmetic.
class AthleteScoreEngine {
  // Weight constants — must sum to 1.0.
  static const double _wConsistency     = 0.25;
  static const double _wAdherence       = 0.20;
  static const double _wReliability     = 0.15;
  static const double _wRecovery        = 0.15;
  static const double _wProgression     = 0.15;
  static const double _wVolumeTolerance = 0.10;

  // Confidence threshold — inputs above this are considered "observed".
  // Signals initialized to 0.0 (consistency, adherence, reliability) are
  // treated as not-yet-observed; mid-point defaults (0.5) also unobserved.
  static const double _observedThreshold = 0.01;

  const AthleteScoreEngine._();

  /// Computes an [AthleteScore] from the six normalized input signals.
  ///
  /// All inputs must be in [0, 1]; values outside that range are clamped.
  static AthleteScore compute({
    required double consistencyScore,
    required double adherenceScore,
    required double reliabilityScore,
    required double recoveryVelocity,
    required double progressionVelocity,
    required double volumeTolerance,
  }) {
    // Clamp all inputs to [0, 1].
    final c  = consistencyScore.clamp(0.0, 1.0);
    final ad = adherenceScore.clamp(0.0, 1.0);
    final r  = reliabilityScore.clamp(0.0, 1.0);
    final rv = recoveryVelocity.clamp(0.0, 1.0);
    final pv = progressionVelocity.clamp(0.0, 1.0);
    final vt = volumeTolerance.clamp(0.0, 1.0);

    // Weighted composite → scale to [0, 100].
    final overall = (c  * _wConsistency +
                     ad * _wAdherence   +
                     r  * _wReliability +
                     rv * _wRecovery    +
                     pv * _wProgression +
                     vt * _wVolumeTolerance) * 100.0;

    // Discipline dimension: consistency + adherence + reliability.
    final discipline = (c  * _wConsistency +
                        ad * _wAdherence   +
                        r  * _wReliability) /
                       (_wConsistency + _wAdherence + _wReliability) * 100.0;

    // Recovery dimension: recoveryVelocity only (isolated for independent tracking).
    final recovery = rv * 100.0;

    // Progression dimension: progressionVelocity only.
    final progression = pv * 100.0;

    // Consistency dimension: direct pass-through.
    final consistency = c * 100.0;

    // Confidence: fraction of signals with observed (non-default) data.
    // Zero-initialized signals (c, ad, r) start at 0.0 → not observed.
    // Mid-point default signals (rv, pv, vt start at 0.5) are considered
    // unobserved until they move more than _observedThreshold off 0.5.
    final observedCount = [
      c  > _observedThreshold,
      ad > _observedThreshold,
      r  > _observedThreshold,
      (rv - 0.5).abs() > _observedThreshold,
      (pv - 0.5).abs() > _observedThreshold,
      (vt - 0.5).abs() > _observedThreshold,
    ].where((observed) => observed).length;

    final confidence = observedCount / 6.0;

    return AthleteScore(
      overallScore:     overall,
      disciplineScore:  discipline,
      recoveryScore:    recovery,
      progressionScore: progression,
      consistencyScore: consistency,
      confidence:       confidence,
    );
  }
}
