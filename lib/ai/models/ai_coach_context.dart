// lib/ai/models/ai_coach_context.dart
//
// AICoachContext — single immutable input contract for the AI prompt layer.
//
// This model aggregates all deterministic signals produced by the intelligence
// pipeline (RecoveryEngine → Analytics → AthleteMemory → AthleteBrain →
// CoachBrain) and passes them to AIPromptBuilder.
//
// Gemini receives only what is in this object. It can explain; it cannot decide.
//
// No Provider. No Firebase. No networking. No UI.

import 'package:flutter/foundation.dart';

import '../../brain/confidence/decision_confidence_engine.dart';
import '../../brain/models/brain_card_data.dart';
import '../../coach/models/coach_context.dart';
import '../../coach/models/coach_message.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../services/adaptive_programming_service.dart';
import '../maturity/ai_maturity_state.dart';

@immutable
class AICoachContext {
  /// The deterministic coaching message produced by CoachBrainService.
  final BrainCoachMessage coachMessage;

  /// The assembled input context that CoachBrainService consumed.
  final CoachBrainContext coachBrainContext;

  /// Long-term EMA memory: consistency, progression velocity, etc. [0, 1].
  final AthleteMemorySnapshot athleteMemorySnapshot;

  /// The adaptive session decision produced by AthleteBrainService.
  final AdaptiveWorkoutDecision adaptiveDecision;

  /// Mission, identity, confidence, and recovery packaged for display.
  final BrainCardData brainCardData;

  /// Per-dimension confidence breakdown from DecisionConfidenceEngine.
  final DecisionConfidence decisionConfidence;

  /// Current AI maturity snapshot. Governs language register and claim
  /// authority for any AI surface that uses this context.
  final AIMaturityState aiMaturity;

  const AICoachContext({
    required this.coachMessage,
    required this.coachBrainContext,
    required this.athleteMemorySnapshot,
    required this.adaptiveDecision,
    required this.brainCardData,
    required this.decisionConfidence,
    required this.aiMaturity,
  });
}
