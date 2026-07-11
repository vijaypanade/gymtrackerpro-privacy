// lib/memory/models/recovery_profile.dart

/// Immutable recovery-related athlete characteristics.
///
/// This model stores long-term recovery tendencies without
/// computing recovery state or recommendations.
class RecoveryProfile {
  final double averageRecoveryScore;
  final int recoverySessionsCompleted;
  final int daysSinceLastRecoveryEvent;

  const RecoveryProfile({
    required this.averageRecoveryScore,
    required this.recoverySessionsCompleted,
    required this.daysSinceLastRecoveryEvent,
  });
}
