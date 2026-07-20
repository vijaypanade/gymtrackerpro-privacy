// lib/models/health_models.dart
// Intermediate model produced by HealthMapper.
//
// Scope: HealthDataPoint → HealthWorkout only.
// HistoryEntryBuilder converts HealthWorkout → HistoryEntry.
// This class must never reference HistoryEntry or any LiftOn domain model.

class HealthWorkout {
  final String   externalId;      // HealthKit UUID — dedup key in HistoryEntry.externalId
  final String   workoutType;     // Human-readable activity name, e.g. "Running"
  final DateTime startTime;
  final int      durationMinutes;
  final double   totalEnergyKcal; // 0.0 when energy was not recorded

  const HealthWorkout({
    required this.externalId,
    required this.workoutType,
    required this.startTime,
    required this.durationMinutes,
    required this.totalEnergyKcal,
  });

  /// Calendar date in YYYY-MM-DD, derived from startTime (local timezone).
  String get date {
    final d = startTime;
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
