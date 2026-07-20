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
//      _getEmojiFromName

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../engines/pr_engine.dart' as pre;
import '../engines/analytics_engine_extensions.dart';
import '../models/memory_models.dart';
import '../models/models.dart';
import '../models/workout_log.dart';
import '../services/ai_engine.dart';
import '../services/exercise_intelligence.dart';
import '../services/ghost_copy_service.dart';
import '../data/exercise_data.dart';
import '../services/storage_service.dart';
import '../utils/id_helper.dart';
import '../data/sync/outbox_service.dart';
import '../data/adapters/logs_sync_adapter.dart';
import '../data/repositories/workout_log_repository.dart';
import '../services/voice_coach_service.dart';
import '../services/rest_timer_service.dart';
import '../services/workout_session_service.dart';
import '../services/progression_service.dart';
import '../models/coach_context.dart' show PREvent;

export '../services/progression_service.dart' show PROutcome, PRResult, SetProgressionHint;

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

  List<Map<String, dynamic>> _customExercises = [];

  Map<String, DateTime>             _lastMuscleTrained = {};
  Map<String, Map<String, dynamic>> _nearMissCache     = {};
  WeeklyMemory?                     _lastWeekMemory;
  final List<PREvent>               _recentPRs         = [];

  bool   _loaded           = false;
  bool   _isBatching       = false;
  bool   _newWeekDetected  = false;
  Timer? _savePlanDebounce;

  // External hooks (AppProvider wires these)
  double Function()? _weightModifierProvider;
  int    Function()? _recommendedSetsProvider;
  String Function()? _weakMuscleProvider;
  bool   Function()? _travelModeProvider;
  int    Function()? _ageProvider;

  static const int _maxLogs = 500;

  // Hive recovery hours per muscle — defined ONCE
  // Base recovery hours — scaled by age at runtime via _ageRecoveryMultiplier.
  static const Map<String, int> _muscleRecoveryHours = {
    'legs': 72, 'back': 48, 'chest': 48,
    'shoulders': 48, 'arms': 36, 'core': 24,
    'biceps': 36, 'triceps': 36, 'calves': 48,
  };

  /// Age scaling for recovery: older lifters recover slower.
  /// Sources: Häkkinen 1995, Petrella 2005, NSCA position stand.
  static double _ageRecoveryMultiplier(int age) {
    if (age < 25) { return 0.85; }  // faster recovery
    if (age < 35) { return 1.00; }  // baseline
    if (age < 45) { return 1.15; }  // 15% more recovery time
    return 1.30;                // 30% more recovery time
  }

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
  List<Map<String, dynamic>> get customExercises =>
      List.unmodifiable(_customExercises);

  WeeklyMemory?      get lastWeekMemory    => _lastWeekMemory;
  bool               get newWeekDetected   => _newWeekDetected;
  void               clearNewWeekBanner()  { _newWeekDetected = false; notifyListeners(); }
  // True when ghost copy ran and pre-filled weights — suppresses offline AI plan generation.
  bool get hasGhostCopyData =>
      _weekPlan.any((d) => d.exercises.any((e) => e.ghostWeekGap > 0));
  Map<String, DateTime> get lastMuscleTrained =>
      Map.unmodifiable(_lastMuscleTrained);

  List<PREvent> get recentPRs => List.unmodifiable(_recentPRs);

  double get previousWeeklyVolumeTotalKg => _lastWeekMemory?.totalVolume ?? 0.0;

  // ═════════════════════════════════════════════════════════
  // EXTERNAL HOOK WIRING
  // ═════════════════════════════════════════════════════════
  void wireExternalHooks({
    double Function()? weightModifier,
    int    Function()? recommendedSets,
    String Function()? weakMuscle,
    bool   Function()? travelMode,
    int    Function()? userAge,
  }) {
    _weightModifierProvider  = weightModifier;
    _recommendedSetsProvider = recommendedSets;
    _weakMuscleProvider      = weakMuscle;
    _travelModeProvider      = travelMode;
    _ageProvider             = userAge;
  }

  bool get _travelMode => _travelModeProvider?.call() ?? false;

  double get _modifier       => _weightModifierProvider?.call() ?? 1.0;
  int    get _recSets        => _recommendedSetsProvider?.call() ?? 4;
  String get _weakMuscleHint => _weakMuscleProvider?.call() ?? '';
  int    get _userAge        => _ageProvider?.call() ?? 27;

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
    if (_history.isEmpty) { return 0; }
    try {
      final last = DateTime.parse(_history.first.date);
      return DateTime.now().difference(last).inDays;
    } catch (_) { return 0; }
  }

  bool get isInactive => daysSinceLastWorkout >= 3;

  DayPlan get todayPlan {
    if (_weekPlan.isEmpty) { return _buildDefaultWeek().first; }
    final i = todayIndex;
    if (i >= _weekPlan.length) { return _weekPlan.last; }
    return _weekPlan[i];
  }

  /// Returns yesterday's DayPlan if it was missed (not completed, not rest, has exercises).
  DayPlan? get yesterdayMissedPlan {
    final yesterdayIdx = (todayIndex - 1 + 7) % 7;
    if (!_isValidDayIndex(yesterdayIdx)) { return null; }
    final yesterday = _weekPlan[yesterdayIdx];
    if (yesterday.isCompleted) { return null; }
    if (yesterday.isRestDay) { return null; }
    if (yesterday.exercises.isEmpty) { return null; }
    return yesterday;
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
      // Prefer explicit muscleGroup over exercise name prefix (prevents "skull" from skull_crushers)
      final m = (log.muscleGroup?.isNotEmpty == true
              ? log.muscleGroup!
              : log.exercise.split('_').first)
          .toLowerCase();
      if (m.isNotEmpty) map[m] = (map[m] ?? 0) + 1;
    }
    return map;
  }

  String get weakestMuscleByLogs {
    final freq = muscleTrainingFrequency;
    if (freq.isEmpty) { return ''; }
    return (freq.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        .first.key;
  }

  String get topMuscleGroup {
    final m = muscleGroupFrequency;
    if (m.isEmpty) { return 'None'; }
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

  /// Scales all kg set weights to 60 % of current value (nearest 0.5 kg).
  /// Applies to every non-rest day in the current week plan.
  void applyDeloadWeights() {
    for (final day in _weekPlan) {
      if (day.isRestDay) continue;
      for (final ex in day.exercises) {
        if (ex.unit != 'kg') continue;
        for (final s in ex.sets) {
          final reduced = (s.weight * 0.60 * 2).roundToDouble() / 2;
          s.weight = reduced.clamp(0, 500);
        }
      }
    }
    _notify();
  }

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
      _sanitizeDayBoundaryState();

      // Load persisted custom exercises
      final rawCustom = await storage.getString(StorageKeys.customExercises);
      if (rawCustom != null) {
        final decoded = jsonDecode(rawCustom);
        if (decoded is List) {
          _customExercises = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // Auto-reset completed workouts on new calendar week
      try {
        bool needsReset = false;

        // Check 1: _lastWeekMemory-based detection (fires when full week was completed).
        final lastWeekDate = _lastWeekMemory?.weekStartDate;
        if (lastWeekDate != null && lastWeekDate.isNotEmpty) {
          final last = DateTime.tryParse(lastWeekDate);
          if (last != null) {
            final now = DateTime.now();
            final lastWeekStart =
                last.subtract(Duration(days: last.weekday - 1));
            final currentWeekStart =
                now.subtract(Duration(days: now.weekday - 1));
            if (currentWeekStart.difference(lastWeekStart).inDays >= 7) {
              needsReset = true;
            }
          }
        }

        // Check 2: completionDate fallback — catches partial-week completions
        // where _lastWeekMemory was never saved because weekDone was never true.
        // If any completed day's completionDate belongs to a prior calendar week,
        // the entire plan must be reset.
        if (!needsReset) {
          final now = DateTime.now();
          final currentWeekMonday = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          for (final day in _weekPlan) {
            if (day.isCompleted && day.completionDate != null) {
              final d = DateTime.tryParse(day.completionDate!);
              if (d != null) {
                final completionDay = DateTime(d.year, d.month, d.day);
                final completionWeekMonday = completionDay
                    .subtract(Duration(days: completionDay.weekday - 1));
                if (completionWeekMonday.isBefore(currentWeekMonday)) {
                  needsReset = true;
                  break;
                }
              }
            }
          }
        }

        if (needsReset) {
          for (final day in _weekPlan) {
            day.isCompleted     = false;
            day.isPendingReview = false;
            day.completionDate  = null;

            for (final ex in day.exercises) {
              ex.isComplete = false;

              for (final set in ex.sets) {
                set.done = false;
              }
            }
          }
          _newWeekDetected = true;

          // Ghost Copy — pre-fill weights from most recent logs
          if (GhostCopyService.canGhostCopy(_weekPlan, _logs)) {
            GhostCopyService.applyGhostWeights(
              weekPlan: _weekPlan,
              logs:     _logs,
            );
            debugPrint('✅ Ghost copy applied — weights pre-filled from logs');
          }

          await _saveWeekPlan();
          debugPrint('✅ Auto-reset weekly completed states');
        }
      } catch (e) {
        debugPrint('Weekly auto-reset error: $e');
      }
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
          return MapEntry(k, DateTime.parse(v));
        } catch (_) {
          return MapEntry(k, DateTime(2000));
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
        title:     'Rest Day',
        exercises: [],
        isRestDay: true,
      ));
    }
    if (_weekPlan.length > 7) _weekPlan = _weekPlan.sublist(0, 7);
    for (int i = 0; i < _weekPlan.length; i++) {
      _weekPlan[i].dayIndex = i;

      // Cleanup old persisted rest-day emojis
      _weekPlan[i].title = _weekPlan[i]
          .title
          .replaceAll('😴', '')
          .replaceAll('😪', '')
          .trim();
    }
  }

  /// Clears stale isPendingReview from any day that is not today.
  /// Prevents cross-day session state inheritance when the app reopens.
  void _sanitizeDayBoundaryState() {
    final today = todayIndex;
    for (int i = 0; i < _weekPlan.length; i++) {
      if (i != today && _weekPlan[i].isPendingReview) {
        _weekPlan[i].isPendingReview = false;
      }
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

  @override
  void dispose() {
    _savePlanDebounce?.cancel();
    super.dispose();
  }

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

  /// Appends missed day's exercises to today + silently marks missed day complete.
  Future<void> appendMissedToToday(int missedDayIdx) async {
    final todayIdx = todayIndex;
    if (!_isValidDayIndex(missedDayIdx) || !_isValidDayIndex(todayIdx)) return;
    final missed = _weekPlan[missedDayIdx];
    final today  = _weekPlan[todayIdx];
    final ts     = DateTime.now().millisecondsSinceEpoch;
    for (final ex in missed.exercises) {
      today.exercises.add(PlannedExercise(
        id:         '${ex.id}_r$ts',
        baseId:     ex.baseId,
        name:       ex.name,
        category:   ex.category,
        emoji:      ex.emoji,
        type:       ex.type,
        unit:       ex.unit,
        bodyweight: ex.bodyweight,
        sets: ex.sets.map((s) => ExSet(
          id:     '${s.id}_r$ts',
          reps:   s.reps,
          weight: s.weight,
          done:   false,
        )).toList(),
      ));
    }
    missed.isCompleted = true;
    await _saveWeekPlan();
    _notify();
  }

  Future<void> resetWeek() async {
    _weekPlan = _buildDefaultWeek();
    await _saveWeekPlan();
    _notify();
  }

  // Clears all exercises from the week plan — used when switching to My Own Way
  Future<void> clearWeekPlan() async {
    _weekPlan = List.generate(7, (i) => DayPlan(
      id: 'day_$i',
      dayIndex: i,
      title: _dayNames[i],
      exercises: [],
      isRestDay: false,
    ));
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
  String getKey(String baseId) => baseId.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  /// Progressive overload weight for a new exercise set.
  /// Looks up historical best from logs; applies _modifier (recovery/fatigue factor).
  /// _modifier > 1.04 → fresh/improving → adds +2.5kg progressive overload.
  /// _modifier < 1.0  → fatigued/deload → reduces by modifier factor.
  double _progressiveWeight(String name, {String equipment = 'dumbbell'}) {
    if (_logs.isEmpty) { return WeightRounder.round(20.0, equipment); }
    final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final matches = _logs.where((l) => l.exercise == key && l.weight > 0).toList();
    if (matches.isEmpty) { return WeightRounder.round(20.0, equipment); }
    matches.sort((a, b) => b.weight.compareTo(a.weight));
    final best = matches.first.weight;
    final raw  = _modifier >= 1.04
        ? (best + WeightRounder.progressionStep(equipment, 'compound')).clamp(10.0, 500.0)
        : (best * _modifier).clamp(10.0, 500.0);
    return WeightRounder.round(raw, equipment);
  }

  // Returns last logged weight + reps for an exercise (most recent session, not best ever)
  ({double weight, int reps}) _lastSession(String name, {String equipment = 'dumbbell'}) {
    final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final matches = _logs.where((l) => l.exercise == key && l.weight > 0).toList();
    if (matches.isEmpty) {
      return (weight: WeightRounder.round(20.0, equipment), reps: 10);
    }
    matches.sort((a, b) => b.date.compareTo(a.date)); // most recent first
    final last = matches.first;
    return (
      weight: last.weight.clamp(1.0, 500.0),
      reps:   last.reps.clamp(1, 50),
    );
  }

  PlannedExercise? _findEx(int dayIndex, String exId) {
    if (!_isValidDayIndex(dayIndex)) { return null; }
    final list = _weekPlan[dayIndex].exercises;
    if (list.isEmpty) { return null; }
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
    // Adding exercise after all sets done — user is still editing, exit pending state
    if (day.isPendingReview) day.isPendingReview = false;

    if (day.title.trim().toLowerCase() == 'rest day') {
      day.title = '${category.isEmpty ? 'Workout' : category} Day';
    }

    final key = getKey(baseId);
    if (day.exercises.any((e) => getKey(e.baseId) == key)) return;

    // Scientific defaults: 3 sets × 8-12 reps (Schoenfeld 2017 hypertrophy meta-analysis)
    day.exercises.add(PlannedExercise(
      id:         IdHelper.uuid(),
      name:       name.trim(),
      category:   category,
      emoji:      emoji.isEmpty ? '💪' : emoji,
      type:       type,
      unit:       isBodyweight ? 'reps' : (unit.isEmpty ? 'kg' : unit),
      baseId:     baseId,
      bodyweight: isBodyweight,
      sets: List.generate(3, (_) => ExSet(
        id:     IdHelper.uuid(),
        reps:   10,
        weight: isBodyweight ? 0.0 : _progressiveWeight(name),
      )),
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

    final stableId = 'custom_${name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    // Skip if this custom exercise name already exists in the global list
    final alreadyExists = _customExercises.any(
      (e) => (e['id'] as String? ?? '') == stableId,
    );

    if (!alreadyExists) {
      final customExercise = {
        'id':        stableId,
        'name':      name.trim(),
        'type':      isBodyweight ? 'Bodyweight' : 'Custom',
        'muscle':    category,
        'equipment': 'custom',
        'movement':  isBodyweight ? 'compound' : 'isolation',
        'bodyweight': isBodyweight,
        'emoji':     emoji.isEmpty ? '💪' : emoji,
        'unit':      isBodyweight ? 'reps' : 'kg',
      };
      _customExercises.add(customExercise);
      await StorageService.instance.setJson(
        StorageKeys.customExercises,
        _customExercises,
      );
    }

    await addExercise(
      dayIndex,
      name:        name,
      category:    category,
      emoji:       emoji.isEmpty ? '💪' : emoji,
      type:        isBodyweight ? 'Bodyweight' : 'Custom',
      unit:        isBodyweight ? 'reps' : 'kg',
      isBodyweight: isBodyweight,
      baseId:      stableId,
    );
  }

  Future<void> removeExercise(int dayIndex, String exId) async {
    if (!_isValidDayIndex(dayIndex)) return;
    _weekPlan[dayIndex].exercises.removeWhere((e) => e.id == exId);
    await _saveWeekPlan();
    _notify();
  }

  Future<void> deleteCustomExercise(String id) async {
    _customExercises.removeWhere((e) => (e['id'] as String? ?? '') == id);
    await StorageService.instance.setJson(StorageKeys.customExercises, _customExercises);
    // Also remove from any day plan that still has it
    for (int i = 0; i < _weekPlan.length; i++) {
      _weekPlan[i].exercises.removeWhere((e) => e.baseId == id);
    }
    await _saveWeekPlan();
    _notify();
  }

  Future<void> editCustomExercise({
    required String id,
    required String name,
    required String category,
    required String emoji,
    required bool isBodyweight,
  }) async {
    final idx = _customExercises.indexWhere((e) => (e['id'] as String? ?? '') == id);
    if (idx == -1) return;
    _customExercises[idx] = {
      ..._customExercises[idx],
      'name':      name.trim(),
      'muscle':    category,
      'emoji':     emoji.isEmpty ? '💪' : emoji,
      'type':      isBodyweight ? 'Bodyweight' : 'Custom',
      'bodyweight': isBodyweight,
      'unit':      isBodyweight ? 'reps' : 'kg',
    };
    await StorageService.instance.setJson(StorageKeys.customExercises, _customExercises);
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
    int?    rir,
    bool    clearRir = false,
  }) async {
    // Only today's reps/weight can be logged
    if (dayIndex != todayIndex) return;
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
    if (clearRir) {
      s.rir = null;
    } else if (rir != null) {
      s.rir = rir.clamp(0, 5);
    }

    final wasDone = s.done;
    _notify();
    _debouncedSave();
    if (wasDone) await _syncLog(dayIndex, exId);
  }

  Future<void> toggleSetDone(
    int dayIndex,
    String exId,
    String setId, {
    double? effectiveWeight,
    double? plannedWeight,
  }) async {
    final isCompletedSession = _isValidDayIndex(dayIndex) && _weekPlan[dayIndex].isCompleted;

    // Allow: today's active workout OR editing a completed session (backfill).
    // Block: non-today unstarted days.
    if (!isCompletedSession && dayIndex != todayIndex) return;

    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;
    ExSet? s;
    for (final set in ex.sets) {
      if (set.id == setId) { s = set; break; }
    }
    if (s == null) return;

    final wasNotDone = !s.done;
    s.done = !s.done;
    _notify();
    _debouncedSave();
    // Pass execution data only when marking done (wasNotDone), not when undoing.
    await _syncLog(dayIndex, exId,
        effectiveWeight: wasNotDone ? effectiveWeight : null,
        plannedWeight:   wasNotDone ? plannedWeight   : null);

    // Completed session edit: recalculate stats silently, no timer/voice/XP.
    if (isCompletedSession) {
      _weekPlan[dayIndex].wasEdited = true;
      await _recalculateSessionAfterEdit(dayIndex);
      return;
    }

    // ── Active workout hooks ───────────────────────────────────────────────
    if (wasNotDone) {
      final session = WorkoutSessionService.instance;
      if (!session.isActive) {
        await session.startSession(dayIndex: dayIndex);
      } else {
        await session.touchActivity();
      }

      session.addVolume(s.weight, s.reps);

      final vc = VoiceCoachService();
      final rt = RestTimerService();
      final completedAfter = ex.sets.where((x) => x.done).length;
      final totalSets = ex.sets.length;

      if (totalSets >= 2) {
        if (completedAfter == totalSets) {
          await vc.exerciseComplete(ex.name);
          rt.start(seconds: 90);
        } else if (completedAfter == totalSets - 1) {
          await vc.lastSet();
          rt.start(seconds: 90);
        } else {
          await vc.setComplete(90);
          rt.start(seconds: 90);
        }
      } else {
        await vc.setComplete(90);
        rt.start(seconds: 90);
      }

      _setRestNextContext(rt, dayIndex, exId);

      final day = _weekPlan[dayIndex];
      final allDone = day.exercises.isNotEmpty &&
          day.exercises.every((e) =>
              e.sets.isNotEmpty && e.sets.every((s) => s.done));
      if (allDone &&
          completedAfter == totalSets &&
          !day.isCompleted &&
          !day.isPendingReview) {
        day.isPendingReview = true;
        await _saveWeekPlan();
        _notify();
        await Future.delayed(const Duration(seconds: 1));
        await vc.workoutComplete(100);
      }
    } else {
      // User unchecked a set — exit pending review back to active state
      final day = _weekPlan[dayIndex];
      if (day.isPendingReview) {
        day.isPendingReview = false;
        _notify();
      }
    }
  }

  /// Finds the next incomplete exercise and sets rest-timer "up-next" context.
  void _setRestNextContext(RestTimerService rt, int dayIndex, String currentExId) {
    if (dayIndex >= _weekPlan.length) return;
    final exercises = _weekPlan[dayIndex].exercises;
    final currentIdx = exercises.indexWhere((e) => e.id == currentExId);
    if (currentIdx < 0) return;
    for (int i = currentIdx + 1; i < exercises.length; i++) {
      final next = exercises[i];
      if (next.sets.any((s) => !s.done)) {
        final hint = smartProgression(next);
        rt.setNextExercise(
          name:        next.name,
          sets:        next.sets.length,
          reps:        hint.targetReps,
          weight:      hint.nextWeight,
          unit:        next.unit,
          isBodyweight: next.bodyweight,
        );
        return;
      }
    }
  }

  Future<void> _syncLog(
    int dayIndex,
    String exId, {
    double? effectiveWeight,
    double? plannedWeight,
  }) async {
    final ex = _findEx(dayIndex, exId);
    if (ex == null) return;

    final key      = getKey(ex.baseId);
    final doneSets = ex.sets.where((s) => s.done).toList();

    // Use the session's original completion date for historical edits,
    // today's date for active workout logging.
    DateTime logDate = DateTime.now();
    if (_isValidDayIndex(dayIndex)) {
      final d = _weekPlan[dayIndex];
      if (d.isCompleted && d.completionDate != null) {
        logDate = DateTime.tryParse(d.completionDate!) ?? DateTime.now();
      }
    }
    final now = logDate;

    _logs.removeWhere((l) =>
        l.exercise == key &&
        l.date.year  == now.year &&
        l.date.month == now.month &&
        l.date.day   == now.day);

    // Historical best BEFORE today's entry is added — used for PR detection below
    final prevBestWeight = doneSets.isNotEmpty ? getPR(key, ex.unit) : 0.0;
    final prevBestReps   = doneSets.isNotEmpty ? getPRReps(key) : 0;

    // RFC-002.1: captured outside the if-block for enqueue after the save.
    WorkoutLog? syncedLog;

    if (doneSets.isNotEmpty) {
      ExSet best = doneSets.first;
      for (final s in doneSets.skip(1)) {
        if (ex.unit == 'reps') {
          if (s.reps > best.reps) best = s;
        } else {
          // Higher weight wins; same weight + more reps also wins
          if (s.weight > best.weight) {
            best = s;
          } else if (s.weight == best.weight && s.reps > best.reps) {
            best = s;
          }
        }
      }

      var muscleKey = normalizeMuscle(ex.category);
      if (muscleKey.isEmpty || muscleKey == 'other') {
        final detected = WorkoutClassifier.classifyMuscle(ex.name);
        muscleKey = normalizeMuscle(detected);
      }
      // Override: if generic "biceps" but exercise is clearly tricep → fix
      // Use exercise name to determine correct biceps vs triceps
      if (muscleKey == 'biceps' || muscleKey == 'triceps') {
        final byName = getMuscleGroup(ex.name);
        if (byName == 'biceps' || byName == 'triceps') {
          muscleKey = byName;
        }
      }

      if (muscleKey.isNotEmpty && muscleKey != 'other') {
        _lastMuscleTrained[muscleKey] = now;
      }

      // RFC-006: actualW is what the athlete actually lifted.
      // effectiveWeight is passed from the done handler when an adaptive session
      // is active. Falls back to best.weight (planner) for non-adaptive sessions.
      final actualW = (effectiveWeight ?? best.weight).clamp(0.0, 500.0);

      syncedLog = WorkoutLog(
        exercise:      key,
        date:          now,
        weight:        actualW,
        reps:          best.reps.clamp(0, 999),
        minutes:       ex.unit == 'min' ? actualW.toInt() : 0,
        muscleGroup:   muscleKey.isNotEmpty ? muscleKey : null,
        plannedWeight: plannedWeight,  // null for non-adaptive sessions
      );
      _logs.add(syncedLog);

      _logs.sort((a, b) => a.date.compareTo(b.date));
      if (_logs.length > _maxLogs) {
        _logs = _logs.sublist(_logs.length - _maxLogs);
      }

      final pr = getPR(key, ex.unit);
      if (pr > 0) {
        final val = ex.unit == 'reps' ? best.reps.toDouble() : actualW;
        final gap = pr - val;
        final gapPct = gap / pr;
        if (gap > 0 && gapPct <= 0.10) {
          _nearMissCache[key] = {
            'value': val, 'gap': gap, 'unit': ex.unit, 'date': _todayStr,
          };
        }
      }

      // ── PR detection ─────────────────────────────────────────
      // Compare today's best set against the historical best (captured before this session).
      // Uses actualW (effective weight) so a deload session cannot trigger a false PR.
      final isBodyweight = ex.unit == 'reps';
      final isWeightPR   = !isBodyweight && actualW > prevBestWeight && prevBestWeight >= 0;
      final isRepsPR     = !isWeightPR &&
          actualW == prevBestWeight &&
          best.reps > prevBestReps &&
          prevBestReps > 0;
      final isBodyweightPR = isBodyweight && best.reps > prevBestReps && prevBestReps > 0;
      if (isWeightPR || isRepsPR || isBodyweightPR) {
        _addRecentPR(PREvent(
          exercise: ex.name,
          weight:   actualW,
          reps:     best.reps,
          date:     now,
          isRepPR:  isRepsPR || isBodyweightPR,
        ));
      }
    }

    await _saveLogs();
    await _saveLastMuscleTrained();
    // RFC-002.1: enqueue per-document cloud sync op (dormant: sync_mode=disabled)
    if (syncedLog != null) {
      await WorkoutLogRepository.instance.enqueueUpsert(
        syncedLog,
        OutboxService.instance.writerDeviceId,
      );
    }
    notifyListeners();
  }

  void _addRecentPR(PREvent event) {
    // One entry per exercise — keep the most recent
    _recentPRs.removeWhere((p) => p.exercise == event.exercise);
    _recentPRs.add(event);
    // Expire entries older than 14 days
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    _recentPRs.removeWhere((p) => p.date.isBefore(cutoff));
  }

  /// Recalculates HistoryEntry volume and set count after a completed session
  /// is edited (backfilled). Call after any set change on a completed day.
  Future<void> _recalculateSessionAfterEdit(int dayIndex) async {
    if (!_isValidDayIndex(dayIndex)) return;
    final day = _weekPlan[dayIndex];
    if (!day.isCompleted) return;

    final newVolume = _calcVolume(day);

    final dateStr = day.completionDate;
    final histIdx = _history.indexWhere((h) {
      if (dateStr != null && h.date != dateStr) { return false; }
      return h.workoutName == day.title;
    });

    if (histIdx >= 0) {
      final old = _history[histIdx];
      _history[histIdx] = HistoryEntry(
        id:              old.id,
        date:            old.date,
        workoutName:     old.workoutName,
        durationMinutes: old.durationMinutes,
        totalVolume:     newVolume,
        exerciseCount:   day.exercises.length,
        setCount:        day.exercises.fold(0, (v, e) => v + e.sets.length),
      );
    }

    await Future.wait([
      _saveWeekPlan(),
      _saveHistory(),
      _saveLogs(),
    ]);
    _notify();
  }

  // ═════════════════════════════════════════════════════════
  // MUSCLE RECOVERY
  // ═════════════════════════════════════════════════════════
  double getMuscleRecovery(String muscle) {
    if (muscle.trim().isEmpty) { return 97; }
    final key = normalizeMuscle(muscle);
    if (key.isEmpty) { return 97; }

    final last = _lastMuscleTrained[key];
    if (last == null) { return 97; }

    final hours = DateTime.now().difference(last).inHours;
    // Age-adjusted max recovery window: older users need longer recovery.
    final ageMult  = _ageRecoveryMultiplier(_userAge);
    final maxHours = ((_muscleRecoveryHours[key] ?? 48) * ageMult).round();
    if (maxHours <= 0) { return 97; }

    double recovery = ((hours / maxHours) * 100).clamp(0.0, 100.0).roundToDouble();

    final streak = _streak.currentStreak;
    if (streak >= 21)      { recovery *= 0.90; }
    else if (streak >= 10) { recovery *= 0.94; }
    else if (streak >= 5)  { recovery *= 0.97; }

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
    final total = muscles.fold<double>(0.0, (total, muscle) {
      return total + (mood != null
          ? getMuscleRecoveryWithMood(muscle, mood)
          : getMuscleRecovery(muscle));
    });
    return (total / muscles.length).round().clamp(10, 97);
  }

  List<MuscleRecovery> muscleRecoveryList({MoodType? mood}) {
    const muscles = [
      'Chest', 'Back', 'Legs', 'Calves', 'Shoulders', 'Biceps', 'Triceps', 'Core',
    ];
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

  /// Returns 'improving' | 'plateau' | 'declining' | '' for an exercise.
  /// Returns '' when fewer than 4 sessions logged (insufficient data).
  String getExerciseTrend(String baseId) {
    final logs = getLogsForExercise(baseId);
    if (logs.length < 4) { return ''; }
    final trend = AIEngine.getStrengthTrend(logs, baseId);
    return trend == 'insufficient_data' ? '' : trend;
  }

  /// Trends for every exercise in today's plan — used by the planner UI.
  Map<String, String> get todayExerciseTrends {
    final result = <String, String>{};
    for (final ex in todayPlan.exercises) {
      final trend = getExerciseTrend(ex.baseId);
      if (trend.isNotEmpty) result[ex.baseId] = trend;
    }
    return result;
  }

  double getPR(String key, String unit) =>
      ProgressionService.getPR(_logs, key, unit);

  int getPRReps(String key) =>
      ProgressionService.getPRReps(_logs, key);

  String? getPRDate(String key, String unit) =>
      ProgressionService.getPRDate(_logs, key, unit);

  bool isNewPR(String key, double weight, int reps, String unit,
      {int minutes = 0}) =>
      ProgressionService.isNewPR(_logs, key, weight, reps, unit,
          minutes: minutes);

  PRResult checkPRResult(String key, double weight, int reps, String unit) =>
      ProgressionService.checkPRResult(_logs, key, weight, reps, unit);

  Future<void> addLog(String key, double weight, int reps, DateTime date,
      {int minutes = 0}) async {
    _logs.removeWhere((l) =>
        l.exercise == key &&
        l.date.year  == date.year &&
        l.date.month == date.month &&
        l.date.day   == date.day);
    final addedLog = WorkoutLog(
      exercise:    key,
      date:        date,
      weight:      weight.clamp(0, 500),
      reps:        reps.clamp(0, 999),
      minutes:     minutes,
      muscleGroup: getMuscleGroup(key),
    );
    _logs.add(addedLog);
    _logs.sort((a, b) => a.date.compareTo(b.date));
    if (_logs.length > _maxLogs) {
      _logs = _logs.sublist(_logs.length - _maxLogs);
    }
    _notify();
    await _saveLogs();
    // RFC-002.1: enqueue per-document cloud sync op (dormant: sync_mode=disabled)
    await WorkoutLogRepository.instance.enqueueUpsert(
      addedLog,
      OutboxService.instance.writerDeviceId,
    );
  }

  String? nearMissMessage(String exerciseKey, String unit) =>
      ProgressionService.nearMissMessage(_logs, exerciseKey, unit);

  // ═════════════════════════════════════════════════════════
  // PR PREDICTION ENGINE — Premium AI Insight
  // ═════════════════════════════════════════════════════════
  String? predictNextPR(String exerciseKey, String unit) =>
      ProgressionService.predictNextPR(_logs, exerciseKey, unit);

  // ═════════════════════════════════════════════════════════
  // PROGRESSION ENGINE
  // ═════════════════════════════════════════════════════════
  SetProgressionHint analyzeProgression(
    PlannedExercise ex, {
    String goal      = 'muscle_gain',
    String movement  = 'isolation',
    // Equipment defaults omitted — WeightRounder resolves '' to dumbbell step.
    // Pass ex.equipment directly; no inline fallback here.
  }) =>
      ProgressionService.analyzeProgression(ex,
          goal: goal, equipment: ex.equipment, movement: movement);

  String getTrainerMessage(PlannedExercise ex) =>
      analyzeProgression(ex).message;

  /// Same logic as PR celebration screen: uses calculateWorkoutFeedback()
  /// when history exists, falls back to analyzeProgression() for first session.
  SetProgressionHint smartProgression(PlannedExercise ex) {
    final fb = computeFeedback(ex);
    if (fb != null) {
      return SetProgressionHint(
        message:    fb.message,
        nextWeight: fb.nextWeight,
        targetReps: fb.nextReps,
      );
    }
    return analyzeProgression(ex);
  }

  /// Smart AI feedback — uses unified central function from pr_engine.
  String getSmartFeedback(PlannedExercise ex) {
    final fb = computeFeedback(ex);
    return fb?.message ?? '';
  }

  /// Returns the full WorkoutFeedback (message + next target + status).
  /// Used by both planner UI and PR celebration.
  pre.WorkoutFeedback? computeFeedback(PlannedExercise ex) {
    final key = getKey(ex.baseId);

    // All past logs for this exercise (excludes today) — sorted newest first
    final today = DateTime.now();
    final history = _logs
        .where((l) =>
            l.exercise == key &&
            !(l.date.year  == today.year &&
              l.date.month == today.month &&
              l.date.day   == today.day))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    // ALL-TIME best across all past sessions — prevents false "NEW PR" vs stale baseline
    // e.g. user hit 40kg 2 months ago, recent sessions at 20kg → don't show "NEW PR" at 30kg
    final allTimeBest = history.isNotEmpty
        ? history.reduce((a, b) => a.weight >= b.weight ? a : b)
        : null;

    // ── PRIORITY 1: Use BEST done set today (max weight, not last) ──
    final doneSets = ex.sets.where((s) => s.done).toList();
    if (doneSets.isNotEmpty) {
      final best = doneSets.reduce((a, b) => a.weight >= b.weight ? a : b);
      return pre.calculateWorkoutFeedback(
        weight:             best.weight,
        reps:               best.reps,
        previousBestWeight: allTimeBest?.weight ?? 0,
        previousBestReps:   allTimeBest?.reps   ?? 0,
        isBodyweight:       ex.bodyweight,
        unit:               ex.unit,
        equipment:          ex.equipment,
      );
    }

    // ── PRIORITY 2: No sets done yet — show PLANNED target as preview ──
    if (ex.sets.isEmpty) { return null; }
    final planned = ex.sets.first;

    if (allTimeBest != null) {
      return pre.calculateWorkoutFeedback(
        weight:             planned.weight,
        reps:               planned.reps,
        previousBestWeight: allTimeBest.weight,
        previousBestReps:   allTimeBest.reps,
        isBodyweight:       ex.bodyweight,
        unit:               ex.unit,
        equipment:          ex.equipment,
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
      msg = '💪 Heavy day — $reps reps · build strength';
      nextW = planned.weight;
      nextR = reps;
    } else if (reps > 12) {
      msg = '🔥 High volume — $reps reps · endurance focus';
      nextW = planned.weight;
      nextR = reps;
    } else {
      msg = '🎯 $reps reps — control the tempo';
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
    if (logs.isEmpty) { return 20; }
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
    if (currentWeight <= 0) { return 20; }
    if (reps >= targetReps + 2) { return (currentWeight + 2.5).clamp(0, 500); }
    if (reps <= targetReps - 3) { return (currentWeight - 2.5).clamp(0, 500); }
    return currentWeight.clamp(0, 500);
  }

  // ═════════════════════════════════════════════════════════
  // DAY COMPLETION
  // ═════════════════════════════════════════════════════════
  Future<DayCompletionResult> markDayComplete(
      int dayIndex, int durationMin) async {
    if (!_isValidDayIndex(dayIndex)) { return DayCompletionResult.empty(); }

    final day = _weekPlan[dayIndex];
    if (day.isCompleted) { return DayCompletionResult.empty(); }

    // Only today's plan can be newly completed.
    // A non-today day may finish if it reached isPendingReview (all sets
    // confirmed before the day rolled over), OR if it is yesterday and has
    // logged sets — the athlete trained but forgot to press Complete.
    // Done sets are the evidence; days without them stay incomplete.
    final yesterdayIdx = (todayIndex - 1 + 7) % 7;
    final hasDoneSets  =
        day.exercises.any((e) => e.sets.any((s) => s.done));
    final isForgottenYesterday =
        dayIndex == yesterdayIdx && hasDoneSets;
    if (dayIndex != todayIndex &&
        !day.isPendingReview &&
        !isForgottenYesterday) {
      return DayCompletionResult.empty();
    }

    final safeDuration = durationMin.clamp(0, 600);

    day.isPendingReview = false;
    day.isCompleted     = true;
    day.durationMinutes = safeDuration;
    day.completionDate  = _todayStr;

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
    _savePlanDebounce?.cancel(); // flush any pending debounce — complete is always immediate

    await Future.wait([
      _saveWeekPlan(),
      _saveStreak(),
      _saveHistory(),
    ]);

    // RFC-002.5: push session to cloud after local saves complete.
    // Non-blocking — completion UI is not gated on cloud latency.
    _syncHistoryEntryToCloud(_history.first);

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
              0, (total, s) => total + (s.weight * s.reps));
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
        planName:       _weekPlan.isEmpty
            ? 'My Plan'
            : _weekPlan.firstWhere(
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
    if (completed.isEmpty) { return 0; }

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
    if (countDays == 0) { return 0; }
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
  /// Compute mesocycle week (1–4) from total completed workouts.
  /// 16-workout cycle (~4 sessions/week × 4 weeks).
  int get mesocycleWeek {
    final pos = _streak.totalWorkouts % 16;
    if (pos < 4)  return 1;
    if (pos < 8)  return 2;
    if (pos < 12) { return 3; }
    return 4; // deload
  }

  bool get isDeloadWeek => mesocycleWeek == 4;

  Future<void> generateSmartPlan({
    required String goal,
    required String level,
    String splitOverride  = '',
    int gymDays           = 3,
    double weightKg       = 75.0,
    String activityLevel  = 'Moderate',
    String gender         = '',
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
        splitOverride: splitOverride,
        gymDays:       gymDays,
        weightKg:      weightKg,
        activityLevel: activityLevel,
        gender:        gender,
        mesocycleWeek: mesocycleWeek,
      );
      final historyNames =
          _logs.map((e) => e.exercise.split('_').first).toList();
      final newPlan  = <DayPlan>[];
      final modifier = _modifier;

      // Derive the per-day type list from the same split AIEngine used so
      // that bro-split / arnold-split / any override is honoured correctly.
      final weekTypes = AIEngine.weekTypesForSplit(
        level: level, goal: goal, splitOverride: splitOverride, gymDays: gymDays,
      );

      for (int i = 0; i < 7; i++) {
        final exNames = result.plan[_dayNames[i]] ?? [];
        if (exNames.isEmpty || exNames.first == 'Rest') {
          newPlan.add(DayPlan(
            id:        IdHelper.uuid(),
            dayIndex:  i,
            title:     'Rest Day',
            exercises: [],
            isRestDay: true,
          ));
          continue;
        }

        // Use the actual type from the resolved split (e.g. 'Chest', 'Back')
        // rather than the hardcoded PPL fallback in _splitTypeForDay.
        final type = (i < weekTypes.length) ? weekTypes[i] : _splitTypeForDay(i, level, goal);
        final exs = AIEngine.generateDayWorkout(
          goal:          goal,
          level:         level,
          type:          type,
          history:       historyNames,
          weakMuscle:    _weakMuscleHint,
          isBeginner:    isBeginnerPhase,
          bodyweightOnly: _travelMode,
          weightKg:      weightKg,
          activityLevel: activityLevel,
          gender:        gender,
          mesocycleWeek: mesocycleWeek,
        );

        final planned = exs.map((ex) {
          final name      = (ex['name'] as String?) ?? 'Exercise';
          final isBW      = ex['bodyweight'] == true;
          final equipment = ex['equipment'] as String? ?? 'dumbbell';

          // Always 3 sets — user adjusts manually
          const exSets = 3;

          // Use last logged weight+reps; fall back to AIEngine smart values for new users
          final lastLog = isBW ? null : _lastSession(name, equipment: equipment);
          final hasHistory = lastLog != null && lastLog.weight > 0;
          final baseW  = (ex['smartWeight'] as num?)?.toDouble() ?? 20.0;
          final adjW   = WeightRounder.round(baseW * modifier, equipment);
          final weight = isBW ? 0.0 : (hasHistory ? lastLog.weight : adjW.clamp(1.0, 500.0));
          final reps   = hasHistory ? lastLog.reps : (ex['smartReps'] as int? ?? 10).clamp(1, 50);

          return PlannedExercise(
            id:         IdHelper.uuid(),
            baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
            name:       name,
            category:   ex['muscle']    as String? ?? '',
            emoji:      ex['emoji']     as String? ?? '💪',
            type:       ex['type']      as String? ?? '',
            unit:       isBW ? 'reps' : (ex['unit'] as String? ?? 'kg'),
            bodyweight: isBW,
            equipment:  equipment,
            sets: List.generate(exSets, (_) => ExSet(
              id:     IdHelper.uuid(),
              reps:   reps,
              weight: weight,
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
          title:     'Rest Day',
          exercises: [],
          isRestDay: true,
        ));
      }

      // Sunday (index 6) always rest
      if (newPlan.length >= 7 && !newPlan[6].isRestDay) {
        newPlan[6] = DayPlan(
          id:        IdHelper.uuid(),
          dayIndex:  6,
          title:     'Rest Day',
          exercises: [],
          isRestDay: true,
        );
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
    double weightKg      = 75.0,
    String activityLevel = 'Moderate',
    String gender        = '',
  }) async {
    if (!_isValidDayIndex(dayIndex)) return;

    final day = _weekPlan[dayIndex];

    if (type.toLowerCase() == 'rest') {
      day
        ..title = 'Rest Day'
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
      goal:          goal,
      level:         level,
      type:          type,
      history:       lastWorkoutNames,
      weakMuscle:    _weakMuscleHint,
      isBeginner:    isBeginnerPhase,
      weightKg:      weightKg,
      activityLevel: activityLevel,
      gender:        gender,
      mesocycleWeek: mesocycleWeek,
    );

    final classifiedType = exs.isNotEmpty
        ? WorkoutClassifier.classifyDayFromExercises(
            exs.map((e) => e['name'] as String? ?? '').toList())
        : type;
    day.title = _formatTitle(classifiedType);

    final modifier = _modifier;
    final sets     = _recSets;

    for (final ex in exs) {
      final name      = (ex['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final isBW      = ex['bodyweight'] == true;
      final equipment = ex['equipment'] as String? ?? 'dumbbell';
      final exSets    = (ex['smartSets'] as int? ?? sets).clamp(1, 6);
      final baseW     = (ex['smartWeight'] as num?)?.toDouble() ?? 20.0;
      final adjW      = isBW ? 0.0 : WeightRounder.round(baseW * modifier, equipment);
      day.exercises.add(PlannedExercise(
        id:         IdHelper.uuid(),
        baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        name:       name,
        category:   ex['muscle']    as String? ?? '',
        emoji:      ex['emoji']     as String? ?? '💪',
        type:       ex['type']      as String? ?? '',
        unit:       isBW ? 'reps' : (ex['unit'] as String? ?? 'kg'),
        bodyweight: isBW,
        sets: List.generate(exSets, (_) => ExSet(
          id:     IdHelper.uuid(),
          reps:   (ex['smartReps'] as int? ?? 10).clamp(1, 50),
          weight: adjW.clamp(0.0, 500.0),
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
          title:     'Rest Day',
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
              category: WorkoutClassifier.classifyMuscle(safeName),
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

      final splitType = result.dayTypes[entry.key] ?? _typeFromNames(rawExercises);
      _weekPlan[idx] = DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  idx,
        title:     _formatTitle(splitType),
        exercises: exercises,
        isRestDay: exercises.isEmpty,
      );
    }

    _validateAndFixWeekPlan();
    await _saveWeekPlan();
    _notify();
  }


  Future<void> applySingleDayWorkout({
    required int dayIndex,
    required Map<String, dynamic> workout,
  }) async {
    if (!_isValidDayIndex(dayIndex)) return;

    final rawExercises = workout['exercises'];

    if (rawExercises == null || rawExercises is! List || rawExercises.isEmpty) {
      debugPrint('❌ Invalid single day workout');
      return;
    }

    final exercises = <PlannedExercise>[];

    for (final e in rawExercises) {
      if (e is! Map) continue;

      final ex = Map<String, dynamic>.from(e);
      var name = (ex['name'] as String?)?.trim() ?? '';

      // Fallback: lookup name from exercise_id if name is empty
      if (name.isEmpty) {
        final id = (ex['exercise_id'] as String?)?.trim() ?? '';
        if (id.isNotEmpty) {
          final found = ExerciseData.list.firstWhere(
            (item) => item['id'] == id,
            orElse: () => {},
          );
          name = (found['name'] as String?)?.trim() ?? '';
          // Last fallback: derive from id (push_chest_bench_press → Bench Press)
          if (name.isEmpty) {
            name = id.split('_').skip(2).map((w) =>
                w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)
            ).join(' ');
          }
        }
      }

      if (name.isEmpty) continue;

      final setCount = (ex['sets'] is int
              ? ex['sets']
              : int.tryParse(ex['sets']?.toString() ?? '') ?? 3)
          .clamp(1, 6);

      final repsText = ex['reps']?.toString() ?? '10';

      final reps = int.tryParse(
            repsText.split('-').first.trim(),
          ) ??
          10;

      exercises.add(
        PlannedExercise(
          id: IdHelper.uuid(),
          baseId: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name: name,
          category: WorkoutClassifier.classifyMuscle(name),
          emoji: '💪',
          type: WorkoutClassifier.classifyExercise(name),
          unit: 'kg',
          bodyweight: false,
          sets: List.generate(
            setCount,
            (_) => ExSet(
              id: IdHelper.uuid(),
              reps: reps,
              weight: 0,
            ),
          ),
        ),
      );
    }

    final old = _weekPlan[dayIndex];
    // Preserve any completed day — including today. A replan fired right
    // after finishing a session must not erase that session's completion.
    final wasCompleted = old.isCompleted && dayIndex <= todayIndex;
    final newDay = DayPlan(
      id: IdHelper.uuid(),
      dayIndex: dayIndex,
      title: workout['focus']?.toString() ?? 'Workout',
      exercises: exercises,
      isRestDay: exercises.isEmpty,
    );
    if (wasCompleted) {
      newDay.isCompleted     = true;
      newDay.completionDate  = old.completionDate;
      newDay.durationMinutes = old.durationMinutes;
    }
    _weekPlan[dayIndex] = newDay;

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

    // Snapshot existing completion state so past-day completions survive a plan replace
    final oldPlan = List<DayPlan>.from(_weekPlan);

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
          title:     'Rest Day',
          exercises: [],
          isRestDay: true,
        ));
        continue;
      }

      final exercises = rawExercises.map<PlannedExercise?>((e) {
        if (e is! Map) { return null; }
        final ex = Map<String, dynamic>.from(e);

        final exerciseId =
            (ex['exercise_id'] as String?)?.trim();

        Map<String, dynamic>? dbExercise;

        if (exerciseId != null && exerciseId.isNotEmpty) {
          dbExercise = ExerciseData.getById(exerciseId);
        }

        final name =
            (dbExercise?['name'] as String?)?.trim() ??
            (ex['name'] as String?)?.trim() ??
            '';

        if (name.isEmpty) { return null; }

        // Detect bodyweight via flag OR by exercise name
        final isBW = ex['bodyweight'] == true || _isBodyweightByName(name);
        final equipment = ex['equipment'] as String? ?? 'dumbbell';

        // Always 3 sets — user adjusts manually if needed
        const setCount = 3;

        // Use last logged weight + reps for this exercise (not AI defaults)
        final last = isBW
            ? (weight: 0.0, reps: 10)
            : _lastSession(name, equipment: equipment);

        return PlannedExercise(
          id:         IdHelper.uuid(),
          baseId:     name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name:       name,
          category:   WorkoutClassifier.classifyMuscle(name),
          emoji:      _getEmojiFromName(name),
          type:       ex['type'] as String? ?? 'strength',
          unit:       isBW ? 'reps' : 'kg',
          bodyweight: isBW,
          sets: List.generate(setCount, (_) => ExSet(
            id:     IdHelper.uuid(),
            reps:   last.reps,
            weight: last.weight,
            done:   false,
          )),
        );
      }).whereType<PlannedExercise>().toList();

      final focus = (dayMap['focus'] as String?)?.trim();
      // Preserve completion state for past days AND today so the planner
      // still shows ✓ — a replan after today's session must not erase it.
      final old = i < oldPlan.length ? oldPlan[i] : null;
      final wasCompleted = old?.isCompleted == true && i <= todayIndex;
      final newDay = DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  i,
        title:     (focus != null && focus.isNotEmpty) ? focus : 'Workout',
        exercises: exercises,
        isRestDay: exercises.isEmpty,
      );
      if (wasCompleted) {
        newDay.isCompleted    = true;
        newDay.completionDate = old!.completionDate;
        newDay.durationMinutes = old.durationMinutes;
      }
      newPlan.add(newDay);
    }

    while (newPlan.length < 7) {
      newPlan.add(DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  newPlan.length,
        title:     'Rest Day',
        exercises: [],
        isRestDay: true,
      ));
    }

    // Sunday (index 6) is always rest — gym closed / recovery day
    if (newPlan.length >= 7 && !newPlan[6].isRestDay) {
      newPlan[6] = DayPlan(
        id:        IdHelper.uuid(),
        dayIndex:  6,
        title:     'Rest Day',
        exercises: [],
        isRestDay: true,
      );
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
    if (_logs.isEmpty) { return []; }
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
          0, (total, l) => total + (l.weight * (l.reps > 0 ? l.reps : 1)));

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
  // Debounced save — coalesces rapid set-tick writes into a single disk op.
  // Callers that need an immediate save (markDayComplete) must cancel this
  // first and call _saveWeekPlan() directly.
  void _debouncedSave() {
    _savePlanDebounce?.cancel();
    _savePlanDebounce = Timer(
      const Duration(milliseconds: 1500),
      () { _saveWeekPlan(); },
    );
  }

  Future<void> _saveWeekPlan() async {
    _savePlanDebounce?.cancel(); // if called directly, no point firing later too
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
    // RFC-002.1: gate legacy blob sync — run only while new sync is disabled.
    // When sync_mode advances beyond disabled, the per-document outbox takes
    // over and this legacy path is permanently retired.
    if (!OutboxService.instance.syncMode.isActive) {
      _scheduleCloudSync();
    }
  }

  Timer? _cloudSyncDebounce;
  void _scheduleCloudSync() {
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce = Timer(const Duration(seconds: 3), _syncLogsToCloud);
  }

  Future<void> _syncLogsToCloud() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final recentLogs = _logs.length > 200
          ? _logs.sublist(_logs.length - 200)
          : _logs;
      await FirebaseFirestore.instance
          .collection('workout_history')
          .doc(uid)
          .set({
            'logs': recentLogs.map((l) => l.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
            'totalLogs': _logs.length,
          }, SetOptions(merge: true));
      debugPrint('☁️ Synced ${recentLogs.length} logs to cloud');
    } catch (e) {
      debugPrint('Cloud log sync failed: $e');
    }
  }

  // RFC-002.5 §6 — fire-and-forget per-session cloud write.
  // Called from markDayComplete after local saves complete.
  // Also used for incremental imports from HealthSyncEngine (1–50 entries).
  // Firestore SDK offline persistence handles retry on reconnect.
  // RFC-002.6B: writes externalSource/externalId when non-null so that
  // reinstall + cloud restore can correctly deduplicate imported workouts.
  Future<void> _syncHistoryEntryToCloud(HistoryEntry entry) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final data = <String, dynamic>{
        'id':              entry.id,
        'date':            entry.date,
        'workoutName':     entry.workoutName,
        'durationMinutes': entry.durationMinutes,
        'totalVolume':     entry.totalVolume,
        'xpEarned':        entry.xpEarned,
        'sv':              1,
      };
      if (entry.externalSource != null) data['externalSource'] = entry.externalSource;
      if (entry.externalId     != null) data['externalId']     = entry.externalId;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history_entries')
          .doc(entry.id)
          .set(data);
      debugPrint('☁️ History entry synced: ${entry.id} (${entry.date})');
    } catch (e) {
      debugPrint('History entry sync failed: $e');
      // Firestore SDK queues the write offline — no manual retry needed.
    }
  }

  // RFC-002.6B — bulk WriteBatch upload for initial health import (since: epoch).
  // Uses the same 500-per-batch pattern as backfillHistoryIfNeeded.
  // Must not be called for incremental sync — use _syncHistoryEntryToCloud there.
  Future<void> _batchSyncEntriesToCloud(List<HistoryEntry> entries) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || entries.isEmpty) return;
      final historyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history_entries');
      const batchSize = 500;
      for (int i = 0; i < entries.length; i += batchSize) {
        final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
        final chunk = entries.sublist(i, end);
        final batch = FirebaseFirestore.instance.batch();
        for (final entry in chunk) {
          final data = <String, dynamic>{
            'id':              entry.id,
            'date':            entry.date,
            'workoutName':     entry.workoutName,
            'durationMinutes': entry.durationMinutes,
            'totalVolume':     entry.totalVolume,
            'xpEarned':        entry.xpEarned,
            'sv':              1,
          };
          if (entry.externalSource != null) data['externalSource'] = entry.externalSource;
          if (entry.externalId     != null) data['externalId']     = entry.externalId;
          batch.set(historyRef.doc(entry.id), data);
        }
        await batch.commit();
      }
      debugPrint('☁️ Batch synced ${entries.length} imported entries');
    } catch (e) {
      debugPrint('_batchSyncEntriesToCloud failed: $e');
    }
  }

  // RFC-002.6B — merge imported HistoryEntry records into local history.
  //
  // TWO-KEY DEDUP:
  //   Imported entries (externalSource + externalId non-null):
  //     reject if (externalSource, externalId) already exists in _history.
  //   Native entries (externalSource == null):
  //     reject if id already exists in _history.
  //
  // SYNC MODE:
  //   isInitialImport = true  → WriteBatch (500-entry chunks, first-ever sync)
  //   isInitialImport = false → per-entry _syncHistoryEntryToCloud (incremental)
  //
  // This is the ONLY WorkoutProvider method that HealthSyncEngine calls.
  // package:health types must never enter this method.
  Future<void> mergeImportedHistory(
    List<HistoryEntry> imported, {
    bool isInitialImport = false,
  }) async {
    if (imported.isEmpty) return;

    // Build dedup sets from existing history.
    final existingIds = _history.map((e) => e.id).toSet();
    final existingExternalKeys = <String>{};
    for (final e in _history) {
      if (e.externalSource != null && e.externalId != null) {
        existingExternalKeys.add('${e.externalSource}::${e.externalId}');
      }
    }

    // Filter to genuinely new entries only.
    final newEntries = <HistoryEntry>[];
    for (final entry in imported) {
      if (entry.externalSource != null && entry.externalId != null) {
        final key = '${entry.externalSource}::${entry.externalId}';
        if (!existingExternalKeys.contains(key)) newEntries.add(entry);
      } else {
        if (!existingIds.contains(entry.id)) newEntries.add(entry);
      }
    }

    if (newEntries.isEmpty) return;

    _history = [..._history, ...newEntries];
    _history.sort((a, b) => b.date.compareTo(a.date));
    await _saveHistory();

    // Cloud sync — batch for initial import, per-entry for incremental.
    if (isInitialImport) {
      await _batchSyncEntriesToCloud(newEntries);
    } else {
      for (final entry in newEntries) {
        _syncHistoryEntryToCloud(entry).ignore();
      }
    }

    notifyListeners();
    debugPrint('☁️ mergeImportedHistory: +${newEntries.length} entries '
        '(${isInitialImport ? "batch" : "incremental"}, '
        'total=${_history.length})');
  }

  // RFC-002.5 §7 — pull session history from Firestore, merge with local,
  // then reconcile derived state (streaks, badges).
  // Called from LoginScreen._signIn() after tryRestoreFromCloud().
  // Must NOT be called on normal app launch — restore only, not every init.
  Future<bool> tryRestoreHistoryFromCloud() async {
    // Re-entrant restore guard: prevents a second concurrent call to
    // tryRestoreHistoryFromCloud (e.g. double sign-in tap) from running
    // while the first is in progress. Does NOT guard markDayComplete —
    // Dart's cooperative concurrency makes the synchronous merge sections
    // (steps 2–3 below) atomic between await suspension points.
    if (_isRestoringHistory) return false;
    _isRestoringHistory = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      // ── 1. Fetch from Firestore ──────────────────────────────────────
      List<HistoryEntry> cloudEntries = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('history_entries')
            .orderBy('date', descending: true)
            .limit(2000)
            .get()
            .timeout(const Duration(seconds: 15));

        for (final doc in snapshot.docs) {
          try {
            cloudEntries.add(HistoryEntry.fromJson(
                Map<String, dynamic>.from(doc.data())));
          } catch (e) {
            debugPrint('history_entries: skipping malformed doc ${doc.id}: $e');
          }
        }
      } catch (e) {
        // Network failure — proceed with empty cloud list.
        // Local history is preserved; reconciliation runs against local only.
        debugPrint('history_entries fetch failed (offline?): $e');
      }

      // ── 2. Merge: union by id, local entries always retained ─────────
      final localIds = _history.map((e) => e.id).toSet();
      final newFromCloud = cloudEntries.where((e) => !localIds.contains(e.id)).toList();

      if (newFromCloud.isNotEmpty) {
        _history = [..._history, ...newFromCloud];
        // Sort newest-first so _history.first is always the latest session.
        _history.sort((a, b) => b.date.compareTo(a.date));
        await _saveHistory();
        debugPrint('☁️ History restored: +${newFromCloud.length} from cloud, '
            'total=${_history.length}');
      } else {
        debugPrint('☁️ History restore: no new cloud entries '
            '(local=${_history.length}, cloud=${cloudEntries.length})');
      }

      // ── 3. Reconcile derived state from merged history ────────────────
      await _reconcileStateFromHistory();

      notifyListeners();
      return true;
    } finally {
      _isRestoringHistory = false;
    }
  }

  // Re-entrant guard for tryRestoreHistoryFromCloud. Set true on entry,
  // cleared in finally. Does not interact with markDayComplete.
  bool _isRestoringHistory = false;

  // RFC-002.5 §7 — recompute derived streak state from the merged history.
  // Called ONLY from tryRestoreHistoryFromCloud(). Must not be called on
  // normal app launch — it is a restore-time repair, not a startup routine.
  //
  // Does NOT restore XP — XP is owned by GamificationProvider.
  // Caller is responsible for invoking GamificationProvider.recoverXPIfNeeded
  // after this method returns (Option B provider boundary).
  Future<void> _reconcileStateFromHistory() async {
    if (_history.isEmpty) return;

    // Count only native LiftOn sessions — Apple Watch imports (externalSource
    // != null) feed recovery/health metrics but must not inflate the session
    // counter, identity stage, AI maturity gates, or timeline milestones.
    final nativeHistory = _history
        .where((e) => e.externalSource == null)
        .toList(); // preserves newest-first order
    final nativeCount = nativeHistory.length;

    // ── totalWorkouts ────────────────────────────────────────────────────
    // Only update if native history has more sessions than the current counter.
    // A higher local counter means offline completions exist that are not yet
    // in the cloud window — those are real sessions and must not be erased.
    // Invariant I-05: never decrease totalWorkouts below native history evidence.
    if (nativeCount <= _streak.totalWorkouts) {
      debugPrint('🔧 reconcileHistory: counter=${_streak.totalWorkouts} '
          '>= native=$nativeCount '
          '(total incl. Watch=${_history.length}), skipping update');
      return;
    }

    _streak.totalWorkouts = nativeCount;

    // ── Training dates set (for streak computation) ──────────────────────
    // Native-only: Apple Watch walks/runs/yoga must not count as gym training
    // days for streak purposes in a strength tracker.
    final trainingDates = nativeHistory.map((e) => e.date).toSet();

    // ── longestStreak ────────────────────────────────────────────────────
    // Blocker 1 fix: never decrease. Use max(existing, computed).
    final computedLongest = _computeLongestStreak(trainingDates);
    if (computedLongest > _streak.longestStreak) {
      _streak.longestStreak = computedLongest;
    }

    // ── lastWorkoutDate ──────────────────────────────────────────────────
    // Use the most recent native LiftOn session, not the most recent Apple
    // Watch entry, so currentStreak is not kept alive by passive Watch activity.
    if (nativeHistory.isNotEmpty) {
      _streak.lastWorkoutDate = nativeHistory.first.date;
    }

    // ── currentStreak ────────────────────────────────────────────────────
    // NOT set here. checkStreakHealth() computes it from lastWorkoutDate vs
    // today, and runs on AppProvider.init(). Setting it here from historical
    // dates would ignore the time gap since reinstall.

    // ── earnedBadges ─────────────────────────────────────────────────────
    final rederived = BadgeSystem.checkNewBadges(_streak, []);
    _streak.earnedBadges = rederived.map((b) => b.id).toList();

    await _saveStreak();
    debugPrint('🔧 reconcileHistory: totalWorkouts=$nativeCount (native), '
        'appleWatch=${_history.length - nativeCount}, '
        'longestStreak=${_streak.longestStreak}, '
        'lastWorkout=${_streak.lastWorkoutDate}, '
        'badges=${_streak.earnedBadges.length}');
  }

  // RFC-002.5 §7 — compute longest consecutive-day streak from a set of
  // "YYYY-MM-DD" training date strings.
  static int _computeLongestStreak(Set<String> trainingDates) {
    if (trainingDates.isEmpty) return 0;
    final sorted = trainingDates
        .map(DateTime.parse)
        .toList()
      ..sort();

    int longest = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (diff > 1) {
        run = 1;
      }
      // diff == 0: two completions same calendar day — count the day once.
    }
    return longest;
  }

  // RFC-002.5 §9 — one-time backfill of all local HistoryEntry records to cloud.
  // Called from AppProvider.init() on every authenticated launch; returns
  // immediately once the migration flag is written (idempotent).
  Future<void> backfillHistoryIfNeeded() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      if (_history.isEmpty) return;

      final prefs = await StorageService.instance.prefs();
      final migrationVersion =
          prefs.getInt(StorageKeys.historySyncMigrationVersion) ?? 0;
      if (migrationVersion >= 1) return;

      final attempts = prefs.getInt(StorageKeys.historySyncAttempts) ?? 0;
      if (attempts >= 5) {
        debugPrint('⚠️ backfillHistoryIfNeeded: max attempts ($attempts/5) reached, giving up');
        return;
      }

      final historyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history_entries');

      // Firestore WriteBatch is capped at 500 operations.
      const batchSize = 500;
      for (int i = 0; i < _history.length; i += batchSize) {
        final end = (i + batchSize < _history.length) ? i + batchSize : _history.length;
        final chunk = _history.sublist(i, end);
        final batch = FirebaseFirestore.instance.batch();
        for (final entry in chunk) {
          batch.set(historyRef.doc(entry.id), {
            'id':              entry.id,
            'date':            entry.date,
            'workoutName':     entry.workoutName,
            'durationMinutes': entry.durationMinutes,
            'totalVolume':     entry.totalVolume,
            'xpEarned':        entry.xpEarned,
            'sv':              1,
          });
        }
        await batch.commit();
      }

      await prefs.setInt(StorageKeys.historySyncMigrationVersion, 1);
      await prefs.setInt(StorageKeys.historySyncAttempts, 0);
      debugPrint('☁️ backfillHistoryIfNeeded: ${_history.length} entries uploaded');
    } catch (e) {
      try {
        final prefs = await StorageService.instance.prefs();
        final attempts = prefs.getInt(StorageKeys.historySyncAttempts) ?? 0;
        await prefs.setInt(StorageKeys.historySyncAttempts, attempts + 1);
        debugPrint('⚠️ backfillHistoryIfNeeded failed (attempt ${attempts + 1}/5): $e');
      } catch (_) {}
    }
  }

  // RFC-002.2 — restore workout logs on login.
  //
  // Source priority:
  //   1. users/{uid}/logs  — RFC-002.1 per-document subcollection (primary)
  //   2. workout_history/{uid} — legacy blob (fallback, migration window)
  //
  // Merge strategy: UNION only. Local logs are never overwritten.
  // Cloud fills gaps; new-path documents deleted via soft-delete (deletedAt)
  // are excluded by LogsSyncAdapter.fromPayload().
  Future<bool> tryRestoreLogsFromCloud() async {
    if (_isRestoringLogs) return false;
    _isRestoringLogs = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      // ── 1. New path: users/{uid}/logs ─────────────────────────────────────
      List<WorkoutLog> cloudLogs = [];
      bool newPathHasData = false;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('logs')
            .orderBy('date', descending: false)
            .limit(5000)
            .get()
            .timeout(const Duration(seconds: 15));

        final adapter = LogsSyncAdapter();
        for (final doc in snapshot.docs) {
          final log = adapter.fromPayload(Map<String, dynamic>.from(doc.data()));
          if (log != null) cloudLogs.add(log);
        }
        newPathHasData = cloudLogs.isNotEmpty;
        debugPrint('☁️ logs restore: ${cloudLogs.length} from users/{uid}/logs');
      } catch (e) {
        debugPrint('logs restore (new path) failed: $e');
      }

      // ── 2. Legacy fallback: workout_history/{uid} blob ────────────────────
      if (!newPathHasData) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('workout_history')
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 10));
          if (doc.exists) {
            final data = doc.data();
            if (data != null && data['logs'] != null) {
              cloudLogs = (data['logs'] as List)
                  .map((e) => WorkoutLog.fromJson(
                      Map<String, dynamic>.from(e as Map)))
                  .toList();
              debugPrint(
                  '☁️ logs restore: ${cloudLogs.length} from legacy blob');
            }
          }
        } catch (e) {
          debugPrint('logs restore (legacy) failed: $e');
        }
      }

      if (cloudLogs.isEmpty) return false;

      // ── 3. Union merge — local always wins for same natural key ───────────
      final localKeys = _logs.map(_logNaturalKey).toSet();
      final newFromCloud =
          cloudLogs.where((l) => !localKeys.contains(_logNaturalKey(l))).toList();

      if (newFromCloud.isEmpty) {
        debugPrint('☁️ logs restore: no new logs '
            '(local=${_logs.length}, cloud=${cloudLogs.length})');
        return false;
      }

      _logs = [..._logs, ...newFromCloud];
      _logs.sort((a, b) => a.date.compareTo(b.date));

      final storage = StorageService.instance;
      final localData = _logs.map((l) => l.toJson()).toList();
      await Future.wait([
        storage.logsBox?.put('all_logs', localData) ?? Future.value(),
        storage.setJson(StorageKeys.logs, localData),
      ]);
      notifyListeners();
      debugPrint('☁️ logs restore: +${newFromCloud.length} new, '
          'total=${_logs.length}');
      return true;
    } catch (e) {
      debugPrint('tryRestoreLogsFromCloud failed: $e');
      return false;
    } finally {
      _isRestoringLogs = false;
    }
  }

  bool _isRestoringLogs = false;

  // Natural key matching LogsSyncAdapter.docIdFor — used to dedup on restore.
  static String _logNaturalKey(WorkoutLog l) {
    final date = l.date.toIso8601String().substring(0, 10);
    return '${l.normalizedExercise}_${date}_${l.weight}_${l.reps}_${l.minutes}';
  }

  // _reconcileStreakWithRestoredLogs() removed — RFC-002.5.
  // Replaced by _reconcileStateFromHistory() which derives session count
  // from HistoryEntry (one-per-session) instead of WorkoutLog
  // (one-per-exercise-per-day, capped, best-set-only, wrong source).

  // ═════════════════════════════════════════════════════════
  // RESET
  // ═════════════════════════════════════════════════════════
  /// Check if streak needs reset based on last workout date + travel mode.
  /// Call this on app load.
  Future<void> checkStreakHealth({required bool travelModeActive}) async {
    if (_streak.lastWorkoutDate.isEmpty) return;
    if (travelModeActive) return; // freeze — no reset

    try {
      final last = DateTime.parse(_streak.lastWorkoutDate);
      final now = DateTime.now();
      final daysSince = now.difference(
        DateTime(last.year, last.month, last.day),
      ).inDays;

      // 2+ days gap (allowing 1 rest day) = streak broken
      if (daysSince > 1 && _streak.currentStreak > 0) {
        _streak.currentStreak = 0;
        await _saveStreak();
        notifyListeners();
      }
    } catch (_) {}
  }

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
  /// Scientific muscle classification (Israetel/Nippard hypertrophy framework)
  /// • Rear delts → BACK (pull day, trained with rows/pulls)
  /// • Biceps & Triceps tracked separately (independent recovery)
  /// • Front delts/Side delts → SHOULDERS (push family)
  static String normalizeMuscle(String muscle) {
    final m = muscle.toLowerCase();

    // Rear delt is BACK family (Schoenfeld 2020, Nippard)
    if (m.contains('rear delt') || m.contains('rear-delt') ||
        m.contains('reardelt') || m.contains('posterior delt')) {
      return 'back';
    }

    if (m.contains('shoulder') || m.contains('delt')) { return 'shoulders'; }

    if (m == 'calves' || m == 'calf') { return 'calves'; }

    if (m.contains('leg') || m.contains('glute') ||
        m.contains('hamstring') || m.contains('calf') ||
        m.contains('quad')) { return 'legs'; }

    if (m.contains('chest') || m.contains('pec')) { return 'chest'; }

    if (m.contains('back') || m.contains('lat') ||
        m.contains('row') || m.contains('deadlift') ||
        m.contains('pull') || m.contains('trap') ||
        m.contains('rhomboid')) { return 'back'; }

    // Biceps and triceps tracked separately (different recovery cycles)
    if (m.contains('bicep')) { return 'biceps'; }
    if (m.contains('tricep')) { return 'triceps'; }
    if (m.contains('forearm')) { return 'arms'; }

    // Generic 'arms' or curl → biceps (most curls are bicep-dominant)
    if (m.contains('curl') || m.contains('arm')) { return 'biceps'; }

    if (m.contains('core') || m.contains('abs') ||
        m.contains('plank') || m.contains('crunch') ||
        m.contains('oblique')) { return 'core'; }
    return 'other';
  }

  static String getMuscleGroup(String exercise) {
    final e = exercise.toLowerCase();

    // Rear delt exercises → back (pull family)
    if (e.contains('rear delt') || e.contains('reverse fly') ||
        e.contains('face pull')) { return 'back'; }

    if (e.contains('bench') || e.contains('chest') ||
        e.contains('pushup') || e.contains('push-up') ||
        e.contains('fly') && !e.contains('reverse')) { return 'chest'; }
    if (e.contains('pull') || e.contains('row') || e.contains('lat')) {
      return 'back';
    }
    if (e.contains('squat') || e.contains('lunge') || e.contains('leg') ||
        e.contains('deadlift') && !e.contains('romanian')) {
      return 'legs';
    }
    if (e.contains('lateral raise') || e.contains('shoulder') ||
        e.contains('overhead press')) { return 'shoulders'; }

    // Tricep exercises (separate from biceps)
    if (e.contains('tricep') || e.contains('skull') ||
        e.contains('pushdown') || e.contains('dip') ||
        e.contains('close grip') || e.contains('kickback')) { return 'triceps'; }

    // Bicep exercises
    if (e.contains('curl') || e.contains('bicep') ||
        e.contains('chin-up') || e.contains('hammer')) { return 'biceps'; }

    if (e.contains('abs') || e.contains('crunch') ||
        e.contains('plank') || e.contains('oblique')) { return 'core'; }
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
    switch (t.toLowerCase().trim()) {
      // PPL
      case 'push':             return 'Push Day';
      case 'pull':             return 'Pull Day';
      case 'legs':             return 'Legs Day';
      // Chest+Tri / Back+Bi split
      case 'chest + tricep':   return 'Chest & Tricep';
      case 'back + bicep':     return 'Back & Bicep';
      case 'legs + shoulders': return 'Legs & Shoulders';
      // Arnold Split
      case 'chest + back':     return 'Chest & Back';
      case 'shoulders + arms': return 'Shoulders & Arms';
      // Bro Split
      case 'chest':            return 'Chest Day';
      case 'back':             return 'Back Day';
      case 'shoulders':        return 'Shoulders Day';
      case 'arms':             return 'Arms Day';
      case 'abs':              return 'Abs Day';
      // Upper/Lower
      case 'upper':            return 'Upper Body';
      case 'lower':            return 'Lower Body';
      // Full Body
      case 'full':             return 'Full Body';
      // Strength
      case 'squat':            return 'Squat Day';
      case 'hinge':            return 'Hinge Day';
      case 'press':            return 'Press Day';
      // Rest / Core
      case 'rest':             return 'Rest Day';
      case 'core':             return 'Core Day';
      default:                 return t.isNotEmpty ? t : 'Workout';
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

  String _typeFromNames(List<String> names) =>
      WorkoutClassifier.classifyDayFromExercises(names);

  /// Detect bodyweight exercise by common naming patterns
  bool _isBodyweightByName(String name) {
    final n = name.toLowerCase();
    const bwKeywords = [
      'push-up', 'pushup', 'push up',
      'pull-up', 'pullup', 'pull up',
      'chin-up', 'chinup', 'chin up',
      'dip', 'plank', 'crunch', 'sit-up', 'situp',
      'burpee', 'mountain climber', 'jumping jack',
      'high knee', 'wall sit', 'superman',
      'lunge', 'squat jump', 'bodyweight squat', 'air squat', 'squats',
      'jumping squat', 'pistol squat', 'split squat',
      'walking lunge', 'reverse lunge', 'jump lunge',
      'step-up', 'step up', 'donkey kick', 'fire hydrant',
      'tricep dip', 'bench dip',
      'inchworm', 'bear crawl', 'crab walk',
      'broad jump', 'box jump', 'tuck jump',
      'shadow box', 'shadow boxing',
      'glute bridge', 'leg raise', 'flutter kick',
      'calf raise', 'standing calf', 'donkey calf',
      'pike push', 'diamond push', 'archer push',
      'hanging leg', 'l-sit', 'v-up', 'bicycle crunch',
      'side plank', 'russian twist', 'jumping rope', 'jump rope',
      'dragon flag', 'ab wheel', 'inverted row',
      'wide grip pull', 'sissy squat',
    ];
    for (final k in bwKeywords) {
      if (n.contains(k)) { return true; }
    }
    return false;
  }

  String _getEmojiFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('bench') || n.contains('push')) { return '💪'; }
    if (n.contains('pull') || n.contains('row')) { return '🏋️'; }
    if (n.contains('leg') || n.contains('squat')) { return '🦵'; }
    if (n.contains('cardio')) { return '🔥'; }
    return '🏋️';
  }

  List<DayPlan> _buildDefaultWeek() {
    const titles = [
      'Push Day', 'Pull Day', 'Legs Day', 'Rest Day',
      'Push Day', 'Pull Day', 'Rest Day',
    ];
    const rests = [false, false, false, true, false, false, true];

    // Starter exercises per day - Beginner-friendly
    final starterExercises = {
      0: [ // Push Day - Mon
        {'name': 'Barbell Bench Press', 'category': 'Chest', 'emoji': '🏋️',
          'type': 'push', 'baseId': 'Barbell Bench Press_push', 'weight': 40.0},
        {'name': 'Dumbbell Shoulder Press', 'category': 'Shoulders', 'emoji': '🆙',
          'type': 'push', 'baseId': 'Dumbbell Shoulder Press_push', 'weight': 12.0},
        {'name': 'Tricep Pushdown', 'category': 'Triceps', 'emoji': '⬇️',
          'type': 'push', 'baseId': 'Tricep Pushdown_push', 'weight': 20.0},
      ],
      1: [ // Pull Day - Tue
        {'name': 'Lat Pulldown', 'category': 'Back', 'emoji': '⬇️',
          'type': 'pull', 'baseId': 'Lat Pulldown_pull', 'weight': 30.0},
        {'name': 'Seated Cable Row', 'category': 'Back', 'emoji': '🚣',
          'type': 'pull', 'baseId': 'Seated Cable Row_pull', 'weight': 30.0},
        {'name': 'Barbell Curl', 'category': 'Biceps', 'emoji': '💪',
          'type': 'pull', 'baseId': 'Barbell Curl_pull', 'weight': 15.0},
      ],
      2: [ // Legs Day - Wed
        {'name': 'Barbell Back Squat', 'category': 'Legs', 'emoji': '🦵',
          'type': 'legs', 'baseId': 'Barbell Back Squat_legs', 'weight': 40.0},
        {'name': 'Leg Press', 'category': 'Legs', 'emoji': '🦿',
          'type': 'legs', 'baseId': 'Leg Press_legs', 'weight': 60.0},
        {'name': 'Standing Calf Raise', 'category': 'Legs', 'emoji': '🦶',
          'type': 'legs', 'baseId': 'Standing Calf Raise_legs', 'weight': 20.0},
      ],
      4: [ // Push Day - Fri
        {'name': 'Incline Barbell Press', 'category': 'Chest', 'emoji': '⬆️',
          'type': 'push', 'baseId': 'Incline Barbell Press_push', 'weight': 30.0},
        {'name': 'Lateral Raise', 'category': 'Shoulders', 'emoji': '🦅',
          'type': 'push', 'baseId': 'Lateral Raise_push', 'weight': 5.0},
        {'name': 'Skull Crushers', 'category': 'Triceps', 'emoji': '💀',
          'type': 'push', 'baseId': 'Skull Crushers_push', 'weight': 15.0},
      ],
      5: [ // Pull Day - Sat
        {'name': 'Pull-ups', 'category': 'Back', 'emoji': '🆙',
          'type': 'pull', 'baseId': 'Pull-ups_pull', 'weight': 0.0, 'bw': true},
        {'name': 'Dumbbell Row', 'category': 'Back', 'emoji': '🚣',
          'type': 'pull', 'baseId': 'Dumbbell Row_pull', 'weight': 12.0},
        {'name': 'Hammer Curl', 'category': 'Biceps', 'emoji': '🔨',
          'type': 'pull', 'baseId': 'Hammer Curl_pull', 'weight': 10.0},
      ],
    };

    return List.generate(7, (i) {
      final exercises = <PlannedExercise>[];
      if (!rests[i] && starterExercises.containsKey(i)) {
        for (final e in starterExercises[i]!) {
          final isBw = e['bw'] == true;
          exercises.add(PlannedExercise(
            id: IdHelper.uuid(),
            name: e['name'] as String,
            category: e['category'] as String,
            emoji: e['emoji'] as String,
            type: e['type'] as String,
            unit: isBw ? 'reps' : 'kg',
            baseId: e['baseId'] as String,
            bodyweight: isBw,
            sets: List.generate(3, (_) => ExSet(
              id: IdHelper.uuid(),
              reps: 10,
              weight: isBw ? 0.0 : (e['weight'] as double),
            )),
          ));
        }
      }
      return DayPlan(
        id: IdHelper.uuid(),
        dayIndex: i,
        title: titles[i],
        exercises: exercises,
        isRestDay: rests[i],
      );
    });
  }

  // ═════════════════════════════════════════════════════════
  // ANALYTICS HELPERS
  // ═════════════════════════════════════════════════════════
  double estimatedE1RM(String exerciseKey) {
    final logs = _logs.where((l) => l.exercise == exerciseKey).toList();
    if (logs.isEmpty) { return 0; }
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
