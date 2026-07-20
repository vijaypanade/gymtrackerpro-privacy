// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/models/workout_log.dart';

void main() {
  setUp(() {
    // Reset Crashlytics override before each test.
    WorkoutLog.crashlyticsReporter = null;
  });

  tearDown(() {
    WorkoutLog.crashlyticsReporter = null;
  });

  // ── helpers ───────────────────────────────────────────────────────────────

  WorkoutLog _baseLog({DateTime? deletedAt}) => WorkoutLog(
        exercise: 'bench_press',
        date: DateTime.utc(2026, 1, 15, 8, 0),
        weight: 100.0,
        reps: 8,
        minutes: 0,
        muscleGroup: 'chest',
        deletedAt: deletedAt,
      );

  Map<String, dynamic> _baseJson({Object? deletedAt = _absent}) => {
        'v': 1,
        'exercise': 'bench_press',
        'date': '2026-01-15T08:00:00.000Z',
        'weight': 100.0,
        'reps': 8,
        'minutes': 0,
        'muscleGroup': 'chest',
        if (!identical(deletedAt, _absent)) 'deletedAt': deletedAt,
      };

  group('isDeleted getter', () {
    test('null deletedAt → isDeleted == false', () {
      expect(_baseLog().isDeleted, isFalse);
    });

    test('non-null deletedAt → isDeleted == true', () {
      expect(_baseLog(deletedAt: DateTime.utc(2026, 7, 1)).isDeleted, isTrue);
    });
  });

  // ── copyWith sentinel ─────────────────────────────────────────────────────

  group('copyWith — sentinel pattern', () {
    test('copyWith() leaves deletedAt unchanged when field not provided', () {
      final dt = DateTime.utc(2026, 7, 1);
      final log = _baseLog(deletedAt: dt);
      final copy = log.copyWith(exercise: 'squat');
      expect(copy.deletedAt, equals(dt));
    });

    test('copyWith(deletedAt: null) clears deletedAt to null (restore path)', () {
      final log = _baseLog(deletedAt: DateTime.utc(2026, 7, 1));
      final restored = log.copyWith(deletedAt: null);
      expect(restored.deletedAt, isNull);
      expect(restored.isDeleted, isFalse);
    });

    test('copyWith(deletedAt: someDate) sets deletedAt', () {
      final log = _baseLog();
      final dt = DateTime.utc(2026, 7, 11, 14, 32);
      final deleted = log.copyWith(deletedAt: dt);
      expect(deleted.deletedAt, equals(dt));
      expect(deleted.isDeleted, isTrue);
    });

    test('copyWith preserves all other fields unchanged', () {
      final original = _baseLog(deletedAt: DateTime.utc(2026, 7, 1));
      final copy = log_copyWithDeletedAt(original, null);
      expect(copy.exercise, equals(original.exercise));
      expect(copy.date, equals(original.date));
      expect(copy.weight, equals(original.weight));
      expect(copy.reps, equals(original.reps));
      expect(copy.minutes, equals(original.minutes));
      expect(copy.muscleGroup, equals(original.muscleGroup));
    });
  });

  // ── toJson / G-05 ─────────────────────────────────────────────────────────

  group('toJson — null-omission contract (§6.1)', () {
    // G-05
    test('deletedAt == null → key "deletedAt" absent from toJson() output', () {
      final json = _baseLog().toJson();
      expect(json.containsKey('deletedAt'), isFalse,
          reason:
              'G-05: toJson() must omit the deletedAt key entirely when null — '
              'not set to null');
    });

    test('deletedAt != null → key present as ISO-8601 UTC string', () {
      final dt = DateTime.utc(2026, 7, 11, 14, 32, 0);
      final json = _baseLog(deletedAt: dt).toJson();
      expect(json.containsKey('deletedAt'), isTrue);
      expect(json['deletedAt'], equals('2026-07-11T14:32:00.000Z'));
    });

    test('deletedAt non-UTC is stored as UTC', () {
      final dtLocal = DateTime(2026, 7, 11, 10, 0).toUtc();
      final json = _baseLog(deletedAt: dtLocal).toJson();
      final stored = json['deletedAt'] as String;
      expect(stored.endsWith('Z'), isTrue);
    });
  });

  // ── fromJson — §3.3 rows ──────────────────────────────────────────────────

  group('fromJson — §3.3 lenient contract', () {
    // Row 1: key absent
    test('Row 1 — key absent → log is active, no Crashlytics', () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      final log = WorkoutLog.fromJson(_baseJson());
      expect(log.deletedAt, isNull);
      expect(log.isDeleted, isFalse);
      expect(captured, isEmpty, reason: 'Row 1 must not emit Crashlytics');
    });

    // Row 2: key present, JSON null
    test('Row 2 — key present with null value → log is active, no Crashlytics',
        () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      final log = WorkoutLog.fromJson(_baseJson(deletedAt: null));
      expect(log.deletedAt, isNull);
      expect(log.isDeleted, isFalse);
      expect(captured, isEmpty, reason: 'Row 2 must not emit Crashlytics');
    });

    // Row 3: valid ISO-8601
    test('Row 3 — valid ISO-8601 string → parsed to UTC DateTime, no Crashlytics',
        () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      const iso = '2026-07-11T14:32:00.000Z';
      final log =
          WorkoutLog.fromJson(_baseJson(deletedAt: iso));
      expect(log.deletedAt, isNotNull);
      expect(log.deletedAt!.isUtc, isTrue);
      expect(log.deletedAt!.toIso8601String(), equals(iso));
      expect(log.isDeleted, isTrue);
      expect(captured, isEmpty, reason: 'Row 3 must not emit Crashlytics');
    });

    // Row 4: integer (Unix ms) — G-03
    test(
        'G-03 / Row 4 — integer Unix-ms → parse succeeds, log is deleted, '
        'Crashlytics migration warning emitted', () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      final epochMs = DateTime.utc(2026, 7, 11).millisecondsSinceEpoch;
      final log = WorkoutLog.fromJson(
        _baseJson(deletedAt: epochMs),
        recordKey: 'logs|test_doc',
      );

      expect(log.isDeleted, isTrue,
          reason: 'G-03: integer deletedAt must mark log as deleted');
      expect(log.deletedAt, isNotNull);

      expect(captured.length, equals(1),
          reason: 'G-03: Crashlytics migration warning must be emitted');
      final evt = captured.first;
      expect(evt['failure_reason'], equals('integer_migration_warning'));
      expect(evt['value_runtime_type'], equals('int'));
    });

    // Row 5: non-null unparseable — G-04
    test(
        'G-04 / Row 5 — unparseable string → log is active, '
        'Crashlytics non-fatal emitted', () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      final log = WorkoutLog.fromJson(
        _baseJson(deletedAt: 'banana'),
        recordKey: 'logs|test_doc',
      );

      expect(log.deletedAt, isNull, reason: 'G-04: log must be treated as active');
      expect(log.isDeleted, isFalse);

      expect(captured.length, equals(1),
          reason: 'G-04: Crashlytics non-fatal must be emitted');
      final evt = captured.first;
      expect(evt['failure_reason'], equals('invalid_iso8601_format'));
      expect(evt['value_runtime_type'], equals('String'));
      expect(evt.containsKey('value_length'), isTrue);
      expect(evt['value_length'], equals(6)); // 'banana'.length
    });

    // Row 5: unexpected type
    test('Row 5 — unexpected type (bool) → log is active, Crashlytics emitted',
        () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      final log =
          WorkoutLog.fromJson(_baseJson(deletedAt: true));
      expect(log.isDeleted, isFalse);
      expect(captured.length, equals(1));
      expect(captured.first['failure_reason'], equals('unexpected_type'));
    });
  });

  // ── G-13: Crashlytics privacy contract ───────────────────────────────────

  group('G-13 — Crashlytics payload structure (§3.4)', () {
    test(
        'G-13 — non-fatal event contains all 6 required fields and no raw values',
        () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      WorkoutLog.fromJson(
        _baseJson(deletedAt: 'not-a-date'),
        recordKey: 'logs|abc123',
      );

      expect(captured.length, equals(1),
          reason: 'G-13: exactly one non-fatal event expected');
      final evt = captured.first;

      // (a) All 6 required fields present.
      expect(evt.containsKey('record_key'), isTrue);
      expect(evt.containsKey('app_version'), isTrue);
      expect(evt.containsKey('field_name'), isTrue);
      expect(evt.containsKey('value_runtime_type'), isTrue);
      expect(evt.containsKey('failure_reason'), isTrue);
      // value_length is present for string values.
      expect(evt.containsKey('value_length'), isTrue,
          reason: 'G-13: value_length required when raw value is a String');

      // (b) field_name must be 'deletedAt'.
      expect(evt['field_name'], equals('deletedAt'));

      // (c) record_key matches what was passed in.
      expect(evt['record_key'], equals('logs|abc123'));

      // (d) No raw WorkoutLog field values present.
      // Check that exercise, weight, reps etc. are not keys in the event.
      for (final forbiddenKey in [
        'exercise',
        'weight',
        'reps',
        'minutes',
        'muscleGroup',
        'date',
      ]) {
        expect(evt.containsKey(forbiddenKey), isFalse,
            reason:
                'G-13: raw WorkoutLog field "$forbiddenKey" must not appear '
                'in Crashlytics payload');
      }

      // (e) The raw deletedAt value itself is not present.
      expect(evt.containsKey('deletedAt'), isFalse,
          reason: 'G-13: raw deletedAt value must not appear in Crashlytics payload');

      // (f) Only exactly the permitted keys are present.
      final allowed = {
        'record_key',
        'app_version',
        'field_name',
        'value_runtime_type',
        'failure_reason',
        'value_length',
      };
      for (final key in evt.keys) {
        expect(allowed.contains(key), isTrue,
            reason: 'G-13: unexpected key "$key" in Crashlytics payload');
      }
    });

    test('G-13 — integer migration warning payload structure', () {
      final captured = <Map<String, dynamic>>[];
      WorkoutLog.crashlyticsReporter = captured.add;

      WorkoutLog.fromJson(
        _baseJson(deletedAt: 1720699200000),
        recordKey: 'logs|abc123',
      );

      final evt = captured.first;
      expect(evt['field_name'], equals('deletedAt'));
      expect(evt['failure_reason'], equals('integer_migration_warning'));
      expect(evt['value_runtime_type'], equals('int'));
      // value_length is NOT present for non-string types.
      expect(evt.containsKey('value_length'), isFalse);

      // No raw values.
      expect(evt.containsKey('deletedAt'), isFalse);
    });
  });

  // ── toJson / fromJson round-trip ──────────────────────────────────────────

  group('serialization round-trips', () {
    test('active log survives round-trip without deletedAt key', () {
      final original = _baseLog();
      final json = original.toJson();
      expect(json.containsKey('deletedAt'), isFalse); // null-omission
      final restored = WorkoutLog.fromJson(json);
      expect(restored.deletedAt, isNull);
      expect(restored.isDeleted, isFalse);
    });

    test('deleted log survives round-trip with deletedAt preserved', () {
      final dt = DateTime.utc(2026, 7, 11, 14, 32, 0);
      final original = _baseLog(deletedAt: dt);
      final json = original.toJson();
      expect(json.containsKey('deletedAt'), isTrue);
      final restored = WorkoutLog.fromJson(json);
      expect(restored.deletedAt, equals(dt));
      expect(restored.isDeleted, isTrue);
    });

    test('existing records without deletedAt field remain active after migration',
        () {
      // Simulates pre-RFC-002.4 records that have no deletedAt key.
      final legacyJson = {
        'v': 1,
        'exercise': 'squat',
        'date': '2025-06-01T10:00:00.000Z',
        'weight': 80.0,
        'reps': 5,
        'minutes': 0,
        'muscleGroup': 'legs',
      };
      final log = WorkoutLog.fromJson(legacyJson);
      expect(log.deletedAt, isNull);
      expect(log.isDeleted, isFalse);
    });
  });

  // ── equality and hashCode ─────────────────────────────────────────────────

  group('equality', () {
    test('two logs with same fields (including deletedAt) are equal', () {
      final dt = DateTime.utc(2026, 7, 1);
      expect(_baseLog(deletedAt: dt), equals(_baseLog(deletedAt: dt)));
    });

    test('logs differ when one has deletedAt and other does not', () {
      expect(_baseLog(), isNot(equals(_baseLog(deletedAt: DateTime.utc(2026, 7, 1)))));
    });

    test('hashCode consistent with equality', () {
      final dt = DateTime.utc(2026, 7, 1);
      expect(_baseLog(deletedAt: dt).hashCode,
          equals(_baseLog(deletedAt: dt).hashCode));
    });
  });

  // ── toString ─────────────────────────────────────────────────────────────

  group('toString', () {
    test('includes deletedAt when set', () {
      final dt = DateTime.utc(2026, 7, 11);
      expect(_baseLog(deletedAt: dt).toString(), contains('deletedAt:'));
    });

    test('shows null for deletedAt when active', () {
      expect(_baseLog().toString(), contains('deletedAt: null'));
    });
  });
}

// ── sentinel placeholder ───────────────────────────────────────────────────

/// Sentinel used by [_baseJson] to signal "don't include this key".
const Object _absent = Object();

/// Helper for copyWith test — avoids referencing private sentinel.
WorkoutLog log_copyWithDeletedAt(WorkoutLog log, DateTime? dt) =>
    log.copyWith(deletedAt: dt);
