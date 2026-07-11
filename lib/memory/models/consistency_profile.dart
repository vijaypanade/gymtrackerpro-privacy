// lib/memory/models/consistency_profile.dart

/// Immutable athlete consistency information.
///
/// This model captures long-term training consistency trends.
class ConsistencyProfile {
  final int totalWorkouts;
  final int averageWorkoutsPerWeek;
  final int longestStreak;
  final int missedWorkoutsLast30Days;

  const ConsistencyProfile({
    required this.totalWorkouts,
    required this.averageWorkoutsPerWeek,
    required this.longestStreak,
    required this.missedWorkoutsLast30Days,
  });
}
