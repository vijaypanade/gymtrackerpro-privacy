import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote/firestore_gateway.dart';
import 'models/sync_op.dart';
import 'sync_mode.dart';

/// Manages the local Hive-backed write queue (outbox) and flushes it to
/// Firestore when the sync mode permits.
///
/// Enqueue semantics (coalescing):
///   Hive key = SyncOp.hiveKey = "<collection>|<docId>".
///   box.put() replaces any existing entry for the same key, so only the
///   latest intent for each document is ever held in the outbox.
///
/// Flush semantics:
///   Ops are flushed FIFO by enqueuedAt. On success the entry is removed.
///   On failure the entry is updated with an incremented retryCount for
///   exponential back-off on the next flush cycle.
///   Partial progress is intentional — a single failed write does not block
///   subsequent ops for other documents.
///
/// RFC-002.1 ships with [SyncMode.disabled]: [flush] is a no-op and the
/// outbox accumulates enqueues silently until the mode is advanced.
class OutboxService {
  /// Hive box name for the outbox.
  /// Public so that main.dart can open it alongside the other app boxes in
  /// _initHive(). Not registered in StorageKeys — owned entirely by the sync
  /// subsystem with no legacy callers.
  static const String boxName = 'syncOutbox';

  /// App-wide singleton wired at startup.
  ///
  /// RFC-002.1 ships with [SyncMode.disabled]: [flush] is always a no-op at
  /// this mode level. The singleton can be used for enqueue() and pendingOps
  /// queries before the mode is ever advanced.
  ///
  /// TODO(RFC-002.x): replace the hardcoded disabled mode with a function that
  ///   reads the persisted SyncMode from settings, once mode advancement is
  ///   implemented.
  static final OutboxService instance = OutboxService(
    gateway: FirestoreGateway(),
    currentMode: () => SyncMode.disabled,
  );

  final FirestoreGateway _gateway;
  final SyncMode Function() _currentMode;

  Box? _box;
  String? _writerDeviceId;

  OutboxService({
    required FirestoreGateway gateway,
    required SyncMode Function() currentMode,
  })  : _gateway = gateway,
        _currentMode = currentMode;

  /// The current sync mode — callers can check this before scheduling flushes.
  SyncMode get syncMode => _currentMode();

  /// Stable device identifier included in every Firestore payload.
  ///
  /// Always available after [open] resolves (generated on first run,
  /// persisted in SharedPreferences). Returns 'pending' only if [open]
  /// has not been called yet, which must not happen in practice.
  String get writerDeviceId => _writerDeviceId ?? 'pending';

  /// Open the outbox Hive box and resolve the writer device ID.
  /// Must be called once during app startup before any enqueue/flush calls.
  Future<void> open() async {
    await Future.wait([
      _openBox(),
      _resolveWriterDeviceId(),
    ]);
  }

  Future<void> _openBox() async {
    if (_box != null && _box!.isOpen) return;
    try {
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
    } catch (e, s) {
      debugPrint('OutboxService._openBox failed: $e\n$s');
    }
  }

  /// Generate a stable per-device identifier on first run; persist and reuse.
  ///
  /// The ID has the form "dev_<hex>" derived from the first-run timestamp.
  /// It is not a true UUID but is unique enough for a single-user, single-device
  /// context and requires no additional dependency.
  Future<void> _resolveWriterDeviceId() async {
    if (_writerDeviceId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = '_sync_writer_device_id_v1';
      var id = prefs.getString(key);
      if (id == null || id.isEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        id = 'dev_${ts.toRadixString(16)}';
        await prefs.setString(key, id);
      }
      _writerDeviceId = id;
    } catch (e) {
      debugPrint('OutboxService._resolveWriterDeviceId error: $e');
    }
  }

  bool get _isReady => _box != null && _box!.isOpen;

  // ─── Enqueue ────────────────────────────────────────────────────────────

  /// Add [op] to the outbox.
  ///
  /// If an entry for [op.hiveKey] already exists it is replaced (coalesced)
  /// so only the latest intent for a given document is ever flushed.
  Future<void> enqueue(SyncOp op) async {
    if (!_isReady) {
      debugPrint('OutboxService.enqueue: box not open — skipping ${op.hiveKey}');
      return;
    }
    try {
      await _box!.put(op.hiveKey, op.toMap());
    } catch (e) {
      debugPrint('OutboxService.enqueue error for ${op.hiveKey}: $e');
    }
  }

  // ─── Pending ops ────────────────────────────────────────────────────────

  /// All pending ops sorted oldest-first (FIFO flush order).
  List<SyncOp> get pendingOps {
    if (!_isReady) return const [];
    try {
      return _box!.values
          .whereType<Map>()
          .map((m) => SyncOp.fromMap(m))
          .where((op) => op.collection.isNotEmpty && op.docId.isNotEmpty)
          .toList()
        ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    } catch (e) {
      debugPrint('OutboxService.pendingOps error: $e');
      return const [];
    }
  }

  /// Number of pending ops. O(1) via Hive's length property.
  int get pendingCount => _isReady ? _box!.length : 0;

  // ─── Flush ──────────────────────────────────────────────────────────────

  /// Flush all pending ops to Firestore for the authenticated [uid].
  ///
  /// No-op if [SyncMode.isActive] is false (RFC-002.1 ships disabled).
  ///
  /// Ops are processed FIFO. Each successful write removes the entry from the
  /// outbox. Each failed write increments retryCount and re-stores the op for
  /// the next flush cycle; processing continues with remaining ops.
  ///
  /// This method does NOT schedule itself — the caller (e.g. a periodic timer
  /// or connectivity listener wired in Phase 3) is responsible for scheduling.
  Future<void> flush(String uid) async {
    if (!_currentMode().isActive) return;
    if (!_isReady) return;

    final ops = pendingOps;
    for (final op in ops) {
      final path = 'users/$uid/${op.collection}/${op.docId}';
      try {
        switch (op.opType) {
          case SyncOpType.upsert:
            await _gateway.upsert(path, op.payload);
          case SyncOpType.softDelete:
            await _gateway.softDelete(path, op.payload);
        }
        await _box!.delete(op.hiveKey);
      } catch (e) {
        debugPrint('OutboxService.flush error for $path: $e');
        final retried = op.withRetry();
        try {
          await _box!.put(retried.hiveKey, retried.toMap());
        } catch (_) {
          // If we can't even persist the retry, continue — the op stays at its
          // previous retryCount from the last successful put.
        }
      }
    }
  }
}
