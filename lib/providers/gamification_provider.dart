// lib/providers/gamification_provider.dart — v5
// ══════════════════════════════════════════════
// Single source of truth for:
//   XP, UserRank, Daily Missions, Badge popups
// ══════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class GamificationProvider extends ChangeNotifier {

  static const _kXP         = 'xp_system_v1';
  static const _kMissions   = 'daily_missions_v1';
  static const _kMissionDate= 'mission_date_v1';

  // ── UI popup flags (transient)
  bool showXPPopup     = false;
  bool showBadgePopup  = false;
  bool showRankUpPopup = false;
  int  lastXPGained    = 0;
  AppBadge?  lastUnlockedBadge;
  UserRank?  newRank;            // for rank-up popup

  // ── Data
  XPSystem _xp = XPSystem();
  List<DailyMission> _missions = [];

  GamificationProvider() { _init(); }

  // ── Getters
  XPSystem get xp                  => _xp;
  List<DailyMission> get missions  => _missions;
  int  get completedMissions       => _missions.where((m) => m.isCompleted).length;
  int  get totalMissions           => _missions.length;
  bool get allMissionsComplete     =>
      _missions.isNotEmpty && _missions.every((m) => m.isCompleted);

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Init
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    final xpJson = prefs.getString(_kXP);
    if (xpJson != null) {
      try { _xp = XPSystem.fromJson(jsonDecode(xpJson)); } catch (_) {}
    }

    final mDate = prefs.getString(_kMissionDate) ?? '';
    if (mDate != _todayStr) {
      _missions = []; // new day — will be generated after profile loads
    } else {
      final misJson = prefs.getString(_kMissions);
      if (misJson != null) {
        try {
          _missions = (jsonDecode(misJson) as List)
              .map((j) => DailyMission.fromJson(j as Map<String, dynamic>))
              .toList();
        } catch (_) { _missions = []; }
      }
    }

    notifyListeners();
  }

  // ── Generate missions (called once after profile loads)
  Future<void> generateDailyMissions({
    required String goal, required int streak, required int totalWorkouts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kMissionDate) == _todayStr && _missions.isNotEmpty) return;

    _missions = MissionGenerator.generate(
      goal: goal, streak: streak, totalWorkouts: totalWorkouts,
    );
    await prefs.setString(_kMissionDate, _todayStr);
    await _saveMissions();
    notifyListeners();
  }

  // ✅ FIX: Called from home_screen when missions are 0/0
  // Generates fresh missions using current app state
  Future<void> initMissionsIfNeeded({
    required int    streak,
    required int    totalWorkouts,
    required String goal,
    required String weakMuscle,
  }) async {
    if (_missions.isNotEmpty) return; // already initialized
    await generateDailyMissions(
      goal:          goal,
      streak:        streak,
      totalWorkouts: totalWorkouts,
    );
  }

  // ── XP — single method, handles rank-up detection
  void addXP(int amount) {
    final prevRank = _xp.rank;
    _xp.totalXP  += amount;
    _xp.weeklyXP += amount;
    lastXPGained  = amount;
    showXPPopup   = true;
    notifyListeners();
    _saveXP();

    Future.delayed(const Duration(milliseconds: 1800), () {
      showXPPopup = false;
      notifyListeners();
    });

    // Rank-up detection
    if (_xp.rank != prevRank) {
      newRank = _xp.rank;
      showRankUpPopup = true;
      notifyListeners();
      Future.delayed(const Duration(seconds: 4), () {
        showRankUpPopup = false;
        newRank = null;
        notifyListeners();
      });
    }
  }

  // RFC-002.5 §7 Option B — XP recovery after reinstall.
  // Called from LoginScreen after tryRestoreHistoryFromCloud() returns.
  // WorkoutProvider has no knowledge of this method (no circular dependency).
  Future<void> recoverXPIfNeeded(List<HistoryEntry> history) async {
    if (_xp.totalXP != 0) return; // XP already present — nothing to recover.
    if (history.isEmpty) return;

    final sumFromHistory = history.fold<int>(0, (s, e) => s + e.xpEarned);
    final recovered = sumFromHistory > 0
        ? sumFromHistory
        : history.length * XPSystem.xpWorkoutComplete; // floor estimate

    _xp.totalXP = recovered;
    await _saveXP();
    notifyListeners();
    debugPrint('🔧 XP recovered: $recovered (${sumFromHistory > 0 ? "exact" : "floor estimate"}, '
        '${history.length} sessions)');
  }

  // ── Missions
  void completeMission(String id) {
    final idx = _missions.indexWhere((m) => m.id == id);
    if (idx == -1 || _missions[idx].isCompleted) return;
    _missions[idx].isCompleted = true;
    addXP(_missions[idx].xpReward);
    notifyListeners();
    _saveMissions();
  }

  /// Complete workout mission
  void onWorkoutComplete() {
    if (_missions.isEmpty) return;

    final wm = _missions.firstWhere(
      (m) => m.type == MissionType.workout && !m.isCompleted,
      orElse: () => _missions.first,
    );

    if (!wm.isCompleted && wm.type == MissionType.workout) {
      completeMission(wm.id);
    }
  }

  // ── Badge popup (includes XP grant)
  void triggerBadgePopup(AppBadge badge) {
    lastUnlockedBadge = badge;
    showBadgePopup = true;
    addXP(badge.xpReward);
    notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      showBadgePopup = false;
      notifyListeners();
    });
  }

  // ── Weekly XP reset
  Future<void> resetWeeklyXP() async {
    _xp.weeklyXP = 0;
    _xp.weekStartDate = _todayStr;
    await _saveXP();
    notifyListeners();
  }

  // ── Persistence
  Future<void> _saveXP() async =>
      (await SharedPreferences.getInstance()).setString(_kXP, jsonEncode(_xp.toJson()));

  Future<void> _saveMissions() async =>
      (await SharedPreferences.getInstance()).setString(
          _kMissions, jsonEncode(_missions.map((m) => m.toJson()).toList()));
}
