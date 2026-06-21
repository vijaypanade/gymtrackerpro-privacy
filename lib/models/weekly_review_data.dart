// lib/models/weekly_review_data.dart
//
// Pure data model for the Weekly Review feature.
// Assembled once per request by AppProvider.weeklyReviewData.
// No computation lives here — this is a typed snapshot, not a service.

// ── Rating ────────────────────────────────────────────────────────────────────
// Reflects the overall quality of the current training week.
// Computed from adherence × volume delta × recovery suppression.
enum WeekRating {
  excellent,     // 100% adherence + non-negative volume delta
  strong,        // ≥ 80% adherence
  solid,         // ≥ 60% adherence
  inconsistent,  // < 60% adherence
  recoveryWeek,  // volume intentionally down while recovery is suppressed
}

extension WeekRatingLabel on WeekRating {
  String get label {
    switch (this) {
      case WeekRating.excellent:    return 'Excellent';
      case WeekRating.strong:       return 'Strong';
      case WeekRating.solid:        return 'Solid';
      case WeekRating.inconsistent: return 'Inconsistent';
      case WeekRating.recoveryWeek: return 'Recovery Week';
    }
  }

  // true = positive / green tint; false = caution tint
  bool get isPositive => this != WeekRating.inconsistent;
}

// ── Data model ────────────────────────────────────────────────────────────────

class WeeklyReviewData {
  // Volume — calendar week (Monday 00:00 → now)
  final double weekVolumeKg;
  final double previousWeekVolumeKg; // from WeeklyMemory (last completed week)
  final double volumeDeltaPercent;   // positive = increase; negative = decrease

  // Session count
  final int    completedSessions;
  final int    plannedSessions;      // non-rest days in the current week plan
  final double adherencePercent;     // 0–100; capped at 100

  // Achievement signals
  final int    prCount;              // PRs set this week (filter of recentPRs)

  // Athlete context
  final int    currentStreak;        // consecutive training days
  final int    consistencyScore;     // 0–100 from AthleteMemory (30-day window)

  // Recovery context
  final double overallRecovery;      // 0–100 from RecoveryEngine.overallScore
  final String limitingMuscle;       // '' when none suppressed

  // Progression signal
  final double progressionScore;     // analytics.weeklyImprovementPct

  // Narrative — fully computed, UI just renders these strings
  final String    headline;
  final String    summary;
  final WeekRating rating;

  const WeeklyReviewData({
    required this.weekVolumeKg,
    required this.previousWeekVolumeKg,
    required this.volumeDeltaPercent,
    required this.completedSessions,
    required this.plannedSessions,
    required this.adherencePercent,
    required this.prCount,
    required this.currentStreak,
    required this.consistencyScore,
    required this.overallRecovery,
    required this.limitingMuscle,
    required this.progressionScore,
    required this.headline,
    required this.summary,
    required this.rating,
  });

  // Safe zero-state: first launch / no history / empty plan.
  // UI should detect this and show a "start logging to see your review" state.
  static const empty = WeeklyReviewData(
    weekVolumeKg:         0.0,
    previousWeekVolumeKg: 0.0,
    volumeDeltaPercent:   0.0,
    completedSessions:    0,
    plannedSessions:      0,
    adherencePercent:     0.0,
    prCount:              0,
    currentStreak:        0,
    consistencyScore:     0,
    overallRecovery:      0.0,
    limitingMuscle:       '',
    progressionScore:     0.0,
    headline:             '',
    summary:              '',
    rating:               WeekRating.solid,
  );

  bool get hasData => completedSessions > 0 || plannedSessions > 0;

  // Convenience helpers used by the UI card.

  bool get hasVolumeDelta =>
      previousWeekVolumeKg > 0 && volumeDeltaPercent.abs() >= 1.0;

  bool get volumeUp => volumeDeltaPercent > 0;

  String get volumeDeltaLabel {
    if (!hasVolumeDelta) return '';
    final sign = volumeUp ? '+' : '';
    return '$sign${volumeDeltaPercent.round()}%';
  }

  // Formats volume as "32 Tonnes" / "6.8 Tonnes" (≥ 1000 kg) or "850 kg".
  static String fmtVol(double v) {
    if (v >= 1000) {
      final t = v / 1000;
      final s = t.toStringAsFixed(1);
      return s.endsWith('.0') ? '${t.round()} Tonnes' : '$s Tonnes';
    }
    return '${v.round()} kg';
  }

  String get weekVolumeLabel    => fmtVol(weekVolumeKg);
  String get prevVolumeLabel    => fmtVol(previousWeekVolumeKg);
}
