// lib/memory/events/workout_completed_event.dart

/// Immutable event describing a completed workout.
///
/// Contains only domain-level metadata that may influence long-term athlete
/// memory evolution.
class WorkoutCompletedEvent {
  final int durationMinutes;
  final bool wasSuccessful;
  final int completedVolumeKg;
  final DateTime completedAt;

  const WorkoutCompletedEvent({
    required this.durationMinutes,
    required this.wasSuccessful,
    required this.completedVolumeKg,
    required this.completedAt,
  });
}
