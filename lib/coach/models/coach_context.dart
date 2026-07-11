// lib/coach/models/coach_context.dart
//
// CoachBrainContext — immutable input contract for CoachBrainService.
// Composes the four domain signals the coach needs without introducing
// any Provider, Firebase, or UI dependencies.

import 'package:flutter/foundation.dart';

import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adaptive_programming_service.dart';
import '../../models/recovery_state.dart';
import '../../brain/confidence/decision_confidence_engine.dart';

@immutable
class CoachBrainContext {
  /// Long-term EMA memory: consistency, progression, recovery velocity, etc.
  /// All score fields are in [0, 1].
  final AthleteMemorySnapshot athleteMemorySnapshot;

  /// Adaptive session decision produced by AthleteBrainService.
  final AdaptiveWorkoutDecision adaptiveDecision;

  /// Current physiological recovery state.
  final RecoveryState recoveryState;

  /// Confidence breakdown from DecisionConfidenceEngine.
  final DecisionConfidence decisionConfidence;

  const CoachBrainContext({
    required this.athleteMemorySnapshot,
    required this.adaptiveDecision,
    required this.recoveryState,
    required this.decisionConfidence,
  });
}
