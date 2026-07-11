// lib/timeline/services/timeline_summary_builder.dart
//
// TimelineSummaryBuilder — generates the narrative fields of TimelineSnapshot.
// Deterministic text selection based on athlete data.
// No AI. No Provider. No Firebase. No UI.

import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../models/milestone.dart';

class TimelineSummaryBuilder {
  const TimelineSummaryBuilder();

  /// Returns a one-sentence evolution summary.
  String buildEvolutionSummary({
    required AthleteMemorySnapshot mem,
    required int totalWorkouts,
    required int totalPRs,
    required int longestStreak,
    required List<Milestone> milestones,
  }) {
    final stage = mem.identityStage;

    if (totalWorkouts == 0) {
      return 'Your athlete timeline will appear after your first workout.';
    }

    if (stage == 'elite') {
      return 'You have reached elite status across $totalWorkouts sessions, '
          'with $totalPRs lifetime PRs and a peak streak of $longestStreak days.';
    }

    if (stage == 'disciplined') {
      return 'A disciplined athlete with $totalWorkouts sessions completed — '
          'your consistency is driving real long-term progress.';
    }

    if (stage == 'consistent') {
      return 'Consistent training across $totalWorkouts sessions has built a '
          'solid foundation${totalPRs > 0 ? " and $totalPRs personal records" : ""}.';
    }

    if (stage == 'developing') {
      return 'You are actively developing your training habit across '
          '$totalWorkouts sessions — the foundation is taking shape.';
    }

    // beginner / default
    if (totalWorkouts >= 5) {
      return 'You have completed $totalWorkouts sessions — your journey is '
          'underway and the habit is forming.';
    }
    return 'Your first sessions are logged — every elite athlete started exactly here.';
  }

  /// Returns a short headline for the timeline period.
  String buildHeadline({
    required int totalWorkouts,
    required String currentIdentityLabel,
    required List<Milestone> milestones,
    required DateTime? firstWorkoutDate,
  }) {
    if (totalWorkouts == 0) return 'No history yet';
    if (totalWorkouts < 5)  return 'Journey Begins';
    if (totalWorkouts < 20) return 'Building the Habit';
    if (totalWorkouts < 50) return 'Developing Athlete';
    if (totalWorkouts < 100) return 'Consistent Performer';
    return 'Seasoned Athlete';
  }
}
