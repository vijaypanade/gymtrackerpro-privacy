# RFC-005-A — Implementation Plan (Step 1: Catalog Foundation)

**Status:** Approved — NOT STARTED. No implementation file has been created or modified.
**Parent RFC:** [RFC-005 — Exercise Demo Catalog & Licensed Video Delivery](RFC-005-exercise-demo-catalog-and-video-delivery.md)
**Author:** Chief Software Architect
**Date:** 2026-08-08
**Phase:** 005-A, first and smallest slice — scoped deliberately below the whole of 005-A
**Governance:** RFC-first; ADR-006 Backward Compatibility First; Rule 9 size limits;
Production Safety Gate (§9 below).

---

## 0. A correction that determines whether this step is possible at all

RFC-005 §4.8 states that touching `pubspec.yaml`, `ios/Podfile`, `Podfile.lock` or
`project.pbxproj` while an App Store submission is in review "would require withdrawing and
resubmitting, restarting review."

**That was overstated, and the distinction matters here.**

- The binary already uploaded to App Store Connect is **independent of the repository**.
  Committing to a branch — or to `main` — does not alter, invalidate, or re-open that
  submission.
- **The real constraint is: do not ship a new binary while the review is in progress.**
  Repository changes are safe; *releases* are what the review gates.

This step requires two asset lines in `pubspec.yaml`. Under the corrected reading that is
safe, and Step 1 may proceed. Under the original wording Step 1 would have been blocked for
no reason.

**Action item:** RFC-005 §4.8 consequence 1 must be reworded to say "do not ship a new
build" rather than "do not touch `pubspec.yaml`". Recorded here; not yet applied.

Everything else in §4.8 stands unchanged — Android is live, iOS is in review, and
"revert the commit" stops being a rollback the moment something ships (§7 below explains why
it is still genuinely valid *for this step*).

---

## 1. Exact files to create — 7

```
tool/movekit/movekit_412_source.json         verified master dataset — generator input
tool/movekit/generate_movekit_catalog.dart   generator
assets/data/movekit_catalog.json             generated output (hand-editing prohibited)
assets/data/movekit_aliases.json             {} — ships empty
lib/models/movekit_clip.dart                 model — the seven fields of RFC-005 §6.1
lib/services/movekit_catalog_service.dart    load + findFor
test/movekit_catalog_consistency_test.dart   assertions (§6)
```

Estimated ~350 LOC across 8 files (7 created + 1 modified). Within Rule 9's soft limits
(15 files / 1,500 lines), so no split is required for this step.

### 1.1 `lib/main.dart` is deliberately NOT touched

Nothing reads the service in Step 1, so no startup initialisation is needed. The service
uses a **lazy, idempotent `init()`** invoked on first `findFor()`. This keeps the
existing-file footprint of Step 1 at exactly one file.

`MoveKitCatalogService.init()` may be added to `lib/main.dart:207` — beside the existing
`ExerciseVideoService.init().ignore()` — in a later step, if startup preloading is wanted.
It is not wanted yet.

---

## 2. `pubspec.yaml` — the only existing file eventually modified

Two entries in the existing `flutter: assets:` block:

```yaml
    - assets/data/movekit_catalog.json
    - assets/data/movekit_aliases.json
```

Individually listed, following the precedent already set by
`assets/data/exercise_videos.json`, rather than declaring the directory.

**No dependency is added.** `git diff pubspec.yaml` must show these two lines and nothing
else — no `video_player`, no `firebase_storage`. This is a verification gate (§8), not a
guideline.

### 2.1 Existing files to inspect before any edit

Terminal-first, read-only, one surgical change at a time:

| File | Why it must be read first |
|---|---|
| `pubspec.yaml` — `assets:` block | Exact indentation and insertion point; the only file to be modified |
| `lib/services/exercise_video_service.dart` | The pattern to mirror — `rootBundle`, `init()`, `_slug()` |
| `lib/data/exercise_data.dart` | **Read-only.** The test needs the 141 names |
| `analysis_options.yaml` | Lint rules the new files must satisfy |
| `test/` | Existing test conventions |
| All 7 target paths | Collision check — nothing may be overwritten (§12) |

---

## 3. Generator — input and output

**Input:** `tool/movekit/movekit_412_source.json` — 412 records, each carrying `id`, `name`,
`muscle`, `equipment`, verbatim as delivered and verified (412 records, ids 1–412, no
duplicate ids, no duplicate names, no blank fields, source terminology preserved).

**Output:** `assets/data/movekit_catalog.json`

```jsonc
{
  "_meta": {
    "version": 1,
    "source": "MoveKit Complete Pack",
    "licenseId": "MK-LIC-DCAYJ-AAHE2-VYM50",
    "generatedAt": "<ISO8601>",
    "count": 412
  },
  "entries": [
    {
      "id": 1,
      "name": "Abdominals Stretch Variation Four",
      "muscle": "Core",
      "equipment": "Stability Ball",
      "slug": "abdominals-stretch-variation-four"
    }
  ]
}
```

### 3.1 Generator requirements

- **Deterministic.** Two consecutive runs must produce byte-identical output. Verified in §8.
- **No normalisation** of `muscle` or `equipment`. Verbatim vendor values are retained so the
  dataset stays auditable against MoveKit's own catalogue (RFC-005 §6.1). Facet
  normalisation belongs to the deferred derivation layer (RFC-005 §5.3), never to this file.
- **Slug precomputed at generation time**, so the app never re-derives 412 slugs at runtime.
- **Fails loudly** — non-zero exit, no output written — on any of:
  - `count != 412`
  - duplicate `id`
  - duplicate `slug`
  - any blank `name` / `muscle` / `equipment` / `slug`
  - `slug != slugify(name)` for any entry
- **Never writes** `type`, `movement`, `bodyweight`, `defaultWeight`, `defaultReps` or
  `emoji`. Their absence is the enforcement mechanism of RFC-005 §13.1, not an oversight.
- The generated file is **not hand-edited**. Corrections go into the generator.

---

## 4. `MoveKitClip` — 7-field schema

```
class MoveKitClip
  final int    id           // 1..412
  final String name         // verbatim
  final String muscle       // verbatim — may contain '·', e.g. "Glutes · Quadriceps"
  final String equipment    // verbatim
  final String slug         // precomputed join key

  String get videoAsset  => 'exercise_clips/v1/$slug.mp4'
  String get posterAsset => 'exercise_clips/v1/$slug.webp'

  factory MoveKitClip.fromJson(Map<String, dynamic> json)
```

**Both getters require a doc comment reading: "Firebase Storage path — NOT a Flutter
asset."** The `movekit-loop-spike` prototype made precisely this mistake — it bundled the
clip as a Flutter asset — so the field names have already cost one round of confusion. The
approved names are kept as specified; implementers must not infer bundling from them.

`type`, `movement`, `bodyweight`, `defaultWeight`, `defaultReps` and `emoji` are **absent by
design**. Adding any of them removes the §9 data-integrity gate and requires its own
approval.

---

## 5. `MoveKitCatalogService` — API and constraints

```
class MoveKitCatalogService
  static Future<void>   init()                        // idempotent, lazy-safe
  static MoveKitClip?   findFor(String exerciseName)  // slug → alias → null
  static MoveKitClip?   bySlug(String slug)
  static int            get count
  static bool           get isLoaded
  static String         slugify(String s)             // carried over verbatim from the spike
```

### 5.1 Constraints

- **Data layer only.** No network, no Firebase Storage, no `video_player`, no file cache.
- **`catch (_) {}` is prohibited.** The spike swallowed a missing-asset failure silently,
  which is exactly why the reported bug took an investigation to find. On load failure:
  `debugPrint` **and** Crashlytics `recordError`. Never silent.
- **`findFor()` returns `null` for all but the 45 exact matches** while
  `movekit_aliases.json` is empty. This is the expected, accepted starting state — coverage
  is 45/141 (32%) until aliases are approved (RFC-005 §4.10, §22 item 8).
- **`toPlannedExercise()` must not be written.** Its non-existence is layer 1 of the
  data-integrity gate (RFC-005 §13.1).
- `slugify` is copied from the spike unchanged — it was verified correct on device
  (`"Barbell Bench Press"` → `barbell-bench-press`, resolved on first try).

---

## 6. Consistency-test assertions — all 11

`test/movekit_catalog_consistency_test.dart`

| # | Assertion |
|---|---|
| 1 | Catalog loads; `count == 412` |
| 2 | ids are exactly 1..412 — no gaps, no duplicates |
| 3 | 412 unique slugs |
| 4 | No blank `name` / `muscle` / `equipment` / `slug` |
| 5 | `slug == slugify(name)` for every entry |
| 6 | `movekit_aliases.json` parses **and is empty** — the Step 1 invariant |
| 7 | **`ExerciseData.list.length == 141`** — canary; fails loudly if anyone touches the planner catalog |
| 8 | No MoveKit-only slug appears in `ExerciseData` (RFC-005 §13.1 layer 4) |
| 9 | Exact-match count **== 45** — freezes the coverage figure; any change to either dataset breaks the test |
| 10 | LiftOn-only count **== 25** |
| 11 | No MoveKit entry carries a `type` / `movement` / `bodyweight` / `defaultWeight` / `defaultReps` / `emoji` key — RFC-005 §6.1, machine-enforced |

**Assertions 7, 8 and 11 are what make the gate real.** The others verify data quality.
Assertions 9 and 10 are intentionally brittle: they exist so that a silent change to either
dataset surfaces as a red test rather than as drifted coverage.

---

## 7. Rollback strategy

| Layer | Rollback |
|---|---|
| Code | `git revert <sha>` — **genuinely valid here**, because nothing has shipped |
| `pubspec.yaml` | Remove the two asset lines |
| User data | **Nothing.** No persisted model, no Hive box, no Firestore document, no favorites id is touched |
| Firebase | **Nothing.** No bucket, no rules, no dependency, no `firebase.json` change |
| Users | **Zero effect.** No screen, route or widget reads the new files |

Reverting returns the app to its exact pre-RFC state.

This is the **only phase in RFC-005 where a code revert is a complete rollback.** From the
moment a loop becomes visible to users, the Remote Config kill switch (RFC-005 §19.3, §20)
becomes the real rollback and a revert alone is insufficient.

---

## 8. Verification commands

After **every** file creation or edit, on the affected file:

```bash
flutter analyze lib/models/movekit_clip.dart
```

Generator determinism:

```bash
dart run tool/movekit/generate_movekit_catalog.dart && cp assets/data/movekit_catalog.json /tmp/a.json && dart run tool/movekit/generate_movekit_catalog.dart && diff /tmp/a.json assets/data/movekit_catalog.json && echo "DETERMINISTIC"
```

Consistency test:

```bash
flutter test test/movekit_catalog_consistency_test.dart
```

Final scope verification:

```bash
flutter analyze && git diff --stat && git diff pubspec.yaml
```

`git diff pubspec.yaml` must show **only the two asset lines** — zero dependency changes.

---

## 9. Production Safety Gate — Step 1

| # | Gate item | Status |
|---|---|---|
| 1 | Complete file impact list | ✅ §1 — 7 created, 1 modified, ~350 LOC |
| 2 | Backup strategy | ⬜ New branch + pre-work commit ref recorded before the first edit |
| 3 | Regression risk assessment | ✅ **Measurably zero** — no existing code path reads the new files |
| 4 | Rollback procedure | ✅ §7 — commit revert is sufficient and complete |
| 5 | Verification checklist | ⬜ §8 — analyze per file, determinism, test, final scope diff |
| 6 | Success criteria | ⬜ §10 |

### 9.1 Data-integrity gate carried into this phase

RFC-005 §13.1, restated because Step 1 is where it is first enforced in code:

| Layer | Mechanism |
|---|---|
| 1 | **Type separation** — `MoveKitClip` is neither a `Map<String,dynamic>` nor a `PlannedExercise`; no conversion exists |
| 2 | **Missing fields are the gate** — `workout_provider.addCustomExercise` (`:790`) requires nine fields; `MoveKitClip` supplies four. Compile-time impossibility, not a runtime check |
| 3 | **Call-site discipline** — nothing in this step calls `addExercise` / `addCustomExercise` |
| 4 | **Test** — assertion 8 |

---

## 10. Definition of Done

- 11/11 consistency assertions pass
- `flutter analyze` clean, whole project
- Generator provably deterministic (§8)
- `git diff --stat` shows only the expected 8 files
- `git diff pubspec.yaml` shows zero dependency changes
- Within Rule 9 limits (8 files, ~350 LOC)
- `ExerciseData.list` byte-identical to its pre-work state
- No YouTube mapping removed; no alias approved; no exercise renamed, merged or deleted

---

## 11. Gates explicitly NOT applicable to Step 1

Stated so that no reader mistakes their absence for an oversight:

| Gate | Why not applicable |
|---|---|
| RFC-005 §19.1 **Storage provisioning** | **Nothing at all.** No bucket, no rules, no region decision executed, no `firebase.json` edit, no `storage.rules` file |
| RFC-005 §19.3 item 1 **Remote Config kill switch** | Not required — nothing is user-visible. **It becomes mandatory at the first step that surfaces a loop to a user** |
| RFC-005 §19.3 item 3 **Staged Play Store rollout** | No release is produced by this step |
| Poster hosting decision (RFC-005 §8.1.1) | Still open; identical either way for this step. Must be resolved before 005-C renders a poster grid |
| Alias approval (RFC-005 §22 item 8) | Not a precondition; `movekit_aliases.json` ships empty |
| Live MAU input (RFC-005 §14.1) | Gates the delivery cost model, not the catalog |

---

## 12. First terminal inspection command

The constraint "do not rewrite existing files" is verified before anything else — confirming
all seven target paths are free:

```bash
cd /Users/vijaypanade/Desktop/Lifton/gym_ios && for f in tool/movekit/movekit_412_source.json tool/movekit/generate_movekit_catalog.dart assets/data/movekit_catalog.json assets/data/movekit_aliases.json lib/models/movekit_clip.dart lib/services/movekit_catalog_service.dart test/movekit_catalog_consistency_test.dart; do [ -e "$f" ] && echo "EXISTS  $f" || echo "free    $f"; done; echo "--- tool/ dir ---"; ls -d tool 2>&1
```

If any path reports `EXISTS`, work stops and the owner is asked. **No file is overwritten.**

---

## 13. Out of scope for Step 1

- The `movekit-loop-spike` worktree remains **NOT FOR MERGE** and untouched. Only its
  `slugify()` function is carried over.
- The 133 likely-match aliases are **not** approved or added.
- The 117 near-duplicate pairs within MoveKit are **not** resolved.
- No faceted browse catalog, no shelves, no UI, no detail screen.
- No `type` / `movement` / `defaultWeight` / `defaultReps` / `bodyweight` / `emoji` authored
  for the 412.

---

**No implementation has been performed. No Dart file, `pubspec.yaml`, asset, test, Firebase
configuration or dependency has been created or modified. No branch, commit, stash or reset
has been made. This document is the only artifact produced.**
