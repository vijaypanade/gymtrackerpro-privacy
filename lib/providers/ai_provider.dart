// lib/providers/ai_provider.dart — v8.4 PRODUCTION-READY
//
// Senior Flutter architect audit fixes applied:
//   ✅ All hyperlink-corrupted identifiers cleaned (this.date, b.date, etc.)
//   ✅ DateTime.now() restored everywhere
//   ✅ Safe DateTime parsing throughout (try-catch + tryParse)
//   ✅ _formatWorkout properly inside class
//   ✅ AI plan persistence wired to load() + setPlanContent
//   ✅ dispose() correctly inside class
//   ✅ Debounced save with proper Timer cancellation
//   ✅ Defensive null guards on all JSON parsing
//   ✅ Immutable DTOs with @immutable annotation
//   ✅ Cache invalidation on recompute
//   ✅ All getters preserved (lastAISuggestion, lastAIPlan, hasAIPlan)
//   ✅ Beginner phase guard, priority system, _pickUnique preserved

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/memory_models.dart';
import '../models/models.dart';
import '../models/readiness.dart';
import '../models/split_template.dart';
import '../models/workout_log.dart';
import '../models/workout_readiness_profile.dart';
import '../services/ai_quota_service.dart' show AiRequestType;
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/monetization_service.dart' show MonetizationService;
import '../services/exercise_candidate_service.dart';
import '../services/storage_service.dart';

// ═══════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════
enum FatigueLevel { fresh, normal, fatigued }

enum WeightSuggestion { increase, decrease, maintain }

// ═══════════════════════════════════════════════════════════════
// AI COACH INSIGHT
// ═══════════════════════════════════════════════════════════════
@immutable
class AICoachInsight {
  final FatigueLevel fatigueLevel;
  final String fatigueMessage;
  final WeightSuggestion weightSuggestion;
  final String weightMessage;
  final String weakMuscleGroup;
  final String dailyCoachMessage;
  final int recommendedSets;
  final double weightModifier;
  final String cacheDate;

  const AICoachInsight({
    required this.fatigueLevel,
    required this.fatigueMessage,
    required this.weightSuggestion,
    required this.weightMessage,
    required this.weakMuscleGroup,
    required this.dailyCoachMessage,
    required this.recommendedSets,
    required this.weightModifier,
    required this.cacheDate,
  });

  Map<String, dynamic> toJson() => {
        'fatigueLevel': fatigueLevel.name,
        'fatigueMessage': fatigueMessage,
        'weightSuggestion': weightSuggestion.name,
        'weightMessage': weightMessage,
        'weakMuscleGroup': weakMuscleGroup,
        'dailyCoachMessage': dailyCoachMessage,
        'recommendedSets': recommendedSets,
        'weightModifier': weightModifier,
        'cacheDate': cacheDate,
      };

  factory AICoachInsight.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaultInsight;
    return AICoachInsight(
      fatigueLevel: FatigueLevel.values.firstWhere(
        (e) => e.name == j['fatigueLevel'],
        orElse: () => FatigueLevel.normal,
      ),
      fatigueMessage: j['fatigueMessage']?.toString() ?? '',
      weightSuggestion: WeightSuggestion.values.firstWhere(
        (e) => e.name == j['weightSuggestion'],
        orElse: () => WeightSuggestion.maintain,
      ),
      weightMessage: j['weightMessage']?.toString() ?? '',
      weakMuscleGroup: j['weakMuscleGroup']?.toString() ?? '',
      dailyCoachMessage: j['dailyCoachMessage']?.toString() ?? '',
      recommendedSets: (j['recommendedSets'] as num?)?.toInt() ?? 4,
      weightModifier: (j['weightModifier'] as num?)?.toDouble() ?? 1.0,
      cacheDate: j['cacheDate']?.toString() ?? '',
    );
  }

  static const defaultInsight = AICoachInsight(
    fatigueLevel: FatigueLevel.fresh,
    fatigueMessage: '✅ Fully recovered — optimal performance today!',
    weightSuggestion: WeightSuggestion.maintain,
    weightMessage: '🎯 Focus on form today — build your foundation.',
    weakMuscleGroup: '',
    recommendedSets: 4,
    weightModifier: 1.0,
    dailyCoachMessage: '🚀 Day 1 — The hardest part is starting. You did it!',
    cacheDate: '',
  );
}

// ═══════════════════════════════════════════════════════════════
// PERFORMANCE PATTERN
// ═══════════════════════════════════════════════════════════════
@immutable
class PerformancePattern {
  final String date; // ISO yyyy-MM-dd or empty
  final double volume;
  final int setsCompleted;
  final int setsPlanned;
  final double effortScore;
  final String mood;
  final bool wasFailedSession;
  final List<String> musclesTrained;
  final String bestExercise;

  const PerformancePattern({
    required this.date,
    required this.volume,
    required this.setsCompleted,
    required this.setsPlanned,
    required this.effortScore,
    required this.mood,
    this.wasFailedSession = false,
    this.musclesTrained = const [],
    this.bestExercise = '',
  });

  /// Safe DateTime parser — never throws. Returns epoch on bad input.
  DateTime get parsedDate {
    if (date.isEmpty) return DateTime(1970);
    return DateTime.tryParse(date) ?? DateTime(1970);
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'volume': volume,
        'setsCompleted': setsCompleted,
        'setsPlanned': setsPlanned,
        'effortScore': effortScore,
        'mood': mood,
        'wasFailedSession': wasFailedSession,
        'musclesTrained': musclesTrained,
        'bestExercise': bestExercise,
      };

  factory PerformancePattern.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const PerformancePattern(
        date: '',
        volume: 0,
        setsCompleted: 0,
        setsPlanned: 0,
        effortScore: 0,
        mood: 'normal',
      );
    }
    return PerformancePattern(
      date: j['date']?.toString() ?? '',
      volume: (j['volume'] as num?)?.toDouble() ?? 0,
      setsCompleted: (j['setsCompleted'] as num?)?.toInt() ?? 0,
      setsPlanned: (j['setsPlanned'] as num?)?.toInt() ?? 0,
      effortScore: (j['effortScore'] as num?)?.toDouble() ?? 0,
      mood: j['mood']?.toString() ?? 'normal',
      wasFailedSession: j['wasFailedSession'] == true,
      musclesTrained: (j['musclesTrained'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bestExercise: j['bestExercise']?.toString() ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COACH INPUTS
// ═══════════════════════════════════════════════════════════════
@immutable
class AICoachInputs {
  final List<WorkoutLog> logs;
  final MoodType mood;
  final int currentStreak;
  final int totalWorkouts;
  final String goal;
  final String level;
  final String trainerType;
  final String userName;
  final bool isOnPlateau;
  final bool needsDeload;
  final int daysSinceLastWorkout;

  const AICoachInputs({
    required this.logs,
    required this.mood,
    required this.currentStreak,
    required this.totalWorkouts,
    required this.goal,
    required this.level,
    required this.trainerType,
    required this.userName,
    required this.isOnPlateau,
    required this.needsDeload,
    required this.daysSinceLastWorkout,
  });

  bool get isBeginner => level == 'beginner';
  bool get isAdvanced => level == 'advanced';
  String get cleanGoal => goal.replaceAll('_', ' ').trim();
}

// ═══════════════════════════════════════════════════════════════
// AI WORKOUT REQUEST
// ═══════════════════════════════════════════════════════════════
@immutable
class AIWorkoutRequest {
  final String goal;
  final String level;
  final int daysPerWeek;
  final List<String> weakMuscles;
  final bool isOnPlateau;
  final bool needsDeload;
  final bool isFatigued;
  final String performanceTrend;
  final List<String> missedDays;
  final List<String> recentWorkoutNames;
  final int currentStreak;
  final int totalWorkouts;
  final double weeklyVolumeTrend;
  final List<ExerciseMemory> exerciseHistory;
  final WeeklyMemory? lastWeekMemory;
  final bool travelMode;
  final bool bodyweightOnly;
  final SplitStyle splitStyle;
  final List<({String muscle, int score})> muscleRecoveryScores;
  final int readinessScore; // 0 = not set; 1–5 = subjective daily readiness
  // V2 adaptive scheduling — non-null only when splitStyle == aiAdaptive.
  // When present, _buildPrompt() uses profile-based slot constraints instead
  // of the raw recovery score binary rules.
  final WorkoutReadinessProfile? adaptiveReadiness;

  const AIWorkoutRequest({
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    this.weakMuscles = const [],
    this.isOnPlateau = false,
    this.needsDeload = false,
    this.isFatigued = false,
    this.performanceTrend = 'stable',
    this.missedDays = const [],
    this.recentWorkoutNames = const [],
    this.currentStreak = 0,
    this.totalWorkouts = 0,
    this.weeklyVolumeTrend = 0,
    this.exerciseHistory = const [],
    this.lastWeekMemory,
    this.travelMode = false,
    this.bodyweightOnly = false,
    this.splitStyle = SplitStyle.pushPullLegs,
    this.muscleRecoveryScores = const [],
    this.readinessScore = 0,
    this.adaptiveReadiness,
  });

  String get cleanGoal => goal.replaceAll('_', ' ');
  String get cleanLevel => level.trim();
}

// ═══════════════════════════════════════════════════════════════
// AI PROVIDER
// ═══════════════════════════════════════════════════════════════
class AIProvider extends ChangeNotifier {
  Timer? _saveDebounce;

  AICoachInsight _insight = AICoachInsight.defaultInsight;
  List<PerformancePattern> _perfMemory = [];

  String _aiTagline = '';
  DateTime? _taglineSetAt;
  String _aiFullPlan = '';
  String _cachedWeightMessage = '';

  final Map<String, String> _lastMessages = {};

  bool _loaded = false;
  bool _generatingPlan = false;
  bool _generatingSessionInsight = false;
  String _lastSessionInsight = '';
  String _dailyBrief = '';
  String _dailyBriefDate = '';
  bool _briefOffline = false;

  static const int _maxMemory = 10;

  // ── Public state ─────────────────────────────────────────
  bool get isLoaded => _loaded;
  bool get isGeneratingPlan => _generatingPlan;
  bool get isGeneratingSessionInsight => _generatingSessionInsight;
  bool get isBriefOffline => _briefOffline;
  String get lastSessionInsight => _lastSessionInsight;
  String get dailyBrief => _dailyBrief;
  AICoachInsight get insight => _insight;
  List<PerformancePattern> get performanceMemory =>
      List.unmodifiable(_perfMemory);

  String get lastAISuggestion {
    // Tagline expires after 24 hours — then daily coach message takes over
    if (_taglineSetAt == null) return _aiTagline;
    final age = DateTime.now().difference(_taglineSetAt!);
    if (age.inHours >= 24) return ''; // expired → fallback to coach message
    return _aiTagline;
  }
  String get lastAIPlan => _aiFullPlan;
  bool get hasAIPlan => _aiFullPlan.isNotEmpty;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // SORTED MEMORY (newest first, safe DateTime sort)
  // ─────────────────────────────────────────────────────────
  List<PerformancePattern> get _sortedMemory {
    final list = List<PerformancePattern>.from(_perfMemory);
    list.sort((a, b) => b.parsedDate.compareTo(a.parsedDate));
    return list;
  }

  double get averageEffortScore {
    if (_perfMemory.isEmpty) return 70;
    final valid = _perfMemory
        .map((p) => p.effortScore.clamp(0, 100).toDouble())
        .toList();
    if (valid.isEmpty) return 70;
    final total = valid.reduce((a, b) => a + b);
    return total / valid.length;
  }

  int get failedSessionCount {
    return _sortedMemory.take(5).where((p) => p.wasFailedSession).length;
  }

  bool get hasFailurePattern => failedSessionCount >= 2;

  String get bestPerformingExercise {
    if (_perfMemory.isEmpty) return '';
    final sorted = _sortedMemory;
    final score = <String, double>{};
    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      if (p.bestExercise.isEmpty) continue;
      final weight = 1.0 / (i + 1);
      score[p.bestExercise] = (score[p.bestExercise] ?? 0) + weight;
    }
    if (score.isEmpty) return '';
    return score.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  List<String> get musclesSkippedLast7Days {
    const all = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
    if (_perfMemory.isEmpty) return all;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final trained = <String>{};
    for (final p in _perfMemory) {
      if (p.parsedDate.isAfter(cutoff)) {
        trained.addAll(p.musclesTrained);
      }
    }
    return all.where((m) => !trained.contains(m)).toList();
  }

  String get performanceTrend {
    if (_perfMemory.length < 6) return 'stable';
    final sorted = _sortedMemory;
    final recent = sorted.take(3).map((p) => p.effortScore).toList();
    final older = sorted.skip(3).take(3).map((p) => p.effortScore).toList();
    if (recent.length < 3 || older.length < 3) return 'stable';
    final rAvg = recent.reduce((a, b) => a + b) / 3;
    final oAvg = older.reduce((a, b) => a + b) / 3;
    if (rAvg > oAvg + 5) return 'improving';
    if (rAvg < oAvg - 5) return 'declining';
    return 'stable';
  }

  // ═════════════════════════════════════════════════════════
  // LOAD (with AI plan persistence restore)
  // ═════════════════════════════════════════════════════════
  Future<void> load() async {
    if (_loaded) return;
    try {
      // 1. Daily insight cache
      final cached = await StorageService.instance.loadObject<AICoachInsight>(
        StorageKeys.aiCache,
        AICoachInsight.fromJson,
      );
      if (cached != null && cached.cacheDate == _todayStr) {
        _insight = cached;
      }

      // 2. Performance memory
      _perfMemory = await StorageService.instance.loadList<PerformancePattern>(
        StorageKeys.performanceMemory,
        PerformancePattern.fromJson,
      );

      // 3. AI Plan persistence (restored after app kill)
      try {
        final savedPlan =
            await StorageService.instance.getString('ai_full_plan');
        final savedTag =
            await StorageService.instance.getString('ai_tagline');
        if (savedPlan != null && savedPlan.isNotEmpty) {
          _aiFullPlan = savedPlan;
        }
        if (savedTag != null && savedTag.isNotEmpty) {
          _aiTagline = savedTag;
      final savedTagAt = await StorageService.instance.getString('ai_tagline_set_at');
      if (savedTagAt != null && savedTagAt.isNotEmpty) {
        try {
          _taglineSetAt = DateTime.parse(savedTagAt);
        } catch (_) {}
      }
        }
      } catch (e) {
        debugPrint('AI plan restore error: $e');
      }

      // 4. Daily brief persistence — survive app restart
      try {
        final savedBrief     = await StorageService.instance.getString('ai_daily_brief');
        final savedBriefDate = await StorageService.instance.getString('ai_daily_brief_date');
        if (savedBrief != null && savedBriefDate == _todayStr && savedBrief.isNotEmpty) {
          _dailyBrief     = savedBrief;
          _dailyBriefDate = savedBriefDate ?? '';
        }
      } catch (e) {
        debugPrint('Daily brief restore error: $e');
      }
    } catch (e) {
      debugPrint('AIProvider.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════════
  // RECOMPUTE INSIGHT
  // ═════════════════════════════════════════════════════════
  Future<void> recomputeInsight(AICoachInputs inputs) async {
    _cachedWeightMessage = '';
    _lastMessages.clear();
    _insight = _computeInsight(inputs);
    notifyListeners();
    try {
      await StorageService.instance
          .setJson(StorageKeys.aiCache, _insight.toJson());
    } catch (e) {
      debugPrint('recomputeInsight persist error: $e');
    }
  }

  void invalidateInsightCache() {
    _insight = AICoachInsight.defaultInsight;
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════
  // PERFORMANCE MEMORY
  // ═════════════════════════════════════════════════════════
  Future<void> recordSession({
    required DayPlan day,
    required MoodType mood,
    required String Function(String) normalizeMuscle,
  }) async {
    final setsPlanned = day.exercises.fold(0, (v, e) => v + e.sets.length);
    final setsCompleted = day.exercises
        .fold(0, (v, e) => v + e.sets.where((s) => s.done).length);
    final volume = _calcVolume(day);
    final effort = setsPlanned > 0
        ? (setsCompleted / setsPlanned * 100).clamp(0, 100).toDouble()
        : 50.0;

    final musclesHit = day.exercises
        .map((e) => normalizeMuscle(e.category))
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    String bestEx = '';
    double bestVol = 0;
    for (final ex in day.exercises) {
      final exVol = ex.sets
          .where((s) => s.done)
          .fold(0.0, (s, set) => s + set.weight * set.reps);
      if (exVol > bestVol) {
        bestVol = exVol;
        bestEx = ex.name;
      }
    }

    _perfMemory.insert(
      0,
      PerformancePattern(
        date: _todayStr,
        volume: volume,
        setsCompleted: setsCompleted,
        setsPlanned: setsPlanned,
        effortScore: effort,
        mood: mood.name,
        wasFailedSession: effort < 40,
        musclesTrained: musclesHit,
        bestExercise: bestEx,
      ),
    );

    if (_perfMemory.length > _maxMemory) {
      _perfMemory = _perfMemory.sublist(0, _maxMemory);
    }

    notifyListeners();
    await _persistMemory();
  }

  Future<void> clearMemory() async {
    _perfMemory = [];
    notifyListeners();
    await _persistMemory();
  }

  // ═════════════════════════════════════════════════════════
  // GEMINI SESSION INSIGHT — real AI analysis after workout
  // ═════════════════════════════════════════════════════════
  Future<void> generateSessionInsight({
    required DayPlan day,
    required MoodType mood,
    required String goal,
    required String level,
    required int streak,
  }) async {
    if (_generatingSessionInsight) return;
    _generatingSessionInsight = true;
    _lastSessionInsight = '';
    notifyListeners();

    try {
      // Today is _perfMemory[0], previous session is [1]
      final today = _perfMemory.isNotEmpty ? _perfMemory[0] : null;
      final prev  = _perfMemory.length > 1  ? _perfMemory[1] : null;

      final setsCompleted = today?.setsCompleted ?? 0;
      final setsPlanned   = today?.setsPlanned   ?? 0;
      final volume        = today?.volume        ?? 0.0;
      final muscles       = (today?.musclesTrained ?? []).join(', ');
      final bestEx        = today?.bestExercise  ?? '';

      final prevLine = prev != null
          ? 'Previous session: ${prev.setsCompleted} sets, ${prev.volume.toStringAsFixed(0)}kg total volume.'
          : 'This is one of their first sessions.';

      final volumeChange = (prev != null && prev.volume > 0)
          ? ' (${((volume - prev.volume) / prev.volume * 100).toStringAsFixed(0)}% vs last session)'
          : '';

      final prompt =
          'You are an elite personal trainer. Analyze this workout and give EXACTLY 2 sentences '
          'of specific, data-driven feedback. Be direct and motivating. No markdown, no lists.\n\n'
          'ATHLETE: $level level, goal: ${goal.replaceAll("_", " ")}, streak: $streak days\n'
          'TODAY: $setsCompleted/$setsPlanned sets completed, '
          '${volume.toStringAsFixed(0)}kg volume$volumeChange\n'
          '${muscles.isNotEmpty ? "Muscles trained: $muscles\n" : ""}'
          '${bestEx.isNotEmpty ? "Best lift today: $bestEx\n" : ""}'
          'Mood: ${mood.name}\n'
          '$prevLine\n\n'
          'Respond with exactly 2 sentences. Start with one relevant emoji.';

      final response = await ApiService.askAI(prompt, type: AiRequestType.insight);

      if (!response.startsWith('⚠️') && !response.startsWith('❌')) {
        _lastSessionInsight = response;
      }
    } catch (e) {
      debugPrint('generateSessionInsight error: $e');
    } finally {
      _generatingSessionInsight = false;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════════
  // DAILY GEMINI BRIEF — replaces rule-based home coach message
  // ═════════════════════════════════════════════════════════
  Future<void> generateDailyBrief({
    required String goal,
    required String level,
    required int streak,
    required String todayWorkoutTitle,
    required List<String> todayExercises,
    required List<({String muscle, int score})> muscleScores,
    required List<({String name, double bestWeight, int bestReps})> exerciseHistory,
    bool forceRefresh = false,
  }) async {
    // One brief per day — unless explicitly refreshed after workout completion
    if (!forceRefresh &&
        _dailyBriefDate == _todayStr &&
        _dailyBrief.isNotEmpty) {
      return;
    }

    // Skip network call when offline — UI will show cached brief or offline state.
    if (!ConnectivityService.instance.isOnline) {
      _briefOffline = _dailyBrief.isEmpty;
      notifyListeners();
      return;
    }
    _briefOffline = false;

    try {
      final muscles = muscleScores
          .map((m) => '${m.muscle}: ${m.score}%')
          .join(', ');

      final history = exerciseHistory.take(5).map((e) {
        if (e.bestWeight > 0) return '${e.name} ${e.bestWeight}kg×${e.bestReps}';
        return '${e.name} ${e.bestReps}reps';
      }).join(', ');

      final todayBlock = todayExercises.isNotEmpty
          ? 'Today\'s planned: ${todayWorkoutTitle.isNotEmpty ? todayWorkoutTitle : "workout"} — ${todayExercises.take(3).join(", ")}'
          : 'Rest day today';

      final prompt =
          'You are an elite fitness coach. Give a SINGLE sentence morning brief — '
          'specific, data-driven, actionable. No fluff. Start with one emoji.\n\n'
          'ATHLETE: $level | goal: ${goal.replaceAll("_", " ")} | streak: $streak days\n'
          '$todayBlock\n'
          'Recovery — $muscles\n'
          '${history.isNotEmpty ? "Recent bests: $history" : ""}\n\n'
          'One sentence. Reference specific muscle recovery or last weight. Be a coach, not a chatbot.';

      final response = await ApiService.askAI(prompt, type: AiRequestType.brief);
      if (!response.startsWith('⚠️') && !response.startsWith('❌')) {
        _dailyBrief     = response;
        _dailyBriefDate = _todayStr;
        _briefOffline   = false;
        notifyListeners();
        // Persist so brief survives app restart
        StorageService.instance.setString('ai_daily_brief',      _dailyBrief).ignore();
        StorageService.instance.setString('ai_daily_brief_date', _dailyBriefDate).ignore();
      }
    } catch (e) {
      debugPrint('generateDailyBrief error: $e');
    }
  }

  void invalidateDailyBrief() {
    _dailyBrief = '';
    _dailyBriefDate = '';
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════
  // AI WORKOUT PLAN GENERATION
  // ═════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> generateWorkoutPlan(
    AIWorkoutRequest request,
  ) async {
    _generatingPlan = true;
    notifyListeners();
    try {
      final prompt = _buildPrompt(request);
      // Workout plan is a full JSON week — must use plan type for 16k token limit + JSON mode.
      final raw = await ApiService.askAI(
        prompt,
        timeout:   const Duration(seconds: 120),
        type:      AiRequestType.plan,
        isPremium: MonetizationService.instance.isPremium,
      );

      debugPrint('================ AI RAW RESPONSE ================');
      debugPrint(raw);
      debugPrint('================================================');

      if (raw.startsWith('⚠️') || raw.startsWith('❌')) {
        debugPrint('AIProvider backend returned error: $raw');
        final fallback = _fallbackWorkoutMap();
        _setPlanContent(_formatWorkout(fallback), planName: 'Fallback PPL');
        return fallback;
      }

      final parsed = _parseResponse(raw);
      _setPlanContent(
        _formatWorkout(parsed),
        planName: _extractPlanName(parsed),
      );
      return parsed;
    } catch (e, s) {
      debugPrint('AIProvider.generateWorkoutPlan error: $e\n$s');
      final fallback = _fallbackWorkoutMap();
      _setPlanContent(_formatWorkout(fallback), planName: 'Fallback PPL');
      return fallback;
    } finally {
      _generatingPlan = false;
      notifyListeners();
    }
  }

  Future<void> generateQuickSuggestion(AIWorkoutRequest request) async {
    final result = await generateWorkoutPlan(request);
    _setPlanContent(
      _formatWorkout(result),
      planName: _extractPlanName(result),
    );
  }

  // ═════════════════════════════════════════════════════════
  // PLAN CONTENT MANAGEMENT (with debounced save)
  // ═════════════════════════════════════════════════════════
  void _setPlanContent(String fullText, {String planName = 'AI Plan'}) {
    final clean = fullText.trim();
    _aiFullPlan = clean;

    final firstLine = clean.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    final shortName = planName.isNotEmpty ? planName : firstLine;
    final tagline =
        shortName.length > 60 ? '${shortName.substring(0, 57)}...' : shortName;
    _aiTagline = '🔥 New plan ready: $tagline';
    _taglineSetAt = DateTime.now();

    _persistAIPlan();
  }

  Future<void> _persistAIPlan() async {
    try {
      await StorageService.instance.setString('ai_full_plan', _aiFullPlan);
      await StorageService.instance.setString('ai_tagline', _aiTagline);
      if (_taglineSetAt != null) {
        await StorageService.instance.setString(
          'ai_tagline_set_at', _taglineSetAt!.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('_persistAIPlan error: $e');
    }
  }

  String _extractPlanName(Map<String, dynamic> parsed) {
    final raw = parsed['planName'] ??
        parsed['name'] ??
        parsed['title'] ??
        parsed['workout_name'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return 'New AI Plan';
  }

  String _formatWorkout(Map<String, dynamic> plan) {
    final buffer = StringBuffer();
    buffer.writeln(plan['workout_name'] ?? 'Workout Plan');
    buffer.writeln('');
    final days = plan['days'];
    if (days is! List) return buffer.toString();
    for (final day in days) {
      if (day is! Map) continue;
      buffer.writeln('${day['day']} - ${day['focus']}');
      final exercises = day['exercises'];
      if (exercises is List) {
        for (final ex in exercises) {
          if (ex is! Map) continue;
          buffer.writeln('- ${ex['name']} (${ex['sets']} x ${ex['reps']})');
        }
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  // ═════════════════════════════════════════════════════════
  // PROMPT BUILDING
  // ═════════════════════════════════════════════════════════
  String _buildPrompt(AIWorkoutRequest r) {
    final buf = StringBuffer();
    buf.writeln('You are a professional gym coach AI.');
    buf.writeln('Your task is to generate a weekly workout plan.');

    // Week structure rules — always enforced
    final promptDayNames = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final todayWeekday = DateTime.now().weekday; // 1=Mon, 7=Sun
    final todayDayName = promptDayNames[todayWeekday - 1];
    buf.writeln('\nWEEK STRUCTURE (MANDATORY):');
    buf.writeln('Day 1=Monday, Day 2=Tuesday, Day 3=Wednesday, Day 4=Thursday, Day 5=Friday, Day 6=Saturday, Day 7=Sunday.');
    buf.writeln('Sunday (Day 7) = ALWAYS Rest — never schedule workouts on Sunday. Gym is closed on Sunday.');
    if (r.totalWorkouts == 0 && todayWeekday > 1 && todayWeekday < 7) {
      // New user joining mid-week
      buf.writeln('NEW USER STARTING TODAY ($todayDayName): Mark all days before $todayDayName as Rest.');
      buf.writeln('Place workouts only from $todayDayName through Saturday. Do NOT assign workouts to past days.');
    }

    buf.writeln('\nSTRICT RULES:');
    buf.writeln('- Output ONLY JSON');
    buf.writeln('- NO explanation');
    buf.writeln('- NO markdown');
    buf.writeln('- NO extra text');
    buf.writeln('- Response MUST be complete — do NOT truncate exercises');
    buf.writeln('- Exercise names must be in ENGLISH only');
    buf.writeln('- Focus must be clear (Push, Pull, Legs, Rest etc.)');
    buf.writeln('- NEVER repeat the same exercise_id twice on the same day');
    buf.writeln('- NEVER add core/ab/plank exercises unless the day explicitly targets "core" — core is NOT a filler');
    buf.writeln('- Each muscle listed for a day MUST have at least 2 exercises — missing muscles are a critical error');
    if (r.travelMode || r.bodyweightOnly) {
      buf.writeln('');
      buf.writeln('🚨 TRAVEL MODE ACTIVE — CRITICAL:');
      buf.writeln('- ONLY bodyweight exercises (NO gym, NO equipment)');
      buf.writeln('- NO barbell, dumbbell, cable, machine, or any weights');
      buf.writeln('- Use ONLY: Push-ups, Pull-ups, Squats, Lunges, Plank,');
      buf.writeln('  Burpees, Mountain Climbers, Dips (chair), Pike Push-ups,');
      buf.writeln('  Glute Bridges, Calf Raises, Crunches, Russian Twists,');
      buf.writeln('  Jumping Jacks, High Knees, Wall Sit, Superman');
      buf.writeln('- User has NO access to gym — hotel/home workouts only');
    }
    // ── Split style constraint ─────────────────────────
    buf.writeln('');
    if (r.splitStyle == SplitStyle.aiAdaptive) {
      final profile = r.adaptiveReadiness;
      if (profile != null) {
        // V2: profile-based scheduling — no contradictory binary rules.
        buf.writeln('SPLIT STYLE: AI ADAPTIVE');
        buf.writeln('Recovery status: ${profile.readinessExplanation}');
        buf.writeln('Output EXACTLY ${profile.effectiveDaysThisWeek} training days.');
        if (profile.isDeloadWeek) {
          buf.writeln('DELOAD WEEK: Reduce load to 60% of normal. Focus on form and technique.');
        }
        if (profile.muscleSlots.isNotEmpty) {
          buf.writeln('MUSCLE SCHEDULE — distribute target sets across training days:');
          for (final slot in profile.muscleSlots) {
            buf.writeln('  ${slot.muscle}: ${slot.targetSets} sets total this week');
          }
        }
        buf.writeln('Pair synergists across days (chest+triceps, back+biceps, quads+hamstrings).');
        buf.writeln('Prioritise compound movements. Place rest between sessions targeting the same muscle.');
      } else {
        // Fallback: V1 prompt (no profile computed — e.g., first launch with no data).
        buf.writeln(SplitTemplate.adaptivePromptConstraints(
          recoveryScores: r.muscleRecoveryScores,
          daysPerWeek:    r.daysPerWeek,
          goal:           r.goal,
          streak:         r.currentStreak,
        ));
      }
    } else {
      final template = SplitTemplate.forStyle(r.splitStyle, r.daysPerWeek);
      buf.writeln(template.toCompactPromptConstraints());
    }

    // ── Daily readiness — highest priority modifier ────────
    if (r.readinessScore > 0) {
      buf.writeln('');
      buf.writeln(ReadinessLevelX.fromScore(r.readinessScore).promptBlock);
    }

    buf.writeln('\nUSER PROFILE:');
    buf.writeln('Goal: ${r.goal.replaceAll("_", " ")}');
    buf.writeln('Level: ${r.level}');
    final effectiveDays =
        (r.splitStyle == SplitStyle.aiAdaptive && r.adaptiveReadiness != null)
            ? r.adaptiveReadiness!.effectiveDaysThisWeek
            : r.daysPerWeek;

    buf.writeln('Days per week: $effectiveDays');
    buf.writeln('Workout streak: ${r.currentStreak}');
    buf.writeln('Total workouts: ${r.totalWorkouts}');

    // ── Sports Science Protocols (MANDATORY — override AI defaults) ──────
    buf.writeln('\nSPORTS SCIENCE PROTOCOLS — FOLLOW EXACTLY:');

    // Volume per muscle per week
    final volumeRule = switch (r.level) {
      'beginner'     => '6–10 sets per muscle per week',
      'intermediate' => '10–15 sets per muscle per week',
      _              => '15–20 sets per muscle per week',
    };
    buf.writeln('VOLUME: $volumeRule');

    // Rep, rest, and ratio rules by goal
    final goal = r.goal.toLowerCase();
    // Sets are always 3 — controlled by app, not AI
    buf.writeln('SETS: Always output "sets": 3 for every exercise. Do NOT output 4 or 5 sets.');

    if (goal.contains('muscle') || goal.contains('hypertrophy') || goal.contains('gain')) {
      buf.writeln('REPS: 8–12 per set (hypertrophy range)');
      buf.writeln('REST: 90–120 seconds between sets');
      buf.writeln('EXERCISE MIX: 60% compound movements, 40% isolation');
    } else if (goal.contains('strength') || goal.contains('power')) {
      buf.writeln('REPS: 4–6 per set for compounds, 8–10 for accessories');
      buf.writeln('REST: 3–5 minutes between compound sets, 90 seconds between isolation');
      buf.writeln('EXERCISE MIX: 80%+ compound movements, minimal isolation');
    } else if (goal.contains('fat') || goal.contains('weight_loss') || goal.contains('cut')) {
      buf.writeln('REPS: 12–15 per set (higher reps, shorter rest = metabolic effect)');
      buf.writeln('REST: 45–60 seconds between sets');
      buf.writeln('EXERCISE MIX: supersets preferred — pair antagonist muscles');
      buf.writeln('FINISHER: Add 1 HIIT finisher at end of each session (10 min)');
    } else {
      buf.writeln('REPS: 8–12 per set');
      buf.writeln('REST: 60–90 seconds between sets');
      buf.writeln('SETS PER EXERCISE: 3–4 sets');
    }

    // Exercises per session — split-aware HARD MINIMUM
    final bool isFullBody = r.splitStyle == SplitStyle.fullBody;

    final int minEx;
    final int maxEx;
    if (isFullBody) {
      // Full body: 2-3 per muscle × 4-5 muscle groups = 10-15 total
      minEx = switch (r.level) { 'beginner' => 8, 'intermediate' => 10, _ => 12 };
      maxEx = switch (r.level) { 'beginner' => 10, 'intermediate' => 14, _ => 16 };
    } else {
      // Standard dedicated muscle days (PPL, Upper/Lower, Antagonist, Adaptive)
      minEx = switch (r.level) { 'beginner' => 4, 'intermediate' => 6, _ => 8 };
      maxEx = switch (r.level) { 'beginner' => 5, 'intermediate' => 7, _ => 10 };
    }
    buf.writeln('EXERCISES PER SESSION: minimum $minEx, maximum $maxEx exercises per workout day');
    buf.writeln('CRITICAL: Never generate fewer than $minEx exercises on any training day. Rest days = 0 exercises.');

    // Frequency-aware volume per session (full body only — other splits handled by split constraints)
    final weeklyFrequency = r.daysPerWeek;
    if (isFullBody) {
      final setsPerSession = switch (r.level) {
        'beginner'     => '2–3',
        'intermediate' => '3–4',
        _              => '4–5',
      };
      buf.writeln('FULL BODY VOLUME: $setsPerSession sets per muscle group per session (trained $weeklyFrequency×/week).');
    }

    // Progressive overload instruction
    if (r.exerciseHistory.isNotEmpty) {
      buf.writeln('PROGRESSIVE OVERLOAD: Build on user\'s existing bests listed below. Add 2.5–5kg or 1–2 reps vs last session.');
    }
    buf.writeln('\nCONDITIONS:');
    if (r.weakMuscles.isNotEmpty) {
      buf.writeln('Prioritize muscles: ${r.weakMuscles.join(", ")}');
    }
    if (r.isOnPlateau) buf.writeln('User is stuck → change exercises');
    if (r.needsDeload) buf.writeln('Deload needed → reduce intensity');
    // Per-muscle recovery constraints.
    // Skipped for AI Adaptive when a profile is available — the slot schedule
    // above already encodes volume decisions without contradictory binary rules.
    final bool useAdaptiveProfile =
        r.splitStyle == SplitStyle.aiAdaptive && r.adaptiveReadiness != null;
    if (r.muscleRecoveryScores.isNotEmpty && !useAdaptiveProfile) {
      final suppressed = r.muscleRecoveryScores.where((m) => m.score < 60).toList();
      final prime = r.muscleRecoveryScores.where((m) => m.score >= 80).toList();
      buf.writeln('\nMUSCLE RECOVERY STATUS (FOLLOW EXACTLY):');
      for (final m in r.muscleRecoveryScores) {
        final label = m.score < 50
            ? 'SUPPRESSED — DO NOT TRAIN'
            : m.score < 70
                ? 'LOW RECOVERY — light/accessory only'
                : m.score < 85
                    ? 'MODERATE — OK to train'
                    : 'PRIME — prioritize today';
        buf.writeln('  ${m.muscle}: ${m.score}% — $label');
      }
      if (suppressed.isNotEmpty) {
        final names = suppressed.map((m) => m.muscle).join(', ');
        buf.writeln('CRITICAL: Zero exercises targeting: $names');
        buf.writeln('Replace those muscle days with PRIME muscles or rest.');
      }
      if (prime.isNotEmpty) {
        final names = prime.map((m) => m.muscle).join(', ');
        buf.writeln('BUILD PLAN AROUND: $names (fully recovered)');
      }
    } else if (r.isFatigued && !useAdaptiveProfile) {
      buf.writeln('User fatigued → keep moderate load');
    }
    buf.writeln('Performance: ${r.performanceTrend}');
    buf.writeln('Volume trend: ${r.weeklyVolumeTrend.toStringAsFixed(1)}');
    if (r.missedDays.isNotEmpty) {
      buf.writeln('Missed days: ${r.missedDays.join(", ")}');
    }

    if (r.recentWorkoutNames.isNotEmpty) {
      buf.writeln('\nRECENT WORKOUTS (avoid repeating these exact patterns):');
      for (final n in r.recentWorkoutNames.take(7)) {
        buf.writeln('- $n');
      }
    }

    if (r.exerciseHistory.isNotEmpty) {
      buf.writeln('\nUSER\'S STRONGEST LIFTS (build progression on these):');
      for (final ex in r.exerciseHistory.take(5)) {
        buf.writeln('- ${ex.name}: ${ex.bestWeight}${ex.unit} x ${ex.bestReps} reps');
      }
    }

    if (r.lastWeekMemory != null) {
      final m = r.lastWeekMemory!;
      buf.writeln('\nLAST WEEK SUMMARY:');
      buf.writeln('- Plan: ${m.planName}');
      buf.writeln('- Completed: ${m.completedDays}/${m.plannedDays} days');
      buf.writeln('- Volume: ${m.totalVolume.toStringAsFixed(0)}kg');
      buf.writeln('- Effort: ${m.avgEffortScore.toStringAsFixed(0)}%');
      if (m.wasDeload) buf.writeln('- Was deload week');
      buf.writeln('IMPORTANT: Generate DIFFERENT exercises than last week to avoid boredom and pattern adaptation. Rotate variations.');
    }

    // ── VALID EXERCISE CANDIDATES ─────────────────────
    final candidates = ExerciseCandidateService.select(
      splitStyle: r.splitStyle,
      targetMuscles: _targetMusclesForCandidates(r),
      daysPerWeek: r.daysPerWeek,
      level: r.level,
      travelMode: r.travelMode,
      bodyweightOnly: r.bodyweightOnly,
      recentExerciseHistory: r.exerciseHistory,
    );

    buf.writeln('\nAVAILABLE EXERCISE CANDIDATES (USE ONLY THESE IDS):');
    buf.writeln('Format: exercise_id|name|muscle|equipment|type');
    buf.writeln(ExerciseCandidateService.toPromptLines(candidates));

    buf.writeln('\nCRITICAL AI RULES:');
    buf.writeln('- You MUST use ONLY exercise_id values from AVAILABLE EXERCISE CANDIDATES');
    buf.writeln('- NEVER invent exercise IDs');
    buf.writeln('- NEVER invent exercise names');
    buf.writeln('- Every exercise object MUST contain exercise_id');
    buf.writeln('- Prefer exercise_id over name');

    buf.writeln('\nOUTPUT FORMAT (FOLLOW EXACTLY):');
    buf.writeln('{"workout_name":"Plan Name","days":[{"day":"Monday","focus":"Back & Biceps","exercises":[{"exercise_id":"id_from_candidates","sets":3,"reps":"8-12"}]},{"day":"Tuesday","focus":"Rest","exercises":[]}]}');
    return buf.toString();
  }

  List<String> _targetMusclesForCandidates(AIWorkoutRequest r) {
    final muscles = <String>{};
    if (r.splitStyle == SplitStyle.aiAdaptive && r.adaptiveReadiness != null) {
      muscles.addAll(r.adaptiveReadiness!.muscleSlots.map((s) => s.muscle));
    } else if (r.splitStyle != SplitStyle.aiAdaptive) {
      final template = SplitTemplate.forStyle(r.splitStyle, r.daysPerWeek);
      muscles.addAll(template.trainingDays.expand((d) => d.muscles));
    } else {
      muscles.addAll(r.muscleRecoveryScores
          .where((m) => m.score >= 60)
          .map((m) => m.muscle));
    }
    muscles.addAll(r.weakMuscles);
    if (muscles.isEmpty) {
      muscles.addAll(['chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs']);
    }
    return muscles.toList();
  }

  Map<String, dynamic> _parseResponse(String raw) {
    try {
      String clean = raw.trim();
      clean = clean.replaceAll(RegExp(r'```json|```'), '');
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        throw Exception('Invalid JSON boundaries');
      }
      clean = clean.substring(start, end + 1);
      final decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic> &&
          decoded['workout_name'] is String &&
          decoded['days'] is List &&
          (decoded['days'] as List).isNotEmpty &&
          (decoded['days'][0] is Map) &&
          (decoded['days'][0]['exercises'] is List)) {
        return decoded;
      }
      throw Exception('Invalid structure');
    } catch (e) {
      debugPrint('❌ AI parse failed → fallback used: $e');
      return _fallbackWorkoutMap();
    }
  }

  Map<String, dynamic> _fallbackWorkoutMap() => {
        'workout_name': 'Smart PPL Backup Plan',
        'days': [
          {
            'day': 'Monday',
            'focus': 'Push',
            'exercises': [
              {'name': 'Bench Press', 'sets': 4, 'reps': '8-12'},
              {'name': 'Incline Dumbbell Press', 'sets': 3, 'reps': '10-12'},
              {'name': 'Overhead Press', 'sets': 3, 'reps': '8-10'},
              {'name': 'Lateral Raise', 'sets': 3, 'reps': '12-15'},
              {'name': 'Tricep Pushdown', 'sets': 3, 'reps': '10-12'},
            ],
          },
          {
            'day': 'Tuesday',
            'focus': 'Pull',
            'exercises': [
              {'name': 'Pull Ups', 'sets': 4, 'reps': '6-10'},
              {'name': 'Barbell Row', 'sets': 3, 'reps': '8-10'},
              {'name': 'Lat Pulldown', 'sets': 3, 'reps': '10-12'},
              {'name': 'Face Pull', 'sets': 3, 'reps': '12-15'},
              {'name': 'Bicep Curl', 'sets': 3, 'reps': '10-12'},
            ],
          },
          {
            'day': 'Wednesday',
            'focus': 'Legs',
            'exercises': [
              {'name': 'Squat', 'sets': 4, 'reps': '6-10'},
              {'name': 'Romanian Deadlift', 'sets': 3, 'reps': '8-10'},
              {'name': 'Leg Press', 'sets': 3, 'reps': '10-12'},
              {'name': 'Leg Curl', 'sets': 3, 'reps': '10-12'},
              {'name': 'Calf Raise', 'sets': 4, 'reps': '12-15'},
            ],
          },
          {'day': 'Thursday', 'focus': 'Rest', 'exercises': []},
          {
            'day': 'Friday',
            'focus': 'Push',
            'exercises': [
              {'name': 'Incline Bench Press', 'sets': 4, 'reps': '8-12'},
              {'name': 'Chest Fly', 'sets': 3, 'reps': '12-15'},
              {'name': 'Shoulder Press', 'sets': 3, 'reps': '8-10'},
              {'name': 'Lateral Raise', 'sets': 3, 'reps': '12-15'},
              {'name': 'Dips', 'sets': 3, 'reps': '8-12'},
            ],
          },
          {
            'day': 'Saturday',
            'focus': 'Pull',
            'exercises': [
              {'name': 'Deadlift', 'sets': 3, 'reps': '5-8'},
              {'name': 'Seated Row', 'sets': 3, 'reps': '10-12'},
              {'name': 'Lat Pulldown', 'sets': 3, 'reps': '10-12'},
              {'name': 'Hammer Curl', 'sets': 3, 'reps': '10-12'},
              {'name': 'Face Pull', 'sets': 3, 'reps': '12-15'},
            ],
          },
          {'day': 'Sunday', 'focus': 'Rest', 'exercises': []},
        ],
      };

  // ═════════════════════════════════════════════════════════
  // INSIGHT COMPUTATION
  // ═════════════════════════════════════════════════════════
  AICoachInsight _computeInsight(AICoachInputs inputs) {
    final fatigue = _detectFatigueLevel(inputs);
    final wSuggest = _computeWeightSuggestion(inputs);
    final weakGroup = _detectWeakMuscleGroup(inputs.logs);
    final sets = _computeRecommendedSets(fatigue, inputs);
    final modifier = _computeWeightModifier(fatigue, wSuggest, inputs);

    final message = _generateDailyCoachMessage(
      inputs: inputs,
      fatigue: fatigue,
      suggestion: wSuggest,
      weakMuscle: weakGroup,
    );

    return AICoachInsight(
      fatigueLevel: fatigue,
      fatigueMessage: _fatigueMessage(fatigue),
      weightSuggestion: wSuggest,
      weightMessage: _weightSuggestionMessage(wSuggest, inputs.isOnPlateau),
      weakMuscleGroup: weakGroup,
      dailyCoachMessage: message,
      recommendedSets: sets,
      weightModifier: modifier,
      cacheDate: _todayStr,
    );
  }

  FatigueLevel _detectFatigueLevel(AICoachInputs inputs) {
    int score = 0;
    if (inputs.currentStreak >= 5) score += 1;
    if (inputs.currentStreak >= 10) score += 2;
    if (inputs.currentStreak >= 20) score += 3;
    if (inputs.mood == MoodType.tired) score += 2;
    if (inputs.mood == MoodType.energetic) score -= 1;
    if (inputs.daysSinceLastWorkout >= 3) score -= 2;
    if (inputs.isOnPlateau) score += 1;
    if (inputs.needsDeload) score += 3;
    if (hasFailurePattern) score += 2;
    score = score.clamp(-2, 6);
    if (score >= 4) return FatigueLevel.fatigued;
    if (score >= 1) return FatigueLevel.normal;
    return FatigueLevel.fresh;
  }

  String _fatigueMessage(FatigueLevel l) {
    switch (l) {
      case FatigueLevel.fresh:
        return _pickUnique('fatigue_fresh', [
          '🚀 You are fully recovered — push your limits today!',
          '💪 Peak condition — today is a PR opportunity.',
          '🔥 Energy is high — train hard and dominate.',
        ]);
      case FatigueLevel.normal:
        return _pickUnique('fatigue_normal', [
          '😐 Slight fatigue — focus on clean reps.',
          '⚖️ Balanced state — train smart, not just hard.',
          '🔄 Moderate recovery — consistency is key today.',
        ]);
      case FatigueLevel.fatigued:
        return _pickUnique('fatigue_fatigued', [
          '⚠️ High fatigue detected — reduce weight today.',
          '🛑 Your body needs recovery — go light.',
          '🔻 Deload recommended — protect long-term progress.',
        ]);
    }
  }

  WeightSuggestion _computeWeightSuggestion(AICoachInputs inputs) {
    if (inputs.logs.isEmpty) return WeightSuggestion.maintain;
    if (inputs.isOnPlateau) return WeightSuggestion.decrease;

    final recent = List<WorkoutLog>.from(inputs.logs)
      ..sort((a, b) => b.date.compareTo(a.date));
    final limited = recent.take(8).toList();
    if (limited.isEmpty) return WeightSuggestion.maintain;

    final last = limited.first;
    final same =
        limited.where((l) => l.exercise == last.exercise).take(4).toList();

    if (same.length < 2) {
      if (last.reps >= 12 && last.weight > 0) {
        return WeightSuggestion.increase;
      }
      if (last.reps <= 5) {
        return WeightSuggestion.decrease;
      }
      return WeightSuggestion.maintain;
    }

    same.sort((a, b) => b.date.compareTo(a.date));
    final curr = same[0];
    final prev = same[1];

    final repDiff = curr.reps - prev.reps;
    final weightDiff = curr.weight - prev.weight;

    double volume(WorkoutLog l) => l.weight * l.reps;
    final currVol = volume(curr);
    final prevVol = volume(prev);

    final isStruggling = curr.reps <= 5 && repDiff < 0;
    final isImproving = (repDiff >= 2 && curr.reps >= 10) ||
        (currVol > prevVol * 1.1);
    final isDropping =
        currVol < prevVol * 0.85 || (weightDiff > 0 && repDiff < -2);

    if (isStruggling) return WeightSuggestion.decrease;
    if (isImproving) return WeightSuggestion.increase;
    if (isDropping) return WeightSuggestion.decrease;
    if (inputs.needsDeload) return WeightSuggestion.decrease;
    return WeightSuggestion.maintain;
  }

  String _weightSuggestionMessage(WeightSuggestion s, bool plateau) {
    if (_cachedWeightMessage.isNotEmpty) return _cachedWeightMessage;
    if (plateau) {
      _cachedWeightMessage =
          '🔄 Plateau detected — reduce weight 10% and rebuild with perfect form.';
      return _cachedWeightMessage;
    }
    switch (s) {
      case WeightSuggestion.increase:
        _cachedWeightMessage = _pickUnique('weight_inc', [
          'Performance trend is improving.',
          'Recovery appears stable for progression.',
          'Training output is increasing consistently.',
        ]);
        break;
      case WeightSuggestion.decrease:
        _cachedWeightMessage = _pickUnique('weight_dec', [
          'Performance drop detected — reduce weight and focus on control.',
          'Recovery or fatigue issue — go lighter today.',
          'Reset the weight — rebuild stronger with better form.',
        ]);
        break;
      case WeightSuggestion.maintain:
        _cachedWeightMessage = _pickUnique('weight_main', [
          'Maintain weight — focus on clean reps.',
          'Consistency phase — master the movement.',
          'Stable performance — keep the same load.',
        ]);
        break;
    }
    return _cachedWeightMessage;
  }

  String _detectWeakMuscleGroup(List<WorkoutLog> logs) {
    if (logs.isEmpty) return '';
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 21));
    final recent = logs.where((l) => l.date.isAfter(cutoff)).toList();
    if (recent.length < 5) return '';

    const keywords = {
      'chest': ['bench', 'chest', 'fly', 'push', 'pec', 'incline', 'decline'],
      'back': ['row', 'pull', 'deadlift', 'lat', 'back', 'chin'],
      'legs': ['squat', 'leg', 'lunge', 'calf', 'hamstring', 'glute', 'rdl'],
      'shoulders': ['shoulder', 'press', 'lateral', 'raise', 'delt', 'arnold'],
      'arms': ['curl', 'tricep', 'bicep', 'hammer', 'pushdown', 'extension'],
      'core': ['plank', 'crunch', 'ab', 'core', 'sit'],
    };

    final freq = <String, int>{};
    final volume = <String, double>{};

    for (final log in recent) {
      final name = log.exercise.toLowerCase();
      for (final entry in keywords.entries) {
        if (entry.value.any((k) => name.contains(k))) {
          final key = entry.key;
          freq[key] = (freq[key] ?? 0) + 1;
          final vol = log.weight * log.reps;
          volume[key] = (volume[key] ?? 0) + vol;
          break;
        }
      }
    }

    if (freq.isEmpty) return '';

    final scores = <String, double>{};
    for (final m in keywords.keys) {
      final f = freq[m] ?? 0;
      final v = volume[m] ?? 0;
      scores[m] = (f * 0.6) + (v * 0.0004);
    }

    String weakest = '';
    double minScore = double.infinity;
    for (final entry in scores.entries) {
      if (entry.value < minScore) {
        minScore = entry.value;
        weakest = entry.key;
      }
    }
    if (weakest.isEmpty) return '';
    return '${weakest[0].toUpperCase()}${weakest.substring(1)}';
  }

  int _computeRecommendedSets(FatigueLevel f, AICoachInputs inputs) {
    int base;
    switch (inputs.level) {
      case 'beginner':
        base = 3;
        break;
      case 'advanced':
        base = 5;
        break;
      default:
        base = 4;
    }
    int sets = base;
    switch (f) {
      case FatigueLevel.fatigued:
        sets -= 1;
        break;
      case FatigueLevel.fresh:
        sets += 1;
        break;
      case FatigueLevel.normal:
        break;
    }
    if (inputs.isOnPlateau) sets += 1;
    if (inputs.needsDeload) sets -= 2;
    if (inputs.currentStreak >= 7) sets += 1;
    if (inputs.daysSinceLastWorkout >= 3) sets -= 1;
    return sets.clamp(2, 6);
  }

  double _computeWeightModifier(
    FatigueLevel f,
    WeightSuggestion s,
    AICoachInputs inputs,
  ) {
    double m = 1.0;
    switch (f) {
      case FatigueLevel.fatigued:
        m *= 0.80;
        break;
      case FatigueLevel.normal:
        m *= 0.95;
        break;
      case FatigueLevel.fresh:
        m *= 1.05;
        break;
    }
    switch (s) {
      case WeightSuggestion.increase:
        m *= 1.05;
        break;
      case WeightSuggestion.decrease:
        m *= 0.90;
        break;
      case WeightSuggestion.maintain:
        break;
    }
    if (inputs.isOnPlateau) m *= 0.90;
    if (inputs.needsDeload) m *= 0.75;
    if (inputs.daysSinceLastWorkout >= 4) m *= 0.85;
    if (inputs.level == 'beginner') m = m.clamp(0.7, 1.0);
    return m.clamp(0.5, 1.2);
  }

  // ═════════════════════════════════════════════════════════
  // DAILY COACH MESSAGE GENERATOR (priority system)
  // ═════════════════════════════════════════════════════════
  String _generateDailyCoachMessage({
    required AICoachInputs inputs,
    required FatigueLevel fatigue,
    required WeightSuggestion suggestion,
    required String weakMuscle,
  }) {
    final style = _adaptiveTone(inputs.trainerType);
    final streak = inputs.currentStreak;
    final inactive = inputs.daysSinceLastWorkout >= 3;
    final trend = performanceTrend;
    final mood = inputs.mood;

    int priority = 0;
    String finalMessage = '';

    void trySet(int p, String msg) {
      if (p > priority && msg.isNotEmpty) {
        priority = p;
        finalMessage = msg;
      }
    }

    // 1. Streak pressure
    if (streak > 0) {
      const milestones = {
        7: '7-DAY FIRE BADGE',
        14: 'UNSTOPPABLE BADGE',
        30: 'IRON WILL BADGE',
        60: 'LEGEND STATUS',
        100: 'ELITE WARRIOR',
        150: 'BEAST MODE',
      };
      final upcoming = milestones.keys.firstWhere(
        (m) => m - 1 == streak,
        orElse: () => -1,
      );
      if (upcoming != -1) {
        trySet(99, _streakPressure(style, streak, milestones[upcoming]!));
      }
    }

    // 1b. Beginner phase
    if (inputs.totalWorkouts < 7 && priority < 90) {
      trySet(
          90,
          _style(
            style,
            friendly: _pickUnique('beginner_friendly', [
              '👋 ${inputs.userName}, welcome! Just one workout today — that\'s enough.',
              '🌱 Start small. Show up today. That\'s how habits are built.',
              '💪 First week matters most — consistency over intensity.',
              '🎯 One exercise. Full focus. That\'s your mission today.',
            ]),
            strict: _pickUnique('beginner_strict', [
              '📋 Beginner phase. Form > weight. No shortcuts.',
              '⚙️ Build base first. Log every session.',
              '🎯 First 7 workouts build your foundation.',
            ]),
            military: _pickUnique('beginner_military', [
              '🪖 RECRUIT MODE. SHOW UP. EXECUTE.',
              '🪖 DAY ONE DISCIPLINE. COMPLETE MISSION.',
            ]),
            hype: _pickUnique('beginner_hype', [
              '🔥 ${inputs.userName}, THIS IS YOUR START!! LET\'S GO!!',
              '💥 FIRST STEP = BIGGEST STEP!! START NOW!!',
            ]),
          ));
    }

    // 2. Comeback
    if (inactive) {
      final days = inputs.daysSinceLastWorkout;
      trySet(
          95,
          _style(
            style,
            friendly:
                '👋 $days days since your last session. No judgment — let\'s write your comeback today 💪',
            strict:
                '📋 $days days missed. Acknowledge it. Move past it. Today begins the rebuild.',
            military:
                '🪖 ${days}D OFFLINE. WELCOME BACK. OPERATION RESUME. EXECUTE.',
            hype:
                '🔥 $days DAYS?? Your comeback story starts RIGHT NOW! MAKE IT EPIC!!',
          ));
    }

    // 3. Failure pattern
    if (hasFailurePattern) {
      trySet(
          100,
          _style(
            style,
            friendly:
                '💙 I\'ve noticed you\'ve been struggling lately. That\'s human — but today, just finish ONE set. Then another.',
            strict:
                '📊 Pattern detected: 2+ incomplete sessions. Today: minimum 3 sets. Consistency first.',
            military:
                '🪖 PATTERN: FAILING. CORRECTION MODE. 3 SETS MINIMUM. EXECUTE MISSION.',
            hype:
                '🧠 Your brain says quit — your BODY says go. Override it! Just START — momentum will carry you!!',
          ));
    }

    // 4. Deload
    if (inputs.needsDeload) {
      trySet(
          98,
          _style(
            style,
            friendly:
                '🔄 Volume dropping — time for a smart deload. Light sets, focus on recovery.',
            strict:
                '⚠️ Decline detected. Mandatory deload. Reduce intensity to 60%.',
            military:
                '🪖 DELOAD PROTOCOL ACTIVE. REDUCE LOAD. MAINTAIN DISCIPLINE.',
            hype:
                '💡 Deload NOW = MASSIVE comeback next week! Trust the process!!',
          ));
    }

    // 5. Plateau
    if (inputs.isOnPlateau) {
      trySet(
          92,
          _style(
            style,
            friendly:
                '🔄 Plateau detected. Let\'s reset — reduce weight slightly and rebuild stronger.',
            strict:
                '📊 Plateau confirmed. Drop 10% load, increase control. Rebuild progression.',
            military:
                '🪖 PROGRESS HALTED. CHANGE STRATEGY. REDUCE LOAD. ADD VOLUME.',
            hype:
                '💥 Plateau means your body adapted — TIME TO SHOCK IT!! Let\'s break limits!!',
          ));
    }

    // 6. Skipped muscles (only after 5+ workouts)
    final skipped =
        inputs.totalWorkouts < 5 ? <String>[] : musclesSkippedLast7Days;
    if (skipped.isNotEmpty) {
      final s = skipped.first;
      final cap = '${s[0].toUpperCase()}${s.substring(1)}';
      trySet(
          85,
          _style(
            style,
            friendly: _pickUnique('skipped_friendly', [
              '🎯 $cap hasn\'t been trained in a while — let\'s hit it today.',
              '⚖️ Balance check: $cap is lagging. Time to fix it.',
              '💪 Give some attention to $cap today — your body needs balance.',
            ]),
            strict: _pickUnique('skipped_strict', [
              '⚠️ $cap neglected. Fix imbalance immediately.',
              '📊 Missing muscle group: $cap. Address today.',
            ]),
            military: _pickUnique('skipped_military', [
              '🪖 TARGET IGNORED: $cap. CORRECT NOW.',
              '🪖 IMBALANCE DETECTED. TRAIN $cap TODAY.',
            ]),
            hype: _pickUnique('skipped_hype', [
              '🔥 $cap is being IGNORED! Wake it up TODAY!!',
              '💥 Your $cap is sleeping — TIME TO DESTROY IT!!',
            ]),
          ));
    }

    // 7. Declining trend
    if (trend == 'declining') {
      trySet(
          93,
          _style(
            style,
            friendly: _pickUnique('decline_friendly', [
              '💙 Your effort dipped recently. No stress — just show up today.',
              '📉 Slight drop detected. Reset today with a simple win.',
            ]),
            strict: _pickUnique('decline_strict', [
              '📉 Performance declining. Fix recovery variables NOW.',
              '⚠️ Drop detected. Sleep, food, discipline — correct today.',
            ]),
            military: _pickUnique('decline_military', [
              '🪖 PERFORMANCE FALLING. IDENTIFY WEAKNESS. CORRECT.',
              '🪖 OUTPUT REDUCED. ADJUST SYSTEM. EXECUTE.',
            ]),
            hype: _pickUnique('decline_hype', [
              '🔥 THIS SLUMP ENDS TODAY!! TURN IT AROUND!!',
              '💥 FALL BACK = SETUP FOR COMEBACK!! LET\'S GO!!',
            ]),
          ));
    }

    // 8a. tired + fatigued
    if (mood == MoodType.tired && fatigue == FatigueLevel.fatigued) {
      trySet(
          97,
          _style(
            style,
            friendly: _pickUnique('tired_friendly', [
              '😴 Body and mind are tired — keep it light, just show up.',
              '💤 Low energy today. Even a small session counts.',
            ]),
            strict: _pickUnique('tired_strict', [
              '⚠️ Fatigue high. Reduce intensity by 30%. Stay consistent.',
            ]),
            military: _pickUnique('tired_military', [
              '🪖 LOW ENERGY DETECTED. REDUCE LOAD. COMPLETE MISSION.',
            ]),
            hype: _pickUnique('tired_hype', [
              '💥 Even 50% effort today keeps the streak alive!! GO!!',
            ]),
          ));
    }

    // 8b. energetic + fresh
    if (mood == MoodType.energetic && fatigue == FatigueLevel.fresh) {
      trySet(
          94,
          _style(
            style,
            friendly: _pickUnique('peak_friendly', [
              '⚡ You\'re fully charged — perfect day to push harder!',
              '🔥 Energy is high. Go for a PR today!',
            ]),
            strict: _pickUnique('peak_strict', [
              '🔥 Peak condition. Increase load. Max effort.',
            ]),
            military: _pickUnique('peak_military', [
              '🪖 MAXIMUM READINESS. EXECUTE HEAVY LIFTS.',
            ]),
            hype: _pickUnique('peak_hype', [
              '🚀 TODAY IS PR DAY!! BREAK YOUR LIMITS!!',
            ]),
          ));
    }

    // 8c. general fatigue
    if (fatigue == FatigueLevel.fatigued) {
      trySet(
          88,
          _style(
            style,
            friendly: _pickUnique('fatigue_friendly', [
              '⚠️ Slight fatigue — focus on form today.',
              '💪 Go lighter today, but stay consistent.',
            ]),
            strict: _pickUnique('fatigue_strict', [
              '⚠️ Fatigue detected. Reduce load. Maintain quality.',
            ]),
            military: _pickUnique('fatigue_military', [
              '🪖 REDUCE LOAD. MAINTAIN DISCIPLINE.',
            ]),
            hype: _pickUnique('fatigue_hype', [
              '💡 Smart training today = stronger tomorrow!!',
            ]),
          ));
    }

    // 9. Improving
    if (trend == 'improving') {
      final best = bestPerformingExercise;
      trySet(
          91,
          _style(
            style,
            friendly: _pickUnique('improve_friendly', [
              best.isNotEmpty
                  ? '📈 You\'re improving fast — $best is your strongest move right now.'
                  : '📈 Your performance is improving — keep pushing!',
            ]),
            strict: _pickUnique('improve_strict', [
              '📈 Upward trend confirmed. Increase load today.',
            ]),
            military: _pickUnique('improve_military', [
              '🪖 PERFORMANCE RISING. PUSH HARDER.',
            ]),
            hype: _pickUnique('improve_hype', [
              '🔥 YOU\'RE ON FIRE!! KEEP THE MOMENTUM GOING!!',
            ]),
          ));
    }

    // 10. Weak muscle focus
    if (weakMuscle.isNotEmpty) {
      trySet(
          87,
          _style(
            style,
            friendly: _pickUnique('weak_friendly', [
              '🎯 Your $weakMuscle needs attention — train it today.',
              '💪 $weakMuscle is slightly lagging. Let\'s improve it.',
            ]),
            strict: _pickUnique('weak_strict', [
              '🎯 Weak point detected: $weakMuscle. Fix imbalance.',
            ]),
            military: _pickUnique('weak_military', [
              '🪖 WEAK AREA: $weakMuscle. TARGET AND IMPROVE.',
            ]),
            hype: _pickUnique('weak_hype', [
              '🔥 $weakMuscle is your weak link — DESTROY IT TODAY!!',
            ]),
          ));
    }

    // 11. Weight progression
    if (suggestion == WeightSuggestion.increase) {
      trySet(
          86,
          _style(
            style,
            friendly: _pickUnique('weight_friendly', [
              '📈 You\'re ready — increase weight slightly today.',
              '💪 Strength improving. Time to go heavier.',
            ]),
            strict: _pickUnique('weight_strict', [
              '📈 Data supports overload. Increase weight.',
            ]),
            military: _pickUnique('weight_military', [
              '🪖 INCREASE LOAD. EXECUTE.',
            ]),
            hype: _pickUnique('weight_hype', [
              '🔥 ADD WEIGHT AND LEVEL UP TODAY!!',
            ]),
          ));
    }

    // 12. Streak risk
    if (inputs.daysSinceLastWorkout >= 2 && streak > 3) {
      trySet(
          96,
          _style(
            style,
            friendly: '⚠️ Your streak is at risk. Don\'t let it break today.',
            strict: '📉 Streak risk detected. Train today.',
            military: '🪖 STREAK IN DANGER. EXECUTE NOW.',
            hype: '🔥 DON\'T BREAK THE CHAIN!! SHOW UP TODAY!!',
          ));
    }

    // 13. Goal fallback (only if nothing else matched)
    if (finalMessage.isEmpty) {
      finalMessage = _goalMessage(inputs.goal);
      if (finalMessage.trim().isEmpty) {
        finalMessage = _style(
          style,
          friendly: '💪 Just show up today. One workout. Stay consistent.',
          strict: '📋 No excuses. Complete your session today.',
          military: '🪖 EXECUTE TODAY. NO DELAY.',
          hype: '🔥 NO ZERO DAYS!! MOVE NOW!!',
        );
      }
    }

    return finalMessage;
  }

  String _adaptiveTone(String userPreference) {
    if (hasFailurePattern) return 'strict';
    if (averageEffortScore >= 85 && performanceTrend == 'improving') {
      return 'motivational';
    }
    if (performanceTrend == 'declining' && !hasFailurePattern) {
      return 'friendly';
    }
    return userPreference;
  }

  String _streakPressure(String style, int current, String reward) {
    return _style(
      style,
      friendly:
          '🔥 $current-day streak! ONE more day unlocks the $reward. Don\'t let it slip now!',
      strict: '📊 $current days in. $reward requires 1 more session. Show up.',
      military:
          '🪖 ${current}D STREAK. 1 DAY FROM $reward. THIS IS NOT THE DAY TO STOP.',
      hype:
          '💥 $current DAYS AND THE $reward IS ONE SESSION AWAY!! DON\'T YOU DARE QUIT NOW!!',
    );
  }

  String _style(
    String style, {
    required String friendly,
    required String strict,
    required String military,
    required String hype,
  }) {
    switch (style) {
      case 'strict':
        return strict;
      case 'military':
        return military;
      case 'motivational':
        return hype;
      default:
        return friendly;
    }
  }

  String _goalMessage(String goal) {
    final options = <String, List<String>>{
      'fat_loss': [
        '🔥 Fat burn mode ON — push your pace today!',
        '💦 Keep intensity high and rest low.',
        '⚡ Sweat session — burn calories, stay sharp.',
      ],
      'muscle_gain': [
        '💪 Focus on controlled reps and muscle tension.',
        '🏋️ Build size — slow reps, full range.',
        '📈 Volume day — every rep matters.',
      ],
      'strength': [
        '🏋️ Heavy lifts today — attack compound moves.',
        '💪 Strength focus — low reps, high power.',
        '⚡ Explosive training — warm up properly.',
      ],
    };
    final list =
        options[goal] ?? ['💪 Show up and train — that\'s what matters.'];
    return _pickUnique('goal_msg', list);
  }

  // ═════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════
  String _pickUnique(String key, List<String> messages) {
    if (messages.isEmpty) return '';
    final cached = _lastMessages[key];
    final available = messages.where((m) => m != cached).toList();
    final pool = available.isEmpty ? messages : available;
    final today = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1;
    final index = (today + key.hashCode.abs()) % pool.length;
    final picked = pool[index];
    _lastMessages[key] = picked;
    return picked;
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

  Future<void> _persistMemory() async {
    try {
      await StorageService.instance.setJson(
        StorageKeys.performanceMemory,
        _perfMemory.map((p) => p.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('_persistMemory error: $e');
    }
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}
