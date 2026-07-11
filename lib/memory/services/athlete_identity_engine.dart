// lib/memory/services/athlete_identity_engine.dart

import '../athlete_memory.dart';

/// Deterministic long-term athlete identity derived from AthleteMemory.
///
/// This engine is pure: no AI, no persistence, no randomness, no external
/// integration. It maps AthleteMemory dimensions to explainable identity
/// labels and output dimensions.
class AthleteIdentityEngine {
  const AthleteIdentityEngine();

  AthleteIdentity derive(AthleteMemory memory) {
    final String consistency = _classifyConsistency(memory.consistencyScore);
    final String recovery = _classifyRecoveryAdaptability(memory.recoveryVelocity);
    final String progression = _classifyProgressionStyle(
      memory.progressionVelocity,
      memory.consistencyScore,
      memory.reliabilityScore,
    );
    final String volumeTolerance = _classifyVolumeTolerance(memory.volumeTolerance);
    final String discipline = _classifyDiscipline(memory.adherenceScore, memory.reliabilityScore);
    final String reliability = _classifyReliability(memory.reliabilityScore);
    final String preferredWindow = _classifyPreferredTrainingWindow(memory.preferredTrainingTime);

    return AthleteIdentity(
      consistency: consistency,
      recoveryAdaptability: recovery,
      progressionStyle: progression,
      volumeTolerance: volumeTolerance,
      discipline: discipline,
      reliability: reliability,
      preferredSessionDuration: memory.preferredSessionDuration,
      preferredTrainingWindow: preferredWindow,
      labels: _deriveLabels(
        consistency,
        recovery,
        progression,
        volumeTolerance,
        discipline,
        reliability,
      ),
    );
  }

  static String _classifyConsistency(double score) {
    if (score >= 0.75) {
      return 'Consistent';
    }
    if (score >= 0.50) {
      return 'Steady';
    }
    return 'Beginner';
  }

  static String _classifyRecoveryAdaptability(double recoveryVelocity) {
    if (recoveryVelocity >= 0.75) {
      return 'Recovery Resilient';
    }
    if (recoveryVelocity >= 0.45) {
      return 'Recovery Adaptive';
    }
    return 'Recovery Sensitive';
  }

  static String _classifyProgressionStyle(
    double progressionVelocity,
    double consistencyScore,
    double reliabilityScore,
  ) {
    if (progressionVelocity >= 0.70 && consistencyScore >= 0.60) {
      return 'Momentum Builder';
    }
    if (progressionVelocity >= 0.55 && reliabilityScore >= 0.55) {
      return 'PR Hunter';
    }
    if (progressionVelocity >= 0.45 && consistencyScore < 0.50) {
      return 'Comeback Athlete';
    }
    if (progressionVelocity >= 0.35) {
      return 'Strength Focused';
    }
    return 'Developmental';
  }

  static String _classifyVolumeTolerance(double volumeTolerance) {
    if (volumeTolerance >= 0.70) {
      return 'High Volume Athlete';
    }
    if (volumeTolerance >= 0.45) {
      return 'Moderate Volume Athlete';
    }
    return 'Low Volume Athlete';
  }

  static String _classifyDiscipline(double adherenceScore, double reliabilityScore) {
    final double combined = (adherenceScore + reliabilityScore) / 2.0;
    if (combined >= 0.70) {
      return 'Disciplined';
    }
    if (combined >= 0.45) {
      return 'Committed';
    }
    return 'Inconsistent';
  }

  static String _classifyReliability(double reliabilityScore) {
    if (reliabilityScore >= 0.70) {
      return 'Reliable';
    }
    if (reliabilityScore >= 0.45) {
      return 'Occasionally Reliable';
    }
    return 'Unreliable';
  }

  static String _classifyPreferredTrainingWindow(String preferredTrainingTime) {
    if (preferredTrainingTime.toLowerCase().contains('morning')) {
      return 'Morning';
    }
    if (preferredTrainingTime.toLowerCase().contains('evening')) {
      return 'Evening';
    }
    if (preferredTrainingTime.toLowerCase().contains('afternoon')) {
      return 'Afternoon';
    }
    return 'Flexible';
  }

  static List<String> _deriveLabels(
    String consistency,
    String recovery,
    String progression,
    String volumeTolerance,
    String discipline,
    String reliability,
  ) {
    final labels = <String>[];

    if (consistency == 'Beginner') {
      labels.add('Beginner');
    }
    if (consistency == 'Consistent') {
      labels.add('Consistent');
    }
    if (progression == 'Momentum Builder') {
      labels.add('Momentum Builder');
    }
    if (progression == 'Comeback Athlete') {
      labels.add('Comeback Athlete');
    }
    if (progression == 'PR Hunter') {
      labels.add('PR Hunter');
    }
    if (recovery == 'Recovery Sensitive') {
      labels.add('Recovery Sensitive');
    }
    if (volumeTolerance == 'High Volume Athlete') {
      labels.add('High Volume Athlete');
    }
    if (progression == 'Strength Focused') {
      labels.add('Strength Focused');
    }
    if (progression == 'Developmental') {
      labels.add('Hypertrophy Focused');
    }
    if (discipline == 'Disciplined') {
      labels.add('Discipline');
    }
    if (reliability == 'Reliable') {
      labels.add('Reliability');
    }

    return labels;
  }
}

/// Immutable identity output produced by AthleteIdentityEngine.
class AthleteIdentity {
  final String consistency;
  final String recoveryAdaptability;
  final String progressionStyle;
  final String volumeTolerance;
  final String discipline;
  final String reliability;
  final Duration preferredSessionDuration;
  final String preferredTrainingWindow;
  final List<String> labels;

  const AthleteIdentity({
    required this.consistency,
    required this.recoveryAdaptability,
    required this.progressionStyle,
    required this.volumeTolerance,
    required this.discipline,
    required this.reliability,
    required this.preferredSessionDuration,
    required this.preferredTrainingWindow,
    required this.labels,
  });
}
