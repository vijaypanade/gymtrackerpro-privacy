// lib/review/models/weekly_review.dart
//
// WeeklyReview — the complete immutable output of WeeklyReviewEngine.
// Contains scores, grades, narrative, achievements, warnings, and
// next-week mission. No AI. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

import 'weekly_recommendation.dart';
import 'weekly_summary.dart';

// ── Grade ─────────────────────────────────────────────────────────────────────

/// Letter-grade scale applied to each score dimension and overall.
///
/// Thresholds (applied to 0–100 scores):
///   S  ≥ 88   — exceptional
///   A  ≥ 74   — strong
///   B  ≥ 58   — solid
///   C  ≥ 42   — needs improvement
///   D  < 42   — poor
enum WeeklyGrade { S, A, B, C, D }

extension WeeklyGradeX on WeeklyGrade {
  String get label {
    switch (this) {
      case WeeklyGrade.S: return 'S — Exceptional';
      case WeeklyGrade.A: return 'A — Strong';
      case WeeklyGrade.B: return 'B — Solid';
      case WeeklyGrade.C: return 'C — Needs Work';
      case WeeklyGrade.D: return 'D — Poor';
    }
  }

  /// Single letter displayed in the grade badge.
  String get letter {
    switch (this) {
      case WeeklyGrade.S: return 'S';
      case WeeklyGrade.A: return 'A';
      case WeeklyGrade.B: return 'B';
      case WeeklyGrade.C: return 'C';
      case WeeklyGrade.D: return 'D';
    }
  }

  bool get isPositive => this == WeeklyGrade.S || this == WeeklyGrade.A;
  bool get needsWork  => this == WeeklyGrade.C || this == WeeklyGrade.D;
}

// ── WeeklyReview ──────────────────────────────────────────────────────────────

@immutable
class WeeklyReview {
  // ── Scores (0–100) ──────────────────────────────────────────────────────
  final double recoveryScore;
  final double consistencyScore;
  final double progressScore;
  final double overallScore;

  // ── Grades ──────────────────────────────────────────────────────────────
  final WeeklyGrade recoveryGrade;
  final WeeklyGrade consistencyGrade;
  final WeeklyGrade progressGrade;
  final WeeklyGrade overallGrade;

  // ── Identity ─────────────────────────────────────────────────────────────
  /// Long-term identity label derived from AthleteMemory.
  final String identityLabel;

  // ── Narrative ────────────────────────────────────────────────────────────
  final WeeklySummary summary;

  // ── Achievements ─────────────────────────────────────────────────────────
  /// Positive events this week (PRs, streaks, adherence milestones).
  final List<String> achievements;

  // ── Warnings ─────────────────────────────────────────────────────────────
  /// Risk or safety signals that need the athlete's attention.
  final List<String> warnings;

  // ── Recommendations ──────────────────────────────────────────────────────
  /// Ordered list of actionable recommendations for next week.
  final List<WeeklyRecommendation> recommendations;

  // ── Next week ────────────────────────────────────────────────────────────
  /// Single mission statement for the coming week.
  final String nextWeekMission;

  const WeeklyReview({
    required this.recoveryScore,
    required this.consistencyScore,
    required this.progressScore,
    required this.overallScore,
    required this.recoveryGrade,
    required this.consistencyGrade,
    required this.progressGrade,
    required this.overallGrade,
    required this.identityLabel,
    required this.summary,
    required this.achievements,
    required this.warnings,
    required this.recommendations,
    required this.nextWeekMission,
  });

  /// Safe empty state — zero history, no data collected yet.
  static const WeeklyReview empty = WeeklyReview(
    recoveryScore:     0,
    consistencyScore:  0,
    progressScore:     0,
    overallScore:      0,
    recoveryGrade:     WeeklyGrade.D,
    consistencyGrade:  WeeklyGrade.D,
    progressGrade:     WeeklyGrade.D,
    overallGrade:      WeeklyGrade.D,
    identityLabel:     'building foundation',
    summary: WeeklySummary(
      headline:      'No data yet',
      bodyText:      'Complete your first training sessions to unlock your weekly review.',
      coachLine:     'Log a few workouts. Your weekly review starts there.',
      nextWeekFocus: 'Focus: Show up and complete your first week.',
    ),
    achievements:    [],
    warnings:        [],
    recommendations: [],
    nextWeekMission: 'Begin your training journey.',
  );

  bool get hasData => overallScore > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklyReview) return false;
    return other.recoveryScore    == recoveryScore    &&
           other.consistencyScore == consistencyScore &&
           other.progressScore    == progressScore    &&
           other.overallScore     == overallScore     &&
           other.overallGrade     == overallGrade     &&
           other.identityLabel    == identityLabel    &&
           other.nextWeekMission  == nextWeekMission;
  }

  @override
  int get hashCode => Object.hash(
    recoveryScore, consistencyScore, progressScore,
    overallScore, overallGrade, identityLabel, nextWeekMission,
  );

  @override
  String toString() =>
      'WeeklyReview(overall:${overallScore.toStringAsFixed(1)} '
      'grade:${overallGrade.letter} '
      'recovery:${recoveryGrade.letter} '
      'consistency:${consistencyGrade.letter} '
      'progress:${progressGrade.letter})';
}
