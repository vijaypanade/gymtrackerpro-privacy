// lib/review/services/weekly_score_engine.dart
//
// WeeklyScoreEngine — pure deterministic grade computation.
//
// Inputs are normalized to [0, 100] scores before grading.
// All weights and thresholds are constants — no runtime configuration.
// Pure static engine. No state, no side effects.
// No AI. No Provider. No Firebase. No UI.

import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../models/weekly_review_data.dart';
import '../../providers/analytics_provider.dart';
import '../models/weekly_review.dart';

class WeeklyScoreEngine {
  // Private constructor — use static methods only.
  const WeeklyScoreEngine._();

  // ── Grade thresholds (applied to 0–100 scores) ─────────────────────────
  static const double _thresholdS = 88.0;
  static const double _thresholdA = 74.0;
  static const double _thresholdB = 58.0;
  static const double _thresholdC = 42.0;

  // ── Overall weights ─────────────────────────────────────────────────────
  static const double _wRecovery     = 0.35;
  static const double _wConsistency  = 0.35;
  static const double _wProgress     = 0.30;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Computes the recovery score [0, 100] from this week's recovery signals.
  ///
  /// Primary: `overallRecovery` from RecoveryEngine.
  /// Penalty:  5 pts when a limiting muscle is present.
  /// Advisory: recovery velocity from long-term memory (±5 pts).
  static double computeRecoveryScore(
    WeeklyReviewData data,
    AthleteMemorySnapshot mem,
  ) {
    final base    = data.overallRecovery.clamp(0.0, 100.0);
    final penalty = data.limitingMuscle.isNotEmpty ? 5.0 : 0.0;
    final memAdvisory = (mem.recoveryVelocity - 0.5).clamp(-0.5, 0.5) * 10.0;
    return (base - penalty + memAdvisory).clamp(0.0, 100.0);
  }

  /// Computes the consistency score [0, 100] from adherence and habit signals.
  ///
  /// Primary:   adherence this week (60 %).
  /// Secondary: 30-day EMA consistency from AthleteMemory (30 %).
  /// Bonus:     streak (up to +10 pts, 10 %).
  static double computeConsistencyScore(
    WeeklyReviewData data,
    AthleteMemorySnapshot mem,
  ) {
    final adherence = data.adherencePercent.clamp(0.0, 100.0);
    final memC      = (mem.consistencyScore * 100.0).clamp(0.0, 100.0);
    final streak    = (data.currentStreak * 2.0).clamp(0.0, 10.0);
    return (adherence * 0.60 + memC * 0.30 + streak).clamp(0.0, 100.0);
  }

  /// Computes the progress score [0, 100] from improvement and volume signals.
  ///
  /// Baseline:  maps weeklyImprovementPct ∈ [-16, +16] → [0, 100].
  ///            0 % improvement → 50; +16 % → 100; −16 % → 0.
  /// PR bonus:  +7 pts per PR, capped at +21.
  /// Volume:    +5 for positive volume delta; −5 for > 10 % drop.
  /// Memory:    progression velocity advisory ±5 pts.
  static double computeProgressScore(
    WeeklyReviewData data,
    AthleteMemorySnapshot mem,
    AnalyticsSnapshot analytics,
  ) {
    final improvement = analytics.weeklyImprovementPct;
    final base        = (50.0 + improvement * 3.125).clamp(0.0, 100.0);
    final prBonus     = (data.prCount * 7.0).clamp(0.0, 21.0);
    final volBonus    = data.volumeDeltaPercent > 0
        ? 5.0
        : (data.volumeDeltaPercent < -10.0 ? -5.0 : 0.0);
    final memAdvisory = (mem.progressionVelocity - 0.5).clamp(-0.5, 0.5) * 10.0;
    return (base + prBonus + volBonus + memAdvisory).clamp(0.0, 100.0);
  }

  /// Computes the weighted overall score [0, 100].
  static double computeOverallScore(
    double recoveryScore,
    double consistencyScore,
    double progressScore,
  ) {
    return (recoveryScore    * _wRecovery    +
            consistencyScore * _wConsistency +
            progressScore    * _wProgress)
        .clamp(0.0, 100.0);
  }

  /// Converts a 0–100 score to a [WeeklyGrade].
  static WeeklyGrade grade(double score) {
    if (score >= _thresholdS) return WeeklyGrade.S;
    if (score >= _thresholdA) return WeeklyGrade.A;
    if (score >= _thresholdB) return WeeklyGrade.B;
    if (score >= _thresholdC) return WeeklyGrade.C;
    return WeeklyGrade.D;
  }
}
