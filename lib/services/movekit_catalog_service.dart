import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/movekit_clip.dart';

/// Read-only access to the generated MoveKit clip catalog.
///
/// RFC-005 §5.3 / §6.1. This is the **resolver** that sits between LiftOn's
/// planner catalog and the MoveKit media catalog. The two datasets are never
/// merged: `ExerciseData` keeps exercise identity, this service supplies media
/// for the subset of exercises MoveKit happens to cover.
///
/// ## Scope
///
/// Data layer only. No network, no Firebase Storage, no `video_player`, no file
/// cache. Those arrive in RFC-005 005-B; nothing here anticipates them.
///
/// ## Alias resolution is not implemented yet
///
/// RFC-005 §5.4 defines `assets/data/movekit_aliases.json` as the place where
/// the 133 reviewed likely-match pairs are reconciled. That file does not exist
/// yet and no alias has been approved, so [findFor] currently resolves by exact
/// slug only. Expected coverage is therefore **45 of LiftOn's 141 exercises**
/// (RFC-005 §4.10) — this is the accepted starting state, not a defect.
class MoveKitCatalogService {
  MoveKitCatalogService._();

  static const String _assetPath = 'assets/data/movekit_catalog.json';

  /// Slug → clip. Null until a successful [init]; never assigned a partial or
  /// empty map on failure.
  static Map<String, MoveKitClip>? _bySlug;

  /// In-flight load, so concurrent [init] calls share one asset read.
  static Future<void>? _loading;

  /// True once the catalog has been loaded successfully.
  static bool get isLoaded => _bySlug != null;

  /// Number of clips in the loaded catalog; `0` before [init] completes.
  static int get count => _bySlug?.length ?? 0;

  /// Loads and parses the catalog asset. Idempotent, and safe to call
  /// concurrently — overlapping calls await the same load.
  ///
  /// **Fails loudly.** Any missing asset, malformed JSON, unexpected structure
  /// or invalid entry throws. It never falls back to an empty catalog and never
  /// invents data: a silent empty catalog would look exactly like "MoveKit has
  /// no clip for this exercise" at every call site, which is precisely the
  /// failure mode that made the earlier prototype's bug so hard to find.
  ///
  /// On failure the service stays unloaded, so a later call may retry.
  static Future<void> init() {
    if (_bySlug != null) return Future<void>.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString(_assetPath);

    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'MoveKit catalog: root of $_assetPath must be a JSON object, '
        'got ${decoded.runtimeType}',
      );
    }

    final entries = decoded['entries'];
    if (entries is! List) {
      throw const FormatException(
        'MoveKit catalog: $_assetPath is missing its "entries" array',
      );
    }

    final bySlug = <String, MoveKitClip>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException(
          'MoveKit catalog: entry ${bySlug.length + 1} is '
          '${entry.runtimeType}, expected a JSON object',
        );
      }
      // Throws FormatException on any missing, mistyped or blank field.
      final clip = MoveKitClip.fromJson(entry);

      final existing = bySlug[clip.slug];
      if (existing != null) {
        throw FormatException(
          'MoveKit catalog: duplicate slug "${clip.slug}" '
          '(ids ${existing.id} and ${clip.id})',
        );
      }
      bySlug[clip.slug] = clip;
    }

    // Published only after every entry parsed, so a partial catalog is never
    // observable.
    _bySlug = bySlug;
  }

  /// The approved MoveKit hyphen-slug rule.
  ///
  /// `'Barbell Bench Press'` → `'barbell-bench-press'`. Mirrors
  /// `tool/movekit/generate_movekit_catalog.dart`, which precomputes the same
  /// value into the catalog at build time.
  ///
  /// **Deliberately independent of `ExerciseVideoService._slug`**, which
  /// produces underscores (`barbell_bench_press`) and is the persisted key for
  /// workout logs. The two rules coexist and must never be substituted for one
  /// another — doing so would orphan user history (RFC-005 §4.9).
  ///
  /// Only exercise *names* are slugified. `muscle` and `equipment` keep their
  /// verbatim source form and are never used as lookup keys.
  static String slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Looks up a clip by its exact catalog slug, or `null`.
  ///
  /// Returns `null` when the catalog has not been loaded yet.
  static MoveKitClip? bySlug(String slug) => _bySlug?[slug];

  /// Resolves a LiftOn exercise name to a MoveKit clip, or `null`.
  ///
  /// Safe before [init] completes — returns `null` rather than throwing, so a
  /// caller rendered during startup simply falls back to the existing YouTube
  /// path (RFC-005 §9.3) instead of failing.
  ///
  /// Resolution order per RFC-005 §5.3 is *slug → alias → null*. The alias step
  /// is not implemented yet; see the class doc.
  static MoveKitClip? findFor(String exerciseName) {
    final catalog = _bySlug;
    if (catalog == null) return null;
    return catalog[slugify(exerciseName)];
  }
}
