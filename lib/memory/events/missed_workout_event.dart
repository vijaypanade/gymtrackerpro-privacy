// lib/memory/events/missed_workout_event.dart

/// Immutable event describing a missed workout.
///
/// Contains only domain data for AthleteMemory adherence and reliability evolution.
class MissedWorkoutEvent {
  final DateTime missedAt;
  final String reason;

  const MissedWorkoutEvent({
    required this.missedAt,
    required this.reason,
  });
}
