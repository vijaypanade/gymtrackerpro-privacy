# RFC-005 — Exercise Demo Catalog & Licensed Video Delivery

**Status:** Draft. The MoveKit 412 list has been supplied and the coverage report is
complete (§4.10); §22 items 1–4 and 6 are resolved. The **integration boundary is approved**
(§5.3–5.5, §6.1, §13.1). Remaining blockers are one missing input (live MAU) and two owner
reviews. **Implementation has not started.**
**Author:** Chief Software Architect
**Date:** 2026-08-08
**Depends on:** MoveKit License Agreement v1.0 (License ID `MK-LIC-DCAYJ-AAHE2-VYM50`,
Order `MK-20260807-06C2`)
**Governance:** RFC-first (never modify code without an approved design); ADR-006
Backward Compatibility First; Rule 9 size limits; Production Safety Gate.

---

## 1. Objective

Give LiftOn a first-class **Exercise Demo Library**: a browsable catalog of exercises,
each with a silent looping demonstration video, reachable independently of the workout
planner — without disturbing the planner, its persisted models, or any existing user data.

Two independent goals, deliberately separated:

1. **Catalog** — merge the existing LiftOn exercise set with the MoveKit set into one
   browsable, facet-filterable catalog that is *not* the planner's data source.
2. **Video** — deliver licensed MP4 loops to the device in a way that satisfies the
   MoveKit licence, works offline after first view, and adds nothing to app size.

---

## 2. Scope

- A new **Exercise Demo Catalog** as a generated data artifact (browsing/demo authority).
- Facet-based taxonomy: `environment[]`, `muscle`, `equipment`, `modality`, `tags[]`.
- Derived shelves/views: Gym, Home, Cardio, Mobility, Full Body, Popular, New — seven, not
  the eight originally proposed. "Strength" was dropped by owner decision (§18.3); the
  facet survives, the shelf does not.
- A dedicated **Exercise Demo Videos** browsing section.
- An exercise detail view with a looping, muted demo video and play/pause/replay.
- Firebase Storage private delivery + app-private cache + local-file playback.
- A mandatory consistency test binding the existing 141 slugs to the final catalog.
- Reuse of the existing derived slug strategy for video lookup.

## 3. Non-Scope

- **No change to `lib/data/exercise_data.dart`.** It is not rewritten, re-ordered, or
  extended with video or catalog fields.
- **No change to `PlannedExercise`, `ExSet`, `DayPlan`, `WorkoutLog`,** or any other
  persisted model. No Hive migration. No Firestore schema change.
- No change to the existing YouTube "Watch Form Demo" flow — it remains as-is and as
  fallback (see §9.3).
- No AI/coaching behaviour change. No change to premium gating or billing.
- No replacement of the planner's exercise picker data source.
- WebM, HEVC, adaptive streaming, and video pre-download-all are explicitly out.
- **Local environment issue, recorded but OUT OF SCOPE.** `/Users/vijaypanade/json.py`
  shadows Python's standard-library `json` module, breaking any Python process launched
  from the home directory (it broke one verification command during this RFC's
  inspection). It is unrelated to LiftOn, affects no shipped code, and **no fix is
  proposed, planned, or included by this RFC.** Recorded here only so a future reader does
  not mistake it for a project defect.

---

## 4. Current State (verified by inspection, 2026-08-08)

### 4.1 Exercise data

- `lib/data/exercise_data.dart` — `ExerciseData.list`, `List<Map<String, dynamic>>`,
  **141 entries**. Both `"id"` and `"name"` are unique across all 141; deriving
  `slug = name.toLowerCase().replaceAll(' ', '-')` yields **141 unique slugs, zero
  collisions**.
- Facet coverage in the existing data:

  | Axis | Values present |
  |---|---|
  | `muscle` | Legs 26 · Back 24 · Chest 20 · Shoulders 16 · Triceps 15 · Core 15 · Biceps 11 · Cardio 10 · Calves 4 |
  | `equipment` | machine 36 · barbell 31 · bodyweight 29 · dumbbell 27 · cable 18 |
  | `type` | push 46 · pull 41 · legs 29 · core 15 · cardio 10 |

- **There is no typed `Exercise` model.** Exercises circulate as untyped `Map`.
  `PlannedExercise` (`lib/models/models.dart:30`) is a *planner* model, not a catalog
  model; it is persisted via `toJson`/`fromJson` into Hive and carries a `baseId`
  derived from the name. Its own comments reference pre-existing persisted plans.

### 4.2 Facets the proposed taxonomy needs but the current data does not have

| Required by taxonomy | Present today | Consequence |
|---|---|---|
| `Glutes` muscle | ❌ (folded into `Legs`) | Empty shelf unless re-tagged or supplied by MoveKit |
| `environment` (gym/home) | ❌ no such field | Must be derived from equipment |
| `Resistance Band` | ❌ not in equipment set | Depends entirely on MoveKit |
| `Mobility / Stretching` | ❌ not in `type` | Depends entirely on MoveKit |
| `Full Body` | ❌ no tag | Must be authored |
| `Strength` | ⚠️ ~131/141 would qualify | Near-useless as a filter; see §7.2 |
| `Popular`, `New` | ⚠️ not intrinsic | Must be derived (§7.3) |

Derived-home ceiling from existing data: **56** exercises (bodyweight 29 + dumbbell 27).
`machine` (36) and `cable` (18) can never be home.

### 4.3 Existing video plumbing

- `assets/data/exercise_videos.json` — 138 curated YouTube entries.
- `lib/services/exercise_video_service.dart:48` — `_slug()` already normalises names
  (lowercase, strip punctuation, collapse whitespace) with alias fallbacks. The slug
  concept is therefore already established in production.
- `lib/widgets/planner/planner_video_widgets.dart:21` — `ExerciseDemoButton`; the file is
  2,077 lines. Used only from `lib/screens/planner_screen.dart` at lines 3547, 3765, 5750.
- Player embed at `planner_video_widgets.dart:536` has no `loop` parameter — nothing in
  the app loops today.
- **No `video_player` dependency.** Only `webview_flutter: ^4.9.0`.

### 4.4 Dead code discovered

- `lib/data/exercise_library.dart` — 8 lines, 5 hardcoded exercises, a vestigial second
  exercise list. Referenced once, at `lib/screens/tools_screen.dart:1230`.
- **`lib/screens/exercise_library_screen.dart` — 361 lines, reachable from nowhere.**
  `MainShell._screens` (`lib/screens/main_shell.dart:39`) contains Home, Planner, Stats,
  Tools, Profile. No route, no navigation, no reference anywhere in `lib/`. It already
  renders `ExerciseData.list` with filter chips and an `_ExerciseCard`.

  This is the single most useful finding for scoping: the demo library has an existing,
  **unreferenced** shell to grow into. Reusing it changes no live code path.

### 4.5 Platform & infrastructure

- Android `minSdk = 26`, `targetSdk = 36` (`android/app/build.gradle.kts:43`).
  iOS `IPHONEOS_DEPLOYMENT_TARGET = 15.0`. Both support H.264 natively.
- Firebase in use: core, auth, firestore, crashlytics, remote_config, analytics.
  **`firebase_storage` is absent** from `pubspec.yaml`, `firebase.json` has no `storage`
  block, and no `FirebaseStorage` reference exists in `lib/`.
- `path_provider: ^2.1.5` **is already present** (`pubspec.yaml:68`) — no new dependency
  needed for cache directories.
- **Hard auth gate:** `lib/screens/splash_screen.dart:146` routes
  `isLoggedIn ? MainShell() : LoginScreen()`. No guest mode, no `signInAnonymously`, no
  skip path. **Every user who reaches app content holds a Firebase Auth token.**

### 4.6 Reference asset (the one purchased clip)

`barbell-bench-press.mp4` — 1936×1072, H.264, **no audio track**, 6.667 s, 2.28 MB
(~2.7 Mbps). Poster `barbell-bench-press.webp`, 8.9 KB. Metadata includes muscles,
equipment, difficulty, 6-step instructions, 4 common mistakes, descriptions.

Its slug is `barbell-bench-press`, which is **exactly** the slug derived from LiftOn's
existing `"Barbell Bench Press"`. The join key requires no new identifier system.

### 4.7 Firebase Storage provisioning state (verified read-only via CLI, 2026-08-08)

Verified directly against project `gymtrackerpro-2cb3a`. No configuration, enablement or
deployment was performed — `describe`, `list` and `GET` only.

| Check | Result |
|---|---|
| Firebase Storage enabled | **No** |
| `gs://gymtrackerpro-2cb3a.firebasestorage.app` | **404 — does not exist** |
| `gs://gymtrackerpro-2cb3a.appspot.com` (legacy name) | **404 — does not exist** |
| Buckets that do exist | `gcf-sources-…`, `gcf-v2-sources-…`, `gcf-v2-uploads-…` — Cloud Functions internal, unrelated to this RFC |
| Rules releases (Firebase Rules API) | **1 total: `cloud.firestore`.** No `firebase.storage` release exists |
| Firestore ruleset last updated | `2026-07-14T17:53:36Z` |
| Firestore database location | `asia-south1` |

`storage_bucket: "gymtrackerpro-2cb3a.firebasestorage.app"` does appear in both
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`. **This is a
predicted default name emitted by Firebase config generation — it is not evidence of a
provisioned bucket.** An earlier reading inferred from its presence that the bucket
probably already existed; that inference was wrong and is corrected here.

Consequences that change decisions elsewhere in this RFC:

- **There are no existing Storage rules to preserve, capture or overwrite.** The earlier
  §19 requirement to capture live console rules before deploying is void and has been
  replaced (§19.1).
- Storage is a genuine **new-product provisioning step**, not adoption of existing infra.
  Bucket region therefore becomes a decision this RFC must fix in advance (§8.1).
- **iOS Firebase config is present** (`ios/Runner/GoogleService-Info.plist`, 14 Jul 2026),
  so this work carries **no dependency on RFC-004 (iOS Enablement)**.
- `.firebaserc` declares a single `default` project. **There is no staging project** —
  every rules deploy lands directly on production.

### 4.8 Distribution status (stated by the owner, 2026-08-08)

**This RFC is not a pre-launch document.**

- **Android: live on the Play Store.** There is a real install base running the current
  build. Every decision here lands on existing users.
- **iOS: submitted and in App Store review.** No iOS users yet, but the binary is frozen
  in a review queue.

Three consequences run through the rest of this document:

1. **iOS is in a change-freeze until review concludes.** Touching `pubspec.yaml`,
   `ios/Podfile`, `Podfile.lock` or `project.pbxproj` now would require withdrawing and
   resubmitting, restarting review. Adding `video_player` does exactly that. **005-B and
   005-C cannot start while the review is open** (§18.2).
2. **"Revert the commit" is no longer a rollback.** Once an update ships, reverting source
   does not reach an installed app. A server-side kill switch is mandatory (§19.3, §20).
3. **Egress starts on day one of 005-B**, against the live Android base — not at some
   future launch (§14.1).

---

### 4.9 Identity audit — exercise names ARE the persisted keys (verified 2026-08-08)

A full read-only audit was run before considering any catalog change. It produced the single
most important constraint in this RFC.

```dart
// lib/models/workout_log.dart:76
String get normalizedExercise => exercise.trim().toLowerCase().replaceAll(' ', '_');

// lib/providers/workout_provider.dart:700, 714, 1517 … (12+ sites)
final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
_logs.where((l) => l.exercise == key)
```

- `WorkoutLog.exercise` is a **String holding the exercise name**, persisted to Hive and
  Firestore (`workout_log.dart:130` writes, `:266` reads).
- The **cloud/local sync dedup key includes it** (`workout_provider.dart:2893`). Changing a
  name would break dedup and produce duplicate logs.
- PR detection, progression, volume and history all match on `l.exercise == key`.
- Favorites persist **old catalog ids** (`exercise_library_screen.dart:181` →
  `ExerciseData['id']`, e.g. `push_chest_barbell_bench_press`) in Firestore.
- The AI contract requires ids from the 141: `ai_provider.dart:1045` sends
  `exercise_id|name|muscle|equipment|type`, `:1049` mandates "ONLY exercise_id values from
  candidates".
- `ai_engine.dart` builds its workout pools by filtering on `type` (`:422 _pushPool`,
  `:428 _pullPool`, `:433 _legsPool`, `:440 _corePool`). MoveKit records have no `type`.
- `workout_provider.addCustomExercise` (`:790`) requires nine fields — `id, name, type,
  muscle, equipment, movement, bodyweight, emoji, unit`.

**There is no stable canonical exercise ID.** Three competing keys exist: `ExerciseData['id']`,
the name-derived underscore slug (used by every log), and `PlannedExercise.baseId`. The
real key is derived from the name, so **renaming an exercise orphans its history.**

**Conclusion, and the reason full replacement was rejected on 2026-08-08:** replacing the
141 catalog with the 412 dataset would orphan history for the 25 LiftOn-only exercises and
for every renamed exercise, break favorites, break the AI id contract, and empty every
workout-generation pool. Nothing in the catalog was found safe to replace wholesale.

### 4.10 Coverage report — 141 vs 412 (completed 2026-08-08)

Run against `ExerciseData.list` and the verified 412 master dataset, using the canonical
slug rule. Neither dataset was modified.

| Result | Count |
|---|---|
| Exact matches (slug-identical) | **45** |
| Likely-match pairs — review required, **not merged** | **133** covering 71 LiftOn / 112 MoveKit |
| MoveKit-only | **255** |
| LiftOn-only — will never have a MoveKit clip | **25** |
| Near-duplicate pairs *within* MoveKit | **117** |

Reconciliation is exact: `45 + 112 + 255 = 412` and `45 + 71 + 25 = 141`.

Consequences:

- **Coverage starts at 45/141 (32%)**, rising to ~116/141 (82%) only if the 133 aliases are
  approved. Alias review is human work and is not a precondition for 005-A.
- **"A loop everywhere" is unreachable.** At least 25 exercises keep the YouTube path
  permanently. §9.3's fallback is therefore structural, not a courtesy.
- Final catalog size is **~396** (141 + 255), not 553.
- Of the 133 pairs, tiering gives **HIGH 28 · MEDIUM 68 · LOW 37**. Two HIGH pairs are
  one-to-many (`Dumbbell Shrugs`, `Rear Delt Fly`) and need a single pick. One HIGH pair
  (`Smith Machine Hip Thrust` ↔ `Machine Hip Thrust`) is flagged as the weakest and may
  belong in MEDIUM.
- MoveKit adds equipment LiftOn has never had: **Kettlebell 25, Band 19**, plus Bicycle,
  Weight Plate, Sled, Stability Ball, Battle Ropes, Bench, Wrist Roller. This **confirms the
  "Resistance Band" home filter of §4.2 is now achievable** — it was previously unknown.
- `normalizeMuscle` (`workout_provider.dart:2955`) already folds Glutes/Quadriceps/Hamstrings
  → `legs`, Trapezius → `back`, Forearms → `arms`. **Adductors, Neck and Tibialis fall to
  `'other'`** and have no icon.

## 5. Proposed Architecture

### 5.1 The data boundary (the central decision)

Two authorities, one join key, one enforced invariant:

```
lib/data/exercise_data.dart          assets/data/exercise_catalog.json
   PLANNER AUTHORITY                    BROWSING / DEMO AUTHORITY
   141 entries, untouched               141 existing + MoveKit-only entries
   defaults, weights, reps, unit        facets, video slug, source marker
   drives workout creation              drives browsing, filtering, demos
             \                                    /
              \______  join key: slug  __________/
                    name.toLowerCase()
                        .replaceAll(' ', '-')

   INVARIANT (enforced by test): every slug derived from ExerciseData.list
   MUST exist in exercise_catalog.json. Build fails otherwise.
```

The planner keeps working exactly as today; it never reads the catalog. The catalog never
feeds workout creation in this RFC. The consistency test in §16.2 is what prevents the
two from silently diverging — without it, this design degrades into the "second
conflicting exercise database" that must be avoided.

### 5.2 Read-time video resolution — no model change

Video paths are **derived, not stored**. `PlannedExercise` gains no field; nothing is
persisted; there is no migration.

```
PlannedExercise.name  ──►  slug  ──►  catalog lookup  ──►  clip availability
      (or catalog entry)                                          │
                                                                  ▼
                                              ClipCacheService.localFileFor(slug)
                                                                  │
                                        cache hit ──► local File ─┤
                                        cache miss ──► Storage SDK download ──┘
```

This mirrors the pattern `ExerciseVideoService` already uses for YouTube IDs, so it
introduces no new architectural concept.

### 5.3 Integration boundary — APPROVED 2026-08-08

**This subsection supersedes the single merged artifact implied by §5.1 and §6 as the
*starting* structure.** §5.1's two-authorities principle and its slug join key are
unchanged and remain the foundation. What changes is that the MoveKit dataset is **not
merged into a combined catalog as the first step**. It stays verbatim, and a resolver sits
between the two.

The reason is the codebase audit of 2026-08-08 (§4.9): exercise identity in LiftOn is
carried by the exercise *name*, and a merged catalog is the artifact most likely to make a
rename look harmless. Keeping the datasets physically separate removes that possibility.

```
  ExerciseData.list (141)          movekit_catalog.json (412)
    PLANNER AUTHORITY                MEDIA AUTHORITY
    id · name · type · defaults      name · muscle · equipment (verbatim)
    UNTOUCHED                        no app fields, by design
            │                                  ▲
            │ name                             │
            ▼                                  │
     ┌──────────────────────────────────────────┴──┐
     │            MoveKitResolver                   │  new, read-only
     │  1. slug exact match                         │
     │  2. movekit_aliases.json lookup              │
     │  3. null                                     │
     └───────────────┬──────────────────────────────┘
              ┌──────┴───────┐
              ▼              ▼
        MoveKitClip?       null
              │              │
        loop player    existing YouTube path — UNTOUCHED
```

**Rule: for anything already in `ExerciseData`, LiftOn's identity always wins.** MoveKit
supplies media only — never name, id, muscle or equipment. This is why the 45 exact matches
existing in both datasets is not duplication: one dataset supplies identity, the other
supplies a clip.

**Deferred, not cancelled:** the faceted browse catalog of §6/§7 (normalised `muscle`,
`environment`, `modality`, shelves) is still the eventual browse layer. It becomes a
*derivation* over these two datasets rather than the first artifact written. §7's shelves
cannot be built from verbatim MoveKit values — `"Glutes · Quadriceps"` is not a facet — so
that normalisation step remains required, just later.

### 5.4 The alias table is the merge artifact — not a rename

```
assets/data/movekit_aliases.json     { "<liftOnSlug>": "<moveKitSlug>", … }
```

The 133 likely-match pairs (§4.10) are reconciled **here and nowhere else**. Approving an
alias adds one line to this file. It does not touch `ExerciseData`, `PlannedExercise`, any
Hive box, any Firestore document, or any log key. Withdrawing an approval deletes the line.

This is the property that makes alias review safe to do incrementally against a live app:
**no alias decision is ever persisted into user data.** The file ships empty; coverage is
45/141 until entries are added, and that is an accepted starting state.

### 5.5 Catalog generation

The catalog is a **generated artifact**, not a hand-maintained file. A `tool/` script reads
`ExerciseData.list` plus the MoveKit metadata export, merges by slug, and emits
`assets/data/exercise_catalog.json`. Regenerating is deterministic and reviewable as a diff.
Hand-editing the generated file is prohibited; corrections go into the generator's
override table.

---

## 6. Catalog Schema

```jsonc
{
  "_meta": {
    "version": 1,
    "generatedAt": "2026-08-08T00:00:00Z",
    "existingCount": 141,
    "movekitOnlyCount": 0,        // BLOCKED — see §19
    "totalCount": 141             // BLOCKED — see §19
  },
  "entries": [
    {
      "slug": "barbell-bench-press",     // stable id + join key + storage path key
      "name": "Barbell Bench Press",     // display name
      "source": "existing",              // "existing" | "movekit" | "both"
      "addedAt": "2026-08-08",           // drives the "New" shelf (§7.3)

      "muscle": "Chest",                 // primary, single-valued
      "secondaryMuscles": ["Triceps"],
      "equipment": "barbell",            // single-valued, normalised vocabulary
      "environment": ["gym"],            // multi-valued: "gym" | "home"
      "modality": "strength",            // "strength" | "cardio" | "mobility"
      "tags": ["compound", "push", "upper-body"],

      "clip": {                          // null when no licensed clip exists
        "slug": "barbell-bench-press",   // → exercise_clips/v1/<slug>.mp4
        "durationSeconds": 6.67,
        "hasPoster": true
      }
    }
  ]
}
```

### 6.1 MoveKit record — the minimal model, APPROVED 2026-08-08

The schema above describes the eventual faceted browse catalog (§5.3: deferred). What ships
first is deliberately smaller. `assets/data/movekit_catalog.json` holds the 412 records
**verbatim as delivered**, and the Dart model carries exactly seven fields:

```
MoveKitClip
  int    id            1..412, from the verified master dataset
  String name          MoveKit's name, unmodified
  String muscle        MoveKit's string, unmodified — may contain "·" (e.g. "Glutes · Quadriceps")
  String equipment     MoveKit's string, unmodified
  String slug          canonical join key, precomputed at generation time
  String videoAsset    derived → exercise_clips/v1/<slug>.mp4
  String posterAsset   derived → <slug>.webp
```

**`type`, `movement`, `bodyweight`, `defaultWeight`, `defaultReps` and `emoji` are absent by
design.** Their absence is not an omission to be fixed later — it is the enforcement
mechanism of §13.1. Adding any of them weakens that gate and requires its own approval.

**Naming caveat, recorded deliberately:** `videoAsset` / `posterAsset` read as Flutter asset
paths. They are **Firebase Storage paths** (§8.1). The `movekit-loop-spike` prototype made
exactly this mistake — it bundled the clip as a Flutter asset — so the ambiguity has already
cost one round of confusion. `videoPath` / `posterPath` would be more accurate. The approved
field names are kept as specified; implementers must not infer bundling from them.

- `muscle` and `equipment` are **not normalised** in this artifact. Verbatim source values
  are retained so that the dataset stays auditable against the vendor's own catalogue. Facet
  normalisation happens in the deferred derivation layer (§5.3), never by editing this file.

Notes on the deferred faceted schema above:

- `slug` is the only identifier that crosses system boundaries. It is derived once, at
  generation time, and then frozen in the artifact — runtime never re-derives it for
  catalog lookups (only for the planner→catalog bridge).
- `clip: null` is a first-class state. Entries without a licensed clip still appear in the
  catalog and fall back per §9.3.
- No `category` field exists, by design. See §7.
- `source` is what makes a coverage report reproducible after merge.

---

## 7. Taxonomy & Facets

### 7.1 Why there is no `category` field

The eight proposed top-level categories are not one axis — they are four:

| Axis | Members |
|---|---|
| Environment | Gym, Home |
| Modality | Strength, Cardio, Mobility/Stretching |
| Scope | Full Body |
| Curation | Popular, New |

"Barbell Squat" is simultaneously Gym, Strength, Full Body and possibly Popular. Forcing
that into a single `category` string either loses information or pushes special-case
branching into every screen — precisely the per-screen hardcoding this RFC must prevent.

**Decision:** the catalog stores **facets**; the eight categories are **derived
shelves/views** computed from those facets by a single query layer. Adding a ninth shelf
later requires no catalog change and no schema migration.

### 7.2 Shelf definitions

**Seven shelves, not eight** — "Strength" was removed by owner decision on 2026-08-08
(§18.3). It would have matched ~131 of the existing 141 exercises, so it filtered almost
nothing while occupying prime navigation space. The `modality == "strength"` **facet is
retained** on every entry; only the shelf is gone, and it can be reinstated later with no
catalog change — which is the whole point of §7.1.

| Shelf | Derivation |
|---|---|
| Gym | `environment contains "gym"` |
| Home | `environment contains "home"` |
| Cardio | `modality == "cardio"` |
| Mobility / Stretching | `modality == "mobility"` |
| Full Body | `tags contains "full-body"` |
| Popular | §7.3 |
| New | §7.3 |

`environment` derivation from equipment (deterministic, applied at generation time):

| equipment | environment |
|---|---|
| bodyweight | `["gym", "home"]` |
| dumbbell | `["gym", "home"]` |
| resistance-band | `["home"]` |
| barbell | `["gym"]` |
| machine | `["gym"]` |
| cable | `["gym"]` |

**Resolved 2026-08-08 (§18.3):** "Strength" matched ~131 of the existing 141 — a shelf that
shows almost everything is not a filter. The owner chose to **drop it as a top-level
shelf**. The facet remains; a curated "core lifts" tag stays available as a future option
and would need no schema change.

### 7.3 Popular and New

- **New** — derived from `source == "movekit"` combined with `addedAt` within a rolling
  window (proposed 60 days from catalog version release). Pure catalog data, no runtime
  dependency.
- **Popular** — derived from the user's own workout usage data already present locally
  (log frequency per exercise). Two-tier: personal frequency first, falling back to a
  static curated list for users with insufficient history. **Kept as an option, not a
  commitment** — if the fallback list is acceptable on its own, the usage-derived tier can
  be deferred to a later RFC without changing the schema.

---

## 8. Video Storage & Delivery

### 8.1 Storage layout & pre-provisioning decisions

```
exercise_clips/v1/<slug>.mp4        e.g. exercise_clips/v1/barbell-bench-press.mp4
exercise_clips/v1/<slug>.webp       poster — hosting OPEN, see §8.1.1
```

The `v1/` segment allows a future re-encode generation to ship without invalidating or
mutating existing objects.

#### 8.1.1 OPEN DECISION — poster hosting: bundled vs Storage

**Not resolved. Both options remain on the table; this RFC does not choose.**

| | Bundled in app (`assets/movekit/posters/`) | Firebase Storage |
|---|---|---|
| App size | **+≈3.6 MB** (412 × 8.9 KB) | unchanged |
| Egress | none | one small fetch per poster |
| Grid/list render | instant, offline from first launch | needs network or cache |
| Catalog growth | new posters need an app release | no release needed |

The video cannot be bundled (940 MB, §8.5). A poster can. Because LiftOn is already live
(§4.8), a +3.6 MB update is a visible cost to existing users, which is what keeps this open
rather than obvious.

This decision does **not** block 005-A: the catalog artifact and resolver are identical
either way. It must be resolved before 005-C renders a poster grid.

Because Storage is unprovisioned (§4.7), the following are **decisions to be fixed before
the bucket is created**, not constraints inherited from existing infrastructure:

| Decision | Value | Reversible after creation? |
|---|---|---|
| Bucket name | `gymtrackerpro-2cb3a.firebasestorage.app` (Firebase default) | — |
| **Region** | **`asia-south1` (Mumbai)** | **No. Bucket location is permanent.** |
| Path prefix | `exercise_clips/v1/` | Yes |

`asia-south1` is chosen to match the Firestore database location (§4.7), keeping clip reads
in the same region as the rest of the user data path and avoiding cross-region egress.
Cloud Functions currently run in `us-central1`; that pre-existing mismatch is recorded here
as an observation and is **not** addressed by this RFC.

Since bucket location cannot be changed after creation, this value must be explicitly
confirmed at the gate before anything is provisioned (§19.1, item 1).

### 8.2 Storage rules

```
match /exercise_clips/{version}/{file} {
  allow read: if request.auth != null;
  allow write: if false;               // uploads are operator-side only
}
```

Public read is never granted. This is safe for 100 % of users because of the hard auth
gate at `splash_screen.dart:146` (§4.5) — there is no guest path that would be locked out.

### 8.3 Delivery chain

```
Firebase Storage SDK  ──►  app-private cache dir  ──►  local MP4  ──►  video_player
     (authenticated)          (path_provider)          (File URI)
```

**`getDownloadURL()` is prohibited.** It mints a long-lived, shareable, tokenised URL —
unnecessary friction with licence §3. Bytes are fetched with the authenticated SDK
directly into the app-private cache directory and played from a local file, so no clip URL
is ever constructed, transmitted to the player layer, or written to logs.

### 8.4 Format

**MP4 / H.264 only.** iOS `AVPlayer` has no native VP9/WebM support; shipping WebM would
require a second Android-only pipeline and double the asset count (412 × 2 = 824). H.264
is natively supported on `minSdk 26` and iOS 15. HEVC is rejected for Android
fragmentation. Source clips are silent, which removes the audio-session question entirely.

**Re-encode requirement:** the reference clip is 1936×1072 at ~2.7 Mbps — far beyond what
a phone card needs. A generation-time encode pass (target ≈720 px wide, no audio, CRF-based)
is required before upload; it reduces egress cost and decode load. The exact ladder is an
implementation-plan detail, not an RFC decision.

### 8.5 Rejected alternatives

| Option | Why rejected |
|---|---|
| Bundle all clips in the app | 412 × 2.28 MB ≈ 940 MB; even re-encoded and limited to 141 it adds tens of MB, and every catalog change requires an app release. |
| Public CDN | `cdn.example.com/clips/<slug>.mp4` is literally a publicly exposed raw file URL — direct conflict with licence §3. Predictable slugs make the whole library scrapeable. **Rejected on licence grounds, not cost.** |
| GCS + Cloud Functions signed URLs | Adds a signing endpoint, token lifetime, clock-skew and offline-renewal handling, for the same licence outcome as §8.3. Unnecessary complexity. |
| Firebase Storage + `getDownloadURL()` | Produces a shareable tokenised URL; see §8.3. |

---

## 9. Licence Compliance (MoveKit License Agreement v1.0)

> This is an engineering reading of the licence, not legal advice. A one-line written
> confirmation from `hello@movekit.com` on §3 is cheap and is recommended before upload.

### 9.1 §3 — Delivery to End Users

> *"may not provide end users with the ability to download, extract, or otherwise obtain
> the raw Content files, and may not expose raw file URLs or download links publicly or to
> unauthorized parties."*

| Obligation | How this design satisfies it |
|---|---|
| No public raw file URLs | Storage rules deny unauthenticated read; `getDownloadURL()` prohibited; no URL is ever generated or logged. |
| No download/extract ability for end users | No share, export, "save video", or file-picker affordance is built. Cache lives in the app-private directory. |
| No exposure to unauthorized parties | Read requires a valid Firebase Auth token issued by LiftOn. |

Note on the limits of any such design: playback requires bytes on the device, so a
determined user with a rooted/jailbroken device can reach the cache. The licence prohibits
*providing the ability*, not achieving mathematical impossibility. This design provides no
such ability.

### 9.2 §5 — Restrictions

**Binding engineering constraints:**

- Clip bytes, frames, thumbnails, or derived stills **must never be sent to Gemini or any
  other model, endpoint, or generative pipeline.** LiftOn's AI features may continue to
  operate normally alongside the clips — §5 explicitly permits AI features in the same app
  — but the Content must not enter a model. Any future feature proposing to analyse clip
  imagery requires its own RFC and a licence re-read.
- No resale, redistribution, or exposure of the clip set as a library, dataset, or asset
  pack.
- Licence identifiers and provenance metadata must not be removed or altered. The
  conventional re-encode in §8.4 is permitted under §2 ("modifying and editing clips for
  the Licensee's own use cases"); stripping provenance is not.

### 9.3 Fallback behaviour (also a licence-safety property)

When `clip == null`, or the download fails, or the device is offline on first view, the UI
falls back to poster + the existing YouTube "Watch Form Demo" flow, which is untouched by
this RFC. No placeholder is fabricated and no clip is ever requested from a non-Storage
origin.

### 9.4 §7 — Records

The License ID (`MK-LIC-DCAYJ-AAHE2-VYM50`) and order reference are recorded in this RFC
and must be retained in `docs/`. They are the evidence of licensing.

---

## 10. Existing-vs-New Data Boundary

| Concern | Rule |
|---|---|
| Planner exercise source | `exercise_data.dart` only. Unchanged. |
| Browsing/demo source | `exercise_catalog.json` only. |
| Video path | Derived at read time from slug. Never persisted. |
| Model changes | None. `PlannedExercise` and all persisted models untouched. |
| Conflict prevention | Consistency test (§16.2) — every existing slug must be present in the catalog. |
| Ownership of a name change | If an exercise is renamed in `exercise_data.dart`, its slug changes and the test fails loudly at CI, forcing a catalog regeneration. This is the intended behaviour. |

---

## 11. UI Information Architecture

### 11.1 Entry point

`MainShell` already carries five tabs (`main_shell.dart:39`); a sixth is not proposed.
The Exercise Demo Videos section is reached from the **Tools/Explore** tab, which is where
`ExerciseLibrary` is already consumed (`tools_screen.dart:1230`).

### 11.2 Screens

| Screen | Basis | Note |
|---|---|---|
| Demo library (shelves + filters) | **Reuse `exercise_library_screen.dart`** | 361 lines, currently unreachable (§4.4). Repointing it at the catalog changes no live code path — its blast radius is zero. |
| Exercise detail + looping demo | **New** | No detail screen exists today; the library screen has no tap-through. |
| **Planner long-press preview** | **`ExercisePreviewSheet`** | See §11.2.1. Highest-traffic surface; smallest change. |
| Planner demo button | `ExerciseDemoButton` | Loop surfaced alongside the existing YouTube button, not replacing it. |

#### 11.2.1 The long-press preview — primary surface

Verified 2026-08-08. Long-pressing an exercise tile in the planner's picker already opens a
preview sheet:

```
onLongPress            planner_screen.dart:5536
  → _showPreview()     planner_screen.dart:6115
    → ExercisePreviewSheet          planner_video_widgets.dart:894
      → _videoId → ExerciseVideos.getVideoId(name)   ← the YouTube thumbnail slot
      → _openVideo()
```

This is the **best surface in the app for the loop**, for three reasons:

1. **One resolution point.** `_videoId` is the single place a video is chosen for this
   sheet. A MoveKit check there makes every long-press in the planner resolve to a loop,
   with no per-call-site changes.
2. **The slot already exists.** The sheet renders a static YouTube thumbnail at a fixed
   size today. An autoplaying, muted, looping clip occupies exactly that space — same
   layout, no new gesture for the user to learn, and it upgrades a still image into motion
   at the moment the user is deciding whether to add the exercise.
3. **Additive.** With no MoveKit clip the existing thumbnail path is untouched, so the
   change cannot regress the shipped behaviour (§4.8 makes that mandatory, not merely
   desirable).

**Inline, not a pushed route.** The `movekit-loop-spike` prototype navigated to a full
screen. That is worse here: the user is mid-decision inside a sheet, and a push costs a tap
and breaks that flow. The loop plays in place.

**Binding constraint:** the controller must be disposed when the sheet closes — including
on drag-dismiss and on back-gesture, not only on an explicit close. A bottom sheet is
easier to leak than a route, and a leaked `VideoPlayerController` holds a hardware decoder.
§12's "one active controller" rule is enforced here or nowhere.

### 11.3 Player behaviour

Autoplay on open, looping, **muted** (source clips are silent), poster shown until first
frame, play/pause/replay controls, loading indicator during first fetch, and the §9.3
fallback on error. Only one clip decodes at a time; list rows show posters, not video.

---

## 12. Performance & Cache Strategy

- **Cache location:** the app-private **application-support** directory via the existing
  `path_provider` — `getApplicationSupportDirectory()`, **not** `getTemporaryDirectory()`.

  This is a correctness requirement, not a preference. Both iOS and Android may purge the
  temporary/caches directory at any time under storage pressure, without warning and
  without the user acting. A clip stored there can disappear between sessions, and a user
  who is offline — in a gym basement, which is the normal case — will not get it back.
  Eviction must be **ours** (LRU, below), never the OS's. The directory must also be
  excluded from device/cloud backup, since re-fetchable licensed content should not inflate
  a user's backup.
- **Population:** lazy, on first view of an exercise. No bulk pre-download, which would
  turn a 412-clip library into a multi-hundred-megabyte background transfer.
- **Eviction:** LRU with a size ceiling (proposed 150 MB) so long-term usage cannot grow
  without bound. Eviction is safe — any evicted clip is re-fetchable.
- **Concurrency:** at most one in-flight download; requests for the same slug coalesce.
- **Decode:** one active `VideoPlayerController`; disposed on navigation away. Grid and
  list surfaces render the WebP poster only.
- **Offline:** cached clips play with no network. Uncached clips fall back per §9.3.
- **Reinstall note:** iOS keeps the Firebase session in the Keychain across uninstall, but
  the cache directory is wiped, so clips re-download after reinstall. This is expected and
  must be included in the egress estimate.

---

## 13. Security

### 13.1 Storage rule architecture (binding)

When Firebase Storage is enabled, the console offers this default template for an
authenticated bucket:

```
// FIREBASE DEFAULT TEMPLATE — MUST NOT BE USED IN LIFTON
allow read, write: if request.auth != null;
```

**This template is prohibited.** Because LiftOn has a hard auth gate (§4.5), *every* app
user is authenticated — so this rule would grant *every user* write and delete over the
entire bucket. Any user could overwrite or destroy licensed MoveKit clips. That is
simultaneously an availability failure and a licence exposure (§9). It must not be active
at any point, including transiently during provisioning (§19.1).

Intended rule architecture:

| Path | read | write | delete |
|---|---|---|---|
| `exercise_clips/v1/**` | authenticated only | **denied** | **denied** |
| everything else | denied | denied | denied |

- **Clients need read access only.** Every upload is operator-side, performed with admin
  credentials via console/CLI/CI, which bypass Storage rules entirely. No client write path
  is ever required, so none is ever granted.
- Default-deny catch-all for all other paths.
- Exercise clips are **licensed content, not user content** — they must never be
  overwriteable or deletable by app users.
- No public read. No `getDownloadURL()`. No raw or public download URL is ever constructed
  or exposed (§8.3, licence §3).
- **Storage rules are not evaluated top-down like a firewall.** Among all matching rules,
  any `allow` grants access; a catch-all deny does *not* override a more specific allow.
  Security must therefore come from never writing an over-broad allow — never from rule
  ordering. Any review that reasons about ordering is reviewing incorrectly.

### 13.2 General

- Storage read is auth-gated; write is denied to all clients.
- No clip URL is generated, transmitted, or logged (§8.3).
- Cache is app-private; no shared/external storage, no media-library registration.
- No new PII is collected, stored, or transmitted. Catalog data is non-personal.
- Health data boundary is unaffected — this feature reads no health data.
- No new network origin beyond the existing Firebase project.
- Crashlytics must not receive clip paths or slugs in a way that could enumerate the
  library in third-party logs.

### 13.1 Data-integrity gate — MoveKit-only exercises must not reach user data

This is a **data-safety control, not a coding convention.** §4.9 established that exercise
names are the persisted keys; a MoveKit-only exercise that leaked into a plan or a log would
create history under an identity the planner cannot service (no `type`, no defaults), and
that history cannot be cleanly removed afterwards.

Four layers, ordered from strongest to weakest:

| # | Layer | Why it holds |
|---|---|---|
| 1 | **Type separation** | `MoveKitClip` is not a `Map<String,dynamic>` and not a `PlannedExercise`. **No conversion exists** — no `toPlannedExercise()` is written. |
| 2 | **Missing fields are the gate** | `workout_provider.addCustomExercise` (`:790`) requires nine fields; `MoveKitClip` supplies four. A MoveKit-only exercise **cannot** satisfy it. This is a compile-time impossibility, not a runtime check — which is why §6.1 forbids adding the missing fields. |
| 3 | **Call-site discipline** | The browse layer never calls `addExercise` / `addCustomExercise`. |
| 4 | **Test** | No MoveKit-only slug may appear in `ExerciseData.list`, in any persisted log key, or in any favorites id. |

Layers 1 and 2 are structural; 3 and 4 are defence in depth. **Layer 2 is the reason the
minimal model must stay minimal.** Any future proposal to add `type` or `defaultWeight` to
`MoveKitClip` removes the gate and must be treated as a change to this section.

### 13.2 The 25 LiftOn-only exercises are untouched by construction

`MoveKitResolver` returns `null` for them, so resolution falls through to the existing
YouTube path (§4.3), which this RFC does not modify (§3). **No code change touches these 25
exercises.** A test asserts all 25 still resolve to a YouTube id, so a future refactor
cannot silently strip their demos.

---

## 14. Cost Impact

| Item | Effect |
|---|---|
| Firebase Storage — storage | 412 re-encoded clips; small and effectively fixed. |
| Firebase Storage — egress | **The real cost.** Scales with users × distinct exercises viewed × reinstalls. Lazy fetch + permanent cache + LRU are the controls. |
| App size | **Unchanged.** No clips bundled. |
| Build/CI | One generation step; negligible. |
| Third-party | None. No new vendor. |

A per-user egress estimate cannot be responsibly produced until the clip count and encoded
size ladder are fixed. It is a required input to the implementation plan, not to this RFC.

### 14.1 Revised for a shipped app (2026-08-08)

An earlier draft of this section was written on a pre-launch assumption. That assumption
was wrong: **LiftOn is already live on the Play Store, and the iOS build is in App Store
review** (§4.8). Egress is therefore not a hypothetical future cost — it begins the day
005-B reaches production users, and it scales with the live Android install base.

This changes one architectural conclusion. §8.5 rejected bundling on the grounds that 412
clips cannot fit in an app. That remains true. But it does **not** follow that zero clips
should be bundled. For a shipped app there is a real argument for bundling a small hero set
(the 10–15 most-viewed exercises, re-encoded): those clips then cost no egress at all, work
offline on first launch, and survive any Storage outage — while the long tail stays remote.
The cost of that choice is a larger app update for existing users and two code paths.

**BLOCKED — required input: current Play Store active installs / MAU.** The hybrid is worth
its complexity above some user count and not below it. Without that number the trade-off
cannot be decided, and any egress figure in an implementation plan is invented. iOS
contributes ~0 until the review clears.

## 15. AI Impact

No change to coaching, prompts, quotas, or model usage. One **new binding constraint**:
clip bytes and frames must never enter any model or generative pipeline (§9.2). Existing
AI features are unaffected and remain permitted under licence §5.

---

## 16. Testing Strategy

### 16.1 Unit

- Slug derivation: known names → expected slugs; punctuation, casing, whitespace.
- Facet derivation: equipment → environment mapping table.
- Shelf queries: each of the eight shelves returns the expected set from a fixture catalog.
- Catalog parsing: malformed entry, missing `clip`, unknown equipment value.

### 16.2 Consistency (mandatory — the invariant of §5.1)

> For every entry in `ExerciseData.list`, `slug(name)` **must** exist in
> `exercise_catalog.json`. Failure blocks merge.

Additionally: catalog slugs are unique; every non-null `clip.slug` maps to a declared
storage object; no entry declares an equipment or modality value outside the vocabulary.

### 16.3 Cache & delivery

- Cache miss → download → play; cache hit → no network call.
- Download failure → fallback path (§9.3), no crash, no partial file left behind.
- Concurrent requests for one slug produce one download.
- LRU eviction respects the ceiling and never evicts the in-flight item.
- **Assert `getDownloadURL()` is never called** — a static check or a test double that
  fails the suite if invoked. This is the licence guarantee expressed as a test.

### 16.4 Device

iOS 15 minimum and current, Android API 26 minimum and current: loop continuity, silence,
background/foreground transitions, memory during extended browsing, offline behaviour.

---

## 17. Impact Analysis Matrix

| Dimension | Rating | Justification |
|---|---|---|
| Architecture | **Medium** | Adds a second read-only data authority and a cache service. Boundary is explicit and test-enforced; planner untouched. |
| Database | **None** | No persisted model, Hive box, or Firestore schema change. |
| AI | **Low** | No behavioural change; adds one prohibition (§9.2). |
| Cost | **Medium** | New Storage egress line scaling with usage. Mitigated by lazy fetch, permanent cache, LRU ceiling, re-encode. |
| Security | **Low** | Auth-gated reads, app-private cache, no URLs, no new PII. |
| Performance | **Medium** | Video decode and first-view network latency are new. Mitigated by poster-first rendering, single active controller, one in-flight download. |
| UX | **High** | A whole new browsing section plus a new detail screen. **Mitigation:** built on the currently unreachable `exercise_library_screen.dart`, so no existing user journey changes; the planner's demo button gains a loop but keeps its YouTube path. |
| Operations | **Medium** | New Firebase product to enable, new rules file to deploy, and an asset upload pipeline to run. **Mitigation:** `firestore.rules` already deploys through the same channel; `storage.rules` follows the established path. |

**What the user will see change:** a new "Exercise Demo Videos" section appears in the
Tools/Explore tab, where exercises can be browsed by shelf and filter and opened to watch a
silent looping demo. Inside the planner, exercises gain a looping demo alongside the
existing "Watch Form Demo" button. **No existing workout, plan, log, or setting changes in
any way.**

---

## 18. File Impact List & Rule 9 Assessment

### 18.1 Estimated files

**New (11):**

| File | Est. LOC |
|---|---|
| `assets/data/exercise_catalog.json` | generated asset (not LOC) |
| `tool/build_exercise_catalog.dart` | ~150 |
| `lib/models/catalog_entry.dart` | ~90 |
| `lib/services/exercise_catalog_service.dart` | ~150 |
| `lib/services/clip_cache_service.dart` | ~180 |
| `lib/widgets/exercise/demo_loop_player.dart` | ~200 |
| `lib/screens/exercise_detail_screen.dart` | ~300 |
| `storage.rules` | ~15 |
| `test/exercise_catalog_consistency_test.dart` | ~80 |
| `test/clip_cache_service_test.dart` | ~110 |
| `test/shelf_query_test.dart` | ~90 |

**Modified (5):**

| File | Change | Est. LOC |
|---|---|---|
| `pubspec.yaml` | +`video_player`, +`firebase_storage`, +asset entry | ~4 |
| `firebase.json` | +`storage` block | ~4 |
| `lib/screens/exercise_library_screen.dart` | repoint to catalog + shelves (currently unreachable) | ~180 |
| `lib/screens/tools_screen.dart` | entry point into the demo section | ~15 |
| `lib/widgets/planner/planner_video_widgets.dart` | two surfaces in one file: inline loop in `ExercisePreviewSheet` (§11.2.1, the primary one) and the loop entry beside the existing `ExerciseDemoButton` | ~110 |
| `lib/main.dart` | `ExerciseCatalogService.init()` alongside the existing `ExerciseVideoService.init()` at line 207 | ~2 |

**Total: 17 files, ≈1,632 LOC.**

Precedent note: `lib/main.dart:207` already calls `ExerciseVideoService.init().ignore()`
at startup. The catalog service follows that established pattern rather than inventing a
new initialisation path. If lazy initialisation on first catalog access is preferred, this
file drops out of the impact list entirely — an implementation-plan decision.

### 18.2 Rule 9 verdict — SPLIT REQUIRED

This **exceeds both soft limits** (15 files / 1,500 lines). Under Rule 9 it must be split
or explicitly approved as one. **Recommendation: split into three sequential RFCs**, which
also follows the strangler-fig principle and keeps each piece independently revertible:

| RFC | Content | Ships | Files / LOC |
|---|---|---|---|
| **005-A** Catalog foundation | Generator, schema, catalog asset, model, service, shelf queries, consistency test | Dormant — no UI reads it yet | ~7 / ~570 |
| **005-B** Video delivery | `firebase_storage`, `video_player`, `storage.rules`, cache service, loop player widget, tests | Behind a flag, exercised only by 005-C | ~6 / ~570 |
| **005-C** Demo library UI | Repointed library screen, detail screen, Tools entry point, planner integration | User-visible | ~4 / ~560 |

Each sub-RFC gets its own implementation plan, Production Safety Gate, and PIR.

### 18.3 Owner decisions (approved 2026-08-08)

| Decision | Ruling |
|---|---|
| Rule 9 | **Split approved.** 005-A / 005-B / 005-C as above. |
| "Strength" shelf | **Removed as a top-level shelf** — it matched ~131 of 141 and carried no filtering value (§4.2, §7.2). The `modality` facet keeps the value; only the shelf goes. |
| Bucket region | **`asia-south1` approved** (§8.1). Irreversible after creation. |

### 18.4 Sequencing under the iOS review freeze

§4.8 changes the order these can ship in. 005-B adds `video_player` and
`firebase_storage`, which touch `pubspec.yaml` and the iOS Pods — enough to force a
resubmission and restart App Store review.

| Phase | Work | Gated on |
|---|---|---|
| **Now** | **005-A only.** No new dependency, no UI change, no iOS build change. Ships dormant and is invisible to users, so it cannot disturb the review. | Nothing — safe to start once approved |
| **After review clears** | 005-B, then 005-C | App Store review outcome |

This ordering is not a preference. Starting 005-B during an open review would put the iOS
release at risk to save no time, since 005-A is the prerequisite for both other phases
anyway.

### 18.5 Integration-boundary file lists (approved 2026-08-08)

**Files that would eventually be modified** — nothing is modified now:

| File | Change | Phase | LOC |
|---|---|---|---|
| `pubspec.yaml` | asset entries · then dependencies | A · B | ~6 |
| `lib/main.dart` | `MoveKitCatalogService.init()` beside the existing `ExerciseVideoService.init()` at `:207` | A | ~2 |
| `lib/widgets/planner/planner_video_widgets.dart` | three resolution points: `:25`, `:114`, **`:1011`** | C | ~35 |
| `lib/screens/exercise_library_screen.dart` | browse layer — unreachable today (§4.4), blast radius zero | C | ~120 |

**New files:** `movekit_clip.dart` · `movekit_catalog_service.dart` · `movekit_clip_cache.dart` ·
loop-player widget · `tool/` generator · `storage.rules` · tests · `movekit_catalog.json` ·
`movekit_aliases.json` · posters (pending §8.1.1).

**Files that MUST remain untouched** — this list is a constraint, not a description:

```
lib/data/exercise_data.dart                 planner authority (§5.3)
lib/data/exercise_videos.dart               existing YouTube map — no mapping deleted (§3)
assets/data/exercise_videos.json            existing YouTube data
lib/models/models.dart                      PlannedExercise — persisted (§4.9)
lib/models/workout_log.dart                 WorkoutLog — persisted, name-keyed (§4.9)
lib/providers/workout_provider.dart         progression / PR / sync dedup (§4.9)
lib/services/ai_engine.dart                 type-based pools (§4.9)
lib/services/exercise_candidate_service.dart AI candidate contract
lib/providers/favorites_provider.dart       favorites keyed on old catalog ids (§4.9)
```

### 18.6 Integration-boundary risks

| Risk | Severity | Control |
|---|---|---|
| An approved alias points at the wrong clip | Medium | Aliases only by human review; reversal is deleting one line from `movekit_aliases.json` (§5.4). Never persisted into user data. |
| Someone writes `MoveKitClip → PlannedExercise` | **High** | §13.1 layers 1–2: no conversion exists, and the four missing fields make `addCustomExercise` unsatisfiable. Plus the layer-4 test. |
| Poster bundling inflates an update for live users | Low | §8.1.1, open; does not block 005-A |
| 412-record parse at startup | Low | Slug precomputed at generation time; lazy `init()` available as a fallback |
| Coverage sits at 32% until aliases are approved | — | Accepted and expected; `movekit_aliases.json` ships empty |
| Faceted browse catalog (§6/§7) drifts from the two source datasets | Medium | It is a *derivation*, never hand-edited (§5.5); §16.2 consistency test |

---

## 19. Production Safety Gate

### 19.1 Storage provisioning sequence

This subsection **supersedes the earlier requirement to capture existing console Storage
rules before deploying.** Verification (§4.7) established that no bucket and no
`firebase.storage` rules release exist, so there is nothing to capture and nothing that a
first deploy could silently overwrite. That requirement is void.

It is replaced by a controlled provisioning sequence, because a different and sharper risk
takes its place.

**This is a gate, not an atomic operation.** Firebase provides no combined "create bucket
with rules" call — bucket creation and rules deployment are separate operations, and a
newly created bucket carries permissive default rules until a deploy replaces them. The
bucket must therefore not be considered ready, must not hold licensed content, and must not
be referenced by any client build until every item below has passed.

| # | Gate item | Status |
|---|---|---|
| 1 | Bucket **region confirmed as `asia-south1`** before creation — irreversible (§8.1) | ⬜ |
| 2 | Bucket provisioned | ⬜ |
| 3 | Firebase's default permissive template **not left active** — the window between items 2 and 4 is treated as a live exposure | ⬜ |
| 4 | Reviewed `storage.rules` deployed as the **immediate next action** after creation | ⬜ |
| 5 | Verified from an authenticated test account: clip read **succeeds** · upload **fails** · delete **fails** · unrelated Storage paths **denied** | ⬜ |
| 6 | Verified **unauthenticated** access is denied | ⬜ |
| 7 | Confirmed the app uses no `getDownloadURL()` and constructs no raw or public URL (§8.3) | ⬜ |

**No licensed MoveKit content may be uploaded until item 5 has passed.** Between items 2
and 4 the bucket is in a known-permissive state; it must be empty throughout that window, so
that the worst case is an exposed empty bucket rather than exposed licensed content.

Note that `.firebaserc` declares no staging project (§4.7) — every deploy in this sequence
lands directly on production. There is no rehearsal environment for these steps.

### 19.2 Standard gate items

| # | Item | Status |
|---|---|---|
| 1 | Complete file impact list | ✅ §18 — refine per sub-RFC at implementation-plan time |
| 2 | Backup strategy | ⬜ Git commit ref + rollback branch per sub-RFC. No data at risk: nothing persisted is modified. |
| 3 | Regression risk assessment | ✅ **Low.** No persisted model, no planner data path, no existing reachable screen modified. Highest-risk touch is `planner_video_widgets.dart` (additive only). |
| 4 | Rollback procedure | ✅ §20 |
| 5 | Verification checklist | ⬜ Per sub-RFC: `flutter analyze` clean, unit + consistency tests green, device matrix (§16.4), Storage rules verified, egress sanity check |
| 6 | Success criteria | ⬜ Defined per sub-RFC |

**The gate is not satisfied. Implementation may not begin.** Items 2, 5 and 6 are completed
in each sub-RFC's implementation plan, and §19's blocked inputs must be resolved first.

### 19.3 Shipped-app rollout controls (added 2026-08-08)

§4.8 established that Android is live and iOS is in review. The gate items below exist
only because of that, and none of them were required by the earlier pre-launch draft.

| # | Gate item | Status |
|---|---|---|
| 1 | **Remote Config kill switch** shipped *with* 005-B, defaulting **off**. The feature must be disableable server-side without an app update. `firebase_remote_config` is already a dependency (§4.5) — no new package, no new vendor. | ⬜ |
| 2 | Kill-switch behaviour **verified on a real device before release**: flipping it off mid-session stops downloads and playback and restores the existing YouTube path, with no crash and no orphaned controller. | ⬜ |
| 3 | **Staged Play Store rollout** — 5% → 20% → 100%, with Crashlytics crash-free rate and Storage egress checked at each stage before advancing. | ⬜ |
| 4 | **iOS review freeze respected**: no dependency, Podfile or pbxproj change while a submission is in review (§4.8). | ⬜ |
| 5 | Storage egress dashboard/budget alert live **before** the 20% stage, so a runaway fetch loop is caught by a bill alert rather than by the bill. | ⬜ |
| 6 | Worktree/CI parity: the untracked, gitignored files an Android build requires (`android/key.properties`, `android/app/google-services.json`) are documented for any fresh clone, worktree or CI runner. Both were discovered the hard way on 2026-08-08 — each cost a failed build. | ⬜ |

Item 1 is the load-bearing one. Without it, the only remedy for a defect that reaches
production is shipping another update and waiting for users to take it.

---

## 20. Rollback Plan

**Revised 2026-08-08.** The earlier version of this table said "revert the commit" for two
of three layers. For a shipped app that is not a rollback — reverting source does nothing
for an app already installed on a user's phone. The distinction below is between what can
be undone **before** a release and what can be undone **after** it.

| Layer | Before release | After release (users have it) |
|---|---|---|
| 005-A (catalog) | Revert the commit. The asset is unreferenced by the planner, so removal is inert. | Inert by construction — dormant data, nothing reads it. Nothing to undo. |
| 005-B (video) | Revert the commit; both dependencies come out. | **Remote Config kill switch → off** (§19.3). Downloads and playback stop; posters and the existing YouTube path remain. This is the real rollback. |
| 005-C (UI) | Revert the commit; the library screen returns to being unreachable, as today. | Same kill switch hides the demo section. A code revert additionally requires a store release and user uptake — slow, not a control. |
| Storage | — | Rules can be tightened to deny all reads with no client change. Objects may remain. Blunt: it breaks playback for every user at once, so it is an incident tool, not a rollback. |
| Data | **Nothing to roll back.** No migration, no schema change, no persisted-model change — this is the point of §5.1 and §10. | Same. This property is what keeps rollback cheap. |

**The ordering matters.** Kill switch first (seconds, server-side, no user action), Storage
rules only if the kill switch is somehow insufficient, code revert last and only to stop the
defect reaching *new* users. A code revert alone leaves every existing installation running
the broken build.

Rollback of any layer leaves the app in exactly its pre-RFC state.

## 21. Migration Plan

**None required, by design.** No persisted model changes, no Hive migration, no Firestore
schema change, no data backfill. Existing Android users, plans, logs, and subscriptions are
untouched — ADR-006 is satisfied trivially rather than by mitigation.

The only rollout sequencing is operational: deploy `storage.rules`, upload the encoded
clips, then ship 005-C.

---

## 22. BLOCKED Items

**Items 1–4 and 6 are RESOLVED as of 2026-08-08.** The MoveKit 412 list was supplied and
verified into a master dataset (412 records, ids 1–412, no duplicates, source terminology
preserved). The coverage report was produced; results are recorded in §4.10.

| # | Item | Status |
|---|---|---|
| 1 | Coverage / duplicate report | ✅ **RESOLVED** — §4.10. 45 exact · 133 likely · 255 MoveKit-only · 25 LiftOn-only · 117 near-dup pairs within MoveKit |
| 2 | Final merged exercise count | ✅ **RESOLVED** — ~**396** (141 + 255), not 553 |
| 3 | Missing / new exercise list | ✅ **RESOLVED** — 255 MoveKit-only and 25 LiftOn-only both enumerated |
| 4 | Final taxonomy values | ✅ **RESOLVED** — Band 19 and Kettlebell 25 confirm the Home/Resistance-Band shelves of §4.2 are achievable. Adductors / Neck / Tibialis fall to `'other'` in `normalizeMuscle` and have no icon |
| 5 | Egress and encoded-size estimates | ⬜ **STILL BLOCKED** — clip count is now known (412), but §14.1 needs live MAU |
| 6 | Purchase-scope sanity check | ✅ **RESOLVED** — the surplus is real: 255 of 412 are exercises LiftOn does not have. Not avoidable spend, but note only 45/141 of the *existing* catalog is covered without alias approval |

Two new items, both **human decisions rather than missing data**:

| # | Item | Status |
|---|---|---|
| 8 | **Alias approval — 133 pairs** (HIGH 28 · MEDIUM 68 · LOW 37) | ⬜ Owner review. Not a blocker for 005-A; gates coverage rising from 32% to ~82%. Two HIGH pairs are one-to-many and need a single pick; `Smith Machine Hip Thrust` ↔ `Machine Hip Thrust` may belong in MEDIUM |
| 9 | **117 near-duplicate pairs within MoveKit** | ⬜ Owner review before they enter any browse catalog |

### 22.1 Second blocker, independent of the MoveKit list (added 2026-08-08)

| # | Blocked item | Why |
|---|---|---|
| 7 | **Bundle-a-hero-set vs all-remote decision** (§14.1) | Requires current Play Store active installs / MAU. LiftOn is live (§4.8), so egress is a real cost from day one of 005-B. The hybrid is justified above some user count and wasteful below it. |

Blockers 1–6 gate the **catalog**. Blocker 7 gates the **delivery cost model**. They are
independent: 005-A can proceed on its own once the MoveKit list arrives, without blocker 7
being resolved.

---

# REMAINING BLOCKERS — one input, two reviews, one open decision.

| | Item | Type |
|---|---|---|
| 1 | **Play Store active installs / MAU** — gates the delivery cost model and the bundle-hero-set question (§14.1, §22.1) | missing input |
| 2 | **Alias approval — 133 pairs** (§22 item 8) | owner review |
| 3 | **117 near-duplicate pairs within MoveKit** (§22 item 9) | owner review |
| 4 | **Poster hosting — bundled vs Storage** (§8.1.1) | open decision |

None of the four blocks **005-A** (§18.5). The MoveKit 412 list is no longer a blocker.

## SMALLEST NEXT IMPLEMENTATION STEP — approved 2026-08-08

Scoped deliberately below even 005-A, so that the first commit is provably inert:

> `tool/` generator producing `assets/data/movekit_catalog.json` (412 records, slug
> precomputed) · `MoveKitClip` model (the seven fields of §6.1, no more) ·
> `MoveKitCatalogService` with `init()` + `findFor()` · `movekit_aliases.json` shipped
> **empty** · the §16.2 consistency test.

Properties that make it the correct first step:

- **No UI reads it.** No screen, route or widget references it.
- **No new dependency.** No `video_player`, no `firebase_storage` — so nothing touches
  `pubspec.yaml` in a way that would disturb the open iOS review (§4.8).
- **No Firebase change.** No bucket, no rules, no `firebase.json` edit.
- **No persisted model touched.** No migration, per §3 and §13.1.
- **Rollback is a commit revert** — the only phase where that is still literally true (§20).

The step after it is a single insertion point: the MoveKit check beside `_videoId`
(`planner_video_widgets.dart:1011`). That is the commit at which a loop first becomes
visible to a user, and it is where the §19.3 kill switch becomes mandatory.

---

**No implementation code has been written. No file outside `docs/` has been modified.**

### Prototype evidence (outside this RFC's scope)

A throwaway spike exists on the `movekit-loop-spike` worktree — **explicitly marked
`SPIKE — NOT FOR MERGE`, never merged, and it changes nothing in `main`.** It bundles the
one purchased clip as a Flutter asset, which is *not* the architecture this RFC proposes
(§8.3), and it exists only to falsify assumptions early. On 2026-08-08 it was run on the
iOS Simulator and confirmed:

- slug join works — `"Barbell Bench Press"` → `barbell-bench-press` resolved on first try,
  validating §5.1's central claim that no new identifier system is needed;
- `video_player` initialised in **607 ms**, 1936×1072, 6667 ms loop, muted, playing —
  confirming the format decision in §8.4;
- MoveKit metadata rendered directly into the UI (muscles, equipment, difficulty,
  instructions, common mistakes), supporting the catalog schema in §6.

Two defects it surfaced, both to be avoided in the real implementation: a `catch (_) {}`
that silently swallowed a missing-asset failure, and a synchronous lookup racing an
unawaited `init()`. Neither is in `main`.
