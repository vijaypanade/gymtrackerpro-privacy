// lib/timeline/models/timeline_snapshot.dart
//
// TimelineSnapshot — immutable output of AthleteTimelineEngine.
// Contains the complete ordered event list, milestone markers, and
// a human-readable summary of the athlete's long-term evolution.
// No AI. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

import 'milestone.dart';
import 'timeline_event.dart';

@immutable
class TimelineSnapshot {
  /// All events sorted chronologically (oldest first).
  final List<TimelineEvent> events;

  /// Subset of events elevated to milestone status, sorted chronologically.
  final List<Milestone> milestones;

  /// Total workouts represented in this timeline.
  final int totalWorkouts;

  /// Longest streak ever recorded (days).
  final int longestStreak;

  /// Total personal records across all time.
  final int totalPRs;

  /// Current identity label at time of snapshot.
  final String currentIdentityLabel;

  /// First workout date; null if no history.
  final DateTime? firstWorkoutDate;

  /// Most recent event date; null if no history.
  final DateTime? latestEventDate;

  /// One-sentence summary of the athlete's evolution.
  final String evolutionSummary;

  /// Short headline for the timeline period.
  final String headline;

  const TimelineSnapshot({
    required this.events,
    required this.milestones,
    required this.totalWorkouts,
    required this.longestStreak,
    required this.totalPRs,
    required this.currentIdentityLabel,
    required this.evolutionSummary,
    required this.headline,
    this.firstWorkoutDate,
    this.latestEventDate,
  });

  /// Safe empty state — no workout history yet.
  static const TimelineSnapshot empty = TimelineSnapshot(
    events:               [],
    milestones:           [],
    totalWorkouts:        0,
    longestStreak:        0,
    totalPRs:             0,
    currentIdentityLabel: 'building foundation',
    evolutionSummary:     'Your athlete timeline will appear after your first workout.',
    headline:             'No history yet',
  );

  bool get hasData => events.isNotEmpty;

  int get milestoneCount => milestones.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TimelineSnapshot) return false;
    return other.totalWorkouts        == totalWorkouts        &&
           other.longestStreak        == longestStreak        &&
           other.totalPRs             == totalPRs             &&
           other.currentIdentityLabel == currentIdentityLabel &&
           other.latestEventDate      == latestEventDate;
  }

  @override
  int get hashCode => Object.hash(
    totalWorkouts, longestStreak, totalPRs,
    currentIdentityLabel, latestEventDate,
  );

  @override
  String toString() =>
      'TimelineSnapshot(workouts:$totalWorkouts streak:$longestStreak '
      'prs:$totalPRs identity:$currentIdentityLabel '
      'events:${events.length} milestones:${milestones.length})';
}
