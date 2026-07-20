// lib/services/training_adjustment_service.dart
// Pure Dart — no Flutter imports.
// Computes session-level training adjustments from recovery state and coach context.

import '../models/recovery_state.dart';
import '../models/coach_context.dart';
import '../models/models.dart';

// ── Exercise fatigue classification ──────────────────────────────────────────

enum _FatigueClass { axial, local, systemic }

const Map<String, _FatigueClass> _kExerciseFatigue = {
  'deadlift':          _FatigueClass.axial,
  'squat':             _FatigueClass.axial,
  'barbell row':       _FatigueClass.axial,
  'romanian deadlift': _FatigueClass.axial,
  'good morning':      _FatigueClass.axial,
  'overhead press':    _FatigueClass.axial,
  'bent over row':     _FatigueClass.axial,
  'pendlay row':       _FatigueClass.axial,
  'hack squat':        _FatigueClass.local,
  'leg press':         _FatigueClass.local,
  'split squat':       _FatigueClass.local,
  'lunge':             _FatigueClass.local,
  'step up':           _FatigueClass.local,
  'hip thrust':        _FatigueClass.local,
  'leg curl':          _FatigueClass.local,
  'leg extension':     _FatigueClass.local,
};

_FatigueClass _classify(String name) {
  final lower = name.toLowerCase();
  for (final e in _kExerciseFatigue.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return _FatigueClass.systemic;
}

// ── Rep range type ────────────────────────────────────────────────────────────

typedef RepRange = ({int low, int high});

const RepRange _kStrength    = (low: 3,  high: 6);
const RepRange _kHypertrophy = (low: 8,  high: 12);
const RepRange _kEndurance   = (low: 15, high: 20);
const RepRange _kRecovery    = (low: 12, high: 20);

RepRange _repRange(String goal, double score, bool deload) {
  if (deload || score < 45) return _kRecovery;
  switch (goal.toLowerCase()) {
    case 'strength':  return score >= 65 ? _kStrength : _kHypertrophy;
    case 'endurance': return _kEndurance;
    default:          return _kHypertrophy;
  }
}

// ── Output model ─────────────────────────────────────────────────────────────

class TrainingAdjustment {
  final double       intensityMultiplier;
  final double       volumeMultiplier;
  final RepRange     suggestedRepRange;
  final bool         shouldDeload;
  final bool         shouldReduceAxialLoad;
  final List<String> recommendedFocusMuscles;
  final List<String> suppressedMuscles;
  final String       readinessHeadline;
  final String       coachDirective;
  /// True when at least one parameter deviates from the baseline session plan.
  final bool         isModified;

  const TrainingAdjustment({
    required this.intensityMultiplier,
    required this.volumeMultiplier,
    required this.suggestedRepRange,
    required this.shouldDeload,
    required this.shouldReduceAxialLoad,
    required this.recommendedFocusMuscles,
    required this.suppressedMuscles,
    required this.readinessHeadline,
    required this.coachDirective,
    required this.isModified,
  });

  static const TrainingAdjustment baseline = TrainingAdjustment(
    intensityMultiplier:      1.0,
    volumeMultiplier:         1.0,
    suggestedRepRange:        _kHypertrophy,
    shouldDeload:             false,
    shouldReduceAxialLoad:    false,
    recommendedFocusMuscles:  <String>[],
    suppressedMuscles:        <String>[],
    readinessHeadline:        'Ready to train',
    coachDirective:           '',
    isModified:               false,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class TrainingAdjustmentService {
  TrainingAdjustmentService._();

  /// Computes session-level adjustments.
  /// Pass [day] to enable exercise-specific axial load screening.
  static TrainingAdjustment compute({
    required RecoveryState recovery,
    required CoachContext  context,
    DayPlan? day,
    bool canShowAdaptiveIncrease = false,
  }) {
    final score    = recovery.overallScore;
    final limiting = recovery.primaryLimitingMuscle;
    final bool peakUnlocked = score >= 90 && !recovery.highFatigue &&
        canShowAdaptiveIncrease;

    // ── Intensity multiplier ──────────────────────────────────────────────
    // 1.10 increase requires canShowAdaptiveIncrease — AI must know the
    // athlete well enough to push beyond planned load.
    final double intensityMult = peakUnlocked
        ? 1.10
        : score >= 75 ? 1.00
        : score >= 60 ? 0.92
        : score >= 45 ? 0.85
        : 0.75;

    // ── Volume multiplier ─────────────────────────────────────────────────
    final double volumeMult = recovery.needsDeload || score < 45
        ? 0.65
        : score < 60      ? 0.80
        : peakUnlocked    ? 1.10
        : 1.00;

    // ── Rep range ─────────────────────────────────────────────────────────
    final range = _repRange(context.goal, score, recovery.needsDeload);

    // ── Axial load screening ──────────────────────────────────────────────
    bool reduceAxial = limiting == 'back' || score < 45;
    if (!reduceAxial && day != null && score < 60) {
      reduceAxial =
          day.exercises.any((ex) => _classify(ex.name) == _FatigueClass.axial);
    }

    // ── Suppressed / recommended muscles ──────────────────────────────────
    final suppressed  = <String>[];
    final recommended = <String>[];
    for (final e in recovery.muscleScores.entries) {
      if (e.value < 45) {
        suppressed.add(e.key);
      } else if (e.value >= 80) {
        recommended.add(e.key);
      }
    }

    // ── Directive copy ────────────────────────────────────────────────────
    final (headline, directive) = _messaging(
      score:                   score,
      limiting:                limiting,
      needsDeload:             recovery.needsDeload,
      highFatigue:             recovery.highFatigue,
      goal:                    context.goal,
      level:                   context.level,
      canShowAdaptiveIncrease: canShowAdaptiveIncrease,
    );

    final modified = intensityMult != 1.0 ||
        volumeMult != 1.0 ||
        reduceAxial ||
        recovery.needsDeload ||
        suppressed.isNotEmpty;

    return TrainingAdjustment(
      intensityMultiplier:     intensityMult,
      volumeMultiplier:        volumeMult,
      suggestedRepRange:       range,
      shouldDeload:            recovery.needsDeload,
      shouldReduceAxialLoad:   reduceAxial,
      recommendedFocusMuscles: recommended,
      suppressedMuscles:       suppressed,
      readinessHeadline:       headline,
      coachDirective:          directive,
      isModified:              modified,
    );
  }

  /// Returns the fatigue class name for an exercise — useful for UI badges.
  static String fatigueClass(String exerciseName) =>
      _classify(exerciseName).name;

  static (String, String) _messaging({
    required double score,
    required String limiting,
    required bool   needsDeload,
    required bool   highFatigue,
    required String goal,
    required String level,
    required bool   canShowAdaptiveIncrease,
  }) {
    if (needsDeload) {
      return (
        'Deload week — movement quality over load',
        'Keep spinal loading controlled. Trim sets to 60% of normal. No training to failure today.',
      );
    }
    // Overload message is an increase prescription — requires canShowAdaptiveIncrease.
    // Without it, a high recovery score still earns "Ready to train effectively".
    if (score >= 90 && !highFatigue && canShowAdaptiveIncrease) {
      return (
        'Peak readiness — overload is on the table',
        'Recovery is elevated — today supports overload work. Push compound lifts and chase new rep targets.',
      );
    }
    if (score >= 75) {
      return (
        'Ready to train effectively',
        'Good training window. Maintain intensity and hit your planned volume.',
      );
    }
    if (score >= 60) {
      if (limiting == 'back') {
        return (
          'Back fatigue elevated — manage spinal load',
          'Keep spinal loading controlled today. Prioritize chest-supported alternatives over rows and deadlifts.',
        );
      }
      if (limiting == 'legs') {
        return (
          'Legs still recovering — redirect loading',
          'Legs need more time. Redirect to upper body or machine-based work.',
        );
      }
      return (
        'Moderate fatigue — trim junk volume',
        'Maintain intensity but trim junk volume. Quality sets over quantity.',
      );
    }
    if (score >= 45) {
      return (
        'Elevated fatigue — reduce compound exposure',
        'System fatigue is elevated. Stick to machines and cables. Avoid heavy compound lifts.',
      );
    }
    return (
      'Suppressed — active recovery only',
      'Your system needs rest more than loading. Light movement, stretching, or a shorter machine-only session.',
    );
  }
}
