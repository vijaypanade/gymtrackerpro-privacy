import 'models/sync_op.dart';

/// Pluggable bridge between a local Hive model type [T] and its Firestore
/// collection representation.
///
/// Each synced collection has exactly one concrete SyncAdapter:
///   - LogsSyncAdapter  → users/{uid}/logs
///   (future: PlansAdapter, MeasurementsAdapter, …)
///
/// The adapter owns three things:
///   1. Routing — collection name, document ID derivation, full path construction.
///   2. Serialisation — local object → Firestore payload, Firestore doc → local object.
///   3. SyncOp factory — convenience methods that build outbox entries.
///
/// The adapter does NOT own:
///   - Hive persistence (that is the repository's job).
///   - Firestore writes (that is FirestoreGateway's job).
///   - Retry / backoff logic (that is the OutboxService's job).
///
/// Timestamp convention: [toPayload] must return [deletedAt] (if present) and
/// any other client-side date fields as epoch-millisecond ints. The outbox
/// flush worker converts these to Firestore Timestamps before calling the
/// gateway, keeping this class free of cloud_firestore imports.
abstract class SyncAdapter<T> {
  /// Firestore subcollection name under "users/{uid}/".
  String get collectionName;

  /// Schema version for the payload this adapter produces.
  /// Written as [schemaVersion] in every Firestore document (RFC-002 contract).
  int get schemaVersion;

  /// Derive a stable, deterministic document ID from [item]'s natural key.
  ///
  /// The result is used as the coalescing key in the outbox: two calls with
  /// logically identical items must return the same ID.
  String docIdFor(T item);

  /// Full Firestore document path for [item] belonging to [uid].
  String documentPath(String uid, T item) =>
      'users/$uid/$collectionName/${docIdFor(item)}';

  /// Convert [item] to a Firestore-ready payload map.
  ///
  /// The returned map MUST include:
  ///   - All business fields.
  ///   - [schemaVersion] (RFC-002 sync contract field).
  ///   - [writerDeviceId] (RFC-002 sync contract field).
  ///
  /// The returned map MUST NOT include:
  ///   - [updatedAt] — appended by FirestoreGateway as a server timestamp.
  ///   - [deletedAt] — appended by [toSoftDeleteOp] when needed.
  Map<String, dynamic> toPayload(T item, {required String writerDeviceId});

  /// Reconstruct a local [T] object from a Firestore document snapshot.
  ///
  /// Returns null if [doc] is malformed, missing required fields, or represents
  /// a soft-deleted document (deletedAt is set). The caller decides whether to
  /// skip or surface deleted documents.
  T? fromPayload(Map<String, dynamic> doc);

  // ─── SyncOp factories (default implementations) ──────────────────────────

  /// Build a [SyncOpType.upsert] entry for [item].
  SyncOp toUpsertOp(T item, {required String writerDeviceId}) => SyncOp(
        collection: collectionName,
        docId: docIdFor(item),
        opType: SyncOpType.upsert,
        payload: toPayload(item, writerDeviceId: writerDeviceId),
        enqueuedAt: DateTime.now(),
      );

  /// Build a [SyncOpType.softDelete] entry for [item].
  ///
  /// Adds [deletedAt] (epoch millis) to the full payload snapshot.
  /// The outbox flush worker converts this to a Firestore Timestamp before
  /// calling FirestoreGateway.
  SyncOp toSoftDeleteOp(T item, {required String writerDeviceId}) {
    final base = toPayload(item, writerDeviceId: writerDeviceId);
    return SyncOp(
      collection: collectionName,
      docId: docIdFor(item),
      opType: SyncOpType.softDelete,
      payload: <String, dynamic>{
        ...base,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      enqueuedAt: DateTime.now(),
    );
  }
}
