// test/data/adapters/logs_sync_adapter_test.dart
//
// Unit tests for LogsSyncAdapter — the RFC-002.1 vertical slice for logs.
// Pure Dart — no Firebase, no Hive, no network.
//
// §1  Metadata
// §2  docIdFor — determinism and format
// §3  toPayload — RFC-002 contract
// §4  fromPayload — null cases + valid reconstruction

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/data/adapters/logs_sync_adapter.dart';
import 'package:gymtrackerpromaster/models/workout_log.dart';

void main() {
  late LogsSyncAdapter adapter;

  setUp(() {
    adapter = LogsSyncAdapter();
  });

  // ── §1 Metadata ───────────────────────────────────────────────────────────

  group('LogsSyncAdapter metadata', () {
    test('collectionName is logs', () {
      expect(adapter.collectionName, equals('logs'));
    });

    test('schemaVersion is 1 (matches WorkoutLog._dataVersion)', () {
      expect(adapter.schemaVersion, equals(1));
    });
  });

  // ── §2 docIdFor — determinism and format ──────────────────────────────────

  group('LogsSyncAdapter.docIdFor', () {
    test('weighted log produces correct deterministic docId', () {
      final log = WorkoutLog(
        exercise: 'Bench Press',
        date: DateTime.utc(2024, 1, 15),
        weight: 80.0,
        reps: 10,
        minutes: 0,
      );
      expect(adapter.docIdFor(log), equals('bench_press_2024-01-15_80.0_10_0'));
    });

    test('bodyweight log (weight=0) produces correct docId', () {
      final log = WorkoutLog(
        exercise: 'Pull Up',
        date: DateTime.utc(2024, 3, 1),
        weight: 0.0,
        reps: 12,
        minutes: 0,
      );
      expect(adapter.docIdFor(log), equals('pull_up_2024-03-01_0.0_12_0'));
    });

    test('timed log (weight=0, reps=0) produces correct docId', () {
      final log = WorkoutLog(
        exercise: 'Plank',
        date: DateTime.utc(2024, 6, 15),
        weight: 0.0,
        reps: 0,
        minutes: 5,
      );
      expect(adapter.docIdFor(log), equals('plank_2024-06-15_0.0_0_5'));
    });

    test('same log always produces same docId (determinism)', () {
      final log = WorkoutLog(
        exercise: 'Squat',
        date: DateTime.utc(2024, 2, 20),
        weight: 100.0,
        reps: 5,
        minutes: 0,
      );
      expect(adapter.docIdFor(log), equals(adapter.docIdFor(log)));
    });

    test('logs differing only in reps produce different docIds', () {
      final log8 = WorkoutLog(
        exercise: 'Bench Press',
        date: DateTime.utc(2024, 1, 15),
        weight: 80.0,
        reps: 8,
        minutes: 0,
      );
      final log10 = log8.copyWith(reps: 10);
      expect(adapter.docIdFor(log8), isNot(equals(adapter.docIdFor(log10))));
    });

    test('exercise is normalised (lowercase + underscores)', () {
      final log = WorkoutLog(
        exercise: 'Overhead Press',
        date: DateTime.utc(2024, 5, 10),
        weight: 60.0,
        reps: 6,
        minutes: 0,
      );
      expect(adapter.docIdFor(log), startsWith('overhead_press_'));
    });
  });

  // ── §3 toPayload — RFC-002 contract ───────────────────────────────────────

  group('LogsSyncAdapter.toPayload', () {
    const writerDeviceId = 'dev_abc123';

    test('includes all required RFC-002 fields', () {
      final log = WorkoutLog(
        exercise: 'Squat',
        date: DateTime.utc(2024, 3, 10),
        weight: 120.0,
        reps: 4,
        minutes: 0,
      );

      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);

      expect(payload, containsPair('exercise', 'squat'));
      expect(payload, contains('date'));
      expect(payload, containsPair('weight', 120.0));
      expect(payload, containsPair('reps', 4));
      expect(payload, containsPair('minutes', 0));
      expect(payload, containsPair('schemaVersion', 1));
      expect(payload, containsPair('writerDeviceId', writerDeviceId));
    });

    test('does NOT include updatedAt (gateway appends it as server timestamp)', () {
      final log = _makeWeightedLog();
      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      expect(payload, isNot(contains('updatedAt')));
    });

    test('does NOT include v key (WorkoutLog.toJson artifact)', () {
      final log = _makeWeightedLog();
      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      expect(payload, isNot(contains('v')));
    });

    test('muscleGroup is included when non-null and non-empty', () {
      final log = WorkoutLog(
        exercise: 'Squat',
        date: DateTime.utc(2024, 3, 10),
        weight: 120.0,
        reps: 4,
        minutes: 0,
        muscleGroup: 'legs',
      );

      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      expect(payload, containsPair('muscleGroup', 'legs'));
    });

    test('muscleGroup is omitted when null', () {
      final log = WorkoutLog(
        exercise: 'Bench Press',
        date: DateTime.utc(2024, 1, 15),
        weight: 80.0,
        reps: 10,
        minutes: 0,
      );

      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      expect(payload, isNot(contains('muscleGroup')));
    });

    test('exercise field uses normalizedExercise (lowercase + underscores)', () {
      final log = WorkoutLog(
        exercise: 'Bench Press',
        date: DateTime.utc(2024, 1, 15),
        weight: 80.0,
        reps: 10,
        minutes: 0,
      );

      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      expect(payload['exercise'], equals('bench_press'));
    });

    test('date field is ISO-8601 string', () {
      final log = _makeWeightedLog();
      final payload = adapter.toPayload(log, writerDeviceId: writerDeviceId);
      final date = payload['date'];
      expect(date, isA<String>());
      expect(DateTime.tryParse(date as String), isNotNull);
    });
  });

  // ── §4 fromPayload — null cases + valid reconstruction ────────────────────

  group('LogsSyncAdapter.fromPayload', () {
    test('returns null for soft-deleted doc (deletedAt present)', () {
      final doc = <String, dynamic>{
        'exercise': 'squat',
        'date': '2024-03-10T00:00:00.000Z',
        'weight': 120.0,
        'reps': 4,
        'minutes': 0,
        'deletedAt': 1709251200000,
      };
      expect(adapter.fromPayload(doc), isNull);
    });

    test('returns non-null for empty map (WorkoutLog.fromJson is fully defensive)', () {
      // WorkoutLog.fromJson never throws on missing fields — it substitutes safe
      // defaults (empty exercise, epoch date, weight/reps/minutes = 0).
      // fromPayload only returns null when deletedAt is present or fromJson throws.
      expect(adapter.fromPayload({}), isNotNull);
    });

    test('reconstructs valid WorkoutLog from a well-formed payload', () {
      final doc = <String, dynamic>{
        'exercise': 'bench_press',
        'date': '2024-01-15T00:00:00.000Z',
        'weight': 80.0,
        'reps': 10,
        'minutes': 0,
        'muscleGroup': 'chest',
        'schemaVersion': 1,
        'writerDeviceId': 'dev_abc123',
      };

      final log = adapter.fromPayload(doc);
      expect(log, isNotNull);
      expect(log!.exercise, equals('bench_press'));
      expect(log.weight, equals(80.0));
      expect(log.reps, equals(10));
      expect(log.minutes, equals(0));
      expect(log.muscleGroup, equals('chest'));
    });

    test('fromPayload does not throw when date is missing (fully defensive)', () {
      final doc = <String, dynamic>{
        'exercise': 'squat',
        'weight': 100.0,
        'reps': 5,
        // no 'date'
      };
      // WorkoutLog.fromJson handles missing date by defaulting to epoch 0;
      // fromPayload will succeed (not throw), so result is non-null.
      // The important contract is no exception is thrown.
      expect(() => adapter.fromPayload(doc), returnsNormally);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

WorkoutLog _makeWeightedLog() => WorkoutLog(
      exercise: 'Bench Press',
      date: DateTime.utc(2024, 1, 15),
      weight: 80.0,
      reps: 10,
      minutes: 0,
    );
