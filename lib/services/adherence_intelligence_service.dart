// lib/services/adherence_intelligence_service.dart
// Pure Dart — no Flutter imports.
// Detects behavioral adherence patterns: burnout, intimidation, motivation, comeback.
//
// SAFETY CONTRACT:
//   No shame, no guilt, no toxic streak pressure.
//   All copy is observational, supportive, or disciplined — never manipulative.

import 'dart:math';
import '../models/models.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Internal classification — NOT exposed directly to users.
/// Governs coach tone and nudge strategy.
enum ConsistencyIdentity {
  disciplinedBuilder,
  weekendWarrior,
  streakChaser,
  inconsistentSprinter,
  burnoutProne,
  momentumAthlete,
}

enum BurnoutRisk { none, low, moderate, high }

enum StreakFragility { resilient, normal, fragile, critical }

enum IntimidationRisk { none, low, moderate, high }

enum MotivationTrend { rising, stable, dipping, dropping }

enum PreferredSessionStyle { longIntense, moderate, short, variable }

// ── Output model ─────────────────────────────────────────────────────────────

class AdherenceProfile {
  /// Internal identity — governs tone, not shown to users.
  final ConsistencyIdentity   consistencyIdentity;
  final BurnoutRisk           burnoutRisk;
  final StreakFragility        streakFragility;
  final IntimidationRisk      intimidationRisk;
  final MotivationTrend       motivationTrend;
  /// 0–1 probability the athlete will return if currently inactive.
  final double                comebackProbability;
  /// 0–100 composite behavioral discipline score.
  final int                   disciplineScore;
  final PreferredSessionStyle preferredSessionStyle;
  /// One observational line — empty when no significant signal is present.
  final String                adherenceInsight;
  final DateTime              computedAt;

  const AdherenceProfile({
    required this.consistencyIdentity,
    required this.burnoutRisk,
    required this.streakFragility,
    required this.intimidationRisk,
    required this.motivationTrend,
    required this.comebackProbability,
    required this.disciplineScore,
    required this.preferredSessionStyle,
    required this.adherenceInsight,
    required this.computedAt,
  });

  static AdherenceProfile get empty => AdherenceProfile(
    consistencyIdentity:  ConsistencyIdentity.disciplinedBuilder,
    burnoutRisk:          BurnoutRisk.none,
    streakFragility:      StreakFragility.normal,
    intimidationRisk:     IntimidationRisk.none,
    motivationTrend:      MotivationTrend.stable,
    comebackProbability:  0.7,
    disciplineScore:      60,
    preferredSessionStyle: PreferredSessionStyle.moderate,
    adherenceInsight:     '',
    computedAt:           DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Input contract ────────────────────────────────────────────────────────────

class AdherenceInsightInput {
  /// Recent workout history (newest first, up to 30 days).
  final List<HistoryEntry> recentHistory;
  final int                consistencyScore;       // 0–100
  final int                missedWorkoutsLast30;
  /// From AthleteMemory: 'normal' | 'recovers_fast' | 'fatigues_after_3_days' | ...
  final String             fatiguePattern;
  final List<String>       motivationalTriggers;
  /// Typical days before momentum drops (-1 = unknown).
  final int                fatigueCollapseAfterDays;
  final int                currentStreak;
  final int                longestStreak;
  final int                totalWorkouts;
  final int                daysSinceLastWorkout;
  final List<String>       skippedMuscleGroups;
  final double             recoveryScore;          // 0–100
  final bool               highFatigue;
  final bool               needsDeload;
  final String             recoveryTrend;          // 'improving'|'stable'|'declining'
  final double             overTrainingRisk;       // 0–100
  /// Ordinal index of OverreachingRisk enum (0=none … 3=high).
  final int                overreachingRiskLevel;
  /// Ordinal index of ConsistencyTrend enum (0=declining … 3=building).
  final int                consistencyTrendLevel;
  /// Ordinal index of MomentumLevel enum (0=declining … 3=peaking).
  final int                momentumLevel;
  final int                prsLast21Days;
  final DateTime           now;

  const AdherenceInsightInput({
    required this.recentHistory,
    required this.consistencyScore,
    required this.missedWorkoutsLast30,
    required this.fatiguePattern,
    required this.motivationalTriggers,
    required this.fatigueCollapseAfterDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalWorkouts,
    required this.daysSinceLastWorkout,
    required this.skippedMuscleGroups,
    required this.recoveryScore,
    required this.highFatigue,
    required this.needsDeload,
    required this.recoveryTrend,
    required this.overTrainingRisk,
    required this.overreachingRiskLevel,
    required this.consistencyTrendLevel,
    required this.momentumLevel,
    required this.prsLast21Days,
    required this.now,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class AdherenceIntelligenceService {
  AdherenceIntelligenceService._();

  static AdherenceProfile compute(AdherenceInsightInput i) {
    if (i.totalWorkouts < 3) return AdherenceProfile.empty;

    // ── Duration analysis ─────────────────────────────────────────────────
    final avg    = _avgDuration(i.recentHistory);
    final recent = _recentAvgDuration(i.recentHistory, 4);
    final abandonRate = _abandonmentRate(i.recentHistory);
    final avgGap = _averageGapDays(i.recentHistory);

    // ── Core detections ───────────────────────────────────────────────────
    final burnout = _burnout(
      overreachingLevel: i.overreachingRiskLevel,
      missedLast30:      i.missedWorkoutsLast30,
      highFatigue:       i.highFatigue,
      fatiguePattern:    i.fatiguePattern,
      recoveryTrend:     i.recoveryTrend,
      needsDeload:       i.needsDeload,
      overTrainingRisk:  i.overTrainingRisk,
    );

    final fragility = _fragility(
      currentStreak:           i.currentStreak,
      longestStreak:           i.longestStreak,
      missedLast30:            i.missedWorkoutsLast30,
      consistencyScore:        i.consistencyScore,
      fatigueCollapseAfterDays: i.fatigueCollapseAfterDays,
    );

    final intimidation = _intimidation(
      avgDuration:       avg,
      recentDuration:    recent,
      consistencyTrend:  i.consistencyTrendLevel,
      abandonmentRate:   abandonRate,
    );

    final motivation = _motivation(
      consistencyTrend: i.consistencyTrendLevel,
      momentumLevel:    i.momentumLevel,
      prsLast21:        i.prsLast21Days,
    );

    final identity = _identity(
      consistencyScore:   i.consistencyScore,
      missedLast30:       i.missedWorkoutsLast30,
      fatiguePattern:     i.fatiguePattern,
      motivationalTriggers: i.motivationalTriggers,
      currentStreak:      i.currentStreak,
      longestStreak:      i.longestStreak,
      momentumLevel:      i.momentumLevel,
      prsLast21:          i.prsLast21Days,
      avgGap:             avgGap,
      overreachingLevel:  i.overreachingRiskLevel,
    );

    final comeback = _comebackProbability(
      consistencyScore: i.consistencyScore,
      longestStreak:    i.longestStreak,
      daysSince:        i.daysSinceLastWorkout,
    );

    final discipline = _disciplineScore(
      consistencyScore: i.consistencyScore,
      missedLast30:     i.missedWorkoutsLast30,
      currentStreak:    i.currentStreak,
    );

    final sessionStyle = _sessionStyle(avg, recent);

    final insight = _insight(
      burnout:        burnout,
      fragility:      fragility,
      intimidation:   intimidation,
      motivation:     motivation,
      identity:       identity,
      daysSince:      i.daysSinceLastWorkout,
      currentStreak:  i.currentStreak,
      consistencyScore: i.consistencyScore,
    );

    return AdherenceProfile(
      consistencyIdentity:   identity,
      burnoutRisk:           burnout,
      streakFragility:       fragility,
      intimidationRisk:      intimidation,
      motivationTrend:       motivation,
      comebackProbability:   comeback,
      disciplineScore:       discipline,
      preferredSessionStyle: sessionStyle,
      adherenceInsight:      insight,
      computedAt:            i.now,
    );
  }

  // ── Duration helpers ──────────────────────────────────────────────────────

  static double _avgDuration(List<HistoryEntry> history) {
    final valid = history.where((e) => e.durationMinutes > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.fold(0, (s, e) => s + e.durationMinutes) / valid.length;
  }

  static double _recentAvgDuration(List<HistoryEntry> history, int n) {
    final recent = history.take(n).where((e) => e.durationMinutes > 0).toList();
    if (recent.isEmpty) return 0;
    return recent.fold(0, (s, e) => s + e.durationMinutes) / recent.length;
  }

  static double _abandonmentRate(List<HistoryEntry> history) {
    if (history.isEmpty) return 0;
    // Sessions under 18 minutes are likely abandoned or very abbreviated
    final short = history.where(
      (e) => e.durationMinutes > 0 && e.durationMinutes < 18,
    ).length;
    return short / history.length;
  }

  static double _averageGapDays(List<HistoryEntry> history) {
    if (history.length < 2) return 1.0;
    double total = 0;
    int count = 0;
    for (int j = 0; j < history.length - 1; j++) {
      final a = DateTime.tryParse(history[j].date);
      final b = DateTime.tryParse(history[j + 1].date);
      if (a != null && b != null) {
        total += a.difference(b).inDays.abs().toDouble();
        count++;
      }
    }
    return count > 0 ? total / count : 1.0;
  }

  // ── Burnout risk ──────────────────────────────────────────────────────────

  static BurnoutRisk _burnout({
    required int    overreachingLevel,
    required int    missedLast30,
    required bool   highFatigue,
    required String fatiguePattern,
    required String recoveryTrend,
    required bool   needsDeload,
    required double overTrainingRisk,
  }) {
    int signals = 0;
    if (overreachingLevel >= 2)                            signals++;
    if (missedLast30 > 6)                                  signals++;
    if (highFatigue)                                       signals++;
    if (fatiguePattern == 'fatigues_after_3_days')         signals++;
    if (recoveryTrend == 'declining')                      signals++;
    if (needsDeload)                                       signals++;
    if (overTrainingRisk > 60)                             signals++;

    if (signals >= 4) return BurnoutRisk.high;
    if (signals >= 2) return BurnoutRisk.moderate;
    if (signals >= 1) return BurnoutRisk.low;
    return BurnoutRisk.none;
  }

  // ── Streak fragility ──────────────────────────────────────────────────────

  static StreakFragility _fragility({
    required int currentStreak,
    required int longestStreak,
    required int missedLast30,
    required int consistencyScore,
    required int fatigueCollapseAfterDays,
  }) {
    if (consistencyScore < 30 || missedLast30 > 10) {
      return StreakFragility.critical;
    }
    // Collapses well before historical best and misses are frequent
    if (longestStreak > 7 &&
        currentStreak < longestStreak * 0.25 &&
        missedLast30 > 3) {
      return StreakFragility.fragile;
    }
    // fatigueCollapseAfterDays hints at a known collapse pattern
    if (fatigueCollapseAfterDays > 0 &&
        currentStreak >= fatigueCollapseAfterDays - 1) {
      return StreakFragility.fragile;
    }
    if (currentStreak >= longestStreak * 0.7 ||
        (currentStreak > 5 && missedLast30 <= 2)) {
      return StreakFragility.resilient;
    }
    return StreakFragility.normal;
  }

  // ── Intimidation risk ─────────────────────────────────────────────────────

  static IntimidationRisk _intimidation({
    required double avgDuration,
    required double recentDuration,
    required int    consistencyTrend,
    required double abandonmentRate,
  }) {
    if (avgDuration <= 0) return IntimidationRisk.none;
    final durationDrop     = recentDuration < avgDuration * 0.65;
    final consistencyDip   = consistencyTrend <= 1; // declining or inconsistent

    if (durationDrop && consistencyDip && abandonmentRate > 0.15) {
      return IntimidationRisk.moderate;
    }
    if (durationDrop && abandonmentRate > 0.10) {
      return IntimidationRisk.low;
    }
    return IntimidationRisk.none;
  }

  // ── Motivation trend ──────────────────────────────────────────────────────

  static MotivationTrend _motivation({
    required int consistencyTrend,
    required int momentumLevel,
    required int prsLast21,
  }) {
    if (consistencyTrend >= 3 && (prsLast21 > 0 || momentumLevel >= 2)) {
      return MotivationTrend.rising;
    }
    if (consistencyTrend >= 2) return MotivationTrend.stable;
    if (consistencyTrend == 1) return MotivationTrend.dipping;
    return MotivationTrend.dropping;
  }

  // ── Consistency identity ──────────────────────────────────────────────────

  static ConsistencyIdentity _identity({
    required int         consistencyScore,
    required int         missedLast30,
    required String      fatiguePattern,
    required List<String> motivationalTriggers,
    required int         currentStreak,
    required int         longestStreak,
    required int         momentumLevel,
    required int         prsLast21,
    required double      avgGap,
    required int         overreachingLevel,
  }) {
    // Burnout-prone overrides — safety first
    if (fatiguePattern == 'fatigues_after_3_days' &&
        missedLast30 > 5 &&
        overreachingLevel >= 2) {
      return ConsistencyIdentity.burnoutProne;
    }
    // Disciplined builder
    if (consistencyScore >= 80 && currentStreak >= 5) {
      return ConsistencyIdentity.disciplinedBuilder;
    }
    // Momentum athlete: driven by PRs + currently in a building/peaking phase
    if (motivationalTriggers.contains('pr_progress') && momentumLevel >= 2) {
      return ConsistencyIdentity.momentumAthlete;
    }
    // Streak chaser: explicit trigger + near personal best streak
    if (motivationalTriggers.contains('streaks') &&
        longestStreak > 3 &&
        currentStreak > longestStreak * 0.7) {
      return ConsistencyIdentity.streakChaser;
    }
    // Inconsistent sprinter: low consistency but still hitting PRs
    if (consistencyScore < 50 && prsLast21 > 0) {
      return ConsistencyIdentity.inconsistentSprinter;
    }
    // Weekend warrior: average gap roughly 2–4 days with reasonable consistency
    if (avgGap >= 2.5 && avgGap <= 4.5 && consistencyScore >= 40) {
      return ConsistencyIdentity.weekendWarrior;
    }
    return ConsistencyIdentity.disciplinedBuilder;
  }

  // ── Comeback probability ──────────────────────────────────────────────────

  static double _comebackProbability({
    required int consistencyScore,
    required int longestStreak,
    required int daysSince,
  }) {
    if (daysSince < 3) return 1.0; // still active
    final base    = consistencyScore / 100.0;
    final history = min(longestStreak, 30) / 30.0;
    // Probability decays slightly with absence duration, but not harshly
    final decay   = max(0.5, 1.0 - (daysSince - 3) * 0.04);
    return ((base * 0.6 + history * 0.4) * decay).clamp(0.1, 0.97);
  }

  // ── Discipline score ──────────────────────────────────────────────────────

  static int _disciplineScore({
    required int consistencyScore,
    required int missedLast30,
    required int currentStreak,
  }) {
    final consistency = consistencyScore * 0.5;
    final attendance  = (1 - missedLast30 / 30.0).clamp(0.0, 1.0) * 30;
    final streak      = min(currentStreak * 2.0, 20.0);
    return (consistency + attendance + streak).round().clamp(0, 100);
  }

  // ── Preferred session style ───────────────────────────────────────────────

  static PreferredSessionStyle _sessionStyle(
      double avgDuration, double recentDuration) {
    if (avgDuration <= 0) return PreferredSessionStyle.moderate;
    // High variance between avg and recent suggests variable preference
    if ((avgDuration - recentDuration).abs() > avgDuration * 0.35) {
      return PreferredSessionStyle.variable;
    }
    if (avgDuration >= 70) return PreferredSessionStyle.longIntense;
    if (avgDuration >= 45) return PreferredSessionStyle.moderate;
    return PreferredSessionStyle.short;
  }

  // ── Adherence insight copy ────────────────────────────────────────────────
  // Tone rules:
  //   burnoutProne / intimidation: gentle, pressure-free
  //   disciplinedBuilder / momentumAthlete: direct, accountable
  //   comeback states: supportive, never guilty
  static String _insight({
    required BurnoutRisk         burnout,
    required StreakFragility      fragility,
    required IntimidationRisk    intimidation,
    required MotivationTrend     motivation,
    required ConsistencyIdentity identity,
    required int                 daysSince,
    required int                 currentStreak,
    required int                 consistencyScore,
  }) {
    // ── Comeback — highest priority, never guilt ──────────────────────────
    if (daysSince >= 7) {
      return 'Momentum returns faster than you think. Restart with one strong session.';
    }
    if (daysSince >= 4) {
      return 'Your training rhythm is just one session away.';
    }

    // ── Burnout signals — gentle framing ──────────────────────────────────
    if (burnout == BurnoutRisk.high) {
      return 'You push hard when momentum builds. Protect recovery before fatigue starts driving missed sessions.';
    }
    if (burnout == BurnoutRisk.moderate) {
      return 'Recent sessions suggest fatigue is affecting adherence. A lighter week resets the pattern.';
    }

    // ── Intimidation — reduce pressure ───────────────────────────────────
    if (intimidation == IntimidationRisk.moderate) {
      return 'Short session is enough today. Showing up matters more than the duration.';
    }
    if (intimidation == IntimidationRisk.low) {
      return 'Keeping sessions sustainable builds the habit better than forcing long ones.';
    }

    // ── Streak fragility ─────────────────────────────────────────────────
    if (fragility == StreakFragility.critical) {
      return 'One session resets the rhythm. The bar is low — just start.';
    }
    if (fragility == StreakFragility.fragile) {
      return 'Consistent short sessions build more than inconsistent long ones.';
    }

    // ── Motivation drop ───────────────────────────────────────────────────
    if (motivation == MotivationTrend.dropping) {
      return 'Consistency has been uneven recently. One solid session shifts the pattern.';
    }
    if (motivation == MotivationTrend.dipping) {
      return 'Training frequency has dipped slightly. Keeping sessions shorter may help maintain the habit.';
    }

    // ── Positive / stable states ──────────────────────────────────────────
    if (motivation == MotivationTrend.rising && currentStreak >= 4) {
      return 'Consistency is stabilizing. The pattern you\'re building here lasts.';
    }
    if (fragility == StreakFragility.resilient && consistencyScore >= 75) {
      return 'Training rhythm is solid. Protect recovery to keep it.';
    }

    return ''; // no significant signal — card does not show
  }
}
