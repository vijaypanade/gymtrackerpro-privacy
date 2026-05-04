// lib/providers/analytics_provider.dart
//
// RESPONSIBILITY:
//   - Compute AnalyticsSnapshot (readiness, fatigue, plateau, intensity, etc.)
//   - Cache the snapshot daily and persist to storage
//   - Apply EMA smoothing so scores don't jump frame-to-frame
//   - Expose smoothed getters that the UI binds to
//
// DESIGN:
//   - This provider is PURE — it does NOT directly read other providers.
//     Instead callers feed it inputs via `recompute(...)`.
//   - That keeps it testable and avoids tight coupling.
//
//   - Workflow:
//       WorkoutProvider logs change      → calls analytics.recompute(...)
//       UserProvider mood/water change   → calls analytics.recompute(...)
//       AppProvider orchestrator wires the dependencies together
//
//   - Premium gating is NOT done here. AnalyticsProvider always returns the
//     full numbers; UI / AppProvider can mask them based on isPremium.
//     (Old code mixed this in — we cleanly separate it.)

import 'package:flutter/foundation.dart';

import '../engines/analytics_engine.dart';
import '../models/models.dart';
import '../models/workout_log.dart';
import '../services/storage_service.dart';
import '../utils/id_helper.dart';

// ═══════════════════════════════════════════════════════════════
// ANALYTICS SNAPSHOT — cached, recomputed once per day or on invalidation
// ═══════════════════════════════════════════════════════════════
class AnalyticsSnapshot {
  final double readinessScore;       // 0–100
  final double fatigueIndex;         // 0–100
  final double effortScoreToday;     // 0–100
  final double plateauScore;         // 0–100
  final double overtTrainingRisk;    // 0–100
  final double weeklyImprovementPct;
  final double muscleBalanceScore;   // 0–100 (higher = more balanced)
  final double intensityScore;       // 0–100
  final String recoveryTrend;        // 'improving' | 'stable' | 'declining'
  final bool   isOnPlateau;
  final String cacheDate;

  const AnalyticsSnapshot({
    required this.readinessScore,
    required this.fatigueIndex,
    required this.effortScoreToday,
    required this.plateauScore,
    required this.overtTrainingRisk,
    required this.weeklyImprovementPct,
    required this.muscleBalanceScore,
    required this.intensityScore,
    required this.recoveryTrend,
    required this.isOnPlateau,
    required this.cacheDate,
  });

  Map<String, dynamic> toJson() => {
        'readinessScore':       readinessScore,
        'fatigueIndex':         fatigueIndex,
        'effortScoreToday':     effortScoreToday,
        'plateauScore':         plateauScore,
        'overtTrainingRisk':    overtTrainingRisk,
        'weeklyImprovementPct': weeklyImprovementPct,
        'muscleBalanceScore':   muscleBalanceScore,
        'intensityScore':       intensityScore,
        'recoveryTrend':        recoveryTrend,
        'isOnPlateau':          isOnPlateau,
        'cacheDate':            cacheDate,
      };

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> j) =>
      AnalyticsSnapshot(
        readinessScore:       (j['readinessScore']       as num?)?.toDouble() ?? 70,
        fatigueIndex:         (j['fatigueIndex']         as num?)?.toDouble() ?? 30,
        effortScoreToday:     (j['effortScoreToday']     as num?)?.toDouble() ?? 50,
        plateauScore:         (j['plateauScore']         as num?)?.toDouble() ?? 0,
        overtTrainingRisk:    (j['overtTrainingRisk']    as num?)?.toDouble() ?? 0,
        weeklyImprovementPct: (j['weeklyImprovementPct'] as num?)?.toDouble() ?? 0,
        muscleBalanceScore:   (j['muscleBalanceScore']   as num?)?.toDouble() ?? 70,
        intensityScore:       (j['intensityScore']       as num?)?.toDouble() ?? 60,
        recoveryTrend:         j['recoveryTrend']         as String? ?? 'stable',
        isOnPlateau:           j['isOnPlateau']           as bool?   ?? false,
        cacheDate:             j['cacheDate']             as String? ?? '',
      );

  static const empty = AnalyticsSnapshot(
    readinessScore: 72, fatigueIndex: 28, effortScoreToday: 55,
    plateauScore: 0, overtTrainingRisk: 0, weeklyImprovementPct: 0,
    muscleBalanceScore: 74, intensityScore: 60,
    recoveryTrend: 'stable', isOnPlateau: false, cacheDate: '',
  );
}

// ═══════════════════════════════════════════════════════════════
// ANALYTICS INPUTS — what the provider needs to compute a snapshot.
// Constructed by AppProvider/WorkoutProvider before calling recompute().
// ═══════════════════════════════════════════════════════════════
class AnalyticsInputs {
  final List<WorkoutLog> logs;
  final MoodType         mood;
  final int              streak;
  final int              overallRecoveryScore;     // from muscle recovery
  final bool             needsDeload;
  final DayPlan?         today;                    // for effort score
  final Map<String, DateTime> lastMuscleTrained;   // for balance

  const AnalyticsInputs({
    required this.logs,
    required this.mood,
    required this.streak,
    required this.overallRecoveryScore,
    required this.needsDeload,
    required this.today,
    required this.lastMuscleTrained,
  });
}

// ═══════════════════════════════════════════════════════════════
// ANALYTICS PROVIDER
// ═══════════════════════════════════════════════════════════════
class AnalyticsProvider extends ChangeNotifier {
  AnalyticsSnapshot _snapshot = AnalyticsSnapshot.empty;
  bool _loaded = false;

  // EMA smoothing — prevents jumpy numbers (Apple Watch style)
  double? _smoothedReadiness;
  double? _smoothedFatigue;
  double? _smoothedIntensity;
  static const double _emaAlpha = 0.3; // lower = smoother

  bool get isLoaded => _loaded;
  AnalyticsSnapshot get snapshot => _snapshot;

  // ── Smoothed public getters (what the UI should bind to) ──
  double get readinessScore {
    _smoothedReadiness =
        _applyEMA(_smoothedReadiness, _snapshot.readinessScore);
    return _smoothedReadiness!;
  }

  double get fatigueIndex {
    _smoothedFatigue = _applyEMA(_smoothedFatigue, _snapshot.fatigueIndex);
    return _smoothedFatigue!;
  }

  double get intensityScore {
    _smoothedIntensity =
        _applyEMA(_smoothedIntensity, _snapshot.intensityScore);
    return _smoothedIntensity!;
  }

  // ── Direct passthroughs ──
  double get effortScoreToday     => _snapshot.effortScoreToday;
  double get plateauScore         => _snapshot.plateauScore;
  double get overTrainingRisk     => _snapshot.overtTrainingRisk;
  double get weeklyImprovementPct => _snapshot.weeklyImprovementPct;
  double get muscleBalanceScore   => _snapshot.muscleBalanceScore;
  String get recoveryTrend        => _snapshot.recoveryTrend;
  bool   get isOnPlateau          => _snapshot.isOnPlateau;

  // ── Human-readable summaries ──
  String get weeklyMessage {
    final p = weeklyImprovementPct;
    if (p > 15)   return '🚀 Elite progress!';
    if (p > 10)   return '🔥 Strong progress this week!';
    if (p > 0)    return "📈 You're improving steadily";
    if (p < -15)  return '🛑 Overtraining risk!';
    if (p < -10)  return '⚠️ Recovery needed';
    return 'Maintain consistency 💪';
  }

  String muscleImbalanceMessage(List<WorkoutLog> logs) =>
      AnalyticsEngine.getMuscleImbalance(logs);

  // ═════════════════════════════════════════════════════════
  // LOAD CACHED SNAPSHOT
  // ═════════════════════════════════════════════════════════
  Future<void> load() async {
    if (_loaded) return;
    try {
      final cached = await StorageService.instance.loadObject<AnalyticsSnapshot>(
        StorageKeys.analyticsCache,
        AnalyticsSnapshot.fromJson,
      );
      // Only use cache if it's from today
      if (cached != null && cached.cacheDate == _todayStr) {
        _snapshot = cached;
      }
    } catch (e) {
      debugPrint('AnalyticsProvider.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════════
  // RECOMPUTE — called whenever inputs change (log added,
  // mood updated, day completed, etc.)
  // ═════════════════════════════════════════════════════════
  Future<void> recompute(AnalyticsInputs inputs) async {
    _snapshot = _compute(inputs);
    notifyListeners();
    await _persistSnapshot();
  }

  /// Force-clear all caches AND smoothed values (e.g. on user reset).
  void invalidateAll() {
    _snapshot          = AnalyticsSnapshot.empty;
    _smoothedReadiness = null;
    _smoothedFatigue   = null;
    _smoothedIntensity = null;
    notifyListeners();
  }

  /// Soft invalidate — clears the cached snapshot only, EMA stays.
  /// Triggers a recompute on next `recompute(...)` call.
  void invalidateCache() {
    _snapshot = AnalyticsSnapshot.empty.copyWithCacheDate('');
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════
  // COMPUTATION
  // ═════════════════════════════════════════════════════════
  AnalyticsSnapshot _compute(AnalyticsInputs inputs) {
    final variance = IdHelper.jitter(3); // ±3 — never static numbers

    final fatigue = AnalyticsEngine.computeFatigueIndex(
      logs:   inputs.logs,
      mood:   inputs.mood,
      streak: inputs.streak,
    );

    final readiness = AnalyticsEngine.computeReadiness(
      recovery:    inputs.overallRecoveryScore.toDouble(),
      fatigue:     fatigue,
      streak:      inputs.streak,
      mood:        inputs.mood.name,
      needsDeload: inputs.needsDeload,
    );

    final plateau = AnalyticsEngine.computePlateauScore(logs: inputs.logs);

    final overtraining = _computeOvertrainingRisk(
      logs: inputs.logs,
      streak: inputs.streak,
      fatigueIndex: fatigue,
      needsDeload: inputs.needsDeload,
      overallRecovery: inputs.overallRecoveryScore,
    );

    final weeklyImp =
        AnalyticsEngine.computeWeeklyImprovement(logs: inputs.logs);

    final balance = _computeMuscleBalance(inputs.logs);
    final intensity = _computeIntensityScore(inputs.logs);
    final effort = _computeEffortScore(inputs.today, inputs.mood);
    final trend = _computeRecoveryTrend(inputs.logs);

    return AnalyticsSnapshot(
      readinessScore:       (readiness    + variance).clamp(0, 100),
      fatigueIndex:         (fatigue      - variance).clamp(0, 100),
      effortScoreToday:     (effort       + variance).clamp(0, 100),
      plateauScore:         (plateau      + variance).clamp(0, 100),
      overtTrainingRisk:    (overtraining - variance).clamp(0, 100),
      weeklyImprovementPct: weeklyImp,
      muscleBalanceScore:   (balance      + variance).clamp(0, 100),
      intensityScore:       (intensity    + variance).clamp(0, 100),
      recoveryTrend:        trend,
      isOnPlateau:          plateau >= 60,
      cacheDate:            _todayStr,
    );
  }

  // ── Effort score: today's plan completion rate ──
  double _computeEffortScore(DayPlan? today, MoodType mood) {
    if (today == null || today.exercises.isEmpty) return 50;

    int planned   = 0;
    int completed = 0;
    for (final ex in today.exercises) {
      planned   += ex.sets.length;
      completed += ex.sets.where((s) => s.done).length;
    }
    if (planned == 0) return 50;

    final base = (completed / planned * 100).clamp(0, 100).toDouble();
    // Extra credit for showing up tired
    if (mood == MoodType.tired && base > 60) {
      return (base + 10).clamp(0, 100);
    }
    return base;
  }

  // ── Overtraining risk score ──
  double _computeOvertrainingRisk({
    required List<WorkoutLog> logs,
    required int streak,
    required double fatigueIndex,
    required bool needsDeload,
    required int overallRecovery,
  }) {
    double risk = 0;

    if (streak >= 7)  risk += 20;
    if (streak >= 14) risk += 25;
    if (streak >= 21) risk += 30;

    risk += fatigueIndex * 0.4;

    if (needsDeload) risk += 30;

    if (overallRecovery < 40)      risk += 25;
    else if (overallRecovery < 60) risk += 10;

    return risk.clamp(0, 95);
  }

  // ── Muscle balance: coefficient of variation across muscle groups ──
  double _computeMuscleBalance(List<WorkoutLog> logs) {
    const muscles = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
    final freq = <String, int>{};

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = logs.where((l) => l.date.isAfter(cutoff)).toList();

    for (final log in recent) {
      final m = _normalizeMuscle(
        log.muscleGroup ?? log.exercise.split('_').first,
      );
      if (m.isNotEmpty) freq[m] = (freq[m] ?? 0) + 1;
    }

    if (freq.isEmpty) return 74;

    final counts = muscles.map((m) => (freq[m] ?? 0).toDouble()).toList();
    final mean = counts.reduce((a, b) => a + b) / counts.length;
    if (mean == 0) return 74;

    final variance =
        counts.map((c) => (c - mean) * (c - mean)).reduce((a, b) => a + b) /
            counts.length;
    final cv = (variance > 0 ? variance : 0).toDouble();
    final stdDev = cv > 0 ? _sqrt(cv) : 0.0;
    final coeffVar = (stdDev / mean).clamp(0, 1);

    return ((1 - coeffVar) * 100).clamp(20, 97).toDouble();
  }

  // ── Intensity: avg volume of last 5 sessions normalized to baseline ──
  double _computeIntensityScore(List<WorkoutLog> logs) {
    if (logs.isEmpty) return 50;
    final recent = logs.reversed.take(5).toList();
    final avgVol = recent
            .map((l) => l.weight * l.reps)
            .reduce((a, b) => a + b) /
        recent.length;
    const baseline = 500.0; // kg·reps
    return ((avgVol / baseline) * 80).clamp(20, 95);
  }

  // ── Recovery trend: this 7d vs prev 7d volume ──
  String _computeRecoveryTrend(List<WorkoutLog> logs) {
    final now = DateTime.now();
    final this7 = logs
        .where((l) => now.difference(l.date).inDays < 7)
        .fold(0.0, (s, l) => s + l.weight * l.reps);
    final prev7 = logs.where((l) {
      final d = now.difference(l.date).inDays;
      return d >= 7 && d < 14;
    }).fold(0.0, (s, l) => s + l.weight * l.reps);

    if (prev7 == 0) return 'stable';
    final change = (this7 - prev7) / prev7;
    if (change >  0.05) return 'improving';
    if (change < -0.05) return 'declining';
    return 'stable';
  }

  // ═════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════
  double _applyEMA(double? previous, double newValue) {
    if (previous == null) return newValue;
    return ((_emaAlpha * newValue) + ((1 - _emaAlpha) * previous))
        .clamp(0, 100);
  }

  String _normalizeMuscle(String muscle) {
    final m = muscle.toLowerCase();
    if (m.contains('shoulder')) return 'shoulders';
    if (m.contains('leg') || m.contains('glute') ||
        m.contains('hamstring') || m.contains('calf') ||
        m.contains('quad')) return 'legs';
    if (m.contains('chest') || m.contains('pec')) return 'chest';
    if (m.contains('back') || m.contains('lat') ||
        m.contains('row') || m.contains('deadlift')) return 'back';
    if (m.contains('arm') || m.contains('bicep') ||
        m.contains('tricep') || m.contains('curl')) return 'arms';
    if (m.contains('core') || m.contains('ab') ||
        m.contains('plank') || m.contains('crunch')) return 'core';
    return m.trim();
  }

  // Inline sqrt — avoids importing dart:math just for this one call
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 16; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  Future<void> _persistSnapshot() async {
    await StorageService.instance.setJson(
      StorageKeys.analyticsCache,
      _snapshot.toJson(),
    );
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
           '${n.day.toString().padLeft(2, '0')}';
  }
}

// Tiny extension to clone snapshot with a different cacheDate (used for
// soft cache invalidation without losing other fields).
extension _SnapshotCacheReset on AnalyticsSnapshot {
  AnalyticsSnapshot copyWithCacheDate(String date) => AnalyticsSnapshot(
        readinessScore:       readinessScore,
        fatigueIndex:         fatigueIndex,
        effortScoreToday:     effortScoreToday,
        plateauScore:         plateauScore,
        overtTrainingRisk:    overtTrainingRisk,
        weeklyImprovementPct: weeklyImprovementPct,
        muscleBalanceScore:   muscleBalanceScore,
        intensityScore:       intensityScore,
        recoveryTrend:        recoveryTrend,
        isOnPlateau:          isOnPlateau,
        cacheDate:            date,
      );
}
