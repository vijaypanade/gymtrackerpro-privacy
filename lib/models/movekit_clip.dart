import 'package:flutter/foundation.dart';

/// One MoveKit demonstration clip, as published in `assets/data/movekit_catalog.json`.
///
/// RFC-005 §6.1. This model is deliberately **minimal — five stored fields**. It
/// describes a licensed media asset and nothing else. It is *not* a planner
/// exercise, and it must never become one.
///
/// ## Why the missing fields are missing
///
/// A [MoveKitClip] carries no `type`, `movement`, `bodyweight`, `defaultWeight`,
/// `defaultReps` or `emoji`. That is not an oversight to be corrected later — it
/// is the enforcement mechanism of RFC-005 §13.1 layer 2:
///
/// `WorkoutProvider.addCustomExercise` requires nine fields before an exercise
/// can enter a plan or a workout log. A [MoveKitClip] can supply four. A
/// MoveKit-only exercise therefore **cannot** be turned into planner data by
/// accident — the impossibility is enforced by the compiler rather than by a
/// runtime check or by reviewer discipline.
///
/// Adding any of those fields silently removes that gate. Doing so requires its
/// own approved design change, not a refactor.
///
/// For the same reason there is **no `toPlannedExercise()`**, and none may be
/// added (RFC-005 §13.1 layer 1).
///
/// ## Identity
///
/// Exercise identity in LiftOn belongs to `ExerciseData` and to the persisted
/// exercise *names* that key every workout log (RFC-005 §4.9). A [MoveKitClip]
/// supplies media only: for any exercise that already exists in LiftOn, LiftOn's
/// name, id, muscle and equipment always win.
@immutable
class MoveKitClip {
  const MoveKitClip({
    required this.id,
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.slug,
  });

  /// Sequential id from the source listing, 1..412. Stable within a catalog
  /// version; the [slug] — not this — is the cross-system join key.
  final int id;

  /// Display name, verbatim from the MoveKit listing.
  final String name;

  /// Muscle grouping, **verbatim source terminology — not normalised**.
  ///
  /// May be multi-valued with a middle-dot separator, e.g.
  /// `'Glutes · Hamstrings'`. Facet normalisation belongs to the derivation
  /// layer (RFC-005 §5.3), never to this model, so that the dataset stays
  /// auditable against the vendor's own listing.
  final String muscle;

  /// Equipment, **verbatim source terminology — not normalised**.
  ///
  /// May be multi-valued, e.g. `'Cable Machine · Band'`. Note that MoveKit's
  /// `'Cable Machine'` and LiftOn's `'cable'` are different vocabularies; this
  /// field holds MoveKit's.
  final String equipment;

  /// Canonical hyphen-slug — the join key and the storage path key.
  ///
  /// Precomputed at generation time by `tool/movekit/generate_movekit_catalog.dart`
  /// as `slugify(name)`, e.g. `'barbell-bench-press'`.
  ///
  /// **This is not the same slug rule as `ExerciseVideoService`**, which
  /// produces underscores (`barbell_bench_press`) and is the persisted key for
  /// workout logs. Substituting one for the other would orphan user history —
  /// see RFC-005 §4.9.
  final String slug;

  /// **Firebase Storage path — NOT a Flutter asset path.**
  ///
  /// This clip is fetched from private, authenticated Firebase Storage and
  /// played from an app-private local file. It is *not* bundled with the app,
  /// and this string must never be passed to `rootBundle`,
  /// `VideoPlayerController.asset`, or any other asset API.
  ///
  /// The `movekit-loop-spike` prototype made exactly this mistake, which is why
  /// the warning is repeated here: the name reads like an asset, the value is a
  /// storage path (RFC-005 §8.1, §6.1).
  String get videoAsset => 'exercise_clips/v1/$slug.mp4';

  /// **Firebase Storage path — NOT a Flutter asset path.** See [videoAsset].
  ///
  /// Whether posters are ultimately bundled with the app instead of served from
  /// Storage is still an open decision (RFC-005 §8.1.1). Until it is resolved,
  /// treat this as a storage path.
  String get posterAsset => 'exercise_clips/v1/$slug.webp';

  /// Strictly parses one entry of `assets/data/movekit_catalog.json`.
  ///
  /// Throws [FormatException] on a missing, mistyped or blank field rather than
  /// substituting a default. The catalog is a generated artifact whose contract
  /// is already enforced at build time, so a malformed entry at runtime means
  /// the asset is corrupt or stale — a condition that must surface loudly, not
  /// be papered over with an empty string.
  factory MoveKitClip.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) {
      throw FormatException(
        'MoveKitClip: "id" must be an int, got ${id.runtimeType} ($id)',
      );
    }

    String requireText(String field) {
      final value = json[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
          'MoveKitClip(id: $id): "$field" must be a non-empty String, '
          'got ${value.runtimeType} ($value)',
        );
      }
      return value;
    }

    return MoveKitClip(
      id: id,
      name: requireText('name'),
      muscle: requireText('muscle'),
      equipment: requireText('equipment'),
      slug: requireText('slug'),
    );
  }

  @override
  String toString() => 'MoveKitClip($id, $slug)';
}
