// lib/models/athlete_memory.dart
// Long-term athlete profile that persists across sessions.
// Built from workout logs + history — never from user self-report.
// All fields are derived from observed behavior.

// ════════════════════════════════════════════
// COACHING TONE
// ════════════════════════════════════════════
enum CoachTone {
  elite,        // confident, high-level insight — advanced athletes
  aggressive,   // push hard, no-fluff — PR-driven, motivated
  disciplined,  // accountability-focused — inconsistent users
  scientific,   // evidence-based, measured — intermediate, analytical
  supportive,   // direct but encouraging — beginners
}

extension CoachToneLabel on CoachTone {
  String get name {
    switch (this) {
      case CoachTone.elite:        return 'elite';
      case CoachTone.aggressive:   return 'aggressive';
      case CoachTone.disciplined:  return 'disciplined';
      case CoachTone.scientific:   return 'scientific';
      case CoachTone.supportive:   return 'supportive';
    }
  }

  static CoachTone fromName(String name) {
    return CoachTone.values.firstWhere(
      (t) => t.name == name,
      orElse: () => CoachTone.scientific,
    );
  }

  // Tone derivation rules (called by AthleteProfileService)
  static CoachTone select({
    required String level,
    required int    age,
    required int    consistencyScore,
    required int    totalWorkouts,
    required List<String> motivationalTriggers,
  }) {
    // Low consistency overrides everything — accountability first
    if (consistencyScore < 50 || totalWorkouts < 10) return CoachTone.disciplined;

    // True beginners need clarity, not pressure
    if (totalWorkouts < 20) return CoachTone.supportive;

    // Older athletes respond better to evidence + recovery framing
    if (age > 40) return CoachTone.scientific;

    // PR-driven + experienced = aggressive tone lands well
    if (motivationalTriggers.contains('pr_progress') && totalWorkouts > 50) {
      return CoachTone.aggressive;
    }

    // Advanced athletes: elite tone
    if (level == 'advanced') return CoachTone.elite;

    // Default for intermediate
    return CoachTone.scientific;
  }
}

// ════════════════════════════════════════════
// ATHLETE MEMORY
// ════════════════════════════════════════════
class AthleteMemory {
  final String favoriteLift;        // most frequently logged exercise
  final String weakestMuscle;       // least trained in logs
  final String strongestMuscle;     // most trained in logs
  final int    consistencyScore;    // 0–100, % of planned sessions completed (30 days)
  final int    missedWorkoutsLast30;
  final double avgWeeklyVolume;     // rolling 4-week average (kg)
  final String fatiguePattern;      // see constants below
  final List<String>         motivationalTriggers; // what drives consistency
  final Map<String, int>     muscleFrequency;      // muscle → sessions/30 days
  final Map<String, String>  topicCooldown;        // topic key → ISO date last shown
  final DateTime             updatedAt;

  // ── Long-term memory fields (Phase 5) ────────────────────
  final int          bestMomentumScore;        // 0–100, historical peak
  final int          longestConsistencyPhase;  // max consecutive training days
  final List<String> motivationSpikeExercises; // exercises logged when PRs happened
  final int          fatigueCollapseAfterDays; // typical days before momentum drops (-1 = unknown)

  // fatiguePattern constants
  static const String patternRecoversFast       = 'recovers_fast';
  static const String patternFatiguesAfter3Days = 'fatigues_after_3_days';
  static const String patternHighVolumeTolerant = 'high_volume_tolerant';
  static const String patternNormal             = 'normal';

  // motivationalTrigger constants
  static const String triggerPR             = 'pr_progress';
  static const String triggerStreaks        = 'streaks';
  static const String triggerStrength       = 'strength_numbers';
  static const String triggerVolumeGrowth   = 'volume_growth';
  static const String triggerConsistency    = 'consistency';

  const AthleteMemory({
    this.favoriteLift      = '',
    this.weakestMuscle     = '',
    this.strongestMuscle   = '',
    this.consistencyScore  = 70,
    this.missedWorkoutsLast30 = 0,
    this.avgWeeklyVolume   = 0.0,
    this.fatiguePattern    = patternNormal,
    this.motivationalTriggers = const [triggerConsistency],
    this.muscleFrequency   = const {},
    this.topicCooldown     = const {},
    required this.updatedAt,
    this.bestMomentumScore        = 0,
    this.longestConsistencyPhase  = 0,
    this.motivationSpikeExercises = const [],
    this.fatigueCollapseAfterDays = -1,
  });

  // ── Cooldown logic ────────────────────────────────────────
  Set<String> cooldownTopics({int cooldownDays = 3}) {
    final cutoff = DateTime.now().subtract(Duration(days: cooldownDays));
    return topicCooldown.entries
        .where((e) {
          final d = DateTime.tryParse(e.value);
          return d != null && d.isAfter(cutoff);
        })
        .map((e) => e.key)
        .toSet();
  }

  AthleteMemory withTopicUsed(String topic) {
    final updated = Map<String, String>.from(topicCooldown)
      ..[topic] = DateTime.now().toIso8601String();
    return copyWith(topicCooldown: updated);
  }

  // ── JSON ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'favoriteLift':               favoriteLift,
    'weakestMuscle':              weakestMuscle,
    'strongestMuscle':            strongestMuscle,
    'consistencyScore':           consistencyScore,
    'missedWorkoutsLast30':       missedWorkoutsLast30,
    'avgWeeklyVolume':            avgWeeklyVolume,
    'fatiguePattern':             fatiguePattern,
    'motivationalTriggers':       motivationalTriggers,
    'muscleFrequency':            muscleFrequency,
    'topicCooldown':              topicCooldown,
    'updatedAt':                  updatedAt.toIso8601String(),
    'bestMomentumScore':          bestMomentumScore,
    'longestConsistencyPhase':    longestConsistencyPhase,
    'motivationSpikeExercises':   motivationSpikeExercises,
    'fatigueCollapseAfterDays':   fatigueCollapseAfterDays,
  };

  factory AthleteMemory.fromJson(Map<String, dynamic> j) => AthleteMemory(
    favoriteLift:     j['favoriteLift']    as String? ?? '',
    weakestMuscle:    j['weakestMuscle']   as String? ?? '',
    strongestMuscle:  j['strongestMuscle'] as String? ?? '',
    consistencyScore: j['consistencyScore'] as int? ?? 70,
    missedWorkoutsLast30: j['missedWorkoutsLast30'] as int? ?? 0,
    avgWeeklyVolume:  (j['avgWeeklyVolume'] as num?)?.toDouble() ?? 0.0,
    fatiguePattern:   j['fatiguePattern']  as String? ?? patternNormal,
    motivationalTriggers: List<String>.from(
        (j['motivationalTriggers'] as List?) ?? [triggerConsistency]),
    muscleFrequency: Map<String, int>.from(
        (j['muscleFrequency'] as Map?) ?? {}),
    topicCooldown: Map<String, String>.from(
        (j['topicCooldown'] as Map?) ?? {}),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
    bestMomentumScore:        j['bestMomentumScore']        as int? ?? 0,
    longestConsistencyPhase:  j['longestConsistencyPhase']  as int? ?? 0,
    motivationSpikeExercises: List<String>.from(
        (j['motivationSpikeExercises'] as List?) ?? []),
    fatigueCollapseAfterDays: j['fatigueCollapseAfterDays'] as int? ?? -1,
  );

  AthleteMemory copyWith({
    String?            favoriteLift,
    String?            weakestMuscle,
    String?            strongestMuscle,
    int?               consistencyScore,
    int?               missedWorkoutsLast30,
    double?            avgWeeklyVolume,
    String?            fatiguePattern,
    List<String>?      motivationalTriggers,
    Map<String, int>?  muscleFrequency,
    Map<String, String>? topicCooldown,
    DateTime?          updatedAt,
    int?               bestMomentumScore,
    int?               longestConsistencyPhase,
    List<String>?      motivationSpikeExercises,
    int?               fatigueCollapseAfterDays,
  }) => AthleteMemory(
    favoriteLift:              favoriteLift              ?? this.favoriteLift,
    weakestMuscle:             weakestMuscle             ?? this.weakestMuscle,
    strongestMuscle:           strongestMuscle           ?? this.strongestMuscle,
    consistencyScore:          consistencyScore          ?? this.consistencyScore,
    missedWorkoutsLast30:      missedWorkoutsLast30      ?? this.missedWorkoutsLast30,
    avgWeeklyVolume:           avgWeeklyVolume           ?? this.avgWeeklyVolume,
    fatiguePattern:            fatiguePattern            ?? this.fatiguePattern,
    motivationalTriggers:      motivationalTriggers      ?? List.of(this.motivationalTriggers),
    muscleFrequency:           muscleFrequency           ?? Map.of(this.muscleFrequency),
    topicCooldown:             topicCooldown             ?? Map.of(this.topicCooldown),
    updatedAt:                 updatedAt                 ?? this.updatedAt,
    bestMomentumScore:         bestMomentumScore         ?? this.bestMomentumScore,
    longestConsistencyPhase:   longestConsistencyPhase   ?? this.longestConsistencyPhase,
    motivationSpikeExercises:  motivationSpikeExercises  ?? List.of(this.motivationSpikeExercises),
    fatigueCollapseAfterDays:  fatigueCollapseAfterDays  ?? this.fatigueCollapseAfterDays,
  );
}
