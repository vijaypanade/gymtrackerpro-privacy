// lib/timeline/models/timeline_event.dart
//
// TimelineEvent — a single chronological event in the athlete's history.
// No AI. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

/// Category of event stored in the timeline.
enum TimelineEventType {
  firstWorkout,
  streak7,
  streak30,
  workout50,
  workout100,
  identityEvolution,
  prAchieved,
  recoveryImprovement,
  consistencyMilestone,
  deloadCompleted,
  comebackCompleted,
  weeklyHighlight,
}

extension TimelineEventTypeX on TimelineEventType {
  String get label {
    switch (this) {
      case TimelineEventType.firstWorkout:          return 'First Workout';
      case TimelineEventType.streak7:               return '7-Day Streak';
      case TimelineEventType.streak30:              return '30-Day Streak';
      case TimelineEventType.workout50:             return '50 Workouts';
      case TimelineEventType.workout100:            return '100 Workouts';
      case TimelineEventType.identityEvolution:     return 'Identity Evolved';
      case TimelineEventType.prAchieved:            return 'Personal Record';
      case TimelineEventType.recoveryImprovement:   return 'Recovery Improved';
      case TimelineEventType.consistencyMilestone:  return 'Consistency Milestone';
      case TimelineEventType.deloadCompleted:       return 'Deload Completed';
      case TimelineEventType.comebackCompleted:     return 'Comeback Completed';
      case TimelineEventType.weeklyHighlight:       return 'Weekly Highlight';
    }
  }

  bool get isPositive {
    switch (this) {
      case TimelineEventType.firstWorkout:
      case TimelineEventType.streak7:
      case TimelineEventType.streak30:
      case TimelineEventType.workout50:
      case TimelineEventType.workout100:
      case TimelineEventType.identityEvolution:
      case TimelineEventType.prAchieved:
      case TimelineEventType.recoveryImprovement:
      case TimelineEventType.consistencyMilestone:
      case TimelineEventType.deloadCompleted:
      case TimelineEventType.comebackCompleted:
        return true;
      case TimelineEventType.weeklyHighlight:
        return false;
    }
  }
}

@immutable
class TimelineEvent {
  final TimelineEventType type;
  final DateTime date;
  final String title;
  final String detail;

  /// Optional numeric value (e.g. weight for PRs, streak count).
  final double? value;

  /// Optional label for the value (e.g. 'kg', 'days').
  final String? valueUnit;

  /// Optional exercise name for PR events.
  final String? exercise;

  const TimelineEvent({
    required this.type,
    required this.date,
    required this.title,
    required this.detail,
    this.value,
    this.valueUnit,
    this.exercise,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TimelineEvent) return false;
    return other.type     == type     &&
           other.date     == date     &&
           other.title    == title    &&
           other.exercise == exercise &&
           other.value    == value;
  }

  @override
  int get hashCode => Object.hash(type, date, title, exercise, value);

  @override
  String toString() =>
      'TimelineEvent(${type.label} @ ${date.toIso8601String().substring(0, 10)}: $title)';
}
