// lib/engines/recovery_engine.dart
// Single authoritative recovery computation for LiftOn.
// No Provider, no I/O.
// Inputs: training timestamps + weekly volume + age + streak + subjective readiness.
// Output: RecoveryState (the only recovery truth the app should consume).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../brain/policy/mission_selection_engine.dart' show MissionType;
import '../models/recovery_state.dart';
import '../utils/app_constants.dart';

// ── Recovery target hours by muscle ───────────────────────────────────────────
// Based on: Schoenfeld 2010 SRA curve, Kraemer & Ratamess 2004 NSCA position stand.
// Large compound muscles (legs/back) need 72 h; small isolation muscles 24–36 h.
const Map<String, double> _kTargetHours = {
  'chest':     48,
  'back':      72,
  'legs':      72,
  'shoulders': 48,
  'biceps':    36,
  'triceps':   36,
  'core':      24,
  'calves':    36,
  'arms':      36,
  'cardio':    24,
};

// ── Weekly volume thresholds (kg) above which fatigue accumulates ─────────────
// Typical serious lifter weekly volume: legs 10–18k, back 8–14k, chest 6–12k.
// Exceeding these signals overreaching territory.
const Map<String, double> _kVolumeThreshold = {
  'legs':      16000,
  'back':      14000,
  'chest':     12000,
  'shoulders': 10000,
  'biceps':     6000,
  'triceps':    6000,
  'calves':     5000,
  'arms':       5000,
  'core':       4000,
};

// ── Muscle weight for overall score computation ────────────────────────────────
// Compound muscles (legs/back) suppress overall more than accessories.
const Map<String, double> _kMuscleWeight = {
  'legs':      1.4,
  'back':      1.3,
  'chest':     1.1,
  'shoulders': 1.0,
  'biceps':    0.7,
  'triceps':   0.7,
  'calves':    0.7,
  'arms':      0.7,
  'core':      0.7,
  'cardio':    0.5,
};

// ── Major muscles — used for highFatigue detection ────────────────────────────
const List<String> _kMajorMuscles = ['chest', 'back', 'legs', 'shoulders'];

// ── Score bounds ──────────────────────────────────────────────────────────────
// Floor/ceiling prevent impossible results (0% or 100% recovery is never true).
const double _kMuscleScoreFloor  = 8.0;
const double _kOverallScoreFloor = 12.0;
const double _kOverallScoreCeil  = 98.0;
const double _kVolumePenaltyCap  = 22.0;

// ── Input model ───────────────────────────────────────────────────────────────

class RecoveryEngineInput {
  final Map<String, DateTime> lastMuscleTrained;   // normalized lowercase keys
  final Map<String, double>   weeklyMuscleVolume;  // kg, same keys
  final int    age;
  final int    streak;
  final double weeklyVolumeTotal;      // kg across all muscles this week
  final double previousWeeklyVolume;   // kg last week (0 if unknown)
  final int    readiness;              // 0 = not set today; 1–5 subjective
  final DateTime now;

  // Health signals — all optional (null = no data → no influence on score)
  final double? sleepHours;       // last night's sleep, hours
  final int?    todayStepCount;   // total steps today
  final double? restingHeartRate; // bpm, most recent overnight reading
  final double? hrv;              // SDNN ms, overnight average
  final double? hrvBaseline;      // EMA baseline from SharedPrefs (null = not yet established)

  // Nutrition signal — today's protein intake as % of goal.
  // Null = no data → no influence. One lightweight modifier among many;
  // never allowed to dominate the training-derived score.
  final double? proteinAdherencePct;

  const RecoveryEngineInput({
    required this.lastMuscleTrained,
    required this.weeklyMuscleVolume,
    required this.age,
    required this.streak,
    required this.weeklyVolumeTotal,
    required this.previousWeeklyVolume,
    required this.readiness,
    required this.now,
    this.sleepHours,
    this.todayStepCount,
    this.restingHeartRate,
    this.hrv,
    this.hrvBaseline,
    this.proteinAdherencePct,
  });
}

// ── HRV readiness classification ─────────────────────────────────────────────
// Single source of truth for HRV state used by both the engine modifier and
// any UI that needs a semantic HRV label. Thresholds mirror _hrvModifier so
// the classification and the score adjustment are always in sync.

enum HrvReadiness { elevated, normal, suppressed, unavailable }

// ── Recovery presentation ─────────────────────────────────────────────────────
// Derives the semantic label + chip colour for any UI surface.
// Mission intent overrides score when the AI has explicitly decided to protect
// recovery — a high numeric score does not mean "Ready" in that case.

@immutable
class RecoveryPresentation {
  final String label;
  final Color  chipColor;
  const RecoveryPresentation({required this.label, required this.chipColor});
}

// ── Engine ────────────────────────────────────────────────────────────────────

class RecoveryEngine {
  RecoveryEngine._();

  /// Semantic label + chip colour for the readiness state visible on home chips.
  /// Mission intent (protectRecovery / recoverySession) overrides a high score;
  /// all other states derive from [overallScore] thresholds.
  static RecoveryPresentation readinessPresentation(
      int overallScore, MissionType mission, bool isRestDay) {
    if (isRestDay) {
      return const RecoveryPresentation(label: 'Rest', chipColor: AppColors.blue);
    }
    if (mission == MissionType.protectRecovery ||
        mission == MissionType.recoverySession) {
      return const RecoveryPresentation(label: 'Recovering', chipColor: AppColors.orange);
    }
    if (overallScore >= 70) {
      return const RecoveryPresentation(label: 'Ready', chipColor: AppColors.green);
    }
    if (overallScore >= 50) {
      return const RecoveryPresentation(label: 'Adapting', chipColor: AppColors.goldSoft);
    }
    return const RecoveryPresentation(label: 'Recovering', chipColor: AppColors.orange);
  }

  /// Classifies HRV relative to the athlete's personal baseline.
  /// Uses % deviation when baseline is available; falls back to static
  /// population bands for the first few days before baseline is established.
  static HrvReadiness hrvReadiness(double? hrv, double? baseline) {
    if (hrv == null || hrv <= 0) return HrvReadiness.unavailable;
    if (baseline != null && baseline > 0) {
      final pct = (hrv - baseline) / baseline;
      if (pct >=  0.05) return HrvReadiness.elevated;
      if (pct >= -0.05) return HrvReadiness.normal;
      return HrvReadiness.suppressed;
    }
    // Fallback: population bands — same order as _hrvModifier's static path.
    if (hrv >= 50) return HrvReadiness.elevated;
    if (hrv >= 30) return HrvReadiness.normal;
    return HrvReadiness.suppressed;
  }

  /// Compute a fresh [RecoveryState] from the provided inputs.
  /// Cheap enough to call on every provider rebuild — no I/O, no async.
  static RecoveryState compute(RecoveryEngineInput input) {
    // Step 1 — Per-muscle base recovery from elapsed time since last training.
    final muscleScores = _computeMuscleBases(input);

    // Step 2 — Penalise muscles with high weekly volume (overreaching signal).
    _applyVolumePenalties(muscleScores, input.weeklyMuscleVolume);

    // Clamp each muscle to its floor after step 2.
    for (final key in muscleScores.keys.toList()) {
      muscleScores[key] = muscleScores[key]!.clamp(_kMuscleScoreFloor, 100.0);
    }

    // Step 3 — Weighted overall score from muscle scores.
    // Age, streak, and readiness modifiers apply to overall (not per-muscle)
    // because they reflect systemic / CNS state, not local tissue recovery.
    double overall = _weightedOverall(muscleScores);
    overall -= _agePenalty(input.age);
    overall -= _streakPenalty(input.streak, input.readiness);
    overall += _readinessDelta(input.readiness);
    // Health modifiers — small contextual nudges, never override training signal.
    overall += _hrvModifier(input.hrv, input.hrvBaseline);
    overall += _sleepModifier(input.sleepHours);
    overall += _rhrModifier(input.restingHeartRate);
    overall += _stepsModifier(input.todayStepCount, overall);
    overall += _proteinModifier(input.proteinAdherencePct);
    final overallClamped = _clampScore(overall, _kOverallScoreFloor, _kOverallScoreCeil);

    // Step 4 — Derived signals.
    final primaryLimiting = _primaryLimitingMuscle(muscleScores);
    final needsDeload     = _computeNeedsDeload(
      overallClamped, input.weeklyVolumeTotal, input.previousWeeklyVolume,
    );
    final highFatigue     = _computeHighFatigue(muscleScores);
    final strainToday     = _computeStrainToday(input);
    final strain7d        = _computeStrain7d(overallClamped, input.weeklyVolumeTotal);

    return RecoveryState(
      overallScore:          overallClamped,
      muscleScores:          Map.unmodifiable(
        muscleScores.map((k, v) => MapEntry(k, v.clamp(0.0, 100.0))),
      ),
      readiness:             RecoveryReadinessX.fromScore(overallClamped),
      primaryLimitingMuscle: primaryLimiting,
      strainToday:           strainToday,
      strain7d:              strain7d,
      needsDeload:           needsDeload,
      highFatigue:           highFatigue,
      updatedAt:             input.now,
    );
  }

  // ── Step 1: Per-muscle base from elapsed hours ────────────────────────────

  static Map<String, double> _computeMuscleBases(RecoveryEngineInput input) {
    final scores = <String, double>{};
    for (final entry in _kTargetHours.entries) {
      final muscle = entry.key;
      final last   = input.lastMuscleTrained[muscle];
      if (last == null) {
        // Never trained this muscle — treat as fully recovered.
        scores[muscle] = 100.0;
        continue;
      }
      final elapsedHours = input.now.difference(last).inMinutes / 60.0;
      final target       = entry.value;
      scores[muscle] = _clampScore(
        (elapsedHours / target) * 100.0,
        _kMuscleScoreFloor,
        100.0,
      );
    }
    return scores;
  }

  // ── Step 2: Volume fatigue penalties ─────────────────────────────────────

  static void _applyVolumePenalties(
    Map<String, double> scores,
    Map<String, double> weeklyVolume,
  ) {
    for (final entry in _kVolumeThreshold.entries) {
      final muscle    = entry.key;
      final threshold = entry.value;
      final volume    = weeklyVolume[muscle] ?? 0.0;
      if (volume <= threshold) continue;

      // Penalty scales with how far over threshold, capped to prevent absurdity.
      final excess  = volume - threshold;
      final penalty = _clampScore(excess / threshold * 35.0, 0.0, _kVolumePenaltyCap);
      if (scores.containsKey(muscle)) {
        scores[muscle] = scores[muscle]! - penalty;
      }
    }
  }

  // ── Step 3 helpers ────────────────────────────────────────────────────────

  // Weighted mean: legs/back suppress overall harder than accessory muscles.
  static double _weightedOverall(Map<String, double> scores) {
    if (scores.isEmpty) return 75.0;
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    for (final entry in scores.entries) {
      final weight = _kMuscleWeight[entry.key] ?? 0.8;
      weightedSum += entry.value * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? weightedSum / totalWeight : 75.0;
  }

  // Age increases recovery time — applied to overall score as a flat penalty.
  static double _agePenalty(int age) {
    if (age >= 41) return 12.0;
    if (age >= 36) return  7.0;
    if (age >= 30) return  3.0;
    return 0.0;
  }

  // High streak → CNS fatigue accumulates; partially offset by high readiness.
  static double _streakPenalty(int streak, int readiness) {
    if (streak < 10) return 0.0;
    final raw     = _clampScore(streak * 0.6, 0.0, 10.0);
    // Readiness ≥ 4 indicates the athlete is adapting well — reduce penalty.
    final penalty = readiness >= 4 ? raw * 0.6 : raw;
    return penalty;
  }

  // Subjective readiness shifts overall: poor feel → meaningful suppression.
  static double _readinessDelta(int readiness) {
    switch (readiness) {
      case 1:  return -18.0;
      case 2:  return -10.0;
      case 3:  return   0.0;
      case 4:  return   5.0;
      case 5:  return   9.0;
      default: return   0.0; // 0 = not submitted today
    }
  }

  // ── Step 4 helpers ────────────────────────────────────────────────────────

  // Lowest-scoring muscle, but only report it if it's genuinely suppressed.
  static String _primaryLimitingMuscle(Map<String, double> scores) {
    if (scores.isEmpty) return '';
    final sorted = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first.value < 65.0 ? sorted.first.key : '';
  }

  // Deload flag: sustained volume spike combined with suppressed recovery.
  static bool _computeNeedsDeload(
    double overallScore,
    double weeklyVolumeTotal,
    double previousWeeklyVolume,
  ) {
    if (previousWeeklyVolume <= 0) return false;
    return weeklyVolumeTotal > previousWeeklyVolume * 1.30 && overallScore < 55.0;
  }

  // High fatigue: 2+ major compound muscles below the suppression threshold.
  static bool _computeHighFatigue(Map<String, double> scores) {
    int suppressed = 0;
    for (final muscle in _kMajorMuscles) {
      final score = scores[muscle];
      if (score != null && score < 40.0) suppressed++;
    }
    return suppressed >= 2;
  }

  // Strain today: proxy from number of muscles trained within the last 20 hours
  // and their relative volume loads. Upgraded to log-based inputs in Phase 6C.
  static double _computeStrainToday(RecoveryEngineInput input) {
    final recentMuscles = <String>[];
    for (final entry in input.lastMuscleTrained.entries) {
      final elapsed = input.now.difference(entry.value).inMinutes / 60.0;
      if (elapsed <= 20.0) recentMuscles.add(entry.key);
    }
    if (recentMuscles.isEmpty) return 0.0;

    double strain = recentMuscles.length * 12.0;
    for (final m in recentMuscles) {
      final vol       = input.weeklyMuscleVolume[m] ?? 0.0;
      final threshold = _kVolumeThreshold[m] ?? 8000.0;
      strain += _clampScore(vol / threshold * 20.0, 0.0, 20.0);
    }
    return _clampScore(strain, 0.0, 100.0);
  }

  // Rolling 7-day strain: proxy from volume magnitude and recovery suppression.
  // Normalises against a realistic weekly ceiling (~25,000 kg total).
  static double _computeStrain7d(double overallScore, double weeklyVolumeTotal) {
    const realisticWeeklyCeiling = 25000.0;
    final volumeFactor    = _clampScore(weeklyVolumeTotal / realisticWeeklyCeiling, 0.0, 1.0);
    final recoveryInverse = 1.0 - (overallScore / 100.0);
    return _clampScore(volumeFactor * 60.0 + recoveryInverse * 40.0, 0.0, 100.0);
  }

  // ── Health Connect modifiers (small, bounded) ─────────────────────────────

  // HRV modifier — deviation from personal EMA baseline (RFC-002.8).
  // HRV is the strongest single biometric recovery signal (max influence: -12 to +5).
  // Uses % deviation so the modifier is personal, not population-average thresholds.
  // When no baseline exists (first days of use), falls back to broad static bands.
  static double _hrvModifier(double? hrv, double? baseline) {
    if (hrv == null || hrv <= 0) return 0.0;
    if (baseline != null && baseline > 0) {
      final pct = (hrv - baseline) / baseline;
      if (pct >=  0.15) return  5.0;
      if (pct >=  0.05) return  2.0;
      if (pct >= -0.05) return  0.0;
      if (pct >= -0.15) return -5.0;
      if (pct >= -0.25) return -8.0;
      return -12.0;
    }
    // Fallback: static population bands — used only until baseline is established.
    if (hrv >= 70) return  3.0;
    if (hrv >= 50) return  1.0;
    if (hrv >= 30) return  0.0;
    if (hrv >= 20) return -3.0;
    return -6.0;
  }

  // Resting heart rate modifier using conservative static thresholds.
  // Personal baseline calibration comes in RFC-002.8 with HRV.
  // Max influence: -8 to +2 points. Null = no reading = no effect.
  //   ≤ 55 bpm  → +2   (athlete-level cardiovascular fitness)
  //   56–70 bpm →  0   (normal resting range — no influence)
  //   71–80 bpm → −4   (mildly elevated — fatigue or stress signal)
  //   > 80 bpm  → −8   (significantly elevated — strong recovery suppressor)
  static double _rhrModifier(double? rhr) {
    if (rhr == null || rhr <= 0) return 0.0;
    if (rhr <= 55) return  2.0;
    if (rhr <= 70) return  0.0;
    if (rhr <= 80) return -4.0;
    return -8.0;
  }

  // Sleep below 7h nudges overall down; 8h+ gives a small boost.
  // Max influence: -8 to +3 points. Null = no data = no effect.
  static double _sleepModifier(double? sleepHours) {
    if (sleepHours == null || sleepHours <= 0) return 0.0;
    if (sleepHours < 5.0) return -8.0;
    if (sleepHours < 6.0) return -4.0;
    if (sleepHours < 7.0) return -2.0;
    if (sleepHours >= 8.0) return  3.0;
    return 0.0;
  }

  // Protein adherence nudges overall recovery by at most ±3 points.
  // Bounds are deliberately tight — protein explains a likely limiter,
  // it never punishes. Null = no data = no effect.
  //   ≥95%  → +2   (small positive contribution)
  //   80–94 →  0   (neutral)
  //   60–79 → -2   (small negative contribution)
  //   <60   → -3   (limiter — UI shows one explanatory insight)
  static double _proteinModifier(double? adherencePct) {
    if (adherencePct == null) return 0.0;
    if (adherencePct >= 95.0) return  2.0;
    if (adherencePct >= 80.0) return  0.0;
    if (adherencePct >= 60.0) return -2.0;
    return -3.0;
  }

  // Very high step count under already-suppressed recovery adds modest pressure.
  // Max influence: -4 points. Null = no data = no effect.
  static double _stepsModifier(int? steps, double currentOverall) {
    if (steps == null || steps <= 0) return 0.0;
    if (steps > 15000 && currentOverall < 55) return -4.0;
    if (steps > 15000) return -2.0;
    return 0.0;
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static double _clampScore(double value, double min, double max) =>
      value.clamp(min, max);

  // ── Public: muscle-specific recovery ETA ─────────────────────────────────
  //
  // Inverts the base formula (score = elapsed / target × 100) using the
  // post-penalty muscle score so volume overreach extends the ETA correctly.
  //   remaining = target × (1 − score / 100)
  //
  // Returns 0 when the muscle is unknown or already fully recovered.
  // Callers must treat 0 as "no reliable ETA" and omit the time copy.
  static int muscleEtaHours(String muscle, double score) {
    final target = _kTargetHours[muscle.toLowerCase()];
    if (target == null || score >= 100.0) return 0;
    final remaining = target * (1.0 - score / 100.0);
    return remaining.ceil().clamp(0, 120);
  }
}
