// lib/models/workout_readiness_profile.dart
// Pure Dart — no Flutter imports.
// Computed by AdaptiveScheduleEngine; consumed by AIProvider prompt builder
// and (future) planner UI readiness surface.

// ── Single muscle's training allocation for this week ──────────────────────

class MuscleSlot {
  final String muscle;
  final int targetSets; // total sets this week for this muscle

  const MuscleSlot({required this.muscle, required this.targetSets});
}

// ── Full adaptive scheduling decision for the current week ─────────────────

class WorkoutReadinessProfile {
  /// Raw overall score from RecoveryEngine (0–100).
  final double overallScore;

  /// Training days recommended this week — may be less than user's selectedDays
  /// when recovery is suppressed.
  final int effectiveDaysThisWeek;

  /// 0–100 proxy for how much training data backs this computation.
  /// Low = AI is still learning; High = fully calibrated to this athlete.
  final int confidenceScore;

  /// One-sentence summary for user display (generated in Dart, not by AI).
  final String readinessExplanation;

  /// True when a structural deload is warranted (volume spike + suppressed score).
  final bool isDeloadWeek;

  /// Per-muscle volume scaling: 0.0 (exclude) → 1.0 (full volume).
  /// Keys match RecoveryEngine muscle names (chest, back, legs, shoulders,
  /// biceps, triceps, core, calves, arms, cardio).
  final Map<String, double> volumePercentByMuscle;

  /// Ordered list of muscles to schedule, highest recovery first.
  /// Muscles with volumePercent == 0.0 are excluded.
  final List<MuscleSlot> muscleSlots;

  const WorkoutReadinessProfile({
    required this.overallScore,
    required this.effectiveDaysThisWeek,
    required this.confidenceScore,
    required this.readinessExplanation,
    required this.isDeloadWeek,
    required this.volumePercentByMuscle,
    required this.muscleSlots,
  });
}
