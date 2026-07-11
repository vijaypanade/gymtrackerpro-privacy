// lib/ai/models/ai_prompt.dart
//
// AIPrompt — immutable prompt contract passed to the Gemini service.
//
// AIPromptBuilder produces this object. The Gemini service (Phase 3)
// consumes it. Nothing in between modifies it.
//
// No Provider. No Firebase. No networking. No UI.

import 'package:flutter/foundation.dart';

@immutable
class AIPrompt {
  /// Static system instructions that constrain Gemini's role and behaviour.
  /// Sent as the "system" role in the Gemini request.
  final String systemPrompt;

  /// Dynamic context block assembled from today's intelligence pipeline.
  /// Sent as the "user" role in the Gemini request.
  final String userPrompt;

  /// Target response length in words. Enforced via system prompt instruction.
  final int maxWords;

  /// Sampling temperature. Low values (≤ 0.4) favour consistency and
  /// factual adherence; higher values increase creativity.
  /// Range: 0.0–2.0 (Gemini API convention).
  final double temperature;

  /// Whether Gemini may use Markdown in its response.
  /// False by default — plain prose is preferred for in-app display.
  final bool allowMarkdown;

  /// Optional key/value pairs for logging, tracing, and analytics.
  /// Never sent to Gemini; consumed by the client layer only.
  final Map<String, String>? metadata;

  const AIPrompt({
    required this.systemPrompt,
    required this.userPrompt,
    required this.maxWords,
    required this.temperature,
    required this.allowMarkdown,
    this.metadata,
  }) : assert(maxWords > 0,        'maxWords must be positive'),
       assert(temperature >= 0.0,  'temperature must be >= 0.0'),
       assert(temperature <= 2.0,  'temperature must be <= 2.0');

  @override
  String toString() =>
      'AIPrompt(maxWords:$maxWords temperature:$temperature '
      'markdown:$allowMarkdown metadata:${metadata?.length ?? 0} keys)';
}
