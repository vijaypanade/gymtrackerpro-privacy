// lib/ai/services/chat_prompt_builder.dart
//
// ChatPromptBuilder — maturity-aware chat prompt construction for AI Chat.
//
// Architecture:
//   AIMaturityState → AllowedClaims + LanguageProfile → prompt sections
//
// Design constraints:
//   - Pure deterministic. Same input always produces the same output.
//   - No randomness, no state, no side effects.
//   - No AI calls. No Provider. No Firebase. No UI.
//   - This builder is the ONLY location where maturity translates into
//     prompt language and data injection decisions for AI Chat.
//   - Widgets pass raw data; this builder decides what Gemini sees.
//   - ClaimCategory annotations mark the epistemic level of each section.
//   - No maturity threshold may be duplicated in the widget.

import '../../services/training_intent_parser.dart';
import '../maturity/allowed_claims.dart';
import '../maturity/claim_category.dart';
import '../maturity/language_profile.dart';
import '../models/chat_prompt_input.dart';

class ChatPromptBuilder {
  const ChatPromptBuilder();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Builds the full Gemini prompt string from [ctx].
  ///
  /// The returned string encodes all maturity-based trust decisions.
  /// Callers pass it directly to ApiService.askAI — no further filtering.
  String build(ChatPromptInput ctx) {
    final buf     = StringBuffer();
    final claims  = ctx.aiMaturity.allowedClaims;
    final lang    = ctx.aiMaturity.languageProfile;
    final profile = ctx.profile;

    _appendIdentity(buf);
    _appendLanguageRegister(buf, lang);
    _appendExpertiseMode(buf, ctx.userMessage);
    _appendEquipmentConstraints(buf, ctx.userMessage);
    _appendTrainingIntentConstraints(buf, ctx.intent);
    _appendConsistencyPsychology(buf);
    _appendUserProfile(buf, profile, ctx.streak);
    _appendProductRules(buf, profile);
    _appendPersonalContext(buf, ctx, claims);
    _appendConversationContext(buf, ctx.conversationHistory, profile, ctx.userMessage);
    _appendMemoryObservation(buf, ctx.memoryObservation, claims);

    buf.writeln('User just asked: "${ctx.userMessage}"');
    return buf.toString().trim();
  }

  // ── LAYER 1: Identity ─────────────────────────────────────────────────────

  void _appendIdentity(StringBuffer buf) {
    buf.writeln('You are LiftOn Coach — a calm, experienced strength coach.');
    buf.writeln('Personality: quiet confidence, like a coach who has trained hundreds. '
        'NO fluff, NO lecture, NO report tone.');
    buf.writeln();
    buf.writeln('COMMUNICATION STYLE:');
    buf.writeln('- Sound like a calm, premium fitness coach.');
    buf.writeln('- Be concise, confident, and practical.');
    buf.writeln('- Avoid excessive slang, hype, or motivational clichés.');
    buf.writeln('- Use short, scan-friendly responses.');
    buf.writeln('- Never sound childish, aggressive, or overly emotional.');
    buf.writeln('- Prioritize clarity and coaching quality over personality.');
    buf.writeln();
  }

  // ── Language Register — derived from LanguageProfile ─────────────────────
  //
  // This section translates the maturity phase into concrete language rules
  // for Gemini. The AI must never use a register beyond what it has earned.

  void _appendLanguageRegister(StringBuffer buf, LanguageProfile lang) {
    buf.writeln('LANGUAGE REGISTER — ${lang.phaseLabel}:');

    if (lang.requiresHedging) {
      buf.writeln('- Use tentative language. Never state certainties about '
          "this athlete's patterns or tendencies.");
      buf.writeln("- Avoid: \"you always\", \"you never\", \"I know that you...\"");
    }

    if (!lang.canAddressAthleteDirectly) {
      buf.writeln('- Do NOT use "you" or "your". Use impersonal framing: '
          '"The data suggests...", "Recovery today...", "Training today..."');
    } else {
      buf.writeln('- You may address the athlete directly: "you", "your".');
    }

    // ClaimCategory.pattern — requires canUsePatternLanguage
    if (lang.canUsePatternLanguage) {
      buf.writeln('- Pattern language PERMITTED. When referencing observations, '
          'open with: "${lang.openingStyle}..."');
      if (lang.evidencePrefix.isNotEmpty) {
        buf.writeln('- When citing history: "${lang.evidencePrefix}..."');
      }
    } else {
      buf.writeln('- Pattern language BANNED. Do NOT use "you usually...", '
          '"you tend to...", or imply recurring habits.');
    }

    // ClaimCategory.prediction — requires canUsePredictionLanguage
    if (lang.canUsePredictionLanguage) {
      buf.writeln('- Forward projection PERMITTED: "I expect...", '
          '"Based on your trend..."');
    } else {
      buf.writeln('- Forward projection BANNED. Do not forecast future '
          'sessions or outcomes.');
    }

    buf.writeln();
  }

  // ── LAYER 2: Expertise mode ───────────────────────────────────────────────
  //
  // Switches between workout-plan format and conversational coaching voice.
  // ClaimCategory.prescription — workout plans are direct prescriptions.

  void _appendExpertiseMode(StringBuffer buf, String userMessage) {
    final lower = userMessage.toLowerCase();
    if (_wantsWorkoutPlan(lower)) {
      buf.writeln('EXPERTISE MODE: Workout Planning (COACH VOICE — strict format)');
      buf.writeln('');
      buf.writeln('OUTPUT FORMAT (follow EXACTLY):');
      buf.writeln('Line 1: One-line opener with address + readiness comment (max 12 words).');
      buf.writeln('Line 2: Blank.');
      buf.writeln('Then EXACTLY this template for each exercise (no deviations):');
      buf.writeln('1. [EXERCISE_NAME] — [SETS]x[REPS], RIR [N]');
      buf.writeln('   [SHORT_TIP under 8 words]');
      buf.writeln('');
      buf.writeln('CRITICAL: Exercise name is MANDATORY on every line.');
      buf.writeln('NEVER output just "3x10, RIR 2" without a name.');
      buf.writeln('Use real exercise names: Bench Press, Squat, Pull-up, Deadlift, etc.');
      buf.writeln('');
      buf.writeln('Real example output:');
      buf.writeln('1. Goblet Squat — 3x12, RIR 2');
      buf.writeln('   Knees out, chest tall.');
      buf.writeln('2. Push-up — 3x10, RIR 2');
      buf.writeln('   Slow down, fast up.');
      buf.writeln('3. Dumbbell Row — 3x12 each, RIR 2');
      buf.writeln('   Squeeze the back.');
      buf.writeln('');
      buf.writeln('Final line: One-line closer (max 10 words).');
      buf.writeln('');
      buf.writeln('FORMAT RULES (hard limits):');
      buf.writeln('- NO long "Why" paragraphs. ONE tip per exercise, ≤8 words.');
      buf.writeln('- NO warm-up/cool-down sections unless explicitly asked.');
      buf.writeln('- NO "Recovery Note" / "Sleep advice" unless explicitly asked.');
      buf.writeln('- NO food advice in workout plans.');
      final exCount = RegExp(r'\b(\d+)\s+exercise').firstMatch(lower);
      final nEx    = exCount != null ? int.tryParse(exCount.group(1) ?? '0') ?? 0 : 0;
      final limit  = nEx >= 5 ? 300 : (nEx >= 3 ? 220 : 150);
      buf.writeln('- Total reply MUST fit in $limit words.');
      buf.writeln('- Match user level — never overload beginners.');
      buf.writeln('- Progress weights gradually using the recovery data below.');
    } else {
      buf.writeln('EXPERTISE MODE: Conversational Coaching');
      buf.writeln('- Length: simple questions under 40 words; normal replies '
          '40–90 words; complex topics max 150 words. Never walls of text.');
      buf.writeln('- Coach voice: short, direct, action-first. Natural paragraph breaks.');
      buf.writeln('- CLARIFY BEFORE ASSUMING: if the user sends only 1–2 words '
          '("bench", "protein", "legs"), ask one short clarifying question first.');
      buf.writeln('- FOLLOW-UP VARIETY: end ~70% of replies with one short question. '
          'Close ~20% with a quiet line ("See how that feels.", "I\'d start there."). '
          'Occasionally (~10%) no follow-up. Never two questions in one reply.');
      buf.writeln('- Use bullets only if listing 3+ items.');
      buf.writeln('- If you don\'t know, say so — never invent science.');
      buf.writeln('- BANNED WORDS (never use): optimal, hypertrophy, progressive '
          'overload, adaptation, muscle synthesis, active recovery, '
          '"fatigue detected", readiness, "recovery score".');
      buf.writeln('- NEVER quote scores, percentages, or numbers from the data '
          'below unless the user explicitly asks for numbers.');
      buf.writeln('- Speak conclusions, not metrics: say "your body needs a '
          'lighter day", never "readiness is 46/100".');
    }
    buf.writeln();
  }

  // ── Equipment constraints ─────────────────────────────────────────────────

  void _appendEquipmentConstraints(StringBuffer buf, String userMessage) {
    final lower = userMessage.toLowerCase();
    final wantsBW = lower.contains('bodyweight') ||
        lower.contains('body weight')   ||
        lower.contains('no equipment')  ||
        lower.contains('home workout')  ||
        lower.contains('without gym');
    if (!wantsBW) return;

    buf.writeln('EQUIPMENT CONSTRAINT: BODYWEIGHT ONLY');
    buf.writeln('- User wants NO EQUIPMENT workout (home/bodyweight).');
    buf.writeln('- USE ONLY: Push-ups, Pull-ups, Chin-ups, Dips, Squats,');
    buf.writeln('  Lunges, Planks, Crunches, Burpees, Mountain Climbers,');
    buf.writeln('  Pike Push-ups, Diamond Push-ups, Jumping Jacks,');
    buf.writeln('  Glute Bridges, Supermans, Leg Raises, Wall Sit.');
    buf.writeln('- DO NOT include ANY barbell/dumbbell/machine exercises.');
    buf.writeln('- Always use proper exercise names (e.g. "Push-up", "Plank").');
    buf.writeln();
  }

  // ── Training intent hard constraints ─────────────────────────────────────

  void _appendTrainingIntentConstraints(StringBuffer buf, TrainingIntent intent) {
    final block = TrainingIntentParser.buildConstraintBlock(intent);
    if (block.isNotEmpty) buf.writeln(block);
  }

  // ── LAYER 3: Consistency psychology ──────────────────────────────────────

  void _appendConsistencyPsychology(StringBuffer buf) {
    buf.writeln('PSYCHOLOGY RULES (very important):');
    buf.writeln('- Celebrate small wins (streak milestones, PRs, comeback days).');
    buf.writeln('- After missed days: NO guilt-tripping. Frame it as "comeback energy".');
    buf.writeln('- Build identity, not just habits: "You ARE someone who trains hard."');
    buf.writeln('- Use streak data to fuel momentum talk when streak ≥ 3 days.');
    buf.writeln('- If user sounds demotivated: acknowledge feelings first, '
        'then redirect to one small action.');
    buf.writeln('- Never shame body type, weight, or starting point.');
    buf.writeln();
    buf.writeln();
  }

  // ── User profile — ClaimCategory.data ─────────────────────────────────────
  //
  // Static profile facts: always injected, independent of maturity.
  // These are biographical, not analytical — they carry no AI authority claim.

  void _appendUserProfile(StringBuffer buf, dynamic pf, dynamic streak) {
    buf.writeln('USER PROFILE (use this to personalize ALL advice):');
    buf.writeln('- Name: ${pf.name}');
    buf.writeln('- Age: ${pf.age}, Gender: ${pf.gender}');
    buf.writeln('- Weight: ${pf.weightKg}kg, Height: ${pf.heightCm}cm');
    buf.writeln('- BMI: ${pf.bmi.toStringAsFixed(1)} (${pf.bmiCategory})');
    buf.writeln('- BMR: ${pf.bmr.toStringAsFixed(0)} kcal/day');
    buf.writeln('- Activity Level: ${pf.activityLevel}');
    buf.writeln('- Goal: ${pf.goal}');
    buf.writeln('- Level: ${pf.level}');
    buf.writeln('- Diet Preference: ${pf.dietPreference} (veg/nonveg/eggetarian)');
    buf.writeln('- Country: ${(pf.country as String).isEmpty ? 'Unknown' : pf.country}');
    buf.writeln('- Weight unit: ${pf.weightUnit} (use this unit for all weight suggestions)');
    buf.writeln('- Trainer style: ${pf.trainerType}');
    buf.writeln('- Streak: ${streak.currentStreak} days');
    buf.writeln('- Total workouts: ${streak.totalWorkouts}');
    buf.writeln();
  }

  // ── Product rules and regional diet constraints ───────────────────────────

  void _appendProductRules(StringBuffer buf, dynamic pf) {
    final hasName    = (pf.name as String).isNotEmpty && pf.name != 'Champion';
    final hasAge     = (pf.age as int) > 0 && pf.age != 25;
    final hasWeight  = (pf.weightKg as double) > 0 && pf.weightKg != 70.0;
    final hasHeight  = (pf.heightCm as double) > 0 && pf.heightCm != 170.0;
    if (!(hasName && hasAge && hasWeight && hasHeight)) {
      buf.writeln('⚠️ IMPORTANT: User profile is INCOMPLETE.');
      buf.writeln('If user asks for personalized advice — DO NOT guess. Politely ask them '
          'to update their Profile tab with: age, weight, height, and goal. '
          'Keep it friendly, 2 sentences max.');
      buf.writeln();
    }

    buf.writeln('IMPORTANT PRODUCT RULE:');
    buf.writeln('- DO NOT generate full diet plans inside chat.');
    buf.writeln('- DO NOT generate full workout plans inside chat.');
    buf.writeln('- If user asks for diet plan, meal plan, calorie plan, '
        'bulking diet, or fat loss diet:');
    buf.writeln('  Give general guidance (macros, food types, timing). '
        'LiftOn does not have a diet planner feature.');
    buf.writeln('- If user asks for workout plan, split, PPL routine, bro split, '
        'weekly schedule, or training program:');
    buf.writeln('  Redirect them to Planner or Tools — it creates more structured, '
        'personalised plans. Mention splits like Push Pull Legs, Upper Lower, Bro Split.');
    buf.writeln('- Keep the reply short, premium, and confident.');
    buf.writeln('- You MAY still answer general nutrition questions.');
    buf.writeln();

    final country = (pf.country as String).isEmpty ? 'an unspecified country' : pf.country;
    buf.writeln('- User is from $country. Suggest foods commonly available there, '
        'matching their cuisine preference (${pf.cuisinePreference}).');
    buf.writeln('- Respect dietPreference: if "veg" → NEVER suggest meat/fish/egg.');
    buf.writeln('- If "eggetarian" → eggs OK but no meat/fish.');
    buf.writeln('- If "nonveg" → all foods OK.');
    buf.writeln('- Suggest affordable, practical, locally available whole foods.');
  }

  // ── Personal context — gated entirely by AIMaturity ───────────────────────
  //
  // This is the trust boundary.
  //
  // When canInjectPersonalContext = false: the AI must remain a general coach.
  // No training history, no recovery signals, no personal data of any kind.
  //
  // When true: recovery DATA is injected. Further gates apply per claim type:
  //   Exercise history → canReferenceHistory  (ClaimCategory.data from past sessions)
  //   Memory observation → canMakeObservation (ClaimCategory.observation)

  void _appendPersonalContext(
      StringBuffer buf, ChatPromptInput ctx, AllowedClaims claims) {
    if (!claims.content.canInjectPersonalContext) {
      // ClaimCategory: none — no personal training DATA may reach Gemini yet.
      // The athlete's data is insufficient for reliable AI insights.
      buf.writeln('\nCOACHING MODE: General fitness guidance.');
      buf.writeln("This athlete's personal training data is not yet deep enough "
          'for AI insights.');
      buf.writeln('- Coach as a knowledgeable general strength expert.');
      buf.writeln('- Do NOT mention recovery percentages, readiness scores, '
          'or volume trends.');
      buf.writeln('- Do NOT imply familiarity with this athlete\'s history or body.');
      buf.writeln('- Encourage logging sessions so the AI can build a personal read.');
      buf.writeln();
      return;
    }

    // ── ClaimCategory.data — current recovery signals ─────────────────────
    buf.writeln('\nRECOVERY DATA (INTERNAL ONLY — inform your advice, '
        'NEVER quote these numbers or terms to the user):');
    buf.writeln('- Recovery Score: ${ctx.recoveryScore}/100');
    buf.writeln('- Training Readiness: ${ctx.readinessScore.toStringAsFixed(0)}/100');
    buf.writeln('  → 85+ = good day to push hard');
    buf.writeln('  → 60–84 = normal training');
    buf.writeln('  → 30–59 = keep it light, focus on form');
    buf.writeln('  → <30 = suggest rest');
    buf.writeln('- Volume Trend: ${ctx.needsDeloadByVolume ? "DROPPING — recommend deload" : "Stable/growing"}');
    if (ctx.lastWorkoutNames.isNotEmpty) {
      buf.writeln('- Last workout: ${ctx.lastWorkoutNames.first}');
    }
    if (ctx.weakMuscle.isNotEmpty) {
      buf.writeln('- Weakest muscle: ${ctx.weakMuscle}');
    }
    buf.writeln('- Current fatigue: ${ctx.isFatigued ? "High" : "Normal"}');
    buf.writeln('- Needs deload: ${ctx.needsDeloadByVolume}');
    buf.writeln('- Recent workouts: ${ctx.lastWorkoutNames.take(5).join(", ")}');

    // ── ClaimCategory.data — per-muscle recovery scores ───────────────────
    if (ctx.muscleRecoveryList.isNotEmpty) {
      buf.writeln('');
      buf.writeln('MUSCLE-BY-MUSCLE RECOVERY '
          '(critical — use for muscle-specific advice):');
      for (final mr in ctx.muscleRecoveryList) {
        buf.writeln('- ${mr.muscle}: ${mr.recoveryScore}% '
            '${mr.emoji} ${mr.status} (last trained ${mr.lastTrainedDate})');
      }
      buf.writeln('→ NEVER suggest training a muscle below 40% recovery.');
      buf.writeln('→ If user asks what to train today → pick highest-% muscles.');
    }

    // ── ClaimCategory.data — historical performance records ────────────────
    // Gated on canReferenceHistory: the AI may cite specific past sessions
    // only once enough sessions exist to make the reference meaningful.
    if (claims.content.canReferenceHistory && ctx.exerciseHistory.isNotEmpty) {
      buf.writeln('');
      buf.writeln('EXERCISE HISTORY — last 21 days '
          '(use for weight recommendations):');
      for (final ex in ctx.exerciseHistory) {
        if (ex.unit == 'kg' && ex.bestWeight > 0) {
          buf.writeln('- ${ex.name}: best ${ex.bestWeight}kg × ${ex.bestReps} reps');
        } else if (ex.bestReps > 0) {
          buf.writeln('- ${ex.name}: best ${ex.bestReps} reps (bodyweight)');
        }
      }
      buf.writeln('→ When user asks weight for a listed exercise → '
          'suggest best + 2.5kg if recovery ≥ 60%.');
      buf.writeln('→ If same weight 3+ sessions → flag stagnation, '
          'suggest a small increase or technique change.');
    }

    buf.writeln();

    // ── Trainer decision rules — available once personal context is earned ──
    buf.writeln('TRAINER DECISION RULES (apply to all workout advice):');
    buf.writeln('- If readiness < 30 → STRONGLY suggest rest/walk/mobility only.');
    buf.writeln('- If readiness 30–59 → suggest 60% intensity, technique focus, RIR 3–4.');
    buf.writeln('- If readiness 60–84 → normal session, RIR 1–2 on top sets.');
    buf.writeln('- If readiness 85+ → green light for PR attempt or heavy day.');
    buf.writeln('- If needsDeload = true → MANDATORY mention deload this week.');
    buf.writeln('- If weakMuscle is set → prioritize it 2×/week, mention by name.');
    buf.writeln('- Let the data shape your advice silently — the user should '
        'feel understood, not measured.');
    buf.writeln();
  }

  // ── Conversation continuity ───────────────────────────────────────────────

  void _appendConversationContext(
      StringBuffer buf,
      List<Map<String, String>> history,
      dynamic profile,
      String currentText) {
    if (history.isEmpty) return;

    final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
    final older  = history.length > 6 ? history.sublist(0, history.length - 6)
                                       : const <Map<String, String>>[];

    if (older.isNotEmpty) {
      buf.writeln('CONVERSATION SUMMARY:');
      buf.writeln('- User goal: ${profile.goal}; '
          'level: ${profile.level}; diet: ${profile.dietPreference}.');
      buf.writeln('- Current topic: ${_topicFor(currentText, older)}.');
      final constraints = _constraintsFromHistory(older);
      if (constraints.isNotEmpty) {
        buf.writeln('- Important constraints: $constraints.');
      }
    }

    buf.writeln('RECENT CONVERSATION:');
    for (final m in recent) {
      final role = m['role'] == 'user' ? 'User' : 'Coach';
      buf.writeln('$role: ${_clip(m['text'] ?? '', 220)}');
    }
    buf.writeln();

    buf.writeln('ONGOING CONVERSATION RULES:');
    buf.writeln('- Do NOT greet again. Answer directly.');
    buf.writeln('- Carry earlier context forward: if the user mentioned pain, '
        'an injury, a constraint or a goal above, factor it in and reference '
        'it briefly when relevant ("Yesterday you mentioned your shoulder...").');
    buf.writeln('- Never contradict advice you gave earlier in this conversation.');
    buf.writeln();
  }

  // ── Memory observation — ClaimCategory.observation ───────────────────────
  //
  // A memory observation is a first-person observation claim ("I've noticed...").
  // Gate: canMakeObservation — requires Learning phase with sufficient workouts.
  // Without this gate, early-session observations would exceed the AI's earned
  // authority and erode athlete trust.

  void _appendMemoryObservation(
      StringBuffer buf, String? obs, AllowedClaims claims) {
    // ClaimCategory.observation — gated on canMakeObservation
    if (obs == null || !claims.content.canMakeObservation) return;

    buf.writeln('COACH MEMORY (real, verified): "$obs"');
    buf.writeln('- You MAY weave this in naturally, at most once, and only '
        'if it fits the user\'s message. Otherwise ignore it silently.');
    buf.writeln('- Never present it as analysis ("according to data...") — '
        'say it like a coach who remembers.');
    buf.writeln();
  }

  // ── Public introspection ─────────────────────────────────────────────────

  /// Returns the maximum [ClaimCategory] this builder will instruct Gemini to
  /// operate at, given the current maturity claims.
  ///
  /// Used by future claim validators to verify prompt output stays within
  /// the earned authority band. Currently informational only.
  static ClaimCategory maxPermittedClaim(AllowedClaimsContent content) {
    if (content.canMakePrediction)   return ClaimCategory.prediction;
    if (content.canMakePatternClaim) return ClaimCategory.pattern;
    if (content.canMakeObservation)  return ClaimCategory.observation;
    return ClaimCategory.data;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _wantsWorkoutPlan(String lower) =>
      lower.contains('workout')  ||
      lower.contains('plan')     ||
      lower.contains('back')     ||
      lower.contains('chest')    ||
      lower.contains('bicep')    ||
      lower.contains('tricep')   ||
      lower.contains('legs')     ||
      lower.contains('shoulder') ||
      lower.contains('push')     ||
      lower.contains('pull');

  static String _topicFor(
      String currentText, List<Map<String, String>> older) {
    final combined =
        '$currentText ${older.map((m) => m['text'] ?? '').join(' ')}'
            .toLowerCase();
    if (combined.contains('diet')     || combined.contains('protein') ||
        combined.contains('calorie')  || combined.contains('meal'))   { return 'nutrition'; }
    if (combined.contains('recovery') || combined.contains('sleep')  ||
        combined.contains('sore')     || combined.contains('fatigue')) { return 'recovery'; }
    if (combined.contains('plan')     || combined.contains('workout') ||
        combined.contains('split'))   { return 'workout planning'; }
    if (combined.contains('motivation') || combined.contains('consistency') ||
        combined.contains('streak'))  { return 'consistency'; }
    return 'general coaching';
  }

  static String _constraintsFromHistory(List<Map<String, String>> older) {
    final text = older.map((m) => m['text'] ?? '').join(' ').toLowerCase();
    final out  = <String>[];
    if (text.contains('bodyweight') || text.contains('no equipment') ||
        text.contains('home workout')) { out.add('bodyweight/no equipment'); }
    if (text.contains('vegetarian') || text.contains(' veg ')) { out.add('vegetarian'); }
    if (text.contains('eggetarian'))  { out.add('eggetarian'); }
    if (text.contains('injury')    || text.contains('pain'))  { out.add('avoid aggravating pain/injury'); }
    return out.take(4).join(', ');
  }

  static String _clip(String value, int maxChars) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars - 3)}...';
  }
}
