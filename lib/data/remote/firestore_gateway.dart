// RFC-002.1 target: all NEW sync infrastructure routes through this gateway.
// Legacy direct Firestore calls in workout_provider, user_provider,
// favorites_provider, and billing_service remain until RFC-002.x migration
// completes (strangler-fig pattern).
import 'package:cloud_firestore/cloud_firestore.dart';

/// Transport-only Firestore wrapper.
///
/// Responsibilities:
///   - Execute upsert and soft-delete writes.
///   - Append [updatedAt: FieldValue.serverTimestamp()] to every write.
///   - Propagate exceptions — the outbox owns retry logic.
///
/// Non-responsibilities:
///   - No business logic.
///   - No conflict resolution.
///   - No schema validation.
///   - No knowledge of collection structure or user identity.
///
/// [path] arguments must be full Firestore document paths,
/// e.g. "users/uid123/logs/exercise_2024-01-15_80.0_10".
/// The caller (SyncAdapter) is responsible for constructing correct paths.
class FirestoreGateway {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Write a complete document snapshot to [path].
  ///
  /// Uses set() without merge — the outbox always supplies a full document
  /// snapshot, so a full replace is correct. Fields not present in [payload]
  /// will be absent in Firestore after this call.
  ///
  /// The gateway automatically appends [updatedAt: FieldValue.serverTimestamp()].
  /// Do not include [updatedAt] in [payload] — it will be overwritten.
  Future<void> upsert(
    String path,
    Map<String, dynamic> payload,
  ) =>
      _db.doc(path).set(<String, dynamic>{
        ...payload,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Soft-delete a document at [path].
  ///
  /// [payload] must contain [deletedAt] as an epoch-millisecond int (the only
  /// serialisable form that survives the Hive round-trip in the outbox).
  /// The gateway converts it to a Firestore [Timestamp] so that Firestore Rules
  /// can assert `deletedAt is timestamp` (RFC-002.3 contract).
  /// The gateway also appends [updatedAt: FieldValue.serverTimestamp()].
  Future<void> softDelete(
    String path,
    Map<String, dynamic> payload,
  ) {
    assert(
      payload.containsKey('deletedAt'),
      'FirestoreGateway.softDelete: payload must include deletedAt. '
      'Path: $path',
    );

    // Convert epoch-millis int to Firestore Timestamp so Rules validate it as
    // a timestamp type. Other payload fields are written as-is.
    final enriched = Map<String, dynamic>.from(payload);
    final rawDeletedAt = payload['deletedAt'];
    if (rawDeletedAt is int) {
      enriched['deletedAt'] =
          Timestamp.fromMillisecondsSinceEpoch(rawDeletedAt);
    }

    return _db.doc(path).set(<String, dynamic>{
      ...enriched,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
