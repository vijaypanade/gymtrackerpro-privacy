// lib/ai/services/gemini_coach_service.dart
//
// GeminiCoachService — the single integration point between the
// deterministic intelligence pipeline and the Gemini backend.
//
// Responsibilities:
//   1. Accept an AICoachContext (already assembled by the caller).
//   2. Use AIPromptBuilder to produce an AIPrompt — the ONLY prompt source.
//   3. Combine systemPrompt + userPrompt into the format ApiService expects.
//   4. Call ApiService.askAI with AiRequestType.brief (short coach insight).
//   5. Return the Gemini response on success.
//   6. Fall back to CoachMessage.subtitle when Gemini fails or is suppressed.
//
// Gemini's role:
//   - Explain today's mission.
//   - Describe current recovery status in natural language.
//   - Reflect the coach recommendation in plain prose.
//   - Provide encouragement aligned with the coach intent.
//   - Nothing else. It CANNOT change workout decisions.
//
// What this service does NOT do:
//   - Build business logic.
//   - Read from AppProvider, Firestore, or Hive.
//   - Modify AthleteBrain, CoachBrain, AthleteMemory, or WeeklyReview.
//   - Inject quota, cooldown, or kill-switch logic (ApiService owns that).

import 'package:flutter/foundation.dart' show debugPrint;

import '../../services/api_service.dart';
import '../../services/ai_quota_service.dart';
import '../models/ai_coach_context.dart';
import 'ai_prompt_builder.dart';

class GeminiCoachService {
  const GeminiCoachService();

  static const _builder = AIPromptBuilder();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches a Gemini-generated coach verdict for today.
  ///
  /// Returns Gemini's response string on success.
  /// Returns [fallback] if Gemini is unavailable, rate-limited, or fails.
  /// Never throws.
  Future<String> fetchVerdict({
    required AICoachContext context,
    required String fallback,
    bool isPremium = false,
  }) async {
    try {
      final prompt = _builder.build(context);
      final combined = _combinePrompt(prompt.systemPrompt, prompt.userPrompt);

      debugPrint('[Gemini] Sending coach verdict request '
          '(maxWords:${prompt.maxWords} temperature:${prompt.temperature})');

      final result = await ApiService.askAI(
        combined,
        type:      AiRequestType.brief,
        isPremium: isPremium,
      );

      if (_isFailure(result)) {
        debugPrint('[Gemini] verdict failed — using fallback. reason: $result');
        return _sanitiseFallback(fallback);
      }

      debugPrint('[Gemini] verdict OK (${result.length} chars)');
      return result.trim();

    } catch (e, st) {
      debugPrint('[Gemini] unexpected error: $e\n$st');
      return _sanitiseFallback(fallback);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Combines systemPrompt + userPrompt into the single string ApiService
  /// accepts. The system block is prefixed with a clear role marker so the
  /// Cloud Function can parse it if needed; the user block follows.
  static String _combinePrompt(String systemPrompt, String userPrompt) {
    return 'SYSTEM:\n$systemPrompt\n\nUSER:\n$userPrompt';
  }

  /// ApiService returns ⚠️-prefixed strings on all failure paths.
  static bool _isFailure(String response) =>
      response.isEmpty || response.startsWith('⚠️');

  /// Strips any leading error markers from the fallback before returning it.
  static String _sanitiseFallback(String raw) =>
      raw.startsWith('⚠️') ? raw.substring(2).trim() : raw.trim();
}
