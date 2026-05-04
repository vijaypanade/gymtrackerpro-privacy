// lib/providers/app_provider.dart — v8.0 ORCHESTRATOR
//
// This is now a LIGHTWEIGHT orchestrator. Heavy lifting lives in:
//   - UserProvider       (profile, water, mood, favorites, measurements)
//   - WorkoutProvider    (week plan, logs, streak, history, recovery)
//   - AnalyticsProvider  (snapshot, EMA scores, plateau, trend)
//   - AIProvider         (coach insights, AI plan generation, memory)
//   - SettingsProvider   (notifications, reminders)
//
// AppProvider's only jobs:
//   1. Wire sub-providers together at startup (load order, hooks).
//   2. Cross-provider workflows (workout complete → record session →
//      recompute analytics → recompute insight).
//   3. Paywall trigger logic (uses MonetizationService).
//   4. Backwards-compatibility getters so existing UI screens that read
//      `appProvider.goal`, `appProvider.streak`, etc. keep working.
//
// AppProvider does NOT extend ChangeNotifier itself for the heavy state —
// instead it listens to its child providers and rebroadcasts.
//
// MIGRATION NOTE: Existing screens can keep using `appProvider.X` in most
// cases — the back-compat getters delegate. Over time, screens should be
// migrated to read directly from the appropriate sub-provider.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';

import '../models/memory_models.dart';
import '../models/models.dart';
import '../models/workout_log.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart';
import '../services/storage_service.dart';
import 'ai_provider.dart';
import 'analytics_provider.dart';
import 'settings_provider.dart';
import 'user_provider.dart';
import 'workout_provider.dart';

class AppProvider extends ChangeNotifier {
  final UserProvider      user;
  final WorkoutProvider   workout;
  final AnalyticsProvider analytics;
  final AIProvider        ai;
  final SettingsProvider  settings;

  AppProvider({
    required this.user,
    required this.workout,
    required this.analytics,
    required this.ai,
    required this.settings,
  }) {
    // Forward child notifications so widgets that listen to AppProvider
    // (legacy code) still rebuild when sub-providers change.
    user.addListener(_onChildChanged);
    workout.addListener(_onChildChanged);
    analytics.addListener(_onChildChanged);
    ai.addListener(_onChildChanged);
    settings.addListener(_onChildChanged);
  }

  bool _loading = true;
  bool get loading => _loading;

  // Streak popup shown after a workout completes
  bool showStreakPopup = false;

  // Paywall trigger — set after key events, read by UI
  PaywallTrigger? _pendingPaywallTrigger;
  PaywallTrigger? get pendingPaywallTrigger => _pendingPaywallTrigger;
  void clearPaywallTrigger() {
    _pendingPaywallTrigger = null;
    notifyListeners();
  }

  void _onChildChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    user.removeListener(_onChildChanged);
    workout.removeListener(_onChildChanged);
    analytics.removeListener(_onChildChanged);
    ai.removeListener(_onChildChanged);
    settings.removeListener(_onChildChanged);
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════
  // INIT
  // ═════════════════════════════════════════════════════════
  Future<void> init() async {
    try {
      // Storage first (everyone depends on it)
      await StorageService.instance.init();

      // Monetization next
      await MonetizationService.instance.init();

      // Load sub-providers in parallel — they're independent
      await Future.wait<void>([
        user.load(),
        settings.load(),
        workout.load(),
        analytics.load(),
        ai.load(),
      ]);

      // Wire WorkoutProvider's external hooks now that AI is loaded.
      workout.wireExternalHooks(
        weightModifier:  () => ai.insight.weightModifier,
        recommendedSets: () => ai.insight.recommendedSets,
        weakMuscle:      () => ai.insight.weakMuscleGroup,
      );

      // Compute initial analytics + AI insight
      await _recomputeAll();
    } catch (e, s) {
      debugPrint('AppProvider.init error: $e\n$s');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Recomputes both analytics and AI insight from current state.
  /// Called after any change that affects derived data.
  Future<void> _recomputeAll() async {
    await analytics.recompute(AnalyticsInputs(
      logs:                 workout.logs,
      mood:                 user.todayMood,
      streak:               workout.streak.currentStreak,
      overallRecoveryScore: workout.getOverallRecovery(mood: user.todayMood),
      needsDeload:          workout.needsDeloadByVolume,
      today:                workout.todayPlan,
      lastMuscleTrained:    workout.lastMuscleTrained,
    ));

    await ai.recomputeInsight(AICoachInputs(
      logs:                 workout.logs,
      mood:                 user.todayMood,
      currentStreak:        workout.streak.currentStreak,
      totalWorkouts:        workout.streak.totalWorkouts,
      goal:                 user.goal,
      level:                user.level,
      trainerType:          user.trainerType,
      userName:             user.name,
      isOnPlateau:          analytics.isOnPlateau,
      needsDeload:          workout.needsDeloadByVolume,
      daysSinceLastWorkout: workout.daysSinceLastWorkout,
    ));
  }

  // ═════════════════════════════════════════════════════════
  // CROSS-PROVIDER WORKFLOWS
  // ═════════════════════════════════════════════════════════

  /// Marks a workout day complete, records session memory, recomputes
  /// analytics + AI insight, checks for paywall triggers, returns badges.
  Future<List<AppBadge>> markDayComplete(int dayIndex, int durationMin) async {
    triggerStreakPopup();

    final result = await workout.markDayComplete(dayIndex, durationMin);
    if (result.completedDay != null) {
      await ai.recordSession(
        day:              result.completedDay!,
        mood:             user.todayMood,
        normalizeMuscle:  WorkoutProvider.normalizeMuscle,
      );
    }

    await _recomputeAll();

    // Behavior-based paywall trigger
    _pendingPaywallTrigger = await checkPaywallTrigger();
    notifyListeners();

    return result.newBadges;
  }

  /// Generates an AI workout plan via the secure backend.
  /// Returns the parsed JSON map (caller can apply via applyAIWorkout).
  Future<Map<String, dynamic>> getAIWorkoutPlan() async {
    final request = AIWorkoutRequest(
      goal:                user.goal,
      level:               user.level,
      daysPerWeek:         6,
      weakMuscles: [
        if (ai.insight.weakMuscleGroup.isNotEmpty) ai.insight.weakMuscleGroup,
        ...ai.musclesSkippedLast7Days.take(2),
      ],
      isOnPlateau:         analytics.isOnPlateau,
      needsDeload:         workout.needsDeloadByVolume,
      isFatigued:          workout.isFatigued,
      performanceTrend:    ai.performanceTrend,
      missedDays:          workout.missedDayNames,
      recentWorkoutNames:  workout.lastWorkoutNames,
      currentStreak:       workout.streak.currentStreak,
      totalWorkouts:       workout.streak.totalWorkouts,
      weeklyVolumeTrend:   analytics.weeklyImprovementPct,
      exerciseHistory:     workout.buildExerciseHistory(),
      lastWeekMemory:      workout.lastWeekMemory,
    );

    if (!canUseAI()) {
      // UI should have checked this and shown paywall, but be safe
      return {};
    }

    final plan = await ai.generateWorkoutPlan(request);
    await MonetizationService.instance.recordAIUse();
    return plan;
  }

  /// Generates a quick AI suggestion (text format) shown on dashboard.
  Future<void> generateAIWorkout() async {
    if (!canUseAI()) {
      _pendingPaywallTrigger = PaywallTrigger.aiLimitHit;
      notifyListeners();
      return;
    }
    final request = AIWorkoutRequest(
      goal:           user.goal,
      level:          user.level,
      daysPerWeek:    user.activityLevel == 'Active'
          ? 5
          : user.activityLevel == 'Very Active'
              ? 6
              : 4,
      weakMuscles: [
        if (ai.insight.weakMuscleGroup.isNotEmpty) ai.insight.weakMuscleGroup,
        ...ai.musclesSkippedLast7Days.take(2),
      ],
      isOnPlateau:        analytics.isOnPlateau,
      needsDeload:        workout.needsDeloadByVolume,
      isFatigued:         workout.isFatigued,
      performanceTrend:   ai.performanceTrend,
      recentWorkoutNames: workout.lastWorkoutNames,
      currentStreak:      workout.streak.currentStreak,
      totalWorkouts:      workout.streak.totalWorkouts,
      weeklyVolumeTrend:  analytics.weeklyImprovementPct,
    );

    await ai.generateQuickSuggestion(request);
    await MonetizationService.instance.recordAIUse();
  }

  /// Apply an AI-generated plan to the week.
  Future<void> applyAIWorkout(Map<String, dynamic> plan) async {
    await workout.applyAIWorkoutMap(plan);
    await _recomputeAll();
  }

  /// Generate a smart plan from local AIEngine.
  void generateSmartPlan() {
    workout.generateSmartPlan(goal: user.goal, level: user.level);
    _recomputeAll();
  }

  void generateWorkoutForDay(String type, int dayIndex) {
    workout.generateWorkoutForDay(
      type:     type,
      dayIndex: dayIndex,
      goal:     user.goal,
      level:    user.level,
    );
    _recomputeAll();
  }

  /// Sets the user's mood and triggers AI/Analytics recomputation.
  Future<void> setMood(MoodType mood) async {
    await user.setMood(mood);
    await _recomputeAll();
  }

  /// Reset everything (used in dev / debug menus).
  Future<void> resetAll() async {
    await user.resetToDefaults();
    await workout.resetAll();
    await ai.clearMemory();
    analytics.invalidateAll();
    await _recomputeAll();
  }

  void triggerStreakPopup() {
    showStreakPopup = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      showStreakPopup = false;
      notifyListeners();
    });
  }

  // ═════════════════════════════════════════════════════════
  // PAYWALL / PREMIUM
  // ═════════════════════════════════════════════════════════
  bool get isPremium       => MonetizationService.instance.isPremium;
  bool canUseAI()          => MonetizationService.instance.canUseAI;
  int  get aiUsesRemaining => MonetizationService.instance.aiUsesRemaining;

  bool canViewAdvancedStats()   => isPremium;
  bool canUseSmartCoach()       => isPremium;
  bool canUseAdvancedInsights() => isPremium;

  Future<void> upgradeToPremium() async {
    await MonetizationService.instance.upgradeToPremium();
    ai.invalidateInsightCache();
    await _recomputeAll();
  }

  void setPremium(bool value) {
    if (value) {
      MonetizationService.instance.upgradeToPremium();
    } else {
      MonetizationService.instance.revokePremium();
    }
    ai.invalidateInsightCache();
    _recomputeAll();
  }

  Future<PaywallTrigger?> checkPaywallTrigger() async {
    if (isPremium) return null;

    if (!canUseAI()) {
      final should = await MonetizationService.instance
          .shouldShowPaywall(PaywallTrigger.aiLimitHit);
      if (should) return PaywallTrigger.aiLimitHit;
    }

    final total = workout.streak.totalWorkouts;
    if (total == 5 || total == 10 || total == 25) {
      final should = await MonetizationService.instance
          .shouldShowPaywall(PaywallTrigger.workoutMilestone);
      if (should) return PaywallTrigger.workoutMilestone;
    }

    final cur = workout.streak.currentStreak;
    if (cur == 7 || cur == 14) {
      final should = await MonetizationService.instance
          .shouldShowPaywall(PaywallTrigger.streakMilestone);
      if (should) return PaywallTrigger.streakMilestone;
    }
    return null;
  }

  Future<PaywallTrigger?> checkPRPaywall() async {
    if (isPremium) return null;
    final should = await MonetizationService.instance
        .shouldShowPaywall(PaywallTrigger.prBroken);
    return should ? PaywallTrigger.prBroken : null;
  }

  // ═════════════════════════════════════════════════════════
  // BACKWARDS-COMPATIBILITY GETTERS
  // (so existing UI screens calling appProvider.X keep working;
  //  these just delegate to the right sub-provider)
  // ═════════════════════════════════════════════════════════

  // Profile / user
  UserProfile get profile => user.profile;
  String get goal           => user.goal;
  String get level          => user.level;
  String get trainerType    => user.trainerType;
  String get fitnessGoal    => user.goal;
  String get fitnessLevel   => user.level;
  String get trainerPersonality => user.trainerType;
  String get gender         => user.gender;
  double get weightKg       => user.weightKg;
  double get heightCm       => user.heightCm;
  int    get age            => user.age;
  Future<void> updateProfile(UserProfile p) => user.updateProfile(p);

  // Mood
  MoodType get todayMood => user.todayMood;

  // Water
  double get waterProgress => user.waterProgress;
  Future<void> addWater(int ml) => user.addWater(ml);
  Future<void> setWaterGoal(int ml) => user.setWaterGoal(ml);
  Future<void> resetWater() => user.resetWater();

  // Favorites
  Set<String> get favorites => user.favorites;
  Future<void> toggleFavorite(String name) => user.toggleFavorite(name);

  // Measurements
  List<BodyMeasurement> get measurements => user.measurements;
  Future<void> addMeasurement(BodyMeasurement m) => user.addMeasurement(m);
  Future<void> deleteMeasurement(String id) => user.deleteMeasurement(id);

  // Onboarding
  Future<void> completeOnboarding() => user.completeOnboarding();
  Future<bool> isOnboardingComplete() => user.isOnboardingComplete();

  // Settings
  Map<String, dynamic> get settingsMap => settings.all;
  bool get workoutReminderEnabled => settings.workoutReminderEnabled;
  bool get waterReminderEnabled   => settings.waterReminderEnabled;
  bool get notificationsEnabled   => settings.notificationsEnabled;
  int  get waterReminderInterval  => settings.waterReminderInterval;
  Future<void> updateSetting(String key, dynamic value) =>
      settings.update(key, value);

  // Workout state
  List<DayPlan>      get weekPlan       => workout.weekPlan;
  List<WorkoutLog>   get logs           => workout.logs;
  StreakData         get streak         => workout.streak;
  List<HistoryEntry> get history        => workout.history;
  WeeklyMemory?      get lastWeekMemory => workout.lastWeekMemory;

  int    get todayIndex          => workout.todayIndex;
  int    get weeklyCompletedDays => workout.weeklyCompletedDays;
  double get weeklyScore         => workout.weeklyScore;
  double get weeklyVolumeTotalKg => workout.weeklyVolumeTotalKg;
  bool   get isBeginnerPhase     => workout.isBeginnerPhase;
  int    get daysSinceLastWorkout => workout.daysSinceLastWorkout;
  bool   get isInactive          => workout.isInactive;
  DayPlan get todayPlan          => workout.todayPlan;
  Set<String> get completedDays  => workout.completedDays;
  List<String> get lastWorkoutNames => workout.lastWorkoutNames;
  List<String> get lastWorkouts  => workout.lastWorkoutNames;

  bool   get isFatigued       => workout.isFatigued;
  bool   get needsDeloadByVolume => workout.needsDeloadByVolume;
  bool   get needsDeload      => workout.needsDeload;
  String get weakestMuscle    => ai.insight.weakMuscleGroup.isNotEmpty
      ? ai.insight.weakMuscleGroup
      : workout.weakestMuscleByLogs;
  String get weakMuscle => weakestMuscle;
  String get topMuscleGroup => workout.topMuscleGroup;
  Map<String, int> get muscleGroupFrequency => workout.muscleGroupFrequency;
  Map<String, int> get muscleTrainingFrequency => workout.muscleTrainingFrequency;
  bool isMuscleOvertrained(String m) => workout.isMuscleOvertrained(m);
  List<String> get skippedMuscleGroups => workout.skippedMuscleGroups;
  List<MuscleRecovery> get muscleRecoveryList =>
      workout.muscleRecoveryList(mood: user.todayMood);
  double getMuscleRecovery(String muscle) =>
      workout.getMuscleRecoveryWithMood(muscle, user.todayMood);
  int    getOverallRecovery() =>
      workout.getOverallRecovery(mood: user.todayMood);

  // Planner ops
  void updateDayTitle(int i, String t) => workout.updateDayTitle(i, t);
  void clearDay(int i) => workout.clearDay(i);
  void resetWeek() => workout.resetWeek();
  void toggleRestDay(int i) => workout.toggleRestDay(i);
  void addExercise(int dayIndex, {
    required String name,
    required String category,
    required String emoji,
    String type = '',
    String unit = 'kg',
    required String baseId,
    bool isBodyweight = false,
  }) => workout.addExercise(
        dayIndex,
        name:        name,
        category:    category,
        emoji:       emoji,
        type:        type,
        unit:        unit,
        baseId:      baseId,
        isBodyweight: isBodyweight,
      );
  void removeExercise(int dayIndex, String exId) =>
      workout.removeExercise(dayIndex, exId);
  void addCustomExercise({
    required int dayIndex,
    required String name,
    required String category,
    required String emoji,
    required bool isBodyweight,
  }) => workout.addCustomExercise(
        dayIndex:    dayIndex,
        name:        name,
        category:    category,
        emoji:       emoji,
        isBodyweight: isBodyweight,
      );
  void addSet(int dayIndex, String exId) => workout.addSet(dayIndex, exId);
  void removeSet(int dayIndex, String exId, String setId) =>
      workout.removeSet(dayIndex, exId, setId);
  void updateSet(int dayIndex, String exId, String setId,
      {int? reps, double? weight}) =>
      workout.updateSet(dayIndex, exId, setId, reps: reps, weight: weight);
  void toggleSetDone(int dayIndex, String exId, String setId) =>
      workout.toggleSetDone(dayIndex, exId, setId);
  void applyAISuggestion(int dayIndex, List<String> suggestions) =>
      workout.applyAISuggestion(dayIndex, suggestions);

  String getKey(String baseId) => workout.getKey(baseId);

  // Logs / PR
  List<WorkoutLog> getLogsForExercise(String key) =>
      workout.getLogsForExercise(key);
  List<WorkoutLog> getHistory(String key) => workout.getHistory(key);
  double getPR(String key, String unit)   => workout.getPR(key, unit);
  int    getPRReps(String key)            => workout.getPRReps(key);
  String? getPRDate(String key, String unit) => workout.getPRDate(key, unit);
  bool   isNewPR(String key, double weight, int reps, String unit,
      {int minutes = 0}) =>
      workout.isNewPR(key, weight, reps, unit, minutes: minutes);
  PRResult checkPRResult(String key, double weight, int reps, String unit) =>
      workout.checkPRResult(key, weight, reps, unit);
  void addLog(String key, double weight, int reps, DateTime date,
      {int minutes = 0}) =>
      workout.addLog(key, weight, reps, date, minutes: minutes);
  String? nearMissMessage(String exerciseKey, String unit) =>
      workout.nearMissMessage(exerciseKey, unit);

  // Progression
  SetProgressionHint analyzeProgression(PlannedExercise ex) =>
      workout.analyzeProgression(ex);
  String getTrainerMessage(PlannedExercise ex) => workout.getTrainerMessage(ex);
  double getSuggestedWeight(PlannedExercise ex) => workout.getSuggestedWeight(ex);
  double adaptiveNextWeight(String exerciseKey) =>
      workout.adaptiveNextWeight(exerciseKey, isOnPlateau: analytics.isOnPlateau);
  double calculateNextWeight({
    required double currentWeight,
    required int reps,
    required int targetReps,
  }) =>
      workout.calculateNextWeight(
        currentWeight: currentWeight,
        reps: reps,
        targetReps: targetReps,
      );

  // Analytics — read-through
  double get readinessScore        => analytics.readinessScore;
  double get fatigueIndex          => analytics.fatigueIndex;
  double get effortScoreToday      => analytics.effortScoreToday;
  double get plateauScore          => isPremium ? analytics.plateauScore : 0;
  double get overTrainingRisk      =>
      isPremium ? analytics.overTrainingRisk : 0;
  double get weeklyImprovementPercent => analytics.weeklyImprovementPct;
  double get muscleBalanceScore    =>
      isPremium ? analytics.muscleBalanceScore : 70;
  double get intensityScore        => analytics.intensityScore;
  String get recoveryTrend         => analytics.recoveryTrend;
  bool   get isOnPlateau           => analytics.isOnPlateau;
  double get recoveryScore         => analytics.readinessScore;
  String get weeklyMessage         => analytics.weeklyMessage;
  String get muscleImbalance       => analytics.muscleImbalanceMessage(workout.logs);

  // AI insight — read-through
  AICoachInsight get aiInsight => ai.insight;
  FatigueLevel   get currentFatigueLevel => ai.insight.fatigueLevel;
  String get fatigueMessage => isPremium
      ? ai.insight.fatigueMessage
      : (ai.insight.fatigueLevel == FatigueLevel.fatigued
          ? '⚠️ High fatigue detected — upgrade for full analysis'
          : '✅ Recovery looks good — upgrade for details!');
  String get weightSuggestionMessage => isPremium
      ? ai.insight.weightMessage
      : '🔒 Upgrade for smart weight suggestions';
  String get weakMuscleInsight {
    if (!isPremium) return '🔒 Upgrade to discover your weak points';
    final w = ai.insight.weakMuscleGroup;
    return w.isEmpty ? '✅ Balanced training detected!' : '🎯 Focus area: $w';
  }
  int get recommendedSetsToday {
    if (!isPremium) return user.level == 'beginner' ? 3 : 4;
    return ai.insight.recommendedSets;
  }
  double get todayWeightModifier =>
      isPremium ? ai.insight.weightModifier : 1.0;
  double applyAIWeight(double base) {
    if (!isPremium || base <= 0) return base;
    return (base * todayWeightModifier).roundToDouble();
  }
  String get dailyCoachMessage => isPremium
      ? ai.insight.dailyCoachMessage
      : '🔒 Upgrade to Premium for your personalized AI coach!';
  String get aiSuggestion {
    if (ai.lastAISuggestion.isNotEmpty) return ai.lastAISuggestion;
    if (isPremium) return ai.insight.dailyCoachMessage;
    if (workout.isInactive && workout.daysSinceLastWorkout >= 2) {
      return 'Welcome back — let\'s get moving 💪';
    }
    return ai.insight.dailyCoachMessage;
  }

  /// Full AI-generated plan text (long, structured). Use this for the
  /// "View Full Plan" screen / bottom sheet — NOT for compact cards.
  String get lastAIPlan => ai.lastAIPlan;

  /// True when an AI plan has been generated and is available to view.
  bool get hasAIPlan => ai.hasAIPlan;
  String get smartCoach => isPremium
      ? ai.insight.dailyCoachMessage
      : '🔒 Upgrade for the full smart coach.';
  String get progressionTip => ai.insight.weightMessage;

  // AI memory
  bool   get hasFailurePattern   => ai.hasFailurePattern;
  double get averageEffortScore  => ai.averageEffortScore;
  int    get failedSessionCount  => ai.failedSessionCount;
  String get bestPerformingExercise => ai.bestPerformingExercise;
  List<String> get musclesSkippedLast7Days => ai.musclesSkippedLast7Days;
  String get performanceTrend    => ai.performanceTrend;

  // Convenience
  String getDayName(int i) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return days[i.clamp(0, 6)];
  }

  // ═════════════════════════════════════════════════════════
  // ADDITIONAL UI BACK-COMPAT GETTERS
  // (UI screens reference these — added so existing screens compile)
  // ═════════════════════════════════════════════════════════

  // From planner_screen, profile_screen
  double get tdee {
    return AIEngine.estimateTDEE(
      weightKg:      user.weightKg,
      heightCm:      user.heightCm,
      age:           user.age,
      gender:        user.gender,
      activityLevel: user.activityLevel,
      goal:          user.goal,
    );
  }

  String get aiFullAdvice {
    final protein = AIEngine.getProteinTarget(
      bodyWeightKg: user.weightKg,
      goal:         user.goal,
      fitnessLevel: user.level,
    );
    return '${tdee.toStringAsFixed(0)} kcal · $protein protein';
  }

  // From home_screen — child providers handle their own refreshes now
  int get refreshTrigger => 0;

  // From progress_screen
  List<WorkoutLog> get workoutLogs => workout.logs;

  // From stats_screen
  List<int> get workoutsByDayOfWeek {
    final c = List<int>.filled(7, 0);
    for (final h in workout.history) {
      try {
        c[(DateTime.parse(h.date).weekday - 1).clamp(0, 6)]++;
      } catch (_) {}
    }
    return c;
  }

  List<double> get weeklyVolumeData {
    final v = List<double>.filled(7, 0);
    for (final h in workout.history) {
      try {
        v[(DateTime.parse(h.date).weekday - 1).clamp(0, 6)] += h.totalVolume;
      } catch (_) {}
    }
    return v;
  }

  String getStrengthTrend(String exercise) =>
      AIEngine.getStrengthTrend(workout.logs, exercise);

  // From ai_setup_screen — accept WorkoutPlanResult from AIEngine.generateWeeklyPlan
  Future<void> applyGeneratedPlan(WorkoutPlanResult result) =>
      workout.applyGeneratedPlan(result);

  // From widgets/progress_chart.dart
  List<FlSpot> getProgressSpots(String key, String unit) {
    final filtered = workout.logs
        .where((l) => l.exercise == key && l.weight >= 0 && l.weight <= 500)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (filtered.isEmpty) return [];
    final spots = <FlSpot>[];
    for (int i = 0; i < filtered.length; i++) {
      final log = filtered[i];
      double y = unit == 'reps'
          ? log.reps.toDouble()
          : unit == 'min'
              ? log.minutes.toDouble()
              : log.weight;
      if (y <= 0 && spots.isNotEmpty) y = spots.last.y;
      if (y >= 0) spots.add(FlSpot(i.toDouble(), y));
    }
    if (spots.isEmpty) return [];
    return spots.length == 1
        ? [FlSpot(0, spots.first.y), FlSpot(1, spots.first.y)]
        : spots;
  }

  // Generic name expected by some old screens
  String get aiCoachMessage => dailyCoachMessage;
}
