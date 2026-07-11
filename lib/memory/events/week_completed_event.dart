// lib/memory/events/week_completed_event.dart

/// Immutable event describing a completed training week.
///
/// Contains only domain-level week completion metadata for AthleteMemory evolution.
class WeekCompletedEvent {
  final int totalWorkouts;
  final int successfulWorkouts;
  final double averageIntensity;
  final DateTime weekEndingAt;

  const WeekCompletedEvent({
    required this.totalWorkouts,
    required this.successfulWorkouts,
    required this.averageIntensity,
    required this.weekEndingAt,
  });
}
