// lib/ai/services/ai_prompt_builder.dart
//
// AIPromptBuilder — deterministic prompt construction for Gemini.
//
// This class converts an AICoachContext into an AIPrompt. It is the only
// layer that knows how to speak to Gemini, but it never calls Gemini.
//
// Design constraints:
//   - Pure deterministic. Same input always produces the same output.
//   - No randomness, no state, no side effects.
//   - No AI calls. No Provider. No Firebase. No UI.
//   - Gemini is a language renderer only; this builder enforces that role
//     by embedding hard rules directly into the system prompt.
//   - Business logic lives upstream (AthleteBrain, CoachBrain).
//     This builder only translates existing decisions into natural language
//     instructions — it never adds, infers, or overrides them.

import '../../coach/models/coach_intent.dart';
import '../../coach/models/coach_mode.dart';
import '../../services/adaptive_programming_service.dart';
import '../models/ai_coach_context.dart';
import '../models/ai_prompt.dart';

class AIPromptBuilder {
  const AIPromptBuilder();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Builds a fully-formed [AIPrompt] from [context].
  ///
  /// The returned prompt encodes all hard constraints in the system prompt
  /// and all athlete-specific context in the user prompt.
  /// Neither field is modified after construction.
  AIPrompt build(AICoachContext context) {
    return AIPrompt(
      systemPrompt: _systemPrompt,
      userPrompt:   _buildUserPrompt(context),
      maxWords:     120,
      temperature:  0.35,
      allowMarkdown: false,
      metadata:     _buildMetadata(context),
    );
  }

  // ── System prompt — static, same for every request ────────────────────────

  static const String _systemPrompt =
      'You are LiftOn Coach — an evidence-based strength and conditioning '
      'assistant embedded in the LiftOn training app.\n\n'
      'Your role is strictly to explain and encourage. '
      'You are NOT a decision maker.\n\n'
      'Hard rules — never violate these:\n'
      '- Do NOT change today\'s workout, volume, or intensity.\n'
      '- Do NOT contradict AthleteBrain or CoachBrain decisions.\n'
      '- Do NOT invent recovery data, training history, or physiological signals.\n'
      '- Do NOT recommend unsafe training under any circumstances.\n'
      '- Do NOT suggest exercises, sets, reps, or weights.\n'
      '- Do NOT use emojis.\n\n'
      'What you MAY do:\n'
      '- Explain today\'s mission in clear, natural language.\n'
      '- Encourage the athlete based on the provided context.\n'
      '- Summarize today\'s readiness in one or two sentences.\n'
      '- Explain why recovery or focus decisions were made.\n\n'
      'Style: professional, supportive, evidence-based. '
      'Short paragraphs. No bullet points in the response. '
      'Maximum response length: 120 words.';

  // ── User prompt — dynamic, assembled from AICoachContext ─────────────────

  String _buildUserPrompt(AICoachContext ctx) {
    final bd  = ctx.brainCardData;
    final msg = ctx.coachMessage;
    final mem = ctx.athleteMemorySnapshot;

    final buffer = StringBuffer();

    // ── Context block ─────────────────────────────────────────────────────
    buffer.writeln('Coach context for today:\n');
    buffer.writeln('Mission: ${bd.missionLabel}');
    buffer.writeln('Coach Mode: ${msg.tone.label}');
    buffer.writeln('Recovery: ${bd.recoveryScore}/100 — ${bd.recoveryLabel}');
    buffer.writeln('Confidence: ${bd.confidencePct}%');
    buffer.writeln('Athlete identity: ${_capitalize(bd.identityLabel)}');
    buffer.writeln('Recommended session: ${bd.preferredDurationMinutes} min');
    buffer.writeln('Primary action: ${msg.primaryAction}');
    buffer.writeln('Coaching intent: ${msg.intent.label}');
    buffer.writeln('Coach headline: ${msg.title}');
    buffer.writeln('Coach message: ${msg.subtitle}');

    // ── Memory signals (advisory context) ────────────────────────────────
    buffer.writeln('\nAthlete memory signals (long-term trends, advisory only):');
    buffer.writeln(
      'Consistency: ${_pct(mem.consistencyScore)} — '
      'Progression velocity: ${_pct(mem.progressionVelocity)} — '
      'Recovery velocity: ${_pct(mem.recoveryVelocity)}',
    );
    buffer.writeln(
      'Adherence: ${_pct(mem.adherenceScore)} — '
      'Reliability: ${_pct(mem.reliabilityScore)} — '
      'Volume tolerance: ${_pct(mem.volumeTolerance)}',
    );
    buffer.writeln(
      'Identity stage: ${mem.identityStage} — '
      'Experience: ${mem.experienceLevel}',
    );

    // ── Adaptive decision context ─────────────────────────────────────────
    buffer.writeln('\nAdaptive session decision:');
    buffer.writeln('Training focus: ${ctx.adaptiveDecision.focus.label}');
    if (ctx.adaptiveDecision.shouldModifyWorkout) {
      buffer.writeln(
        'Session is modified from the base plan. '
        'Intensity multiplier: '
        '${ctx.adaptiveDecision.intensityMultiplier.toStringAsFixed(2)} — '
        'Volume multiplier: '
        '${ctx.adaptiveDecision.volumeMultiplier.toStringAsFixed(2)}.',
      );
    }

    // ── Confidence breakdown ──────────────────────────────────────────────
    final conf = ctx.decisionConfidence;
    buffer.writeln('\nDecision confidence breakdown:');
    buffer.writeln(
      'Overall: ${_pct01(conf.overallConfidence)} — '
      'Recovery: ${_pct01(conf.recoveryConfidence)} — '
      'Analytics: ${_pct01(conf.analyticsConfidence)} — '
      'Behavior: ${_pct01(conf.behaviorConfidence)} — '
      'Memory: ${_pct01(conf.memoryConfidence)}',
    );

    // ── Conditional signals ───────────────────────────────────────────────
    if (msg.hasWarning) {
      buffer.writeln(
        '\nIMPORTANT: A recovery warning is active today. '
        'The athlete must prioritize protection over performance.',
      );
    }

    if (msg.isCelebration) {
      buffer.writeln(
        '\nNOTE: A peak performance window has been identified. '
        'The athlete may capitalize on this opportunity within the plan.',
      );
    }

    // ── Instruction ───────────────────────────────────────────────────────
    buffer.writeln(
      '\nUsing only the context above, explain today\'s mission naturally '
      'in under 120 words. Be professional, supportive, and evidence-based. '
      'Do not use emojis. Do not recommend specific exercises, sets, or weights.',
    );

    return buffer.toString().trim();
  }

  // ── Metadata ──────────────────────────────────────────────────────────────

  Map<String, String> _buildMetadata(AICoachContext ctx) {
    final bd  = ctx.brainCardData;
    final msg = ctx.coachMessage;
    return {
      'missionLabel':   bd.missionLabel,
      'coachMode':      msg.tone.label,
      'coachIntent':    msg.intent.label,
      'confidencePct':  bd.confidencePct.toString(),
      'recoveryScore':  bd.recoveryScore.toString(),
      'recoveryLabel':  bd.recoveryLabel,
      'identityLabel':  bd.identityLabel,
      'sessionMinutes': bd.preferredDurationMinutes.toString(),
      'hasWarning':     msg.hasWarning.toString(),
      'isCelebration':  msg.isCelebration.toString(),
      'priority':       msg.priority.toString(),
      'trainingFocus':  ctx.adaptiveDecision.focus.label,
    };
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  /// Format a [0, 1] score as a whole-number percentage string.
  static String _pct(double v) => '${(v * 100).round()}%';

  /// Format an already-percentage [0, 1] confidence value.
  static String _pct01(double v) => '${(v * 100).round()}%';

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
