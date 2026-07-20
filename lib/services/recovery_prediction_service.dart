// lib/services/recovery_prediction_service.dart
// Pure Dart — no Flutter imports.
// Derives forward-looking recovery projections from existing RecoveryState signals.
//
// Language: calm, observational, forward-looking. No medical terminology.
// UI: surfaces as a single muted prediction line + one system-level line.
//
// SAFETY CONTRACT:
//   Never says "you are depleted" or "your CNS is compromised."
//   Always framed as expected timeline, not judgment.
//   Returns '' when there is no meaningful prediction to make.

class RecoveryPrediction {
  /// Per-muscle calm prediction lines. Only populated for muscles with score < 80.
  /// Keys are lowercase muscle keys (e.g. 'legs', 'back', 'chest').
  final Map<String, String> muscleProjections;

  /// One system-level line about overall recovery trajectory. May be empty.
  final String systemLine;

  /// 0–1 recovery velocity — higher means recovering faster.
  /// Derived from strain, rest time, and overall score.
  final double recoveryVelocity;

  const RecoveryPrediction({
    required this.muscleProjections,
    required this.systemLine,
    required this.recoveryVelocity,
  });

  static const RecoveryPrediction empty = RecoveryPrediction(
    muscleProjections: {},
    systemLine:        '',
    recoveryVelocity:  0.5,
  );
}

class RecoveryPredictionInput {
  /// From RecoveryState.muscleScores — lowercase muscle key → 0–100.
  final Map<String, double> muscleScores;

  /// From WorkoutProvider.lastTrainedByMuscle — lowercase muscle key → DateTime.
  final Map<String, DateTime> lastTrainedByMuscle;

  final double overallScore;
  final double strain7d;
  final int    daysSinceLastWorkout;
  final DateTime now;

  const RecoveryPredictionInput({
    required this.muscleScores,
    required this.lastTrainedByMuscle,
    required this.overallScore,
    required this.strain7d,
    required this.daysSinceLastWorkout,
    required this.now,
  });
}

class RecoveryPredictionService {
  RecoveryPredictionService._();

  static RecoveryPrediction compute(RecoveryPredictionInput i) {
    if (i.muscleScores.isEmpty) return RecoveryPrediction.empty;

    final projections = <String, String>{};

    for (final entry in i.muscleScores.entries) {
      final muscle = entry.key;
      final score  = entry.value;
      if (score >= 80) continue; // Already ready — no prediction needed

      final lastTrained  = i.lastTrainedByMuscle[muscle];
      final hoursElapsed = lastTrained != null
          ? i.now.difference(lastTrained).inHours
          : i.daysSinceLastWorkout * 24;

      final line = _projectLine(
          _capitalize(muscle), score, hoursElapsed.clamp(0, 120));
      if (line.isNotEmpty) projections[muscle] = line;
    }

    final velocity   = _velocity(i);
    final systemLine = _systemLine(i, velocity);

    return RecoveryPrediction(
      muscleProjections: projections,
      systemLine:        systemLine,
      recoveryVelocity:  velocity,
    );
  }

  // ── Per-muscle projection line ─────────────────────────────────────────────

  static String _projectLine(String muscle, double score, int hoursElapsed) {
    // Baseline hours to reach 80+ from each score band
    final baseHours = score >= 65 ? 14 : score >= 50 ? 30 : score >= 30 ? 52 : 72;
    final remaining = (baseHours - hoursElapsed).clamp(0, 72);

    if (remaining <= 6)  return '$muscle readiness is nearly restored.';
    if (remaining <= 18) return '$muscle recovery is progressing — expected to normalize soon.';
    if (remaining <= 32) return '$muscle is expected to normalize by tomorrow.';
    if (remaining <= 52) return '$muscle may need another day to fully recover.';
    return '$muscle recovery demand remains elevated.';
  }

  // ── Recovery velocity ─────────────────────────────────────────────────────

  static double _velocity(RecoveryPredictionInput i) {
    final strainFactor = 1.0 - (i.strain7d / 100.0).clamp(0.0, 1.0);
    final restFactor   = (i.daysSinceLastWorkout / 3.0).clamp(0.0, 1.0);
    final scoreFactor  = (i.overallScore / 100.0).clamp(0.0, 1.0);
    return (strainFactor * 0.40 + restFactor * 0.30 + scoreFactor * 0.30)
        .clamp(0.0, 1.0);
  }

  // ── System-level recovery line ─────────────────────────────────────────────

  static String _systemLine(RecoveryPredictionInput i, double velocity) {
    final score = i.overallScore;
    final days  = i.daysSinceLastWorkout;

    if (score >= 80 && i.strain7d < 35)         return 'Full system readiness — ready to train.';
    if (days >= 2 && velocity >= 0.65)           return 'Recovery is progressing steadily — readiness is rebuilding.';
    if (score < 45 && i.strain7d > 60)           return 'Recovery demand is elevated. Rest is the active work right now.';
    if (score >= 62 && days >= 1 && score < 80)  return 'Readiness is rebuilding — most muscle groups are recovering well.';
    if (score < 60 && days == 0)                 return 'Your system is processing today\'s training load.';
    return '';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
