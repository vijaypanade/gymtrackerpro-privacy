// lib/services/exercise_intelligence_service.dart
// Pure Dart — no Flutter imports.
// Auto-classifies exercise names into muscle groups, movement patterns,
// equipment type, and fatigue profile using deterministic keyword rules.
//
// Classification pipeline:
//   1. Exact known-exercise lookup   (confidence ≥ 0.95)
//   2. Keyword extraction + rules    (confidence 0.50–0.85)
//   3. Returns low-confidence profile when signal is insufficient
//
// Custom exercise learning:
//   Unknown names are classified by structural keyword cues (e.g. "Row" → pull/back).
//   Confidence rises as more signals converge (equipment + muscle + movement all detected).

// ── Enums ─────────────────────────────────────────────────────────────────────

enum MovementPattern { push, pull, hinge, squat, carry, isolation, cardio, unknown }
enum EquipmentType   { barbell, dumbbell, cable, machine, bodyweight, band, kettlebell, unknown }
enum ExerciseCategory { compound, isolation, cardio, unknown }

extension MovementPatternLabel on MovementPattern {
  String get label => switch (this) {
    MovementPattern.push      => 'Push',
    MovementPattern.pull      => 'Pull',
    MovementPattern.hinge     => 'Hinge',
    MovementPattern.squat     => 'Squat',
    MovementPattern.carry     => 'Carry',
    MovementPattern.isolation => 'Isolation',
    MovementPattern.cardio    => 'Cardio',
    MovementPattern.unknown   => '',
  };
}

extension ExerciseCategoryLabel on ExerciseCategory {
  String get label => switch (this) {
    ExerciseCategory.compound  => 'Compound',
    ExerciseCategory.isolation => 'Isolation',
    ExerciseCategory.cardio    => 'Cardio',
    ExerciseCategory.unknown   => '',
  };
}

// ── Output model ──────────────────────────────────────────────────────────────

class ExerciseProfile {
  final String canonicalName;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final MovementPattern movementPattern;
  final EquipmentType equipment;
  final bool axialLoading;
  /// Relative CNS / systemic fatigue demand, 0–1.
  final double fatigueWeight;
  final ExerciseCategory category;
  final bool isCustom;
  /// true when muscle group was inferred rather than exactly known.
  final bool isEstimated;
  /// 0–1 classification confidence.
  final double confidence;
  final List<String> aliases;

  const ExerciseProfile({
    required this.canonicalName,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.movementPattern,
    required this.equipment,
    required this.axialLoading,
    required this.fatigueWeight,
    required this.category,
    required this.isCustom,
    required this.isEstimated,
    required this.confidence,
    this.aliases = const [],
  });

  static const ExerciseProfile unknown = ExerciseProfile(
    canonicalName:    '',
    primaryMuscle:    '',
    secondaryMuscles: [],
    movementPattern:  MovementPattern.unknown,
    equipment:        EquipmentType.unknown,
    axialLoading:     false,
    fatigueWeight:    0.5,
    category:         ExerciseCategory.unknown,
    isCustom:         true,
    isEstimated:      true,
    confidence:       0.0,
  );

  ExerciseProfile withName(String name) => ExerciseProfile(
    canonicalName:    name,
    primaryMuscle:    primaryMuscle,
    secondaryMuscles: secondaryMuscles,
    movementPattern:  movementPattern,
    equipment:        equipment,
    axialLoading:     axialLoading,
    fatigueWeight:    fatigueWeight,
    category:         category,
    isCustom:         true,
    isEstimated:      true,
    confidence:       confidence * 0.88,
    aliases:          aliases,
  );
}

// ── Known exercise table ───────────────────────────────────────────────────────
// Compact tuple format: (primary, secondaries, pattern, equipment, axial, fatigue, category)
typedef _KnownEntry = ({
  String          primary,
  List<String>    secondary,
  MovementPattern pattern,
  EquipmentType   equip,
  bool            axial,
  double          fatigue,
  ExerciseCategory cat,
  List<String>    aliases,
});

ExerciseProfile _ep(_KnownEntry e, String name) => ExerciseProfile(
  canonicalName:    name,
  primaryMuscle:    e.primary,
  secondaryMuscles: e.secondary,
  movementPattern:  e.pattern,
  equipment:        e.equip,
  axialLoading:     e.axial,
  fatigueWeight:    e.fatigue,
  category:         e.cat,
  isCustom:         false,
  isEstimated:      false,
  confidence:       0.95,
  aliases:          e.aliases,
);

const _push = MovementPattern.push;
const _pull = MovementPattern.pull;
const _hing = MovementPattern.hinge;
const _squt = MovementPattern.squat;
const _isol = MovementPattern.isolation;
const _card = MovementPattern.cardio;

const _bb  = EquipmentType.barbell;
const _db  = EquipmentType.dumbbell;
const _cab = EquipmentType.cable;
const _mac = EquipmentType.machine;
const _bw  = EquipmentType.bodyweight;

const _com = ExerciseCategory.compound;
const _iso = ExerciseCategory.isolation;
const _car = ExerciseCategory.cardio;

final Map<String, _KnownEntry> _kTable = {
  // ── Chest ─────────────────────────────────────────────────────────────
  'bench press':              (primary:'chest', secondary:['shoulders','triceps'],   pattern:_push, equip:_bb, axial:false, fatigue:0.82, cat:_com, aliases:['barbell bench press']),
  'incline bench press':      (primary:'chest', secondary:['shoulders','triceps'],   pattern:_push, equip:_bb, axial:false, fatigue:0.78, cat:_com, aliases:['incline press']),
  'decline bench press':      (primary:'chest', secondary:['triceps'],               pattern:_push, equip:_bb, axial:false, fatigue:0.75, cat:_com, aliases:[]),
  'dumbbell bench press':     (primary:'chest', secondary:['shoulders','triceps'],   pattern:_push, equip:_db, axial:false, fatigue:0.75, cat:_com, aliases:['db bench']),
  'dumbbell fly':             (primary:'chest', secondary:[],                        pattern:_isol, equip:_db, axial:false, fatigue:0.40, cat:_iso, aliases:['db flye']),
  'cable fly':                (primary:'chest', secondary:[],                        pattern:_isol, equip:_cab, axial:false, fatigue:0.35, cat:_iso, aliases:['cable crossover','pec deck']),
  'push up':                  (primary:'chest', secondary:['shoulders','triceps'],   pattern:_push, equip:_bw, axial:false, fatigue:0.45, cat:_com, aliases:['push-up','pushup']),
  // ── Shoulders ─────────────────────────────────────────────────────────
  'overhead press':           (primary:'shoulders', secondary:['triceps'],           pattern:_push, equip:_bb, axial:false, fatigue:0.80, cat:_com, aliases:['ohp','military press','shoulder press']),
  'dumbbell shoulder press':  (primary:'shoulders', secondary:['triceps'],           pattern:_push, equip:_db, axial:false, fatigue:0.72, cat:_com, aliases:['db shoulder press','arnold press']),
  'lateral raise':            (primary:'shoulders', secondary:[],                    pattern:_isol, equip:_db, axial:false, fatigue:0.28, cat:_iso, aliases:['db lateral raise','side raise']),
  'cable lateral raise':      (primary:'shoulders', secondary:[],                    pattern:_isol, equip:_cab, axial:false, fatigue:0.25, cat:_iso, aliases:[]),
  'front raise':              (primary:'shoulders', secondary:[],                    pattern:_isol, equip:_db, axial:false, fatigue:0.28, cat:_iso, aliases:[]),
  'face pull':                (primary:'shoulders', secondary:['back'],              pattern:_pull, equip:_cab, axial:false, fatigue:0.30, cat:_iso, aliases:[]),
  'rear delt fly':            (primary:'shoulders', secondary:[],                    pattern:_isol, equip:_db, axial:false, fatigue:0.28, cat:_iso, aliases:['reverse fly','bent over fly']),
  // ── Back ──────────────────────────────────────────────────────────────
  'deadlift':                 (primary:'back', secondary:['glutes','hamstrings'],    pattern:_hing, equip:_bb, axial:true,  fatigue:1.00, cat:_com, aliases:['barbell deadlift','conventional deadlift']),
  'romanian deadlift':        (primary:'back', secondary:['hamstrings','glutes'],    pattern:_hing, equip:_bb, axial:true,  fatigue:0.85, cat:_com, aliases:['rdl','romanian dl']),
  'sumo deadlift':            (primary:'back', secondary:['glutes','quads'],         pattern:_hing, equip:_bb, axial:true,  fatigue:0.90, cat:_com, aliases:[]),
  'good morning':             (primary:'back', secondary:['hamstrings'],             pattern:_hing, equip:_bb, axial:true,  fatigue:0.75, cat:_com, aliases:[]),
  'barbell row':              (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_bb, axial:true,  fatigue:0.80, cat:_com, aliases:['barbell bent over row','bent over row']),
  'pendlay row':              (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_bb, axial:true,  fatigue:0.78, cat:_com, aliases:[]),
  'cable row':                (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_cab, axial:false, fatigue:0.55, cat:_com, aliases:['seated cable row','low cable row']),
  'chest supported row':      (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_mac, axial:false, fatigue:0.55, cat:_com, aliases:['chest supported dumbbell row']),
  'lat pulldown':             (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_cab, axial:false, fatigue:0.60, cat:_com, aliases:['wide grip pulldown']),
  'pull up':                  (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_bw, axial:false, fatigue:0.70, cat:_com, aliases:['pull-up','pullup','chin up','chin-up']),
  'dumbbell row':             (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_db, axial:false, fatigue:0.60, cat:_com, aliases:['single arm row','one arm row']),
  't-bar row':                (primary:'back', secondary:['biceps'],                 pattern:_pull, equip:_bb, axial:true,  fatigue:0.75, cat:_com, aliases:['t bar row','tbar row']),
  'cable pull-through':       (primary:'back', secondary:['glutes','hamstrings'],    pattern:_hing, equip:_cab, axial:false, fatigue:0.45, cat:_com, aliases:['cable pull through']),
  // ── Biceps ────────────────────────────────────────────────────────────
  'barbell curl':             (primary:'biceps', secondary:['brachialis'],           pattern:_isol, equip:_bb, axial:false, fatigue:0.38, cat:_iso, aliases:['barbell bicep curl']),
  'dumbbell curl':            (primary:'biceps', secondary:['brachialis'],           pattern:_isol, equip:_db, axial:false, fatigue:0.32, cat:_iso, aliases:['bicep curl','db curl']),
  'hammer curl':              (primary:'biceps', secondary:['brachialis'],           pattern:_isol, equip:_db, axial:false, fatigue:0.32, cat:_iso, aliases:[]),
  'cable curl':               (primary:'biceps', secondary:[],                       pattern:_isol, equip:_cab, axial:false, fatigue:0.28, cat:_iso, aliases:[]),
  'preacher curl':            (primary:'biceps', secondary:[],                       pattern:_isol, equip:_bb, axial:false, fatigue:0.35, cat:_iso, aliases:[]),
  // ── Triceps ───────────────────────────────────────────────────────────
  'tricep pushdown':          (primary:'triceps', secondary:[],                      pattern:_isol, equip:_cab, axial:false, fatigue:0.28, cat:_iso, aliases:['cable pushdown','cable tricep pushdown']),
  'skull crusher':            (primary:'triceps', secondary:[],                      pattern:_isol, equip:_bb, axial:false, fatigue:0.38, cat:_iso, aliases:['lying tricep extension','ez bar extension']),
  'overhead tricep extension':(primary:'triceps', secondary:[],                      pattern:_isol, equip:_db, axial:false, fatigue:0.32, cat:_iso, aliases:['overhead extension']),
  'dip':                      (primary:'triceps', secondary:['chest','shoulders'],   pattern:_push, equip:_bw, axial:false, fatigue:0.55, cat:_com, aliases:['parallel bar dip']),
  // ── Legs — Quads ──────────────────────────────────────────────────────
  'squat':                    (primary:'quads', secondary:['glutes','hamstrings'],   pattern:_squt, equip:_bb, axial:true,  fatigue:0.95, cat:_com, aliases:['back squat','barbell squat']),
  'front squat':              (primary:'quads', secondary:['glutes'],                pattern:_squt, equip:_bb, axial:true,  fatigue:0.90, cat:_com, aliases:[]),
  'leg press':                (primary:'quads', secondary:['glutes'],                pattern:_squt, equip:_mac, axial:false, fatigue:0.75, cat:_com, aliases:[]),
  'hack squat':               (primary:'quads', secondary:['glutes'],                pattern:_squt, equip:_mac, axial:false, fatigue:0.78, cat:_com, aliases:[]),
  'lunge':                    (primary:'quads', secondary:['glutes','hamstrings'],   pattern:_squt, equip:_db, axial:false, fatigue:0.60, cat:_com, aliases:['walking lunge','reverse lunge']),
  'split squat':              (primary:'quads', secondary:['glutes'],                pattern:_squt, equip:_db, axial:false, fatigue:0.65, cat:_com, aliases:['bulgarian split squat','bss']),
  'leg extension':            (primary:'quads', secondary:[],                        pattern:_isol, equip:_mac, axial:false, fatigue:0.30, cat:_iso, aliases:[]),
  // ── Legs — Hamstrings / Glutes ────────────────────────────────────────
  'leg curl':                 (primary:'hamstrings', secondary:[],                   pattern:_isol, equip:_mac, axial:false, fatigue:0.30, cat:_iso, aliases:['seated leg curl','lying leg curl']),
  'hip thrust':               (primary:'glutes', secondary:['hamstrings'],           pattern:_hing, equip:_bb, axial:false, fatigue:0.65, cat:_com, aliases:['barbell hip thrust']),
  'glute bridge':             (primary:'glutes', secondary:[],                       pattern:_hing, equip:_bw, axial:false, fatigue:0.38, cat:_iso, aliases:[]),
  'hip abduction':            (primary:'glutes', secondary:[],                       pattern:_isol, equip:_mac, axial:false, fatigue:0.25, cat:_iso, aliases:['abductor machine']),
  // ── Calves ────────────────────────────────────────────────────────────
  'calf raise':               (primary:'calves', secondary:[],                       pattern:_isol, equip:_mac, axial:false, fatigue:0.22, cat:_iso, aliases:['standing calf raise','seated calf raise']),
  // ── Core ──────────────────────────────────────────────────────────────
  'plank':                    (primary:'core', secondary:[],                         pattern:_isol, equip:_bw, axial:false, fatigue:0.20, cat:_iso, aliases:[]),
  'crunch':                   (primary:'core', secondary:[],                         pattern:_isol, equip:_bw, axial:false, fatigue:0.18, cat:_iso, aliases:['sit up']),
  'cable crunch':             (primary:'core', secondary:[],                         pattern:_isol, equip:_cab, axial:false, fatigue:0.22, cat:_iso, aliases:[]),
  // ── Cardio ────────────────────────────────────────────────────────────
  'treadmill':                (primary:'cardio', secondary:[],                       pattern:_card, equip:_mac, axial:false, fatigue:0.40, cat:_car, aliases:['running','jogging']),
  'stationary bike':          (primary:'cardio', secondary:[],                       pattern:_card, equip:_mac, axial:false, fatigue:0.35, cat:_car, aliases:['cycling','bike']),
  'rowing machine':           (primary:'cardio', secondary:['back'],                 pattern:_card, equip:_mac, axial:false, fatigue:0.45, cat:_car, aliases:['concept2','ergometer']),
};

// ── Service ───────────────────────────────────────────────────────────────────

class ExerciseIntelligenceService {
  ExerciseIntelligenceService._();

  /// Classify any exercise name, including custom or user-invented ones.
  /// Returns [ExerciseProfile.unknown] when no signal can be found.
  static ExerciseProfile classify(String name) {
    if (name.trim().isEmpty) return ExerciseProfile.unknown;
    final lower = name.toLowerCase().trim();

    // 1. Exact lookup
    final exact = _kTable[lower];
    if (exact != null) return _ep(exact, name);

    // 2. Alias lookup
    for (final entry in _kTable.entries) {
      if (entry.value.aliases.any((a) => a.toLowerCase() == lower)) {
        return _ep(entry.value, name);
      }
    }

    // 3. Fuzzy keyword match against known names
    for (final entry in _kTable.entries) {
      if (_strongFuzzyMatch(lower, entry.key)) {
        return _ep(entry.value, name).withName(name);
      }
    }

    // 4. Keyword inference
    return _inferFromKeywords(name, lower);
  }

  /// Whether this profile's primary muscle is in the suppressed set —
  /// used by adaptive engine to evaluate custom exercises.
  static bool isMuscleSuppressed(ExerciseProfile p, List<String> suppressed) {
    if (p.primaryMuscle.isEmpty) return false;
    return suppressed.contains(p.primaryMuscle) ||
        p.secondaryMuscles.any((m) => suppressed.contains(m));
  }

  // ── Fuzzy matching ────────────────────────────────────────────────────────

  static bool _strongFuzzyMatch(String input, String known) {
    final kWords = known.split(' ').where((w) => w.length > 2).toList();
    if (kWords.isEmpty) return false;
    final iWords = input.split(' ');
    final matches = kWords.where((kw) => iWords.any((iw) => iw.contains(kw) || kw.contains(iw))).length;
    return matches >= (kWords.length * 0.70).ceil() && matches >= 2;
  }

  // ── Keyword inference pipeline ────────────────────────────────────────────

  static ExerciseProfile _inferFromKeywords(String name, String lower) {
    final equipment = _detectEquipment(lower);
    final (muscle, secondaries, pattern) = _detectMuscle(lower);
    final isAxial = _detectAxial(lower, pattern, equipment);

    final category = switch (pattern) {
      MovementPattern.cardio    => ExerciseCategory.cardio,
      MovementPattern.isolation => ExerciseCategory.isolation,
      _ => muscle.isNotEmpty ? ExerciseCategory.compound : ExerciseCategory.unknown,
    };

    final fatigueWeight = isAxial ? 0.85
        : category == ExerciseCategory.compound  ? 0.65
        : category == ExerciseCategory.isolation ? 0.35
        : 0.50;

    // Confidence: each detected signal contributes
    double conf = 0.0;
    if (muscle.isNotEmpty)                    conf += 0.35;
    if (pattern != MovementPattern.unknown)   conf += 0.25;
    if (equipment != EquipmentType.unknown)   conf += 0.20;
    conf = conf.clamp(0.0, 0.80);

    return ExerciseProfile(
      canonicalName:    name,
      primaryMuscle:    muscle,
      secondaryMuscles: secondaries,
      movementPattern:  pattern,
      equipment:        equipment,
      axialLoading:     isAxial,
      fatigueWeight:    fatigueWeight,
      category:         category,
      isCustom:         true,
      isEstimated:      muscle.isEmpty,
      confidence:       conf,
    );
  }

  static EquipmentType _detectEquipment(String lower) {
    if (lower.contains('barbell') || lower.startsWith('bb ')) {
      return EquipmentType.barbell;
    }
    if (lower.contains('dumbbell') || lower.contains('dumbell') ||
        lower.startsWith('db ')) {
      return EquipmentType.dumbbell;
    }
    if (lower.contains('cable') || lower.contains('pulley')) {
      return EquipmentType.cable;
    }
    if (lower.contains('machine') || lower.contains('smith') ||
        lower.contains('seated ') || lower.contains('hack')) {
      return EquipmentType.machine;
    }
    if (lower.contains('band') || lower.contains('resistance band')) {
      return EquipmentType.band;
    }
    if (lower.contains('kettlebell') || lower.startsWith('kb ')) {
      return EquipmentType.kettlebell;
    }
    if (lower.contains('push-up') || lower.contains('pushup') ||
        lower.contains('pull-up') || lower.contains('chin-up') ||
        lower.contains('dip') || lower.contains('bodyweight')) {
      return EquipmentType.bodyweight;
    }
    return EquipmentType.unknown;
  }

  // Returns (primaryMuscle, secondaryMuscles, movementPattern)
  static (String, List<String>, MovementPattern) _detectMuscle(String lower) {
    // Hinge / posterior chain
    if (lower.contains('deadlift') || lower.contains('rdl') ||
        lower.contains('stiff leg') || lower.contains('good morning')) {
      return ('back', ['glutes', 'hamstrings'], MovementPattern.hinge);
    }
    // Squat / legs compound
    if (lower.contains('squat') || lower.contains('leg press') ||
        lower.contains('lunge') || lower.contains('split squat') ||
        lower.contains('step up') || lower.contains('hack')) {
      return ('quads', ['glutes', 'hamstrings'], MovementPattern.squat);
    }
    // Hip thrust / glute hinge
    if (lower.contains('hip thrust') || lower.contains('glute bridge')) {
      return ('glutes', ['hamstrings'], MovementPattern.hinge);
    }
    // Chest push
    if ((lower.contains('bench') || lower.contains('pec') ||
         lower.contains('chest press') || lower.contains('chest fly') ||
         lower.contains('flye') || lower.contains(' fly')) &&
        !lower.contains('row')) {
      return ('chest', ['shoulders', 'triceps'],
          lower.contains('fly') || lower.contains('flye')
              ? MovementPattern.isolation
              : MovementPattern.push);
    }
    // Shoulder press / overhead
    if (lower.contains('overhead') || lower.contains('ohp') ||
        lower.contains('military press') || lower.contains('arnold') ||
        (lower.contains('shoulder press'))) {
      return ('shoulders', ['triceps'], MovementPattern.push);
    }
    // Generic press (not leg press) — lean chest / push
    if (lower.contains('press') && !lower.contains('leg press')) {
      if (lower.contains('incline') || lower.contains('decline') ||
          lower.contains('flat')) {
        return ('chest', ['shoulders', 'triceps'], MovementPattern.push);
      }
      return ('shoulders', ['triceps', 'chest'], MovementPattern.push);
    }
    // Row — back pull
    if (lower.contains('row') && !lower.contains('rowing machine')) {
      final axialRow = lower.contains('barbell') || lower.contains('bent over') ||
          lower.contains('pendlay') || lower.contains('t-bar') || lower.contains('tbar');
      return ('back', ['biceps'], axialRow ? MovementPattern.pull : MovementPattern.pull);
    }
    // Pull / pulldown / lat
    if ((lower.contains('pull') && !lower.contains('pull-through') &&
         !lower.contains('cable pull')) ||
        lower.contains('pulldown') || lower.contains('chin') ||
        lower.contains('lat ')) {
      return ('back', ['biceps'], MovementPattern.pull);
    }
    // Curl — biceps
    if (lower.contains('curl') && !lower.contains('leg curl') &&
        !lower.contains('hip') && !lower.contains('lying')) {
      return ('biceps', ['brachialis'], MovementPattern.isolation);
    }
    // Triceps
    if (lower.contains('tricep') || lower.contains('pushdown') ||
        (lower.contains('extension') && !lower.contains('leg extension'))) {
      return ('triceps', [], MovementPattern.isolation);
    }
    // Shoulder isolation
    if (lower.contains('lateral') || lower.contains('front raise') ||
        lower.contains('rear delt') || lower.contains('face pull') ||
        lower.contains('reverse fly')) {
      return ('shoulders', [], MovementPattern.isolation);
    }
    // Leg isolation
    if (lower.contains('leg curl') || lower.contains('hamstring curl')) {
      return ('hamstrings', [], MovementPattern.isolation);
    }
    if (lower.contains('leg extension') || lower.contains('quad extension')) {
      return ('quads', [], MovementPattern.isolation);
    }
    if (lower.contains('calf') || lower.contains('calves')) {
      return ('calves', [], MovementPattern.isolation);
    }
    if (lower.contains('glute') || lower.contains('abduction') ||
        lower.contains('abductor')) {
      return ('glutes', [], MovementPattern.isolation);
    }
    // Core
    if (lower.contains('crunch') || lower.contains('plank') ||
        lower.contains('oblique') || lower.contains('ab ') ||
        lower.contains('core') || lower.contains('sit up') ||
        lower.contains('situp')) {
      return ('core', [], MovementPattern.isolation);
    }
    // Cardio
    if (lower.contains('treadmill') || lower.contains('running') ||
        lower.contains('jogging') || lower.contains('cycling') ||
        lower.contains('bike') || lower.contains('rowing machine') ||
        lower.contains('elliptical') || lower.contains('stair')) {
      return ('cardio', [], MovementPattern.cardio);
    }
    // Named customs — structural pattern hints
    if (lower.contains('t-bar') || lower.contains('tbar')) {
      return ('back', ['biceps'], MovementPattern.pull);
    }
    if (lower.contains('raise')) {
      return ('shoulders', [], MovementPattern.isolation);
    }
    if (lower.contains('pull-through')) {
      return ('back', ['glutes', 'hamstrings'], MovementPattern.hinge);
    }

    return ('', [], MovementPattern.unknown);
  }

  static bool _detectAxial(
    String lower,
    MovementPattern pattern,
    EquipmentType equipment,
  ) {
    // Explicit high-axial exercises
    if (lower.contains('deadlift') || lower.contains('squat') ||
        lower.contains('good morning') || lower.contains('overhead press') ||
        lower.contains('ohp') || lower.contains('military press') ||
        lower.contains('barbell row') || lower.contains('bent over') ||
        lower.contains('pendlay') || lower.contains('t-bar') ||
        lower.contains('tbar')) return true;
    // Machines, cables, and chest-supported movements remove axial stress
    if (equipment == EquipmentType.cable  ||
        equipment == EquipmentType.machine ||
        lower.contains('chest supported') ||
        lower.contains('seated ')         ||
        lower.contains('lying ')) {
      return false;
    }
    // Barbell hinge = axial
    if (pattern == MovementPattern.hinge && equipment == EquipmentType.barbell) {
      return true;
    }
    return false;
  }
}
