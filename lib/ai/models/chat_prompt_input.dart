// lib/ai/models/chat_prompt_input.dart
// Pure Dart — no Flutter imports.
//
// ChatPromptInput — the single input contract for ChatPromptBuilder.
//
// The widget assembles this snapshot from AppProvider and hands it to
// ChatPromptBuilder.build(). The builder owns all trust decisions.
//
// Responsibility boundary:
//   Widget:  collects raw provider data, parses user message, pre-fetches
//            async observation. Then stops. No prompt logic in widgets.
//   Builder: receives this model and decides what Gemini sees.
//
// No maturity gate may be applied before this object reaches the builder.
// Pass all available data; the builder filters on AllowedClaims.

import '../../models/memory_models.dart';
import '../../models/models.dart';
import '../../services/training_intent_parser.dart';
import '../maturity/ai_maturity_state.dart';

class ChatPromptInput {
  /// The current AI maturity snapshot. The builder gates ALL personalisation
  /// decisions — context injection, language register, pattern claims — on the
  /// [allowedClaims] and [languageProfile] within this state.
  final AIMaturityState aiMaturity;

  // ── Static profile data ─────────────────────────────────────────────────
  // Always available; independent of training history depth.

  final UserProfile profile;
  final StreakData   streak;

  // ── Personal training signals ────────────────────────────────────────────
  // Injected only when [aiMaturity.allowedClaims.content.canInjectPersonalContext].

  final int                  recoveryScore;
  final double               readinessScore;
  final bool                 isFatigued;
  final bool                 needsDeloadByVolume;
  final List<MuscleRecovery> muscleRecoveryList;
  final List<String>         lastWorkoutNames;
  final String               weakMuscle;
  final bool                 isTravelMode;

  // ── Historical performance records ──────────────────────────────────────
  // Injected only when [aiMaturity.allowedClaims.content.canReferenceHistory].

  final List<ExerciseMemory> exerciseHistory;

  // ── Per-request context ─────────────────────────────────────────────────

  /// Messages already in the conversation — oldest first.
  /// Role values: 'user' | 'ai'.
  final List<Map<String, String>> conversationHistory;

  /// The user's current message.
  final String userMessage;

  /// Structured intent extracted from [userMessage].
  final TrainingIntent intent;

  /// A verified coach memory observation, or null if none available.
  /// Injected only when [aiMaturity.allowedClaims.content.canMakeObservation].
  final String? memoryObservation;

  const ChatPromptInput({
    required this.aiMaturity,
    required this.profile,
    required this.streak,
    required this.recoveryScore,
    required this.readinessScore,
    required this.isFatigued,
    required this.needsDeloadByVolume,
    required this.muscleRecoveryList,
    required this.exerciseHistory,
    required this.lastWorkoutNames,
    required this.weakMuscle,
    required this.isTravelMode,
    required this.conversationHistory,
    required this.userMessage,
    required this.intent,
    required this.memoryObservation,
  });
}
