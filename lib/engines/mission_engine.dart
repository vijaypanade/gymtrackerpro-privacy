// lib/engines/mission_engine.dart
// ══════════════════════════════════════════════════════════
// FIXES: Daily missions always showing 0/0
// 
// Root cause: MissionGenerator in models.dart generates missions,
// but AppProvider never calls it OR updates isCompleted.
//
// This engine:
// 1. Generates missions dynamically based on current state
// 2. Checks completion automatically
// 3. Persists state through app restarts
// 4. Refreshes daily (new missions each day)
// ══════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/workout_log.dart';

// ─────────────────────────────────────────────────────────
// MISSION — extended with progress tracking
// ─────────────────────────────────────────────────────────
class Mission {
  final String      id;
  final String      title;
  final String      description;
  final String      emoji;
  final int         xpReward;
  final MissionType type;
  final int         targetValue;   // e.g. 15 sets, 3000ml water
  int               currentValue;  // progress toward target
  bool              isCompleted;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.xpReward,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    this.isCompleted  = false,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  String get progressText {
    if (isCompleted) return 'Done! ✅';
    if (targetValue == 1) return isCompleted ? 'Done!' : 'Not yet';
    return '$currentValue / $targetValue';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'emoji': emoji, 'xpReward': xpReward, 'type': type.name,
    'targetValue': targetValue, 'currentValue': currentValue,
    'isCompleted': isCompleted,
  };

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
    id:           j['id']           as String? ?? '',
    title:        j['title']        as String? ?? '',
    description:  j['description']  as String? ?? '',
    emoji:        j['emoji']        as String? ?? '🎯',
    xpReward:     j['xpReward']     as int?    ?? 50,
    type:         MissionType.values.firstWhere(
        (e) => e.name == (j['type'] as String? ?? 'workout'),
        orElse: () => MissionType.workout),
    targetValue:  j['targetValue']  as int?    ?? 1,
    currentValue: j['currentValue'] as int?    ?? 0,
    isCompleted:  j['isCompleted']  as bool?   ?? false,
  );
}

// ─────────────────────────────────────────────────────────
// MISSION ENGINE
// ─────────────────────────────────────────────────────────
class MissionEngine extends ChangeNotifier {
  static const _keyMissions = 'daily_missions_v2';
  static const _keyDate     = 'mission_date_v2';

  List<Mission> _missions = [];
  String        _date     = '';
  bool          _loading  = true;

  List<Mission> get missions       => List.unmodifiable(_missions);
  bool          get isLoading      => _loading;
  int           get completedCount => _missions.where((m) => m.isCompleted).length;
  int           get totalCount     => _missions.length;
  int           get totalXPAvailable =>
      _missions.where((m) => !m.isCompleted).fold(0, (s, m) => s + m.xpReward);

  // ─────────────────────────────────────────────────────────
  // INIT — load or generate missions for today
  // ─────────────────────────────────────────────────────────
  Future<void> init({
    required int    streak,
    required int    totalWorkouts,
    required String goal,
    required String weakMuscle,
    required int    currentWaterMl,
    required int    waterGoalMl,
  }) async {
    final today = _todayStr;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyMissions);
    final savedDate = prefs.getString(_keyDate) ?? '';

    if (saved != null && savedDate == today) {
      // Load existing missions for today
      try {
        final list = jsonDecode(saved) as List;
        _missions = list.map((j) => Mission.fromJson(j as Map<String, dynamic>)).toList();
        _date     = today;
        _loading  = false;
        notifyListeners();
        return;
      } catch (_) {}
    }

    // Generate fresh missions for today
    _missions = _generateMissions(
      streak:        streak,
      totalWorkouts: totalWorkouts,
      goal:          goal,
      weakMuscle:    weakMuscle,
    );

    // Pre-fill water progress if already drunk some today
    final waterMission = _missions.firstWhere(
        (m) => m.type == MissionType.water, orElse: () => Mission(
          id: '', title: '', description: '', emoji: '', xpReward: 0,
          type: MissionType.water, targetValue: 1));
    if (waterMission.id.isNotEmpty) {
      waterMission.currentValue = currentWaterMl;
      if (currentWaterMl >= waterGoalMl) waterMission.isCompleted = true;
    }

    _date    = today;
    _loading = false;
    await _save(prefs);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // GENERATE MISSIONS — dynamic based on user state
  // ─────────────────────────────────────────────────────────
  List<Mission> _generateMissions({
    required int    streak,
    required int    totalWorkouts,
    required String goal,
    required String weakMuscle,
  }) {
    final today   = DateTime.now();
    final dayCode = today.day.toString();
    final missions = <Mission>[];

    // ── Mission 1: Always — complete workout ──────────────
    missions.add(Mission(
      id:          'workout_$dayCode',
      title:       'Complete Today\'s Workout',
      description: 'Finish all planned sets',
      emoji:       '🏋️',
      xpReward:    XPSystem.xpWorkoutComplete,
      type:        MissionType.workout,
      targetValue: 1,
    ));

    // ── Mission 2: Water goal ─────────────────────────────
    missions.add(Mission(
      id:          'water_$dayCode',
      title:       'Hit Water Goal',
      description: 'Stay hydrated — performance + recovery',
      emoji:       '💧',
      xpReward:    XPSystem.xpWaterGoalMet,
      type:        MissionType.water,
      targetValue: 1, // completion handled separately
    ));

    // ── Mission 3: Context-aware third mission ────────────
    if (weakMuscle.isNotEmpty && weakMuscle != 'other') {
      // User has a weak muscle → encourage training it
      final muscle = weakMuscle[0].toUpperCase() + weakMuscle.substring(1);
      missions.add(Mission(
        id:          'weak_${weakMuscle}_$dayCode',
        title:       'Train Your $muscle',
        description: '$muscle is lagging — give it extra attention today',
        emoji:       _muscleEmoji(weakMuscle),
        xpReward:    XPSystem.xpMissionComplete + 25,
        type:        MissionType.workout,
        targetValue: 1,
      ));
    } else if (streak >= 3) {
      // Building streak → streak mission
      missions.add(Mission(
        id:          'streak_$dayCode',
        title:       'Extend Your ${streak}-Day Streak',
        description: 'Don\'t break the chain! Train today.',
        emoji:       '🔥',
        xpReward:    XPSystem.xpStreakBonus * (streak ~/ 3 + 1),
        type:        MissionType.streak,
        targetValue: 1,
      ));
    } else if (goal.contains('fat')) {
      // Fat loss goal → extra sets mission
      missions.add(Mission(
        id:          'sets_$dayCode',
        title:       'Log 20 Total Sets',
        description: 'Higher volume burns more — go for 20 sets today',
        emoji:       '🔥',
        xpReward:    XPSystem.xpMissionComplete,
        type:        MissionType.sets,
        targetValue: 20,
      ));
    } else {
      // Default — volume mission
      missions.add(Mission(
        id:          'sets_$dayCode',
        title:       'Complete 15 Sets',
        description: 'Log at least 15 quality sets today',
        emoji:       '💪',
        xpReward:    XPSystem.xpMissionComplete,
        type:        MissionType.sets,
        targetValue: 15,
      ));
    }

    return missions;
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE PROGRESS — called by AppProvider on events
  // ─────────────────────────────────────────────────────────

  /// Call when a workout session is completed
  Future<int> onWorkoutComplete() async {
    return _completeMissionsByType(MissionType.workout);
  }

  /// Call after every set toggle — pass total sets done today
  Future<int> onSetLogged(int totalSetsToday) async {
    int xp = 0;
    for (final m in _missions.where(
        (m) => m.type == MissionType.sets && !m.isCompleted)) {
      m.currentValue = totalSetsToday;
      if (m.currentValue >= m.targetValue) {
        m.isCompleted = true;
        xp += m.xpReward;
      }
    }
    if (xp > 0) {
      final prefs = await SharedPreferences.getInstance();
      await _save(prefs);
      notifyListeners();
    }
    return xp;
  }

  /// Call when water intake updated
  Future<int> onWaterUpdated(int totalMl, int goalMl) async {
    int xp = 0;
    for (final m in _missions.where(
        (m) => m.type == MissionType.water && !m.isCompleted)) {
      m.currentValue = totalMl;
      if (totalMl >= goalMl) {
        m.isCompleted = true;
        xp += m.xpReward;
      }
    }
    if (xp > 0) {
      final prefs = await SharedPreferences.getInstance();
      await _save(prefs);
      notifyListeners();
    }
    return xp;
  }

  /// Call when streak maintained
  Future<int> onStreakMaintained() async {
    return _completeMissionsByType(MissionType.streak);
  }

  /// Call when weak muscle trained today
  Future<int> onWeakMuscleTrained(String muscle) async {
    int xp = 0;
    for (final m in _missions.where(
        (m) => m.id.contains('weak_$muscle') && !m.isCompleted)) {
      m.isCompleted = true;
      xp += m.xpReward;
    }
    if (xp > 0) {
      final prefs = await SharedPreferences.getInstance();
      await _save(prefs);
      notifyListeners();
    }
    return xp;
  }

  Future<int> _completeMissionsByType(MissionType type) async {
    int xp = 0;
    for (final m in _missions.where((m) => m.type == type && !m.isCompleted)) {
      m.isCompleted  = true;
      m.currentValue = m.targetValue;
      xp += m.xpReward;
    }
    if (xp > 0) {
      final prefs = await SharedPreferences.getInstance();
      await _save(prefs);
      notifyListeners();
    }
    return xp;
  }

  Future<void> _save(SharedPreferences prefs) async {
    await prefs.setString(_keyMissions,
        jsonEncode(_missions.map((m) => m.toJson()).toList()));
    await prefs.setString(_keyDate, _date);
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  String _muscleEmoji(String muscle) {
    const map = {
      'chest': '💪', 'back': '🔙', 'legs': '🦵',
      'shoulders': '🏋️', 'arms': '💪', 'core': '🎯',
    };
    return map[muscle] ?? '💪';
  }
}
