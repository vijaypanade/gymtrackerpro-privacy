// lib/timeline/services/milestone_detector.dart
//
// MilestoneDetector — converts TimelineEvents into Milestone records.
// Pure deterministic. No AI. No Provider. No Firebase. No UI.

import '../models/milestone.dart';
import '../models/timeline_event.dart';

class MilestoneDetector {
  const MilestoneDetector._();

  /// Evaluates [events] and returns all that qualify as milestones.
  ///
  /// Each eligible event type is assigned a tier and an emoji. Only
  /// events with a milestone-eligible type are elevated; weeklyHighlight
  /// events are never promoted.
  static List<Milestone> detect(List<TimelineEvent> events) {
    final result = <Milestone>[];

    for (final event in events) {
      final entry = _toMilestone(event);
      if (entry != null) result.add(entry);
    }

    // Sort chronologically
    result.sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    return result;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static Milestone? _toMilestone(TimelineEvent event) {
    switch (event.type) {
      case TimelineEventType.firstWorkout:
        return Milestone.fromEvent(event, MilestoneTier.silver, '🏁');

      case TimelineEventType.streak7:
        return Milestone.fromEvent(event, MilestoneTier.bronze, '🔥');

      case TimelineEventType.streak30:
        return Milestone.fromEvent(event, MilestoneTier.gold, '⚡');

      case TimelineEventType.workout50:
        return Milestone.fromEvent(event, MilestoneTier.silver, '💪');

      case TimelineEventType.workout100:
        return Milestone.fromEvent(event, MilestoneTier.legendary, '🏆');

      case TimelineEventType.identityEvolution:
        return Milestone.fromEvent(event, MilestoneTier.gold, '⭐');

      case TimelineEventType.prAchieved:
        return Milestone.fromEvent(event, MilestoneTier.bronze, '🎯');

      case TimelineEventType.recoveryImprovement:
        return Milestone.fromEvent(event, MilestoneTier.bronze, '💚');

      case TimelineEventType.consistencyMilestone:
        return Milestone.fromEvent(event, MilestoneTier.silver, '📈');

      case TimelineEventType.deloadCompleted:
        return Milestone.fromEvent(event, MilestoneTier.bronze, '🛡️');

      case TimelineEventType.comebackCompleted:
        return Milestone.fromEvent(event, MilestoneTier.silver, '🦅');

      // weeklyHighlight events are not promoted to milestones.
      case TimelineEventType.weeklyHighlight:
        return null;
    }
  }
}
