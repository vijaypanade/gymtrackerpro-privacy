// lib/models/readiness.dart
//
// Readiness + Injury Risk models.
// Pure data — no ChangeNotifier, no Provider dependency.
//
// Two responsibilities:
//   1. ReadinessLevel — subjective 1-5 daily score, drives AI prompt intensity
//   2. InjuryRiskDetector — deterministic, lightweight, runs on existing logs

import 'package:flutter/material.dart';
import 'workout_log.dart';

// ═══════════════════════════════════════════════════════
// READINESS
// ═══════════════════════════════════════════════════════

enum ReadinessLevel {
  exhausted,   // 1
  lowEnergy,   // 2
  normal,      // 3
  good,        // 4
  excellent,   // 5
}

extension ReadinessLevelX on ReadinessLevel {
  int get score => index + 1;

  String get label {
    switch (this) {
      case ReadinessLevel.exhausted:  return 'Exhausted';
      case ReadinessLevel.lowEnergy:  return 'Low Energy';
      case ReadinessLevel.normal:     return 'Normal';
      case ReadinessLevel.good:       return 'Good';
      case ReadinessLevel.excellent:  return 'Excellent';
    }
  }

  String get emoji {
    switch (this) {
      case ReadinessLevel.exhausted:  return '😴';
      case ReadinessLevel.lowEnergy:  return '😐';
      case ReadinessLevel.normal:     return '🙂';
      case ReadinessLevel.good:       return '💪';
      case ReadinessLevel.excellent:  return '🔥';
    }
  }

  Color get color {
    switch (this) {
      case ReadinessLevel.exhausted:  return const Color(0xFFEF4444);
      case ReadinessLevel.lowEnergy:  return const Color(0xFFF97316);
      case ReadinessLevel.normal:     return const Color(0xFFFFCC00);
      case ReadinessLevel.good:       return const Color(0xFF86EFAC);
      case ReadinessLevel.excellent:  return const Color(0xFF22C55E);
    }
  }

  // Injected into the AI prompt — gives Gemini precise behavioural rules.
  String get promptBlock {
    switch (this) {
      case ReadinessLevel.exhausted:
        return 'DAILY READINESS: 1/5 — Exhausted.\n'
            'MANDATORY RULES:\n'
            '- Reduce total volume by 30–35%.\n'
            '- NO failure sets. NO PR attempts. NO maximal effort.\n'
            '- Use machines and isolation exercises only.\n'
            '- Avoid heavy barbell compounds (squat, deadlift, bench) today.\n'
            '- Keep RIR ≥ 4 on every set.\n'
            '- If user insists on training, prescribe mobility + light pump work only.';
      case ReadinessLevel.lowEnergy:
        return 'DAILY READINESS: 2/5 — Low Energy.\n'
            'MANDATORY RULES:\n'
            '- Reduce total volume by 20–25%.\n'
            '- Avoid failure sets. No PR attempts.\n'
            '- Prefer controlled compound movements over maximal lifts.\n'
            '- Keep RIR ≥ 3. Focus on technique.';
      case ReadinessLevel.normal:
        return 'DAILY READINESS: 3/5 — Normal.\n'
            '- Standard training protocol. No adjustments needed.';
      case ReadinessLevel.good:
        return 'DAILY READINESS: 4/5 — Good.\n'
            '- Allow normal progression. Compound-first approach.\n'
            '- RIR 1–2 on top sets if recovery data supports it.';
      case ReadinessLevel.excellent:
        return 'DAILY READINESS: 5/5 — Peak Condition.\n'
            '- Green light for PR attempts on main lifts.\n'
            '- Full planned volume. Heavier loading is appropriate.\n'
            '- Ideal day for new weight records.';
    }
  }

  static ReadinessLevel fromScore(int score) {
    final clamped = score.clamp(1, 5);
    return ReadinessLevel.values[clamped - 1];
  }
}

// ═══════════════════════════════════════════════════════
// INJURY RISK
// ═══════════════════════════════════════════════════════

enum RecoveryWarningType {
  consecutiveMuscle, // same muscle in 3+ consecutive sessions
  volumeSurge,       // weekly volume more than doubled vs previous week
  highFatigueStreak, // 3+ sessions all below 50% effort
}

class RecoveryWarning {
  final RecoveryWarningType type;
  final String muscle;   // empty for highFatigueStreak
  final String message;
  final String emoji;

  const RecoveryWarning({
    required this.type,
    required this.muscle,
    required this.message,
    required this.emoji,
  });
}

// ═══════════════════════════════════════════════════════
// INJURY RISK DETECTOR
// Pure static — no state, no Provider.
// ═══════════════════════════════════════════════════════
class InjuryRiskDetector {
  InjuryRiskDetector._();

  /// Main entry point.
  /// [recentEffortScores] — newest first, from PerformancePattern.effortScore
  static List<RecoveryWarning> detect({
    required List<WorkoutLog> logs,
    required List<double> recentEffortScores,
  }) {
    final warnings = <RecoveryWarning>[];
    if (logs.isNotEmpty) {
      _checkConsecutiveMuscle(logs, warnings);
      _checkVolumeSurge(logs, warnings);
    }
    if (recentEffortScores.length >= 3) {
      _checkHighFatigueStreak(recentEffortScores, warnings);
    }
    return warnings;
  }

  // ── 1. Same muscle trained in last 3 consecutive sessions ──────────────
  static void _checkConsecutiveMuscle(
    List<WorkoutLog> logs,
    List<RecoveryWarning> out,
  ) {
    // Build date → muscle groups trained that session
    final sessionMuscles = <String, Set<String>>{};
    for (final log in logs) {
      final mg = log.muscleGroup;
      if (mg == null || mg.isEmpty) continue;
      final key = _dateKey(log.date);
      sessionMuscles.putIfAbsent(key, () => <String>{}).add(mg);
    }

    if (sessionMuscles.length < 3) return;

    // Sort descending (most recent first)
    final sessions = sessionMuscles.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final last3 = sessions.take(3).map((e) => e.value).toList();

    const tracked = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
    for (final muscle in tracked) {
      if (last3.every((set) => set.contains(muscle))) {
        final cap = '${muscle[0].toUpperCase()}${muscle.substring(1)}';
        out.add(RecoveryWarning(
          type:    RecoveryWarningType.consecutiveMuscle,
          muscle:  muscle,
          message: '$cap trained in 3 consecutive sessions — overuse risk',
          emoji:   '⚠️',
        ));
      }
    }
  }

  // ── 2. Weekly volume surge >120% vs previous week ──────────────────────
  // Requires a meaningful baseline (≥2000 kg) so that tiny prior sessions
  // don't manufacture false positives for users returning after rest weeks.
  static void _checkVolumeSurge(
    List<WorkoutLog> logs,
    List<RecoveryWarning> out,
  ) {
    final now = DateTime.now();
    // "this week" = last 7 days; "last week" = 7–14 days ago
    final thisStart = now.subtract(const Duration(days: 7));
    final lastStart = now.subtract(const Duration(days: 14));

    final thisWeek = <String, double>{};
    final lastWeek = <String, double>{};

    for (final log in logs) {
      final mg = log.muscleGroup;
      if (mg == null || mg.isEmpty) continue;
      if (log.weight <= 0 && log.reps <= 0) continue;
      final vol = log.weight > 0 ? log.weight * log.reps : log.reps.toDouble();

      if (log.date.isAfter(thisStart)) {
        thisWeek[mg] = (thisWeek[mg] ?? 0) + vol;
      } else if (log.date.isAfter(lastStart)) {
        lastWeek[mg] = (lastWeek[mg] ?? 0) + vol;
      }
    }

    for (final entry in thisWeek.entries) {
      final prev = lastWeek[entry.key] ?? 0;
      // Skip if no baseline or baseline is too small to be meaningful
      if (prev < 2000) continue;
      final pctIncrease = (entry.value - prev) / prev;
      if (pctIncrease >= 1.20) {
        final cap = '${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
        final pct = (pctIncrease * 100).toStringAsFixed(0);
        out.add(RecoveryWarning(
          type:    RecoveryWarningType.volumeSurge,
          muscle:  entry.key,
          message: '$cap volume is +$pct% above last week — monitor recovery',
          emoji:   '📈',
        ));
      }
    }
  }

  // ── 3. Three consecutive sessions all below 50% effort ────────────────
  static void _checkHighFatigueStreak(
    List<double> recentEffortScores, // newest first
    List<RecoveryWarning> out,
  ) {
    final last3 = recentEffortScores.take(3).toList();
    if (last3.length < 3) return;
    if (last3.every((s) => s < 50)) {
      out.add(const RecoveryWarning(
        type:    RecoveryWarningType.highFatigueStreak,
        muscle:  '',
        message: '3 consecutive low-effort sessions — recovery may be insufficient',
        emoji:   '😴',
      ));
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
