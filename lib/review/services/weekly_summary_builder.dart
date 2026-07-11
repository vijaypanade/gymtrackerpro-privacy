// lib/review/services/weekly_summary_builder.dart
//
// WeeklySummaryBuilder — generates deterministic narrative text for the
// weekly report. No AI. No Provider. No Firebase. No UI.
//
// Text is selected via grade combination rules. The same input always
// produces the same output.

import '../../brain/models/brain_card_data.dart';
import '../../coach/models/coach_message.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../models/weekly_review_data.dart';
import '../models/weekly_recommendation.dart';
import '../models/weekly_review.dart';
import '../models/weekly_summary.dart';

class WeeklySummaryBuilder {
  const WeeklySummaryBuilder();

  // ── Public API ────────────────────────────────────────────────────────────

  WeeklySummary build({
    required WeeklyReviewData data,
    required AthleteMemorySnapshot mem,
    required BrainCardData brainCardData,
    required BrainCoachMessage coachMessage,
    required WeeklyGrade overallGrade,
    required WeeklyGrade recoveryGrade,
    required WeeklyGrade consistencyGrade,
    required WeeklyGrade progressGrade,
  }) {
    return WeeklySummary(
      headline:      _headline(overallGrade, data),
      bodyText:      _body(overallGrade, recoveryGrade, consistencyGrade, progressGrade, data),
      coachLine:     _coachLine(coachMessage, overallGrade, data),
      nextWeekFocus: _nextWeekFocus(recoveryGrade, consistencyGrade, progressGrade, mem),
    );
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  List<String> buildAchievements(WeeklyReviewData data, WeeklyGrade overallGrade) {
    final list = <String>[];
    if (data.prCount > 0) {
      final s = data.prCount == 1 ? '' : 's';
      list.add('${data.prCount} personal record$s set this week');
    }
    if (data.adherencePercent >= 100.0) {
      list.add('Completed every planned session');
    } else if (data.adherencePercent >= 80.0) {
      list.add('Strong session adherence this week');
    }
    if (data.currentStreak >= 14) {
      list.add('${data.currentStreak}-day training streak');
    } else if (data.currentStreak >= 7) {
      list.add('7+ day training streak maintained');
    }
    if (data.volumeDeltaPercent >= 5.0) {
      list.add('Volume up ${data.volumeDeltaPercent.round()}% vs last week');
    }
    if (overallGrade == WeeklyGrade.S) {
      list.add('Exceptional overall week — all signals aligned');
    }
    return list;
  }

  // ── Warnings ─────────────────────────────────────────────────────────────

  List<String> buildWarnings({
    required WeeklyReviewData data,
    required BrainCoachMessage coachMessage,
    required WeeklyGrade recoveryGrade,
    required WeeklyGrade consistencyGrade,
  }) {
    final list = <String>[];
    if (recoveryGrade == WeeklyGrade.D) {
      list.add('Recovery score is critically low — consider a full deload next week');
    } else if (recoveryGrade == WeeklyGrade.C) {
      list.add('Recovery is below target — prioritise sleep and nutrition');
    }
    if (data.limitingMuscle.isNotEmpty) {
      list.add('${_cap(data.limitingMuscle)} needs recovery time before next session');
    }
    if (coachMessage.hasWarning) {
      list.add('Active recovery warning: protect your body before pushing again');
    }
    if (data.volumeDeltaPercent < -15.0) {
      list.add('Volume dropped significantly — check session completion');
    }
    if (consistencyGrade == WeeklyGrade.D && data.plannedSessions > 0) {
      list.add('Missed sessions this week — consistency is the foundation of progress');
    }
    return list;
  }

  // ── Recommendations ───────────────────────────────────────────────────────

  List<WeeklyRecommendation> buildRecommendations({
    required WeeklyGrade recoveryGrade,
    required WeeklyGrade consistencyGrade,
    required WeeklyGrade progressGrade,
    required WeeklyReviewData data,
    required BrainCardData brainCardData,
  }) {
    final list = <WeeklyRecommendation>[];

    // Recovery recommendations — safety first
    if (recoveryGrade == WeeklyGrade.D) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.rest,
        title:    'Take a deload or rest week',
        detail:   'Recovery is critically low. Reduce volume by 40–50% or take a full rest week.',
        isUrgent: true,
      ));
    } else if (recoveryGrade == WeeklyGrade.C) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.recovery,
        title:    'Prioritise recovery next week',
        detail:   'Train at reduced intensity and focus on sleep and nutrition.',
        isUrgent: false,
      ));
    }

    // Consistency recommendations
    if (consistencyGrade.needsWork) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.consistency,
        title:    'Set a fixed training schedule',
        detail:   'Missing sessions breaks momentum. Pick 3 days and protect them.',
        isUrgent: false,
      ));
    }

    // Progress recommendations
    if (progressGrade == WeeklyGrade.S || progressGrade == WeeklyGrade.A) {
      if (recoveryGrade.isPositive) {
        list.add(const WeeklyRecommendation(
          type:     RecommendationType.push,
          title:    'Push for new personal records next week',
          detail:   'Progression is strong and recovery supports it. Use this window.',
          isUrgent: false,
        ));
      }
    } else if (progressGrade == WeeklyGrade.C || progressGrade == WeeklyGrade.D) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.technique,
        title:    'Refocus on movement quality',
        detail:   'Progress is stalling. Review form and reduce load to build a stronger base.',
        isUrgent: false,
      ));
    }

    // Volume recommendation
    if (data.volumeDeltaPercent >= 10.0 && recoveryGrade.needsWork) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.volume,
        title:    'Volume is high — watch fatigue accumulation',
        detail:   'High volume with low recovery is an overreaching risk. Plan a lighter week.',
        isUrgent: false,
      ));
    } else if (data.volumeDeltaPercent < -5.0 && consistencyGrade.needsWork) {
      list.add(const WeeklyRecommendation(
        type:     RecommendationType.volume,
        title:    'Rebuild training volume gradually',
        detail:   'Volume dropped this week. Start with your base plan before adding load.',
        isUrgent: false,
      ));
    }

    return list;
  }

  // ── Private text builders ──────────────────────────────────────────────────

  String _headline(WeeklyGrade grade, WeeklyReviewData data) {
    switch (grade) {
      case WeeklyGrade.S: return 'Exceptional Week';
      case WeeklyGrade.A:
        return data.prCount > 0 ? 'Strong Week — PRs Set' : 'Strong Training Week';
      case WeeklyGrade.B:
        return data.adherencePercent >= 80 ? 'Solid Consistency' : 'Solid Week';
      case WeeklyGrade.C: return 'Room to Improve';
      case WeeklyGrade.D: return 'Tough Week — Reset and Rebuild';
    }
  }

  String _body(
    WeeklyGrade overall,
    WeeklyGrade recovery,
    WeeklyGrade consistency,
    WeeklyGrade progress,
    WeeklyReviewData data,
  ) {
    final buf = StringBuffer();

    // Lead sentence — overall frame
    switch (overall) {
      case WeeklyGrade.S:
        buf.write('All three pillars — recovery, consistency, and progress — fired this week. ');
        break;
      case WeeklyGrade.A:
        buf.write('This was a strong week across the board with solid contributions from all signal areas. ');
        break;
      case WeeklyGrade.B:
        buf.write('A decent week with room to sharpen one or two areas going forward. ');
        break;
      case WeeklyGrade.C:
        buf.write('This week highlighted some gaps worth addressing before they compound. ');
        break;
      case WeeklyGrade.D:
        buf.write('A difficult week — the data points to overreaching, missed sessions, or both. ');
        break;
    }

    // Recovery sentence
    if (recovery.needsWork) {
      buf.write('Recovery signals were below target — rest and nutrition should be the priority. ');
    } else if (recovery.isPositive) {
      buf.write('Recovery was strong, which underpins everything else. ');
    }

    // Consistency sentence
    if (data.completedSessions > 0 && data.plannedSessions > 0) {
      final completedStr = '${data.completedSessions}/${data.plannedSessions}';
      if (consistency.isPositive) {
        buf.write('Completing $completedStr sessions shows reliable habit formation. ');
      } else {
        buf.write('Only $completedStr planned sessions were completed — consistency is the lever. ');
      }
    }

    // Progress sentence
    if (data.prCount > 0) {
      final s = data.prCount == 1 ? 'a personal record' : '${data.prCount} personal records';
      buf.write('Setting $s confirms the training stimulus is working.');
    } else if (progress.isPositive) {
      buf.write('Progression signals are trending in the right direction.');
    } else {
      buf.write('No new personal records this week — focus on consistency and recovery first.');
    }

    return buf.toString().trim();
  }

  String _coachLine(BrainCoachMessage msg, WeeklyGrade grade, WeeklyReviewData data) {
    if (msg.isCelebration && grade.isPositive) {
      return 'Strong week. Keep the rhythm.';
    }
    if (msg.hasWarning) {
      return 'Your body asked for rest. Listen to it.';
    }
    switch (grade) {
      case WeeklyGrade.S:
        return 'Weeks like this add up. Same again next week.';
      case WeeklyGrade.A:
        return 'You showed up and delivered. Keep the standard.';
      case WeeklyGrade.B:
        return 'Solid week. One small step up next week.';
      case WeeklyGrade.C:
        return 'Not every week is smooth. Reset and go again.';
      case WeeklyGrade.D:
        return 'Hard week. Rest up and come back.';
    }
  }

  String _nextWeekFocus(
    WeeklyGrade recovery,
    WeeklyGrade consistency,
    WeeklyGrade progress,
    AthleteMemorySnapshot mem,
  ) {
    if (recovery == WeeklyGrade.D) {
      return 'Focus: Recovery first. Deload week.';
    }
    if (recovery == WeeklyGrade.C) {
      return 'Focus: Recovery. Lighter training, more sleep.';
    }
    if (consistency.needsWork) {
      return 'Focus: Consistency. Just show up.';
    }
    if (progress == WeeklyGrade.S && recovery.isPositive) {
      return 'Focus: Strength. Go for new PRs.';
    }
    if (progress.needsWork) {
      return 'Focus: Rebuild. Lighter loads, better reps.';
    }
    if (mem.progressionVelocity > 0.70 && recovery.isPositive) {
      return 'Focus: Add weight. Keep building.';
    }
    return 'Focus: Consistency. Protect what you built.';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
