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
import '../services/workout_session_service.dart';

import '../models/memory_models.dart';
import '../models/models.dart';
import '../models/readiness.dart';
import '../models/split_template.dart';
import '../models/workout_log.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../engines/pr_engine.dart' as pre;
import 'ai_provider.dart';
import 'analytics_provider.dart';
import 'settings_provider.dart';
import 'user_provider.dart';
import 'workout_provider.dart';
import '../services/progression_service.dart';
import '../models/coach_context.dart';
import '../models/athlete_memory.dart';
import '../services/coach_message_service.dart';
import '../services/athlete_profile_service.dart';
import '../models/coach_visual_state.dart';
import '../models/athlete_identity.dart';
import '../models/momentum_state.dart';
import '../models/daily_mission.dart';
import '../services/mission_service.dart';
import '../services/weekly_narrative_service.dart';
import '../models/recovery_state.dart';
import '../engines/recovery_engine.dart';
import '../engines/adaptive_schedule_engine.dart';
import '../models/workout_readiness_profile.dart';
import '../services/training_adjustment_service.dart';
import '../services/athlete_trend_service.dart';
import '../services/adherence_intelligence_service.dart';
import '../services/predictive_performance_service.dart';
import '../services/adaptive_programming_service.dart';
import '../services/exercise_intelligence_service.dart';
import '../services/athlete_memory_service.dart';
import '../services/progression_timeline_service.dart';
import '../services/weekly_evolution_service.dart';
import '../services/onboarding_intelligence_service.dart';
import '../services/recovery_prediction_service.dart';
import '../services/behavioral_pattern_service.dart';
import '../services/health_connect_service.dart';
import '../services/recovery_session_service.dart';
import '../services/narrative_orchestrator.dart';
import '../models/weekly_review_data.dart';
import '../models/unified_coach_insight.dart';
import '../services/coach_insight_orchestrator.dart';

/// Drives which adaptive surface the planner shows for today's session.
enum PlannerAdaptiveState {
  /// Suppressed muscles conflict with today's exercises — show intervention card.
  interventionRequired,
  /// Suppressed muscles exist but today's session already avoids them — show calm insight.
  recoveryAligned,
  /// No recovery concerns affecting today — show nothing.
  clear,
}

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

  // ── CoachContext cache — rebuilt at most every 5 minutes ──
  CoachContext? _coachContextCache;
  DateTime?     _coachContextCacheTime;

  // ── RecoveryState cache — rebuilt at most every 5 minutes ──────────────
  RecoveryState?             _cachedRecoveryState;
  DateTime?                  _recoveryComputedAt;
  RecoverySessionSuggestion? _cachedRecoverySuggestion;

  // ── TrainingAdjustment cache — invalidated with recovery ─────────────
  TrainingAdjustment?   _cachedAdjustment;
  DateTime?             _adjustmentComputedAt;

  // ── NarrativeMessage cache — invalidated with recovery + workout state ─
  NarrativeMessage? _cachedNarrative;
  DateTime?         _narrativeCacheTime;

  // ── AthleteTrendSnapshot cache — rebuilt every 5 minutes ──────────────
  AthleteTrendSnapshot? _cachedTrend;
  DateTime?             _trendComputedAt;

  // ── AdherenceProfile cache — rebuilt every 5 minutes ──────────────────
  AdherenceProfile? _cachedAdherence;
  DateTime?         _adherenceComputedAt;

  // ── PredictiveSnapshot cache — rebuilt every 15 minutes ───────────────
  PredictiveSnapshot? _cachedPredictive;
  DateTime?           _predictiveComputedAt;

  // ── AdaptiveWorkoutDecision cache — rebuilt every 5 minutes ───────────
  AdaptiveWorkoutDecision? _cachedAdaptive;
  DateTime?                _adaptiveComputedAt;

  // ── AthleteMemory — rebuilt after workout, persisted daily ──
  AthleteMemory? _athleteMemory;

  // ── AthleteMemorySnapshot cache — rebuilt every 5 minutes ─────────────
  AthleteMemorySnapshot? _cachedMemorySnapshot;
  DateTime?              _memorySnapshotComputedAt;

  // ── WeeklyEvolutionSnapshot cache — rebuilt every 15 minutes ──────────
  WeeklyEvolutionSnapshot? _cachedWeeklyEvolution;
  DateTime?                _weeklyEvolutionComputedAt;

  // ── OnboardingAthleteProfile cache — rebuilt every 5 minutes ───────────
  OnboardingAthleteProfile? _cachedOnboardingProfile;
  DateTime?                 _onboardingComputedAt;

  // ── RecoveryPrediction cache — rebuilt every 10 minutes ─────────────────
  RecoveryPrediction? _cachedRecoveryPrediction;
  DateTime?           _recoveryPredictionComputedAt;

  // ── BehavioralPattern cache — rebuilt every 30 minutes ──────────────────
  BehavioralPattern? _cachedBehavioralPattern;
  DateTime?          _behavioralPatternComputedAt;

  // ── WeeklyReviewData cache — rebuilt on workout completion / invalidation ─
  WeeklyReviewData? _cachedWeeklyReview;
  DateTime?         _weeklyReviewCachedAt;

  // ── HealthSnapshot — fetched once on init, refreshed every 30 minutes ───
  HealthSnapshot _latestHealthSnapshot = HealthSnapshot.empty;
  DateTime?      _healthSnapshotComputedAt;

  // Paywall trigger — set after key events, read by UI
  PaywallTrigger? _pendingPaywallTrigger;
  PaywallTrigger? get pendingPaywallTrigger => _pendingPaywallTrigger;
  void clearPaywallTrigger() {
    _pendingPaywallTrigger = null;
    notifyListeners();
  }

  /// Call after rewarded ad grant or premium upgrade to refresh AI limit state.
  void refreshMonetization() => notifyListeners();

  // Dedup flag: multiple children notifying in the same microtask queue
  // (e.g. workout + analytics both fire on save) collapse into one rebuild.
  bool _pendingNotify = false;
  void _onChildChanged() {
    if (_pendingNotify) return;
    _pendingNotify = true;
    Future.microtask(() {
      _pendingNotify = false;
      notifyListeners();
    });
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

      // Restore active workout session (if user was mid-workout)
      await WorkoutSessionService.instance.restoreFromDisk();

      // Load sub-providers in parallel — they're independent
      await Future.wait<void>([
        user.load(),
        settings.load(),
        workout.load(),
        analytics.load(),
        ai.load(),
      ]);

      // ── Streak health check (with travel mode freeze) ──
      await workout.checkStreakHealth(
        travelModeActive: settings.travelMode,
      );

      // Wire WorkoutProvider's external hooks now that AI is loaded.
      workout.wireExternalHooks(
        weightModifier:  () => ai.insight.weightModifier,
        recommendedSets: () => ai.insight.recommendedSets,
        weakMuscle:      () => ai.insight.weakMuscleGroup,
        travelMode:      () => settings.travelMode,
        userAge:         () => user.age,
      );

      // Compute initial analytics + AI insight
      await _recomputeAll();

      // Load athlete memory (persisted across sessions)
      await loadAthleteMemory();
      // Rebuild memory daily — stale if older than 24 hours
      if (_athleteMemory == null ||
          DateTime.now().difference(_athleteMemory!.updatedAt).inHours >= 24) {
        _rebuildAndSaveAthleteMemory().ignore();
      }

      // Fire daily Gemini brief — one call per day, ready within ~3s
      _triggerDailyBrief();

      // Schedule mission reminder for today if a workout is planned
      _scheduleTodayMissionReminder();
      // Schedule momentum protection if user hasn't trained in 2+ days
      _scheduleMomentumNotifications();
      // Inactivity alert — schedule notification for 3 days after last workout
      _scheduleInactivityAlertIfNeeded();
      // Initialize Health Connect silently — non-blocking, never crashes
      _initHealthConnect().ignore();

      // New week: ghost copy carries last week's plan with progressive weights.
      // Only fall back to smart-plan generation when there's no history to ghost from.
      if (workout.newWeekDetected && !workout.hasGhostCopyData) {
        Future.microtask(() => generateSmartPlan());
      }
    } catch (e, s) {
      debugPrint('AppProvider.init error: $e\n$s');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _scheduleTodayMissionReminder() {
    try {
      final plan = workout.todayPlan;
      if (plan.isRestDay || plan.exercises.isEmpty) return;
      NotificationService.instance.scheduleMissionReminder(
        planTitle:   plan.title,
        userName:    user.name.isEmpty ? 'Champion' : user.name,
        workoutDate: DateTime.now(),
      ).ignore();
    } catch (_) {}
  }

  void _scheduleMomentumNotifications() {
    try {
      final days = workout.daysSinceLastWorkout;
      if (days < 2) return;
      final name = user.name.isEmpty ? 'Champion' : user.name;
      NotificationService.instance.scheduleMomentumProtection(
        daysMissed:       days,
        previousStreak:   workout.streak.currentStreak,
        consistencyScore: athleteMemory.consistencyScore,
        userName:         name,
      ).ignore();
      // Weekly narrative notification (Sunday evening)
      final narrative = weeklyNarrative;
      if (narrative.hasContent) {
        NotificationService.instance.scheduleWeeklyNarrativeNotification(
          headline: narrative.headline,
          userName: name,
        ).ignore();
      }
      // Silent day re-engagement — schedule day 5/6/7 from last workout (Phase C1)
      // Only if the user is between day 4–6 so future notifications still fire.
      if (days >= 4 && days <= 6) {
        final lastDate = DateTime.now().subtract(Duration(days: days));
        NotificationService.instance.scheduleSilentDayNotifications(
          lastWorkoutDate: lastDate,
          userName:        name,
          streak:          workout.streak.currentStreak,
        ).ignore();
      }
    } catch (_) {}
  }

  void _scheduleInactivityAlertIfNeeded() {
    try {
      final notif = NotificationService.instance;
      if (!settings.inactivityAlertEnabled || settings.travelMode) {
        notif.cancelInactivityAlert().ignore();
        return;
      }
      final dateStr = workout.streak.lastWorkoutDate;
      if (dateStr.isEmpty) return;
      final lastDate = DateTime.parse(dateStr);
      notif.scheduleInactivityAlert(
        lastWorkoutDate: lastDate,
        userName: user.name.isEmpty ? 'Champion' : user.name,
      ).ignore();
    } catch (_) {}
  }

  void _triggerDailyBrief() {
    final todayPlan = workout.todayPlan;
    final exHistory = workout.buildExerciseHistory();
    ai.generateDailyBrief(
      goal:               user.goal,
      level:              user.level,
      streak:             workout.streak.currentStreak,
      todayWorkoutTitle:  todayPlan.title,
      todayExercises:     todayPlan.exercises.map((e) => e.name).toList(),
      muscleScores:       muscleRecoveryList
          .map((m) => (muscle: m.muscle, score: m.recoveryScore))
          .toList(),
      exerciseHistory:    exHistory
          .map((e) => (name: e.name, bestWeight: e.bestWeight, bestReps: e.bestReps))
          .toList(),
      forceRefresh:       true,
    ).ignore();
  }

  /// Recomputes both analytics and AI insight from current state.
  /// Called after any change that affects derived data.
  Future<void> _recomputeAll() async {
    await analytics.recompute(AnalyticsInputs(
      logs:                 workout.logs,
      mood:                 user.todayMood,
      streak:               workout.streak.currentStreak,
      overallRecoveryScore: recoveryState.overallScore.round(),
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

    debugPrint('[Momentum] before completion: score=${momentumState.score} '
        'streak=${workout.streak.currentStreak} '
        'daysSince=${workout.daysSinceLastWorkout} '
        'consistency=${athleteMemory.consistencyScore} '
        'missed=${athleteMemory.missedWorkoutsLast30}');

    final result = await workout.markDayComplete(dayIndex, durationMin);

    debugPrint('[Momentum] after completion: score=${momentumState.score} '
        'streak=${workout.streak.currentStreak} '
        'daysSince=${workout.daysSinceLastWorkout}');

    if (result.completedDay != null) {
      await ai.recordSession(
        day:              result.completedDay!,
        mood:             user.todayMood,
        normalizeMuscle:  WorkoutProvider.normalizeMuscle,
      );
      // Fire Gemini analysis — completes in ~3s, ready before summary sheet opens
      ai.generateSessionInsight(
        day:    result.completedDay!,
        mood:   user.todayMood,
        goal:   user.goal,
        level:  user.level,
        streak: workout.streak.currentStreak,
      ).ignore();
    }

    await _recomputeAll();

    // Refresh AI coach brief after workout completion.
    // Delayed 12 s so it lands outside the Cloud Function's 10 s cooldown
    // window that session insight already opened.
    ai.invalidateDailyBrief();
    Future.delayed(const Duration(seconds: 12), _triggerDailyBrief);

    // Proactive recovery notification — fires tomorrow 7:30AM if any muscle < 50%
    final recoveries = muscleRecoveryList;
    if (recoveries.isNotEmpty) {
      final lowest = recoveries.reduce(
          (a, b) => a.recoveryScore < b.recoveryScore ? a : b);
      await NotificationService.instance.scheduleRecoveryCoach(
        lowestMuscle: lowest.muscle,
        lowestScore:  lowest.recoveryScore,
        userName:     user.name.isEmpty ? 'Champion' : user.name,
      );
      // Recovery-ready notification — fires next morning when fully recovered
      await NotificationService.instance.scheduleRecoveryReadyNotification(
        readiness: settings.todayReadiness,
        userName:  user.name.isEmpty ? 'Champion' : user.name,
      );
    }

    // Streak milestone notification — fires immediately on threshold hit
    final newStreak = workout.streak.currentStreak;
    await NotificationService.instance.scheduleStreakMilestoneNotification(
      streak:   newStreak,
      userName: user.name.isEmpty ? 'Champion' : user.name,
    );

    // Silent day notifications — day 5/6/7 re-engagement (Phase C1)
    // Cancel any from the previous gap; schedule fresh from today's session.
    await NotificationService.instance.scheduleSilentDayNotifications(
      lastWorkoutDate: DateTime.now(),
      userName:        user.name.isEmpty ? 'Champion' : user.name,
      streak:          newStreak,
    );

    // Behavior-based paywall trigger
    _pendingPaywallTrigger = await checkPaywallTrigger();

    debugPrint('[Momentum] before notifyListeners: score=${momentumState.score} '
        'consistency=${athleteMemory.consistencyScore} '
        'missed=${athleteMemory.missedWorkoutsLast30}');
    notifyListeners();
    debugPrint('[Momentum] after notifyListeners: score=${momentumState.score}');

    // Track to analytics
    AnalyticsService.instance.workoutComplete(durationMin, 100);

    invalidateCoachContext();
    invalidateRecoveryState(); // also calls _invalidateNarrative()
    debugPrint('[Momentum] after invalidateRecoveryState: score=${momentumState.score} '
        'consistency=${athleteMemory.consistencyScore} '
        'missed=${athleteMemory.missedWorkoutsLast30}');

    // Rebuild athlete memory with fresh data after each completed workout.
    // Runs sync-then-async: _athleteMemory is set before the next frame renders.
    _rebuildAndSaveAthleteMemory().ignore();
    debugPrint('[Momentum] after memory rebuild (new values): score=${momentumState.score} '
        'consistency=${athleteMemory.consistencyScore} '
        'missed=${athleteMemory.missedWorkoutsLast30}');

    return result.newBadges;
  }

  // ═════════════════════════════════════════════════════════
  // COACH CONTEXT
  // ═════════════════════════════════════════════════════════

  void invalidateCoachContext() {
    _coachContextCache     = null;
    _coachContextCacheTime = null;
  }

  // ═════════════════════════════════════════════════════════
  // NARRATIVE ORCHESTRATOR — phase-aware unified messaging
  // ═════════════════════════════════════════════════════════

  /// Cached for 2 minutes. Invalidated on workout completion and recovery change.
  NarrativeMessage get _narrativeMessage {
    final now = DateTime.now();
    if (_cachedNarrative != null &&
        _narrativeCacheTime != null &&
        now.difference(_narrativeCacheTime!).inSeconds < 120) {
      return _cachedNarrative!;
    }
    _cachedNarrative = NarrativeOrchestrator.build(_buildNarrativeContext());
    _narrativeCacheTime = now;
    return _cachedNarrative!;
  }

  NarrativeContext _buildNarrativeContext() {
    final plan     = workout.todayPlan;
    final rs       = recoveryState;
    final daysSince = workout.daysSinceLastWorkout;
    final total    = workout.streak.totalWorkouts;
    final ms       = momentumState;

    // ── Phase detection ─────────────────────────────────────────────────
    final NarrativePhase phase;
    if (plan.isRestDay) {
      phase = NarrativePhase.restDay;
    } else if (daysSince >= 4 && total > 0) {
      phase = NarrativePhase.comeback;
    } else if (plan.isCompleted && daysSince == 0) {
      phase = NarrativePhase.postWorkout;
    } else if (daysSince == 1) {
      phase = NarrativePhase.nextDay;
    } else {
      phase = NarrativePhase.preWorkout;
    }

    // ── Muscles trained today (from completed plan exercises) ────────────
    final trainedToday = plan.isCompleted
        ? plan.exercises
            .map((e) => e.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];

    // ── Suppressed / ready muscles from recovery scores ──────────────────
    final suppressedMuscles = rs.muscleScores.entries
        .where((e) => e.value < 60)
        .map((e) => e.key)
        .toList();

    final readyMuscles = rs.muscleScores.entries
        .where((e) => e.value >= 80)
        .map((e) => e.key)
        .toList();

    // ── PR today ─────────────────────────────────────────────────────────
    final latestPR = coachContext.latestPR;
    final prToday  = latestPR != null &&
        DateTime.now().difference(latestPR.date).inHours < 24;

    // ── Recovery improving ────────────────────────────────────────────────
    final recoveryImproving =
        rs.readiness == RecoveryReadiness.ready ||
        rs.readiness == RecoveryReadiness.peak;

    final hs = _latestHealthSnapshot;

    // ── Session performance — post-workout only ──────────────────────────
    // history.first is the most recent entry; inserted at index 0 on completion.
    // All values default to 0/false so pre-workout phases are completely unaffected.
    double sessionVolumeKg   = 0.0;
    int    sessionSetCount   = 0;
    double previousVolumeKg  = 0.0;
    bool   hasPreviousSession = false;

    if (plan.isCompleted && workout.history.isNotEmpty) {
      final todayEntry = workout.history.first;
      sessionVolumeKg = todayEntry.totalVolume;
      sessionSetCount = todayEntry.setCount;

      // Find last session with same workout name that has weight data.
      // Skip(1) excludes today's entry; requires name match + non-zero volume.
      if (sessionVolumeKg > 0) {
        final matches = workout.history
            .skip(1)
            .where((h) =>
                h.workoutName == todayEntry.workoutName && h.totalVolume > 0)
            .toList();
        if (matches.isNotEmpty) {
          previousVolumeKg   = matches.first.totalVolume;
          hasPreviousSession = true;
        }
      }
    }

    return NarrativeContext(
      phase:              phase,
      recoverySuppressed: rs.isRecoverySuppressed,
      recoveryImproving:  recoveryImproving,
      highFatigue:        rs.highFatigue,
      needsDeload:        rs.needsDeload,
      overallRecovery:    rs.overallScore,
      limitingMuscle:     rs.primaryLimitingMuscle,
      trainedToday:       trainedToday,
      suppressedMuscles:  suppressedMuscles,
      readyMuscles:       readyMuscles,
      prToday:            prToday,
      isDropoutRisk:      isAtRiskOfDropout,
      isLockedIn:         ms.lockedIn,
      isRising:           ms.rising,
      momentumScore:      ms.score,
      daysSince:          daysSince,
      sleepHours:         hs.sleepHours,
      hasSleepData:       hs.hasSleepData,
      sessionVolumeKg:    sessionVolumeKg,
      sessionSetCount:    sessionSetCount,
      previousVolumeKg:   previousVolumeKg,
      hasPreviousSession: hasPreviousSession,
    );
  }

  // ═════════════════════════════════════════════════════════
  // RECOVERY STATE — single authoritative source
  // ═════════════════════════════════════════════════════════

  /// Cached for 5 minutes. Invalidated explicitly after workout completion.
  RecoveryState get recoveryState {
    final now = DateTime.now();
    if (_cachedRecoveryState != null &&
        _recoveryComputedAt  != null &&
        now.difference(_recoveryComputedAt!).inSeconds < 300) {
      return _cachedRecoveryState!;
    }
    final hs = _latestHealthSnapshot;
    _cachedRecoveryState = RecoveryEngine.compute(
      RecoveryEngineInput(
        lastMuscleTrained:    workout.lastTrainedByMuscle,
        weeklyMuscleVolume:   workout.weeklyVolumeByMuscle,
        age:                  user.age,
        streak:               workout.streak.currentStreak,
        weeklyVolumeTotal:    workout.weeklyVolumeTotalKg,
        previousWeeklyVolume: workout.previousWeeklyVolumeTotalKg,
        readiness:            settings.todayReadiness,
        now:                  now,
        sleepHours:    hs.hasSleepData ? hs.sleepHours   : null,
        todayStepCount: hs.hasStepsData ? hs.todaySteps   : null,
      ),
    );
    _recoveryComputedAt = now;
    return _cachedRecoveryState!;
  }

  /// Current adaptive scheduling profile — null when not using AI Adaptive.
  /// Derived from cached recoveryState; no extra caching required.
  WorkoutReadinessProfile? get currentAdaptiveProfile {
    if (settings.splitStyle != SplitStyle.aiAdaptive) return null;
    return AdaptiveScheduleEngine.compute(
      recoveryState: recoveryState,
      selectedDays:  settings.gymDaysPerWeek,
      level:         user.level,
      goal:          user.goal,
      totalWorkouts: workout.streak.totalWorkouts,
    );
  }

  void _invalidateNarrative() {
    _cachedNarrative    = null;
    _narrativeCacheTime = null;
  }

  void invalidateRecoveryState() {
    _cachedRecoveryState      = null;
    _invalidateNarrative();
    _recoveryComputedAt       = null;
    _cachedRecoverySuggestion = null;
    _cachedAdjustment         = null;
    _adjustmentComputedAt     = null;
    _cachedTrend              = null;
    _trendComputedAt          = null;
    _cachedAdherence      = null;
    _adherenceComputedAt  = null;
    _cachedPredictive     = null;
    _predictiveComputedAt = null;
    _cachedAdaptive              = null;
    _adaptiveComputedAt          = null;
    _cachedMemorySnapshot        = null;
    _memorySnapshotComputedAt    = null;
    _cachedWeeklyEvolution       = null;
    _weeklyEvolutionComputedAt   = null;
    _cachedOnboardingProfile       = null;
    _onboardingComputedAt          = null;
    _cachedRecoveryPrediction      = null;
    _recoveryPredictionComputedAt  = null;
    _cachedBehavioralPattern       = null;
    _behavioralPatternComputedAt   = null;
    _cachedWeeklyReview            = null;
    _weeklyReviewCachedAt          = null;
    notifyListeners();
  }

  // ── Recovery Session suggestion — cached with recovery state ──────────────

  RecoverySessionSuggestion get recoverySuggestion {
    final cached = _cachedRecoverySuggestion;
    if (cached != null &&
        cached.computedAt.millisecondsSinceEpoch > 0 &&
        cached.computedAt.isAfter(
            recoveryState.updatedAt.subtract(const Duration(seconds: 1)))) {
      return cached;
    }
    _cachedRecoverySuggestion = RecoverySessionService.compute(
      recoveryState:            recoveryState,
      daysSinceLastWorkout:     workout.daysSinceLastWorkout,
      adherenceBurnoutLevel:    adherenceBurnoutLevel,
      predictiveCollapseLevel:  predictiveCollapseLevel,
      todayExerciseCategories:  workout.todayPlan.exercises
                                    .map((e) => e.category)
                                    .toList(),
    );
    return _cachedRecoverySuggestion!;
  }

  // ── Health Connect public surface ─────────────────────────────────────────

  /// True if Health Connect is linked and returned data.
  bool get healthConnectLinked => _latestHealthSnapshot.isConnected;

  /// Contextual sleep note — shown only when HC data is available.
  String get sleepContextLine {
    final snap = _latestHealthSnapshot;
    if (!snap.isConnected || !snap.hasSleepData || snap.sleepHours <= 0) return '';
    final h = snap.sleepHours;
    if (h < 5.5) return 'Sleep was below average last night — readiness may be slightly reduced.';
    if (h < 7.0) return 'Sleep was slightly below your recent pattern.';
    if (h >= 8.0) return 'Recovery conditions improved overnight.';
    return '';
  }

  /// Raw sleep hours for Home AI Coach sleep-aware messaging.
  /// Returns 0.0 when Health Connect is unavailable, not connected, or has no sleep data.
  /// Callers treat 0.0 as "no data" and must not surface any sleep copy.
  double get coachSleepHours {
    final snap = _latestHealthSnapshot;
    if (!snap.isConnected || !snap.hasSleepData || snap.sleepHours <= 0) return 0.0;
    return snap.sleepHours;
  }

  /// Today's step count from Health Connect.
  /// Returns 0 when HC is unavailable, not connected, or has no step data.
  int get healthTodaySteps {
    final snap = _latestHealthSnapshot;
    if (!snap.isConnected || !snap.hasStepsData) return 0;
    return snap.todaySteps;
  }

  /// Title of the next non-rest training session after today in the week plan.
  /// Returns '' when today is the last training day, the rest of the week is rest days,
  /// or no plan exists. Callers must treat '' as "no data" and show no continuity copy.
  String get nextWorkoutTitle {
    final plan  = workout.weekPlan;
    final start = workout.todayIndex + 1;
    for (int i = start; i < plan.length; i++) {
      final day = plan[i];
      if (!day.isRestDay && day.exercises.isNotEmpty) return day.title;
    }
    return '';
  }

  /// Primary limiting muscle and estimated recovery ETA, both from RecoveryEngine.
  /// Single source of truth — uses the same muscle scores that drive all other
  /// recovery decisions, so ETA is consistent with the recovery orb and planner.
  /// Returns (muscle:'', hours:0) when no limiting muscle exists or ETA is zero.
  ({String muscle, int hours}) get limitingMuscleEta {
    final muscle = recoveryState.primaryLimitingMuscle;
    if (muscle.isEmpty) return (muscle: '', hours: 0);
    final score = recoveryState.muscleScores[muscle];
    if (score == null) return (muscle: muscle, hours: 0);
    return (muscle: muscle, hours: RecoveryEngine.muscleEtaHours(muscle, score));
  }

  /// Show Health Connect permission dialog; if granted, refresh snapshot.
  Future<bool> requestHealthPermissions() async {
    final ok = await HealthConnectService.instance.requestPermissions();
    if (ok) {
      await _refreshHealthSnapshot();
      invalidateRecoveryState();
    }
    return ok;
  }

  Future<void> _initHealthConnect() async {
    try {
      final svc = HealthConnectService.instance;
      final ok = await svc.initialize();
      if (!ok) return;
      final available = await svc.isAvailable();
      if (!available) return;
      // hasPermissions() is unreliable for granted→false (known health pkg bug),
      // but correctly returns false when never granted. Guard here prevents
      // Android from logging READ_STEPS/READ_SLEEP missing on first launch.
      final granted = await svc.hasPermissions();
      if (!granted) return;
      await _refreshHealthSnapshot();
      invalidateRecoveryState();
    } catch (_) {
      // Health Connect is optional — never block app startup
    }
  }

  Future<void> _refreshHealthSnapshot() async {
    final now = DateTime.now();
    if (_healthSnapshotComputedAt != null &&
        now.difference(_healthSnapshotComputedAt!).inMinutes < 30) return;
    try {
      _latestHealthSnapshot = await HealthConnectService.instance.fetchSnapshot();
      _healthSnapshotComputedAt = now;
    } catch (_) {
      _latestHealthSnapshot = HealthSnapshot.empty;
    }
  }

  AthleteTrendSnapshot get athleteTrend {
    final now = DateTime.now();
    if (_cachedTrend != null &&
        _trendComputedAt != null &&
        now.difference(_trendComputedAt!).inSeconds < 300) {
      return _cachedTrend!;
    }
    _cachedTrend = AthleteTrendService.compute(AthleteTrendInput(
      recentPRs:              workout.recentPRs,
      weeklyVolumeKg:         workout.weeklyVolumeTotalKg,
      previousWeeklyVolumeKg: workout.previousWeeklyVolumeTotalKg,
      avgWeeklyVolumeKg:      athleteMemory.avgWeeklyVolume,
      consistencyScore:       athleteMemory.consistencyScore,
      missedWorkoutsLast30:   athleteMemory.missedWorkoutsLast30,
      muscleFrequency:        athleteMemory.muscleFrequency,
      recoveryScore:          recoveryState.overallScore,
      recoveryTrend:          analytics.recoveryTrend,
      fatigueIndex:           analytics.fatigueIndex,
      plateauScore:           analytics.plateauScore,
      overTrainingRisk:       analytics.overTrainingRisk,
      weeklyImprovementPct:   analytics.weeklyImprovementPct,
      isOnPlateau:            analytics.isOnPlateau,
      currentStreak:          workout.streak.currentStreak,
      totalWorkouts:          workout.streak.totalWorkouts,
      needsDeload:            recoveryState.needsDeload,
      highFatigue:            recoveryState.highFatigue,
      now:                    now,
    ));
    _trendComputedAt = now;
    return _cachedTrend!;
  }

  // ── Trend display getters — consumed by home screen Selector ──────────
  String get trendInsight       => athleteTrend.coachInsight;
  int    get trendMomentumIndex => athleteTrend.momentumState.index;
  String get trendPhaseLabel    => athleteTrend.recommendedPhase.label;
  bool   get trendIsWarning     =>
      athleteTrend.overreachingRisk.index >= 2 ||
      athleteTrend.plateauRisk     == PlateauRisk.high;

  AdherenceProfile get adherenceProfile {
    final now = DateTime.now();
    if (_cachedAdherence != null &&
        _adherenceComputedAt != null &&
        now.difference(_adherenceComputedAt!).inSeconds < 300) {
      return _cachedAdherence!;
    }
    final trend = athleteTrend;
    final cutoff = now.subtract(const Duration(days: 30));
    final recentHistory = workout.history.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && d.isAfter(cutoff);
    }).toList();
    final cut21 = now.subtract(const Duration(days: 21));
    final prsLast21 = workout.recentPRs
        .where((p) => p.date.isAfter(cut21))
        .length;
    _cachedAdherence = AdherenceIntelligenceService.compute(
      AdherenceInsightInput(
        recentHistory:            recentHistory,
        consistencyScore:         athleteMemory.consistencyScore,
        missedWorkoutsLast30:     athleteMemory.missedWorkoutsLast30,
        fatiguePattern:           athleteMemory.fatiguePattern,
        motivationalTriggers:     athleteMemory.motivationalTriggers,
        fatigueCollapseAfterDays: athleteMemory.fatigueCollapseAfterDays,
        currentStreak:            workout.streak.currentStreak,
        longestStreak:            workout.streak.longestStreak,
        totalWorkouts:            workout.streak.totalWorkouts,
        daysSinceLastWorkout:     workout.daysSinceLastWorkout,
        skippedMuscleGroups:      workout.skippedMuscleGroups,
        recoveryScore:            recoveryState.overallScore,
        highFatigue:              recoveryState.highFatigue,
        needsDeload:              recoveryState.needsDeload,
        recoveryTrend:            analytics.recoveryTrend,
        overTrainingRisk:         analytics.overTrainingRisk,
        overreachingRiskLevel:    trend.overreachingRisk.index,
        consistencyTrendLevel:    trend.consistencyTrend.index,
        momentumLevel:            trend.momentumState.index,
        prsLast21Days:            prsLast21,
        now:                      now,
      ),
    );
    _adherenceComputedAt = now;
    return _cachedAdherence!;
  }

  // ── Adherence display getters — consumed by home screen Selector ───────
  String get adherenceInsight      => adherenceProfile.adherenceInsight;
  int    get adherenceBurnoutLevel => adherenceProfile.burnoutRisk.index;
  int    get adherenceMotivIndex   => adherenceProfile.motivationTrend.index;
  int    get disciplineScore       => adherenceProfile.disciplineScore;

  // ── PredictiveSnapshot — 15-minute TTL ───────────────────────────────
  PredictiveSnapshot get predictiveSnapshot {
    final now = DateTime.now();
    if (_cachedPredictive != null &&
        _predictiveComputedAt != null &&
        now.difference(_predictiveComputedAt!).inSeconds < 900) {
      return _cachedPredictive!;
    }
    final trend     = athleteTrend;
    final adherence = adherenceProfile;
    final cut21     = now.subtract(const Duration(days: 21));
    final prsLast21 = workout.recentPRs
        .where((p) => p.date.isAfter(cut21))
        .length;
    _cachedPredictive = PredictivePerformanceService.compute(
      PredictiveInput(
        recoveryScore:          recoveryState.overallScore,
        highFatigue:            recoveryState.highFatigue,
        needsDeload:            recoveryState.needsDeload,
        recoveryTrend:          analytics.recoveryTrend,
        momentumLevel:          trend.momentumState.index,
        plateauRiskLevel:       trend.plateauRisk.index,
        overreachingRiskLevel:  trend.overreachingRisk.index,
        fatigueTrendLevel:      trend.fatigueTrend.index,
        consistencyTrendLevel:  trend.consistencyTrend.index,
        progressionVelocity:    trend.progressionVelocity,
        burnoutRiskLevel:       adherence.burnoutRisk.index,
        streakFragilityLevel:   adherence.streakFragility.index,
        motivationTrendLevel:   adherence.motivationTrend.index,
        intimidationRiskLevel:  adherence.intimidationRisk.index,
        comebackProbability:    adherence.comebackProbability,
        overTrainingRisk:       analytics.overTrainingRisk,
        fatigueIndex:           analytics.fatigueIndex,
        weeklyImprovementPct:   analytics.weeklyImprovementPct,
        isOnPlateau:            analytics.isOnPlateau,
        weeklyVolumeKg:         workout.weeklyVolumeTotalKg,
        previousWeeklyVolumeKg: workout.previousWeeklyVolumeTotalKg,
        avgWeeklyVolumeKg:      athleteMemory.avgWeeklyVolume,
        currentStreak:          workout.streak.currentStreak,
        daysSinceLastWorkout:   workout.daysSinceLastWorkout,
        prsLast21Days:          prsLast21,
        totalWorkouts:          workout.streak.totalWorkouts,
        consistencyScore:       athleteMemory.consistencyScore,
        missedWorkoutsLast30:   athleteMemory.missedWorkoutsLast30,
        now:                    now,
      ),
    );
    _predictiveComputedAt = now;
    return _cachedPredictive!;
  }

  // ── Predictive display getters — consumed by home screen Selector ────────
  String get predictiveInsight       => predictiveSnapshot.predictiveInsight;
  int    get predictiveOverloadLevel => predictiveSnapshot.overloadReadiness.index;
  int    get predictiveCollapseLevel => predictiveSnapshot.recoveryCollapseRisk.index;
  String get nextPRWindow            => predictiveSnapshot.nextBestPRWindow;

  // ── One-dominant-insight resolver ────────────────────────────────────────
  // Priority: adherence risk > predictive collapse > predictive opportunity
  //           > predictive general > adherence positive > trend
  // Only ONE insight card renders at a time on the home screen.
  String get dominantInsightSource {
    // 1. Burnout or motivation drop — behavioural emergency
    if (adherenceInsight.isNotEmpty &&
        (adherenceBurnoutLevel >= 2 || adherenceMotivIndex >= 2)) {
      return 'adherence';
    }
    // 2. Predictive — recovery collapse warning
    if (predictiveInsight.isNotEmpty && predictiveCollapseLevel >= 2) {
      return 'predictive';
    }
    // 3. Predictive — overload window or PR opportunity
    if (predictiveInsight.isNotEmpty &&
        (predictiveOverloadLevel >= 2 || nextPRWindow.isNotEmpty)) {
      return 'predictive';
    }
    // 4. Predictive — any other forward-looking signal
    if (predictiveInsight.isNotEmpty) return 'predictive';
    // 5. Adherence — gentle or positive behavioural signal
    if (adherenceInsight.isNotEmpty) return 'adherence';
    // 6. Trend — long-term momentum / periodization
    if (trendInsight.isNotEmpty) return 'trend';
    return 'none';
  }

  // ── AdaptiveWorkoutDecision — 5-minute TTL ───────────────────────────
  AdaptiveWorkoutDecision get adaptiveDecision {
    final now = DateTime.now();
    if (_cachedAdaptive != null &&
        _adaptiveComputedAt != null &&
        now.difference(_adaptiveComputedAt!).inSeconds < 300) {
      return _cachedAdaptive!;
    }
    final trend      = athleteTrend;
    final adherence  = adherenceProfile;
    final predictive = predictiveSnapshot;
    final adjustment = trainingAdjustment;
    _cachedAdaptive = AdaptiveProgrammingService.compute(
      AdaptiveInput(
        recoveryScore:             recoveryState.overallScore,
        highFatigue:               recoveryState.highFatigue,
        needsDeload:               recoveryState.needsDeload,
        recoveryTrend:             analytics.recoveryTrend,
        suppressedMuscles:         adjustment.suppressedMuscles,
        shouldReduceAxialLoad:     adjustment.shouldReduceAxialLoad,
        recommendedFocusMuscles:   adjustment.recommendedFocusMuscles,
        momentumLevel:             trend.momentumState.index,
        overreachingRiskLevel:     trend.overreachingRisk.index,
        plateauRiskLevel:          trend.plateauRisk.index,
        fatigueTrendLevel:         trend.fatigueTrend.index,
        overloadReadinessLevel:    predictive.overloadReadiness.index,
        recoveryCollapseRiskLevel: predictive.recoveryCollapseRisk.index,
        burnoutRiskLevel:          adherence.burnoutRisk.index,
        intimidationRiskLevel:     adherence.intimidationRisk.index,
        comebackProbability:       adherence.comebackProbability,
        disciplineScore:           adherence.disciplineScore,
        weeklyImprovementPct:      analytics.weeklyImprovementPct,
        isOnPlateau:               analytics.isOnPlateau,
        daysSinceLastWorkout:      workout.daysSinceLastWorkout,
        totalWorkouts:             workout.streak.totalWorkouts,
        goal:                      user.goal,
        todayExerciseNames:        workout.todayPlan.exercises.map((e) => e.name).toList(),
        todayExerciseCategories:   workout.todayPlan.exercises.map((e) => e.category).toList(),
        now:                       now,
      ),
    );
    _adaptiveComputedAt = now;
    return _cachedAdaptive!;
  }

  // ── Adaptive display getters — consumed by home and planner Selectors ─────
  String get adaptiveFocusLabel     => adaptiveDecision.focus.label;
  String get adaptiveAthleteMessage => adaptiveDecision.athleteFacingMessage;
  bool   get isAdaptiveModified     => adaptiveDecision.shouldModifyWorkout;
  int    get adaptiveFocusIndex     => adaptiveDecision.focus.index;
  List<ExerciseSwap> get adaptiveSwaps => adaptiveDecision.swaps;

  /// Context-aware planner state — drives which surface (if any) to show.
  PlannerAdaptiveState get plannerAdaptiveState {
    final d = adaptiveDecision;
    if (d.shouldModifyWorkout && d.athleteFacingMessage.isNotEmpty) {
      return PlannerAdaptiveState.interventionRequired;
    }
    if (d.recoveryAlignedMessage.isNotEmpty) {
      return PlannerAdaptiveState.recoveryAligned;
    }
    return PlannerAdaptiveState.clear;
  }

  String get recoveryAlignedMessage => adaptiveDecision.recoveryAlignedMessage;
  bool   get isComebackSession      => adaptiveDecision.focus == AdaptiveTrainingFocus.comebackSession;

  // ── AthleteMemorySnapshot — 5-minute TTL ──────────────────────────────
  AthleteMemorySnapshot get athleteMemorySnapshot {
    final now = DateTime.now();
    if (_cachedMemorySnapshot != null &&
        _memorySnapshotComputedAt != null &&
        now.difference(_memorySnapshotComputedAt!).inSeconds < 300) {
      return _cachedMemorySnapshot!;
    }
    _cachedMemorySnapshot = AthleteMemoryService.build(
      logs:     workout.logs,
      history:  workout.history,
      streak:   workout.streak,
      weekPlan: workout.weekPlan,
      memory:   athleteMemory,
    );
    _memorySnapshotComputedAt = now;
    return _cachedMemorySnapshot!;
  }

  // ── Athlete Memory display getters ────────────────────────────────────
  String       get athleteIdentitySummary  => athleteMemorySnapshot.athleteIdentitySummary;
  List<String> get favoriteExercises       => athleteMemorySnapshot.favoriteExercises;
  List<String> get progressionMovements    => athleteMemorySnapshot.progressionMovements;
  List<String> get avoidedExercises        => athleteMemorySnapshot.avoidedExercises;
  String       get preferredSessionStyle   => athleteMemorySnapshot.preferredSessionStyle.label;

  // ── Exercise intelligence — classify any exercise name ────────────────
  ExerciseProfile classifyExercise(String name) =>
      ExerciseIntelligenceService.classify(name);

  // ── Progression timeline — used by stats_screen ───────────────────────
  ProgressionTimeline buildProgressionTimeline(ProgressionMetric metric) =>
      ProgressionTimelineService.buildTimeline(workout.logs, metric);

  List<ExerciseMastery> get movementMastery =>
      ProgressionTimelineService.computeMastery(workout.logs);

  // ── WeeklyEvolutionSnapshot — 15-minute TTL ───────────────────────────
  WeeklyEvolutionSnapshot get weeklyEvolution {
    final now = DateTime.now();
    if (_cachedWeeklyEvolution != null &&
        _weeklyEvolutionComputedAt != null &&
        now.difference(_weeklyEvolutionComputedAt!).inMinutes < 15) {
      return _cachedWeeklyEvolution!;
    }
    final trend     = athleteTrend;
    final adherence = adherenceProfile;
    final predictive = predictiveSnapshot;
    final memory    = athleteMemorySnapshot;
    final adaptive  = adaptiveDecision;
    final adjustment = trainingAdjustment;
    _cachedWeeklyEvolution = WeeklyEvolutionService.compute(
      WeeklyEvolutionInput(
        recoveryScore:             recoveryState.overallScore,
        highFatigue:               recoveryState.highFatigue,
        needsDeload:               recoveryState.needsDeload,
        shouldReduceAxialLoad:     adjustment.shouldReduceAxialLoad,
        suppressedMuscles:         adjustment.suppressedMuscles,
        momentumLevel:             trend.momentumState.index,
        overreachingRiskLevel:     trend.overreachingRisk.index,
        plateauRiskLevel:          trend.plateauRisk.index,
        fatigueTrendLevel:         trend.fatigueTrend.index,
        overloadReadinessLevel:    predictive.overloadReadiness.index,
        recoveryCollapseRiskLevel: predictive.recoveryCollapseRisk.index,
        burnoutRiskLevel:          adherence.burnoutRisk.index,
        disciplineScore:           adherence.disciplineScore,
        comebackProbability:       adherence.comebackProbability,
        weeklyImprovementPct:      analytics.weeklyImprovementPct,
        isOnPlateau:               analytics.isOnPlateau,
        daysSinceLastWorkout:      workout.daysSinceLastWorkout,
        totalWorkouts:             workout.streak.totalWorkouts,
        recentPRCount:             workout.recentPRs.length,
        goal:                      user.goal,
        progressionMovements:      memory.progressionMovements,
        recurringWeakPoints:       memory.recurringWeakPoints,
        favoriteExercises:         memory.favoriteExercises,
        adaptiveFocusIndex:        adaptive.focus.index,
        now:                       now,
      ),
    );
    _weeklyEvolutionComputedAt = now;
    return _cachedWeeklyEvolution!;
  }

  // ── Weekly Evolution display getters ──────────────────────────────────
  String get weeklyPhaseLabel          => weeklyEvolution.phase.label;
  String get weeklyPhaseColor          => weeklyEvolution.phase.color;
  String get weeklyEvolutionNarrative  => weeklyEvolution.athleteNarrative;
  String get weeklyInsight             => weeklyEvolution.weeklyInsight;
  double get weeklyReadinessScore  => weeklyEvolution.readinessScore;
  double get weeklyFatiguePressure => weeklyEvolution.fatiguePressure;
  int    get weeklyPhaseIndex      => weeklyEvolution.phase.index;
  bool   get weeklyRecommendDeload => weeklyEvolution.recommendDeload;
  WeeklyAdjustment? get topWeeklyAdjustment => weeklyEvolution.topAdjustment;
  List<WeeklyAdjustment> get weeklyAdjustments => weeklyEvolution.adjustments;
  double get weeklyProgressionScore      => weeklyEvolution.progressionScore;
  List<SmartIntervention> get smartInterventions => weeklyEvolution.smartInterventions;
  String get topSmartInterventionMessage =>
      weeklyEvolution.smartInterventions.isNotEmpty
          ? weeklyEvolution.smartInterventions.first.message
          : '';

  // ── Recovery Prediction — 10-minute TTL ──────────────────────────────────
  RecoveryPrediction get recoveryPrediction {
    final now = DateTime.now();
    if (_cachedRecoveryPrediction != null &&
        _recoveryPredictionComputedAt != null &&
        now.difference(_recoveryPredictionComputedAt!).inMinutes < 10) {
      return _cachedRecoveryPrediction!;
    }
    final rs = recoveryState;
    _cachedRecoveryPrediction = RecoveryPredictionService.compute(
      RecoveryPredictionInput(
        muscleScores:         rs.muscleScores,
        lastTrainedByMuscle:  workout.lastTrainedByMuscle,
        overallScore:         rs.overallScore,
        strain7d:             rs.strain7d,
        daysSinceLastWorkout: workout.daysSinceLastWorkout,
        now:                  now,
      ),
    );
    _recoveryPredictionComputedAt = now;
    return _cachedRecoveryPrediction!;
  }

  String get recoverySystemLine => recoveryPrediction.systemLine;

  // ── Behavioral Pattern — 30-minute TTL ───────────────────────────────────
  BehavioralPattern get behavioralPattern {
    final now = DateTime.now();
    if (_cachedBehavioralPattern != null &&
        _behavioralPatternComputedAt != null &&
        now.difference(_behavioralPatternComputedAt!).inMinutes < 30) {
      return _cachedBehavioralPattern!;
    }
    _cachedBehavioralPattern = BehavioralPatternService.compute(
      BehavioralPatternInput(
        history:              workout.history,
        daysSinceLastWorkout: workout.daysSinceLastWorkout,
        currentStreak:        workout.streak.currentStreak,
        totalWorkouts:        workout.streak.totalWorkouts,
        skippedMuscleGroups:  workout.skippedMuscleGroups,
        now:                  now,
      ),
    );
    _behavioralPatternComputedAt = now;
    return _cachedBehavioralPattern!;
  }

  String get retentionMessage             => behavioralPattern.retentionInsightLine;
  bool   get isAtRiskOfDropout            => behavioralPattern.isAtRiskOfDropout;
  String get preferredSessionRhythm       => behavioralPattern.consistencyRhythm;
  List<String> get skippedMuscleTendencies => behavioralPattern.skippedMuscleTendencies;

  // ── Onboarding profile — 5-minute TTL ────────────────────────────────────
  OnboardingAthleteProfile get onboardingProfile {
    final now = DateTime.now();
    if (_cachedOnboardingProfile != null &&
        _onboardingComputedAt != null &&
        now.difference(_onboardingComputedAt!).inSeconds < 300) {
      return _cachedOnboardingProfile!;
    }
    _cachedOnboardingProfile = OnboardingIntelligenceService.compute(
      logs:     workout.logs,
      history:  workout.history,
      streak:   workout.streak,
      weekPlan: workout.weekPlan,
    );
    _onboardingComputedAt = now;
    return _cachedOnboardingProfile!;
  }

  // ── Onboarding display getters ────────────────────────────────────────────
  String get onboardingNarrative      => onboardingProfile.onboardingNarrative;
  bool   get onboardingComplete       => onboardingProfile.onboardingComplete;
  bool   get isHighIntimidation       =>
      onboardingProfile.intimidationRisk == OnboardingIntimidationRisk.high;
  int    get intimidationRiskIdx      =>
      onboardingProfile.intimidationRisk.index;
  int    get adherenceProbabilityIdx  =>
      onboardingProfile.adherenceProbability.index;
  int    get recommendedCoachStyleIdx =>
      onboardingProfile.recommendedCoachStyle.index;
  int    get onboardingMotivationIdx  =>
      onboardingProfile.motivationStyle.index;
  List<String> get onboardingSignals  => onboardingProfile.onboardingSignals;

  TrainingAdjustment get trainingAdjustment {
    // Post-workout: pre-session load directives are no longer relevant.
    // Return baseline so _RecoveryDirectiveBanner is suppressed.
    if (workout.todayPlan.isCompleted) return TrainingAdjustment.baseline;

    final now = DateTime.now();
    if (_cachedAdjustment != null &&
        _adjustmentComputedAt != null &&
        now.difference(_adjustmentComputedAt!).inSeconds < 300) {
      return _cachedAdjustment!;
    }
    _cachedAdjustment = TrainingAdjustmentService.compute(
      recovery: recoveryState,
      context:  coachContext,
      day:      workout.todayPlan,
    );
    _adjustmentComputedAt = now;
    return _cachedAdjustment!;
  }

  // ── Planner narrative — phase-routed through NarrativeOrchestrator ────────

  /// Top-of-planner insight. Routes by training phase:
  ///   postWorkout  → recovery-state messaging (never pre-workout warnings)
  ///   activeWorkout → execution / pacing guidance
  ///   preWorkout   → readiness signals, load coaching, or aiSuggestion fallback
  /// Thin delegate — preserves all existing call sites that read plannerNarrative.
  String get plannerNarrative => plannerNarrativeFor(workout.todayIndex);

  /// Day-aware planner coaching. dayIdx = 0 (Mon) … 6 (Sun).
  /// TODAY  → full phase-aware logic (post-workout / active / pre-workout).
  /// PAST + COMPLETED → post-workout reflection for that day's exercises.
  /// FUTURE or PAST UNFINISHED → pre-workout coaching for that day's plan.
  String plannerNarrativeFor(int dayIdx) {
    final todayIdx = workout.todayIndex;
    final ctx      = _buildNarrativeContext();

    // ── TODAY — full existing logic, unchanged ───────────────────────────
    if (dayIdx == todayIdx) {
      final plan = workout.todayPlan;

      if (plan.isCompleted) {
        final msg = NarrativeOrchestrator.postWorkoutPlannerMessage(ctx);
        return msg.isEmpty
            ? 'Recovery window active. Sleep and nutrition are the work now.'
            : msg.body;
      }

      final inProgress = plan.exercises.any((e) => e.sets.any((s) => s.done));
      if (inProgress) {
        final msg = NarrativeOrchestrator.activeWorkoutMessage(ctx);
        return msg.isEmpty
            ? 'Focus on execution quality. Controlled effort compounds over time.'
            : msg.body;
      }

      if (!plan.isRestDay && plan.exercises.isNotEmpty) {
        final focused = _workoutFocusMessage(plan, ctx);
        if (focused.isNotEmpty) return focused;
      }

      final msg = NarrativeOrchestrator.preWorkoutPlannerMessage(ctx);
      return msg.isEmpty ? aiSuggestion : msg.body;
    }

    // ── NON-TODAY — guard bounds ─────────────────────────────────────────
    if (dayIdx < 0 || dayIdx >= workout.weekPlan.length) {
      return plannerNarrativeFor(todayIdx);
    }

    final plan   = workout.weekPlan[dayIdx];
    final isPast = dayIdx < todayIdx;

    // ── PAST + COMPLETED — post-workout reflection for that day ──────────
    // Patch context with the selected day's muscle categories.
    // Recovery signals (overallRecovery, sleep) remain current — still valid framing.
    // Session volume stats are cleared: they reflect the most recent session, not this day.
    if (isPast && plan.isCompleted) {
      final trainedCategories = plan.exercises
          .map((e) => e.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      final patchedCtx = ctx.copyWith(
        phase:             NarrativePhase.postWorkout,
        trainedToday:      trainedCategories,
        sessionVolumeKg:   0.0,
        sessionSetCount:   0,
        hasPreviousSession: false,
      );

      final msg = NarrativeOrchestrator.postWorkoutPlannerMessage(patchedCtx);
      return msg.isEmpty
          ? '${plan.title} complete. Recovery window active.'
          : msg.body;
    }

    // ── REST DAY ─────────────────────────────────────────────────────────
    if (plan.isRestDay) {
      return 'Rest day. Adaptation happens between sessions — the plan accounts for it.';
    }

    // ── FUTURE OR PAST UNFINISHED — pre-workout coaching for this plan ───
    // _workoutFocusMessage already accepts any DayPlan, so passing the
    // selected day's plan gives correctly titled, exercise-specific coaching.
    if (plan.exercises.isNotEmpty) {
      final focused = _workoutFocusMessage(plan, ctx);
      if (focused.isNotEmpty) return focused;
    }

    final msg = NarrativeOrchestrator.preWorkoutPlannerMessage(ctx);
    return msg.isEmpty ? plan.title : msg.body;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // WEEKLY REVIEW DATA
  // Single source of truth for the Weekly Review card.
  // Cached for 60 seconds; invalidated on workout completion.
  // All computation is pure — no Gemini, no external calls.
  // ═════════════════════════════════════════════════════════════════════════

  WeeklyReviewData get weeklyReviewData {
    final now = DateTime.now();
    if (_cachedWeeklyReview != null &&
        _weeklyReviewCachedAt != null &&
        now.difference(_weeklyReviewCachedAt!).inSeconds < 60) {
      return _cachedWeeklyReview!;
    }
    _cachedWeeklyReview   = _computeWeeklyReview();
    _weeklyReviewCachedAt = now;
    return _cachedWeeklyReview!;
  }

  // ── Week boundary: Monday 00:00:00 of the current calendar week ──────────
  static DateTime _weekMonday(DateTime ref) {
    final d = DateTime(ref.year, ref.month, ref.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  WeeklyReviewData _computeWeeklyReview() {
    final now       = DateTime.now();
    final monday    = _weekMonday(now);
    final hist      = workout.history;

    // ── Volume ─────────────────────────────────────────────────────────────
    // Uses HistoryEntry.totalVolume (already accurate — weight × reps on done sets).
    // Filtered to the current calendar week (Monday 00:00 → now).
    bool inThisWeek(String dateStr) {
      final d = DateTime.tryParse(dateStr);
      return d != null && !d.isBefore(monday);
    }

    final weekEntries        = hist.where((h) => inThisWeek(h.date)).toList();
    final weekVolumeKg       = weekEntries.fold(0.0, (s, h) => s + h.totalVolume);
    final previousWeekVolumeKg = workout.previousWeeklyVolumeTotalKg;

    final volumeDeltaPercent = previousWeekVolumeKg > 0
        ? (weekVolumeKg - previousWeekVolumeKg) / previousWeekVolumeKg * 100
        : 0.0;

    // ── Sessions ───────────────────────────────────────────────────────────
    final completedSessions  = weekEntries.length;
    final plannedSessions    = workout.weekPlan
        .where((d) => !d.isRestDay)
        .length;

    // plannedUntilToday: non-rest days from Monday through today only.
    // Future days are NOT counted as planned — they are scheduled.
    final todayWeekdayIdx    = (now.weekday - 1).clamp(0, 6);
    final plannedUntilToday  = workout.weekPlan
        .asMap()
        .entries
        .where((e) => e.key <= todayWeekdayIdx && !e.value.isRestDay)
        .length;
    final remainingScheduled = (plannedSessions - plannedUntilToday).clamp(0, plannedSessions);
    final missedSessions     = (plannedUntilToday - completedSessions).clamp(0, plannedUntilToday);

    // Adherence is mid-week fair: completed vs planned-until-today.
    final adherencePercent   = plannedUntilToday > 0
        ? (completedSessions / plannedUntilToday * 100).clamp(0.0, 100.0)
        : 0.0;

    // ── PRs this week ──────────────────────────────────────────────────────
    // recentPRs keeps one entry per exercise (most recent), max 14 days old.
    // Filtering by ≥ this Monday gives PR count for the current calendar week.
    final prCount = workout.recentPRs
        .where((p) => !p.date.isBefore(monday))
        .length;

    // ── Athlete context ─────────────────────────────────────────────────────
    final currentStreak    = workout.streak.currentStreak;
    final consistencyScore = athleteMemory.consistencyScore;

    // ── Recovery context ────────────────────────────────────────────────────
    final rs               = recoveryState;
    final overallRecovery  = rs.overallScore;
    final limitingMuscle   = rs.primaryLimitingMuscle;
    final recoverySuppressed = rs.isRecoverySuppressed;

    // ── Progression signal ─────────────────────────────────────────────────
    // analytics.weeklyImprovementPct is the week-over-week progression metric.
    final progressionScore = analytics.weeklyImprovementPct;

    // ── Derived narrative ──────────────────────────────────────────────────
    final rating = _computeWeekRating(
      adherencePercent:     adherencePercent,
      volumeDeltaPercent:   volumeDeltaPercent,
      recoverySuppressed:   recoverySuppressed,
      previousWeekVolumeKg: previousWeekVolumeKg,
      plannedSessions:      plannedSessions,
      completedSessions:    completedSessions,
    );

    final headline = _computeWeekHeadline(
      prCount:             prCount,
      volumeDeltaPercent:  volumeDeltaPercent,
      adherencePercent:    adherencePercent,
      completedSessions:   completedSessions,
      plannedSessions:     plannedSessions,
      weekVolumeKg:        weekVolumeKg,
      previousWeekVolumeKg: previousWeekVolumeKg,
    );

    final summary = _computeWeekSummary(
      prCount:              prCount,
      volumeDeltaPercent:   volumeDeltaPercent,
      adherencePercent:     adherencePercent,
      completedSessions:    completedSessions,
      plannedSessions:      plannedSessions,
      missedSessions:       missedSessions,
      remainingScheduled:   remainingScheduled,
      limitingMuscle:       limitingMuscle,
      recoverySuppressed:   recoverySuppressed,
      previousWeekVolumeKg: previousWeekVolumeKg,
    );

    return WeeklyReviewData(
      weekVolumeKg:         weekVolumeKg,
      previousWeekVolumeKg: previousWeekVolumeKg,
      volumeDeltaPercent:   volumeDeltaPercent,
      completedSessions:    completedSessions,
      plannedSessions:      plannedSessions,
      adherencePercent:     adherencePercent,
      prCount:              prCount,
      currentStreak:        currentStreak,
      consistencyScore:     consistencyScore,
      overallRecovery:      overallRecovery,
      limitingMuscle:       limitingMuscle,
      progressionScore:     progressionScore,
      headline:             headline,
      summary:              summary,
      rating:               rating,
    );
  }

  // ── Rating ────────────────────────────────────────────────────────────────
  //
  // Priority order:
  //   1. RecoveryWeek — volume intentionally down while recovery suppressed
  //      Guard: previous week must have existed (prevVol > 0) to confirm the
  //      drop was real, not a first-week baseline issue.
  //   2. Excellent — perfect adherence with no volume regression
  //   3. Strong    — ≥ 80% adherence
  //   4. Solid     — ≥ 60% adherence
  //   5. Inconsistent — below 60%
  //   Zero-plan edge case: default to Solid (no judgment without a plan).
  static WeekRating _computeWeekRating({
    required double adherencePercent,
    required double volumeDeltaPercent,
    required bool   recoverySuppressed,
    required double previousWeekVolumeKg,
    required int    plannedSessions,
    required int    completedSessions,
  }) {
    if (plannedSessions == 0) return WeekRating.solid;

    if (recoverySuppressed &&
        previousWeekVolumeKg > 0 &&
        volumeDeltaPercent < -5.0) {
      return WeekRating.recoveryWeek;
    }
    if (adherencePercent >= 100 && volumeDeltaPercent >= 0) {
      return WeekRating.excellent;
    }
    if (adherencePercent >= 80) return WeekRating.strong;
    if (adherencePercent >= 60) return WeekRating.solid;
    return WeekRating.inconsistent;
  }

  // ── Headline ──────────────────────────────────────────────────────────────
  //
  // Priority order (highest signal wins):
  //   1. PR count — strongest achievement signal, always shown first
  //   2. Volume increase > 10% — progression milestone
  //   3. Perfect adherence — habit/consistency milestone
  //   4. Fallback — raw session + volume summary
  static String _computeWeekHeadline({
    required int    prCount,
    required double volumeDeltaPercent,
    required double adherencePercent,
    required int    completedSessions,
    required int    plannedSessions,
    required double weekVolumeKg,
    required double previousWeekVolumeKg,
  }) {
    // 1. PRs
    if (prCount > 0) {
      final noun = prCount == 1 ? 'Personal Record' : 'Personal Records';
      return '$prCount $noun this week';
    }

    // 2. Volume increase > 10% (only meaningful when previous week exists)
    if (previousWeekVolumeKg > 0 && volumeDeltaPercent > 10) {
      return '+${volumeDeltaPercent.round()}% volume vs last week';
    }

    // 3. Perfect adherence
    if (plannedSessions > 0 && adherencePercent >= 100) {
      return 'Perfect week — $completedSessions/$plannedSessions sessions complete';
    }

    // 4. Fallback
    if (completedSessions > 0) {
      final volStr = WeeklyReviewData.fmtVol(weekVolumeKg);
      final sessStr = '$completedSessions session${completedSessions > 1 ? "s" : ""}';
      return weekVolumeKg > 0
          ? '$sessStr • $volStr lifted'
          : '$sessStr logged this week';
    }

    return 'No sessions logged yet this week';
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  //
  // Single-sentence narrative. Priority:
  //   1. PR achieved → acknowledge + adherence context
  //   2. Volume delta ≥ 5% either direction → volume story
  //   3. Missed sessions → gap acknowledgement
  //   4. Recovery limiting → muscle fatigue context
  //   5. Positive completion → forward-looking
  //   6. Empty state → prompt to start logging
  static String _computeWeekSummary({
    required int    prCount,
    required double volumeDeltaPercent,
    required double adherencePercent,
    required int    completedSessions,
    required int    plannedSessions,
    required int    missedSessions,
    required int    remainingScheduled,
    required String limitingMuscle,
    required bool   recoverySuppressed,
    required double previousWeekVolumeKg,
  }) {
    // 1. PR achieved this week
    if (prCount > 0) {
      final noun = prCount == 1 ? 'record' : 'records';
      if (adherencePercent >= 100 && plannedSessions > 0) {
        return '${prCount == 1 ? "One personal" : "$prCount personal"} '
            '$noun${prCount > 1 ? "s" : ""} recorded while completing all planned sessions.';
      }
      return '${prCount == 1 ? "One personal $noun" : "$prCount personal ${noun}s"} '
          'recorded this week.';
    }

    // 2. Volume comparison (requires previous week data + ≥ 5% delta)
    if (previousWeekVolumeKg > 0 && volumeDeltaPercent.abs() >= 5) {
      final pct = volumeDeltaPercent.abs().round();
      if (volumeDeltaPercent > 0) {
        final qualifier = adherencePercent >= 100
            ? ' while maintaining full adherence.'
            : adherencePercent >= 80
                ? ' with strong session completion.'
                : '.';
        return 'Volume increased $pct% vs last week$qualifier';
      } else {
        // Volume down — frame contextually
        if (recoverySuppressed) {
          return 'Volume reduced $pct% — consistent with a recovery-focused week.';
        }
        return 'Volume decreased $pct% vs last week — '
            'evaluate whether load or frequency needs adjustment.';
      }
    }

    // 3. Session summary — future days are scheduled, not missed.
    if (plannedSessions > 0) {
      if (missedSessions > 0 && completedSessions > 0) {
        final sessWord = completedSessions > 1 ? 'sessions' : 'session';
        if (remainingScheduled > 0) {
          final remWord  = remainingScheduled > 1 ? 'sessions' : 'session';
          final missWord = missedSessions > 1 ? 'sessions' : 'session';
          return '$completedSessions $sessWord completed. '
              '$missedSessions $missWord missed — '
              '$remainingScheduled $remWord remaining this week.';
        }
        return '$completedSessions $sessWord completed. '
            'Training rhythm remains on course.';
      }
      if (missedSessions > 0 && completedSessions == 0) {
        if (remainingScheduled > 0) {
          final remWord = remainingScheduled > 1 ? 'sessions' : 'session';
          return '$remainingScheduled $remWord remain scheduled this week — '
              'resume the plan to maintain your training rhythm.';
        }
        return 'No sessions completed yet this week — training rhythm continues next cycle.';
      }
    }

    // 4. Recovery limiting muscle
    if (recoverySuppressed && limitingMuscle.isNotEmpty) {
      final cap = '${limitingMuscle[0].toUpperCase()}${limitingMuscle.substring(1)}';
      return '$cap recovery remains limited — '
          'adapt loading this week to protect the adaptation.';
    }

    // 5. Positive completion
    if (completedSessions > 0) {
      return 'Recovery and adaptation are pacing the next progression block.';
    }

    // 6. Empty state
    return 'Log your first session to begin tracking weekly progress.';
  }

  /// Generates a short workout-specific actionable message for the planner AI banner.
  /// Format: "[Title] day. [Recovery-gated PR/load directive]."
  String _workoutFocusMessage(DayPlan plan, NarrativeContext ctx) {
    final title = plan.title
        .replaceAll('😴', '').replaceAll('😪', '').trim();
    if (title.isEmpty) return '';

    // Short exercise name — strip equipment prefixes, take first 2 words
    String shorten(String name) => name
        .replaceAll(
            RegExp(r'\b(Barbell|Dumbbell|Machine|Cable|EZ|Smith)\b',
                caseSensitive: false),
            '')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .join(' ')
        .toLowerCase();

    final compounds = plan.exercises
        .where((e) => e.category.toLowerCase() != 'rest')
        .take(2)
        .map((e) => shorten(e.name))
        .where((s) => s.isNotEmpty)
        .toList();

    final recovery = ctx.overallRecovery.round();

    // ── Sleep signal ─────────────────────────────────────────────────────────
    // Surfaces only when Health Connect returned a plausible reading (≥ 1h).
    // Sub-1h readings are noise / sensor gaps — treat as no data.
    final bool sleepKnown  = ctx.hasSleepData && ctx.sleepHours >= 1.0;
    final String sleepStr  = sleepKnown ? ctx.sleepHours.toStringAsFixed(1) : '';
    final bool poorSleep   = sleepKnown && ctx.sleepHours < 6.0;
    final bool strongSleep = sleepKnown && ctx.sleepHours >= 8.0;

    // ── PR Proximity ──────────────────────────────────────────────────────────
    // Scans weight-based exercises for how close the planned load is to the
    // all-time best. Only surfaces in the ≥ 80% recovery branch where an
    // attempt is physiologically supported.
    //
    // Guards:
    //   ex.isWeight     — skip cardio (min) and pure bodyweight exercises
    //   prWeight > 0    — skip when no log history exists for this exercise
    //   plannedWeight > 0 — skip when no weight has been entered in the plan
    //   0 ≤ gap ≤ 5 kg  — skip if already above PR (gap < 0) or too far away

    // Capitalises first letter of a shortened exercise name ("bench press" → "Bench press").
    String capFirst(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    // Formats a kg gap as an integer when whole, otherwise one decimal place.
    String fmtGap(double g) =>
        g == g.roundToDouble() ? '${g.round()} kg' : '${g.toStringAsFixed(1)} kg';

    final List<({String label, double gap, bool isStrong})> prOpps = [];

    for (final ex in plan.exercises) {
      if (!ex.isWeight) continue;
      final prKey = workout.getKey(ex.baseId);
      final prWeight = workout.getPR(prKey, ex.unit);
      if (prWeight <= 0) continue;

      final weights = ex.sets.map((s) => s.weight).where((w) => w > 0).toList();
      if (weights.isEmpty) continue;
      final plannedWeight = weights.reduce((a, b) => a > b ? a : b);

      final gap = prWeight - plannedWeight;
      if (gap < 0 || gap > 5.0) continue;

      prOpps.add((
        label:    capFirst(shorten(ex.name)),
        gap:      gap,
        isStrong: gap <= 2.5,
      ));
    }

    // ── High recovery (≥ 80%) ────────────────────────────────────────────────
    if (ctx.overallRecovery >= 80) {
      if (poorSleep) {
        // Recovery score is good but sleep limits neurological output.
        // Override PR coaching — scale back to quality sets.
        final exNote = compounds.isNotEmpty
            ? 'Quality sets on ${compounds[0]} — skip max-effort attempts today.'
            : 'Solid working sets — skip max-effort attempts today.';
        return '$title day. Sleep logged at ${sleepStr}h — '
            'recovery supports training, but reduced sleep may limit peak output. $exNote';
      }

      // ── PR Proximity — named opportunity replaces generic PR coaching ────────
      // poorSleep already handled above (suppresses max-effort intent).
      // Only fires when actual log history and planned weight exist.
      if (prOpps.isNotEmpty) {
        if (strongSleep && sleepStr.isNotEmpty) {
          // Sleep + high recovery + PR proximity — amplify the signal.
          if (prOpps.length >= 2) {
            final ex1 = prOpps[0].label;
            final ex2 = prOpps[1].label;
            return '$title day. Sleep at ${sleepStr}h — '
                '$ex1 and $ex2 are in PR territory. '
                'Strong recovery foundation supports max attempts today.';
          }
          final opp = prOpps.first;
          if (opp.isStrong) {
            return '$title day. Sleep at ${sleepStr}h — '
                '${opp.label} is within ${fmtGap(opp.gap)} of your all-time best. '
                'Prime conditions for an attempt today.';
          }
          return '$title day. Sleep at ${sleepStr}h — '
              '${opp.label} is in PR territory. '
              'Recovery supports progressive loading today.';
        }
        // No HC sleep data or normal sleep (6–8h) — standard PR proximity copy.
        if (prOpps.length >= 2) {
          final count = prOpps.length;
          final ex1   = prOpps[0].label;
          final ex2   = prOpps[1].label;
          return '$title day. $count exercises in PR territory: $ex1 and $ex2. '
              'Recovery at $recovery% — good conditions for an attempt.';
        }
        final opp = prOpps.first;
        if (opp.isStrong) {
          return '$title day. ${opp.label} is within ${fmtGap(opp.gap)} of your all-time best — '
              'recovery supports an attempt today.';
        }
        return '$title day. ${opp.label} is in PR territory — '
            'focus on progressive loading today.';
      }

      if (strongSleep) {
        // Both recovery and sleep optimal — amplify progressive intent.
        if (compounds.length >= 2) {
          return '$title day. Sleep at ${sleepStr}h — strong recovery foundation. '
              'Target 1–2 PR attempts on ${compounds[0]} and ${compounds[1]}.';
        }
        if (compounds.isNotEmpty) {
          return '$title day. Sleep at ${sleepStr}h — strong recovery foundation. '
              'Target a PR on ${compounds[0]} today.';
        }
        return '$title day. Sleep at ${sleepStr}h — strong recovery foundation. '
            'Full training intensity is supported today.';
      }
      // 6–8h sleep or no HC data — standard high-recovery message.
      if (compounds.length >= 2) {
        return '$title day. Recovery at $recovery% — '
            'target 1–2 PR attempts on ${compounds[0]} and ${compounds[1]}.';
      }
      if (compounds.isNotEmpty) {
        return '$title day. Strong recovery — '
            'target a PR on ${compounds[0]} today.';
      }
      return '$title day. Recovery is strong — push intensity across all sets.';
    }

    // ── Moderate recovery (60–79%) ────────────────────────────────────────────
    if (ctx.overallRecovery >= 60) {
      if (poorSleep) {
        return '$title day. Sleep logged at ${sleepStr}h — '
            'recovery supports productive training. '
            'Maintain current loading and focus on execution quality.';
      }
      if (compounds.isNotEmpty) {
        return '$title day. Good conditions — '
            'prioritise quality on ${compounds[0]}. Maintain current loading.';
      }
      return '$title day. Solid session conditions. Focus on execution quality.';
    }

    // ── Low recovery (< 60%) ─────────────────────────────────────────────────
    if (poorSleep) {
      return '$title day. Sleep logged at ${sleepStr}h. '
          'Keep intensity managed — form over load on all sets today.';
    }
    return '$title day. Keep intensity managed — '
        'form over load on all sets today.';
  }

  /// Single dominant intelligence insight — drives _CoachInsightCard on home screen.
  /// Consolidates recovery, momentum, phase, and narrative into one surface.
  UnifiedCoachInsight get coachInsight => CoachInsightOrchestrator.compute(
        ctx:      _buildNarrativeContext(),
        momentum: momentumState,
        recovery: recoveryState,
      );

  CoachContext buildCoachContext() {
    final recovery = muscleRecoveryList;
    final recoveryMap = <String, int>{};
    for (final r in recovery) {
      recoveryMap[r.muscle.toLowerCase()] = r.recoveryScore;
    }

    final lastTrained = workout.lastMuscleTrained;
    final lastDaysMap = <String, int>{};
    final now = DateTime.now();
    for (final entry in lastTrained.entries) {
      lastDaysMap[entry.key] = now.difference(entry.value).inDays;
    }

    return CoachContext(
      totalWorkouts:         workout.streak.totalWorkouts,
      currentStreak:         workout.streak.currentStreak,
      daysSinceLastWorkout:  workout.daysSinceLastWorkout,
      weeklyVolume:          workout.weeklyVolumeTotalKg,
      previousWeeklyVolume:  workout.previousWeeklyVolumeTotalKg,
      recentPRs:             workout.recentPRs,
      muscleRecovery:        recoveryMap,
      muscleLastDays:        lastDaysMap,
      skippedMuscles:        workout.skippedMuscleGroups,
      isDeloadWeek:          workout.needsDeload,
      isPlannedRestDay:      workout.todayPlan.isRestDay,
      goal:                  user.goal,
      level:                 user.level,
      age:                   user.age,
    );
  }

  CoachContext get coachContext {
    final now = DateTime.now();
    if (_coachContextCache != null &&
        _coachContextCacheTime != null &&
        now.difference(_coachContextCacheTime!).inSeconds < 300) {
      return _coachContextCache!;
    }
    _coachContextCache     = buildCoachContext();
    _coachContextCacheTime = now;
    return _coachContextCache!;
  }

  CoachVisualState get coachVisualState =>
      CoachVisualStateX.fromContext(coachContext);

  // ── Identity + Momentum (Phase 5) ─────────────────────────

  AthleteIdentityStage get identityStage => AthleteIdentityStageX.from(
    totalWorkouts:   workout.streak.totalWorkouts,
    consistencyScore: athleteMemory.consistencyScore,
  );

  MomentumState get momentumState => MomentumState.compute(
    ctx:    coachContext,
    memory: athleteMemory,
  );

  CoachMission get dailyMission => MissionService.build(
    ctx:      coachContext,
    memory:   athleteMemory,
    momentum: momentumState,
    identity: identityStage,
  );

  WeeklyNarrative get weeklyNarrative => WeeklyNarrativeService.generate(
    history:             workout.history,
    plannedDaysPerWeek:  workout.weekPlan.where((d) => !d.isRestDay).length,
  );

  // ── Athlete memory ─────────────────────────────────────────

  AthleteMemory get athleteMemory =>
      _athleteMemory ?? AthleteMemory(updatedAt: DateTime(2000));

  CoachTone get _coachTone => CoachToneLabel.select(
    level:                 user.level,
    age:                   user.age,
    consistencyScore:      athleteMemory.consistencyScore,
    totalWorkouts:         workout.streak.totalWorkouts,
    motivationalTriggers:  athleteMemory.motivationalTriggers,
  );

  Future<void> loadAthleteMemory() async {
    try {
      final mem = await StorageService.instance.loadObject<AthleteMemory>(
        StorageKeys.athleteMemory,
        AthleteMemory.fromJson,
      );
      if (mem != null) {
        _athleteMemory = mem;
        debugPrint('[Momentum] restored from persistence: '
            'consistency=${mem.consistencyScore} '
            'missed=${mem.missedWorkoutsLast30} '
            'bestScore=${mem.bestMomentumScore}');
      }
    } catch (e) {
      // Non-critical — will be rebuilt on next workout complete
    }
  }

  Future<void> _rebuildAndSaveAthleteMemory() async {
    try {
      _athleteMemory = AthleteProfileService.buildMemory(
        logs:                 workout.logs,
        history:              workout.history,
        streak:               workout.streak,
        weekPlan:             workout.weekPlan,
        weeklyVolume:         workout.weeklyVolumeTotalKg,
        previousWeeklyVolume: workout.previousWeeklyVolumeTotalKg,
        recentPRExercises:    workout.recentPRs.map((p) => p.exercise).toList(),
        previous:             _athleteMemory,
      );
      // Preserve peak momentum score across rebuilds
      final currentMomentum = MomentumState.compute(
        ctx: coachContext, memory: _athleteMemory!,
      );
      final peakScore = currentMomentum.score > (_athleteMemory!.bestMomentumScore)
          ? currentMomentum.score
          : _athleteMemory!.bestMomentumScore;
      if (peakScore != _athleteMemory!.bestMomentumScore) {
        _athleteMemory = _athleteMemory!.copyWith(bestMomentumScore: peakScore);
      }
      await StorageService.instance.setJson(
        StorageKeys.athleteMemory,
        _athleteMemory!.toJson(),
      );
    } catch (e) {
      // Non-critical
    }
  }

  /// Records that a coach topic was shown and saves the updated cooldown.
  Future<void> recordCoachTopic(String topic) async {
    if (topic.isEmpty) return;
    try {
      _athleteMemory = (_athleteMemory ?? AthleteMemory(updatedAt: DateTime.now()))
          .withTopicUsed(topic);
      await StorageService.instance.setJson(
        StorageKeys.athleteMemory,
        _athleteMemory!.toJson(),
      );
    } catch (_) {}
  }

  /// Generates an AI workout plan via the secure backend.
  /// Returns the parsed JSON map (caller can apply via applyAIWorkout).
  Future<Map<String, dynamic>> getAIWorkoutPlan({bool bodyweightOnly = false}) async {
    // Compute adaptive profile only when user has selected AI Adaptive.
    final WorkoutReadinessProfile? adaptiveProfile =
        settings.splitStyle == SplitStyle.aiAdaptive
            ? AdaptiveScheduleEngine.compute(
                recoveryState: recoveryState,
                selectedDays:  settings.gymDaysPerWeek,
                level:         user.level,
                goal:          user.goal,
                totalWorkouts: workout.streak.totalWorkouts,
              )
            : null;

    final request = AIWorkoutRequest(
      goal:                user.goal,
      level:               user.level,
      daysPerWeek:         settings.gymDaysPerWeek,
      bodyweightOnly:      bodyweightOnly,
      splitStyle:          settings.splitStyle,
      muscleRecoveryScores: muscleRecoveryList
          .map((r) => (muscle: r.muscle, score: r.recoveryScore))
          .toList(),
      readinessScore:      settings.todayReadiness,
      adaptiveReadiness:   adaptiveProfile,
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
      travelMode:          settings.travelMode,
    );

    if (!canUseAI()) {
      // UI should have checked this and shown paywall, but be safe
      return {};
    }

    final plan = await ai.generateWorkoutPlan(request);
    await MonetizationService.instance.recordAIUse();
    AnalyticsService.instance.planGenerated('ai_full');
    return plan;
  }

  /// Generates a quick AI suggestion (text format) shown on dashboard.
  Future<void> generateAIWorkout() async {
    if (!canUseAI()) {
      debugPrint('[Paywall] AI limit hit — showing paywall');
      _pendingPaywallTrigger = PaywallTrigger.aiLimitHit;
      notifyListeners();
      return;
    }
    debugPrint('[AI] generateAIWorkout start');
    final WorkoutReadinessProfile? adaptiveProfile =
        settings.splitStyle == SplitStyle.aiAdaptive
            ? AdaptiveScheduleEngine.compute(
                recoveryState: recoveryState,
                selectedDays:  settings.gymDaysPerWeek,
                level:         user.level,
                goal:          user.goal,
                totalWorkouts: workout.streak.totalWorkouts,
              )
            : null;

    final request = AIWorkoutRequest(
      goal:                user.goal,
      level:               user.level,
      daysPerWeek:         settings.gymDaysPerWeek,
      splitStyle:          settings.splitStyle,
      muscleRecoveryScores: muscleRecoveryList
          .map((r) => (muscle: r.muscle, score: r.recoveryScore))
          .toList(),
      readinessScore:     settings.todayReadiness,
      adaptiveReadiness:  adaptiveProfile,
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
      travelMode:         settings.travelMode,
    );

    await ai.generateQuickSuggestion(request);
    await MonetizationService.instance.recordAIUse();
    debugPrint('[AI] generateAIWorkout done');
  }

  /// Apply an AI-generated plan to the week.
  Future<void> applyAIWorkout(Map<String, dynamic> plan) async {
    await workout.applyAIWorkoutMap(plan);
    await _recomputeAll();
  }

  /// Generate a smart plan from local AIEngine.
  /// Respects gymDaysPerWeek, splitStyle, user body weight, and activity level.
  void generateSmartPlan() {
    // If the user has picked an explicit split (not AI adaptive), honour it.
    final splitOverride = settings.splitStyle == SplitStyle.aiAdaptive
        ? ''
        : AIEngine.splitStyleToKey(settings.splitStyle, settings.gymDaysPerWeek);

    workout.generateSmartPlan(
      goal:          user.goal,
      level:         user.level,
      gymDays:       settings.gymDaysPerWeek,
      weightKg:      user.weightKg > 0 ? user.weightKg : 75.0,
      activityLevel: user.activityLevel,
      gender:        user.gender,
      splitOverride: splitOverride,
    );
    _recomputeAll();
  }

  void generateWorkoutForDay(String type, int dayIndex) {
    workout.generateWorkoutForDay(
      type:          type,
      dayIndex:      dayIndex,
      goal:          user.goal,
      level:         user.level,
      weightKg:      user.weightKg > 0 ? user.weightKg : 75.0,
      activityLevel: user.activityLevel,
      gender:        user.gender,
    );
    _recomputeAll();
  }

  Future<void> applySingleDayAIWorkout({
    required int dayIndex,
    required Map<String, dynamic> workoutPlan,
  }) async {
    await workout.applySingleDayWorkout(
      dayIndex: dayIndex,
      workout: workoutPlan,
    );

    await _recomputeAll();
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
  bool get isPremium         => MonetizationService.instance.isPremium;
  bool canUseAI()            => MonetizationService.instance.canUseAI;
  int  get aiUsesRemaining   => MonetizationService.instance.aiUsesRemaining;
  bool canUseChat()          => MonetizationService.instance.canUseChat;
  int  get chatUsesRemaining => MonetizationService.instance.chatUsesRemaining;

  bool canViewAdvancedStats()   => isPremium;
  bool canUseSmartCoach()       => isPremium;
  bool canUseAdvancedInsights() => isPremium;

  Future<void> upgradeToPremium() async {
    await MonetizationService.instance.upgradeToPremium();
    ai.invalidateInsightCache();
    AnalyticsService.instance.premiumPurchased();
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

  // ── Full data reset — wipes all workout data, resets to new-user state ──
  Future<void> resetAllData() async {
    final storage = StorageService.instance;
    final prefs   = await storage.prefs();

    // Clear all workout + history + memory keys
    final keys = [
      StorageKeys.weekPlan,
      StorageKeys.streak,
      StorageKeys.history,
      StorageKeys.logs,
      StorageKeys.measurements,
      StorageKeys.mood,
      StorageKeys.aiCache,
      StorageKeys.lastMuscleTrained,
      StorageKeys.performanceMemory,
      StorageKeys.weeklyMemory,
      StorageKeys.analyticsCache,
      StorageKeys.athleteMemory,
      StorageKeys.dailyMission,
      StorageKeys.weeklyNarrative,
      StorageKeys.onboardingDone,
      StorageKeys.profile,
      StorageKeys.settings,
      StorageKeys.customExercises,
      StorageKeys.favorites,
    ];
    for (final k in keys) {
      await prefs.remove(k);
    }

    // Clear Hive boxes
    try {
      await storage.writeWorkoutBox(StorageKeys.hiveWeekPlan, null);
    } catch (_) {}

    notifyListeners();
  }

  // Settings — broad map (avoid in Selectors; use typed getters below)
  Map<String, dynamic> get settingsMap => settings.all;

  // Typed single-value getters — safe to use directly in Selector selectors
  bool       get workoutReminderEnabled  => settings.workoutReminderEnabled;
  bool       get notificationsEnabled    => settings.notificationsEnabled;
  bool       get travelMode              => settings.travelMode;
  bool       get inactivityAlertEnabled  => settings.inactivityAlertEnabled;
  int        get gymDaysPerWeek          => settings.gymDaysPerWeek;
  SplitStyle get splitStyle              => settings.splitStyle;
  int        get todayReadiness          => settings.todayReadiness;

  Future<void> updateSetting(String key, dynamic value) =>
      settings.update(key, value);

  // ── Injury risk — deterministic, no AI needed ──────
  List<RecoveryWarning> get injuryRisks => InjuryRiskDetector.detect(
    logs:               workout.logs.toList(),
    recentEffortScores: ai.performanceMemory.map((p) => p.effortScore).toList(),
  );

  // Workout state
  List<DayPlan>      get weekPlan       => workout.weekPlan;
  bool               get hasActivePlan  => workout.weekPlan.isNotEmpty;
  int                get totalWorkouts  => workout.streak.totalWorkouts;
  List<WorkoutLog>   get logs           => workout.logs;
  StreakData         get streak         => workout.streak;
  List<String>       get earnedBadges   => workout.streak.earnedBadges;
  List<HistoryEntry> get history        => workout.history;
  WeeklyMemory?      get lastWeekMemory => workout.lastWeekMemory;

  int    get todayIndex          => workout.todayIndex;
  int    get weeklyCompletedDays => workout.weeklyCompletedDays;
  double get weeklyScore         => workout.weeklyScore;
  double get weeklyVolumeTotalKg => workout.weeklyVolumeTotalKg;
  List<PREvent> get recentPRs    => workout.recentPRs;

  double get lifetimeVolumeKg =>
      workout.logs.fold(0.0, (s, l) => s + l.volume);

  Map<String, double> get weeklyVolumeByMuscle => workout.weeklyVolumeByMuscle;
  bool   get isBeginnerPhase     => workout.isBeginnerPhase;
  int    get daysSinceLastWorkout  => workout.daysSinceLastWorkout;
  String get lastWorkoutDateStr    => workout.streak.lastWorkoutDate;
  bool   get isInactive           => workout.isInactive;
  DayPlan  get todayPlan          => workout.todayPlan;
  DayPlan? get yesterdayMissedPlan => workout.yesterdayMissedPlan;
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

  /// One-line post-generation insight: "Built around Chest + Back — letting Legs recover"
  String get workoutGenerationContextLine {
    final list = muscleRecoveryList;
    if (list.isEmpty) return '';
    final suppressed = list.where((m) => m.recoveryScore < 60).toList();
    final prime = list.where((m) => m.recoveryScore >= 80).toList();
    if (suppressed.isEmpty && prime.isEmpty) return '';
    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
    final primeNames = prime.take(2).map((m) => cap(m.muscle)).join(' + ');
    final suppressedNames = suppressed.take(2).map((m) => cap(m.muscle)).join(', ');
    if (primeNames.isNotEmpty && suppressedNames.isNotEmpty) {
      return 'Built around $primeNames — letting $suppressedNames recover';
    } else if (primeNames.isNotEmpty) {
      return 'Built around your freshest muscles: $primeNames';
    } else {
      return 'Low recovery detected — plan kept moderate';
    }
  }

  double getMuscleRecovery(String muscle) =>
      workout.getMuscleRecoveryWithMood(muscle, user.todayMood);
  int    getOverallRecovery() =>
      recoveryState.overallScore.round(); // shim → RecoveryEngine

  // Planner ops
  void updateDayTitle(int i, String t) => workout.updateDayTitle(i, t);
  void clearDay(int i) => workout.clearDay(i);
  Future<void> appendMissedToToday(int missedDayIdx) =>
      workout.appendMissedToToday(missedDayIdx);
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

  // Trend / periodization
  String getExerciseTrend(String baseId) => workout.getExerciseTrend(baseId);
  Map<String, String> get todayExerciseTrends => workout.todayExerciseTrends;
  int  get mesocycleWeek => workout.mesocycleWeek;
  bool get isDeloadWeek  => workout.isDeloadWeek;
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
  SetProgressionHint smartProgression(PlannedExercise ex) =>
      workout.smartProgression(ex);
  String getTrainerMessage(PlannedExercise ex) => workout.getTrainerMessage(ex);
  String getSmartFeedback(PlannedExercise ex) => workout.getSmartFeedback(ex);
  pre.WorkoutFeedback? computeFeedback(PlannedExercise ex) =>
      workout.computeFeedback(ex);
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
  bool   get shouldSuggestPlanRefresh =>
      isPremium && (isOnPlateau || needsDeloadByVolume);
  bool   get showNewWeekBanner  => workout.newWeekDetected;
  bool   get showComebackBanner =>
      workout.daysSinceLastWorkout >= 4 && workout.streak.totalWorkouts > 0;
  void   dismissNewWeekBanner()   => workout.clearNewWeekBanner();
  double get recoveryScore         => recoveryState.overallScore; // shim → RecoveryEngine
  String get weeklyMessage         => analytics.weeklyMessage;
  String get muscleImbalance       => analytics.muscleImbalanceMessage(workout.logs);

  // AI insight — read-through
  AICoachInsight get aiInsight => ai.insight;
  FatigueLevel   get currentFatigueLevel => ai.insight.fatigueLevel;
  String get fatigueMessage => isPremium
      ? ai.insight.fatigueMessage
      : (ai.insight.fatigueLevel == FatigueLevel.fatigued
          ? 'High fatigue detected — consider an extra rest day.'
          : 'Recovery looks good. Ready to train today.');
  String get weightSuggestionMessage => isPremium
      ? ai.insight.weightMessage
      : 'Focus on progressive overload — small weekly increases add up.';
  String get weakMuscleInsight {
    if (!isPremium) return 'Complete more sessions to reveal muscle patterns.';
    final w = ai.insight.weakMuscleGroup;
    return w.isEmpty ? 'Balanced training detected.' : 'Focus area: $w';
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
      : 'Train consistently — your body adapts best with regular sessions.';
  String get aiSuggestion {
    // ── PRIORITY 0: Travel mode active ──
    if (settings.travelMode) {
      return 'Travel mode on — tap to generate a bodyweight plan.';
    }

    // ── PRIORITY 0.5: Reactive coach — data-driven, instant, offline-first ──
    // Memory-personalised and tone-calibrated. Topic cooldown prevents repetition.
    // Returns '' when no strong signal → Gemini handles the brief.
    if (isPremium) {
      final cooldown = _athleteMemory?.cooldownTopics() ?? {};
      final surface  = workout.todayPlan.isCompleted
          ? CoachSurfaceContext.postWorkout
          : CoachSurfaceContext.preWorkout;
      final result   = CoachMessageService.buildWithTopic(
        coachContext,
        memory:        _athleteMemory,
        tone:          _coachTone,
        cooldown:      cooldown,
        surfaceContext: surface,
      );
      if (result.message.isNotEmpty) {
        // Record topic asynchronously — does not block the getter
        recordCoachTopic(result.topic).ignore();
        return result.message;
      }
    }

    // ── PRIORITY 0.7: Gemini daily brief — fallback when no reactive signal ──
    if (isPremium && ai.dailyBrief.isNotEmpty) return ai.dailyBrief;

    // ── PRIORITY 0.5: Stale weekly plan (7+ days old) ──
    try {
      final mem = workout.lastWeekMemory;
      if (mem != null) {
        final parts = mem.weekStartDate.split('-');
        if (parts.length == 3) {
          final start = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final daysOld = DateTime.now().difference(start).inDays;
          if (daysOld >= 7) {
            return 'New week started — tap AI to generate a fresh plan.';
          }
        }
      }
    } catch (_) {}

    final w = workout;
    final s = w.streak;
    final a = analytics;
    final daysSince = w.daysSinceLastWorkout;
    final total = s.totalWorkouts;
    final cur = s.currentStreak;

    // ── FREE USERS: basic coaching only ──
    if (!isPremium) {
      if (total == 0) {
        return 'Start your first workout today.';
      }

      if (daysSince >= 3) {
        return 'Training rhythm matters more than single sessions. Each one compounds.';
      }

      if (cur >= 3) {
        return '${cur}-day training streak. Rhythm maintained.';
      }

      return 'Stay consistent — your body adapts best with regular training.';
    }

    // ═══════════════════════════════════════════════
    // SCIENTIFIC PREMIUM COACH — based on:
    // ACWR (Gabbett 2016), Schoenfeld 2010, Zourdos 2016
    // ═══════════════════════════════════════════════

    // ── PRIORITY 0.8: Emotional retention — dropout risk ──
    if (isAtRiskOfDropout && retentionMessage.isNotEmpty) {
      return retentionMessage;
    }

    // ── PRIORITY 0.9: Cross-screen continuity — reference limiting muscle ──
    // Gate: only fires pre-workout. Post-workout, "avoid X" is factually wrong.
    final limiting = recoveryState.primaryLimitingMuscle;
    if (limiting.isNotEmpty &&
        (recoveryState.muscleScores[limiting] ?? 100) < 40 &&
        total >= 5 &&
        !w.todayPlan.isCompleted) {
      final mn = _capitalizeMuscle(limiting);
      return '$mn recovery demand is still elevated. Managing load today keeps adaptation on track.';
    }

    // ── PRIORITY 1: Overtraining ──
    if (a.overTrainingRisk > 75 && total >= 10) {
      return 'Training load has been building up. A lighter session today helps your body recover and grow stronger.';
    }

    // ── PRIORITY 2: Deload ──
    if (w.needsDeload) {
      return 'You\'ve been training hard consistently. A lighter week now will help you come back stronger next week.';
    }

    // ── PRIORITY 3: Plateau detection ──
    if (a.isOnPlateau && a.plateauScore > 70) {
      return 'Progress has stabilized over the last few weeks. Switching up exercises or intensity can restart improvement.';
    }

    // ── PRIORITY 4: Severe inactivity ──
    if (daysSince >= 7 && total > 0) {
      return '${daysSince} days since your last session. Starting light today is the right call — rhythm before intensity.';
    }
    if (daysSince >= 4 && total > 0) {
      return '${daysSince} days since your last session. Keep it controlled today to get back into your groove.';
    }

    // ── PRIORITY 5: Skipped muscle (training balance) ──
    final skipped = w.skippedMuscleGroups;
    if (skipped.isNotEmpty && total >= 5) {
      return '${_capitalizeMuscle(skipped.first)} hasn\'t been trained recently. Adding it back keeps your training balanced.';
    }

    // ── PRIORITY 5.5: Today's workout aware ──
    final todayPlan = w.todayPlan;
    if (
      !todayPlan.isRestDay &&
      !todayPlan.isCompleted &&
      todayPlan.exercises.isNotEmpty &&
      total >= 2
    ) {
      final compounds = ['bench', 'squat', 'deadlift', 'press', 'row', 'pull'];
      for (final ex in todayPlan.exercises) {
        final nameL = ex.name.toLowerCase();
        if (compounds.any((k) => nameL.contains(k))) {
          final logs = w.logs.where((l) => l.exercise == ex.baseId).toList();
          final lastWeight = logs.isNotEmpty ? logs.last.weight : 0.0;
          if (lastWeight > 0) {
            final next = (lastWeight * 1.025).toStringAsFixed(1);
            return 'Last ${ex.name}: ${lastWeight}kg — try ${next}kg today.';
          }
        }
      }
      return '${todayPlan.title} is scheduled — ready when you are.';
    }

    // ── PRIORITY 6: Beginner phase ──
    if (total == 0) {
      if (!todayPlan.isRestDay && todayPlan.exercises.isNotEmpty) {
        return 'Today: ${todayPlan.title} — log your first set to begin.';
      }
      return 'Tap Planner to set up your first workout.';
    }
    if (total <= 3) {
      return 'The first few sessions build the foundation. Consistency now matters more than intensity.';
    }

    // ── PRIORITY 7: Streak milestones ──
    if (cur == 7)   return 'Seven sessions in. You\'re building a real rhythm now.';
    if (cur == 14)  return 'Fourteen sessions. Consistency at this level is already meaningful.';
    if (cur == 21)  return 'Twenty-one sessions. Your body is adapting to a regular training pattern.';
    if (cur == 30)  return 'Thirty sessions. Training has become a habit — that\'s the real win.';
    if (cur == 60)  return 'Sixty sessions. This level of consistency is genuinely rare.';
    if (cur == 100) return 'One hundred sessions. Remarkable consistency.';

    // ── PRIORITY 8: Fatigue management ──
    if (w.isFatigued && a.fatigueIndex > 70) {
      return 'Your body is under heavier stress right now. Controlled, technical training today serves you better than pushing.';
    }
    if (w.isFatigued) {
      return 'Recovery demand is higher than usual. Keeping things controlled today maintains momentum safely.';
    }

    // ── PRIORITY 9: Streak continuity ──
    if (cur >= 3 && daysSince == 1) {
      return 'You\'re on a roll. Even a short session today keeps the momentum going.';
    }

    // ── PRIORITY 10: Peak readiness ──
    if (a.readinessScore > 85) {
      return 'Recovery is looking strong today — good conditions to push a bit further than usual.';
    }

    // ── PRIORITY 11: Recovery improving ──
    if (a.recoveryTrend == 'improving') {
      return 'Recovery is trending in the right direction. Good moment to progressively increase your load.';
    }

    // ── PRIORITY 12: Plan ready (only if no critical signals) ──
    if (ai.lastAISuggestion.isNotEmpty) return ai.lastAISuggestion;

    // ── PRIORITY 13: Volume-based default ──
    final weeklyImp = a.weeklyImprovementPct;
    if (weeklyImp > 10) {
      return 'Volume is up ${weeklyImp.toStringAsFixed(0)}% from last week. Momentum is building.';
    }
    if (weeklyImp < -15) {
      return 'Volume is down ${weeklyImp.abs().toStringAsFixed(0)}% from last week — recovery conditions may be affecting output.';
    }

    // ── PRIORITY 14: Default coach message ──
    return ai.insight.dailyCoachMessage;
  }

  // ── Unified Intelligence — orchestrated, phase-aware home screen message ──────
  // Phase 25: NarrativeOrchestrator gates ALL messaging by workout lifecycle state.
  // Post-workout → recovery framing always. Pre-workout → protective coaching.
  // Cards never contradict each other.

  String get unifiedInsight {
    final narrative = _narrativeMessage;

    // ── POST-WORKOUT: orchestrator owns the narrative entirely ──────────────
    // Never say "avoid X" or "train another muscle group" — the session is done.
    if (narrative.phase == NarrativePhase.postWorkout) {
      return narrative.isEmpty ? _fallbackUnifiedInsight() : narrative.body;
    }

    // ── REST-DAY: calm recovery framing ─────────────────────────────────────
    if (narrative.phase == NarrativePhase.restDay) {
      return narrative.body;
    }

    // ── COMEBACK: supportive restart, dropout retention takes priority ───────
    if (narrative.phase == NarrativePhase.comeback) {
      if (isAtRiskOfDropout && retentionMessage.isNotEmpty) return retentionMessage;
      return narrative.isEmpty ? _fallbackUnifiedInsight() : narrative.body;
    }

    // ── PRE-WORKOUT / NEXT-DAY: orchestrator provides top-priority signal ────
    // Dropout risk always fires first.
    if (isAtRiskOfDropout && retentionMessage.isNotEmpty) return retentionMessage;

    // Orchestrator returns a phase-appropriate message when signal is strong.
    // Empty → falls through to existing priority cascade below.
    if (!narrative.isEmpty) return narrative.body;

    return _fallbackUnifiedInsight();
  }

  // Existing priority cascade — fires only when orchestrator returns empty.
  // These are all valid for pre-workout / next-day scenarios.
  String _fallbackUnifiedInsight() {
    final rs = recoveryState;

    // Deload needed
    if (rs.needsDeload) {
      return 'Your body has been working hard. A lighter week now will help you come back stronger next week.';
    }

    // High fatigue
    if (rs.highFatigue) {
      return 'Fatigue is building across your main muscle groups. Controlled, quality movement today is better than heavy load.';
    }

    // Burnout signal from adherence
    if (adherenceBurnoutLevel >= 2 && adherenceInsight.isNotEmpty) return adherenceInsight;

    // Recovery collapse risk
    if (predictiveCollapseLevel >= 2 && predictiveInsight.isNotEmpty) return predictiveInsight;

    // Weekly training phase narrative
    if (weeklyEvolutionNarrative.isNotEmpty) return weeklyEvolutionNarrative;

    // Onboarding guidance — early athletes
    if (!onboardingComplete && onboardingNarrative.isNotEmpty) return onboardingNarrative;

    // Trend direction (building or declining)
    if (trendInsight.isNotEmpty) return trendInsight;

    // Progression window or general outlook
    if (predictiveInsight.isNotEmpty) return predictiveInsight;

    // Athlete identity observation
    if (athleteIdentitySummary.isNotEmpty) return athleteIdentitySummary;

    // AI suggestion — general fallback
    return aiSuggestion;
  }

  /// Small-caps category label displayed above the unified insight text.
  String get unifiedInsightLabel {
    final narrative = _narrativeMessage;

    // Phase-controlled labels from orchestrator
    switch (narrative.phase) {
      case NarrativePhase.postWorkout:
        return narrative.label.isNotEmpty ? narrative.label : 'Recovery Window';
      case NarrativePhase.restDay:
        return narrative.label.isNotEmpty ? narrative.label : 'Rest Day';
      case NarrativePhase.comeback:
        if (isAtRiskOfDropout) return 'Comeback';
        return narrative.label.isNotEmpty ? narrative.label : 'Comeback';
      default:
        break;
    }

    // Pre-workout / next-day: use orchestrator label when it has a signal
    if (isAtRiskOfDropout) return 'Comeback';
    if (!narrative.isEmpty && narrative.label.isNotEmpty) return narrative.label;

    // Existing label logic for fallback cascade
    final rs = recoveryState;
    if (rs.needsDeload) return 'Recovery Focus';
    if (rs.highFatigue) return 'Recovery Focus';
    if (adherenceBurnoutLevel >= 2) return 'Well-being';
    if (predictiveCollapseLevel >= 2) return 'Heads Up';
    if (weeklyEvolutionNarrative.isNotEmpty) {
      const phaseLabels = <String, String>{
        'Accumulation':    'Building Phase',
        'Overload':        'Push Week',
        'Stabilization':   'Stable Phase',
        'Recovery':        'Recovery Focus',
        'Deload':          'Recovery Focus',
        'Rebound':         'Momentum Building',
        'Intensification': 'Push Week',
      };
      return phaseLabels[weeklyPhaseLabel] ?? 'This Week';
    }
    if (!onboardingComplete) {
      return workout.streak.totalWorkouts > 0 ? 'Coach Insight' : 'Getting Started';
    }
    if (trendInsight.isNotEmpty) {
      return trendMomentumIndex >= 2 ? 'Momentum' : 'Consistency';
    }
    if (predictiveInsight.isNotEmpty) {
      return nextPRWindow.isNotEmpty ? 'Progression' : 'Outlook';
    }
    return 'Today';
  }

  String _capitalizeMuscle(String m) {
    if (m.isEmpty) return m;
    return m[0].toUpperCase() + m.substring(1);
  }

  /// Full AI-generated plan text (long, structured). Use this for the
  /// "View Full Plan" screen / bottom sheet — NOT for compact cards.
  String get lastAIPlan => ai.lastAIPlan;

  /// True when an AI plan has been generated and is available to view.
  bool get hasAIPlan => ai.hasAIPlan;
  String get smartCoach => isPremium
      ? ai.insight.dailyCoachMessage
      : 'Every session builds your foundation. Keep showing up.';
  String get progressionTip {
    final base = ai.insight.weightMessage;

    if (!isPremium) return base;

    try {
      final today = workout.todayPlan;

      if (today.exercises.isNotEmpty) {
        final ex = today.exercises.first;

        final prediction =
            workout.predictNextPR(ex.baseId, ex.unit);

        if (prediction != null) {
          return '$base\n\n$prediction';
        }
      }
    } catch (_) {}

    return base;
  }

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
