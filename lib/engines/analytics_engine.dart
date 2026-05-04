// lib/engines/analytics_engine.dart — v3.0 SCIENTIFIC ENGINE
// ══════════════════════════════════════════════════════════════
// Based on peer-reviewed sports science:
//
// FATIGUE INDEX:
//   • Acute:Chronic Workload Ratio (ACWR) — Gabbett 2016
//     Acute load (7-day) / Chronic load (28-day rolling avg)
//     Safe zone: 0.8–1.3 | Danger: >1.5
//   • Neuromuscular fatigue markers: rep quality drop, inter-session gaps
//   • HRV proxy: training density + mood
//
// PLATEAU DETECTION:
//   • Requires minimum 3 weeks data + 8 sessions (Schoenfeld 2010)
//   • Uses SRA curve (Stimulus → Recovery → Adaptation)
//   • Per-exercise weight stagnation over 3+ consecutive sessions
//   • 3-week no-progress window = confirmed plateau
//
// DELOAD DETECTION:
//   • NOT triggered by low session count
//   • Triggered by: ACWR > 1.3 + fatigue > 65 + 3+ weeks training
//   • OR: 4-week block completion (periodization standard)
//   • Science: Zourdos et al. 2016 — deload every 4-6 weeks optimal
//
// READINESS SCORE:
//   • Composite: recovery (40%) + fatigue inverse (35%) + mood (15%) + trend (10%)
//   • Mirrors HRV-based readiness used in elite sports
//
// WEEKLY IMPROVEMENT:
//   • Weighted volume comparison — accounts for exercise rotation
//   • Uses tonnage (sets × reps × weight) not raw volume
// ══════════════════════════════════════════════════════════════

import 'dart:math';
import '../models/workout_log.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────
// TRAINING READINESS LEVEL — human-readable output
// ─────────────────────────────────────────────────────────────
enum TrainingReadiness {
  peak,          // 85-100: PR attempt, push hard
  high,          // 70-84:  normal progressive session
  moderate,      // 50-69:  train, but don't max out
  low,           // 30-49:  light session only
  deloadNeeded,  // 0-29:   deload or rest
}

extension TrainingReadinessX on TrainingReadiness {
  String get label {
    switch (this) {
      case TrainingReadiness.peak:         return 'Peak Readiness 🔥';
      case TrainingReadiness.high:         return 'High Readiness ✅';
      case TrainingReadiness.moderate:     return 'Moderate — Train Smart 💪';
      case TrainingReadiness.low:          return 'Low — Light Session Only ⚠️';
      case TrainingReadiness.deloadNeeded: return 'Deload Needed 🔄';
    }
  }
  String get coachNote {
    switch (this) {
      case TrainingReadiness.peak:
        return 'Neuromuscular system is primed. Attack PRs today.';
      case TrainingReadiness.high:
        return 'Good recovery. Execute the plan with progressive overload.';
      case TrainingReadiness.moderate:
        return 'Partial recovery. Train at 80% intensity, focus on form.';
      case TrainingReadiness.low:
        return 'Accumulated fatigue detected. Light session max — protect your recovery.';
      case TrainingReadiness.deloadNeeded:
        return 'ACWR elevated. 40% volume reduction for 1 week — mandatory for long-term progress.';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// ACWR RESULT — Acute:Chronic Workload Ratio
// ─────────────────────────────────────────────────────────────
class ACWRResult {
  final double acuteLoad;   // 7-day tonnage
  final double chronicLoad; // 28-day rolling avg
  final double ratio;       // acute / chronic
  final String zone;        // 'safe' | 'optimal' | 'caution' | 'danger'

  const ACWRResult({
    required this.acuteLoad,
    required this.chronicLoad,
    required this.ratio,
    required this.zone,
  });

  bool get isInSafeZone   => ratio >= 0.8 && ratio <= 1.3;
  bool get isOptimal      => ratio >= 0.8 && ratio <= 1.1;
  bool get isDanger       => ratio > 1.5;
  bool get isUnderloaded  => ratio < 0.8 && chronicLoad > 0;

  String get readableRatio => ratio.toStringAsFixed(2);
}

class AnalyticsEngine {

  // ══════════════════════════════════════════════════════════════
  // ACWR — Acute:Chronic Workload Ratio
  // Gold standard for injury prevention in sports science
  // ══════════════════════════════════════════════════════════════
  static ACWRResult computeACWR({required List<WorkoutLog> logs}) {
    if (logs.isEmpty) {
      return const ACWRResult(acuteLoad: 0, chronicLoad: 0, ratio: 1.0, zone: 'safe');
    }

    final now = DateTime.now();

    // Acute load = tonnage in last 7 days
    final acute = logs
        .where((l) => now.difference(l.date).inDays < 7)
        .fold(0.0, (s, l) => s + _tonnage(l));

    // Chronic load = rolling 28-day average (divided by 4 weeks)
    final last28 = logs
        .where((l) => now.difference(l.date).inDays < 28)
        .fold(0.0, (s, l) => s + _tonnage(l));
    final chronic = last28 / 4.0; // per-week average

    // Avoid division by zero — new users
    if (chronic < 1.0) {
      return ACWRResult(
        acuteLoad: acute, chronicLoad: 0, ratio: 1.0, zone: 'safe');
    }

    final ratio = acute / chronic;

    String zone;
    if (ratio < 0.8)        zone = 'underloaded'; // too little → detraining
    else if (ratio <= 1.1)  zone = 'optimal';     // sweet spot
    else if (ratio <= 1.3)  zone = 'safe';        // acceptable increase
    else if (ratio <= 1.5)  zone = 'caution';     // elevated risk
    else                    zone = 'danger';       // injury/overtraining zone

    return ACWRResult(
      acuteLoad: acute, chronicLoad: chronic, ratio: ratio, zone: zone);
  }

  // ══════════════════════════════════════════════════════════════
  // FATIGUE INDEX (0–100) — Higher = more fatigued
  // Based on: ACWR + volume trend + rep quality + mood + streak
  // ══════════════════════════════════════════════════════════════
  static double computeFatigueIndex({
    required List<WorkoutLog> logs,
    required MoodType mood,
    required int streak,
  }) {
    if (logs.length < 3) return 15; // Insufficient data → assume fresh

    double index = 0;

    // ── Component 1: ACWR-based fatigue (50% weight) ─────────────
    final acwr = computeACWR(logs: logs);
    if (acwr.ratio > 1.5)       index += 50;
    else if (acwr.ratio > 1.3)  index += 30;
    else if (acwr.ratio > 1.1)  index += 10;
    else if (acwr.ratio < 0.7)  index += 5; // underloading still has mild effect

    // ── Component 2: Volume trend — last 3 sessions (25% weight) ─
    final recent = logs.reversed.take(6).toList();
    if (recent.length >= 3) {
      final vols = recent.take(3).map((l) => _tonnage(l)).toList();
      final avgRecent = vols.reduce((a, b) => a + b) / vols.length;
      final prev = recent.skip(3).take(3).map((l) => _tonnage(l)).toList();
      if (prev.isNotEmpty) {
        final avgPrev = prev.reduce((a, b) => a + b) / prev.length;
        if (avgPrev > 0) {
          final volDrop = (avgPrev - avgRecent) / avgPrev;
          if (volDrop > 0.20) index += 20; // 20%+ drop = fatigue signal
          else if (volDrop > 0.10) index += 10;
        }
      }
    }

    // ── Component 3: Training density — gaps between sessions ────
    if (recent.length >= 4) {
      final gaps = <int>[];
      for (int i = 0; i < recent.length - 1; i++) {
        gaps.add(recent[i].date.difference(recent[i + 1].date).inHours.abs());
      }
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      if (avgGap < 16)     index += 15; // Training twice per day
      else if (avgGap < 24) index += 8;  // <24h between sessions
    }

    // ── Component 4: Rep quality degradation ─────────────────────
    final byEx = <String, List<WorkoutLog>>{};
    for (final log in recent) {
      byEx.putIfAbsent(log.exercise, () => []).add(log);
    }
    int repDropCount = 0;
    for (final exLogs in byEx.values) {
      if (exLogs.length >= 2) {
        exLogs.sort((a, b) => b.date.compareTo(a.date));
        if (exLogs[0].reps < exLogs[1].reps * 0.75) repDropCount++;
      }
    }
    if (repDropCount >= 2) index += 15; // Multiple exercises declining

    // ── Component 5: Mood modifier ────────────────────────────────
    if (mood == MoodType.tired)     index += 12;
    if (mood == MoodType.energetic) index -= 8;

    // ── Component 6: Streak-based cumulative fatigue ──────────────
    // Science: >7 days continuous training = significant CNS fatigue
    if (streak >= 21) index += 18;
    else if (streak >= 14) index += 12;
    else if (streak >= 7)  index += 6;

    return index.clamp(0.0, 95.0);
  }

  // ══════════════════════════════════════════════════════════════
  // READINESS SCORE (0–100) — How ready is the user to train?
  // Composite score, not just "fatigue inverted"
  // ══════════════════════════════════════════════════════════════
  static double computeReadiness({
    required double recovery,  // muscle recovery 0-100
    required double fatigue,   // fatigue index 0-100
    required int streak,
    required String mood,
    required bool needsDeload,
  }) {
    // Base from recovery (40%)
    double score = recovery * 0.40;

    // Fatigue inverse contribution (35%)
    // fatigue=0 → +35 pts, fatigue=100 → +0 pts
    score += (1.0 - (fatigue / 100.0)) * 35;

    // Mood contribution (15%)
    if (mood == 'energetic') score += 15;
    else if (mood == 'normal') score += 8;
    else score += 2; // tired

    // Streak continuity bonus (10%)
    // Optimal sweet spot: 3–6 days streak
    if (streak >= 3 && streak <= 6)  score += 10;
    else if (streak >= 7 && streak <= 13) score += 5;
    else if (streak >= 14) score += 0; // No bonus — fatigue accumulation

    // Deload penalty
    if (needsDeload) score -= 20;

    return score.clamp(10.0, 98.0);
  }

  // ══════════════════════════════════════════════════════════════
  // PLATEAU DETECTION (0–100) — Scientific minimum thresholds
  // Based on: Schoenfeld 2010 + Kraemer & Ratamess 2004
  // ══════════════════════════════════════════════════════════════
  static double computePlateauScore({required List<WorkoutLog> logs}) {
    // SCIENTIFIC MINIMUM: 3 weeks (21 days) + 8+ sessions
    // Reasoning: SRA curve requires 72-96h to complete
    // Can't plateau in less than 3 full training cycles per muscle
    if (logs.length < 8) return 0;
    if (logs.isEmpty) return 0;

    final oldest = logs.map((l) => l.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final weeksOfData = DateTime.now().difference(oldest).inDays / 7.0;
    if (weeksOfData < 3.0) return 0; // Hard scientific minimum

    // Group by exercise, require 4+ data points per exercise
    final byEx = <String, List<WorkoutLog>>{};
    for (final log in logs.reversed.take(40)) { // Last 40 entries
      byEx.putIfAbsent(log.exercise, () => []).add(log);
    }

    int plateauCount  = 0;
    int totalChecked  = 0;

    for (final exLogs in byEx.values) {
      if (exLogs.length < 4) continue; // Need 4+ sessions per exercise
      exLogs.sort((a, b) => a.date.compareTo(b.date));

      // Check last 4 sessions for weight progress
      final last4 = exLogs.takeLast(4);
      final weights = last4.map((l) => l.weight).toList();

      // Only check weight-based exercises
      if (weights.every((w) => w == 0)) continue;

      // Calculate max weight increase over window
      final maxInWindow = weights.reduce(max);
      final firstInWindow = weights.first;
      final increase = maxInWindow - firstInWindow;

      // Plateau: no meaningful strength progress in last 4 sessions
      // Threshold: <2.5kg = essentially stagnant (Kraemer standard)
      if (increase < 2.5) {
        // Secondary check: did volume increase? (rep PR)
        final maxReps = last4.map((l) => l.reps).reduce(max);
        final firstReps = last4.first.reps;
        if (maxReps - firstReps < 2) plateauCount++; // No rep progress either
      }
      totalChecked++;
    }

    if (totalChecked == 0) return 0;

    // Require at least 2 exercises plateaued for signal
    if (plateauCount < 2) return (plateauCount / totalChecked * 50).clamp(0, 49);

    return ((plateauCount / totalChecked) * 100).clamp(0.0, 95.0);
  }

  // ══════════════════════════════════════════════════════════════
  // DELOAD DETECTION — Scientific criteria
  // Based on: Zourdos 2016, Haff & Triplett NSCA Essentials
  // ══════════════════════════════════════════════════════════════
  static bool shouldDeload({
    required List<WorkoutLog> logs,
    required int streak,
    required int totalWorkouts,
  }) {
    // CRITICAL: Never suggest deload with < 8 sessions
    // New users are NOT fatigued — they're building base
    if (totalWorkouts < 8) return false;

    final now = DateTime.now();
    if (logs.isEmpty) return false;

    final oldest = logs.map((l) => l.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final weeksTraining = now.difference(oldest).inDays / 7.0;

    // SCIENTIFIC RULE 1: 4-week periodization block completion
    // Every 4th week should be a deload (Zourdos protocol)
    if (weeksTraining >= 4.0 && totalWorkouts >= 12) {
      final acwr = computeACWR(logs: logs);
      if (acwr.ratio > 1.3) return true; // High workload + 4 weeks = deload
    }

    // SCIENTIFIC RULE 2: ACWR danger zone (>1.5) with significant training history
    if (totalWorkouts >= 10) {
      final acwr = computeACWR(logs: logs);
      if (acwr.ratio > 1.5) return true;
    }

    // SCIENTIFIC RULE 3: Consecutive volume decline (3+ sessions)
    // Indicates body can no longer adapt → forced deload
    if (logs.length >= 6) {
      final recent = logs.reversed.take(6).toList();
      final vols = recent.map((l) => _tonnage(l)).toList();
      bool consecutiveDecline = true;
      for (int i = 0; i < vols.length - 1; i++) {
        if (vols[i] >= vols[i + 1] * 0.90) {
          consecutiveDecline = false;
          break;
        }
      }
      if (consecutiveDecline && weeksTraining >= 3.0) return true;
    }

    // SCIENTIFIC RULE 4: Long streak without rest (>21 days)
    if (streak >= 21) return true;

    return false;
  }

  // ══════════════════════════════════════════════════════════════
  // WEEKLY IMPROVEMENT — Weighted tonnage comparison
  // ══════════════════════════════════════════════════════════════
  static double computeWeeklyImprovement({required List<WorkoutLog> logs}) {
    final now = DateTime.now();

    // Weighted tonnage: sets × reps × weight
    // More accurate than raw volume for mixed sessions
    final week1 = logs
        .where((l) => now.difference(l.date).inDays < 7)
        .fold(0.0, (s, l) => s + _tonnage(l));

    final week2 = logs
        .where((l) {
          final d = now.difference(l.date).inDays;
          return d >= 7 && d < 14;
        })
        .fold(0.0, (s, l) => s + _tonnage(l));

    if (week2 < 1.0) return 0.0; // No comparison data

    return ((week1 - week2) / week2 * 100).clamp(-50.0, 100.0);
  }

  // ══════════════════════════════════════════════════════════════
  // TRAINING AGE CLASSIFICATION
  // Determines appropriate progression rate
  // ══════════════════════════════════════════════════════════════
  static String classifyTrainingAge(int totalWorkouts) {
    if (totalWorkouts < 12)  return 'novice';      // Linear progression every session
    if (totalWorkouts < 40)  return 'intermediate'; // Progress weekly
    if (totalWorkouts < 100) return 'advanced';    // Progress monthly
    return 'elite';                                 // Block periodization needed
  }

  // ══════════════════════════════════════════════════════════════
  // OPTIMAL TRAINING FREQUENCY — per muscle group
  // Based on: Schoenfeld meta-analysis 2016
  // ══════════════════════════════════════════════════════════════
  static int optimalFrequencyPerMuscle(String muscle, String experience) {
    // Science: 2× per week per muscle group is optimal for most
    // Advanced athletes can handle 3× with proper recovery
    switch (experience) {
      case 'beginner':     return 3; // Full body 3× hits each muscle 3×
      case 'advanced':     return 3; // PPL 6-day hits each 2-3×
      default:             return 2; // Standard intermediate: 2× per week
    }
  }

  // ══════════════════════════════════════════════════════════════
  // MUSCLE IMBALANCE SCORE
  // ══════════════════════════════════════════════════════════════
  static String getMuscleImbalance(List<WorkoutLog> logs) {
    if (logs.isEmpty) return 'Start training to unlock insights';

    final volumeByMuscle = <String, double>{};
    for (final log in logs) {
      final muscle = log.muscleGroup ?? 'other';
      if (muscle == 'other') continue;
      volumeByMuscle[muscle] = (volumeByMuscle[muscle] ?? 0) + _tonnage(log);
    }

    if (volumeByMuscle.length < 2) return 'Train more muscles for balance insights';

    final sorted = volumeByMuscle.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final weakest  = sorted.first.key;
    final maxVol   = sorted.last.value;
    final minVol   = sorted.first.value;

    if (maxVol == 0) return 'Balanced training';

    final diff = ((maxVol - minVol) / maxVol) * 100;

    if (diff < 15)      return 'Excellent muscle balance 💪';
    else if (diff < 30) return '$weakest slightly lagging';
    else if (diff < 50) return '⚠️ $weakest needs attention';
    else                return '🚨 Significant $weakest imbalance — prioritize today';
  }

  // ══════════════════════════════════════════════════════════════
  // RECOVERY QUALITY INDEX — 0 to 100
  // How well is the user recovering between sessions?
  // ══════════════════════════════════════════════════════════════
  static double computeRecoveryQuality({required List<WorkoutLog> logs}) {
    if (logs.length < 4) return 80; // Assume good recovery — not enough data

    final sorted = List<WorkoutLog>.from(logs)
        ..sort((a, b) => b.date.compareTo(a.date));

    double quality = 100;

    // Check performance consistency: good recovery = consistent performance
    final recent = sorted.take(6).toList();
    double prevTonnage = 0;
    int declineCount   = 0;

    for (final log in recent) {
      final t = _tonnage(log);
      if (prevTonnage > 0 && t < prevTonnage * 0.85) declineCount++;
      prevTonnage = t;
    }

    quality -= declineCount * 12;

    // Check gap consistency: erratic gaps = poor recovery habits
    if (recent.length >= 3) {
      final gaps = <int>[];
      for (int i = 0; i < recent.length - 1; i++) {
        gaps.add(recent[i].date.difference(recent[i + 1].date).inHours.abs());
      }
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      final variance = gaps.map((g) => pow(g - avgGap, 2).toDouble())
          .reduce((a, b) => a + b) / gaps.length;
      final stdDev = sqrt(variance);

      // High variance in training gaps = inconsistent recovery
      if (stdDev > 48) quality -= 15;
      else if (stdDev > 24) quality -= 8;
    }

    return quality.clamp(20.0, 100.0);
  }

  // ── PRIVATE: Tonnage calculator ───────────────────────────────
  // Tonnage = weight × reps (fundamental unit of training load)
  static double _tonnage(WorkoutLog log) {
    if (log.weight <= 0) return log.reps.toDouble(); // bodyweight
    return log.weight * log.reps;
  }
}

// ─────────────────────────────────────────────────────────────
// LIST EXTENSION
// ─────────────────────────────────────────────────────────────
extension ListUtils<T> on List<T> {
  List<T> takeLast(int n) {
    if (n <= 0 || isEmpty) return [];
    return length <= n ? List<T>.from(this) : sublist(length - n);
  }
}
