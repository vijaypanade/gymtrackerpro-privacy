// lib/services/ai_engine.dart — v7.1 ELITE PRODUCTION
// Recovery ownership moved to AppProvider (single source of truth)
// getAllMuscleRecovery / getMuscleRecoveryScore removed from here

import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import '../data/exercise_data.dart';
import '../models/models.dart';
import '../models/split_template.dart';
import '../models/workout_log.dart';
import 'exercise_intelligence.dart';
import 'split_recommendation_engine.dart';

// ═══════════════════════════════════════════════════════════════
// WORKOUT CLASSIFIER — Exercise name → type/muscle auto-detect
// ═══════════════════════════════════════════════════════════════
class WorkoutClassifier {
  WorkoutClassifier._();

  static const _pushKeywords = [
    'bench', 'chest fly', 'fly', 'flye', 'pec', 'push-up', 'push up',
    'dip', 'incline press', 'decline press', 'chest press', 'machine press',
    'cable crossover', 'shoulder press', 'overhead press', 'ohp', 'arnold',
    'lateral raise', 'front raise', 'upright row', 'machine shoulder',
    'tricep', 'triceps', 'pushdown', 'skull crusher', 'close grip bench',
    'overhead extension', 'kickback', 'rope pushdown',
  ];

  static const _pullKeywords = [
    'pull-up', 'pullup', 'pull up', 'chin-up', 'chinup', 'chin up',
    'lat pulldown', 'pulldown', 'barbell row', 'dumbbell row', 't-bar row',
    'seated row', 'cable row', 'machine row', 'straight arm pulldown',
    'face pull', 'rear delt', 'reverse fly',
    'bicep curl', 'barbell curl', 'dumbbell curl', 'hammer curl',
    'ez bar curl', 'preacher curl', 'concentration curl', 'cable curl',
    'incline curl',
  ];

  static const _legsKeywords = [
    'squat', 'leg press', 'lunge', 'leg extension', 'leg curl',
    'seated leg curl', 'standing calf', 'seated calf', 'calf raise',
    'hack squat', 'goblet squat', 'split squat', 'bulgarian',
    'hip thrust', 'glute bridge', 'box jump', 'step up',
    'walking lunge', 'sumo squat',
  ];

  static const _deadliftLegs = [
    'romanian deadlift', 'rdl', 'stiff leg', 'sumo deadlift',
  ];
  static const _deadliftPull = [
    'barbell deadlift', 'conventional deadlift', 'trap bar deadlift',
  ];

  static const _coreKeywords = [
    'plank', 'crunch', 'sit-up', 'sit up', 'situp',
    'leg raise', 'hanging leg', 'ab wheel', 'cable crunch',
    'russian twist', 'decline sit', 'core', ' abs',
  ];

  static String classifyExercise(String name) {
    final n = name.toLowerCase().trim();

    for (final kw in _deadliftLegs) { if (n.contains(kw)) return 'legs'; }
    for (final kw in _deadliftPull) { if (n.contains(kw)) return 'pull'; }
    if (n == 'deadlift' || n.contains('deadlift')) return 'pull';

    try {
      final found = ExerciseData.list.firstWhere(
        (e) => (e['name'] as String).toLowerCase() == n,
      );
      return (found['type'] as String? ?? 'full').toLowerCase();
    } catch (_) {}

    for (final kw in _coreKeywords) { if (n.contains(kw)) return 'core'; }
    for (final kw in _legsKeywords) { if (n.contains(kw)) return 'legs'; }
    for (final kw in _pushKeywords) { if (n.contains(kw)) return 'push'; }
    for (final kw in _pullKeywords) { if (n.contains(kw)) return 'pull'; }

    return 'full';
  }

  static String classifyMuscle(String name) {
    final n = name.toLowerCase().trim();

    try {
      final found = ExerciseData.list.firstWhere(
        (e) => (e['name'] as String).toLowerCase() == n,
      );
      return (found['muscle'] as String? ?? '').toLowerCase();
    } catch (_) {}

    for (final kw in _deadliftLegs) { if (n.contains(kw)) return 'legs'; }
    if (n.contains('deadlift')) return 'back';

    // Tricep priority before generic bench detection
    if (n.contains('close grip') ||
        n.contains('tricep') ||
        n.contains('pushdown') ||
        n.contains('skull') ||
        n.contains('kickback') ||
        n.contains('extension')) {
      return 'arms';
    }

    if (n.contains('bench') || n.contains('chest') || n.contains('fly') ||
        n.contains('pec')) {
      return 'chest';
    }
    if (n.contains('squat') || n.contains('leg press') ||
        n.contains('lunge') || n.contains('calf') ||
        n.contains('hack squat') || n.contains('hip thrust')) {
      return 'legs';
    }
    if (n.contains('leg curl') || n.contains('hamstring') ||
        n.contains('rdl') || n.contains('romanian')) {
      return 'legs';
    }
    if (n.contains('pulldown') || n.contains('pull-up') ||
        n.contains('row') || n.contains('lat ') ||
        n.contains('back')) {
      return 'back';
    }
    if (n.contains('shoulder') || n.contains('lateral') ||
        n.contains('arnold') || n.contains('overhead press') ||
        n.contains('front raise')) {
      return 'shoulders';
    }
    if (n.contains('curl') || n.contains('bicep') ||
        n.contains('hammer')) {
      return 'arms';
    }
    if (n.contains('tricep') || n.contains('pushdown') ||
        n.contains('skull') || n.contains('dip') ||
        n.contains('kickback') || n.contains('extension')) {
      return 'arms';
    }
    if (n.contains('plank') || n.contains('crunch') ||
        n.contains('ab') || n.contains('core')) {
      return 'core';
    }

    return 'other';
  }

  static String classifyDayFromExercises(List<String> names) {
    if (names.isEmpty) return 'full';
    final counts = <String, int>{'push': 0, 'pull': 0, 'legs': 0, 'core': 0};
    for (final n in names) {
      final t = classifyExercise(n);
      if (counts.containsKey(t)) counts[t] = (counts[t] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.value > 0 ? sorted.first.key : 'full';
  }
}

// ═══════════════════════════════════════════════════════════════
// REST DAY INTELLIGENCE
// ═══════════════════════════════════════════════════════════════
class RestDayPlan {
  final String title;
  final String description;
  final List<Map<String, String>> activities;
  final String coachMessage;

  const RestDayPlan({
    required this.title,
    required this.description,
    required this.activities,
    required this.coachMessage,
  });
}

class RestDayGenerator {
  RestDayGenerator._();

  static RestDayPlan generate({
    required int recoveryScore,
    required MoodType mood,
    required int streak,
    required String trainerType,
  }) {
    final isTired      = mood == MoodType.tired;
    final needsFullRest   = recoveryScore < 40 || (isTired && streak >= 5);
    final needsActiveRest = recoveryScore < 65;

    if (needsFullRest) {
      return RestDayPlan(
        title: '😴 Complete Rest Day',
        description: 'Your body needs full recovery. No gym today.',
        activities: [
          {'emoji': '🚶', 'name': 'Easy 10-min Walk',  'duration': '10 min',  'note': 'Gentle pace only'},
          {'emoji': '🧘', 'name': 'Foam Rolling',       'duration': '10 min',  'note': 'Focus on sore spots'},
          {'emoji': '💧', 'name': 'Hydrate Well',       'duration': 'All day', 'note': 'Aim for 3L+'},
          {'emoji': '😴', 'name': 'Sleep 8+ hours',     'duration': '8 hrs',   'note': 'Muscle growth happens here'},
          {'emoji': '🥗', 'name': 'High-Protein Meal',  'duration': 'Dinner',  'note': 'Feed the recovery'},
        ],
        coachMessage: _msg(trainerType,
          f: '😴 Complete rest today — your muscles are rebuilding. Trust the process.',
          s: '🧠 Rest is mandatory. Muscles grow when you sleep, not when you lift.',
          m: '🪖 TACTICAL REST ORDER. Muscles are under construction. Stand down.',
          h: '💤 Rest day = GROWTH day! Your body is building muscle RIGHT NOW!'),
      );
    }

    if (needsActiveRest) {
      return RestDayPlan(
        title: '🔄 Active Recovery Day',
        description: 'Light movement speeds up recovery.',
        activities: [
          {'emoji': '🏃', 'name': 'Brisk Walk / Light Jog', 'duration': '20-30 min', 'note': 'Conversational pace'},
          {'emoji': '🧘', 'name': 'Full-Body Stretch',      'duration': '15 min',    'note': '30 sec holds'},
          {'emoji': '🫁', 'name': 'Box Breathing',          'duration': '5 min',     'note': 'Lowers cortisol'},
          {'emoji': '🧊', 'name': 'Cold Shower',            'duration': '2 min',     'note': 'Reduces inflammation'},
          {'emoji': '💧', 'name': 'Hydration + Protein',    'duration': 'All day',   'note': 'Recovery fuel'},
        ],
        coachMessage: _msg(trainerType,
          f: '🔄 Active recovery today — light movement flushes fatigue faster than full rest.',
          s: '🔄 Active rest protocol. Light movement = faster lactic acid clearance.',
          m: '🪖 ACTIVE RECOVERY MODE. Light movement only. Save firepower for tomorrow.',
          h: '⚡ Active rest = FASTER gains! Move light, recover HARD, come back STRONGER!'),
      );
    }

    return RestDayPlan(
      title: '⚡ Mobility & Flexibility Day',
      description: 'You\'re recovering well. Mobility work today.',
      activities: [
        {'emoji': '🏃', 'name': 'Light Jog',        'duration': '20 min',    'note': 'Easy pace'},
        {'emoji': '🧘', 'name': 'Yoga / Mobility',  'duration': '20 min',    'note': 'Hip flexors + shoulders'},
        {'emoji': '🔄', 'name': 'Foam Roll',        'duration': '10 min',    'note': 'Full body'},
        {'emoji': '🤸', 'name': 'Band Pull-Aparts', 'duration': '3×15 reps', 'note': 'Shoulder health'},
        {'emoji': '💧', 'name': 'Nutrition Focus',  'duration': 'All day',   'note': 'High protein + good sleep'},
      ],
      coachMessage: _msg(trainerType,
        f: '🤸 Mobility today = better lifts tomorrow. Invest in your joints.',
        s: '🤸 Mobility work is non-negotiable. Flexibility = longevity.',
        m: '🪖 MOBILITY PROTOCOL. Flexible soldier = injury-proof soldier.',
        h: '🔥 Mobility = INJURY PROOF! Work the joints, WIN the long game!'),
    );
  }

  static String _msg(String style, {
    required String f, required String s, required String m, required String h,
  }) {
    switch (style) {
      case 'strict':       return s;
      case 'military':     return m;
      case 'motivational': return h;
      default:             return f;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TYPED MODELS
// ═══════════════════════════════════════════════════════════════
class WorkoutPlanResult {
  final Map<String, List<String>> plan;
  final Map<String, String> dayTypes; // day name → split type (e.g. 'Chest + Tricep')
  final String summary;
  const WorkoutPlanResult({
    required this.plan,
    this.dayTypes = const {},
    required this.summary,
  });
}

class ProgressionResult {
  final int    newReps;
  final double newWeight;
  final String message;
  final String type;
  const ProgressionResult({
    required this.newReps,
    required this.newWeight,
    required this.message,
    required this.type,
  });
}

// ═══════════════════════════════════════════════════════════════
// AI ENGINE — v7.1 Elite
// Recovery is owned by AppProvider. AIEngine does NOT compute
// muscle recovery — it only generates workouts, progressions,
// coach messages, and nutrition estimates.
// ═══════════════════════════════════════════════════════════════
class AIEngine {
  AIEngine._();
  static final Random _rng = Random();

  // ── Fatigue detection ─────────────────────────────────────────
  static bool isPerformanceDropping(List<WorkoutLog> logs) {
    if (logs.length < 5) return false;
    int score = 0;
    final recent = logs.reversed.take(5).toList();
    for (int i = 1; i < recent.length; i++) {
      final prev = recent[i - 1];
      final curr = recent[i];
      final pVol = prev.weight * prev.reps;
      final cVol = curr.weight * curr.reps;
      if (pVol > 0 && cVol < pVol * 0.85) score += 2;
      if (curr.date.difference(prev.date).inHours.abs() < 24) score += 1;
      if (prev.exercise.split('_').first == curr.exercise.split('_').first) {
        score += 1;
      }
    }
    return score >= 4;
  }

  static bool isFatigued(List<WorkoutLog> logs) =>
      isPerformanceDropping(logs);

  static bool shouldDeload({
    required List<WorkoutLog> logs,
    required int currentStreak,
  }) {
    if (logs.length < 6) return false;
    final last5 = logs.reversed.take(5).toList();
    final avg   = last5
            .map((l) => l.weight * l.reps)
            .reduce((a, b) => a + b) /
        last5.length;
    return isPerformanceDropping(logs) && avg < 5000 && currentStreak >= 4;
  }

  static String detectFatigue(List<String> history) {
    if (history.length < 3) return '';
    final last3  = history.reversed.take(3).toList();
    final splits = last3.map(_extractSplit).toList();
    if (splits.every((s) => s == splits.first) && splits.first != 'Rest') {
      return '${splits.first} three days in a row. A lighter day would fit well.';
    }
    if (history.length >= 5) {
      if (history.reversed
          .take(5)
          .every((w) => !w.toLowerCase().contains('rest'))) {
        return 'Five sessions in a row. Recovery today will help tomorrow.';
      }
    }
    return '';
  }

  static String detectWeakMuscleAdvanced(List<WorkoutLog> logs) {
    if (logs.isEmpty) return '';
    final freq = <String, int>{};
    for (final log in logs) {
      final m = log.exercise.split('_').first.toLowerCase();
      freq[m] = (freq[m] ?? 0) + 1;
    }
    return (freq.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .first
        .key;
  }

  // ── Progression ───────────────────────────────────────────────
  static String getStrengthTrend(List<WorkoutLog> logs, String exercise) {
    final ex = logs.where((l) => l.exercise == exercise).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (ex.length < 4) return 'insufficient_data';
    final recent = ex.reversed.take(2).map((l) => l.weight).toList();
    final older  = ex.reversed.skip(2).take(2).map((l) => l.weight).toList();
    final rAvg   = recent.reduce((a, b) => a + b) / recent.length;
    final oAvg   = older.reduce((a, b) => a + b) / older.length;
    if (rAvg > oAvg * 1.03) return 'improving';
    if (rAvg < oAvg * 0.97) return 'declining';
    return 'plateau';
  }

  static String getPlateauBreaker(String goal) {
    final m = <String, List<String>>{
      'strength':    ['💡 Wave loading: 3×5 heavy, then 3×8 lighter.', '💡 Add pause reps to rebuild power.'],
      'muscle_gain': ['💡 Drop sets to shock growth.', '💡 Switch tempo: 3 sec down, 1 sec up.'],
      'fat_loss':    ['💡 Switch to HIIT — steady cardio plateaus fast.', '💡 Shorten rest to 45 sec.'],
    };
    final list = m[goal] ?? ['💡 Change rep range or exercise order.'];
    return list[_rng.nextInt(list.length)];
  }

  static ProgressionResult getProgressionSuggestion({
    required String goal,
    required int lastReps,
    required double lastWeight,
    required int sessionCount,
  }) {
    if (sessionCount == 0 || sessionCount % 2 != 0) {
      return const ProgressionResult(
        newReps: 0, newWeight: 0,
        message: '✅ Same weight — focus on perfect form today', type: 'form',
      );
    }
    int nr = lastReps; double nw = lastWeight; String msg; String type;
    switch (goal) {
      case 'muscle_gain':
        if (lastReps < 12) { nr = lastReps + 1; msg = '💪 +1 rep'; type = 'reps'; }
        else { nw = lastWeight + 2.5; nr = 8; msg = '🔥 +2.5kg, reset to 8 reps'; type = 'weight'; }
        break;
      case 'strength':
        nw = lastWeight + 5.0; msg = '🏋️ +5kg'; type = 'weight'; break;
      case 'fat_loss':
        nr = lastReps + 2; msg = '⚡ +2 reps — more burn!'; type = 'reps'; break;
      default:
        nw = lastWeight + 2.5; msg = '📈 +2.5kg'; type = 'weight';
    }
    return ProgressionResult(newReps: nr, newWeight: nw, message: msg, type: type);
  }

  static double calculateOneRM(double weight, int reps) {
    if (reps <= 0 || reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  static double getPersonalRecord(List<WorkoutLog> logs, String exercise) {
    final ex = logs.where((l) => l.exercise == exercise).toList();
    if (ex.isEmpty) return 0.0;
    return ex.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
  }

  // ── STRICT TYPE-BASED EXERCISE POOLS ─────────────────────────
  static List<Map<String, dynamic>> _pushPool() =>
      ExerciseData.list.where((e) {
        return (e['type'] as String? ?? '').toLowerCase() == 'push';
      }).toList();

  static List<Map<String, dynamic>> _pullPool() =>
      ExerciseData.list.where((e) {
        return (e['type'] as String? ?? '').toLowerCase() == 'pull';
      }).toList();

  static List<Map<String, dynamic>> _legsPool() =>
      ExerciseData.list.where((e) {
        final t      = (e['type']   as String? ?? '').toLowerCase();
        final muscle = (e['muscle'] as String? ?? '').toLowerCase();
        return t == 'legs' || muscle == 'legs';
      }).toList();

  static List<Map<String, dynamic>> _corePool() =>
      ExerciseData.list.where((e) {
        final t      = (e['type']   as String? ?? '').toLowerCase();
        final muscle = (e['muscle'] as String? ?? '').toLowerCase();
        return t == 'core' || muscle == 'core';
      }).toList();

  // ── Fallbacks guarantee non-empty ────────────────────────────
  static List<Map<String, dynamic>> _fallback(String type) {
    switch (type.toLowerCase()) {
      case 'push': return [
        {'name': 'Push-ups',        'muscle': 'Chest',     'emoji': '💪', 'type': 'push', 'bodyweight': true,  'defaultWeight': 0.0,  'defaultReps': 15},
        {'name': 'Bench Press',     'muscle': 'Chest',     'emoji': '🏋️', 'type': 'push', 'bodyweight': false, 'defaultWeight': 60.0, 'defaultReps': 8},
        {'name': 'Shoulder Press',  'muscle': 'Shoulders', 'emoji': '💪', 'type': 'push', 'bodyweight': false, 'defaultWeight': 40.0, 'defaultReps': 10},
        {'name': 'Lateral Raise',   'muscle': 'Shoulders', 'emoji': '💪', 'type': 'push', 'bodyweight': false, 'defaultWeight': 8.0,  'defaultReps': 15},
        {'name': 'Tricep Pushdown', 'muscle': 'Arms',      'emoji': '⚡', 'type': 'push', 'bodyweight': false, 'defaultWeight': 20.0, 'defaultReps': 15},
      ];
      case 'pull': return [
        {'name': 'Pull-ups',              'muscle': 'Back',      'emoji': '🔥', 'type': 'pull', 'bodyweight': true,  'defaultWeight': 0.0,  'defaultReps': 8},
        {'name': 'Barbell Row',           'muscle': 'Back',      'emoji': '🏋️', 'type': 'pull', 'bodyweight': false, 'defaultWeight': 60.0, 'defaultReps': 8},
        {'name': 'Lat Pulldown',          'muscle': 'Back',      'emoji': '🤖', 'type': 'pull', 'bodyweight': false, 'defaultWeight': 50.0, 'defaultReps': 12},
        {'name': 'Dumbbell Bicep Curl',   'muscle': 'Arms',      'emoji': '💪', 'type': 'pull', 'bodyweight': false, 'defaultWeight': 12.0, 'defaultReps': 12},
        {'name': 'Face Pulls',            'muscle': 'Shoulders', 'emoji': '⚡', 'type': 'pull', 'bodyweight': false, 'defaultWeight': 15.0, 'defaultReps': 15},
      ];
      case 'legs': return [
        {'name': 'Barbell Back Squat',  'muscle': 'Legs', 'emoji': '🏋️', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 80.0,  'defaultReps': 8},
        {'name': 'Romanian Deadlift',   'muscle': 'Legs', 'emoji': '🏋️', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 60.0,  'defaultReps': 10},
        {'name': 'Leg Press',           'muscle': 'Legs', 'emoji': '🤖', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 100.0, 'defaultReps': 12},
        {'name': 'Leg Curl',            'muscle': 'Legs', 'emoji': '🤖', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 35.0,  'defaultReps': 12},
        {'name': 'Standing Calf Raise', 'muscle': 'Legs', 'emoji': '🦵', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 60.0,  'defaultReps': 15},
      ];
      default: return [
        {'name': 'Bench Press',        'muscle': 'Chest',     'emoji': '🏋️', 'type': 'push', 'bodyweight': false, 'defaultWeight': 60.0, 'defaultReps': 8},
        {'name': 'Barbell Row',        'muscle': 'Back',      'emoji': '💪', 'type': 'pull', 'bodyweight': false, 'defaultWeight': 60.0, 'defaultReps': 8},
        {'name': 'Barbell Back Squat', 'muscle': 'Legs',      'emoji': '🦵', 'type': 'legs', 'bodyweight': false, 'defaultWeight': 80.0, 'defaultReps': 8},
        {'name': 'Shoulder Press',     'muscle': 'Shoulders', 'emoji': '💪', 'type': 'push', 'bodyweight': false, 'defaultWeight': 40.0, 'defaultReps': 10},
        {'name': 'Plank',              'muscle': 'Core',      'emoji': '🔥', 'type': 'core', 'bodyweight': true,  'defaultWeight': 0.0,  'defaultReps': 3},
      ];
    }
  }

  // ── Core generator ────────────────────────────────────────────
  static List<Map<String, dynamic>> generateDayWorkout({
    required String goal,
    required String level,
    required String type,
    required List<String> history,
    String weakMuscle     = '',
    bool isBeginner       = false,
    bool bodyweightOnly   = false,
    double weightKg       = 75.0,
    String activityLevel  = 'Moderate',
    String gender         = '',
    int    mesocycleWeek  = 1,
  }) {
    final t = type.toLowerCase().trim();

    List<Map<String, dynamic>> base;
    switch (t) {
      case 'push':
        base = ExerciseData.list.where((e) {
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return m == 'chest' || m == 'shoulders' || m == 'triceps';
        }).toList();
        break;
      case 'pull':
        base = ExerciseData.list.where((e) {
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return m == 'back' || m == 'biceps';
        }).toList();
        break;
      case 'legs':
        base = _legsPool(); break;
      case 'core':
        base = _corePool(); break;
      case 'full':
      case 'fullbody':
        final pp = (_pushPool()..shuffle(_rng)).take(2).toList();
        final pl = (_pullPool()..shuffle(_rng)).take(2).toList();
        final lg = (_legsPool()..shuffle(_rng)).take(2).toList();
        final co = (_corePool()..shuffle(_rng)).take(1).toList();
        base = [...pp, ...pl, ...lg, ...co];
        break;
      case 'upper':
        final pu = (ExerciseData.list.where((e) {
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return m == 'chest' || m == 'shoulders' || m == 'triceps';
        }).toList()..shuffle(_rng)).take(3).toList();
        final pl2 = (ExerciseData.list.where((e) {
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return m == 'back' || m == 'biceps';
        }).toList()..shuffle(_rng)).take(3).toList();
        base = [...pu, ...pl2];
        break;
      case 'lower':
        final lg2 = (_legsPool()..shuffle(_rng)).take(4).toList();
        final co2 = (_corePool()..shuffle(_rng)).take(2).toList();
        base = [...lg2, ...co2];
        break;
      case 'chest':
        base = ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase().contains('chest') ||
          ((e['type'] as String? ?? '').toLowerCase() == 'push' &&
           (e['muscle'] as String? ?? '').toLowerCase().contains('chest'))
        ).toList();
        if (base.length < 3) base = _pushPool().where((e) => (e['muscle'] as String? ?? '').toLowerCase().contains('chest')).toList();
        if (base.length < 3) base = _pushPool();
        break;
      case 'back':
        base = ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase().contains('back')
        ).toList();
        if (base.length < 3) base = _pullPool();
        break;
      case 'shoulders':
        base = ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase().contains('shoulder') ||
          (e['muscle'] as String? ?? '').toLowerCase().contains('delt')
        ).toList();
        if (base.length < 3) base = _pushPool();
        break;
      case 'arms':
        final bi = ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'biceps'
        ).take(4).toList();
        final tri = ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'triceps'
        ).take(4).toList();
        base = [...bi, ...tri];
        if (base.length < 3) base = [..._pushPool().take(3), ..._pullPool().take(3)];
        break;
      case 'abs':
        base = _corePool();
        break;
      case 'chestback':
      case 'chest + back':
        final ch = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'chest'
        ).toList()..shuffle(_rng)).take(3).toList();
        final bk = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'back'
        ).toList()..shuffle(_rng)).take(3).toList();
        base = [...ch, ...bk];
        break;
      case 'shouldersarms':
      case 'shoulders + arms':
        final sh = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'shoulders'
        ).toList()..shuffle(_rng)).take(3).toList();
        final ar = (ExerciseData.list.where((e) {
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return m == 'biceps' || m == 'triceps';
        }).toList()..shuffle(_rng)).take(4).toList();
        base = [...sh, ...ar];
        if (base.length < 3) base = [...sh, ..._pullPool().take(2), ..._pushPool().take(2)];
        break;
      case 'chest + tricep':
        final ctChest = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'chest'
        ).toList()..shuffle(_rng)).take(3).toList();
        final ctTri = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'triceps'
        ).toList()..shuffle(_rng)).take(2).toList();
        base = [...ctChest, ...ctTri];
        break;
      case 'back + bicep':
        final bbBack = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'back'
        ).toList()..shuffle(_rng)).take(3).toList();
        final bbBi = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'biceps'
        ).toList()..shuffle(_rng)).take(2).toList();
        base = [...bbBack, ...bbBi];
        break;
      case 'legs + shoulders':
        final lsLegs = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'legs'
        ).toList()..shuffle(_rng)).take(3).toList();
        final lsSh = (ExerciseData.list.where((e) =>
          (e['muscle'] as String? ?? '').toLowerCase() == 'shoulders'
        ).toList()..shuffle(_rng)).take(2).toList();
        base = [...lsLegs, ...lsSh];
        break;
      case 'squat':
        base = ExerciseData.list.where((e) {
          final n = (e['name'] as String? ?? '').toLowerCase();
          final m = (e['muscle'] as String? ?? '').toLowerCase();
          return n.contains('squat') || n.contains('lunge') || n.contains('leg press') || m == 'legs';
        }).toList();
        if (base.length < 3) base = _legsPool();
        break;
      case 'hinge':
        base = ExerciseData.list.where((e) {
          final n = (e['name'] as String? ?? '').toLowerCase();
          return n.contains('deadlift') || n.contains('rdl') || n.contains('hip thrust') || n.contains('romanian');
        }).toList();
        if (base.length < 3) base = _legsPool();
        break;
      case 'press':
        base = ExerciseData.list.where((e) {
          final n = (e['name'] as String? ?? '').toLowerCase();
          return n.contains('press') || n.contains('bench') || n.contains('overhead');
        }).toList();
        if (base.length < 3) base = _pushPool();
        break;
      default:
        base = _fallback('full');
    }

    if (base.length < 3) base = _fallback(t);

    // Hard validation: strip any exercise whose muscle group isn't allowed for
    // this day type.  Only applies the result if it leaves ≥3 exercises.
    final validated = _validateForDay(base, t);
    if (validated.length >= 3) base = validated;

    // ── TRAVEL MODE: bodyweight only ──
    if (bodyweightOnly) {
      final filtered = base.where((e) =>
          e['bodyweight'] == true ||
          (e['equipment'] as String? ?? '').toLowerCase() == 'bodyweight'
      ).toList();
      if (filtered.length >= 3) base = filtered;
    }

    if (weakMuscle.isNotEmpty) {
      final wm = weakMuscle.toLowerCase();
      final matches =
          (t == 'push' && (wm == 'chest' || wm == 'shoulders')) ||
          (t == 'pull' && (wm == 'back'  || wm == 'arms')) ||
          (t == 'legs' && wm == 'legs') ||
          (t == 'core' && wm == 'core') ||
          t == 'full' || t == 'fullbody';
      if (matches) {
        final bonus = ExerciseData.list
            .where((e) => (e['muscle'] as String? ?? '').toLowerCase() == wm)
            .take(1)
            .toList();
        if (bonus.isNotEmpty) base = [...base, ...bonus];
      }
    }

    final seen = <String>{};
    base = base.where((e) {
      return seen.add((e['name'] as String? ?? '').toLowerCase());
    }).toList();

    final recent = history.take(15).map((h) => h.toLowerCase()).toList();
    final fresh  = base.where((e) {
      final n = (e['name'] as String? ?? '').toLowerCase();
      return !recent.any((r) {
        final rFirst = r.split(' ').first;
        return r.contains(n) || n.contains(rFirst);
      });
    }).toList();

    final poolList = (fresh.length >= 3 ? fresh : base).toList();

    if (poolList.isEmpty) {
      final fallback = _fallback(t).take(isBeginner ? 4 : 5).toList();
      return fallback.asMap().entries
          .map((e) => _buildExerciseMap(e.value, goal, isBeginner, e.key,
              weightKg: weightKg, level: level, gender: gender,
              mesocycleWeek: mesocycleWeek))
          .toList();
    }

    // Beginners: remove high-risk / high-skill exercises from the pool.
    if (isBeginner) {
      final safe = poolList.where((e) {
        final name = (e['name'] as String? ?? '').toLowerCase();
        return !_beginnerBlockedNames.any((blocked) => name.contains(blocked));
      }).toList();
      if (safe.length >= 3) {
        debugPrint('[SplitEngine] Beginner filter: ${poolList.length} → ${safe.length} safe exercises');
        final safeCompounds  = safe.where((e) =>
            (e['movement'] as String? ?? '').toLowerCase() == 'compound').toList()
          ..shuffle(_rng);
        final safeIsolations = safe.where((e) =>
            (e['movement'] as String? ?? '').toLowerCase() != 'compound').toList()
          ..shuffle(_rng);
        final safeOrdered = [...safeCompounds, ...safeIsolations];
        const baseCount = 4;
        final count = (baseCount + _activityVolumeBonus(activityLevel)).clamp(3, 5);
        return safeOrdered.take(count).toList().asMap().entries
            .map((e) => _buildExerciseMap(e.value, goal, isBeginner, e.key,
                weightKg: weightKg, level: level, gender: gender,
                mesocycleWeek: mesocycleWeek))
            .toList();
      }
    }

    // Compounds first, then isolations — shuffle within each tier for variety.
    final compounds  = poolList.where((e) =>
        (e['movement'] as String? ?? '').toLowerCase() == 'compound').toList()
      ..shuffle(_rng);
    final isolations = poolList.where((e) =>
        (e['movement'] as String? ?? '').toLowerCase() != 'compound').toList()
      ..shuffle(_rng);
    final ordered = [...compounds, ...isolations];

    final baseCount = isBeginner ? 4 : (level == 'advanced' ? 6 : 5);
    final count = (baseCount + _activityVolumeBonus(activityLevel)).clamp(3, 7);
    return ordered.take(count).toList().asMap().entries
        .map((e) => _buildExerciseMap(e.value, goal, isBeginner, e.key,
            weightKg: weightKg, level: level, gender: gender,
            mesocycleWeek: mesocycleWeek))
        .toList();
  }

  // ── Allowed muscle groups per day type ───────────────────────
  static const Map<String, List<String>> _dayAllowedMuscles = {
    'push':             ['chest', 'shoulders', 'triceps'],
    'pull':             ['back', 'biceps'],
    'legs':             ['legs'],
    'core':             ['core'],
    'abs':              ['core'],
    'upper':            ['chest', 'back', 'shoulders', 'biceps', 'triceps'],
    'lower':            ['legs', 'core'],
    'full':             ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core'],
    'fullbody':         ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core'],
    'chest':            ['chest'],
    'back':             ['back'],
    'shoulders':        ['shoulders'],
    'arms':             ['biceps', 'triceps'],
    'chestback':        ['chest', 'back'],
    'chest + back':     ['chest', 'back'],
    'shouldersarms':    ['shoulders', 'biceps', 'triceps'],
    'shoulders + arms': ['shoulders', 'biceps', 'triceps'],
    'chest + tricep':   ['chest', 'triceps'],
    'back + bicep':     ['back', 'biceps'],
    'legs + shoulders': ['legs', 'shoulders'],
    'squat':            ['legs'],
    'hinge':            ['legs', 'back'],
    'press':            ['chest', 'shoulders', 'triceps'],
  };

  static List<Map<String, dynamic>> _validateForDay(
    List<Map<String, dynamic>> exercises,
    String dayType,
  ) {
    final dt      = dayType.toLowerCase();
    final allowed = _dayAllowedMuscles[dt];
    if (allowed == null) return exercises;

    final validated = exercises.where((e) {
      final m = (e['muscle'] as String? ?? '').toLowerCase();
      return allowed.contains(m);
    }).toList();

    debugPrint(
      '[SplitEngine] Day=$dayType '
      'Allowed=$allowed '
      'Before=${exercises.length} After=${validated.length} '
      'Selected=${validated.map((e) => e['name']).toList()}',
    );

    return validated.isNotEmpty ? validated : exercises;
  }

  static Map<String, dynamic> _buildExerciseMap(
    Map<String, dynamic> ex,
    String goal,
    bool isBeginner,
    int position, {  // 0 = primary compound, increases toward finishing isolation
    double weightKg     = 75.0,
    String level        = 'intermediate',
    String gender       = '',
    int    mesocycleWeek = 1,
  }) {
    final isBW      = ex['bodyweight'] == true;
    final baseW     = (ex['defaultWeight'] as num? ?? 20.0).toDouble();
    final equipment = (ex['equipment'] as String? ?? 'dumbbell');
    final movement  = (ex['movement']  as String? ?? 'isolation');
    final lvl       = isBeginner ? 'beginner' : level;

    final range = VolumeAllocator.repRange(
      position: position, movement: movement, goal: goal, gender: gender,
    );
    final baseSets = VolumeAllocator.setsForPosition(
      position: position, movement: movement, level: lvl, goal: goal,
    );

    // Mesocycle periodization: week 3 = peak (+1 set), week 4 = deload (-1 set, 60% weight)
    final sets = mesocycleWeek == 4
        ? (baseSets - 1).clamp(1, 5)
        : mesocycleWeek == 3
            ? (baseSets + 1).clamp(2, 7)
            : baseSets;

    // Bodyweight-relative scaling: scale defaultWeight by user's body mass.
    // Reference body: 75 kg (population median). Clamped 50%–200% of reference.
    // Beginners get an additional 0.75× safety discount.
    // Deload week (4): reduce to 60% of planned weight for active recovery.
    double scaledW = 0.0;
    if (!isBW) {
      final bwScale     = (weightKg / 75.0).clamp(0.5, 2.0);
      final lvlScale    = lvl == 'beginner' ? 0.75 : lvl == 'advanced' ? 1.10 : 1.0;
      final deloadScale = mesocycleWeek == 4 ? 0.60 : 1.0;
      scaledW = WeightRounder.round(baseW * bwScale * lvlScale * deloadScale, equipment);
    }

    return {
      'name':          ex['name']   ?? 'Exercise',
      'muscle':        ex['muscle'] ?? '',
      'emoji':         ex['emoji']  ?? '💪',
      'type':          ex['type']   ?? 'strength',
      'movement':      movement,
      'equipment':     equipment,
      'unit':          isBW ? 'reps' : (ex['unit'] as String? ?? 'kg'),
      'bodyweight':    isBW,
      'smartSets':     sets,
      'smartRepMin':   range.min,
      'smartRepMax':   range.max,
      'smartReps':     range.mid,
      'smartWeight':   scaledW,
      'isDeloadWeek':  mesocycleWeek == 4,
    };
  }

  // ── Weekly plan generator ─────────────────────────────────────

  // Blocked exercises for beginners — high axial load, complex technique, or injury risk.
  static const Set<String> _beginnerBlockedNames = {
    'barbell back squat',
    'sumo deadlift',
    'barbell deadlift',
    'conventional deadlift',
    'trap bar deadlift',
    'barbell overhead press',
    'behind the neck press',
    'good morning',
    'zercher squat',
    'jefferson squat',
    'power clean',
    'hang power clean',
    'snatch',
    'clean and jerk',
    'weighted dip',
    'weighted dips',
    'bent-over barbell row',
    'barbell row',
  };

  /// Map a [SplitStyle] enum → AIEngine split key, factoring in [gymDays].
  static String splitStyleToKey(SplitStyle style, int gymDays) {
    switch (style) {
      case SplitStyle.fullBody:
        return gymDays >= 4 ? 'FullBody4' : 'FullBody';
      case SplitStyle.upperLower:
        return gymDays >= 4 ? 'UpperLower4' : 'UpperLower2';
      case SplitStyle.pushPullLegs:
        return gymDays >= 5 ? 'PPLPPL' : 'PPL';
      case SplitStyle.antagonistPairs:
        return gymDays >= 6 ? 'ChestTriBackBi6' : 'ChestTriBackBi';
      case SplitStyle.broSplit:
        return gymDays >= 6 ? 'BroSplit6' : 'BroSplit5';
      case SplitStyle.dailySingleMuscle:
        return gymDays >= 6 ? 'DailySingleMuscle6' : 'DailySingleMuscle';
      case SplitStyle.aiAdaptive:
        return gymDays >= 5 ? 'PPLPPL' : 'PPL';
      case SplitStyle.myOwnWay:
        return 'PPL';
    }
  }

  /// Activity level → extra exercise count modifier.
  static int _activityVolumeBonus(String activityLevel) {
    switch (activityLevel.toLowerCase().trim()) {
      case 'sedentary': return -1;
      case 'low':       return 0;
      case 'moderate':  return 0;
      case 'high':      return 1;
      case 'very high': return 1;
      default:          return 0;
    }
  }

  /// Determines the split key from user profile — replaces flat 3-line heuristic.
  ///
  /// Priority order:
  ///   1. [splitOverride] — explicit user or test override
  ///   2. strength goal → Strength3 (≤4 days) or PPL strength variant
  ///   3. SplitRecommendationEngine 3-axis lookup (level × gymDays × goal)
  static String _decideSplit(String level, String goal, {
    String splitOverride = '',
    int gymDays = 3,
  }) {
    if (splitOverride.isNotEmpty) return splitOverride;

    // Strength athletes need a strength-specific structure
    if (goal == 'strength') {
      if (gymDays <= 4) return 'Strength3';
      return gymDays >= 5 ? 'PPLPPL' : 'PPL';
    }

    // Map internal level strings to SplitRecommendationEngine casing
    final lvlStr = level == 'beginner' ? 'Beginner'
        : level == 'advanced' ? 'Advanced'
        : 'Intermediate';

    // Map internal goal strings to SplitRecommendationEngine phrasing
    final goalStr = goal == 'fat_loss'    ? 'Lose Fat'
        : goal == 'muscle_gain' ? 'Build Muscle'
        : 'General Fitness';

    final rec = SplitRecommendationEngine.recommend(
      level:   lvlStr,
      gymDays: gymDays.clamp(2, 6),
      goal:    goalStr,
    );

    debugPrint('[SplitEngine] $lvlStr/${gymDays}d/$goalStr → ${rec.split} → ${splitStyleToKey(rec.split, gymDays)}');
    return splitStyleToKey(rec.split, gymDays);
  }

  static List<String> _generateWeek(String split) {
    switch (split) {
      case 'FullBody':      return ['Full', 'Rest', 'Full', 'Rest', 'Full', 'Rest', 'Rest'];
      case 'PPLPPL':        return ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs', 'Rest'];
      case 'UpperLower4':   return ['Upper', 'Lower', 'Rest', 'Upper', 'Lower', 'Rest', 'Rest'];
      case 'UpperLower2':   return ['Upper', 'Rest', 'Lower', 'Rest', 'Rest', 'Rest', 'Rest'];
      case 'BroSplit5':     return ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Rest', 'Rest'];
      case 'BroSplit6':     return ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Abs', 'Rest'];
      case 'ChestTriBackBi':  return ['Chest + Tricep', 'Back + Bicep', 'Legs + Shoulders', 'Rest', 'Chest + Tricep', 'Back + Bicep', 'Rest'];
      case 'ChestTriBackBi6': return ['Chest + Tricep', 'Back + Bicep', 'Legs + Shoulders', 'Chest + Tricep', 'Back + Bicep', 'Legs + Shoulders', 'Rest'];
      case 'ArnoldSplit':     return ['Chest + Back', 'Shoulders + Arms', 'Legs', 'Chest + Back', 'Shoulders + Arms', 'Legs', 'Rest']; // advanced explicit only
      case 'FullBody4':     return ['Full', 'Rest', 'Full', 'Rest', 'Full', 'Rest', 'Full'];
      case 'Strength3':     return ['Squat', 'Hinge', 'Press', 'Rest', 'Squat', 'Rest', 'Rest'];
      default:              return ['Push', 'Pull', 'Legs', 'Rest', 'Push', 'Pull', 'Rest'];
    }
  }

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Returns the ordered list of day-types (e.g. ['Chest','Back','Shoulders',…])
  /// for the chosen split.  Callers use this to drive [generateDayWorkout] so
  /// that the actual exercises match the requested split rather than defaulting
  /// to Push/Pull/Legs.
  static List<String> weekTypesForSplit({
    required String level,
    required String goal,
    String splitOverride = '',
    int gymDays = 3,
  }) {
    final split = _decideSplit(level, goal, splitOverride: splitOverride, gymDays: gymDays);
    return _generateWeek(split);
  }

  static WorkoutPlanResult generateWeeklyPlan({
    required String goal,
    required String level,
    required List<WorkoutLog> logs,
    required String weakMuscle,
    required int recoveryScore,
    required bool fatigued,
    String splitOverride = '',
    int gymDays          = 3,
    double weightKg      = 75.0,
    String activityLevel = 'Moderate',
    String gender        = '',
    int mesocycleWeek    = 1,
  }) {
    final split    = _decideSplit(level, goal, splitOverride: splitOverride, gymDays: gymDays);
    final week     = _generateWeek(split);
    final plan     = <String, List<String>>{};
    final dayTypes = <String, String>{};
    int trainingDays = 0;

    for (int i = 0; i < 7; i++) {
      final day  = week[i];
      final name = _dayNames[i];

      dayTypes[name] = day;

      if (day == 'Rest' || (fatigued && recoveryScore < 40)) {
        plan[name] = ['Rest'];
        continue;
      }

      final wl     = weakMuscle.toLowerCase();
      final dl     = day.toLowerCase();
      final inject = weakMuscle.isNotEmpty &&
          ((wl == 'chest'     && dl == 'push') ||
           (wl == 'shoulders' && dl == 'push') ||
           (wl == 'back'      && dl == 'pull') ||
           (wl == 'arms'      && (dl == 'push' || dl == 'pull')) ||
           (wl == 'legs'      && dl == 'legs') ||
           dl == 'full');

      final exercises = generateDayWorkout(
        goal:          goal,
        level:         level,
        type:          day,
        history:       logs.map((e) => e.exercise).toList(),
        weakMuscle:    inject ? weakMuscle : '',
        weightKg:      weightKg,
        activityLevel: activityLevel,
        gender:        gender,
        mesocycleWeek: mesocycleWeek,
      );
      plan[name] = exercises.map((e) => e['name'] as String).toList();
      trainingDays++;
    }

    return WorkoutPlanResult(
      plan:     plan,
      dayTypes: dayTypes,
      summary:  _summary(
        split: split, trainingDays: trainingDays, goal: goal,
        weakMuscle: weakMuscle, fatigued: fatigued, recoveryScore: recoveryScore,
      ),
    );
  }

  static String _summary({
    required String split, required int trainingDays, required String goal,
    required String weakMuscle, required bool fatigued, required int recoveryScore,
  }) {
    if (fatigued) return '😴 Deload phase — $trainingDays light sessions this week';
    if (recoveryScore < 40) return '⚠️ Recovery $recoveryScore% — reduced intensity applied';
    final gl = {'fat_loss': 'Fat Loss', 'muscle_gain': 'Muscle Gain', 'strength': 'Strength'}[goal] ?? 'Fitness';
    final wk = weakMuscle.isNotEmpty ? ' · Focus: ${_cap(weakMuscle)}' : '';
    return '🗓️ $split split · $trainingDays sessions/week · $gl$wk';
  }

  // ── Coach messages ────────────────────────────────────────────
  static String getDailySuggestion({
    required List<String> lastWorkouts,
    required String goal,
    required int streak,
    required String trainerType,
    required String weakMuscle,
    List<WorkoutLog>? logs,
  }) {
    if (logs != null && logs.isNotEmpty) {
      final last = logs.last;
      if (last.reps >= 12) {
        return _say(trainerType,
        s: '📈 Strong last session. Increase load today.',
        m: '🪖 LAST SESSION DOMINANT. ADD WEIGHT.',
        h: '🔥 YOU CRUSHED LAST WORKOUT! LEVEL UP THE WEIGHT!!',
        f: '🔥 Great last session! Try adding weight today 💪');
      }
      if (last.reps <= 5 && last.weight > 0) {
        return _say(trainerType,
        s: '⚠️ Heavy strain detected. Reduce load.',
        m: '🪖 TOO HEAVY. CONTROL THE LOAD.',
        h: '⚡ HEAVY LIFT ALERT! RESET AND COME BACK STRONGER!',
        f: '⚠️ That was heavy! Maybe slightly lighter today 😊');
      }
    }

    if (logs != null && shouldDeload(logs: logs, currentStreak: streak)) {
      return _say(trainerType,
        s: '🧠 Deload required. Reduce weight 40%.',
        m: '🪖 RECOVERY WEEK. Drop weight 40%.',
        h: '💤 Deload = NEXT LEVEL gains! Trust the science! 🔓',
        f: '😴 Deload week — you\'ll come back stronger 💪');
    }

    final fatigue = detectFatigue(lastWorkouts);
    if (fatigue.isNotEmpty) return fatigue;

    if (lastWorkouts.length >= 2) {
      final r = lastWorkouts.take(3).map((w) => w.toLowerCase()).toList();
      if (r.every((w) => !w.contains('leg') && !w.contains('squat')) && streak > 1) {
        return _say(trainerType,
          s: '😤 Dodging legs? NOT TODAY.',
          m: '🪖 LEGS. NOW. No negotiation.',
          h: '🦵 Legs don\'t train themselves! LET\'S GO!',
          f: 'Haven\'t seen those legs lately 👀 Today\'s the day! 🦵');
      }
    }

    if (streak == 6)  return '🔥 ONE MORE DAY for a 7-day streak!';
    if (streak == 13) return '🚀 Day 14 tomorrow — Unstoppable badge RIGHT THERE!';
    if (streak == 29) return '⚔️ DAY 30 TOMORROW! Iron Will badge!';
    if (streak > 0 && streak % 7 == 0) return '👑 $streak-day streak! Absolute machine!';

    if (lastWorkouts.isEmpty && streak == 0) {
      return _say(trainerType,
      s: '😈 Day 1. Move.',
      m: '🪖 RECRUIT! First workout TODAY!',
      h: '⚡ TODAY is Day 1! LEGENDS start here!!',
      f: '💪 Welcome! Day 1 starts NOW!');
    }

    if (_countRest(lastWorkouts) >= 2) {
      return _say(trainerType,
      s: '😈 Enough rest. Iron is waiting.',
      m: '🪖 MOVE IT! 3 rest days = regression.',
      h: '💥 REST IS OVER! Your muscles have been BEGGING for this!',
      f: 'Body\'s recharged — ready to crush it 💪');
    }

    if (weakMuscle.isNotEmpty) {
      return _say(trainerType,
      s: '🎯 ${_cap(weakMuscle)} lagging. Fix it today.',
      m: '🪖 WEAKNESS: ${_cap(weakMuscle)}. Eliminate.',
      h: '🎯 ${_cap(weakMuscle)} is your kryptonite — DESTROY IT!',
      f: '🎯 Focus on ${_cap(weakMuscle)} today for balance!');
    }

    return _goalMessage(goal, _nextSplit(lastWorkouts), trainerType, streak);
  }

  static String getSmartCoach({
    required List<WorkoutLog> logs,
    required MoodType mood,
    required String trainerType,
    required int currentStreak,
  }) {
    if (logs.length >= 4) {
      final lastEx = logs.last.exercise;
      final trend  = getStrengthTrend(logs, lastEx);
      final name   = _cap(lastEx.split('_').first);
      if (trend == 'improving') {
        return _say(trainerType,
        s: '📈 $name trending up. Add load.',
        m: '📈 $name PROGRESSING. ADD WEIGHT.',
        h: '🔥 $name ON FIRE! HIT A PR TODAY!',
        f: '📈 $name getting stronger — keep the momentum!');
      }
      if (trend == 'declining') {
        return _say(trainerType,
        s: '⚠️ $name declining. Reduce load 10%.',
        m: '⚠️ $name dropping. Rebuild the base.',
        h: '⚡ $name dipped — reset and come back STRONGER!',
        f: '⚠️ $name dipping — rest up and come back fresh 🌟');
      }
    }

    if (shouldDeload(logs: logs, currentStreak: currentStreak)) {
      return _say(trainerType,
        s: '🧠 Deload required.',
        m: '🪖 RECOVERY MODE.',
        h: '💤 Smart rest = next level strength!',
        f: '😴 Deload week — recovery builds muscle 💡');
    }

    if (mood == MoodType.energetic) {
      return _say(trainerType,
      s: '🔥 High energy — PR attempt today.',
      m: '🪖 FULL POWER MODE! Attack every set!',
      h: '🔥 YOU\'RE FIRED UP!! HIT A PR!!',
      f: '🔥 Great energy — push harder today!');
    }

    if (mood == MoodType.tired) {
      return _say(trainerType,
      s: '😐 Tired — drop intensity 20%.',
      m: '🪖 LOW ENERGY. Discipline anyway.',
      h: '😴 The GREATS train when tired!',
      f: '😴 Keep it light — showing up IS the win 🌟');
    }

    return _say(trainerType,
      s: '💪 Stay consistent. No shortcuts.',
      m: '🪖 Every rep counts. Every session matters.',
      h: '💥 Building something INCREDIBLE! Keep going!!',
      f: '💪 Every session makes you stronger than yesterday!');
  }

  static String getPushMessage({required int streak, required bool fatigued}) {
    if (fatigued) {
      return ['😴 Recovery day — light effort counts',
              '💤 Easy session — muscles rebuilding'][_rng.nextInt(2)];
    }
    if (streak == 0) {
      return ['🚀 Start today.', '⚡ First rep is the hardest. GO.'][_rng.nextInt(2)];
    }
    if (streak >= 5) {
      return ['🔥 Don\'t break the streak!',
              '👑 $streak-day streak. Protect it.'][_rng.nextInt(2)];
    }
    return ['💪 Show up. That\'s enough.',
            '⚡ Your future body is built today.'][_rng.nextInt(2)];
  }

  // ── Nutrition ─────────────────────────────────────────────────
  static double estimateTDEE({
    required double weightKg, required double heightCm,
    required int age, required String gender, required String goal,
    String activityLevel = 'Moderate',
  }) {
    final bmr = gender == 'male'
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    const m = {
      'Sedentary': 1.2, 'Low': 1.375, 'Moderate': 1.55,
      'High': 1.725,    'Very High': 1.9,
    };
    double tdee = bmr * (m[activityLevel] ?? 1.55);
    if (goal == 'fat_loss')    tdee -= 400;
    if (goal == 'muscle_gain') tdee += 300;
    if (goal == 'strength')    tdee += 100;
    return tdee.roundToDouble();
  }

  static Map<String, double> getMacros({
    required double tdee, required double weightKg, required String goal,
  }) {
    double p, f, c;
    switch (goal) {
      case 'fat_loss':
        p = weightKg * 2.2; f = (tdee * 0.25) / 9; c = (tdee - (p * 4) - (f * 9)) / 4; break;
      case 'muscle_gain':
        p = weightKg * 2.0; f = (tdee * 0.25) / 9; c = (tdee - (p * 4) - (f * 9)) / 4; break;
      case 'strength':
        p = weightKg * 1.8; f = (tdee * 0.30) / 9; c = (tdee - (p * 4) - (f * 9)) / 4; break;
      default:
        p = weightKg * 1.6; f = (tdee * 0.25) / 9; c = (tdee - (p * 4) - (f * 9)) / 4;
    }
    return {
      'protein': p.clamp(0, 500).roundToDouble(),
      'carbs':   c.clamp(0, 1000).roundToDouble(),
      'fat':     f.clamp(0, 300).roundToDouble(),
    };
  }

  static String getProteinTarget({
    required double bodyWeightKg, required String goal,
    String fitnessLevel = 'intermediate',
  }) {
    const m = {'fat_loss': 2.2, 'muscle_gain': 2.0, 'strength': 1.8};
    return '${(bodyWeightKg * (m[goal] ?? 1.6)).round()}g';
  }

  // ── Smart alternative exercise ────────────────────────────────
  static Map<String, dynamic>? getSmartAlternative({
    required Map<String, dynamic> current,
    required List<Map<String, dynamic>> db,
  }) {
    try {
      return db.firstWhere(
        (e) => e['muscle']    == current['muscle'] &&
               e['movement']  == current['movement'] &&
               e['name']      != current['name'] &&
               e['equipment'] != current['equipment'],
      );
    } catch (_) { return null; }
  }

  static List<Map<String, dynamic>> generateWorkout({
    required String type,
    required List<Map<String, dynamic>> db,
    required List<String> history,
    required bool fatigued,
  }) {
    final filtered = db.where((e) => e['type'] == type).toList();
    if (fatigued) return filtered.where((e) => e['intensity'] != 'heavy').toList();
    return filtered.take(5).toList();
  }

  // ── Private helpers ───────────────────────────────────────────
  static String _say(String style, {
    required String s, required String m, required String h, required String f,
  }) {
    switch (style) {
      case 'strict':       return s;
      case 'military':     return m;
      case 'motivational': return h;
      default:             return f;
    }
  }

  static String _goalMessage(String goal, String split, String trainer, int streak) {
    final e = {'Push': '🔴', 'Pull': '🔵', 'Legs': '🟢', 'Full Body': '⚡'}[split] ?? '💪';
    final n = streak >= 3 ? ' ($streak🔥)' : '';
    switch (goal) {
      case 'fat_loss':    return '$e $split + Cardio$n — burn everything 🔥';
      case 'strength':    return '$e Heavy $split$n — overload protocol 🏋️';
      case 'muscle_gain': return '$e $split$n — mind-muscle connection 💪';
      default:            return '$e $split Training$n — let\'s go!';
    }
  }

  static String _extractSplit(String w) {
    final s = w.toLowerCase();
    if (s.contains('push') || s.contains('chest')) return 'Push';
    if (s.contains('pull') || s.contains('back'))  return 'Pull';
    if (s.contains('leg')  || s.contains('squat')) return 'Legs';
    if (s.contains('rest'))                         return 'Rest';
    return w;
  }

  static String _nextSplit(List<String> h) {
    if (h.isEmpty) return 'Push';
    switch (_extractSplit(h.first)) {
      case 'Push': return 'Pull';
      case 'Pull': return 'Legs';
      case 'Legs': return 'Push';
      default:     return 'Full Body';
    }
  }

  static int _countRest(List<String> h) {
    int c = 0;
    for (final w in h) { if (w.toLowerCase().contains('rest')) {
      c++;
    } else {
      break;
    } }
    return c;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String getTrendMessage(String exercise, List<WorkoutLog> logs) {
    switch (getStrengthTrend(logs, exercise)) {
      case 'improving': return '📈 $exercise improving!';
      case 'declining': return '⚠️ $exercise declining. ${getPlateauBreaker("muscle_gain")}';
      case 'plateau':   return '⏸️ Plateau on $exercise. ${getPlateauBreaker("muscle_gain")}';
      default:          return '';
    }
  }
}
