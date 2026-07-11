// lib/review/models/weekly_recommendation.dart
//
// WeeklyRecommendation — a single actionable suggestion in the weekly report.
// Immutable. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

/// Category of the recommendation, used by the UI for icon selection.
enum RecommendationType {
  /// Athlete should prioritize recovery next week.
  recovery,

  /// Session volume should increase (positive progression signal).
  volume,

  /// Athlete needs to improve session frequency and habit.
  consistency,

  /// Intensity can be raised (good recovery + progression signals).
  intensity,

  /// Movement quality should be prioritised over load.
  technique,

  /// Full rest or deload is needed.
  rest,

  /// Clear opportunity to push for new personal records.
  push,
}

extension RecommendationTypeX on RecommendationType {
  String get label {
    switch (this) {
      case RecommendationType.recovery:    return 'Recovery';
      case RecommendationType.volume:      return 'Volume';
      case RecommendationType.consistency: return 'Consistency';
      case RecommendationType.intensity:   return 'Intensity';
      case RecommendationType.technique:   return 'Technique';
      case RecommendationType.rest:        return 'Rest';
      case RecommendationType.push:        return 'Push';
    }
  }
}

@immutable
class WeeklyRecommendation {
  /// Category — drives icon and colour in the UI.
  final RecommendationType type;

  /// Short action headline. Max ~40 chars.
  final String title;

  /// One-sentence explanation of why this is recommended.
  final String detail;

  /// True when this recommendation must be acted on (safety or recovery risk).
  final bool isUrgent;

  const WeeklyRecommendation({
    required this.type,
    required this.title,
    required this.detail,
    required this.isUrgent,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklyRecommendation) return false;
    return other.type     == type     &&
           other.title    == title    &&
           other.detail   == detail   &&
           other.isUrgent == isUrgent;
  }

  @override
  int get hashCode => Object.hash(type, title, detail, isUrgent);

  @override
  String toString() =>
      'WeeklyRecommendation(${type.label} urgent:$isUrgent "$title")';
}
