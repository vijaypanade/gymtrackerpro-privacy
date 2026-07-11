// lib/memory/events/pr_achieved_event.dart

/// Immutable event describing a new personal record.
///
/// Contains only domain data for AthleteMemory progression evolution.
class PRAchievedEvent {
  final String liftName;
  final double newWeightKg;
  final int newReps;
  final DateTime achievedAt;

  const PRAchievedEvent({
    required this.liftName,
    required this.newWeightKg,
    required this.newReps,
    required this.achievedAt,
  });
}
