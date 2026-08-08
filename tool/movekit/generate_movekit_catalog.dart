// RFC-005-A Step 2 — MoveKit catalog generator.
//
// Reads the provisional 412-record source listing and emits the app-facing
// catalog asset with a precomputed slug on every entry.
//
//   input   tool/movekit/movekit_412_source.json   (top-level "records")
//   output  assets/data/movekit_catalog.json
//
// Run from the project root:
//
//   dart run tool/movekit/generate_movekit_catalog.dart
//
// DETERMINISTIC BY CONTRACT. Two consecutive runs must produce byte-identical
// output, so nothing time-, locale- or environment-dependent may enter the
// result. In particular there is deliberately NO `generatedAt` field: a
// timestamp would make every run differ and destroy the guarantee that a
// regenerated catalog can be diffed against the committed one.
//
// The generated file is NOT hand-edited. Corrections belong in this generator
// or in the source listing.
//
// This script is a build-time tool. It is not shipped in the app and imports
// nothing from Flutter.

import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'tool/movekit/movekit_412_source.json';
const String _outputPath = 'assets/data/movekit_catalog.json';

const int _expectedCount = 412;

/// Fields a MoveKit record may carry. Anything else is a bug in the source.
const Set<String> _allowedFields = {'id', 'name', 'muscle', 'equipment'};

/// Fields that must never reach a MoveKit record.
///
/// Their absence is the enforcement mechanism of RFC-005 §13.1 layer 2:
/// `workout_provider.addCustomExercise` requires nine fields, so a record
/// carrying only four cannot be turned into a planner exercise. Adding any of
/// these silently removes that gate.
const Set<String> _prohibitedFields = {
  'type',
  'movement',
  'bodyweight',
  'defaultWeight',
  'defaultReps',
  'emoji',
};

/// Human-readable statement of the slug rule, embedded in the output metadata.
const String _slugRule =
    "lowercase; every run of [^a-z0-9] becomes '-'; leading and trailing '-' trimmed";

/// The approved MoveKit hyphen-slug rule.
///
/// Produces `barbell-bench-press` from `Barbell Bench Press`. This is the join
/// key against LiftOn exercise names and the Firebase Storage path key.
///
/// NOTE: this is NOT the same rule as `ExerciseVideoService._slug`, which
/// produces underscores (`barbell_bench_press`) and is the persisted key for
/// workout logs. The two must never be substituted for one another — see
/// RFC-005 §4.9.
String slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Thrown when the source listing violates a contract. Nothing is written.
class GeneratorFailure implements Exception {
  GeneratorFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

void _require({required bool condition, required String message}) {
  if (!condition) throw GeneratorFailure(message);
}

void main(List<String> args) {
  try {
    _run();
  } on GeneratorFailure catch (failure) {
    stderr
      ..writeln('GENERATOR FAILED — no output written.')
      ..writeln('  $failure');
    exitCode = 1;
  }
}

void _run() {
  final sourceFile = File(_sourcePath);
  _require(
    condition: sourceFile.existsSync(),
    message: 'source not found at $_sourcePath (run from the project root)',
  );

  final decoded = json.decode(sourceFile.readAsStringSync());
  _require(
    condition: decoded is Map<String, dynamic>,
    message: 'source root must be a JSON object with "_meta" and "records"',
  );
  final source = decoded as Map<String, dynamic>;

  final meta = source['_meta'];
  _require(
    condition: meta is Map<String, dynamic>,
    message: 'source is missing its "_meta" object',
  );
  final sourceMeta = meta as Map<String, dynamic>;

  final rawRecords = source['records'];
  _require(
    condition: rawRecords is List,
    message: 'source is missing its top-level "records" array',
  );
  final records = (rawRecords as List).cast<Map<String, dynamic>>();

  _require(
    condition: records.length == _expectedCount,
    message: 'expected $_expectedCount records, found ${records.length}',
  );

  final seenIds = <int>{};
  final seenNames = <String>{};
  final seenSlugs = <String, String>{}; // slug -> first name that produced it
  final entries = <Map<String, dynamic>>[];

  for (final record in records) {
    final position = entries.length + 1;

    final unknown = record.keys.toSet().difference(_allowedFields);
    _require(
      condition: unknown.isEmpty,
      message: 'record $position carries unexpected field(s): '
          '${unknown.toList()..sort()}',
    );

    final prohibited = record.keys.toSet().intersection(_prohibitedFields);
    _require(
      condition: prohibited.isEmpty,
      message: 'record $position carries prohibited field(s) '
          '${prohibited.toList()..sort()} — see RFC-005 §6.1 and §13.1',
    );

    final id = record['id'];
    _require(
      condition: id is int,
      message: 'record $position has a non-integer id: $id',
    );
    final intId = id as int;
    _require(
      condition: intId == position,
      message: 'ids must be exactly 1..$_expectedCount in order — '
          'record at position $position has id $intId',
    );
    _require(
      condition: seenIds.add(intId),
      message: 'duplicate id $intId',
    );

    final name = (record['name'] as String? ?? '').trim();
    final muscle = (record['muscle'] as String? ?? '').trim();
    final equipment = (record['equipment'] as String? ?? '').trim();

    _require(condition: name.isNotEmpty, message: 'record $intId has a blank name');
    _require(
      condition: muscle.isNotEmpty,
      message: 'record $intId ($name) has a blank muscle',
    );
    _require(
      condition: equipment.isNotEmpty,
      message: 'record $intId ($name) has a blank equipment',
    );
    _require(
      condition: seenNames.add(name),
      message: 'duplicate name: $name',
    );

    final slug = slugify(name);
    _require(
      condition: slug.isNotEmpty,
      message: 'record $intId ($name) produced an empty slug',
    );
    // Defensive: guarantees the emitted slug is exactly what slugify(name)
    // yields, so a future refactor cannot introduce a hand-authored slug that
    // silently diverges from the join key.
    _require(
      condition: slug == slugify(name),
      message: 'record $intId ($name): slug "$slug" != slugify(name)',
    );
    final previous = seenSlugs[slug];
    _require(
      condition: previous == null,
      message: 'duplicate slug "$slug" from "$name" and "$previous"',
    );
    seenSlugs[slug] = name;

    // name, muscle and equipment are carried through verbatim. No
    // normalisation: multi-valued values keep their ' · ' separator so the
    // dataset stays auditable against the vendor's own listing.
    entries.add(<String, dynamic>{
      'id': intId,
      'name': name,
      'muscle': muscle,
      'equipment': equipment,
      'slug': slug,
    });
  }

  final output = <String, dynamic>{
    '_meta': <String, dynamic>{
      'schemaVersion': 1,
      'generator': _sourcePath,
      'source': sourceMeta['source'],
      'licenseId': sourceMeta['licenseId'],
      // Carried through unchanged. This dataset is NOT vendor-verified and
      // nothing here may imply otherwise.
      'provenance': sourceMeta['provenance'],
      'verifyAgainstVendorWhen': sourceMeta['verifyAgainstVendorWhen'],
      'normalisation': sourceMeta['normalisation'],
      'slugRule': _slugRule,
      'deterministic':
          'No timestamp is emitted; two runs produce byte-identical output.',
      'count': entries.length,
    },
    'entries': entries,
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(output);
  final outputFile = File(_outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync('$encoded\n');

  stdout
    ..writeln('OK  wrote $_outputPath')
    ..writeln('    entries      ${entries.length}')
    ..writeln('    unique slugs ${seenSlugs.length}')
    ..writeln('    provenance   PROVISIONAL (not vendor-verified)');
}
