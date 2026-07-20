import '../../models/workout_log.dart';
import '../sync/sync_adapter.dart';

/// SyncAdapter implementation for the Workout Logs collection.
///
/// Maps WorkoutLog ↔ Firestore path  users/{uid}/logs/{docId}.
///
/// docId derivation (deterministic natural key):
///   {normalizedExercise}_{YYYY-MM-DD}_{weight}_{reps}_{minutes}
///
///   Reps and minutes are both included so that weighted, bodyweight, and
///   timed variants of the same exercise on the same day produce distinct IDs.
///   The natural key intentionally has no time component — two logs that share
///   every field down to minutes are the same logical entry and should coalesce.
///
/// schemaVersion mirrors WorkoutLog._dataVersion (private).
/// If WorkoutLog's serialisation format changes, increment [schemaVersion]
/// here and add a migration branch to [fromPayload].
class LogsSyncAdapter extends SyncAdapter<WorkoutLog> {
  LogsSyncAdapter();

  @override
  String get collectionName => 'logs';

  @override
  int get schemaVersion => 1;

  @override
  String docIdFor(WorkoutLog log) {
    assert(
      log.normalizedExercise.isNotEmpty,
      'LogsSyncAdapter.docIdFor: normalizedExercise must not be empty',
    );
    final date = log.date.toIso8601String().substring(0, 10); // YYYY-MM-DD
    return '${log.normalizedExercise}_${date}_${log.weight}_${log.reps}_${log.minutes}';
  }

  /// Build a Firestore-ready payload from [log].
  ///
  /// Field names match the RFC-002 Firestore schema for users/{uid}/logs.
  /// The 'v' key from WorkoutLog.toJson() is deliberately excluded —
  /// schemaVersion is the Firestore-side version identifier.
  /// updatedAt is excluded — appended by FirestoreGateway as a server timestamp.
  @override
  Map<String, dynamic> toPayload(
    WorkoutLog log, {
    required String writerDeviceId,
  }) {
    return <String, dynamic>{
      'exercise': log.normalizedExercise,
      'date': log.date.toIso8601String(),
      'weight': log.weight,
      'reps': log.reps,
      'minutes': log.minutes,
      if (log.muscleGroup != null && log.muscleGroup!.isNotEmpty)
        'muscleGroup': log.muscleGroup,
      // RFC-006: null-omission — key absent when non-adaptive session (§6.1)
      if (log.plannedWeight != null) 'plannedWeight': log.plannedWeight!,
      'schemaVersion': schemaVersion,
      'writerDeviceId': writerDeviceId,
    };
  }

  /// Reconstruct a [WorkoutLog] from a Firestore document snapshot.
  ///
  /// Returns null for:
  ///   - Soft-deleted documents (deletedAt is present and non-null).
  ///   - Malformed documents that cannot be parsed.
  ///
  /// Delegates to [WorkoutLog.fromJson] which has its own defensive parsing
  /// for all numeric and date fields.
  @override
  WorkoutLog? fromPayload(Map<String, dynamic> doc) {
    if (doc['deletedAt'] != null) return null;
    try {
      return WorkoutLog.fromJson(doc);
    } catch (_) {
      return null;
    }
  }
}
