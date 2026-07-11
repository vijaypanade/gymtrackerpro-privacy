// lib/utils/readiness_helper.dart
// Deterministic AI readiness engine — no network, no AI calls.
// Inputs: weekly volume, streak, completedDays, daysSinceLastWorkout.

import 'package:flutter/material.dart';

class ReadinessResult {
  final int score;
  final String label;
  final Color color;
  final IconData icon;
  final String coach;
  const ReadinessResult({
    required this.score,
    required this.label,
    required this.color,
    required this.icon,
    required this.coach,
  });
}

abstract final class ReadinessHelper {
  static ReadinessResult compute({
    required Map<String, double> volumeByMuscle,
    required int streakCount,
    required int completedDaysThisWeek,
    required int daysSinceLastWorkout,
  }) {
    double score = 100.0;

    final totalVol = volumeByMuscle.values.fold(0.0, (a, b) => a + b);

    // Volume penalty
    if (totalVol > 20000) {
      score -= 28;
    } else if (totalVol > 13000) {
      score -= 18;
    } else if (totalVol > 7000) {
      score -= 10;
    }

    // Recovery bonus — rest days restore readiness
    if (daysSinceLastWorkout >= 2) {
      score += 10;
    } else if (daysSinceLastWorkout == 0) {
      score -= 8;
    }

    // Weekly frequency penalty
    if (completedDaysThisWeek >= 6) {
      score -= 20;
    } else if (completedDaysThisWeek >= 5) {
      score -= 12;
    } else if (completedDaysThisWeek >= 4) {
      score -= 5;
    }

    // Streak: momentum bonus, long streak = slight fatigue signal
    if (streakCount >= 21) {
      score -= 8;
    } else if (streakCount >= 7) {
      score += 5;
    } else if (streakCount == 0) {
      score -= 5;
    }

    score = score.clamp(0.0, 100.0);
    final s = score.toInt();
    final coach = _coachLine(volumeByMuscle, daysSinceLastWorkout, totalVol);

    if (s >= 90) {
      return ReadinessResult(
        score: s, label: 'Peak Performance',
        color: const Color(0xFF22C55E),
        icon: Icons.local_fire_department_rounded, coach: coach,
      );
    }
    if (s >= 70) {
      return ReadinessResult(
        score: s, label: 'Ready To Push',
        color: const Color(0xFFD4AF37),
        icon: Icons.bolt_rounded, coach: coach,
      );
    }
    if (s >= 50) {
      return ReadinessResult(
        score: s, label: 'Moderate Fatigue',
        color: const Color(0xFFFF9F0A),
        icon: Icons.hourglass_top_rounded, coach: coach,
      );
    }
    return ReadinessResult(
      score: s, label: 'Recovery Needed',
      color: const Color(0xFFFF6232),
      icon: Icons.bedtime_rounded, coach: coach,
    );
  }

  static String _coachLine(
    Map<String, double> volMap,
    int daysSince,
    double totalVol,
  ) {
    if (volMap.isEmpty) return 'Fresh start — full capacity today.';
    final top = volMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    final name = '${top.key[0].toUpperCase()}${top.key.substring(1)}';
    if (daysSince >= 2) return '$name recovered well today.';
    if (totalVol > 15000) return 'Big week so far. Pace yourself.';
    if (totalVol > 8000) return 'Solid training load — stay consistent.';
    return 'Recovery on track — push hard today.';
  }
}
