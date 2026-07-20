// test/data/sync/sync_op_test.dart
//
// Unit tests for SyncOp serialisation and SyncMode behaviour.
// Pure Dart — no Firebase, no Hive, no network.
//
// §1  SyncOpType.fromString
// §2  SyncOp.hiveKey
// §3  SyncOp.toMap / fromMap round-trip
// §4  SyncOp.fromMap defensive parsing
// §5  SyncOp.withRetry
// §6  SyncMode.fromString
// §7  SyncMode.isActive

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/data/sync/models/sync_op.dart';
import 'package:gymtrackerpromaster/data/sync/sync_mode.dart';

void main() {
  // ── §1 SyncOpType.fromString ──────────────────────────────────────────────

  group('SyncOpType.fromString', () {
    test('deserialises upsert', () {
      expect(SyncOpType.fromString('upsert'), SyncOpType.upsert);
    });

    test('deserialises softDelete', () {
      expect(SyncOpType.fromString('softDelete'), SyncOpType.softDelete);
    });

    test('unknown string defaults to upsert', () {
      expect(SyncOpType.fromString('unknown'), SyncOpType.upsert);
      expect(SyncOpType.fromString(null), SyncOpType.upsert);
      expect(SyncOpType.fromString(''), SyncOpType.upsert);
    });
  });

  // ── §2 SyncOp.hiveKey ─────────────────────────────────────────────────────

  group('SyncOp.hiveKey', () {
    test('combines collection and docId with pipe separator', () {
      final op = _makeOp(collection: 'logs', docId: 'bench_press_2024-01-15');
      expect(op.hiveKey, equals('logs|bench_press_2024-01-15'));
    });

    test('same (collection, docId) always produces same hiveKey', () {
      final op1 = _makeOp(collection: 'logs', docId: 'squat_2024-03-01_100.0_5_0');
      final op2 = _makeOp(collection: 'logs', docId: 'squat_2024-03-01_100.0_5_0');
      expect(op1.hiveKey, equals(op2.hiveKey));
    });

    test('different docIds produce different hiveKeys', () {
      final op1 = _makeOp(collection: 'logs', docId: 'bench_2024-01-15_80.0_8_0');
      final op2 = _makeOp(collection: 'logs', docId: 'bench_2024-01-15_80.0_10_0');
      expect(op1.hiveKey, isNot(equals(op2.hiveKey)));
    });
  });

  // ── §3 SyncOp round-trip ──────────────────────────────────────────────────

  group('SyncOp toMap / fromMap round-trip', () {
    test('all fields survive upsert round-trip', () {
      final original = SyncOp(
        collection: 'logs',
        docId: 'bench_press_2024-01-15_80.0_10_0',
        opType: SyncOpType.upsert,
        payload: {
          'exercise': 'bench_press',
          'weight': 80.0,
          'reps': 10,
          'schemaVersion': 1,
          'writerDeviceId': 'dev_abc123',
        },
        enqueuedAt: DateTime.utc(2024, 1, 15, 10, 30),
        retryCount: 0,
      );

      final restored = SyncOp.fromMap(original.toMap());

      expect(restored.collection, equals(original.collection));
      expect(restored.docId, equals(original.docId));
      expect(restored.opType, equals(original.opType));
      expect(restored.payload['exercise'], equals('bench_press'));
      expect(restored.payload['weight'], equals(80.0));
      expect(restored.payload['schemaVersion'], equals(1));
      expect(restored.payload['writerDeviceId'], equals('dev_abc123'));
      expect(restored.enqueuedAt.millisecondsSinceEpoch,
          equals(original.enqueuedAt.millisecondsSinceEpoch));
      expect(restored.retryCount, equals(0));
    });

    test('softDelete opType survives round-trip', () {
      final op = SyncOp(
        collection: 'logs',
        docId: 'squat_2024-02-01_100.0_5_0',
        opType: SyncOpType.softDelete,
        payload: {'deletedAt': 1706745600000},
        enqueuedAt: DateTime.utc(2024, 2, 1),
      );

      final restored = SyncOp.fromMap(op.toMap());
      expect(restored.opType, equals(SyncOpType.softDelete));
      expect(restored.payload['deletedAt'], equals(1706745600000));
    });
  });

  // ── §4 SyncOp.fromMap defensive parsing ───────────────────────────────────

  group('SyncOp.fromMap defensive parsing', () {
    test('empty map returns op with safe defaults', () {
      final op = SyncOp.fromMap({});
      expect(op.collection, equals(''));
      expect(op.docId, equals(''));
      expect(op.opType, equals(SyncOpType.upsert));
      expect(op.payload, isEmpty);
      expect(op.retryCount, equals(0));
    });

    test('missing enqueuedAt uses DateTime.now() (non-null)', () {
      final op = SyncOp.fromMap({'collection': 'logs', 'docId': 'abc'});
      expect(op.enqueuedAt, isNotNull);
    });

    test('retryCount is clamped to 0-100', () {
      final tooHigh = SyncOp.fromMap({'retryCount': 999});
      expect(tooHigh.retryCount, equals(100));

      final negative = SyncOp.fromMap({'retryCount': -5});
      expect(negative.retryCount, equals(0));
    });

    test('non-map payload falls back to empty', () {
      final op = SyncOp.fromMap({'payload': 'not-a-map'});
      expect(op.payload, isEmpty);
    });
  });

  // ── §5 SyncOp.withRetry ───────────────────────────────────────────────────

  group('SyncOp.withRetry', () {
    test('increments retryCount by one', () {
      final op = _makeOp().withRetry();
      expect(op.retryCount, equals(1));
    });

    test('preserves all other fields', () {
      final original = _makeOp(
        collection: 'logs',
        docId: 'test_2024-01-01_50.0_5_0',
        opType: SyncOpType.upsert,
      );
      final retried = original.withRetry();
      expect(retried.collection, equals(original.collection));
      expect(retried.docId, equals(original.docId));
      expect(retried.opType, equals(original.opType));
      expect(retried.enqueuedAt, equals(original.enqueuedAt));
    });

    test('multiple retries accumulate correctly', () {
      final after3 = _makeOp().withRetry().withRetry().withRetry();
      expect(after3.retryCount, equals(3));
    });

    test('original is immutable — not modified by withRetry', () {
      final original = _makeOp();
      original.withRetry();
      expect(original.retryCount, equals(0));
    });
  });

  // ── §6 SyncMode.fromString ────────────────────────────────────────────────

  group('SyncMode.fromString', () {
    test('all valid strings deserialise correctly', () {
      expect(SyncMode.fromString('disabled'), SyncMode.disabled);
      expect(SyncMode.fromString('internal'), SyncMode.internal);
      expect(SyncMode.fromString('beta'), SyncMode.beta);
      expect(SyncMode.fromString('production'), SyncMode.production);
    });

    test('unknown string defaults to disabled', () {
      expect(SyncMode.fromString(null), SyncMode.disabled);
      expect(SyncMode.fromString(''), SyncMode.disabled);
      expect(SyncMode.fromString('enabled'), SyncMode.disabled);
    });
  });

  // ── §7 SyncMode.isActive ──────────────────────────────────────────────────

  group('SyncMode.isActive', () {
    test('disabled is not active', () {
      expect(SyncMode.disabled.isActive, isFalse);
    });

    test('all non-disabled modes are active', () {
      expect(SyncMode.internal.isActive, isTrue);
      expect(SyncMode.beta.isActive, isTrue);
      expect(SyncMode.production.isActive, isTrue);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

SyncOp _makeOp({
  String collection = 'logs',
  String docId = 'bench_press_2024-01-15_80.0_10_0',
  SyncOpType opType = SyncOpType.upsert,
}) {
  return SyncOp(
    collection: collection,
    docId: docId,
    opType: opType,
    payload: {'exercise': 'bench_press', 'schemaVersion': 1},
    enqueuedAt: DateTime.utc(2024, 1, 15),
    retryCount: 0,
  );
}
