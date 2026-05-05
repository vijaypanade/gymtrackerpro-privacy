// lib/providers/workout_provider.dart — v8.2 USER UPGRADES + ALL FIXES
//
// Based on user's uploaded version which had several improvements:
//   ✅ All exercise/set ops are Future<void> with proper await
//   ✅ Better best-set selection in _syncLog
//   ✅ Better progression engine (bodyweight branch)
//   ✅ Cleaner PR/recovery code
//   ✅ Future.wait based persistence
//
// Bugs that this version fixes:
//   ❌ Duplicate addExercise/_findEx/addCustomExercise/removeExercise/getKey
//   ❌ Duplicate _averageEffortFromPlan
//   ❌ Duplicate _muscleRecoveryHours
//   ❌ DayCompletionResult was nested inside class
//   ❌ Missing helpers _buildDefaultWeek, _isValidDayIndex, _calcVolume,
//      _splitTypeForDay, _parseDayIndex, _typeFromNames, _validateAndFixWeekPlan,
//      _getCategoryFromName, _getEmojiFromName

import 'package:flutter/foundation.dart';

import '../engines/analytics_engine.dart';
import '../engines/pr_engine.dart' as pre;
import '../engines/analytics_engine_extensions.dart';
import '../models/memory_models.dart';
import '../models/models.dart';
import '../models/workout_log.dart';
import '../services/ai_engine.dart';
import '../services/storage_service.dart';
import '../utils/id_helper.dart';

// ═══════════════════════════════════════════════════════════════
// PR RESULT
// ═══════════════════════════════════════════════════════════════
enum PROutcome { pr, match, drop, first }

class PRResult {
  final PROutcome outcome;
  final double    newWeight;
  final int       newReps;
  final double    prevWeight;
  final int       prevReps;
  final double    improvePct;

  const PRResult({
    required this.outcome,
    required this.newWeight,
    required this.newReps,
    required this.prevWeight,
    required this.prevReps,
    required this.improvePct,
  });

  bool get isPR    => outcome == PROutcome.pr || outcome == PROutcome.first;
  bool get isMatch => outcome == PROutcome.match;
  bool get isDrop  => outcome == PROutcome.drop;
  bool get isFirst => outcome == PROutcome.first;

  String get uxMessage {
    switch (outcome) {
      case PROutcome.first: return '🎉 First rep logged! Every journey starts here.';
      case PROutcome.pr:    return '🔥 You\'re getting stronger!';
      case PROutcome.match: return '💪 Consistency builds strength. Keep pushing.';
      case PROutcome.drop:  return '📈 Recovery matters — come back stronger.';
    }
  }

  String get improvementStr {
    if (outcome == PROutcome.first) return '🎉 First ever!';
    if (improvePct == 0) return 'No change 🔁';
    if (improvePct > 0) return '+${improvePct.toStringAsFixed(1)}% 🔥';
    return '${improvePct.toStringAsFixed(1)}%';
  }
}

// ═══════════════════════════════════════════════════════════════
// SET PROGRESSION HINT
// ═══════════════════════════════════════════════════════════════
class SetProgressionHint {
  final String message;
  final double nextWeight;
  final int    targetReps;

  const SetProgressionHint({
    required this.message,
    required this.nextWeight,
    required this.targetReps,
  });
}

// ═══════════════════════════════════════════════════════════════
// DAY COMPLETION RESULT — top-level class (was nested = illegal)
// ═══════════════════════════════════════════════════════════════
class DayCompletionResult {
  final List<AppBadge> newBadges;
  final DayPlan?       completedDay;
  final bool           weekJustCompleted;

  const DayCompletionResult({
    required this.newBadges,
    required this.completedDay,
    required this.weekJustCompleted,
  });

  factory DayCompletionResult.empty() => const DayCompletionResult(
        newBadges: [],
        completedDay: null,
        weekJustCompleted: false,
      );
}

// ═══════════════════════════════════════════════════════════════
// WORKOUT PROVIDER
// ═══════════════════════════════════════════════════════════════
class WorkoutProvider extends ChangeNotifier {
  // ── Core state ──
  List<DayPlan>      _weekPlan = [];
  List<WorkoutLog>   _logs     = [];
  StreakData         _streak   = StreakData();
  List<HistoryEntry> _history  = [];

  Map<String, DateTime>             _lastMuscleTrained = {};
  Map<String, Map<String, dynamic>> _nearMissCache     = {};
  WeeklyMemory?                     _lastWeekMemory;

  bool _loaded     = false;
  bool _isBatching = false;

  // External hooks (AppProvider wires these)
  double Function()? _weightModifierProvider;
  int    Function()? _recommendedSetsProvider;
  String Function()? _weakMuscleProvider;

  static const int _maxLogs = 500;

  // Hive recovery hours per muscle — defined ONCE
  static const Map<String, int> _muscleRecoveryHours = {
    'legs': 72, 'back': 48, 'chest': 48,
    'shoulders': 48, 'arms': 36, 'core': 24,
  };

  // Day name lookup
  static const List<String> _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday',  'Saturday', 'Sunday',
  ];

  // ═════════════════════════════════════════════════════════
  // PUBLIC STATE
  // ═════════════════════════════════════════════════════════
  bool get isLoaded => _loaded;
  List<DayPlan>      get weekPlan => List.unmodifiable(_weekPlan);
  List<WorkoutLog>   get logs     => List.unmodifiable(_logs);
  StreakData         get streak   => _streak;
  List<HistoryEntry> get history  => List.unmodifiable(_history);
  WeeklyMemory?      get lastWeekMemory => _lastWeekMemory;
  Map<String, DateTime> get lastMuscleTrained =>
      Map.unmodifiable(_lastMuscleTrained);

  // ═════════════════════════════════════════════════════════
  // EXTERNAL HOOK WIRING
  // ═════════════════════════════════════════════════════════
  void wireExternalHooks({
    double Function()? weightModifier,
    int    Function()? recommendedSets,
    String Function()? weakMuscle,
  }) {
    _weightModifierProvider  = weightModifier;
    _recommendedSetsProvider = recommendedSets;
    _weakMuscleProvider      = weakMuscle;
  }

  double get _modifier       => _weightModifierProvider?.call() ?? 1.0;
  int    get _recSets        => _recommendedSetsProvider?.call() ?? 4;
  String get _weakMuscleHint => _weakMuscleProvider?.call() ?? '';

  // ═════════════════════════════════════════════════════════
  // CONVENIENCE COMPUTED GETTERS
  // ═════════════════════════════════════════════════════════
  int    get todayIndex => (DateTime.now().weekday - 1).clamp(0, 6);
  int    get weeklyCompletedDays => _weekPlan.where((d) => d.isCompleted).length;
  double get weeklyScore =>
      ((weeklyCompletedDays / 7) * 100).clamp(0.0, 100.0);

  double get weeklyVolumeTotalKg {
    final now = DateTime.now();
    return _logs
        .where((l) => now.difference(l.date).inDays < 7)
        .fold(0.0, (s, l) => s + l.weight * l.reps);
  }

  bool get isBeginnerPhase => _streak.totalWorkouts < 7;

  int get daysSinceLastWorkout {
    if (_history.isEmpty) return 0;
    try {
      final last = DateTime.parse(_history.first.date);
      return DateTime.now().difference(last).inDays;
    } catch (_) { return 0; }
  }

  bool get isInactive => daysSinceLastWorkout >= 3;

  DayPlan get todayPlan {
    if (_weekPlan.isEmpty) return _buildDefaultWeek().first;
    final i = todayIndex;
    if (i >= _weekPlan.length) return _weekPlan.last;
    return _weekPlan[i];
  }

  Set<String> get completedDays =>
      _weekPlan.where((d) => d.isCompleted).map((d) => d.title).toSet();

  List<String> get lastWorkoutNames =>
      _history.take(5).map((e) => e.workoutName).toList();

  Map<String, int> get muscleGroupFrequency {
    final map = <String, int>{};
    for (final day in _weekPlan) {
      for (final ex in day.exercises) {
        if (ex.category.isNotEmpty) {
          map[ex.category] = (map[ex.category] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  Map<String, int> get muscleTrainingFrequency {
    final map = <String, int>{};
    for (final log in _logs) {
      final m = log.exercise.split('_').first.toLowerCase();
      if (m.isNotEmpty) map[m] = (map[m] ?? 0) + 1;
    }
    return map;
  }

  String get weakestMuscleByLogs {
    final freq = muscleTrainingFrequency;
    if (freq.isEmpty) return '';
    return (freq.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        .first.key;
  }

  String get topMuscleGroup {
    final m = muscleGroupFrequency;
    if (m.isEmpty) return 'None';
    return m.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  bool isMuscleOvertrained(String muscle) =>
      _weekPlan.expand((d) => d.exercises)
          .where((e) => e.category.toLowerCase() == muscle.toLowerCase())
          .length >= 3;

  bool get isFatigued => AIEngine.isFatigued(_logs);

  bool get needsDeloadByVolume => AnalyticsEngineX.shouldDeload(
        logs:          _logs,
        streak:        _streak.currentStreak,
        totalWorkouts: _streak.totalWorkouts,
      );

  bool get needsDeload => needsDeloadByVolume;

  List<String> get skippedMuscleGroups {
    const muscles = ['chest', 'back', 'legs', 'shoulders', 'arms'];
    final cutoff  = DateTime.now().subtract(const Duration(days: 14));
    final freq    = <String, int>{};
    for (final log in _logs.where((l) => l.date.isAfter(cutoff))) {
      final m = normalizeMuscle(log.exercise.split('_').first);
      if (m.isNotEmpty) freq[m] = (freq[m] ?? 0) + 1;
    }
    return muscles.where((m) => (freq[m] ?? 0) == 0).toList();
  }

  // ═════════════════════════════════════════════════════════
  // INIT / LOAD
  // ═════════════════════════════════════════════════════════
  Future<void> load() async {
    if (_loaded) return;
    try {
      final storage = StorageService.instance;

      final streakLoaded = await storage.loadObject<StreakData>(
        StorageKeys.streak,
        StreakData.fromJson,
      );
      if (streakLoaded != null) _streak = streakLoaded;

      _history = await storage.loadList<HistoryEntry>(
        StorageKeys.history,
        HistoryEntry.fromJson,
      );

      _logs = await _loadLogsHybrid(storage);
      if (_logs.length > _maxLogs) {
        _logs = _logs.sublist(_logs.length - _maxLogs);
      }

      await _loadLastMuscleTrained();
      await _loadWeeklyMemory();

      _weekPlan = await _loadWeekPlan();
      _validateAndFixWeekPlan();
    } catch (e, s) {
      debugPrint('WorkoutProvider.load error: $e\n$s');
      _resetToDefaults();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _loadLastMuscleTrained() async {
    try {
      final raw = await StorageService.instance
          .getString(StorageKeys.lastMuscleTrained);
      if (raw == null) return;
      final result = StorageService.instance.decodeObject(raw, (m) => m);
      if (!result.hasData) return;
      _lastMuscleTrained = (result.data!).map((k, v) {
        try {
          return MapEntry(k as String, DateTime.parse(v as String));
        } catch (_) {
          return MapEntry(k as String, DateTime(2000));
        }
      });
    } catch (e) {
      debugPrint('_loadLastMuscleTrained error: $e');
    }
  }

  Future<void> _saveLastMuscleTrained() async {
    final encoded =
        _lastMuscleTrained.map((k, v) => MapEntry(k, v.toIso8601String()));
    await StorageService.instance
        .setJson(StorageKeys.lastMuscleTrained, encoded);
  }

  Future<List<WorkoutLog>> _loadLogsHybrid(StorageService storage) async {
    try {
      final box = storage.logsBox;
      if (box != null) {
        final raw = box.get('all_logs');
        if (raw is List && raw.isNotEmpty) {
          final out = <WorkoutLog>[];
          for (final j in raw) {
            try {
              if (j is Map<String, dynamic>) {
                out.add(WorkoutLog.fromJson(j));
              } else if (j is Map) {
                out.add(WorkoutLog.fromJson(Map<String, dynamic>.from(j)));
              }
            } catch (_) {}
          }
          if (out.isNotEmpty) {
            debugPrint('✅ Logs loaded from Hive: ${out.length} entries');
            return out;
          }
        }
      }
    } catch (e) {
      debugPrint('Hive logs load: $e');
    }

    final fromPrefs = await storage.loadList<WorkoutLog>(
      StorageKeys.logs,
      WorkoutLog.fromJson,
    );
    debugPrint('✅ Logs loaded from Prefs: ${fromPrefs.length} entries');
    return fromPrefs;
  }

  Future<void> _loadWeeklyMemory() async {
    try {
      _lastWeekMemory = await StorageService.instance.loadObject<WeeklyMemory>(
        StorageKeys.weeklyMemory,
        WeeklyMemory.fromJson,
      );
    } catch (e) {
      debugPrint('_loadWeeklyMemory error: $e');
    }
  }

  Future<List<DayPlan>> _loadWeekPlan() async {
    final storage = StorageService.instance;

    try {
      final hiveRaw = storage.readWorkoutBox(StorageKeys.hiveWeekPlan);
      List? hiveList;
      if (hiveRaw is String) {
        final r = storage.decodeList(hiveRaw, (m) => m);
        if (r.hasData) hiveList = r.data;
      } else if (hiveRaw is List) {
        hiveList = hiveRaw;
      }
      if (hiveList != null && hiveList.isNotEmpty) {
        final plans = <DayPlan>[];
        for (final j in hiveList) {
          try {
            if (j is Map<String, dynamic>) {
              plans.add(DayPlan.fromJson(j));
            } else if (j is Map) {
              plans.add(DayPlan.fromJson(Map<String, dynamic>.from(j)));
            }
          } catch (_) {}
        }
       if (plans.length == 7) {
  debugPrint('✅ WeekPlan loaded from Hive: ${plans.length} days');
  return plans;
}
debugPrint('⚠️ Hive returned ${plans.length} days — falling through to prefs');

      }
    } catch (e) {
      debugPrint('Hive load: $e');
    }

    try {
      final plans = await storage.loadList<DayPlan>(
        StorageKeys.weekPlan,
        DayPlan.fromJson,
      );
      if (plans.length == 7) {
  debugPrint('✅ WeekPlan loaded from Prefs: ${plans.length} days');
  return plans;
}

    } catch (e) {
      debugPrint('Prefs load: $e');
    }

    debugPrint('⚠️ No saved plan — using default week');
    return _buildDefaultWeek();
  }

  void _validateAndFixWeekPlan() {
    if (_weekPlan.isEmpty) {
      _weekPlan = _buildDefaultWeek();
      return;
    }
    while (_weekPlan.length < 7) {
      _weekPlan.add(DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  _weekPlan.length,
        title:     'Rest Day 😴',
        exercises: [],
        isRestDay: true,
      ));
    }
    if (_weekPlan.length > 7) _weekPlan = _weekPlan.sublist(0, 7);
    for (int i = 0; i < _weekPlan.length; i++) {
      _weekPlan[i].dayIndex = i;
    }
  }

  // ═════════════════════════════════════════════════════════
  // NOTIFY CONTROL
  // ═════════════════════════════════════════════════════════
  void _notify() {
    if (!_isBatching) notifyListeners();
  }

  void startBatch() { _isBatching = true; }
  void endBatch()   { _isBatching = false; notifyListeners(); }

  bool _isValidDayIndex(int i) => i >= 0 && i < _weekPlan.length;

  // ═════════════════════════════════════════════════════════
  // PLANNER — DAY-LEVEL OPERATIONS (used by AppProvider)
  // ═════════════════════════════════════════════════════════
  Future<void> updateDayTitle(int i, String title) async {
    if (!_isValidDayIndex(i)) return;
    _weekPlan[i].title = title.trim().isEmpty ? 'Workout' : title.trim();
    await _saveWeekPlan();
    _notify();
  }

  Future<void> clearDay(int i) async {
    if (!_isValidDayIndex(i)) return;
    _weekPlan[i]
      ..exercises.clear()
      ..isCompleted = false
      ..durationMinutes = 0;
    await _saveWeekPlan();
    _notify();
  }

  Future<void> resetWeek() async {
    _weekPlan = _buildDefaultWeek();
    await _saveWeekPlan();
    _notify();
  }

  Future<void> toggleRestDay(int i) async {
    if (!_isValidDayIndex(i)) return;
    final day = _weekPlan[i];
    day.isRestDay = !day.isRestDay;
    if (day.isRestDay) {
      day.exercises.clear();
      day.isCompleted = false;
      day.durationMinutes = 0;
    }
    await _saveWeekPlan();
    _notify();
  }

  // ═════════════════════════════════════════════════════════
  // EXERCISE OPERATIONS — defined ONCE
  // ═════════════════════════════════════════════════════════
  String getKey(String baseId) => baseId.toLowerCase().trim();

  PlannedExercise? _findEx(int dayIndex, String exId) {
    if (!_isValidDayIndex(dayIndex)) return null;
    final list = _weekPlan[dayIndex].exercises;
    if (list.isEmpty) return null;
    try {
      return list.firstWhere((e) => e.id == exId);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  Future<void> addExercise(
    int dayIndex, {
    required String name,
    required String category,
    required String emoji,
    String type = '',
    String unit = 'kg',
    required String baseId,
    bool isBodyweight = false,
  }) async {
    if (!_isValidDayIndex(dayIndex) || name.trim().isEmpty) return;

    final day = _weekPlan[dayIndex];
    day.isRestDay = false;

    final key = getKey(baseId);
    if (day.exercises.any((e) => getKey(e.baseId) == key)) return;

    day.exercises.add(PlannedExercise(
      id:         IdHelper.uuid(),
      name:       name.trim(),
      category:   category,
      emoji:      emoji.isEmpty ? '💪' : emoji,
      type:       type,
      unit:       isBodyweight ? 'reps' : (unit.isEmpty ? 'kg' : unit),
      baseId:     baseId,
      bodyweight: isBodyweight,
      sets: [
        ExSet(
          id:     IdHelper.uuid(),
          reps:   10,
          weight: isBodyweight ? 0.0 : 20.0,
        ),
      ],
    ));

    await _saveWeekPlan();
    _notify();
  }

  Future<void> addCustomExercise({
    required int    dayIndex,
    required String name,
    required String category,
    required String emoji,
    required bool   isBodyweight,
  }) async {
    var resolvedCategory = category;
    if (category.isEmpty || category.toLowerCase() == 'custom') {
      final detected = WorkoutClassifier.classifyMuscle(name);
      resolvedCategory = detected.isNotEmpty ? detected : 'Custom';
    }
    if (resolvedCategory.isNotEmpty) {
      resolvedCategory = resolvedCategory[0].toUpperCase() +
          resolvedCategory.substring(1);
    }

    await addExercise(
      dayIndex,
      name:        name,
      category:    resolvedCategory,
      emoji:       emoji.isEmpty ? '💪' : emoji,
      type:        isBodyweight
          ? 'Bodyweight'
          : WorkoutClassifier.classifyExercise(name),
      unit:        isBodyweight ? 'reps' : 'kg',
      isBodyweight: isBodyweight,
      baseId:      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
    );
  }

  Future<void> removeExercise(int dayIndex, String exId) async {
    if (!_isValidDayIndex(dayIndex)) return;
    _weekPlan[dayIndex].exercises.removeWhere((e) => e.id == exId);
    await _saveWeekPlan();
    _notify();
  }

  // ═════════════════════════════════════════════════════════
  // SET OPERATIONS
  // ═════════════════════════════════════════════════════════
  Future<void> addSet(int dayIndex, String exId) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    ex.sets.add(ExSet(
      id:     IdHelper.uuid(),
      reps:   last?.reps ?? 10,
      weight: ex.bodyweight ? 0.0 : (last?.weight ?? 20.0),
    ));
    await _saveWeekPlan();
    _notify();
  }

  Future<void> removeSet(int dayIndex, String exId, String setId) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null || ex.sets.length <= 1) return;
    ex.sets.removeWhere((s) => s.id == setId);
    _notify();
    await _saveWeekPlan();
    await _syncLog(dayIndex, exId);
  }

  Future<void> updateSet(
    int dayIndex,
    String exId,
    String setId, {
    int?    reps,
    double? weight,
  }) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;

    ExSet? s;
    for (final set in ex.sets) {
      if (set.id == setId) { s = set; break; }
    }
    if (s == null) return;

    if (reps != null)   s.reps = reps.clamp(0, 999);
    if (weight != null) {
      if (weight > 500) return;
      s.weight = weight.clamp(0, 500);
    }

    final wasDone = s.done;
    _notify();
    await _saveWeekPlan();
    if (wasDone) await _syncLog(dayIndex, exId);
  }

  Future<void> toggleSetDone(int dayIndex, String exId, String setId) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;
    ExSet? s;
    for (final set in ex.sets) {
      if (set.id == setId) { s = set; break; }
    }
    if (s == null) return;
    s.done = !s.done;
    _notify();
    await _saveWeekPlan();
    await _syncLog(dayIndex, exId);
  }

  Future<void> _syncLog(int dayIndex, String exId) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;

    final key      = getKey(ex.baseId);
    final doneSets = ex.sets.where((s) => s.done).toList();
    final now      = DateTime.now();

    _logs.removeWhere((l) =>
        l.exercise == key &&
        l.date.year  == now.year &&
        l.date.month == now.month &&
        l.date.day   == now.day);

    if (doneSets.isNotEmpty) {
      ExSet best = doneSets.first;
      for (final s in doneSets.skip(1)) {
        if (ex.unit == 'reps') {
          if (s.reps > best.reps) best = s;
        } else {
          if (s.weight > best.weight) best = s;
        }
      }

      var muscleKey = normalizeMuscle(ex.category);
      if (muscleKey.isEmpty || muscleKey == 'other') {
        final detected = WorkoutClassifier.classifyMuscle(ex.name);
        muscleKey = normalizeMuscle(detected);
      }

      if (muscleKey.isNotEmpty && muscleKey != 'other') {
        _lastMuscleTrained[muscleKey] = now;
      }

      _logs.add(WorkoutLog(
        exercise:    key,
        date:        now,
        weight:      best.weight.clamp(0, 500),
        reps:        best.reps.clamp(0, 999),
        minutes:     ex.unit == 'min' ? best.weight.toInt() : 0,
        muscleGroup: muscleKey.isNotEmpty ? muscleKey : null,
      ));

      _logs.sort((a, b) => a.date.compareTo(b.date));
      if (_logs.length > _maxLogs) {
        _logs = _logs.sublist(_logs.length - _maxLogs);
      }

      final pr = getPR(key, ex.unit);
      if (pr > 0) {
        final val = ex.unit == 'reps' ? best.reps.toDouble() : best.weight;
        final gap = pr - val;
        final gapPct = gap / pr;
        if (gap > 0 && gapPct <= 0.10) {
          _nearMissCache[key] = {
            'value': val, 'gap': gap, 'unit': ex.unit, 'date': _todayStr,
          };
        }
      }
    }

    await _saveLastMuscleTrained();
    await _saveLogs();
  }

  // ═════════════════════════════════════════════════════════
  // MUSCLE RECOVERY
  // ═════════════════════════════════════════════════════════
  double getMuscleRecovery(String muscle) {
    if (muscle.trim().isEmpty) return 97;
    final key = normalizeMuscle(muscle);
    if (key.isEmpty) return 97;

    final last = _lastMuscleTrained[key];
   if (last == null) return 97;


 final hours = DateTime.now().difference(last).inHours ~/ 1;
    final maxHours = _muscleRecoveryHours[key] ?? 48;
    if (maxHours <= 0) return 97;

  double recovery =
    ((hours / maxHours) * 100).clamp(0.0, 100.0).roundToDouble();

    final streak = _streak.currentStreak;
    if (streak >= 21)      recovery *= 0.90;
    else if (streak >= 10) recovery *= 0.94;
    else if (streak >= 5)  recovery *= 0.97;

   return recovery.clamp(5, 97);

  }

  double getMuscleRecoveryWithMood(String muscle, MoodType mood) {
    double base = getMuscleRecovery(muscle);
    switch (mood) {
      case MoodType.tired:     base *= 0.85; break;
      case MoodType.energetic: base *= 1.05; break;
      case MoodType.normal:    break;
    }
    return base.clamp(5, 97);
  }

  int getOverallRecovery({MoodType? mood}) {
    const muscles = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
    final total = muscles.fold<double>(0.0, (sum, muscle) {
      return sum + (mood != null
          ? getMuscleRecoveryWithMood(muscle, mood)
          : getMuscleRecovery(muscle));
    });
    return (total / muscles.length).round().clamp(10, 97);
  }

  List<MuscleRecovery> muscleRecoveryList({MoodType? mood}) {
    const muscles = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
    return muscles.map((muscle) {
      final key = normalizeMuscle(muscle);
      final score = mood != null
          ? getMuscleRecoveryWithMood(muscle, mood)
          : getMuscleRecovery(muscle);

      final last = _lastMuscleTrained[key];
      final lastStr = last != null ? '${last.day}/${last.month}' : 'Never';

      final muscleLogs = _logs
          .where((l) => normalizeMuscle(
                l.muscleGroup ?? l.exercise.split('_').first,
              ) == key)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final lastVolume = muscleLogs.isNotEmpty
          ? muscleLogs.first.weight * muscleLogs.first.reps
          : 0.0;

      return MuscleRecovery(
        muscle:          muscle,
        recoveryScore:   score.round().clamp(0, 100),
        lastTrainedDate: lastStr,
        lastVolume:      lastVolume,
      );
    }).toList();
  }

  // ═════════════════════════════════════════════════════════
  // LOGS & PR
  // ═════════════════════════════════════════════════════════
  List<WorkoutLog> getLogsForExercise(String key) =>
      _logs.where((l) => l.exercise == key).toList();
  List<WorkoutLog> getHistory(String key) => getLogsForExercise(key);

  double getPR(String key, String unit) {
    final ex = _logs
        .where((l) => l.exercise == key && l.weight >= 0 && l.weight <= 500)
        .toList();
    if (ex.isEmpty) return 0;

    double best = 0;
    for (final l in ex) {
      final val = unit == 'reps'
          ? l.reps.toDouble()
          : unit == 'min'
              ? l.minutes.toDouble()
              : l.weight;
      if (val > best) best = val;
    }
    return best;
  }

  int getPRReps(String key) {
    final ex = _logs.where((l) => l.exercise == key).toList();
    if (ex.isEmpty) return 0;
    WorkoutLog best = ex.first;
    for (final l in ex.skip(1)) {
      if (l.weight > best.weight) best = l;
    }
    return best.reps;
  }

  String? getPRDate(String key, String unit) {
    final ex = getLogsForExercise(key);
    if (ex.isEmpty) return null;
    WorkoutLog best = ex.first;
    for (final l in ex.skip(1)) {
      final current = unit == 'reps'
          ? l.reps.toDouble()
          : unit == 'min' ? l.minutes.toDouble() : l.weight;
      final bestVal = unit == 'reps'
          ? best.reps.toDouble()
          : unit == 'min' ? best.minutes.toDouble() : best.weight;
      if (current > bestVal) best = l;
    }
    return '${best.date.day}/${best.date.month}/${best.date.year}';
  }

  bool isNewPR(String key, double weight, int reps, String unit,
      {int minutes = 0}) {
    final ex = _logs.where((l) => l.exercise == key).toList();
    if (ex.isEmpty) return true;
    final prevPR = getPR(key, unit);
    final current = unit == 'reps'
        ? reps.toDouble()
        : unit == 'min' ? minutes.toDouble() : weight;
    return current > prevPR;
  }

  PRResult checkPRResult(String key, double weight, int reps, String unit) {
    final logs = _logs.where((l) => l.exercise == key).toList();
    if (logs.isEmpty) {
      return PRResult(
        outcome: PROutcome.first,
        newWeight: weight, newReps: reps,
        prevWeight: 0, prevReps: 0, improvePct: 0,
      );
    }

    final prevValue = getPR(key, unit);
    final prevReps  = getPRReps(key);
    final currentValue = unit == 'reps' ? reps.toDouble() : weight;

    if (currentValue > prevValue ||
        (currentValue == prevValue && reps > prevReps)) {
      final pct = prevValue > 0
          ? ((currentValue - prevValue) / prevValue * 100)
          : 5.0;
      return PRResult(
        outcome: PROutcome.pr,
        newWeight: weight, newReps: reps,
        prevWeight: prevValue, prevReps: prevReps,
        improvePct: pct.clamp(0, 999),
      );
    }

    if ((currentValue - prevValue).abs() < 0.01 && reps == prevReps) {
      return PRResult(
        outcome: PROutcome.match,
        newWeight: weight, newReps: reps,
        prevWeight: prevValue, prevReps: prevReps,
        improvePct: 0,
      );
    }

    final dropPct = prevValue > 0
        ? ((prevValue - currentValue) / prevValue * 100)
        : 0.0;
    return PRResult(
      outcome: PROutcome.drop,
      newWeight: weight, newReps: reps,
      prevWeight: prevValue, prevReps: prevReps,
      improvePct: -dropPct.clamp(0.0, 100.0),
    );
  }

  Future<void> addLog(String key, double weight, int reps, DateTime date,
      {int minutes = 0}) async {
    _logs.removeWhere((l) =>
        l.exercise == key &&
        l.date.year  == date.year &&
        l.date.month == date.month &&
        l.date.day   == date.day);
    _logs.add(WorkoutLog(
      exercise:    key,
      date:        date,
      weight:      weight.clamp(0, 500),
      reps:        reps.clamp(0, 999),
      minutes:     minutes,
      muscleGroup: getMuscleGroup(key),
    ));
    _logs.sort((a, b) => a.date.compareTo(b.date));
    if (_logs.length > _maxLogs) {
      _logs = _logs.sublist(_logs.length - _maxLogs);
    }
    _notify();
    await _saveLogs();
  }

  String? nearMissMessage(String exerciseKey, String unit) {
    final pr = getPR(exerciseKey, unit);
    if (pr <= 0) return null;
    final logs = getLogsForExercise(exerciseKey);
    if (logs.length < 2) return null;
    logs.sort((a, b) => b.date.compareTo(a.date));
    final latest = logs.first;
    final latestVal = unit == 'reps'
        ? latest.reps.toDouble()
        : unit == 'min' ? latest.minutes.toDouble() : latest.weight;
    final gap = pr - latestVal;
    if (gap <= 0) return null;
    final gapPct = gap / pr;
    if (gapPct <= 0.05) {
      return unit == 'reps'
          ? '🎯 Just ${gap.toInt()} reps away from your PR!'
          : '🎯 Only ${gap.toStringAsFixed(1)} ${unit == 'min' ? 'min' : 'kg'} away!';
    }
    if (gapPct <= 0.10) {
      return '📈 Within 10% of your PR. Push next time!';
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════
  // PROGRESSION ENGINE
  // ═════════════════════════════════════════════════════════
  SetProgressionHint analyzeProgression(PlannedExercise ex) {
    final validSets = ex.sets.where((s) => s.reps > 0).toList();

    if (validSets.isEmpty) {
      return SetProgressionHint(
        message:    'Start your first set 💪',
        nextWeight: ex.bodyweight ? 0 : 20,
        targetReps: 10,
      );
    }

    final last = validSets.last;

    if (ex.bodyweight) {
      if (last.reps >= 15) {
        return SetProgressionHint(
          message: '🔥 Increase reps or add difficulty!',
          nextWeight: 0,
          targetReps: (last.reps + 2).clamp(1, 50),
        );
      }
      return SetProgressionHint(
        message: '💪 Keep pushing reps',
        nextWeight: 0,
        targetReps: (last.reps + 1).clamp(1, 50),
      );
    }

    if (last.reps <= 5) {
      return SetProgressionHint(
        message: '⚠️ Too heavy — reduce weight',
        nextWeight: (last.weight - 2.5).clamp(0, 500),
        targetReps: 8,
      );
    }
    if (last.reps >= 12) {
      return SetProgressionHint(
        message: '🔥 Increase weight next set!',
        nextWeight: (last.weight + 2.5).clamp(0, 500),
        targetReps: 8,
      );
    }
    return SetProgressionHint(
      message: '💪 Perfect range — control it',
      nextWeight: last.weight.clamp(0, 500),
      targetReps: (last.reps + 1).clamp(1, 50),
    );
  }

  String getTrainerMessage(PlannedExercise ex) =>
      analyzeProgression(ex).message;

  /// Smart AI feedback — uses unified central function from pr_engine.
  String getSmartFeedback(PlannedExercise ex) {
    final fb = computeFeedback(ex);
    return fb?.message ?? '';
  }

  /// Returns the full WorkoutFeedback (message + next target + status).
  /// Used by both planner UI and PR celebration.
  pre.WorkoutFeedback? computeFeedback(PlannedExercise ex) {
    final key = getKey(ex.baseId);

    // History: previous session best (NOT today)
    final today = DateTime.now();
    final history = _logs
        .where((l) =>
            l.exercise == key &&
            (l.date.year != today.year ||
                l.date.month != today.month ||
                l.date.day != today.day))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final prev = history.isNotEmpty ? history.first : null;

    // ── PRIORITY 1: Use last DONE set if any ──
    final doneSets = ex.sets.where((s) => s.done).toList();
    if (doneSets.isNotEmpty) {
      final last = doneSets.last;
      return pre.calculateWorkoutFeedback(
        weight:             last.weight,
        reps:               last.reps,
        previousBestWeight: prev?.weight ?? 0,
        previousBestReps:   prev?.reps ?? 0,
        isBodyweight:       ex.bodyweight,
        unit:               ex.unit,
      );
    }

    // ── PRIORITY 2: No sets done yet — show PLANNED target as preview ──
    // Use first planned set as the target user is about to attempt
    if (ex.sets.isEmpty) return null;
    final planned = ex.sets.first;

    // If we have history, base feedback on history vs planned
    if (prev != null) {
      return pre.calculateWorkoutFeedback(
        weight:             planned.weight,
        reps:               planned.reps,
        previousBestWeight: prev.weight,
        previousBestReps:   prev.reps,
        isBodyweight:       ex.bodyweight,
        unit:               ex.unit,
      );
    }

    // ── PRIORITY 3: No history, not done — show generic plan-aware message ──
    final reps = planned.reps;
    String msg;
    double nextW;
    int nextR;

    if (ex.bodyweight || ex.unit == 'reps') {
      msg = '🎯 Target: ${planned.reps} reps — focus on form';
      nextW = 0;
      nextR = planned.reps;
    } else if (ex.unit == 'min') {
      msg = '⏱️ Target: ${planned.weight.toInt()} min steady pace';
      nextW = planned.weight;
      nextR = planned.reps;
    } else if (reps < 6) {
      msg = '💪 Heavy day — ${reps} reps · build strength';
      nextW = planned.weight;
      nextR = reps;
    } else if (reps > 12) {
      msg = '🔥 High volume — ${reps} reps · endurance focus';
      nextW = planned.weight;
      nextR = reps;
    } else {
      msg = '🎯 Hypertrophy zone — ${reps} reps · control & tempo';
      nextW = planned.weight;
      nextR = reps;
    }

    return pre.WorkoutFeedback(
      message:    msg,
      nextWeight: nextW,
      nextReps:   nextR,
      status:     pre.ProgressStatus.first,
      xpEarned:   0,
    );
  }
  double getSuggestedWeight(PlannedExercise ex) =>
      analyzeProgression(ex).nextWeight;

  double adaptiveNextWeight(String exerciseKey, {bool isOnPlateau = false}) {
    final logs = _logs.where((l) => l.exercise == exerciseKey).toList();
    if (logs.isEmpty) return 20;
    logs.sort((a, b) => b.date.compareTo(a.date));
    final last = logs.first;
    if (isOnPlateau) {
      return (last.weight * 0.90).clamp(5, 500);
    }
    return last.weight.clamp(0, 500);
  }

  double calculateNextWeight({
    required double currentWeight,
    required int    reps,
    required int    targetReps,
  }) {
    if (currentWeight <= 0) return 20;
    if (reps >= targetReps + 2) return (currentWeight + 2.5).clamp(0, 500);
    if (reps <= targetReps - 3) return (currentWeight - 2.5).clamp(0, 500);
    return currentWeight.clamp(0, 500);
  }

  // ═════════════════════════════════════════════════════════
  // DAY COMPLETION
  // ═════════════════════════════════════════════════════════
  Future<DayCompletionResult> markDayComplete(
      int dayIndex, int durationMin) async {
    if (!_isValidDayIndex(dayIndex)) return DayCompletionResult.empty();

    final day = _weekPlan[dayIndex];
    if (day.isCompleted) return DayCompletionResult.empty();

    final safeDuration = durationMin.clamp(0, 600);

    day.isCompleted     = true;
    day.durationMinutes = safeDuration;

    final volume = _calcVolume(day);

    _history.insert(0, HistoryEntry(
      id:              IdHelper.uuid(),
      date:            _todayStr,
      workoutName:     day.title,
      durationMinutes: safeDuration,
      totalVolume:     volume,
      exerciseCount:   day.exercises.length,
      setCount:        day.exercises.fold(0, (v, e) => v + e.sets.length),
    ));

    _streak.totalWorkouts++;
    _streak.currentStreak++;
    _streak.lastWorkoutDate = _todayStr;
    if (_streak.currentStreak > _streak.longestStreak) {
      _streak.longestStreak = _streak.currentStreak;
    }

    final newBadges = BadgeSystem.checkNewBadges(_streak, _streak.earnedBadges);
    _streak.earnedBadges.addAll(newBadges.map((b) => b.id));

    final plannedCount   = _weekPlan.where((d) => !d.isRestDay).length;
    final completedCount = _weekPlan.where((d) => d.isCompleted).length;
    final weekDone       = plannedCount > 0 && completedCount >= plannedCount;

    if (weekDone) {
      await _saveCurrentWeekAsMemory();
    }

    _nearMissCache.clear();

    await Future.wait([
      _saveWeekPlan(),
      _saveStreak(),
      _saveHistory(),
    ]);

    _notify();

    return DayCompletionResult(
      newBadges:         newBadges,
      completedDay:      day,
      weekJustCompleted: weekDone,
    );
  }

  Future<void> _saveCurrentWeekAsMemory() async {
    try {
      final completedDays = _weekPlan.where((d) => d.isCompleted).length;
      final plannedDays   = _weekPlan.where((d) => !d.isRestDay).length;
      if (completedDays == 0 || plannedDays == 0) return;

      final totalVol  = weeklyVolumeTotalKg;
      final avgEffort = _averageEffortFromPlan();

      final topExercises = <ExerciseMemory>[];
      for (final day in _weekPlan.where((d) => d.isCompleted)) {
        for (final ex in day.exercises) {
          final doneSets = ex.sets.where((s) => s.done).toList();
          if (doneSets.isEmpty) continue;
          final best = doneSets.reduce((a, b) => a.weight >= b.weight ? a : b);
          final vol  = doneSets.fold<double>(
              0, (sum, s) => sum + (s.weight * s.reps));
          if (vol <= 0) continue;
          topExercises.add(ExerciseMemory(
            name:        ex.name,
            bestWeight:  best.weight.clamp(0, 500),
            bestReps:    best.reps.clamp(0, 999),
            unit:        ex.unit,
            totalVolume: vol,
          ));
        }
      }

      final dedup = <String, ExerciseMemory>{};
      for (final e in topExercises) {
        final key = e.name.toLowerCase();
        if (!dedup.containsKey(key) ||
            e.totalVolume > dedup[key]!.totalVolume) {
          dedup[key] = e;
        }
      }

      final currentWeekNum = (_lastWeekMemory?.weekNumber ?? 0) + 1;

      _lastWeekMemory = WeeklyMemory(
        weekNumber:     currentWeekNum,
        weekStartDate:  _todayStr,
        planName:       _weekPlan.firstWhere(
          (d) => !d.isRestDay && d.exercises.isNotEmpty,
          orElse: () => _weekPlan.first,
        ).title,
        totalVolume:    totalVol,
        avgEffortScore: avgEffort,
        completedDays:  completedDays,
        plannedDays:    plannedDays,
        wasDeload:      needsDeloadByVolume,
        topExercises: (dedup.values.toList()
              ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume)))
            .take(6)
            .toList(),
      );

      await StorageService.instance.setJson(
        StorageKeys.weeklyMemory,
        _lastWeekMemory!.toJson(),
      );
      debugPrint('✅ Weekly memory saved: Week $currentWeekNum');
    } catch (e) {
      debugPrint('_saveCurrentWeekAsMemory error: $e');
    }
  }

  // _averageEffortFromPlan defined ONCE
  double _averageEffortFromPlan() {
    final completed = _weekPlan.where((d) => d.isCompleted).toList();
    if (completed.isEmpty) return 0;

    double totalEffort = 0;
    int    countDays   = 0;
    for (final d in completed) {
      final planned = d.exercises.fold(0, (v, e) => v + e.sets.length);
      final done    = d.exercises.fold(0,
          (v, e) => v + e.sets.where((s) => s.done).length);
      if (planned <= 0) continue;
      totalEffort += ((done / planned) * 100).clamp(0, 100);
      countDays++;
    }
    if (countDays == 0) return 0;
    return (totalEffort / countDays).clamp(0, 100);
  }

  double _calcVolume(DayPlan day) {
    double total = 0;
    for (final ex in day.exercises) {
      for (final s in ex.sets) {
        if (!s.done) continue;
        if (ex.unit == 'min') {
          total += s.weight.clamp(0, 600);
        } else if (ex.bodyweight || ex.unit == 'reps') {
          total += s.reps.clamp(0, 999).toDouble();
        } else {
          total += (s.weight * (s.reps > 0 ? s.reps : 1)).clamp(0, 100000);
        }
      }
    }
    return total;
  }

  // ═════════════════════════════════════════════════════════
  // PLAN GENERATION
  // ═════════════════════════════════════════════════════════
  Future<void> generateSmartPlan({
    required String goal,
    required String level,
  }) async {
    startBatch();
    try {
      final result = AIEngine.generateWeeklyPlan(
        goal:          goal,
        level:         level,
        logs:          _logs,
        weakMuscle:    _weakMuscleHint,
        recoveryScore: getOverallRecovery(),
        fatigued:      isFatigued,
      );
      final historyNames =
          _logs.map((e) => e.exercise.split('_').first).toList();
      final newPlan  = <DayPlan>[];
      final modifier = _modifier;
      final sets     = _recSets;

      for (int i = 0; i < 7; i++) {
        final exNames = result.plan[_dayNames[i]] ?? [];
        if (exNames.isEmpty || exNames.first == 'Rest') {
          newPlan.add(DayPlan(
            id:        IdHelper.uuid(),
            dayIndex:  i,
            title:     'Rest Day 😴',
            exercises: [],
            isRestDay: true,
          ));
          continue;
        }

        final type = _splitTypeForDay(i, level, goal);
        final exs = AIEngine.generateDayWorkout(
          goal:       goal,
          level:      level,
          type:       type,
          history:    historyNames,
          weakMuscle: _weakMuscleHint,
          isBeginner: isBeginnerPhase,
        );

        final planned = exs.map((ex) {
          final name = (ex['name'] as String?) ?? 'Exercise';
          final isBW = ex['bodyweight'] == true;
          return PlannedExercise(
            id:         IdHelper.uuid(),
            baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
            name:       name,
            category:   ex['muscle']  as String? ?? '',
            emoji:      ex['emoji']   as String? ?? '💪',
            type:       ex['type']    as String? ?? '',
            unit:       isBW ? 'reps' : (ex['unit'] as String? ?? 'kg'),
            bodyweight: isBW,
            sets: List.generate(sets.clamp(1, 6), (_) => ExSet(
              id:     IdHelper.uuid(),
              reps:   (ex['smartReps'] as int? ?? 10).clamp(1, 50),
              weight: isBW
                  ? 0.0
                  : (((ex['smartWeight'] as num?)?.toDouble() ?? 20.0)
                          * modifier)
                      .clamp(0, 500),
            )),
          );
        }).toList();

        newPlan.add(DayPlan(
          id:        IdHelper.uuid(),
          dayIndex:  i,
          title:     _formatTitle(type),
          exercises: planned,
        ));
      }

      while (newPlan.length < 7) {
        newPlan.add(DayPlan(
          id:        IdHelper.uuid(),
          dayIndex:  newPlan.length,
          title:     'Rest Day 😴',
          exercises: [],
          isRestDay: true,
        ));
      }

      _weekPlan = newPlan.take(7).toList();
      _validateAndFixWeekPlan();
    } catch (e) {
      debugPrint('❌ generateSmartPlan error: $e');
    } finally {
      endBatch();
      await _saveWeekPlan();
      _notify();
    }
  }

  Future<void> generateWorkoutForDay({
    required String type,
    required int    dayIndex,
    required String goal,
    required String level,
  }) async {
    if (!_isValidDayIndex(dayIndex)) return;

    final day = _weekPlan[dayIndex];

    if (type.toLowerCase() == 'rest') {
      day
        ..title = 'Rest Day 😴'
        ..exercises.clear()
        ..isRestDay = true
        ..durationMinutes = 0;
      await _saveWeekPlan();
      _notify();
      return;
    }

    day.exercises.clear();
    day.isCompleted = false;
    day.durationMinutes = 0;
    day.isRestDay = false;

    final exs = AIEngine.generateDayWorkout(
      goal:       goal,
      level:      level,
      type:       type,
      history:    lastWorkoutNames,
      weakMuscle: _weakMuscleHint,
      isBeginner: isBeginnerPhase,
    );

    final classifiedType = exs.isNotEmpty
        ? WorkoutClassifier.classifyDayFromExercises(
            exs.map((e) => e['name'] as String? ?? '').toList())
        : type;
    day.title = _formatTitle(classifiedType);

    final modifier = _modifier;
    final sets     = _recSets;

    for (final ex in exs) {
      final name = (ex['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final isBW = ex['bodyweight'] == true;
      day.exercises.add(PlannedExercise(
        id:         IdHelper.uuid(),
        baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        name:       name,
        category:   ex['muscle']  as String? ?? '',
        emoji:      ex['emoji']   as String? ?? '💪',
        type:       ex['type']    as String? ?? '',
        unit:       isBW ? 'reps' : (ex['unit'] as String? ?? 'kg'),
        bodyweight: isBW,
        sets: List.generate(sets.clamp(1, 6), (_) => ExSet(
          id:     IdHelper.uuid(),
          reps:   (ex['smartReps'] as int? ?? 10).clamp(1, 50),
          weight: isBW
              ? 0.0
              : (((ex['smartWeight'] as num?)?.toDouble() ?? 20.0)
                      * modifier)
                  .clamp(0, 500),
        )),
      ));
    }

    await _saveWeekPlan();
    _notify();
  }

  Future<void> applyGeneratedPlan(WorkoutPlanResult result) async {
    if (_weekPlan.isEmpty) _weekPlan = _buildDefaultWeek();

    for (final entry in result.plan.entries) {
      final idx = _parseDayIndex(entry.key);
      if (idx < 0 || idx >= 7) continue;

      final rawExercises = entry.value;
      if (rawExercises.isEmpty || rawExercises.first == 'Rest') {
        _weekPlan[idx] = DayPlan(
          id:        IdHelper.uuid(),
          dayIndex:  idx,
          title:     'Rest Day 😴',
          exercises: [],
          isRestDay: true,
        );
        continue;
      }

      final exercises = rawExercises
          .where((e) => e.trim().isNotEmpty && e != 'Rest')
          .map((e) {
            final safeName = e.trim();
            return PlannedExercise(
              id: IdHelper.uuid(),
              baseId: safeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
              name: safeName,
              category: WorkoutProvider.getMuscleGroup(safeName),
              emoji: '💪',
              type: 'strength',
              unit: 'kg',
              bodyweight: false,
              sets: [
                ExSet(id: IdHelper.uuid(), reps: 10, weight: 20.0),
              ],
            );
          })
          .toList();

      _weekPlan[idx] = DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  idx,
        title:     _formatTitle(_typeFromNames(rawExercises)),
        exercises: exercises,
        isRestDay: exercises.isEmpty,
      );
    }

    _validateAndFixWeekPlan();
    await _saveWeekPlan();
    _notify();
  }

  Future<void> applyAIWorkoutMap(Map<String, dynamic> plan) async {
    try {
      await _applyPlanToWeek(plan);
    } catch (e) {
      debugPrint('applyAIWorkoutMap error: $e');
      notifyListeners();
    }
  }

  Future<void> _applyPlanToWeek(Map<String, dynamic> plan) async {
    final rawDays = plan['days'];
    if (rawDays == null || rawDays is! List || rawDays.isEmpty) {
      debugPrint('❌ Invalid plan structure');
      return;
    }

    final newPlan = <DayPlan>[];

    for (int i = 0; i < rawDays.length && i < 7; i++) {
      final d = rawDays[i];
      if (d is! Map) continue;
      final dayMap = Map<String, dynamic>.from(d);

      final rawExercises = dayMap['exercises'];
      if (rawExercises == null ||
          rawExercises is! List ||
          rawExercises.isEmpty) {
        newPlan.add(DayPlan(
          id:        IdHelper.uuid(),
          dayIndex:  i,
          title:     'Rest Day 😴',
          exercises: [],
          isRestDay: true,
        ));
        continue;
      }

      final exercises = rawExercises.map<PlannedExercise?>((e) {
        if (e is! Map) return null;
        final ex = Map<String, dynamic>.from(e);
        final name = (ex['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return null;

        final setCount = (ex['sets'] is int
                ? ex['sets']
                : int.tryParse(ex['sets']?.toString() ?? '') ?? 3)
            .clamp(1, 6);

        int reps = 10;
        final rawReps = ex['reps'];
        if (rawReps is int) {
          reps = rawReps;
        } else if (rawReps is String) {
          reps = int.tryParse(
                  rawReps.split(RegExp(r'[-–]')).first.trim()) ??
              10;
        }

        final isBW = ex['bodyweight'] == true;
        return PlannedExercise(
          id:         IdHelper.uuid(),
          baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name:       name,
          category:   _getCategoryFromName(name),
          emoji:      _getEmojiFromName(name),
          type:       ex['type'] as String? ?? 'strength',
          unit:       isBW ? 'reps' : 'kg',
          bodyweight: isBW,
          sets: List.generate(setCount, (_) => ExSet(
            id:     IdHelper.uuid(),
            reps:   reps.clamp(1, 50),
            weight: isBW ? 0.0 : 20.0,
            done:   false,
          )),
        );
      }).whereType<PlannedExercise>().toList();

      final focus = (dayMap['focus'] as String?)?.trim();
      newPlan.add(DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  i,
        title:     (focus != null && focus.isNotEmpty) ? focus : 'Workout',
        exercises: exercises,
        isRestDay: exercises.isEmpty,
      ));
    }

    while (newPlan.length < 7) {
      newPlan.add(DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  newPlan.length,
        title:     'Rest Day 😴',
        exercises: [],
        isRestDay: true,
      ));
    }

    _weekPlan = newPlan.take(7).toList();
    _validateAndFixWeekPlan();
    await _saveWeekPlan();
    _notify();
  }

  Future<void> applyAISuggestion(int dayIndex, List<String> suggestions) async {
    if (!_isValidDayIndex(dayIndex) || suggestions.isEmpty) return;

    final day = _weekPlan[dayIndex];
    day.isRestDay = false;

    startBatch();
    try {
      for (final name in suggestions) {
        final cleanName = name.trim();
        if (cleanName.isEmpty) continue;
        final baseId = cleanName.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '_');

        final exists = day.exercises.any(
          (e) => getKey(e.baseId) == getKey(baseId),
        );
        if (exists) continue;

        final muscleClass = WorkoutClassifier.classifyMuscle(cleanName);
        day.exercises.add(PlannedExercise(
          id:         IdHelper.uuid(),
          name:       cleanName,
          category:   muscleClass.isNotEmpty
              ? '${muscleClass[0].toUpperCase()}${muscleClass.substring(1)}'
              : 'AI',
          emoji:      '💪',
          type:       WorkoutClassifier.classifyExercise(cleanName),
          unit:       'kg',
          bodyweight: false,
          baseId:     baseId,
          sets: [
            ExSet(id: IdHelper.uuid(), reps: 10, weight: 20.0),
          ],
        ));
      }
      await _saveWeekPlan();
    } catch (e) {
      debugPrint('applyAISuggestion error: $e');
    } finally {
      endBatch();
    }
  }

  /// Helper for AIProvider
  List<ExerciseMemory> buildExerciseHistory() {
    if (_logs.isEmpty) return [];
    final cutoff = DateTime.now().subtract(const Duration(days: 21));

    final byExercise = <String, List<WorkoutLog>>{};
    for (final log in _logs) {
      if (!log.date.isAfter(cutoff)) continue;
      byExercise.putIfAbsent(log.exercise, () => []).add(log);
    }

    final memories = <ExerciseMemory>[];
    for (final entry in byExercise.entries) {
      final logs = List<WorkoutLog>.from(entry.value);
      if (logs.isEmpty) continue;
      final isRepsOnly = logs.every((l) => l.weight == 0);
      logs.sort((a, b) => isRepsOnly
          ? b.reps.compareTo(a.reps)
          : b.weight.compareTo(a.weight));

      final best = logs.first;
      if (best.weight == 0 && best.reps == 0) continue;
      final totalVol = logs.fold<double>(
          0, (sum, l) => sum + (l.weight * (l.reps > 0 ? l.reps : 1)));

      memories.add(ExerciseMemory(
        name: entry.key
            .replaceAll('_', ' ')
            .replaceFirstMapped(
                RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase()),
        bestWeight:  best.weight,
        bestReps:    best.reps,
        unit:        isRepsOnly ? 'reps' : 'kg',
        totalVolume: totalVol,
      ));
    }
    memories.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    return memories.take(8).toList();
  }

  List<String> get missedDayNames {
    return _weekPlan
        .where((d) => !d.isRestDay && d.exercises.isEmpty)
        .map((d) => _dayNames[d.dayIndex.clamp(0, 6)])
        .toList();
  }

  // ═════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═════════════════════════════════════════════════════════
  Future<void> _saveWeekPlan() async {
    try {
      final data = _weekPlan.map((d) => d.toJson()).toList();
      final storage = StorageService.instance;
      await Future.wait([
        storage.writeWorkoutBox(StorageKeys.hiveWeekPlan, data),
        storage.setJson(StorageKeys.weekPlan, data),
      ]);
      debugPrint('💾 WeekPlan saved (${_weekPlan.length} days)');
    } catch (e, s) {
      debugPrint('❌ _saveWeekPlan ERROR: $e\n$s');
    }
  }

  Future<void> _saveStreak() async {
    try {
      await StorageService.instance
          .setJson(StorageKeys.streak, _streak.toJson());
    } catch (e) { debugPrint('❌ _saveStreak: $e'); }
  }

  Future<void> _saveHistory() async {
    try {
      await StorageService.instance.setJson(
        StorageKeys.history,
        _history.map((h) => h.toJson()).toList(),
      );
    } catch (e) { debugPrint('❌ _saveHistory: $e'); }
  }

  Future<void> _saveLogs() async {
    final data = _logs.map((l) => l.toJson()).toList();
    final storage = StorageService.instance;
    try {
      await Future.wait([
        storage.logsBox?.put('all_logs', data) ?? Future.value(),
        storage.setJson(StorageKeys.logs, data),
      ]);
    } catch (e, s) {
      debugPrint('❌ _saveLogs ERROR: $e\n$s');
    }
  }

  // ═════════════════════════════════════════════════════════
  // RESET
  // ═════════════════════════════════════════════════════════
  void _resetToDefaults() {
    _weekPlan          = _buildDefaultWeek();
    _streak            = StreakData();
    _history           = [];
    _logs              = [];
    _lastMuscleTrained = {};
    _nearMissCache     = {};
    _lastWeekMemory    = null;
  }

  Future<void> resetAll() async {
    _resetToDefaults();
    await Future.wait([
      _saveWeekPlan(),
      _saveStreak(),
      _saveHistory(),
      _saveLogs(),
      _saveLastMuscleTrained(),
    ]);
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════
  // STATIC HELPERS
  // ═════════════════════════════════════════════════════════
  static String normalizeMuscle(String muscle) {
    final m = muscle.toLowerCase();
    if (m.contains('shoulder') || m.contains('delt')) return 'shoulders';
    if (m.contains('leg') || m.contains('glute') ||
        m.contains('hamstring') || m.contains('calf') ||
        m.contains('quad')) return 'legs';
    if (m.contains('chest') || m.contains('pec')) return 'chest';
    if (m.contains('back') || m.contains('lat') ||
        m.contains('row') || m.contains('deadlift') ||
        m.contains('pull')) return 'back';
    if (m.contains('bicep') || m.contains('tricep') ||
        m.contains('curl') || m.contains('arm')) return 'arms';
    if (m.contains('core') || m.contains('abs') ||
        m.contains('plank') || m.contains('crunch')) return 'core';
    return 'other';
  }

  static String getMuscleGroup(String exercise) {
    final e = exercise.toLowerCase();
    if (e.contains('bench') || e.contains('chest') ||
        e.contains('pushup') || e.contains('push-up')) return 'chest';
    if (e.contains('pull') || e.contains('row') || e.contains('lat')) {
      return 'back';
    }
    if (e.contains('squat') || e.contains('lunge') || e.contains('leg')) {
      return 'legs';
    }
    if (e.contains('press') || e.contains('shoulder')) return 'shoulders';
    if (e.contains('curl') || e.contains('bicep')) return 'arms';
    if (e.contains('tricep') || e.contains('dip')) return 'arms';
    if (e.contains('abs') || e.contains('crunch') ||
        e.contains('plank')) return 'core';
    return 'other';
  }

  // ═════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═════════════════════════════════════════════════════════
  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
           '${n.day.toString().padLeft(2, '0')}';
  }

  String _formatTitle(String t) {
    switch (t.toLowerCase()) {
      case 'push': return 'Push Day';
      case 'pull': return 'Pull Day';
      case 'legs': return 'Legs Day';
      case 'rest': return 'Rest Day 😴';
      case 'full': return 'Full Body';
      case 'core': return 'Core Day';
      default:     return t.isNotEmpty ? t : 'Workout';
    }
  }

  String _splitTypeForDay(int i, String level, String goal) {
    if (level == 'beginner') {
      const s = ['Full', 'Rest', 'Full', 'Rest', 'Full', 'Rest', 'Rest'];
      return s[i.clamp(0, 6)];
    }
    if (level == 'advanced' && goal == 'muscle_gain') {
      const s = ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs', 'Rest'];
      return s[i.clamp(0, 6)];
    }
    const s = ['Push', 'Pull', 'Legs', 'Rest', 'Push', 'Pull', 'Rest'];
    return s[i.clamp(0, 6)];
  }

  int _parseDayIndex(String day) {
    const m = {
      'monday': 0, 'tuesday': 1, 'wednesday': 2, 'thursday': 3,
      'friday': 4, 'saturday': 5, 'sunday': 6,
    };
    return m[day.toLowerCase()] ?? -1;
  }

  String _typeFromNames(List<String> names) {
    final all = names.join(' ').toLowerCase();
    if (all.contains('push') || all.contains('chest'))   return 'Push';
    if (all.contains('pull') || all.contains('back'))    return 'Pull';
    if (all.contains('squat') || all.contains('leg'))    return 'Legs';
    if (all.contains('shoulder'))                        return 'Shoulders';
    if (all.contains('bicep') || all.contains('tricep')) return 'Arms';
    return 'Workout';
  }

  String _getCategoryFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('bench') || n.contains('push')) return 'Chest';
    if (n.contains('pull') || n.contains('row')) return 'Back';
    if (n.contains('squat') || n.contains('leg')) return 'Legs';
    if (n.contains('curl')) return 'Biceps';
    if (n.contains('tricep')) return 'Triceps';
    return 'General';
  }

  String _getEmojiFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('bench') || n.contains('push')) return '💪';
    if (n.contains('pull') || n.contains('row')) return '🏋️';
    if (n.contains('leg') || n.contains('squat')) return '🦵';
    if (n.contains('cardio')) return '🔥';
    return '🏋️';
  }

  List<DayPlan> _buildDefaultWeek() {
    const titles = [
      'Push Day', 'Pull Day', 'Legs Day', 'Rest Day 😴',
      'Push Day', 'Pull Day', 'Rest Day 😴',
    ];
    const rests = [false, false, false, true, false, false, true];
    return List.generate(7, (i) => DayPlan(
      id:        IdHelper.uuid(),
      dayIndex:  i,
      title:     titles[i],
      exercises: [],
      isRestDay: rests[i],
    ));
  }

  // ═════════════════════════════════════════════════════════
  // ANALYTICS HELPERS
  // ═════════════════════════════════════════════════════════
  double estimatedE1RM(String exerciseKey) {
    final logs = _logs.where((l) => l.exercise == exerciseKey).toList();
    if (logs.isEmpty) return 0;
    double best = 0;
    for (final l in logs) {
      if (l.weight <= 0 || l.reps <= 0) continue;
      final est = l.weight * (1 + l.reps / 30.0);
      if (est > best) best = est;
    }
    return best.clamp(0, 1000);
  }

  Map<String, int> get setsPerMuscleThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final out = <String, int>{};
    for (final log in _logs.where((l) => l.date.isAfter(cutoff))) {
      final m = normalizeMuscle(
        log.muscleGroup ?? log.exercise.split('_').first,
      );
      if (m == 'other') continue;
      out[m] = (out[m] ?? 0) + 1;
    }
    return out;
  }

  Map<String, double> get weeklyVolumeByMuscle {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final out = <String, double>{};
    for (final log in _logs.where((l) => l.date.isAfter(cutoff))) {
      final m = normalizeMuscle(
        log.muscleGroup ?? log.exercise.split('_').first,
      );
      if (m == 'other') continue;
      final vol = log.weight * (log.reps > 0 ? log.reps : 1);
      out[m] = (out[m] ?? 0) + vol;
    }
    return out;
  }

  Map<String, DateTime> get lastTrainedByMuscle =>
      Map<String, DateTime>.from(_lastMuscleTrained);
}
