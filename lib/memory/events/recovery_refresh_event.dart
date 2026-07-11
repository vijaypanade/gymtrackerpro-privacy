// lib/memory/events/recovery_refresh_event.dart

/// Immutable event describing a recovery refresh.
///
/// Contains only long-term recovery metadata for AthleteMemory evolution.
class RecoveryRefreshEvent {
  final Duration recoveryWindow;
  final double recoveryScore;
  final DateTime refreshedAt;

  const RecoveryRefreshEvent({
    required this.recoveryWindow,
    required this.recoveryScore,
    required this.refreshedAt,
  });
}
