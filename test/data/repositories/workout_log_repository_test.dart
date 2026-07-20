// Repository tests for RFC-002.4 §5 contracts.
//
// Outbox write-ordering crash-window scenarios (G-01, G-02) live in
// test/services/startup_recovery_test.dart — they need Hive.
// This file covers everything testable via an in-memory test double:
//
//   G-08  softDelete on already-deleted log → no write, no enqueue
//   G-09  restore on already-active log     → no write, no enqueue
//   G-10  softDelete → loadActive() excludes the log
//   G-11  restore    → loadDeleted() excludes the log
//   G-12  softDelete → loadDeleted() includes log with deletedAt != null
//
//   + loadActive / loadDeleted filtering
//   + error handling (not found)
//   + outbox payload contract (§6.1 null-omission for restore)
//   + write ordering invariant (outbox before data box)
//   + LWW coalescing key contract

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/data/adapters/logs_sync_adapter.dart';
import 'package:gymtrackerpromaster/data/repositories/workout_log_repository.dart';
import 'package:gymtrackerpromaster/data/remote/firestore_gateway.dart';
import 'package:gymtrackerpromaster/data/sync/models/sync_op.dart';
import 'package:gymtrackerpromaster/data/sync/outbox_service.dart';
import 'package:gymtrackerpromaster/data/sync/sync_mode.dart';
import 'package:gymtrackerpromaster/models/workout_log.dart';
import 'package:gymtrackerpromaster/services/storage_service.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

/// OutboxService that captures enqueued ops without requiring Hive.
///
/// Overrides [enqueue] — the stored [FirestoreGateway] and mode function
/// are never called so Firebase is never touched in unit tests.
class _RecordingOutbox extends OutboxService {
  final List<SyncOp> enqueuedOps = [];

  _RecordingOutbox()
      : super(
          gateway: FirestoreGateway(),
          currentMode: () => SyncMode.disabled,
        );

  @override
  Future<void> enqueue(SyncOp op) async => enqueuedOps.add(op);

  @override
  String get writerDeviceId => 'test-device';
}

/// Outbox that always throws — used to verify failure-path invariants.
class _FailingOutbox extends _RecordingOutbox {
  @override
  Future<void> enqueue(SyncOp op) async =>
      throw Exception('simulated Hive outbox write failure');
}

/// Outbox that records 'enqueue' calls to a shared call-sequence list.
/// Used together with [_OrderingTestRepo] to verify write ordering.
class _TrackingOutbox extends _RecordingOutbox {
  final List<String> calls;

  _TrackingOutbox(this.calls);

  @override
  Future<void> enqueue(SyncOp op) async {
    calls.add('enqueue');
    await super.enqueue(op); // also stores in enqueuedOps
  }
}

/// WorkoutLogRepository backed by an in-memory list.
///
/// Overrides [loadAll] and [saveAll] to avoid any Hive / SharedPreferences I/O
/// while exercising the real production logic in softDelete, restore,
/// loadActive, and loadDeleted.
class _MemRepo extends WorkoutLogRepository {
  List<WorkoutLog> _data;

  // Public — subclasses and tests access this for assertions.
  final _RecordingOutbox testOutbox;

  _MemRepo._(List<WorkoutLog> initial, _RecordingOutbox outbox)
      : _data = List.from(initial),
        testOutbox = outbox,
        super(
          storage: StorageService.instance, // never reached — loadAll/saveAll overridden
          outbox: outbox,
          adapter: LogsSyncAdapter(),
        );

  factory _MemRepo(List<WorkoutLog> initial, [_RecordingOutbox? outbox]) =>
      _MemRepo._(initial, outbox ?? _RecordingOutbox());

  @override
  Future<List<WorkoutLog>> loadAll() async => List.from(_data);

  @override
  Future<void> saveAll(List<WorkoutLog> logs) async =>
      _data = List.from(logs);
}

/// Extends [_MemRepo] to record the SEQUENCE of outbox-enqueue and
/// saveAll calls so that write-ordering can be asserted.
class _OrderingTestRepo extends _MemRepo {
  final List<String> calls;

  _OrderingTestRepo(List<WorkoutLog> initial, List<String> calls)
      : calls = calls,
        super._(initial, _TrackingOutbox(calls));

  @override
  Future<void> saveAll(List<WorkoutLog> logs) async {
    calls.add('saveAll');
    await super.saveAll(logs);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

final _adapter = LogsSyncAdapter();

String _docId(WorkoutLog log) => _adapter.docIdFor(log);

WorkoutLog _log({
  String exercise = 'bench_press',
  double weight = 100.0,
  int reps = 8,
  DateTime? date,
  DateTime? deletedAt,
}) =>
    WorkoutLog(
      exercise: exercise,
      date: date ?? DateTime.utc(2026, 1, 15, 8, 0),
      weight: weight,
      reps: reps,
      minutes: 0,
      muscleGroup: 'chest',
      deletedAt: deletedAt,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => WorkoutLog.crashlyticsReporter = (_) {});
  tearDown(() => WorkoutLog.crashlyticsReporter = null);

  // ── loadActive / loadDeleted ───────────────────────────────────────────────

  group('loadActive()', () {
    test('returns only logs where isDeleted == false', () async {
      final active = _log();
      final deleted = _log(exercise: 'squat', deletedAt: DateTime.utc(2026, 7, 1));
      final result = await _MemRepo([active, deleted]).loadActive();

      expect(result.length, 1);
      expect(result.first.exercise, 'bench_press');
      expect(result.first.isDeleted, isFalse);
    });

    test('returns empty list when all logs are deleted', () async {
      final repo = _MemRepo([
        _log(deletedAt: DateTime.utc(2026, 7, 1)),
        _log(exercise: 'squat', deletedAt: DateTime.utc(2026, 7, 1)),
      ]);
      expect(await repo.loadActive(), isEmpty);
    });

    test('returns all logs when none are deleted', () async {
      final repo = _MemRepo([_log(), _log(exercise: 'squat')]);
      expect((await repo.loadActive()).length, 2);
    });
  });

  group('loadDeleted()', () {
    test('returns only logs where isDeleted == true', () async {
      final dt = DateTime.utc(2026, 7, 1);
      final repo = _MemRepo([
        _log(),
        _log(exercise: 'squat', deletedAt: dt),
      ]);
      final result = await repo.loadDeleted();

      expect(result.length, 1);
      expect(result.first.exercise, 'squat');
      expect(result.first.isDeleted, isTrue);
    });

    test('returns empty when no deleted logs', () async {
      expect(await _MemRepo([_log()]).loadDeleted(), isEmpty);
    });
  });

  group('loadAll()', () {
    test('includes both active and deleted records', () async {
      final repo = _MemRepo([
        _log(),
        _log(exercise: 'squat', deletedAt: DateTime.utc(2026, 7, 1)),
      ]);
      expect((await repo.loadAll()).length, 2);
    });
  });

  // ── softDelete — happy path ────────────────────────────────────────────────

  group('softDelete() — happy path', () {
    // G-10
    test(
        'G-10 — loadActive() does not contain the log after softDelete()',
        () async {
      final log = _log();
      final repo = _MemRepo([log]);
      await repo.softDelete(_docId(log));

      final active = await repo.loadActive();
      expect(active.any((l) => _docId(l) == _docId(log)), isFalse,
          reason: 'G-10: deleted log must not appear in loadActive()');
    });

    // G-12
    test(
        'G-12 — loadDeleted() contains log with deletedAt != null after softDelete()',
        () async {
      final log = _log();
      final repo = _MemRepo([log]);
      await repo.softDelete(_docId(log));

      final deleted = await repo.loadDeleted();
      expect(deleted.length, 1, reason: 'G-12: log must appear in loadDeleted()');
      expect(deleted.first.deletedAt, isNotNull,
          reason: 'G-12: deletedAt must be non-null after softDelete()');
    });

    test('softDelete sets deletedAt to a UTC time near now', () async {
      final log = _log();
      final repo = _MemRepo([log]);
      final before = DateTime.now().toUtc();
      await repo.softDelete(_docId(log));
      final after = DateTime.now().toUtc();

      final dt = (await repo.loadDeleted()).first.deletedAt!;
      expect(dt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(dt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('softDelete outbox payload contains deletedAt as ISO-8601 string',
        () async {
      final log = _log();
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);
      await repo.softDelete(_docId(log));

      expect(outbox.enqueuedOps.length, 1);
      final op = outbox.enqueuedOps.first;
      expect(op.collection, 'logs');
      expect(op.docId, _docId(log));
      expect(op.opType, SyncOpType.upsert);
      expect(op.payload.containsKey('deletedAt'), isTrue,
          reason: 'softDelete payload must include deletedAt');
      // Must be ISO-8601 string (not epoch int) per §6.1 + M-01 decision.
      expect(op.payload['deletedAt'], isA<String>());
      expect(DateTime.tryParse(op.payload['deletedAt'] as String), isNotNull,
          reason: 'deletedAt in outbox payload must be valid ISO-8601');
    });

    test(
        'write ordering: outbox enqueue (step 2) precedes saveAll (step 3)',
        () async {
      final log = _log();
      final calls = <String>[];
      final repo = _OrderingTestRepo([log], calls);
      await repo.softDelete(_docId(log));

      expect(calls, hasLength(2));
      expect(calls[0], 'enqueue',
          reason: 'RFC-002.4 §4.1 step 2: outbox must be written first');
      expect(calls[1], 'saveAll',
          reason: 'RFC-002.4 §4.1 step 3: data box written after outbox');
    });
  });

  // ── restore — happy path ───────────────────────────────────────────────────

  group('restore() — happy path', () {
    // G-11
    test(
        'G-11 — loadDeleted() does not contain the log after restore()',
        () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final repo = _MemRepo([log]);
      await repo.restore(_docId(log));

      final deleted = await repo.loadDeleted();
      expect(deleted.any((l) => _docId(l) == _docId(log)), isFalse,
          reason: 'G-11: restored log must not appear in loadDeleted()');
    });

    test('restore moves log back into loadActive()', () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final repo = _MemRepo([log]);
      await repo.restore(_docId(log));

      final active = await repo.loadActive();
      expect(active.any((l) => _docId(l) == _docId(log)), isTrue);
    });

    test('restored log has deletedAt == null', () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final repo = _MemRepo([log]);
      await repo.restore(_docId(log));

      expect((await repo.loadActive()).first.deletedAt, isNull);
    });

    // §6.1 null-omission contract — absent key is the restore intent for M-01
    test(
        'restore outbox payload omits deletedAt key entirely (§6.1 null-omission)',
        () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);
      await repo.restore(_docId(log));

      expect(outbox.enqueuedOps.length, 1);
      final op = outbox.enqueuedOps.first;
      expect(op.payload.containsKey('deletedAt'), isFalse,
          reason:
              '§6.1: restore payload must omit deletedAt key — '
              'absence signals restore intent to WorkoutLog.fromJson (M-01)');
    });

    test(
        'write ordering: outbox enqueue (step 2) precedes saveAll (step 3)',
        () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final calls = <String>[];
      final repo = _OrderingTestRepo([log], calls);
      await repo.restore(_docId(log));

      expect(calls[0], 'enqueue');
      expect(calls[1], 'saveAll');
    });
  });

  // ── idempotency ───────────────────────────────────────────────────────────

  group('idempotency contracts', () {
    // G-08
    test(
        'G-08 — softDelete(logId) on already-deleted log → '
        'no write, no enqueue', () async {
      final dt = DateTime.utc(2026, 7, 1);
      final log = _log(deletedAt: dt);
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);

      await repo.softDelete(_docId(log));

      expect(outbox.enqueuedOps, isEmpty,
          reason: 'G-08: idempotent softDelete must not enqueue');
      expect((await repo.loadAll()).first.deletedAt, dt,
          reason: 'G-08: deletedAt must not be mutated on idempotent call');
    });

    // G-09
    test(
        'G-09 — restore(logId) on already-active log → '
        'no write, no enqueue', () async {
      final log = _log(); // active: deletedAt == null
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);

      await repo.restore(_docId(log));

      expect(outbox.enqueuedOps, isEmpty,
          reason: 'G-09: idempotent restore must not enqueue');
      expect((await repo.loadAll()).first.deletedAt, isNull,
          reason: 'G-09: deletedAt must remain null on idempotent call');
    });

    test('calling softDelete twice: second call is a no-op', () async {
      final log = _log();
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);

      await repo.softDelete(_docId(log));
      final firstTs = (await repo.loadDeleted()).first.deletedAt;

      await repo.softDelete(_docId(log)); // idempotent
      expect(outbox.enqueuedOps.length, 1,
          reason: 'second softDelete must not add another outbox entry');
      expect((await repo.loadDeleted()).first.deletedAt, firstTs,
          reason: 'deletedAt must not be updated on idempotent call');
    });
  });

  // ── error handling ────────────────────────────────────────────────────────

  group('error handling', () {
    test('softDelete throws ArgumentError when logId not found', () {
      final repo = _MemRepo([_log()]);
      expect(
        () => repo.softDelete('nonexistent|id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('restore throws ArgumentError when logId not found', () {
      final repo = _MemRepo([_log()]);
      expect(
        () => repo.restore('nonexistent|id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'softDelete propagates exception and leaves state unchanged '
        'when outbox write fails (§5.2)', () async {
      final log = _log();
      final repo = _MemRepo([log], _FailingOutbox());

      await expectLater(
        repo.softDelete(_docId(log)),
        throwsA(isA<Exception>()),
      );

      // Data box unchanged — log must still be active.
      expect((await repo.loadActive()).first.deletedAt, isNull,
          reason: '§5.2: outbox failure must leave data box unchanged');
    });

    test(
        'restore propagates exception and leaves state unchanged '
        'when outbox write fails (§5.3)', () async {
      final log = _log(deletedAt: DateTime.utc(2026, 7, 1));
      final repo = _MemRepo([log], _FailingOutbox());

      await expectLater(
        repo.restore(_docId(log)),
        throwsA(isA<Exception>()),
      );

      // Data box unchanged — log must still be deleted.
      expect((await repo.loadDeleted()).first.isDeleted, isTrue,
          reason: '§5.3: outbox failure must leave data box unchanged');
    });
  });

  // ── LWW coalescing key ────────────────────────────────────────────────────

  group('outbox LWW coalescing key', () {
    test(
        'softDelete then restore produce ops with the same hiveKey '
        '(LWW: last write wins)', () async {
      final log = _log();
      final outbox = _RecordingOutbox();
      final repo = _MemRepo([log], outbox);

      await repo.softDelete(_docId(log));
      await repo.restore(_docId(log));

      expect(outbox.enqueuedOps.length, 2);
      // Same hiveKey → OutboxService.box.put() keeps only the last op.
      expect(
        outbox.enqueuedOps[0].hiveKey,
        outbox.enqueuedOps[1].hiveKey,
        reason:
            'both ops must share the same hiveKey so LWW coalescing is correct',
      );
      // Op 0 (softDelete): deletedAt present.
      expect(outbox.enqueuedOps[0].payload.containsKey('deletedAt'), isTrue);
      // Op 1 (restore): deletedAt absent — restore intent per §6.1.
      expect(outbox.enqueuedOps[1].payload.containsKey('deletedAt'), isFalse);
    });

    test('hiveKey format is collection|docId', () async {
      final log = _log();
      final outbox = _RecordingOutbox();
      await _MemRepo([log], outbox).softDelete(_docId(log));

      final op = outbox.enqueuedOps.first;
      expect(op.hiveKey, '${op.collection}|${op.docId}');
      expect(op.hiveKey, startsWith('logs|'));
    });
  });
}
