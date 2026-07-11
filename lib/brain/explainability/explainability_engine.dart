// lib/brain/explainability/explainability_engine.dart

import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adherence_intelligence_service.dart';
import '../../services/predictive_performance_service.dart';
import '../confidence/decision_confidence_engine.dart';
import '../models/decision_context.dart';
import '../policy/mission_selection_engine.dart';

/// Deterministic explainability layer for AthleteBrain decisions.
///
/// Converts mission choice, confidence, and decision context into a
/// concise, human-readable explanation without AI or persistence.
class ExplainabilityEngine {
  const ExplainabilityEngine();

  DecisionExplanation explain({
    required MissionType missionType,
    required DecisionConfidence decisionConfidence,
    required DecisionContext decisionContext,
    required AthleteMemorySnapshot athleteMemorySnapshot,
  }) {
    final dominantSignals = _selectDominantSignals(
      missionType,
      decisionContext,
      athleteMemorySnapshot,
    );
    final suppressedSignals = _selectSuppressedSignals(
      decisionContext,
      athleteMemorySnapshot,
    );
    final warnings = _selectWarnings(decisionConfidence, decisionContext);
    final title = _buildTitle(missionType);
    final summary = _buildSummary(
      missionType,
      dominantSignals,
      suppressedSignals,
      warnings,
      decisionConfidence,
    );
    final recommendation = _buildRecommendation(missionType, dominantSignals);
    final confidenceNarrative = _buildConfidenceNarrative(decisionConfidence);
    final nextReview = _buildNextReview(decisionConfidence);

    return DecisionExplanation(
      title: title,
      summary: summary,
      dominantSignals: dominantSignals,
      suppressedSignals: suppressedSignals,
      warnings: warnings,
      recommendation: recommendation,
      confidenceNarrative: confidenceNarrative,
      nextReview: nextReview,
    );
  }

  String _buildTitle(MissionType missionType) {
    return '${missionType.label} Recommended';
  }

  List<String> _selectDominantSignals(
    MissionType missionType,
    DecisionContext context,
    AthleteMemorySnapshot athleteMemorySnapshot,
  ) {
    final signals = <String>[];
    final recoveryScore = context.recoveryState.overallScore.round();

    switch (missionType) {

      case MissionType.recoverySession:
        // Primary: always emit the actual recovery score — this is the reason
        signals.add('Recovery at $recoveryScore% — lighter session needed');
        if (context.analyticsSnapshot.recoveryTrend == 'declining') {
          signals.add('Recovery trend is still declining');
        }
        if (context.recoveryState.highFatigue) {
          signals.add('Fatigue remains elevated');
        }
        break;

      case MissionType.protectRecovery:
        signals.add('Recovery at $recoveryScore% — protect it today');
        if (context.analyticsSnapshot.readinessScore < 45) {
          signals.add('Readiness is below normal');
        }
        if (context.predictiveSnapshot.recoveryCollapseRisk != RecoveryCollapseRisk.low) {
          signals.add('Recovery collapse risk is elevated');
        }
        break;

      case MissionType.deload:
        signals.add('Recovery at $recoveryScore% — accumulated fatigue detected');
        if (context.recoveryState.highFatigue) {
          signals.add('Fatigue load is high');
        }
        if (context.recoveryState.needsDeload) {
          signals.add('Recovery tracking advises a deload cycle');
        }
        break;

      case MissionType.pushPerformance:
        signals.add('Recovery at $recoveryScore% — ready to push');
        if (context.predictiveSnapshot.overloadReadiness == OverloadReadiness.prime) {
          signals.add('Performance window is open');
        }
        if (context.analyticsSnapshot.weeklyImprovementPct >= 5.0) {
          final pct = context.analyticsSnapshot.weeklyImprovementPct.toStringAsFixed(1);
          signals.add('Weekly improvement is at $pct%');
        }
        break;

      case MissionType.maintainConsistency:
        final disc = context.adherenceProfile.disciplineScore.round();
        signals.add('Discipline score at $disc%');
        if (athleteMemorySnapshot.consistencyScore >= 50) {
          signals.add('Routine is holding steady');
        }
        if (context.analyticsSnapshot.weeklyImprovementPct >= 0) {
          signals.add('Progress is tracking forward');
        }
        break;

      case MissionType.comeback:
        final days = context.workoutContext.daysSinceLastWorkout;
        signals.add('${days}d since last session');
        if (context.adherenceProfile.comebackProbability >= 0.7) {
          signals.add('Return likelihood is high');
        }
        break;

      case MissionType.volumeReduction:
        final risk = context.analyticsSnapshot.overtTrainingRisk.round();
        signals.add('Training load risk at $risk%');
        if (context.trainingAdjustment.volumeMultiplier < 0.9) {
          final cut = ((1.0 - context.trainingAdjustment.volumeMultiplier) * 100).round();
          signals.add('Volume reduced by $cut% from baseline');
        }
        break;

      case MissionType.homeAdaptation:
        signals.add('Session adapted for home or bodyweight training');
        if (context.trainingAdjustment.volumeMultiplier < 1.0) {
          final cut = ((1.0 - context.trainingAdjustment.volumeMultiplier) * 100).round();
          signals.add('Load already reduced by $cut%');
        }
        break;

      case MissionType.technique:
        final cons = athleteMemorySnapshot.consistencyScore.round();
        signals.add('Consistency at $cons% — form focus builds the base');
        if (context.adherenceProfile.consistencyIdentity == ConsistencyIdentity.streakChaser ||
            context.adherenceProfile.consistencyIdentity == ConsistencyIdentity.inconsistentSprinter) {
          signals.add('Quality over load right now');
        }
        break;
    }

    return signals;
  }

  List<String> _selectSuppressedSignals(
    DecisionContext context,
    AthleteMemorySnapshot athleteMemorySnapshot,
  ) {
    final suppressed = <String>[];

    if (context.recoveryState.isReadyToPush) {
      suppressed.add('Recovery urgency');
    }
    if (context.analyticsSnapshot.isOnPlateau) {
      suppressed.add('Plateau concern');
    }
    if (athleteMemorySnapshot.consistencyScore >= 70.0) {
      suppressed.add('Inconsistent routine');
    }
    if (context.adherenceProfile.comebackProbability < 0.4) {
      suppressed.add('Comeback urgency');
    }
    if (context.predictiveSnapshot.plateauProbability < 0.3) {
      suppressed.add('Immediate plateau risk');
    }

    return suppressed.take(3).toList();
  }

  List<String> _selectWarnings(
    DecisionConfidence confidence,
    DecisionContext context,
  ) {
    final warnings = <String>[];
    if (confidence.overallConfidence < 0.55) {
      warnings.add('Confidence is low because some signals are uncertain.');
    }
    if (context.analyticsSnapshot.cacheDate.isEmpty) {
      warnings.add('Analytics snapshot is missing freshness metadata.');
    }
    if (context.athleteTrend.progressionVelocity < 0.5) {
      warnings.add('History is short or progression is weak; the decision is based on limited data.');
    }
    return warnings;
  }

  String _buildSummary(
    MissionType missionType,
    List<String> dominantSignals,
    List<String> suppressedSignals,
    List<String> warnings,
    DecisionConfidence confidence,
  ) {
    final buffer = StringBuffer();
    buffer.write('Selected ${missionType.label} because ');
    buffer.write(dominantSignals.join(', ').toLowerCase());
    buffer.write('. ');
    buffer.write('This choice focuses on the strongest current signals. ');
    if (suppressedSignals.isNotEmpty) {
      buffer.write('It downplays ');
      buffer.write(suppressedSignals.join(', ').toLowerCase());
      buffer.write('. ');
    }
    buffer.write('Confidence is ${_format(confidence.overallConfidence)}.');
    if (warnings.isNotEmpty) {
      buffer.write(' Note: ');
      buffer.write(warnings.join(' '));
    }
    return buffer.toString();
  }

  String _buildRecommendation(MissionType missionType, List<String> dominantSignals) {
    return switch (missionType) {
      MissionType.protectRecovery => 'Keep intensity light and prioritize recovery today.',
      MissionType.maintainConsistency => 'Stick to the plan and preserve training rhythm.',
      MissionType.pushPerformance => 'Use the current window to make measurable progress.',
      MissionType.comeback => 'Focus on returning to training with manageable effort.',
      MissionType.deload => 'Lower volume and let your body recover before the next cycle.',
      MissionType.volumeReduction => 'Reduce load and avoid extra volume until signals improve.',
      MissionType.homeAdaptation => 'Use the available home-friendly setup and keep it balanced.',
      MissionType.technique => 'Prioritize skill, form, and controlled movement today.',
      MissionType.recoverySession => 'Choose a lighter session and emphasize recovery work.',
    };
  }

  String _buildConfidenceNarrative(DecisionConfidence confidence) {
    if (confidence.overallConfidence >= 0.8) {
      return 'The decision is strong because multiple signals align clearly.';
    }
    if (confidence.overallConfidence >= 0.6) {
      return 'The decision is reasonable, though some signals are less certain.';
    }
    return 'The decision is tentative due to limited or mixed signals.';
  }

  String _buildNextReview(DecisionConfidence confidence) {
    return confidence.overallConfidence >= 0.7
        ? 'Review this mission after the next training session.'
        : 'Review again once fresh analytics or recovery data is available.';
  }

  String _format(double value) => '${(value * 100).roundToDouble().toStringAsFixed(0)}%';
}

/// Immutable output for mission explanation.
class DecisionExplanation {
  final String title;
  final String summary;
  final List<String> dominantSignals;
  final List<String> suppressedSignals;
  final List<String> warnings;
  final String recommendation;
  final String confidenceNarrative;
  final String nextReview;

  const DecisionExplanation({
    required this.title,
    required this.summary,
    required this.dominantSignals,
    required this.suppressedSignals,
    required this.warnings,
    required this.recommendation,
    required this.confidenceNarrative,
    required this.nextReview,
  });
}
