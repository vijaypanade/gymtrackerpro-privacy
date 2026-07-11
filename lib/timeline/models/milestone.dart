// lib/timeline/models/milestone.dart
//
// Milestone — a significant long-term achievement marker.
// No AI. No Provider. No Firebase. No UI.

import 'package:flutter/foundation.dart';

import 'timeline_event.dart';

/// Tier of a milestone — used to drive visual emphasis.
enum MilestoneTier {
  /// Ordinary progress checkpoint.
  bronze,
  /// Meaningful achievement.
  silver,
  /// Major career marker.
  gold,
  /// Rare, exceptional achievement.
  legendary,
}

extension MilestoneTierX on MilestoneTier {
  String get label {
    switch (this) {
      case MilestoneTier.bronze:    return 'Bronze';
      case MilestoneTier.silver:    return 'Silver';
      case MilestoneTier.gold:      return 'Gold';
      case MilestoneTier.legendary: return 'Legendary';
    }
  }
}

@immutable
class Milestone {
  final TimelineEventType type;
  final MilestoneTier tier;
  final DateTime achievedAt;
  final String title;
  final String description;
  final String emoji;

  const Milestone({
    required this.type,
    required this.tier,
    required this.achievedAt,
    required this.title,
    required this.description,
    required this.emoji,
  });

  /// Builds a [Milestone] from a [TimelineEvent].
  factory Milestone.fromEvent(TimelineEvent event, MilestoneTier tier, String emoji) {
    return Milestone(
      type:        event.type,
      tier:        tier,
      achievedAt:  event.date,
      title:       event.title,
      description: event.detail,
      emoji:       emoji,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Milestone) return false;
    return other.type == type && other.achievedAt == achievedAt;
  }

  @override
  int get hashCode => Object.hash(type, achievedAt);

  @override
  String toString() =>
      'Milestone(${tier.label} ${type.label} @ ${achievedAt.toIso8601String().substring(0, 10)})';
}
