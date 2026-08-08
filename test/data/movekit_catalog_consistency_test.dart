// test/data/movekit_catalog_consistency_test.dart
//
// RFC-005-A Step 1 consistency test for the generated MoveKit catalog.
// No Firebase, no Storage, no network, no video_player — asset + pure Dart only.
//
// §1  Runtime API — init, isLoaded, count, bySlug, findFor
// §2  Structural integrity — ids, slugs, non-empty fields
// §3  Slug rule — slug == slugify(name)
// §4  Aliases — parses and is empty
// §5  ExerciseData is untouched, and no MoveKit-only exercise has leaked into it
// §6  Prohibited fields are absent (RFC-005 §6.1 / §13.1 layer 2)

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/data/exercise_data.dart';
import 'package:gymtrackerpromaster/services/movekit_catalog_service.dart';

/// Frozen coverage figures from the 2026-08-08 report (RFC-005 §4.10).
///
/// These are deliberately brittle. They are what turns §5 from a tautology into
/// a real guard: "no MoveKit-only slug is in ExerciseData" is true by
/// definition, but pinning the counts means that adding a MoveKit-only exercise
/// to ExerciseData — or renaming an existing one — moves a number and fails the
/// test loudly instead of drifting silently.
const int _expectedCatalogCount = 412;
const int _expectedLiftOnCount = 141;
const int _expectedOverlap = 45;

/// MoveKit slugs with **no exact LiftOn match**: 412 − 45 = 367.
///
/// Not to be confused with the report's "MoveKit-only = 255" (RFC-005 §4.10),
/// which additionally excludes the 112 MoveKit exercises that have a *likely*
/// alias candidate. That figure only becomes meaningful once aliases are
/// approved; this test measures exact matching, which is all the resolver does
/// today.
const int _expectedNoExactMatch = 367;

const Set<String> _prohibitedFields = {
  'type',
  'movement',
  'bodyweight',
  'defaultWeight',
  'defaultReps',
  'emoji',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MoveKitCatalogService.init();
  });

  // ── §1 Runtime API ────────────────────────────────────────────────────────

  group('MoveKitCatalogService runtime', () {
    test('catalog loads', () {
      expect(MoveKitCatalogService.isLoaded, isTrue);
    });

    test('count is $_expectedCatalogCount', () {
      expect(MoveKitCatalogService.count, _expectedCatalogCount);
    });

    test('bySlug resolves the reference clip', () {
      expect(MoveKitCatalogService.bySlug('barbell-bench-press')?.id, 32);
    });

    test('findFor resolves a LiftOn exercise name', () {
      expect(MoveKitCatalogService.findFor('Barbell Bench Press')?.id, 32);
    });

    test('findFor returns null for an unknown exercise', () {
      expect(
        MoveKitCatalogService.findFor('Definitely Not A MoveKit Exercise'),
        isNull,
      );
    });

    test('init is idempotent', () async {
      await MoveKitCatalogService.init();
      expect(MoveKitCatalogService.count, _expectedCatalogCount);
    });
  });

  // ── §2 Structural integrity ───────────────────────────────────────────────

  group('catalog structure', () {
    late List<Map<String, dynamic>> entries;

    setUpAll(() async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      entries = (json.decode(raw) as Map<String, dynamic>)['entries']
          .cast<Map<String, dynamic>>() as List<Map<String, dynamic>>;
    });

    test('has exactly $_expectedCatalogCount entries', () {
      expect(entries.length, _expectedCatalogCount);
    });

    test('ids are exactly 1..$_expectedCatalogCount', () {
      final ids = entries.map((e) => e['id'] as int).toList();
      expect(ids, List<int>.generate(_expectedCatalogCount, (i) => i + 1));
    });

    test('ids are unique', () {
      final ids = entries.map((e) => e['id'] as int).toSet();
      expect(ids.length, entries.length);
    });

    test('slugs are unique', () {
      final slugs = entries.map((e) => e['slug'] as String).toSet();
      expect(slugs.length, entries.length);
    });

    test('name, muscle, equipment and slug are non-empty', () {
      for (final entry in entries) {
        for (final field in const ['name', 'muscle', 'equipment', 'slug']) {
          final value = entry[field];
          expect(
            value is String && value.trim().isNotEmpty,
            isTrue,
            reason: 'entry ${entry['id']} has a blank "$field"',
          );
        }
      }
    });
  });

  // ── §3 Slug rule ──────────────────────────────────────────────────────────

  group('slug rule', () {
    test('slugify follows the approved hyphen convention', () {
      expect(
        MoveKitCatalogService.slugify('Barbell Bench Press'),
        'barbell-bench-press',
      );
    });

    test('every slug equals slugify(name)', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      final entries = (json.decode(raw) as Map<String, dynamic>)['entries']
          as List<dynamic>;
      for (final entry in entries.cast<Map<String, dynamic>>()) {
        expect(
          entry['slug'],
          MoveKitCatalogService.slugify(entry['name'] as String),
          reason: 'entry ${entry['id']} (${entry['name']}) has a stale slug',
        );
      }
    });
  });

  // ── §4 Aliases ────────────────────────────────────────────────────────────

  group('aliases', () {
    test('parses and is empty', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_aliases.json');
      final decoded = json.decode(raw);
      expect(decoded, isA<Map<String, dynamic>>());
      expect(
        (decoded as Map<String, dynamic>).isEmpty,
        isTrue,
        reason: 'no alias has been approved yet — RFC-005 §5.4, §22 item 8',
      );
    });
  });

  // ── §5 ExerciseData untouched, and no MoveKit-only leak ───────────────────

  group('planner catalog boundary', () {
    test('ExerciseData still holds exactly $_expectedLiftOnCount exercises', () {
      expect(ExerciseData.list.length, _expectedLiftOnCount);
    });

    test('overlap and MoveKit-only counts are unchanged', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      final moveKitSlugs = ((json.decode(raw) as Map<String, dynamic>)['entries']
              as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => e['slug'] as String)
          .toSet();

      final liftOnSlugs = ExerciseData.list
          .map((e) => MoveKitCatalogService.slugify(e['name'] as String))
          .toSet();

      final overlap = moveKitSlugs.intersection(liftOnSlugs);
      final moveKitOnly = moveKitSlugs.difference(liftOnSlugs);

      expect(overlap.length, _expectedOverlap,
          reason: 'exact-match coverage changed — a name was renamed on one '
              'side, or ExerciseData gained a MoveKit exercise');
      expect(moveKitOnly.length, _expectedNoExactMatch,
          reason: 'a MoveKit-only exercise may have leaked into ExerciseData '
              '(RFC-005 §13.1 layer 4)');
    });

    test('no MoveKit-only slug appears in ExerciseData', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      final moveKitSlugs = ((json.decode(raw) as Map<String, dynamic>)['entries']
              as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => e['slug'] as String)
          .toSet();

      final liftOnSlugs = ExerciseData.list
          .map((e) => MoveKitCatalogService.slugify(e['name'] as String))
          .toSet();

      for (final slug in moveKitSlugs.difference(liftOnSlugs)) {
        expect(liftOnSlugs.contains(slug), isFalse, reason: 'leaked: $slug');
      }
    });
  });

  // ── §6 Prohibited fields ──────────────────────────────────────────────────

  group('prohibited fields', () {
    test('no catalog entry carries planner fields', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      final entries = ((json.decode(raw) as Map<String, dynamic>)['entries']
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final entry in entries) {
        final offending = entry.keys.toSet().intersection(_prohibitedFields);
        expect(
          offending,
          isEmpty,
          reason: 'entry ${entry['id']} carries $offending — this removes the '
              'RFC-005 §13.1 layer 2 gate',
        );
      }
    });

    test('catalog entries expose only the five approved fields', () async {
      final raw =
          await rootBundle.loadString('assets/data/movekit_catalog.json');
      final entries = ((json.decode(raw) as Map<String, dynamic>)['entries']
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final entry in entries) {
        expect(
          entry.keys.toSet(),
          const {'id', 'name', 'muscle', 'equipment', 'slug'},
          reason: 'entry ${entry['id']} has an unexpected field set',
        );
      }
    });
  });
}
