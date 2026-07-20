import 'package:flutter/foundation.dart';

import '../../models/workout_log.dart';
import '../../services/storage_service.dart';
import '../adapters/logs_sync_adapter.dart';
import '../sync/models/sync_op.dart';
import '../sync/outbox_service.dart';

/// Local-first repository for workout logs.
///
/// Write path:
///   1. Hive logsBox ('all_logs') — authoritative local store.
///   2. SharedPreferences (workout_logs_v4) — legacy fallback.
///   3. OutboxService.enqueue() — queues op for deferred Firestore sync.
///
/// Read path:
///   Hive first → SharedPreferences fallback.
///   Mirrors _loadLogsHybrid in workout_provider.dart exactly to preserve
///   backward compatibility for existing data (ADR-006).
///
/// Phase 2 note: this repository is not yet wired into any provider.
/// It is created and injected in Phase 3 (main.dart + workout_provider.dart).
/// All OutboxService enqueues are dormant while SyncMode == disabled.
class WorkoutLogRepository {
  final StorageService _storage;
  final OutboxService _outbox;
  final LogsSyncAdapter _adapter;

  WorkoutLogRepository({
    required StorageService storage,
    required OutboxService outbox,
    required LogsSyncAdapter adapter,
  })  : _storage = storage,
        _outbox = outbox,
        _adapter = adapter;

  /// App-wide singleton. All app code should use this instance rather than
  /// constructing its own, so the outbox stays coherent across callers.
  static final WorkoutLogRepository instance = WorkoutLogRepository(
    storage: StorageService.instance,
    outbox: OutboxService.instance,
    adapter: LogsSyncAdapter(),
  );

  static const String _hiveKey = 'all_logs';

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Returns ALL workout logs including soft-deleted records (deletedAt != null).
  ///
  /// This method is reserved for internal, administrative, migration, or
  /// sync-engine use. For any user-facing UI display, use loadActive() instead.
  /// Calling this method in a UI context will expose deleted records to users.
  Future<List<WorkoutLog>> loadAll() async {
    try {
      final box = _storage.logsBox;
      if (box != null) {
        final raw = box.get(_hiveKey);
        if (raw is List && raw.isNotEmpty) {
          final out = <WorkoutLog>[];
          for (final j in raw) {
            try {
              if (j is Map<String, dynamic>) {
                out.add(WorkoutLog.fromJson(j));
              } else if (j is Map) {
                out.add(WorkoutLog.fromJson(Map<String, dynamic>.from(j)));
              }
            } catch (_) {}
          }
          if (out.isNotEmpty) return out;
        }
      }
    } catch (e) {
      debugPrint('WorkoutLogRepository.loadAll Hive error: $e');
    }

    // SharedPreferences fallback — keeps existing installations working
    return _storage.loadList<WorkoutLog>(StorageKeys.logs, WorkoutLog.fromJson);
  }

  /// Returns only active logs (deletedAt == null). Use for all UI rendering.
  Future<List<WorkoutLog>> loadActive() async {
    final all = await loadAll();
    return all.where((l) => !l.isDeleted).toList();
  }

  /// Returns only soft-deleted logs (deletedAt != null). Use for trash/restore UI.
  Future<List<WorkoutLog>> loadDeleted() async {
    final all = await loadAll();
    return all.where((l) => l.isDeleted).toList();
  }

  // ─── Write (local) ────────────────────────────────────────────────────────

  /// Persist the full log list to Hive and SharedPreferences.
  ///
  /// Mirrors workout_provider._saveLogs() exactly — both stores are always
  /// written in parallel so that neither gets out of sync.
  Future<void> saveAll(List<WorkoutLog> logs) async {
    final data = logs.map((l) => l.toJson()).toList();
    try {
      await Future.wait([
        _storage.logsBox?.put(_hiveKey, data) ?? Future.value(),
        _storage.setJson(StorageKeys.logs, data),
      ]);
    } catch (e, s) {
      debugPrint('WorkoutLogRepository.saveAll error: $e\n$s');
    }
  }

  // ─── Soft-delete / restore (outbox-first, RFC-002.4 §4.1) ────────────────

  /// Soft-deletes the log identified by [logId].
  ///
  /// Follows the four-step outbox-first protocol (§4.1):
  ///   1. Build payload with deletedAt = DateTime.now().toUtc()
  ///   2. Write outbox entry (LWW coalescing by hiveKey)
  ///   3. Write data box
  ///   (Step 4 — provider refresh — is the provider's responsibility)
  ///
  /// Idempotent: returns immediately if the log is already deleted.
  ///
  /// Throws [ArgumentError] if [logId] is not found in the data box.
  /// Throws on outbox write failure (state unchanged).
  /// Throws on data box write failure (outbox entry is preserved for recovery).
  Future<void> softDelete(String logId) async {
    final all = await loadAll();
    final index = all.indexWhere((l) => _adapter.docIdFor(l) == logId);
    if (index == -1) throw ArgumentError('WorkoutLog not found: $logId');

    final log = all[index];
    if (log.isDeleted) return; // idempotent — no write, no outbox enqueue

    // Step 1: Build payload.
    final updated = log.copyWith(deletedAt: DateTime.now().toUtc());

    // Step 2: Write outbox entry first.
    final op = SyncOp(
      collection: _adapter.collectionName,
      docId: logId,
      opType: SyncOpType.upsert,
      payload: _buildOutboxPayload(updated),
      enqueuedAt: DateTime.now(),
    );
    await _outbox.enqueue(op);

    // Step 3: Write data box.
    final updatedAll = List<WorkoutLog>.from(all);
    updatedAll[index] = updated;
    await saveAll(updatedAll);
  }

  /// Restores the soft-deleted log identified by [logId].
  ///
  /// Follows the four-step outbox-first protocol (§4.1):
  ///   1. Build payload with deletedAt = null
  ///   2. Write outbox entry (LWW coalescing; deletedAt key ABSENT per §6.1)
  ///   3. Write data box
  ///
  /// Idempotent: returns immediately if the log is already active.
  ///
  /// Throws [ArgumentError] if [logId] is not found in the data box.
  /// Throws on outbox write failure (state unchanged).
  /// Throws on data box write failure (outbox entry is preserved for recovery).
  Future<void> restore(String logId) async {
    final all = await loadAll();
    final index = all.indexWhere((l) => _adapter.docIdFor(l) == logId);
    if (index == -1) throw ArgumentError('WorkoutLog not found: $logId');

    final log = all[index];
    if (!log.isDeleted) return; // idempotent — no write, no outbox enqueue

    // Step 1: Build payload (deletedAt cleared via sentinel — key absent in JSON).
    final updated = log.copyWith(deletedAt: null);

    // Step 2: Write outbox entry first. Payload omits 'deletedAt' key (§6.1).
    final op = SyncOp(
      collection: _adapter.collectionName,
      docId: logId,
      opType: SyncOpType.upsert,
      payload: _buildOutboxPayload(updated),
      enqueuedAt: DateTime.now(),
    );
    await _outbox.enqueue(op);

    // Step 3: Write data box.
    final updatedAll = List<WorkoutLog>.from(all);
    updatedAll[index] = updated;
    await saveAll(updatedAll);
  }

  // ─── Outbox (cloud sync) ──────────────────────────────────────────────────

  /// Enqueue a cloud upsert for [log].
  ///
  /// [writerDeviceId] must be a stable device identifier sourced from the
  /// sync engine context (see Phase 3 wiring). Never pass an empty string —
  /// the gateway will write it verbatim to Firestore as the sync contract field.
  ///
  /// No-op in effect while SyncMode == disabled (OutboxService.flush never runs).
  /// The op is still stored in the outbox so it flushes as soon as the mode
  /// is advanced by a server-side flag update.
  Future<void> enqueueUpsert(WorkoutLog log, String writerDeviceId) async {
    final op = _adapter.toUpsertOp(log, writerDeviceId: writerDeviceId);
    await _outbox.enqueue(op);
  }

  /// Enqueue a cloud soft-delete for [log].
  ///
  /// The op carries a [deletedAt] epoch-millis timestamp in its payload.
  /// FirestoreGateway converts this to a Firestore Timestamp at flush time.
  Future<void> enqueueSoftDelete(WorkoutLog log, String writerDeviceId) async {
    final op = _adapter.toSoftDeleteOp(log, writerDeviceId: writerDeviceId);
    await _outbox.enqueue(op);
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Builds an outbox payload from [log] for the outbox-first protocol.
  ///
  /// Uses [LogsSyncAdapter.toPayload] as the base (Firestore-compatible fields)
  /// and appends [deletedAt] as an ISO-8601 UTC string when non-null.
  /// When [log.deletedAt] is null, the key is absent entirely (§6.1 contract).
  ///
  /// The format is readable by [WorkoutLog.fromJson] in the recovery pass (M-01),
  /// and compatible with [Gateway.upsert] when sync is eventually enabled.
  Map<String, dynamic> _buildOutboxPayload(WorkoutLog log) {
    final payload =
        _adapter.toPayload(log, writerDeviceId: _outbox.writerDeviceId);
    if (log.deletedAt != null) {
      payload['deletedAt'] = log.deletedAt!.toUtc().toIso8601String();
    }
    // deletedAt key is absent when null — WorkoutLog.fromJson treats absence
    // as null (restore intent). Do NOT add 'deletedAt': null.
    return payload;
  }
}
