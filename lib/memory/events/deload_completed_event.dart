// lib/memory/events/deload_completed_event.dart

/// Immutable event describing a completed deload.
///
/// Contains only domain-level deload metadata for AthleteMemory evolution.
class DeloadCompletedEvent {
  final Duration deloadDuration;
  final double reducedVolumeKg;
  final DateTime completedAt;

  const DeloadCompletedEvent({
    required this.deloadDuration,
    required this.reducedVolumeKg,
    required this.completedAt,
  });
}
