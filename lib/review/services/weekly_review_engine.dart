// lib/review/services/weekly_review_engine.dart
//
// WeeklyReviewEngine — orchestrates WeeklyScoreEngine + WeeklySummaryBuilder
// to produce a complete WeeklyReview from existing intelligence outputs.
//
// This engine:
//   - Takes deterministic inputs from the pipeline (no new business logic).
//   - Calls WeeklyScoreEngine to compute scores and grades.
//   - Calls WeeklySummaryBuilder to generate narrative text.
//   - Assembles and returns an immutable WeeklyReview.
//
// No AI. No Provider. No Firebase. No UI. No networking.

import '../../brain/confidence/decision_confidence_engine.dart';
import '../../brain/models/brain_card_data.dart';
import '../../coach/models/coach_message.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../models/weekly_review_data.dart';
import '../../providers/analytics_provider.dart';
import '../models/weekly_review.dart';
import 'weekly_score_engine.dart';
import 'weekly_summary_builder.dart';

class WeeklyReviewEngine {
  const WeeklyReviewEngine();

  static const _summaryBuilder = WeeklySummaryBuilder();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generates a complete [WeeklyReview] from the intelligence pipeline outputs.
  ///
  /// Inputs:
  ///   [reviewData]            — aggregated workout, adherence, and volume signals.
  ///   [athleteMemorySnapshot] — long-term EMA memory (consistency, progression, etc.).
  ///   [brainCardData]         — mission, identity, confidence, and recovery labels.
  ///   [coachMessage]          — coaching intent, tone, warning, and celebration flags.
  ///   [analyticsSnapshot]     — weekly improvement %, plateau, fatigue index.
  ///   [decisionConfidence]    — per-dimension confidence from DecisionConfidenceEngine.
  ///
  /// Returns [WeeklyReview.empty] when [reviewData] has no data.
  WeeklyReview generate({
    required WeeklyReviewData reviewData,
    required AthleteMemorySnapshot athleteMemorySnapshot,
    required BrainCardData brainCardData,
    required BrainCoachMessage coachMessage,
    required AnalyticsSnapshot analyticsSnapshot,
    required DecisionConfidence decisionConfidence,
  }) {
    // Guard: return empty state when no workout data exists yet.
    if (!reviewData.hasData) return WeeklyReview.empty;

    // ── 1. Compute scores ──────────────────────────────────────────────────
    final recoveryScore = WeeklyScoreEngine.computeRecoveryScore(
      reviewData,
      athleteMemorySnapshot,
    );
    final consistencyScore = WeeklyScoreEngine.computeConsistencyScore(
      reviewData,
      athleteMemorySnapshot,
    );
    final progressScore = WeeklyScoreEngine.computeProgressScore(
      reviewData,
      athleteMemorySnapshot,
      analyticsSnapshot,
    );
    final overallScore = WeeklyScoreEngine.computeOverallScore(
      recoveryScore,
      consistencyScore,
      progressScore,
    );

    // ── 2. Derive grades ───────────────────────────────────────────────────
    final recoveryGrade    = WeeklyScoreEngine.grade(recoveryScore);
    final consistencyGrade = WeeklyScoreEngine.grade(consistencyScore);
    final progressGrade    = WeeklyScoreEngine.grade(progressScore);
    final overallGrade     = WeeklyScoreEngine.grade(overallScore);

    // ── 3. Build narrative, achievements, warnings, recommendations ────────
    final summary = _summaryBuilder.build(
      data:             reviewData,
      mem:              athleteMemorySnapshot,
      brainCardData:    brainCardData,
      coachMessage:     coachMessage,
      overallGrade:     overallGrade,
      recoveryGrade:    recoveryGrade,
      consistencyGrade: consistencyGrade,
      progressGrade:    progressGrade,
    );

    final achievements = _summaryBuilder.buildAchievements(reviewData, overallGrade);

    final warnings = _summaryBuilder.buildWarnings(
      data:             reviewData,
      coachMessage:     coachMessage,
      recoveryGrade:    recoveryGrade,
      consistencyGrade: consistencyGrade,
    );

    final recommendations = _summaryBuilder.buildRecommendations(
      recoveryGrade:    recoveryGrade,
      consistencyGrade: consistencyGrade,
      progressGrade:    progressGrade,
      data:             reviewData,
      brainCardData:    brainCardData,
    );

    // ── 4. Next week mission ───────────────────────────────────────────────
    final nextWeekMission = _deriveNextWeekMission(
      overallGrade:     overallGrade,
      recoveryGrade:    recoveryGrade,
      consistencyGrade: consistencyGrade,
      progressGrade:    progressGrade,
      brainCardData:    brainCardData,
      mem:              athleteMemorySnapshot,
      decisionConfidence: decisionConfidence,
    );

    // ── 5. Assemble ────────────────────────────────────────────────────────
    return WeeklyReview(
      recoveryScore:     recoveryScore,
      consistencyScore:  consistencyScore,
      progressScore:     progressScore,
      overallScore:      overallScore,
      recoveryGrade:     recoveryGrade,
      consistencyGrade:  consistencyGrade,
      progressGrade:     progressGrade,
      overallGrade:      overallGrade,
      identityLabel:     brainCardData.identityLabel,
      summary:           summary,
      achievements:      achievements,
      warnings:          warnings,
      recommendations:   recommendations,
      nextWeekMission:   nextWeekMission,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Selects a directional mission statement for the coming week.
  ///
  /// Priority:
  ///   1. Critical recovery → rest/deload mission.
  ///   2. Poor consistency  → habit-building mission.
  ///   3. High confidence + strong grades → push/PR mission.
  ///   4. Moderate grades   → maintain momentum.
  ///   5. Default           → steady progression.
  String _deriveNextWeekMission({
    required WeeklyGrade overallGrade,
    required WeeklyGrade recoveryGrade,
    required WeeklyGrade consistencyGrade,
    required WeeklyGrade progressGrade,
    required BrainCardData brainCardData,
    required AthleteMemorySnapshot mem,
    required DecisionConfidence decisionConfidence,
  }) {
    // P1: Critical recovery
    if (recoveryGrade == WeeklyGrade.D) {
      return 'Protect Recovery — deload or rest to rebuild your base.';
    }

    // P2: Poor consistency
    if (consistencyGrade == WeeklyGrade.D) {
      return 'Build the Habit — complete at least 3 sessions at any intensity.';
    }

    // P3: High confidence + strong recovery + progress
    final isHighConfidence = decisionConfidence.overallConfidence >= 0.72;
    if (isHighConfidence && recoveryGrade.isPositive && progressGrade.isPositive) {
      return 'Push Performance — everything supports a heavier week.';
    }

    // P4: Strong overall but recovery needs care
    if (overallGrade.isPositive && recoveryGrade == WeeklyGrade.C) {
      return 'Maintain Consistency — train at moderate intensity and protect recovery.';
    }

    // P5: Good consistency, progress lagging
    if (consistencyGrade.isPositive && progressGrade.needsWork) {
      return 'Technique Focus — reduce load and refine movement quality.';
    }

    // P6: Memory shows strong progression momentum
    if (mem.progressionVelocity > 0.70 && recoveryGrade.isPositive) {
      return 'Capitalise on Momentum — push the weights this week.';
    }

    // Default
    return 'Maintain Consistency — show up, protect your gains, and build from here.';
  }
}
