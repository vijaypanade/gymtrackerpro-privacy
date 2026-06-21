// lib/models/split_template.dart
//
// Split style logic — the ONLY place that knows about muscle-group day assignment.
// Everything else (planner, progression, recovery, XP) is split-agnostic.
//
// Adding a new split = add enum value + one entry in _library. Nothing else.

// ═══════════════════════════════════════════════════════
// ENUM
// ═══════════════════════════════════════════════════════
enum SplitStyle {
  pushPullLegs,      // PPL — classic compound-first
  antagonistPairs,   // Chest+Tri / Back+Bi / Legs+Shoulders — proven synergist pairing
  broSplit,          // One muscle group per day — hypertrophy focus
  upperLower,        // Upper / Lower alternating — great for 4×/week
  fullBody,          // Full body each session — best for 2-3×/week beginners
  dailySingleMuscle, // Pure single-muscle focus per day — maximum isolation volume
  aiAdaptive,        // AI decides based on live recovery data
  myOwnWay,          // User builds their own plan from scratch — planner starts empty
}

extension SplitStyleLabel on SplitStyle {
  String get label {
    switch (this) {
      case SplitStyle.pushPullLegs:    return 'Push / Pull / Legs';
      case SplitStyle.antagonistPairs: return 'Chest+Tri / Back+Bi';
      case SplitStyle.broSplit:          return 'Bro Split';
      case SplitStyle.upperLower:        return 'Upper / Lower';
      case SplitStyle.fullBody:          return 'Full Body';
      case SplitStyle.dailySingleMuscle: return 'Daily Single Muscle';
      case SplitStyle.aiAdaptive:        return 'AI Adaptive';
      case SplitStyle.myOwnWay:          return 'My Own Way';
    }
  }

  String get description {
    switch (this) {
      case SplitStyle.pushPullLegs:
        return 'Classic 3–6 day split. Chest/Shoulders/Triceps → Back/Biceps → Legs.';
      case SplitStyle.antagonistPairs:
        return 'Train opposing muscles together. Better recovery between sets.';
      case SplitStyle.broSplit:
        return '5-day split. One muscle group per session. Maximum volume per muscle.';
      case SplitStyle.upperLower:
        return '4-day split. Upper body + Lower body, alternating. Time-efficient.';
      case SplitStyle.fullBody:
        return '2–3 day split. Every session trains all muscles. Best for beginners.';
      case SplitStyle.dailySingleMuscle:
        return '6-day split. Pure single-muscle focus each session — Chest / Back / Shoulders / Biceps / Triceps / Legs. Maximum isolation volume.';
      case SplitStyle.aiAdaptive:
        return 'AI reads your recovery data and builds the optimal schedule each week.';
      case SplitStyle.myOwnWay:
        return 'Start with an empty planner and build your own routine from scratch.';
    }
  }

  String get emoji {
    switch (this) {
      case SplitStyle.pushPullLegs:    return '🔄';
      case SplitStyle.antagonistPairs: return '⚡';
      case SplitStyle.broSplit:          return '💪';
      case SplitStyle.upperLower:        return '↕️';
      case SplitStyle.fullBody:          return '🔥';
      case SplitStyle.dailySingleMuscle: return '🎯';
      case SplitStyle.aiAdaptive:        return '🤖';
      case SplitStyle.myOwnWay:          return '✏️';
    }
  }

  String get name => toString().split('.').last;

  static SplitStyle fromName(String name) {
    return SplitStyle.values.firstWhere(
      (s) => s.name == name,
      orElse: () => SplitStyle.pushPullLegs,
    );
  }
}

// ═══════════════════════════════════════════════════════
// SPLIT DAY — one day's muscle group assignment
// ═══════════════════════════════════════════════════════
class SplitDay {
  final String       focus;        // "Push", "Chest + Triceps", "Upper"
  final List<String> muscles;      // canonical muscle groups for AI constraint
  final bool         isRest;

  const SplitDay({
    required this.focus,
    this.muscles = const [],
    this.isRest  = false,
  });

  static const SplitDay rest = SplitDay(focus: 'Rest', isRest: true);

  // AI prompt line for this day
  String toPromptLine(int dayNumber) {
    if (isRest) return 'Day $dayNumber: Rest';
    return 'Day $dayNumber: $focus — train: ${muscles.join(", ")}';
  }
}

// ═══════════════════════════════════════════════════════
// SPLIT TEMPLATE
// ═══════════════════════════════════════════════════════
class SplitTemplate {
  final SplitStyle  style;
  final List<SplitDay> trainingDays; // training days only (no rest)

  const SplitTemplate({required this.style, required this.trainingDays});

  // ── Static templates library ─────────────────────────
  static const _push = SplitDay(
    focus: 'Push',
    muscles: ['chest', 'shoulders', 'triceps'],
  );
  static const _pull = SplitDay(
    focus: 'Pull',
    muscles: ['back', 'biceps'],
  );
  static const _legs = SplitDay(
    focus: 'Legs',
    muscles: ['quads', 'hamstrings', 'glutes', 'calves'],
  );
  static const _upper = SplitDay(
    focus: 'Upper Body',
    muscles: ['chest', 'back', 'shoulders', 'arms'],
  );
  static const _lower = SplitDay(
    focus: 'Lower Body',
    muscles: ['quads', 'hamstrings', 'glutes', 'calves', 'core'],
  );
  static const _fullA = SplitDay(
    focus: 'Full Body A',
    muscles: ['chest', 'back', 'quads', 'core'],
  );
  static const _fullB = SplitDay(
    focus: 'Full Body B',
    muscles: ['shoulders', 'back', 'hamstrings', 'glutes', 'arms'],
  );
  static const _fullC = SplitDay(
    focus: 'Full Body C',
    muscles: ['chest', 'legs', 'arms', 'core'],
  );
  static const _chestTri = SplitDay(
    focus: 'Chest + Triceps',
    muscles: ['chest', 'triceps'],
  );
  static const _backBi = SplitDay(
    focus: 'Back + Biceps',
    muscles: ['back', 'biceps'],
  );
  static const _legsShoulders = SplitDay(
    focus: 'Legs + Shoulders',
    muscles: ['quads', 'hamstrings', 'glutes', 'calves', 'shoulders'],
  );
  static const _shouldersCore = SplitDay(
    focus: 'Shoulders + Core',
    muscles: ['shoulders', 'core'],
  );
  static const _coreCalves = SplitDay(
    focus: 'Core + Calves',
    muscles: ['core', 'calves'],
  );
  // ── Daily Single Muscle constants ──────────────────
  static const _singChest = SplitDay(
    focus: 'Chest',
    muscles: ['chest'],
  );
  static const _singBack = SplitDay(
    focus: 'Back',
    muscles: ['back'],
  );
  static const _singShoulders = SplitDay(
    focus: 'Shoulders',
    muscles: ['shoulders'],
  );
  static const _singBiceps = SplitDay(
    focus: 'Biceps',
    muscles: ['biceps'],
  );
  static const _singTriceps = SplitDay(
    focus: 'Triceps',
    muscles: ['triceps'],
  );
  static const _singLegs = SplitDay(
    focus: 'Legs',
    muscles: ['quads', 'hamstrings', 'glutes', 'calves'],
  );
  static const _singArms = SplitDay(
    focus: 'Arms',
    muscles: ['biceps', 'triceps'],
  );

  static const _broChest = SplitDay(
    focus: 'Chest Day',
    muscles: ['chest', 'triceps'],
  );
  static const _broBack = SplitDay(
    focus: 'Back Day',
    muscles: ['back', 'biceps'],
  );
  static const _broShoulders = SplitDay(
    focus: 'Shoulder Day',
    muscles: ['shoulders', 'traps'],
  );
  static const _broArms = SplitDay(
    focus: 'Arms Day',
    muscles: ['biceps', 'triceps', 'forearms'],
  );
  static const _broLegs = SplitDay(
    focus: 'Legs Day',
    muscles: ['quads', 'hamstrings', 'glutes', 'calves'],
  );

  // ── Template library: style → days per week → training days ──
  static const Map<SplitStyle, Map<int, List<SplitDay>>> _library = {
    SplitStyle.pushPullLegs: {
      3: [_push, _pull, _legs],
      4: [_push, _pull, _legs, _push],
      5: [_push, _pull, _legs, _push, _pull],
      6: [_push, _pull, _legs, _push, _pull, _legs],
    },
    SplitStyle.upperLower: {
      2: [_upper, _lower],
      3: [_upper, _lower, _upper],
      4: [_upper, _lower, _upper, _lower],
      5: [_upper, _lower, _upper, _lower, _upper],
      6: [_upper, _lower, _upper, _lower, _upper, _lower],
    },
    SplitStyle.antagonistPairs: {
      3: [_chestTri, _backBi, _legsShoulders],
      4: [_chestTri, _backBi, _legsShoulders, _shouldersCore],
      5: [_chestTri, _backBi, _legsShoulders, _chestTri, _backBi],
      6: [_chestTri, _backBi, _legsShoulders, _chestTri, _backBi, _legsShoulders],
    },
    SplitStyle.broSplit: {
      3: [_broChest, _broBack, _broLegs],
      4: [_broChest, _broBack, _broShoulders, _broLegs],
      5: [_broChest, _broBack, _broShoulders, _broArms, _broLegs],
      6: [_broChest, _broBack, _broShoulders, _broArms, _broLegs, _coreCalves],
    },
    SplitStyle.fullBody: {
      2: [_fullA, _fullB],
      3: [_fullA, _fullB, _fullC],
      4: [_fullA, _fullB, _fullA, _fullC],
      5: [_fullA, _fullB, _fullC, _fullA, _fullB],
    },
    SplitStyle.dailySingleMuscle: {
      3: [_singChest, _singBack, _singLegs],
      4: [_singChest, _singBack, _singShoulders, _singLegs],
      5: [_singChest, _singBack, _singShoulders, _singArms, _singLegs],
      6: [_singChest, _singBack, _singShoulders, _singBiceps, _singTriceps, _singLegs],
    },
    // aiAdaptive has no fixed template — AI builds it from recovery data
  };

  // ── Factory ──────────────────────────────────────────
  static SplitTemplate forStyle(SplitStyle style, int daysPerWeek) {
    if (style == SplitStyle.aiAdaptive || style == SplitStyle.myOwnWay) {
      return SplitTemplate(style: style, trainingDays: const []);
    }

    final styleMap = _library[style];
    if (styleMap == null) {
      return forStyle(SplitStyle.pushPullLegs, daysPerWeek);
    }

    // Find closest available daysPerWeek
    final clampedDays = daysPerWeek.clamp(2, 6);
    final days = styleMap[clampedDays] ??
        styleMap[_closestKey(styleMap.keys.toList(), clampedDays)];

    return SplitTemplate(
      style:       style,
      trainingDays: days ?? [_push, _pull, _legs],
    );
  }

  static int _closestKey(List<int> keys, int target) {
    if (keys.isEmpty) return target;
    keys.sort((a, b) => (a - target).abs().compareTo((b - target).abs()));
    return keys.first;
  }

  // ── Prompt generation ─────────────────────────────────
  // Returns the constraint block injected into the Gemini prompt.
  String toPromptConstraints() {
    if (trainingDays.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('SPLIT STRUCTURE (FOLLOW EXACTLY — do not reorder days):');
    for (int i = 0; i < trainingDays.length; i++) {
      buf.writeln(trainingDays[i].toPromptLine(i + 1));
    }
    buf.writeln('→ Fill each day ONLY with exercises for its listed muscle groups.');
    buf.writeln('→ Do NOT mix muscle groups across days.');
    buf.writeln('→ NEVER add core/ab exercises unless "core" is explicitly listed for that day.');
    buf.writeln('→ NEVER repeat the same exercise twice on the same day.');
    buf.writeln('→ On repeated day types (e.g. Day 1 and Day 4 both Chest+Tri): use COMPLETELY DIFFERENT exercises — zero overlap between them.');
    buf.writeln('→ Rest days are automatically added between training days.');

    // ── Split-specific scientific protocols ─────────────
    switch (style) {

      // ── PUSH / PULL / LEGS ────────────────────────────
      case SplitStyle.pushPullLegs:
        buf.writeln('');
        buf.writeln('═══ PPL SCIENTIFIC PROTOCOL ═══');
        buf.writeln('');
        buf.writeln('PUSH DAY — muscles: chest (primary), shoulders, triceps.');
        buf.writeln('  MANDATORY first exercise: Bench Press (flat) OR Incline Bench Press.');
        buf.writeln('  Exercise order: flat/incline press → overhead press → shoulder isolation → tricep isolation.');
        buf.writeln('  MINIMUM: 3 chest exercises + 2 shoulder exercises + 2 tricep exercises.');
        buf.writeln('  NEVER start Push day with lateral raises, flyes, or tricep isolation.');
        buf.writeln('  If two Push days exist (6-day plan): Day 1 = horizontal push focus (Bench Press primary), Day 4 = vertical push focus (Overhead Press primary) — use DIFFERENT exercises on both days.');
        buf.writeln('  BANNED on Push days: back, biceps, rows, pull-downs, core, leg exercises.');
        buf.writeln('');
        buf.writeln('PULL DAY — muscles: back (primary), biceps.');
        buf.writeln('  MANDATORY first exercise: Barbell Row OR Bent-Over Row OR Pull-Ups.');
        buf.writeln('  Exercise order: horizontal row → vertical pull (lat pulldown/pull-ups) → cable row → bicep isolation.');
        buf.writeln('  MINIMUM: 4 back exercises + 3 bicep-only exercises.');
        buf.writeln('  Bicep variety required: include at least one supinated (barbell/EZ curl), one neutral grip (hammer curl), one stretch-focused (incline dumbbell curl or cable curl).');
        buf.writeln('  If two Pull days exist (6-day plan): Day 2 = lat width focus (lat pulldown, pull-ups primary), Day 5 = back thickness focus (rows primary) — use DIFFERENT exercises on both days.');
        buf.writeln('  BANNED on Pull days: chest, triceps, pressing movements, core, leg exercises.');
        buf.writeln('');
        buf.writeln('LEGS DAY — muscles: quads, hamstrings, glutes, calves.');
        buf.writeln('  MANDATORY: include squat pattern (Back Squat, Hack Squat, or Leg Press) AND hip hinge (Romanian Deadlift or Leg Curl).');
        buf.writeln('  Exercise order: squat pattern → hip hinge → quad isolation (leg extension) → hamstring isolation (leg curl) → calf raises.');
        buf.writeln('  MINIMUM 2 calf exercises (standing calf raise + seated calf raise).');
        buf.writeln('  If two Legs days exist (6-day plan): Day 3 = quad dominant (squat heavy), Day 6 = posterior chain dominant (RDL, Hip Thrust heavy) — use DIFFERENT exercises on both days.');
        buf.writeln('  BANNED on Legs days: any upper body exercise, core, pressing movements.');
        break;

      // ── ANTAGONIST PAIRS ──────────────────────────────
      case SplitStyle.antagonistPairs:
        buf.writeln('');
        buf.writeln('═══ ANTAGONIST PAIRS SCIENTIFIC PROTOCOL ═══');
        buf.writeln('');
        buf.writeln('CHEST + TRICEPS DAY:');
        buf.writeln('  MANDATORY first exercise: Flat Bench Press or Incline Bench Press (compound).');
        buf.writeln('  MINIMUM: 4 chest exercises + 3 tricep exercises = 7 minimum total.');
        buf.writeln('  Alternating order: chest compound → tricep compound → chest isolation → tricep isolation → chest fly → tricep finisher.');
        buf.writeln('  Chest variety: flat press + incline press + fly/cable fly (all three angles covered).');
        buf.writeln('  Tricep variety: overhead extension (long head) + pushdown (lateral head) + dips or close-grip bench (all heads).');
        buf.writeln('  BANNED: back, biceps, rows, pull-downs, shoulders (no lateral raises), core, legs.');
        buf.writeln('');
        buf.writeln('BACK + BICEPS DAY:');
        buf.writeln('  MANDATORY first exercise: Barbell Row, Bent-Over Row, or Pull-Ups (compound).');
        buf.writeln('  MINIMUM: 4 back exercises + 3 bicep exercises = 7 minimum total.');
        buf.writeln('  Back variety: include BOTH lat width movement (lat pulldown/pull-ups) AND thickness movement (row). Both are mandatory.');
        buf.writeln('  Alternating order: back compound → bicep exercise → back isolation → bicep exercise → back finisher → bicep finisher.');
        buf.writeln('  Bicep variety: supinated grip (barbell/EZ curl) + neutral grip (hammer curl) + stretch-focused (incline curl or cable curl).');
        buf.writeln('  BANNED: chest, triceps, pressing movements, core, legs. Biceps are MANDATORY — zero core substitution allowed.');
        buf.writeln('');
        buf.writeln('LEGS + SHOULDERS DAY:');
        buf.writeln('  MANDATORY: include squat or leg press (quad compound) AND Romanian Deadlift or hip thrust (posterior chain).');
        buf.writeln('  MANDATORY shoulder compound: Overhead Press (barbell or dumbbell).');
        buf.writeln('  MINIMUM: 3 leg exercises + 3 shoulder exercises = 6 minimum total.');
        buf.writeln('  Shoulder variety: overhead press + lateral raises + rear delt fly or face pull. Rear delts are MANDATORY.');
        buf.writeln('  Order: squat → overhead press → leg isolation → lateral raises → hip hinge → rear delt.');
        buf.writeln('  BANNED: chest, back, biceps, triceps, core exercises.');
        buf.writeln('');
        buf.writeln('If two same-focus days exist (e.g., Day 1 and Day 4 both Chest+Tri): use COMPLETELY DIFFERENT exercises — zero exercise overlap.');
        break;

      // ── BRO SPLIT ─────────────────────────────────────
      case SplitStyle.broSplit:
        buf.writeln('');
        buf.writeln('═══ BRO SPLIT SCIENTIFIC PROTOCOL ═══');
        buf.writeln('Each muscle is trained ONCE per week — ALL weekly volume goes into ONE session. Maximum variety required.');
        buf.writeln('Compound exercises FIRST. Isolation exercises LAST. Never reverse this order.');
        buf.writeln('');
        buf.writeln('CHEST DAY (chest + triceps secondary):');
        buf.writeln('  MANDATORY: Flat Bench Press AND Incline Bench Press — both required for complete chest development.');
        buf.writeln('  Exercise order: flat bench → incline bench → dumbbell press variation → cable fly or pec deck → tricep finisher (1-2 exercises).');
        buf.writeln('  Include: at least one stretch-focused exercise (dumbbell fly, incline fly) for chest hypertrophy.');
        buf.writeln('  Triceps are a secondary add-on at the end — 1-2 exercises only.');
        buf.writeln('');
        buf.writeln('BACK DAY (back + biceps secondary):');
        buf.writeln('  MANDATORY: Deadlift or Barbell Row (compound hip hinge or horizontal pull) AND Lat Pulldown or Pull-Ups (vertical pull).');
        buf.writeln('  Exercise order: barbell row or deadlift → lat pulldown/pull-ups → cable row → dumbbell row → bicep isolation (2-3 exercises).');
        buf.writeln('  Include BOTH width training (lat pulldown/pull-ups) AND thickness training (rows) — both are mandatory.');
        buf.writeln('  Bicep exercises at the end — 2-3 exercises with grip variety.');
        buf.writeln('');
        buf.writeln('SHOULDER DAY (shoulders + traps):');
        buf.writeln('  MANDATORY first exercise: Overhead Press (barbell or dumbbell).');
        buf.writeln('  MANDATORY: include rear delt exercise (face pull, rear delt fly, or reverse pec deck) — rear delts are always skipped and always mandatory.');
        buf.writeln('  Exercise order: overhead press → Arnold press or seated DB press → lateral raises → rear delt fly/face pull → shrugs (for traps).');
        buf.writeln('  Cover all three delt heads: front (OHP), lateral (lateral raise), rear (face pull/reverse fly).');
        buf.writeln('');
        buf.writeln('ARMS DAY (biceps + triceps + forearms):');
        buf.writeln('  EQUAL SPLIT: exactly 3-4 bicep exercises + 3-4 tricep exercises. Never more than 1 exercise difference.');
        buf.writeln('  Alternating order: bicep → tricep → bicep → tricep throughout the session.');
        buf.writeln('  Bicep variety: barbell/EZ curl → hammer curl → incline dumbbell curl → cable curl.');
        buf.writeln('  Tricep variety: skull crusher or overhead extension → cable pushdown → dips or close-grip bench → kickback.');
        buf.writeln('  Forearms: 1-2 exercises at the very end (wrist curl, reverse wrist curl, or reverse barbell curl).');
        buf.writeln('');
        buf.writeln('LEGS DAY (full leg development):');
        buf.writeln('  MANDATORY: Back Squat or Hack Squat AND Romanian Deadlift or Leg Curl — both movement patterns required.');
        buf.writeln('  Exercise order: squat → RDL → leg press → leg curl → leg extension → seated/standing calf raise.');
        buf.writeln('  MINIMUM 2 calf exercises. Calves are never skipped on legs day.');
        buf.writeln('  Cover full posterior chain: RDL + leg curl for hamstrings and glutes.');
        buf.writeln('');
        buf.writeln('Do NOT repeat any exercise within the same week across days.');
        break;

      // ── UPPER / LOWER ─────────────────────────────────
      case SplitStyle.upperLower:
        buf.writeln('');
        buf.writeln('═══ UPPER / LOWER SCIENTIFIC PROTOCOL ═══');
        buf.writeln('');
        buf.writeln('UPPER BODY DAY — muscles: chest, back, shoulders, arms.');
        buf.writeln('  MANDATORY movement patterns every upper session:');
        buf.writeln('    1. Horizontal PUSH: Bench Press or Dumbbell Press (mandatory compound).');
        buf.writeln('    2. Horizontal PULL: Barbell Row or Cable Row (mandatory compound).');
        buf.writeln('    3. Vertical PUSH or PULL: Overhead Press OR Lat Pulldown/Pull-Ups (at least one).');
        buf.writeln('    4. Shoulder isolation: lateral raises or rear delt fly.');
        buf.writeln('    5. Arm isolation: 1 bicep + 1 tricep exercise.');
        buf.writeln('  If two Upper days exist (4-5 day plan): Upper A = chest/horizontal push focus, Upper B = back/vertical pull focus — use DIFFERENT exercises.');
        buf.writeln('  MINIMUM per session: 2 chest + 2 back + 1-2 shoulders + 1 bicep + 1 tricep.');
        buf.writeln('  BANNED on Upper days: squat, leg press, deadlift, leg curl, calf raise, any leg exercise.');
        buf.writeln('');
        buf.writeln('LOWER BODY DAY — muscles: quads, hamstrings, glutes, calves.');
        buf.writeln('  MANDATORY: squat pattern (Back Squat, Front Squat, or Leg Press) AND hip hinge (Romanian Deadlift, Leg Curl, or Hip Thrust). Both movement patterns are mandatory every lower session.');
        buf.writeln('  Exercise order: squat → hip hinge → quad isolation (leg extension) → hamstring isolation (seated leg curl) → glute isolation (hip thrust if not done) → calf raises.');
        buf.writeln('  MINIMUM 2 calf exercises per lower session — calves are never skipped.');
        buf.writeln('  Core: 1-2 core exercises are permitted on lower days ONLY (not on upper days).');
        buf.writeln('  BANNED on Lower days: bench press, overhead press, rows, pull-downs, arm exercises.');
        buf.writeln('');
        buf.writeln('If alternating (Upper A / Upper B): rotate emphasis. Never use identical exercises on both upper days.');
        break;

      // ── FULL BODY ─────────────────────────────────────
      case SplitStyle.fullBody:
        buf.writeln('');
        buf.writeln('═══ FULL BODY SCIENTIFIC PROTOCOL ═══');
        buf.writeln('Volume is distributed across multiple sessions per week — keep sets per muscle per session lower (2-4 sets), not 5+.');
        buf.writeln('');
        buf.writeln('EVERY full body session MUST include ALL SIX movement patterns:');
        buf.writeln('  1. SQUAT PATTERN: Back Squat, Goblet Squat, Hack Squat, or Leg Press (mandatory).');
        buf.writeln('  2. HIP HINGE: Romanian Deadlift, Deadlift, or Hip Thrust (mandatory — never skip).');
        buf.writeln('  3. HORIZONTAL PUSH: Bench Press, Incline Press, or Dumbbell Press (mandatory).');
        buf.writeln('  4. HORIZONTAL PULL: Barbell Row, Dumbbell Row, or Cable Row (mandatory).');
        buf.writeln('  5. VERTICAL PUSH or PULL: Overhead Press OR Lat Pulldown/Pull-Ups (at least one).');
        buf.writeln('  6. ISOLATION FINISHER: 1 arm exercise (curl or pushdown) + 1 calf raise.');
        buf.writeln('');
        buf.writeln('Session rotation (for variety when multiple full-body days exist):');
        buf.writeln('  Full Body A: squat heavy (3-4 sets), bench press heavy → rows → RDL lighter → OHP lighter.');
        buf.writeln('  Full Body B: deadlift/RDL heavy → row heavy → leg press lighter → OHP heavy → pull-ups.');
        buf.writeln('  Full Body C: overhead press heavy → pull-ups heavy → squat lighter → RDL lighter → dumbbell variations.');
        buf.writeln('Compound exercises ALWAYS come first. Never program isolation before compound.');
        buf.writeln('BANNED: core-only exercises as main exercises. Core is trained incidentally through compound lifts.');
        break;

      // ── DAILY SINGLE MUSCLE ───────────────────────────
      case SplitStyle.dailySingleMuscle:
        buf.writeln('');
        buf.writeln('═══ DAILY SINGLE MUSCLE SCIENTIFIC PROTOCOL ═══');
        buf.writeln('All weekly volume for the target muscle goes into ONE session. Maximum variety and angle coverage required.');
        buf.writeln('');
        buf.writeln('EQUIPMENT PROGRESSION within each session (follow this order):');
        buf.writeln('  1. BARBELL compound (1-2 exercises, heaviest load, 4-5 sets) — always first.');
        buf.writeln('  2. DUMBBELL variations (2 exercises, 3-4 sets) — unilateral or bilateral.');
        buf.writeln('  3. CABLE exercises (2 exercises, 3 sets) — constant tension through full range.');
        buf.writeln('  4. MACHINE exercises (1-2 exercises, 3 sets) — peak contraction focus.');
        buf.writeln('');
        buf.writeln('MANDATORY ANGLE COVERAGE per muscle:');
        buf.writeln('  CHEST: flat angle + incline angle + decline or fly (stretch-focused) — all three required.');
        buf.writeln('  BACK: vertical pull (lat pulldown/pull-ups) + horizontal row + low cable row — all three required.');
        buf.writeln('  SHOULDERS: front delt (OHP) + lateral delt (lateral raise) + rear delt (face pull/reverse fly) — all three heads required.');
        buf.writeln('  BICEPS: supinated grip (barbell curl) + neutral grip (hammer curl) + stretch-position (incline dumbbell curl) + peak contraction (cable curl) — minimum 3 of 4.');
        buf.writeln('  TRICEPS: overhead position (overhead extension — long head) + pushdown (lateral/medial head) + dip angle (dips/close-grip) — all three heads required.');
        buf.writeln('  LEGS: squat pattern (quad dominant) + hip hinge (posterior chain) + leg press + isolation (leg curl, leg extension) + calves — full coverage required.');
        buf.writeln('');
        buf.writeln('MANDATORY per session:');
        buf.writeln('  - At least 1 stretch-position exercise (incline curl for biceps, fly for chest, overhead extension for triceps, RDL for hamstrings).');
        buf.writeln('  - At least 1 peak-contraction exercise (cable curl, cable fly, cable pushdown, leg extension).');
        buf.writeln('  - NEVER repeat any exercise. All exercises must be unique.');
        buf.writeln('  - BANNED: exercises for any muscle NOT listed for that day.');
        break;

      case SplitStyle.myOwnWay:
        break;
      default:
        break;
    }
    return buf.toString();
  }

  String toCompactPromptConstraints() {
    if (trainingDays.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('SPLIT STRUCTURE:');
    for (int i = 0; i < trainingDays.length; i++) {
      buf.writeln(trainingDays[i].toPromptLine(i + 1));
    }
    buf.writeln('Rules: train only listed muscles; no duplicate exercise_id on a day; rest days = no exercises.');

    switch (style) {
      case SplitStyle.pushPullLegs:
        buf.writeln('PPL order: Push=chest/shoulders/triceps, Pull=back/biceps, Legs=quads/hamstrings/glutes/calves. Start each day with compound lifts, then isolation.');
        break;
      case SplitStyle.antagonistPairs:
        buf.writeln('Antagonist days: Chest+Triceps, Back+Biceps, Legs+Shoulders. Alternate related muscle exercises and keep banned muscles out of each day.');
        break;
      case SplitStyle.broSplit:
        buf.writeln('Bro split: one primary muscle per session, compound first, isolation last, maximum angle variety, no exercise repeated across the week.');
        break;
      case SplitStyle.upperLower:
        buf.writeln('Upper: horizontal push, horizontal pull, vertical push/pull, shoulders, arms. Lower: squat pattern, hinge, quad/hamstring isolation, calves.');
        break;
      case SplitStyle.fullBody:
        buf.writeln('Full body: each session includes squat, hinge, horizontal push, horizontal pull, vertical push/pull, and a small isolation finisher.');
        break;
      case SplitStyle.dailySingleMuscle:
        buf.writeln('Daily single muscle: all weekly volume for listed muscle in one session; use barbell/dumbbell/cable/machine variety and cover key angles.');
        break;
      case SplitStyle.aiAdaptive:
        break;
      case SplitStyle.myOwnWay:
        break;
    }
    return buf.toString();
  }

  // ── AI Adaptive prompt ────────────────────────────────
  // When style is aiAdaptive, use this instead. Takes live recovery scores.
  static String adaptivePromptConstraints({
    required List<({String muscle, int score})> recoveryScores,
    required int daysPerWeek,
    required String goal,
    required int streak,
  }) {
    final buf = StringBuffer();
    buf.writeln('SPLIT STYLE: AI ADAPTIVE');
    buf.writeln('Build the optimal schedule using these live recovery scores:');
    final sorted = List.of(recoveryScores)
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final r in sorted) {
      final status = r.score >= 80
          ? '✅ READY'
          : r.score >= 60
              ? '🟡 OK'
              : '🔴 AVOID';
      buf.writeln('  ${r.muscle}: ${r.score}% $status');
    }
    buf.writeln('');
    buf.writeln('ADAPTIVE RULES (apply in order of priority):');
    buf.writeln('1. NEVER schedule a muscle below 40% recovery.');
    buf.writeln('2. Prefer muscles above 70% — that is peak training window.');
    buf.writeln('3. Ensure each major muscle group appears at least once across $daysPerWeek days.');
    buf.writeln('4. If goal is muscle_gain → prioritize compound movements first.');
    buf.writeln('5. Protect the streak — keep volume manageable if streak ≥ 5 days.');
    buf.writeln('6. Pair synergists when scheduling (chest+triceps, back+biceps).');
    buf.writeln('→ Output $daysPerWeek training days optimised for these scores.');
    return buf.toString();
  }
}
