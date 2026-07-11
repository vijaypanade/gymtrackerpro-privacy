// lib/review/models/weekly_summary.dart
//
// WeeklySummary — narrative layer of the weekly report.
// All text is generated deterministically by WeeklySummaryBuilder.
// No AI. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

@immutable
class WeeklySummary {
  /// One punchy headline summarising the week in ≤ 8 words.
  final String headline;

  /// 2–3 sentence narrative covering performance, recovery, and trend.
  final String bodyText;

  /// What the coach says about this specific week's outcome.
  final String coachLine;

  /// Directional focus statement for the athlete going into next week.
  final String nextWeekFocus;

  const WeeklySummary({
    required this.headline,
    required this.bodyText,
    required this.coachLine,
    required this.nextWeekFocus,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklySummary) return false;
    return other.headline      == headline      &&
           other.bodyText      == bodyText      &&
           other.coachLine     == coachLine     &&
           other.nextWeekFocus == nextWeekFocus;
  }

  @override
  int get hashCode =>
      Object.hash(headline, bodyText, coachLine, nextWeekFocus);
}
