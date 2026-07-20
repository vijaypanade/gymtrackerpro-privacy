import 'package:flutter/foundation.dart';

/// The kind of write this outbox entry represents.
enum SyncOpType {
  /// Full document write — covers both CREATE and UPDATE.
  /// The gateway uses set() with the complete payload snapshot.
  upsert,

  /// Marks a document deleted by adding deletedAt to the payload.
  /// Payload must include a deletedAt millisecond-epoch value.
  softDelete;

  /// Deserialise from the stored string, defaulting to upsert on unknown values.
  static SyncOpType fromString(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => upsert);
}

/// One pending Firestore write held in the local outbox.
///
/// [payload] carries every document field that will be written to Firestore,
/// including [schemaVersion] and [writerDeviceId] (RFC-002 sync contract
/// fields). The gateway appends [updatedAt] as a server timestamp at
/// write time — it is never stored here because FieldValue is not serialisable.
///
/// Coalescing: [hiveKey] is the Hive box key. Enqueueing a newer op for the
/// same (collection, docId) pair calls box.put(hiveKey, …), which atomically
/// replaces any existing entry — so only the latest intent for each document
/// is ever flushed to Firestore.
@immutable
class SyncOp {
  final String collection;
  final String docId;
  final SyncOpType opType;

  /// Serialisable document payload (no FieldValue sentinels).
  final Map<String, dynamic> payload;

  /// Wall-clock time this op was enqueued; used for FIFO ordering during flush.
  final DateTime enqueuedAt;

  /// Incremented on each failed flush attempt; used for exponential back-off.
  final int retryCount;

  const SyncOp({
    required this.collection,
    required this.docId,
    required this.opType,
    required this.payload,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  /// Hive box key — drives coalescing.
  ///
  /// Format: "<collection>|<docId>"
  /// The pipe separator is safe because Firestore document IDs cannot contain pipes.
  String get hiveKey => '$collection|$docId';

  /// Returns a copy with [retryCount] incremented by one.
  SyncOp withRetry() => SyncOp(
        collection: collection,
        docId: docId,
        opType: opType,
        payload: Map<String, dynamic>.from(payload),
        enqueuedAt: enqueuedAt,
        retryCount: retryCount + 1,
      );

  // ─── Hive persistence ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'collection': collection,
        'docId': docId,
        'opType': opType.name,
        'payload': Map<String, dynamic>.from(payload),
        'enqueuedAt': enqueuedAt.millisecondsSinceEpoch,
        'retryCount': retryCount,
      };

  factory SyncOp.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final rawEnqueued = map['enqueuedAt'];
    final enqueuedAt = rawEnqueued is int
        ? DateTime.fromMillisecondsSinceEpoch(rawEnqueued)
        : DateTime.now();

    final rawPayload = map['payload'];
    final Map<String, dynamic> payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : const {};

    final rawRetry = map['retryCount'];
    final retryCount =
        (rawRetry is int) ? rawRetry.clamp(0, 100) : 0;

    return SyncOp(
      collection: map['collection']?.toString() ?? '',
      docId: map['docId']?.toString() ?? '',
      opType: SyncOpType.fromString(map['opType']?.toString()),
      payload: payload,
      enqueuedAt: enqueuedAt,
      retryCount: retryCount,
    );
  }

  @override
  String toString() => 'SyncOp($opType $collection/$docId '
      'retry=$retryCount enqueued=${enqueuedAt.toIso8601String()})';
}
