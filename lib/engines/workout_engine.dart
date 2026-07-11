
// lib/engines/workout_engine.dart
//
// Elite-level adaptive workout generation engine.
// - Weekly volume control (sets/muscle/week)
// - Movement pattern fatigue tracking
// - RIR-based progression (Renaissance Periodization style)
// - Mesocycle periodization (3 weeks progressive + 1 deload)
// - Weak-muscle prioritization with frequency boost
// - Fatigue-driven exercise pruning
// - Intensity technique injection (dropset, rest-pause, superset)
// - Session duration control (45–70 min)
//
// Pure Dart. No Flutter dependencies.

import 'dart:math';

import '../models/models.dart';
import '../models/workout_log.dart';
import '../utils/id_helper.dart';

// ═══════════════════════════════════════════════════════════════
// ENUMS & TYPES
// ═══════════════════════════════════════════════════════════════
enum TrainingGoal { hypertrophy, strength, fatLoss, general }

enum ExperienceLevel { beginner, intermediate, advanced }

enum SplitType {
  fullBody,
  upper,
  lower,
  push,
  pull,
  legs,
  cardio,
}

enum ExerciseTier { compound, accessory, isolation }

enum IntensityTechnique { none, dropset, restPause, superset }

enum MesoPhase { accumulation, intensification, peak, deload }
enum DifficultyLevel { easy, moderate, hard, elite }

enum SessionFocus { strength, hypertrophy, pump, recovery }

enum PerformanceTrend { improving, stagnant, declining }

class UserProfile {
  final double weight;
  final double height;
  final ExperienceLevel experienceLevel;
  final List<String> injuries;
  final List<String> availableEquipment;

  const UserProfile({
    this.weight = 75,
    this.height = 175,
    this.experienceLevel = ExperienceLevel.intermediate,
    this.injuries = const [],
    this.availableEquipment = const [
      'barbell', 'dumbbell', 'cable', 'machine', 'bodyweight'
    ],
  });

  bool hasInjury(String area) =>
      injuries.any((i) => i.toLowerCase().contains(area.toLowerCase()));

  bool hasEquipment(List<String> required) {
    if (required.isEmpty) return true;
    final avail = availableEquipment.map((e) => e.toLowerCase()).toSet();
    return required.any((r) => avail.contains(r.toLowerCase()));
  }
}
// ═══════════════════════════════════════════════════════════════
// EXERCISE TEMPLATE
// ═══════════════════════════════════════════════════════════════
class _ExerciseTemplate {
  final String name;
  final String muscle;
  final String emoji;
  final ExerciseTier tier;
  final List<String> patterns;
  final bool bodyweight;
  final double baseWeight;
  final List<String> equipment;
  final double fatigueCost;
  final DifficultyLevel difficulty;        // ← ADD
  final List<String> injuryFlags;          // ← ADD (e.g. ['knee','lower_back'])

  const _ExerciseTemplate({
    required this.name,
    required this.muscle,
    required this.emoji,
    required this.tier,
    required this.patterns,
    this.bodyweight = false,
    this.baseWeight = 20,
    this.equipment = const ['barbell'],
    this.fatigueCost = 0.5,
    this.difficulty = DifficultyLevel.moderate,   // ← ADD
    this.injuryFlags = const [],                  // ← ADD
  });

  // Effective fatigue (scaled by difficulty)
  double get effectiveFatigueCost {
    switch (difficulty) {
      case DifficultyLevel.easy:     return fatigueCost * 0.8;
      case DifficultyLevel.moderate: return fatigueCost;
      case DifficultyLevel.hard:     return fatigueCost * 1.15;
      case DifficultyLevel.elite:    return fatigueCost * 1.35;
    }
  }
}
// ═══════════════════════════════════════════════════════════════
// EXERCISE LIBRARY
// ═══════════════════════════════════════════════════════════════
class _Library {
  static const chest = <_ExerciseTemplate>[
    _ExerciseTemplate(
  name: 'Barbell Bench Press',
  muscle: 'chest', emoji: '💪',
  tier: ExerciseTier.compound,
  patterns: ['horizontal_press'],
  baseWeight: 40, fatigueCost: 0.85,
  difficulty: DifficultyLevel.hard,
  equipment: ['barbell'],
  injuryFlags: ['shoulder'],
),

    _ExerciseTemplate(
      name: 'Incline Dumbbell Press',
      muscle: 'chest',
      emoji: '💪',
      tier: ExerciseTier.compound,
      patterns: ['incline_press'],
      baseWeight: 16,
      fatigueCost: 0.7,
    ),
    _ExerciseTemplate(
      name: 'Dumbbell Bench Press',
      muscle: 'chest',
      emoji: '💪',
      tier: ExerciseTier.compound,
      patterns: ['horizontal_press'],
      baseWeight: 18,
      fatigueCost: 0.7,
    ),
    _ExerciseTemplate(
      name: 'Cable Fly',
      muscle: 'chest',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['fly'],
      baseWeight: 10,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Push Up',
      muscle: 'chest',
      emoji: '🤸',
      tier: ExerciseTier.compound,
      patterns: ['horizontal_press'],
      bodyweight: true,
      fatigueCost: 0.45,
    ),
    _ExerciseTemplate(
      name: 'Dips',
      muscle: 'chest',
      emoji: '🤸',
      tier: ExerciseTier.compound,
      patterns: ['vertical_press'],
      bodyweight: true,
      fatigueCost: 0.6,
    ),
  ];

  static const back = <_ExerciseTemplate>[
    _ExerciseTemplate(
      name: 'Barbell Row',
      muscle: 'back',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['horizontal_pull'],
      baseWeight: 35,
      fatigueCost: 0.8,
    ),
    _ExerciseTemplate(
      name: 'Pull Up',
      muscle: 'back',
      emoji: '🤸',
      tier: ExerciseTier.compound,
      patterns: ['vertical_pull'],
      bodyweight: true,
      fatigueCost: 0.7,
    ),
    _ExerciseTemplate(
      name: 'Lat Pulldown',
      muscle: 'back',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['vertical_pull'],
      baseWeight: 30,
      fatigueCost: 0.5,
    ),
    _ExerciseTemplate(
      name: 'Seated Cable Row',
      muscle: 'back',
      emoji: '🚣',
      tier: ExerciseTier.compound,
      patterns: ['horizontal_pull'],
      baseWeight: 30,
      fatigueCost: 0.5,
    ),
    _ExerciseTemplate(
      name: 'Deadlift',
      muscle: 'back',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['hinge'],
      baseWeight: 60,
      fatigueCost: 1.0,
    ),
    _ExerciseTemplate(
      name: 'Face Pull',
      muscle: 'back',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['rear_delt'],
      baseWeight: 12,
      fatigueCost: 0.2,
    ),
  ];

  static const legs = <_ExerciseTemplate>[
    _ExerciseTemplate(
  name: 'Back Squat',
  muscle: 'legs', emoji: '🦵',
  tier: ExerciseTier.compound,
  patterns: ['squat'],
  baseWeight: 50, fatigueCost: 1.0,
  difficulty: DifficultyLevel.elite,
  equipment: ['barbell'],
  injuryFlags: ['knee', 'lower_back'],
),

    _ExerciseTemplate(
      name: 'Front Squat',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.compound,
      patterns: ['squat'],
      baseWeight: 40,
      fatigueCost: 0.95,
    ),
    _ExerciseTemplate(
      name: 'Romanian Deadlift',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.compound,
      patterns: ['hinge'],
      baseWeight: 40,
      fatigueCost: 0.85,
    ),
    _ExerciseTemplate(
      name: 'Leg Press',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.compound,
      patterns: ['squat'],
      baseWeight: 80,
      fatigueCost: 0.7,
    ),
    _ExerciseTemplate(
      name: 'Walking Lunge',
      muscle: 'legs',
      emoji: '🚶',
      tier: ExerciseTier.compound,
      patterns: ['lunge'],
      baseWeight: 14,
      fatigueCost: 0.65,
    ),
    _ExerciseTemplate(
      name: 'Leg Curl',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.isolation,
      patterns: ['hamstring_curl'],
      baseWeight: 20,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Leg Extension',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.isolation,
      patterns: ['quad_extension'],
      baseWeight: 25,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Standing Calf Raise',
      muscle: 'legs',
      emoji: '🦵',
      tier: ExerciseTier.isolation,
      patterns: ['calf'],
      baseWeight: 30,
      fatigueCost: 0.2,
    ),
  ];

  static const shoulders = <_ExerciseTemplate>[
    _ExerciseTemplate(
      name: 'Overhead Press',
      muscle: 'shoulders',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['vertical_press'],
      baseWeight: 25,
      fatigueCost: 0.75,
    ),
    _ExerciseTemplate(
      name: 'Seated Dumbbell Press',
      muscle: 'shoulders',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['vertical_press'],
      baseWeight: 12,
      fatigueCost: 0.6,
    ),
    _ExerciseTemplate(
      name: 'Lateral Raise',
      muscle: 'shoulders',
      emoji: '💪',
      tier: ExerciseTier.isolation,
      patterns: ['lateral_raise'],
      baseWeight: 6,
      fatigueCost: 0.2,
    ),
    _ExerciseTemplate(
      name: 'Cable Lateral Raise',
      muscle: 'shoulders',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['lateral_raise'],
      baseWeight: 5,
      fatigueCost: 0.2,
    ),
    _ExerciseTemplate(
      name: 'Reverse Pec Deck',
      muscle: 'shoulders',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['rear_delt'],
      baseWeight: 12,
      fatigueCost: 0.2,
    ),
  ];

  static const arms = <_ExerciseTemplate>[
    _ExerciseTemplate(
      name: 'Barbell Curl',
      muscle: 'arms',
      emoji: '💪',
      tier: ExerciseTier.isolation,
      patterns: ['biceps_curl'],
      baseWeight: 15,
      fatigueCost: 0.3,
    ),
    _ExerciseTemplate(
      name: 'Hammer Curl',
      muscle: 'arms',
      emoji: '💪',
      tier: ExerciseTier.isolation,
      patterns: ['biceps_curl'],
      baseWeight: 10,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Incline Dumbbell Curl',
      muscle: 'arms',
      emoji: '💪',
      tier: ExerciseTier.isolation,
      patterns: ['biceps_curl'],
      baseWeight: 8,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Tricep Pushdown',
      muscle: 'arms',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['triceps_extension'],
      baseWeight: 15,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Overhead Tricep Extension',
      muscle: 'arms',
      emoji: '💪',
      tier: ExerciseTier.isolation,
      patterns: ['triceps_extension'],
      baseWeight: 10,
      fatigueCost: 0.25,
    ),
    _ExerciseTemplate(
      name: 'Close-Grip Bench Press',
      muscle: 'arms',
      emoji: '🏋️',
      tier: ExerciseTier.compound,
      patterns: ['horizontal_press'],
      baseWeight: 30,
      fatigueCost: 0.65,
    ),
  ];

  static const core = <_ExerciseTemplate>[
    _ExerciseTemplate(
      name: 'Plank',
      muscle: 'core',
      emoji: '🧘',
      tier: ExerciseTier.isolation,
      patterns: ['anti_extension'],
      bodyweight: true,
      fatigueCost: 0.15,
    ),
    _ExerciseTemplate(
      name: 'Hanging Leg Raise',
      muscle: 'core',
      emoji: '🤸',
      tier: ExerciseTier.isolation,
      patterns: ['flexion'],
      bodyweight: true,
      fatigueCost: 0.3,
    ),
    _ExerciseTemplate(
      name: 'Cable Crunch',
      muscle: 'core',
      emoji: '🔗',
      tier: ExerciseTier.isolation,
      patterns: ['flexion'],
      baseWeight: 20,
      fatigueCost: 0.2,
    ),
    _ExerciseTemplate(
      name: 'Russian Twist',
      muscle: 'core',
      emoji: '🤸',
      tier: ExerciseTier.isolation,
      patterns: ['rotation'],
      baseWeight: 5,
      fatigueCost: 0.15,
    ),
  ];

  static List<_ExerciseTemplate> forMuscle(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
        return chest;
      case 'back':
        return back;
      case 'legs':
        return legs;
      case 'shoulders':
        return shoulders;
      case 'arms':
        return arms;
      case 'core':
        return core;
      default:
        return const [];
    }
  }

  static List<_ExerciseTemplate> all() => [
        ...chest,
        ...back,
        ...legs,
        ...shoulders,
        ...arms,
        ...core,
      ];

  static _ExerciseTemplate? findByName(String name) {
    final n = name.toLowerCase().trim();
    for (final t in all()) {
      if (t.name.toLowerCase() == n) return t;
    }
    return null;
  }

  static _ExerciseTemplate? findByKey(String key) {
    for (final t in all()) {
      final k =
          t.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      if (k == key) return t;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
// PRESCRIPTION
// ═══════════════════════════════════════════════════════════════
class _Prescription {
  final int sets;
  final int repsLow;
  final int repsHigh;
  final double rir;
  final int restSec;
  final IntensityTechnique technique;

  const _Prescription({
    required this.sets,
    required this.repsLow,
    required this.repsHigh,
    required this.rir,
    required this.restSec,
    this.technique = IntensityTechnique.none,
  });

  int get repsTarget => ((repsLow + repsHigh) / 2).round();

  _Prescription copyWith({
    int? sets,
    int? repsLow,
    int? repsHigh,
    double? rir,
    int? restSec,
    IntensityTechnique? technique,
  }) =>
      _Prescription(
        sets: sets ?? this.sets,
        repsLow: repsLow ?? this.repsLow,
        repsHigh: repsHigh ?? this.repsHigh,
        rir: rir ?? this.rir,
        restSec: restSec ?? this.restSec,
        technique: technique ?? this.technique,
      );
}

// ═══════════════════════════════════════════════════════════════
// WEEKLY VOLUME REPORT
// ═══════════════════════════════════════════════════════════════
class _VolumeReport {
  final Map<String, int> setsPerMuscle;
  final Map<String, int> patternFreq;
  final int totalSessions;

  const _VolumeReport({
    required this.setsPerMuscle,
    required this.patternFreq,
    required this.totalSessions,
  });

  int sets(String muscle) => setsPerMuscle[muscle.toLowerCase()] ?? 0;
  int pattern(String p) => patternFreq[p] ?? 0;
}

// ═══════════════════════════════════════════════════════════════
// WORKOUT ENGINE
// ═══════════════════════════════════════════════════════════════
class WorkoutEngine {
  WorkoutEngine._();

  static final Random _rng = Random();

  // ───────────────────────────────────────────────────
  // PUBLIC API
  // ───────────────────────────────────────────────────
static DayPlan generateWorkout({
  required String goal,
  required String experienceLevel,
  required int trainingDaysPerWeek,
  required double readiness,
  required double fatigue,
  required bool needsDeload,
  required List<WorkoutLog> logs,
  required String weakMuscle,
  int dayIndex = 0,
  String? splitOverride,
  int targetMinutes = 60,
  UserProfile? profile,                   // ← ADD
}) {
  final user = profile ?? const UserProfile();
  final parsedGoal = _parseGoal(goal);
  final level = _parseLevel(experienceLevel);
  final days = trainingDaysPerWeek.clamp(1, 7);
  final targetMin = targetMinutes.clamp(30, 120);

  // ── Recovery score ──
  final recoveryScore =
      (readiness * 0.6) + ((100 - fatigue) * 0.4);

  // ── Missed workout adaptation ──
  final daysSinceLast = _daysSinceLastWorkout(logs);
  final missedLong = daysSinceLast > 3;

  // ── Phase ──
  var phase = needsDeload ? MesoPhase.deload : _detectMesoPhase(logs);
  if (missedLong && phase == MesoPhase.peak) {
    phase = MesoPhase.intensification;
  }

  // ── Trend ──
  final trend = _computeTrend(logs);

  // ── Reason builder ──
  final reasonParts = <String>[];
  if (phase == MesoPhase.deload) reasonParts.add('Deload week');
  if (recoveryScore < 50) reasonParts.add('Volume reduced (low recovery)');
  if (recoveryScore > 80) reasonParts.add('Volume boost (peak recovery)');
  if (missedLong) reasonParts.add('Reintro after $daysSinceLast d gap');
  if (trend == PerformanceTrend.declining) reasonParts.add('Smart reset');
  final reason = reasonParts.isEmpty ? '' : reasonParts.join(' · ');

  // ── Session focus ──
  final focus = _autoFocus(phase, fatigue, readiness);

  final split = splitOverride != null
      ? _parseSplit(splitOverride)
      : _splitForDay(level, days, dayIndex, parsedGoal, weakMuscle);

  if (phase == MesoPhase.deload) {
    return _buildDeloadPlan(
      split: split, goal: parsedGoal, level: level,
      logs: logs, weakMuscle: weakMuscle,
      profile: user, reason: reason,        // ← pass through
    );
  }

  final report = _computeVolumeReport(logs);
  final lowReadiness = readiness < 40;
  final highFatigue = fatigue > 70;

  var volMult = _volumeMultiplier(
    readiness: readiness, fatigue: fatigue, level: level, phase: phase,
  );
  // recovery score override
  if (recoveryScore < 50) volMult *= 0.85;
  if (recoveryScore > 80) volMult *= 1.05;
  if (missedLong) volMult *= 0.85;
  if (trend == PerformanceTrend.declining) volMult *= 0.9;
  if (trend == PerformanceTrend.improving) volMult *= 1.05;

  DayPlan plan;
  switch (parsedGoal) {
    case TrainingGoal.strength:
      plan = _buildStrengthPlan(
        split: split, level: level, logs: logs,
        weakMuscle: weakMuscle, volumeMultiplier: volMult,
        lowReadiness: lowReadiness, highFatigue: highFatigue,
        report: report, phase: phase,
        profile: user, focus: focus, trend: trend, reason: reason,
      );
      break;
    case TrainingGoal.fatLoss:
      plan = _buildFatLossPlan(
        split: split, level: level, logs: logs,
        weakMuscle: weakMuscle, volumeMultiplier: volMult,
        highFatigue: highFatigue, report: report, phase: phase,
        profile: user, focus: focus, trend: trend, reason: reason,
      );
      break;
    case TrainingGoal.hypertrophy:
    case TrainingGoal.general:
      plan = _buildHypertrophyPlan(
        split: split, level: level, logs: logs,
        weakMuscle: weakMuscle, volumeMultiplier: volMult,
        lowReadiness: lowReadiness, highFatigue: highFatigue,
        report: report, phase: phase,
        profile: user, focus: focus, trend: trend, reason: reason,
      );
      break;
  }

  plan = _enforceSessionDuration(plan, targetMin, level);
  return plan;
  
}

  /// Substitute single exercise within same movement pattern.
  static String? substituteExercise(
    String currentName, {
    List<String> exclude = const [],
  }) {
    final current = _Library.findByName(currentName);
    if (current == null) return null;

    final excludeLc = exclude.map((e) => e.toLowerCase()).toSet()
      ..add(currentName.toLowerCase());

    final candidates = _Library.forMuscle(current.muscle).where((t) {
      if (excludeLc.contains(t.name.toLowerCase())) return false;
      return t.patterns.any(current.patterns.contains);
    }).toList();

    if (candidates.isEmpty) return null;
    return candidates[_rng.nextInt(candidates.length)].name;
  }

  /// RIR-based weight prescription.
  static double suggestNextWeight({
  required String exerciseName,
  required List<WorkoutLog> logs,
  required int targetReps,
  required double targetRir,
  bool plateau = false,
}) {
  final tpl = _Library.findByName(exerciseName);
  final fallback = tpl?.baseWeight ?? 20.0;
  if (tpl?.bodyweight == true) return 0.0;

  final key = exerciseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  final history = logs.where((l) => l.exercise == key && l.weight > 0).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (history.isEmpty) return _roundWeight(fallback);
  if (plateau) return _roundWeight(history.first.weight * 0.90);

  // ── Smoothed: avg of last 3 ──
  final lastN = history.take(3).toList();
  final avgWeight =
      lastN.fold<double>(0, (s, l) => s + l.weight) / lastN.length;
  final avgReps =
      lastN.fold<double>(0, (s, l) => s + l.reps) / lastN.length;

  final estRir = _estimateRir(avgReps.round(), targetReps);

  // Conservative jumps (smoothing)
  final maxIncrease = avgWeight < 40 ? 2.5 : 5.0;
  final smoothBase = (avgWeight * 0.7) + (history.first.weight * 0.3);

  if (estRir <= 0.5 && avgReps >= targetReps) {
    return _roundWeight((smoothBase + maxIncrease).clamp(0, 500));
  }
  if (estRir <= targetRir - 1) {
    return _roundWeight(smoothBase + 2.5);
  }
  if (estRir >= targetRir + 1.5) {
    return _roundWeight(smoothBase - 2.5);
  }
  return _roundWeight(smoothBase);
}

  // ───────────────────────────────────────────────────
  // MESOCYCLE PHASE DETECTION
  // ───────────────────────────────────────────────────
  static MesoPhase _detectMesoPhase(List<WorkoutLog> logs) {
    if (logs.isEmpty) return MesoPhase.accumulation;

    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first.date;
    final now = DateTime.now();
    final daysIn = now.difference(first).inDays;
    if (daysIn < 7) return MesoPhase.accumulation;

    final weekIndex = (daysIn ~/ 7) % 4;
    switch (weekIndex) {
      case 0:
        return MesoPhase.accumulation;
      case 1:
        return MesoPhase.intensification;
      case 2:
        return MesoPhase.peak;
      case 3:
        return MesoPhase.deload;
    }
    return MesoPhase.accumulation;
  }

  // ───────────────────────────────────────────────────
  // WEEKLY VOLUME / PATTERN TRACKING
  // ───────────────────────────────────────────────────
  static _VolumeReport _computeVolumeReport(List<WorkoutLog> logs) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final weekly = logs.where((l) => l.date.isAfter(cutoff)).toList();

    final perMuscle = <String, int>{};
    final perPattern = <String, int>{};
    final sessions = <String>{};

    for (final l in weekly) {
      sessions.add(_dateKey(l.date));
      final tpl = _Library.findByKey(l.exercise);
      final muscle =
          (l.muscleGroup ?? tpl?.muscle ?? '').toLowerCase().trim();
      if (muscle.isNotEmpty) {
        perMuscle[muscle] = (perMuscle[muscle] ?? 0) + 1;
      }
      if (tpl != null) {
        for (final p in tpl.patterns) {
          perPattern[p] = (perPattern[p] ?? 0) + 1;
        }
      }
    }

    return _VolumeReport(
      setsPerMuscle: perMuscle,
      patternFreq: perPattern,
      totalSessions: sessions.length,
    );
  }

  static int _weeklyVolumeTarget(ExperienceLevel level, String muscle) {
    final small =
        muscle == 'arms' || muscle == 'shoulders' || muscle == 'core';
    switch (level) {
      case ExperienceLevel.beginner:
        return small ? 8 : 10;
      case ExperienceLevel.intermediate:
        return small ? 12 : 14;
      case ExperienceLevel.advanced:
        return small ? 16 : 18;
    }
  }

  static double _volumeAdjustmentForMuscle(
    String muscle,
    ExperienceLevel level,
    _VolumeReport report,
  ) {
    final target = _weeklyVolumeTarget(level, muscle);
    final current = report.sets(muscle);
    if (current >= target * 1.25) return 0.6;
    if (current >= target) return 0.85;
    if (current >= target * 0.6) return 1.0;
    if (current >= target * 0.3) return 1.15;
    return 1.25;
  }
static double _rotationScore(
  _ExerciseTemplate tpl,
  Set<String> recentKeys,
  _VolumeReport report,
) {
  double score = 1.0;

  final key = tpl.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  // ❌ recent used → heavy penalty
  if (recentKeys.contains(key)) score *= 0.4;

  // ❌ pattern saturation
  for (final p in tpl.patterns) {
    if (report.pattern(p) > 4) score *= 0.7;
  }

  // ✅ compound priority boost
  if (tpl.tier == ExerciseTier.compound) score *= 1.2;

  return score;
}
  // ───────────────────────────────────────────────────
  // PLAN BUILDERS
  // ───────────────────────────────────────────────────
  static DayPlan _buildHypertrophyPlan({
    required SplitType split,
    required ExperienceLevel level,
    required List<WorkoutLog> logs,
    required String weakMuscle,
    required double volumeMultiplier,
    required bool lowReadiness,
    required bool highFatigue,
    required _VolumeReport report,
    required MesoPhase phase,
    required UserProfile profile,              // ← ADD
  SessionFocus focus = SessionFocus.hypertrophy,  // ← ADD
  PerformanceTrend trend = PerformanceTrend.stagnant,  // ← ADD
  String reason = '', 
  }) {
    final muscles = _orderMuscles(_musclesForSplit(split), weakMuscle);
    final exercises = <PlannedExercise>[];

    for (var idx = 0; idx < muscles.length; idx++) {
      final muscle = muscles[idx];
      final isWeak = _normalize(muscle) == _normalize(weakMuscle);
      final volAdj = _volumeAdjustmentForMuscle(muscle, level, report);

      final base = _hypertrophyVolume(level);
      var setCount = (base * volumeMultiplier * volAdj).round();
      if (isWeak) setCount += level == ExperienceLevel.beginner ? 1 : 2;
      setCount = setCount.clamp(2, 6);

      final selected = _selectExercises(
        muscle: muscle,
        count: _exerciseCount(level, isPrimary: idx == 0),
        logs: logs,
        report: report,
        prioritizeCompound: true,
        skipIsolationIfFatigued: highFatigue,
        profile: profile,
      );

      final perEx = (setCount / max(1, selected.length)).ceil().clamp(2, 5);

      for (var i = 0; i < selected.length; i++) {
        final tpl = selected[i];
        final adj = _focusRepsAdjust(focus);
var pres = _Prescription(
  sets: perEx,
  repsLow: (_phaseRepsLow(phase, tpl.tier, isHypertrophy: true) + adj[0])
      .clamp(3, 30),
  repsHigh: (_phaseRepsHigh(phase, tpl.tier, isHypertrophy: true) + adj[1])
      .clamp(4, 35),
  rir: (_phaseRir(phase, lowReadiness) + adj[2] / 10.0).clamp(0, 5),
  restSec: tpl.tier == ExerciseTier.compound ? 150 : 75,
);

pres = _maybeAddIntensityTechnique(
  pres: pres,
  tpl: tpl,
  fatigue: highFatigue ? 80 : 50,
  isLastExercise: i == selected.length - 1,
  level: level,                              // ← ADD
);

        exercises.add(_buildExercise(tpl, pres, logs));
      }
    }

    return _wrap(split: split, exercises: exercises);
  }

  static DayPlan _buildStrengthPlan({
    required SplitType split,
    required ExperienceLevel level,
    required List<WorkoutLog> logs,
    required String weakMuscle,
    required double volumeMultiplier,
    required bool lowReadiness,
    required bool highFatigue,
    required _VolumeReport report,
    required MesoPhase phase,
    required UserProfile profile,              // ← ADD
  SessionFocus focus = SessionFocus.hypertrophy,  // ← ADD
  PerformanceTrend trend = PerformanceTrend.stagnant,  // ← ADD
  String reason = '', 
  }) {
    final muscles = _orderMuscles(_musclesForSplit(split), weakMuscle);
    final exercises = <PlannedExercise>[];
var eliteCount = 0;                          // ← ADD
const eliteCap = 2;                          // ← ADD
    for (var idx = 0; idx < muscles.length; idx++) {
      final muscle = muscles[idx];
      final isPrimary = idx == 0;

      final selected = _selectExercises(
        muscle: muscle,
        count: isPrimary ? 2 : 1,
        logs: logs,
        report: report,
        prioritizeCompound: true,
        skipIsolationIfFatigued: highFatigue,
        profile: profile,
      );

      for (var i = 0; i < selected.length; i++) {
  final tpl = selected[i];
  final isCompound = tpl.tier == ExerciseTier.compound;

  final isMain = i == 0 && isCompound;

var pres = _Prescription(
  sets: ((3 * volumeMultiplier).round())
      .clamp(2, highFatigue ? 3 : 5),
  repsLow: isMain ? 3 : 5,
  repsHigh: isMain ? 5 : 8,
  rir: isMain ? 1.0 : 1.5,
  restSec: isMain ? 240 : 150,
);

  // Force superset on non-compound paired, no random
  if (!isCompound && !highFatigue && i.isOdd) {
    pres = pres.copyWith(technique: IntensityTechnique.superset);
  }

  if (tpl.difficulty == DifficultyLevel.elite) {
    if (eliteCount >= eliteCap) {
      pres = pres.copyWith(sets: (pres.sets - 1).clamp(2, 6));
    }
    eliteCount++;
  }

  exercises.add(_buildExercise(tpl, pres, logs));
}
    }

   return _wrap(split: split, exercises: exercises, reason: reason);
  }

  static DayPlan _buildFatLossPlan({
    required SplitType split,
    required ExperienceLevel level,
    required List<WorkoutLog> logs,
    required String weakMuscle,
    required double volumeMultiplier,
    required bool highFatigue,
    required _VolumeReport report,
    required MesoPhase phase,
    required UserProfile profile,              // ← ADD
  SessionFocus focus = SessionFocus.hypertrophy,  // ← ADD
  PerformanceTrend trend = PerformanceTrend.stagnant,  // ← ADD
  String reason = '', 
  }) {
    final muscles = _orderMuscles(_musclesForSplit(split), weakMuscle);
    final exercises = <PlannedExercise>[];
var eliteCount = 0;                          // ← ADD
const eliteCap = 2;                          // ← ADD
    for (final muscle in muscles) {
      final selected = _selectExercises(
        muscle: muscle,
        count: 2,
        logs: logs,
        report: report,
        prioritizeCompound: true,
        skipIsolationIfFatigued: highFatigue,
        profile: profile,
      );

      for (var i = 0; i < selected.length; i++) {
        final tpl = selected[i];

        var pres = _Prescription(
          sets: ((3 * volumeMultiplier).round())
              .clamp(2, highFatigue ? 3 : 4),
          repsLow: 12,
          repsHigh: 20,
          rir: 1.5,
          restSec: 60,
        );
if (tpl.difficulty == DifficultyLevel.elite) {
  if (eliteCount >= eliteCap) {
    pres = pres.copyWith(sets: (pres.sets - 1).clamp(2, 6));
  }
  eliteCount++;
}

if (!highFatigue && i.isOdd) {
  pres = pres.copyWith(technique: IntensityTechnique.superset);
}

        exercises.add(_buildExercise(tpl, pres, logs));
      }
    }

    if (split != SplitType.cardio) {
      final coreSel = _selectExercises(
        muscle: 'core',
        count: 1,
        logs: logs,
        report: report,
        prioritizeCompound: false,
        skipIsolationIfFatigued: false,
        profile: profile,
      );
      for (final tpl in coreSel) {
        exercises.add(_buildExercise(
          tpl,
          const _Prescription(
            sets: 3,
            repsLow: 12,
            repsHigh: 20,
            rir: 1,
            restSec: 45,
          ),
          logs,
        ));
      }
    }

    return _wrap(split: split, exercises: exercises);
  }

  static DayPlan _buildDeloadPlan({
    required SplitType split,
    required TrainingGoal goal,
    required ExperienceLevel level,
    required List<WorkoutLog> logs,
    required String weakMuscle,
    required UserProfile profile,              // ← ADD
  String reason = '',
  }) {
    final muscles = _musclesForSplit(split);
    final exercises = <PlannedExercise>[];

    for (final muscle in muscles) {
      final selected = _selectExercises(
        muscle: muscle,
        count: 1,
        logs: logs,
        report: const _VolumeReport(
          setsPerMuscle: {},
          patternFreq: {},
          totalSessions: 0,
        ),
        prioritizeCompound: true,
        skipIsolationIfFatigued: true,
        profile: profile,
      );
      for (final tpl in selected) {
        const pres = _Prescription(
          sets: 2,
          repsLow: 6,
          repsHigh: 10,
          rir: 4,
          restSec: 120,
        );
        exercises.add(_buildExercise(tpl, pres, logs, deload: true));
      }
    }

   return _wrap(
  split: split,
  exercises: exercises,
  titleOverride: 'Deload — ${_titleForSplit(split)}',
  reason: reason,                            // ← ADD
);
  }

  // ───────────────────────────────────────────────────
  // EXERCISE SELECTION
  // ───────────────────────────────────────────────────
  static List<_ExerciseTemplate> _selectExercises({
  required String muscle,
  required int count,
  required List<WorkoutLog> logs,
  required _VolumeReport report,
  required bool prioritizeCompound,
  required bool skipIsolationIfFatigued,
  required UserProfile profile,
  }) {
    var pool = List<_ExerciseTemplate>.from(_Library.forMuscle(muscle));
    if (pool.isEmpty) return const [];

    if (skipIsolationIfFatigued) {
      final filtered = pool
          .where((t) => t.tier != ExerciseTier.isolation)
          .toList();
      if (filtered.isNotEmpty) pool = filtered;
    }

    pool = pool.where((t) {
  if (!profile.hasEquipment(t.equipment)) return false;
  for (final flag in t.injuryFlags) {
    if (profile.hasInjury(flag)) return false;
  }
  return true;
}).toList();

if (pool.isEmpty) {
  pool = List<_ExerciseTemplate>.from(_Library.forMuscle(muscle));
}

    final recentNames = _recentExerciseNames(logs, days: 7);
    final overusedKeys = recentNames
        .map((n) => n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'))
        .toSet();

   pool.sort((a, b) {
  double aScore = _rotationScore(a, overusedKeys, report);
  double bScore = _rotationScore(b, overusedKeys, report);

  // ✅ keep compound priority (old logic merged)
  if (prioritizeCompound) {
    if (a.tier == ExerciseTier.compound) aScore *= 1.2;
    if (b.tier == ExerciseTier.compound) bScore *= 1.2;
  }

  return bScore.compareTo(aScore); // higher score first
});
    final picked = <_ExerciseTemplate>[];
    final usedPatterns = <String>{};

    for (final tpl in pool) {
      if (picked.length >= count) break;
      final overlap = tpl.patterns.any(usedPatterns.contains);
      if (overlap && picked.isNotEmpty) continue;
      picked.add(tpl);
      usedPatterns.addAll(tpl.patterns);
    }

    if (picked.length < count) {
      for (final tpl in pool) {
        if (picked.length >= count) break;
        if (!picked.contains(tpl)) picked.add(tpl);
      }
    }

    if (picked.length > 1 && _rng.nextDouble() < 0.20) {
      final compoundFirst = picked.first;
      final tail = picked.sublist(1)..shuffle(_rng);
      return [compoundFirst, ...tail];
    }

    return picked;
  }

  // ───────────────────────────────────────────────────
  // INTENSITY TECHNIQUES
  // ───────────────────────────────────────────────────
  static _Prescription _maybeAddIntensityTechnique({
  required _Prescription pres,
  required _ExerciseTemplate tpl,
  required double fatigue,
  required bool isLastExercise,
  required ExperienceLevel level,
}) {
  // Strict gates — no randomness
  if (level != ExperienceLevel.advanced) return pres;
  if (fatigue >= 60) return pres;
  if (!isLastExercise) return pres;
  if (tpl.tier == ExerciseTier.compound) return pres;

  // Deterministic: compound→none, isolation→dropset, accessory→rest-pause
  if (tpl.tier == ExerciseTier.isolation) {
    return pres.copyWith(technique: IntensityTechnique.dropset);
  }
  return pres.copyWith(technique: IntensityTechnique.restPause);
}

  // ───────────────────────────────────────────────────
  // EXERCISE BUILDING
  // ───────────────────────────────────────────────────
  static PlannedExercise _buildExercise(
    _ExerciseTemplate tpl,
    _Prescription pres,
    List<WorkoutLog> logs, {
    bool deload = false,
  }) {
    final targetReps = pres.repsTarget;

    final weight = tpl.bodyweight
        ? 0.0
        : suggestNextWeight(
            exerciseName: tpl.name,
            logs: logs,
            targetReps: targetReps,
            targetRir: pres.rir,
          );

    final actualWeight = deload ? _roundWeight(weight * 0.55) : weight;
    final baseId =
        tpl.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final type = pres.technique == IntensityTechnique.none
        ? tpl.tier.name
        : '${tpl.tier.name}+${pres.technique.name}';

    return PlannedExercise(
      id: IdHelper.uuid(),
      baseId: baseId,
      name: tpl.name,
      category: _capitalize(tpl.muscle),
      emoji: tpl.emoji,
      type: type,
      unit: tpl.bodyweight ? 'reps' : 'kg',
      bodyweight: tpl.bodyweight,
      sets: List.generate(
        pres.sets,
        (int _) => ExSet(
          id: IdHelper.uuid(),
          reps: targetReps.clamp(1, 50),
          weight: actualWeight.clamp(0, 500),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────
  // SESSION DURATION CONTROL
  // ───────────────────────────────────────────────────
  static DayPlan _enforceSessionDuration(
    DayPlan plan,
    int targetMinutes,
    ExperienceLevel level,
  ) {
    if (plan.exercises.isEmpty) return plan;

    final estMin = _estimateDurationMinutes(plan);
    if (estMin <= targetMinutes + 10) return plan;

    final sortedByPriority = List<PlannedExercise>.from(plan.exercises);
    sortedByPriority.sort((a, b) {
      final at = _isCompoundType(a.type) ? 0 : 1;
      final bt = _isCompoundType(b.type) ? 0 : 1;
      return at - bt;
    });

    final keep = <PlannedExercise>[];
    var minutes = 0.0;
    for (final ex in sortedByPriority) {
      final cost = _exerciseDurationMinutes(ex);
      if (minutes + cost > targetMinutes + 5 && keep.length >= 4) continue;
      keep.add(ex);
      minutes += cost;
    }

    final reordered = <PlannedExercise>[];
    for (final ex in plan.exercises) {
      if (keep.contains(ex)) reordered.add(ex);
    }

    return DayPlan(
      id: plan.id,
      dayIndex: plan.dayIndex,
      title: plan.title,
      exercises: reordered,
      isRestDay: reordered.isEmpty,
    );
  }

  static double _estimateDurationMinutes(DayPlan plan) {
    var total = 0.0;
    for (final ex in plan.exercises) {
      total += _exerciseDurationMinutes(ex);
    }
    return total + 5; // warmup buffer
  }

  static double _exerciseDurationMinutes(PlannedExercise ex) {
    final isCompound = _isCompoundType(ex.type);
    final restSec = isCompound ? 150 : 75;
    final perSetSec = 35 + restSec;
    return (ex.sets.length * perSetSec) / 60.0;
  }

  static bool _isCompoundType(String type) =>
      type.toLowerCase().contains('compound');

  // ───────────────────────────────────────────────────
  // SPLIT LOGIC
  // ───────────────────────────────────────────────────
  static SplitType _splitForDay(
    ExperienceLevel level,
    int daysPerWeek,
    int dayIndex,
    TrainingGoal goal,
    String weakMuscle,
  ) {
    final i = dayIndex.clamp(0, 6);

    if (level == ExperienceLevel.beginner || daysPerWeek <= 3) {
      return SplitType.fullBody;
    }

    if (daysPerWeek == 4) {
      const rotation = [
        SplitType.upper,
        SplitType.lower,
        SplitType.upper,
        SplitType.lower,
      ];
      return rotation[i % rotation.length];
    }

    if (daysPerWeek == 5) {
      const rotation = [
        SplitType.push,
        SplitType.pull,
        SplitType.legs,
        SplitType.upper,
        SplitType.lower,
      ];
      return rotation[i % rotation.length];
    }

    const ppl = [
      SplitType.push,
      SplitType.pull,
      SplitType.legs,
      SplitType.push,
      SplitType.pull,
      SplitType.legs,
    ];
    return ppl[i % ppl.length];
  }

  static List<String> _musclesForSplit(SplitType s) {
    switch (s) {
      case SplitType.fullBody:
        return const ['legs', 'chest', 'back', 'shoulders', 'core'];
      case SplitType.upper:
        return const ['chest', 'back', 'shoulders', 'arms'];
      case SplitType.lower:
        return const ['legs', 'core'];
      case SplitType.push:
        return const ['chest', 'shoulders', 'arms'];
      case SplitType.pull:
        return const ['back', 'arms'];
      case SplitType.legs:
        return const ['legs', 'core'];
      case SplitType.cardio:
        return const ['core'];
    }
  }

  static List<String> _orderMuscles(
    List<String> muscles,
    String weakMuscle,
  ) {
    final wm = _normalize(weakMuscle);
    if (wm.isEmpty) return muscles;
    final ordered = List<String>.from(muscles);
    final idx = ordered.indexWhere((m) => _normalize(m) == wm);
    if (idx > 0) {
      final w = ordered.removeAt(idx);
      ordered.insert(0, w);
    }
    return ordered;
  }

  static String _titleForSplit(SplitType s) {
    switch (s) {
      case SplitType.fullBody:
        return 'Full Body';
      case SplitType.upper:
        return 'Upper Body';
      case SplitType.lower:
        return 'Lower Body';
      case SplitType.push:
        return 'Push Day';
      case SplitType.pull:
        return 'Pull Day';
      case SplitType.legs:
        return 'Legs Day';
      case SplitType.cardio:
        return 'Conditioning';
    }
  }

  // ───────────────────────────────────────────────────
  // VOLUME / REP / RIR HELPERS
  // ───────────────────────────────────────────────────
  static int _hypertrophyVolume(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return 3;
      case ExperienceLevel.intermediate:
        return 4;
      case ExperienceLevel.advanced:
        return 5;
    }
  }

  static int _exerciseCount(
    ExperienceLevel level, {
    required bool isPrimary,
  }) {
    switch (level) {
      case ExperienceLevel.beginner:
        return isPrimary ? 2 : 1;
      case ExperienceLevel.intermediate:
        return isPrimary ? 3 : 2;
      case ExperienceLevel.advanced:
        return isPrimary ? 3 : 2;
    }
  }

  static double _volumeMultiplier({
    required double readiness,
    required double fatigue,
    required ExperienceLevel level,
    required MesoPhase phase,
  }) {
    var m = 1.0;

    if (readiness < 40) {
      m *= 0.75;
    } else if (readiness < 60) {
      m *= 0.90;
    } else if (readiness > 85) {
      m *= 1.05;
    }

    if (fatigue > 80) {
      m *= 0.70;
    } else if (fatigue > 65) {
      m *= 0.85;
    } else if (fatigue < 30) {
      m *= 1.05;
    }

    switch (phase) {
      case MesoPhase.accumulation:
        m *= 1.0;
        break;
      case MesoPhase.intensification:
        m *= 1.05;
        break;
      case MesoPhase.peak:
        m *= 0.90;
        break;
      case MesoPhase.deload:
        m *= 0.55;
        break;
    }

    if (level == ExperienceLevel.beginner) {
      m = m.clamp(0.7, 1.0);
    } else {
      m = m.clamp(0.5, 1.20);
    }
    return m;
  }

  static int _phaseRepsLow(
    MesoPhase phase,
    ExerciseTier tier, {
    required bool isHypertrophy,
  }) {
    if (!isHypertrophy) return tier == ExerciseTier.compound ? 3 : 5;
    switch (phase) {
      case MesoPhase.accumulation:
        return tier == ExerciseTier.compound ? 8 : 10;
      case MesoPhase.intensification:
        return tier == ExerciseTier.compound ? 6 : 8;
      case MesoPhase.peak:
        return tier == ExerciseTier.compound ? 4 : 6;
      case MesoPhase.deload:
        return tier == ExerciseTier.compound ? 6 : 8;
    }
  }

  static int _phaseRepsHigh(
    MesoPhase phase,
    ExerciseTier tier, {
    required bool isHypertrophy,
  }) {
    if (!isHypertrophy) return tier == ExerciseTier.compound ? 5 : 8;
    switch (phase) {
      case MesoPhase.accumulation:
        return tier == ExerciseTier.compound ? 12 : 15;
      case MesoPhase.intensification:
        return tier == ExerciseTier.compound ? 10 : 12;
      case MesoPhase.peak:
        return tier == ExerciseTier.compound ? 6 : 10;
      case MesoPhase.deload:
        return tier == ExerciseTier.compound ? 10 : 12;
    }
  }
static int _daysSinceLastWorkout(List<WorkoutLog> logs) {
  if (logs.isEmpty) return 0;
  final sorted = List<WorkoutLog>.from(logs)
    ..sort((a, b) => b.date.compareTo(a.date));
  return DateTime.now().difference(sorted.first.date).inDays;
}

static SessionFocus _autoFocus(
  MesoPhase phase, double fatigue, double readiness,
) {
  if (fatigue > 75 || readiness < 40) return SessionFocus.recovery;
  switch (phase) {
    case MesoPhase.peak:           return SessionFocus.strength;
    case MesoPhase.intensification:return SessionFocus.hypertrophy;
    case MesoPhase.accumulation:   return SessionFocus.pump;
    case MesoPhase.deload:         return SessionFocus.recovery;
  }
}

static PerformanceTrend _computeTrend(List<WorkoutLog> logs) {
  if (logs.length < 6) return PerformanceTrend.stagnant;
  final sorted = List<WorkoutLog>.from(logs)
    ..sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(3)
      .fold<double>(0, (s, l) => s + l.weight * (l.reps == 0 ? 1 : l.reps));
  final older = sorted.skip(3).take(3)
      .fold<double>(0, (s, l) => s + l.weight * (l.reps == 0 ? 1 : l.reps));
  if (older <= 0) return PerformanceTrend.stagnant;
  final ratio = recent / older;
  if (ratio > 1.05) return PerformanceTrend.improving;
  if (ratio < 0.92) return PerformanceTrend.declining;
  return PerformanceTrend.stagnant;
}

static List<int> _focusRepsAdjust(SessionFocus f) {
  // returns [repLowDelta, repHighDelta, rirDelta*10]
  switch (f) {
    case SessionFocus.strength:    return [-2, -2, -5];
    case SessionFocus.hypertrophy: return [0, 0, 0];
    case SessionFocus.pump:        return [2, 3, -5];
    case SessionFocus.recovery:    return [1, 2, 10];
  }
}
  static double _phaseRir(MesoPhase phase, bool lowReadiness) {
    var rir = 1.5;
    switch (phase) {
      case MesoPhase.accumulation:
        rir = 2.5;
        break;
      case MesoPhase.intensification:
        rir = 1.5;
        break;
      case MesoPhase.peak:
        rir = 0.5;
        break;
      case MesoPhase.deload:
        rir = 4.0;
        break;
    }
    if (lowReadiness) rir += 1.0;
    return rir.clamp(0.0, 5.0);
  }

  static double _estimateRir(int actualReps, int targetReps) {
    final diff = actualReps - targetReps;
    if (diff >= 3) return 0;
    if (diff >= 1) return 1;
    if (diff == 0) return 1.5;
    if (diff == -1) return 2.5;
    return 4.0;
  }

  // ───────────────────────────────────────────────────
  // UTIL
  // ───────────────────────────────────────────────────
  static DayPlan _wrap({
  required SplitType split,
  required List<PlannedExercise> exercises,
  String? titleOverride,
  String reason = '',                     // ← ADD
}) {
  final baseTitle = titleOverride ?? _titleForSplit(split);
  final fullTitle = reason.isEmpty ? baseTitle : '$baseTitle • $reason';
  return DayPlan(
    id: IdHelper.uuid(),
    dayIndex: 0,
    title: fullTitle,
    exercises: exercises,
    isRestDay: exercises.isEmpty,
  );
}
  static List<String> _recentExerciseNames(
    List<WorkoutLog> logs, {
    required int days,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return logs
        .where((l) => l.date.isAfter(cutoff))
        .map((l) => l.exercise)
        .toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static double _roundWeight(double w) {
    if (w <= 0) return 0;
    final rounded = (w / 2.5).round() * 2.5;
    return rounded.clamp(0, 500).toDouble();
  }

  static String _normalize(String s) => s.toLowerCase().trim();

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static TrainingGoal _parseGoal(String g) {
    switch (g.toLowerCase().trim()) {
      case 'strength':
        return TrainingGoal.strength;
      case 'fat_loss':
      case 'fatloss':
      case 'cut':
        return TrainingGoal.fatLoss;
      case 'muscle_gain':
      case 'hypertrophy':
      case 'bulk':
        return TrainingGoal.hypertrophy;
      default:
        return TrainingGoal.general;
    }
  }

  static ExperienceLevel _parseLevel(String l) {
    switch (l.toLowerCase().trim()) {
      case 'advanced':
      case 'elite':
        return ExperienceLevel.advanced;
      case 'intermediate':
        return ExperienceLevel.intermediate;
      default:
        return ExperienceLevel.beginner;
    }
  }

  static SplitType _parseSplit(String s) {
    switch (s.toLowerCase().trim()) {
      case 'push':
        return SplitType.push;
      case 'pull':
        return SplitType.pull;
      case 'legs':
        return SplitType.legs;
      case 'upper':
        return SplitType.upper;
      case 'lower':
        return SplitType.lower;
      case 'cardio':
        return SplitType.cardio;
      default:
        return SplitType.fullBody;
    }
  }
}
