// lib/screens/ai_chat_screen.dart — v3.0 FIXED
// ✅ ROOT CAUSE FIXES:
//   1. _send() was hardcoded to getAIWorkoutPlan() for EVERY message → now uses ApiService
//   2. ApiService.askAI() correctly called with full context
//   3. Workout plan trigger only when user explicitly asks for it
//   4. Normal conversation works — greetings, diet, recovery, motivation all reply as text
//   5. "Generate plan" button shown in chat when relevant — doesn't auto-navigate
//   6. Full premium black/gold theme applied

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/training_intent_parser.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/monetization_service.dart';
import '../utils/app_constants.dart';
import 'ai_workout_screen.dart';

// Workout generation removed from AI chat.
// Planner screen handles structured workout generation only.

class AIChatScreen extends StatefulWidget {
  // Optional pre-loaded context injected from home screen AI Verdict card.
  // When non-null and chat is fresh, replaces the generic greeting so the
  // coach opens already aware of the user's current recovery state.
  final String? seedContext;

  const AIChatScreen({super.key, this.seedContext});

  // ✅ static on widget class — accessible via AIChatScreen._quickQuestions
  static const quickQuestions = [
    "Training guidance",
    "Recovery analysis",
    "Protein target",
    "Fat loss strategy",
    "Improve consistency",
  ];

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final FocusNode              _focus  = FocusNode();

  // Each message: role = 'user' | 'ai', text = string, planData = optional Map
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  static const String _kChatHistory = 'ai_chat_history';
  static const int _kMaxMessages = 50; // Cap history to prevent storage bloat

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHistory();
      if (_messages.isEmpty && mounted) {
        final p = context.read<AppProvider>();
        final isTravel = p.settings.travelMode;
        final seed = widget.seedContext;
        final opening = (seed != null && seed.isNotEmpty)
            ? seed
            : isTravel
                ? "Travel mode active.\n\nBodyweight-focused guidance is ready."
                : "Ready to help with training, recovery, and progress. Ask anything.";
        setState(() {
          _messages.add({'role': 'ai', 'text': opening});
        });
        _saveHistory();
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await StorageService.instance.getString(_kChatHistory);
      if (raw == null || raw.isEmpty) return;
      final result = StorageService.instance.decodeList(raw, (m) => m);
      if (!result.hasData) return;
      final loaded = (result.data as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (loaded.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(loaded);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      debugPrint('Chat load error: \$e');
    }
  }

  /// Detect if user wants bodyweight-only workout
  bool _detectBwIntent(String msg) {
    final t = msg.toLowerCase();
    return t.contains('bodyweight') ||
        t.contains('body weight') ||
        t.contains('no equipment') ||
        t.contains('home workout') ||
        t.contains('without gym');
  }

  Future<void> _saveHistory() async {
    try {
      // Keep only last N messages to prevent bloat
      final toSave = _messages.length > _kMaxMessages
          ? _messages.sublist(_messages.length - _kMaxMessages)
          : _messages;
      await StorageService.instance.setJson(_kChatHistory, toSave);
    } catch (e) {
      debugPrint('Chat save error: \$e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── MAIN SEND LOGIC ────────────────────────────────────────────────────────
  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    // ── PREMIUM GATE — chat message limit check (5/day, separate from workout AI) ──
    final ap = context.read<AppProvider>();
    if (!ap.canUseChat()) {
      HapticFeedback.heavyImpact();
      _showPaywallSheet();
      return;
    }

    _ctrl.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _saveHistory();
    _scrollToBottom();

    final p = context.read<AppProvider>();

    // ── ROUTE: Plan generation intent detection ───────────────────
    final intent = TrainingIntentParser.parse(text);

       try {
      // Build history in format ApiService expects
      final history = _messages
          .where((m) => m['role'] != null && m['text'] != null)
          .map<Map<String, String>>((m) => {
                'role': m['role'] as String,
                'text': m['text'] as String,
              })
          .toList();

      // Build a context-rich prompt for the secure backend.
      // ApiService.askAI now takes a single String prompt — we fold all
      // the user/profile/history context into it here.

      final lowerText = text.toLowerCase();

      final wantsWorkoutPlan =
          lowerText.contains('workout') ||
          lowerText.contains('plan') ||
          lowerText.contains('back') ||
          lowerText.contains('chest') ||
          lowerText.contains('bicep') ||
          lowerText.contains('tricep') ||
          lowerText.contains('legs') ||
          lowerText.contains('shoulder') ||
          lowerText.contains('push') ||
          lowerText.contains('pull');

      final buf = StringBuffer();

      final pf = p.profile;

      // ═══════════════════════════════════════════════
      // LAYER 1: IDENTITY — Indian Elite Trainer
      // ═══════════════════════════════════════════════
      buf.writeln('You are LiftOn AI Coach — an elite Indian fitness mentor.');
      buf.writeln('Personality: Confident, direct, like a senior who trained hundreds. NO fluff, NO lecture.');
      buf.writeln();
      buf.writeln('COMMUNICATION STYLE:');
      buf.writeln('- Sound like a calm, premium Indian fitness coach.');
      buf.writeln('- Be concise, confident, and practical.');
      buf.writeln('- Avoid excessive slang, hype, or motivational clichés.');
      buf.writeln('- Use short, scan-friendly responses.');
      buf.writeln('- Never sound childish, aggressive, or overly emotional.');
      buf.writeln('- Prioritize clarity and coaching quality over personality.');
      buf.writeln();

      // ═══════════════════════════════════════════════
      // LAYER 2: KNOWLEDGE & EXPERTISE
      // ═══════════════════════════════════════════════
      if (wantsWorkoutPlan) {
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
        // Allow more words when user asks for multiple exercises
        final exCount = RegExp(r'\b(\d+)\s+exercise').firstMatch(text.toLowerCase());
        final nEx = exCount != null ? int.tryParse(exCount.group(1) ?? '0') ?? 0 : 0;
        final wordLimit = nEx >= 5 ? 300 : (nEx >= 3 ? 220 : 150);
        buf.writeln('- Total reply MUST fit in $wordLimit words.');
        buf.writeln('- Match user level — never overload beginners.');
        buf.writeln('- Use progressive overload + recovery data for prescription.');
      } else {
        buf.writeln('EXPERTISE MODE: Conversational Coaching');
        buf.writeln('- Reply in MAX 3 short sentences. NO long paragraphs.');
        buf.writeln('- Coach voice: short, direct, action-first.');
        buf.writeln('- Use bullets only if listing 3+ items.');
        buf.writeln('- If you don\'t know, say so — never invent science.');
      }
      buf.writeln();

      // ═══════════════════════════════════════════════
      // EQUIPMENT CONSTRAINT (if user asks for bodyweight)
      // ═══════════════════════════════════════════════
      final wantsBW = text.toLowerCase().contains('bodyweight') ||
          text.toLowerCase().contains('body weight') ||
          text.toLowerCase().contains('no equipment') ||
          text.toLowerCase().contains('home workout') ||
          text.toLowerCase().contains('without gym');
      if (wantsBW) {
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

      // ═══════════════════════════════════════════════════════════════
      // TRAINING INTENT — HARD CONSTRAINTS
      // ═══════════════════════════════════════════════════════════════
      final constraintBlock = TrainingIntentParser.buildConstraintBlock(intent);
      if (constraintBlock.isNotEmpty) {
        buf.writeln(constraintBlock);
      }

      // ═══════════════════════════════════════════════
      // LAYER 3: CONSISTENCY PSYCHOLOGY
      // ═══════════════════════════════════════════════
      buf.writeln('PSYCHOLOGY RULES (very important):');
      buf.writeln('- Celebrate small wins (streak milestones, PRs, comeback days).');
      buf.writeln('- After missed days: NO guilt-tripping. Frame it as "comeback energy".');
      buf.writeln('- Build identity, not just habits: "You ARE someone who trains hard."');
      buf.writeln('- Use streak data to fuel momentum talk when streak ≥ 3 days.');
      buf.writeln('- If user sounds demotivated: acknowledge feelings first, then redirect to one small action.');
      buf.writeln('- Never shame body type, weight, or starting point.');
      buf.writeln();

      buf.writeln();

      // Detect profile completeness
      final hasName = pf.name.isNotEmpty && pf.name != 'Champion';
      final hasAge = pf.age > 0 && pf.age != 25;
      final hasWeight = pf.weightKg > 0 && pf.weightKg != 70.0;
      final hasHeight = pf.heightCm > 0 && pf.heightCm != 170.0;
      final profileComplete = hasName && hasAge && hasWeight && hasHeight;

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
      buf.writeln('- Location: ${pf.state}');
      debugPrint('SENDING LOCATION TO AI: ${pf.state}');
      buf.writeln('- Trainer style: ${pf.trainerType}');
      buf.writeln('- Streak: ${p.streak.currentStreak} days');
      buf.writeln('- Total workouts: ${p.streak.totalWorkouts}');
      buf.writeln();

      if (!profileComplete) {
        buf.writeln('⚠️ IMPORTANT: User profile is INCOMPLETE.');
        buf.writeln('If user asks for personalized advice — DO NOT guess. Instead politely ask them '
            'to update their Profile tab with: age, weight, height, and goal. Keep it friendly, 2 sentences max.');
        buf.writeln();
      }

      buf.writeln('IMPORTANT PRODUCT RULE:');
      buf.writeln('- DO NOT generate full diet plans inside chat.');
      buf.writeln('- DO NOT generate full workout plans inside chat.');
      buf.writeln('- If user asks for diet plan, meal plan, calorie plan, bulking diet, or fat loss diet:');
      buf.writeln('  Give general guidance (macros, food types, timing). Do NOT reference any in-app diet tool.');
      buf.writeln('  LiftOn does not have a diet planner feature.');

      buf.writeln('- If user asks for workout plan, split, PPL routine, bro split, weekly schedule, or training program:');
      buf.writeln('  redirect them to Planner or Tools.');
      buf.writeln('  Tell them the Planner creates more structured and personalized plans than chat.');
      buf.writeln('  Mention split-based generation like Push Pull Legs, Upper Lower, Bro Split, etc.');
      buf.writeln('- Keep the reply short, premium, and confident.');
      buf.writeln('- You MAY still answer general nutrition questions.');
      buf.writeln();
      buf.writeln('- User is from India. Suggest Indian foods only.');
      buf.writeln('- Respect dietPreference: if "veg" → NEVER suggest meat/fish/egg.');
      buf.writeln('- If "eggetarian" → eggs OK but no meat/fish.');
      buf.writeln('- If "nonveg" → all foods OK.');
      buf.writeln('- Use household items: dal, roti, rice, paneer, dahi, sabzi, '
          'poha, upma, idli, dosa, chicken curry, eggs, etc.');
      buf.writeln('- AVOID: avocado, salmon, quinoa, expensive western foods.');
      if (p.lastWorkoutNames.isNotEmpty) {
        buf.writeln('- Last workout: ${p.lastWorkoutNames.first}');
      }
      if (p.weakMuscle.isNotEmpty) {
        buf.writeln('- Weakest muscle: ${p.weakMuscle}');
      }

      buf.writeln('- Current fatigue: ${p.isFatigued ? "High" : "Normal"}');
      buf.writeln('- Needs deload: ${p.needsDeloadByVolume}');
      buf.writeln('- Recent workouts: ${p.lastWorkoutNames.take(5).join(", ")}');
      buf.writeln();

      // ═══════════════════════════════════════════════
      // SPORTS SCIENCE DATA (use to personalize advice)
      // ═══════════════════════════════════════════════
      final totalSessions = p.streak.totalWorkouts;
      final isNewUser = totalSessions < 3;

      if (isNewUser) {
        buf.writeln('USER STATUS: NEW USER (only \$totalSessions workouts logged).');
        buf.writeln('CRITICAL: Recovery/readiness scores are NOT reliable yet.');
        buf.writeln('- DO NOT mention any recovery percentage or readiness score.');
        buf.writeln('- DO NOT pretend to know fatigue or volume trend.');
        buf.writeln('- Treat as fresh start: suggest beginner-friendly form-first workout.');
        buf.writeln('- Encourage them to log workouts so AI learns their body.');
      } else {
        buf.writeln('SCIENTIFIC RECOVERY & READINESS DATA:');
        buf.writeln('- Recovery Score: ${p.recoveryScore.toStringAsFixed(0)}/100');
        buf.writeln('- Training Readiness: ${p.readinessScore.toStringAsFixed(0)}/100');
        buf.writeln('  → 85+ = peak (PR attempts OK)');
        buf.writeln('  → 60-84 = normal training');
        buf.writeln('  → 30-59 = light/technique day');
        buf.writeln('  → <30 = deload or rest');
        buf.writeln('- Volume Trend: ${p.needsDeloadByVolume ? "DROPPING — recommend deload" : "Stable/growing"}');

        // ── Fix 1: Per-muscle recovery ──────────────────
        final muscleRecoveries = p.muscleRecoveryList;
        if (muscleRecoveries.isNotEmpty) {
          buf.writeln('');
          buf.writeln('MUSCLE-BY-MUSCLE RECOVERY (critical — use for muscle-specific advice):');
          for (final mr in muscleRecoveries) {
            buf.writeln('- ${mr.muscle}: ${mr.recoveryScore}% ${mr.emoji} ${mr.status}'
                ' (last trained ${mr.lastTrainedDate})');
          }
          buf.writeln('→ NEVER suggest training a muscle below 40% recovery.');
          buf.writeln('→ If user asks what to train today → pick highest % muscles.');
        }
      }

      // ── Fix 2: Exercise weight history ───────────────
      final exHistory = p.workout.buildExerciseHistory();
      if (exHistory.isNotEmpty) {
        buf.writeln('');
        buf.writeln('EXERCISE HISTORY — last 21 days (use for weight recommendations):');
        for (final ex in exHistory) {
          if (ex.unit == 'kg' && ex.bestWeight > 0) {
            buf.writeln('- ${ex.name}: best ${ex.bestWeight}kg × ${ex.bestReps} reps');
          } else if (ex.bestReps > 0) {
            buf.writeln('- ${ex.name}: best ${ex.bestReps} reps (bodyweight)');
          }
        }
        buf.writeln('→ When user asks weight for a listed exercise → suggest best + 2.5kg if recovery ≥ 60%.');
        buf.writeln('→ If same weight 3+ sessions → tell them they are stagnant, suggest increase or technique change.');
      }
      buf.writeln();

      buf.writeln('TRAINER DECISION RULES (apply to all workout advice):');
      buf.writeln('- If readiness < 30 → STRONGLY suggest rest/walk/mobility only.');
      buf.writeln('- If readiness 30-59 → suggest 60% intensity, technique focus, RIR 3-4.');
      buf.writeln('- If readiness 60-84 → normal session, RIR 1-2 on top sets.');
      buf.writeln('- If readiness 85+ → green light for PR attempt or heavy day.');
      buf.writeln('- If needsDeload = true → MANDATORY mention deload this week.');
      buf.writeln('- If weakMuscle is set → prioritize it 2x/week, mention by name.');
      buf.writeln('- Always reference user data ("Bhai, your recovery is at X today...").');
      buf.writeln();

      final contextBlock = _compressedConversationContext(history, p, text);
      if (contextBlock.isNotEmpty) buf.writeln(contextBlock);

      buf.writeln('User just asked: "$text"');

      final reply = await ApiService.askAI(
        buf.toString(),
        timeout: const Duration(seconds: 60),
      );

      // Record chat message usage (independent from workout AI limit)
      await MonetizationService.instance.recordChatMessageUse();

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({'role': 'ai', 'text': reply});
      });
      _saveHistory();

      // ── Auto-generate plan if user requested ──
      final wantsPlan = lowerText.contains('create') && lowerText.contains('plan') ||
          lowerText.contains('generate') && lowerText.contains('plan') ||
          lowerText.contains('make') && lowerText.contains('plan') ||
          lowerText.contains('bodyweight') && lowerText.contains('workout') ||
          lowerText.contains('weekly plan');

      if (wantsPlan) {
        try {
          final ap = context.read<AppProvider>();
          // Detect goal
          String goal = 'Build Muscle';
          if (lowerText.contains('lose') || lowerText.contains('fat')) goal = 'Lose Fat';
          if (lowerText.contains('strong') || lowerText.contains('strength')) goal = 'Get Stronger';

          // Detect level
          String level = 'Beginner';
          if (lowerText.contains('intermediate')) level = 'Intermediate';
          if (lowerText.contains('advanced')) level = 'Advanced';

          await ap.workout.generateSmartPlan(goal: goal, level: level, splitOverride: intent.engineSplit);

          if (!mounted) return;
          setState(() {
            _messages.add({
              'role': 'ai',
              'text': '✅ Done! Your \$goal plan is in the Planner tab. Open Planner to see it!',
            });
          });
          _saveHistory();
        } catch (e) {
          debugPrint('Auto plan generation failed: \$e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': "⚠️ Something went wrong. Try again 💪",
        });
      });
      _saveHistory();
    }


    _scrollToBottom();
  }

  String _compressedConversationContext(
    List<Map<String, String>> history,
    AppProvider p,
    String currentText,
  ) {
    if (history.isEmpty) return '';
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    final older = history.length > 6
        ? history.sublist(0, history.length - 6)
        : const <Map<String, String>>[];

    final buf = StringBuffer();
    if (older.isNotEmpty) {
      buf.writeln('CONVERSATION SUMMARY:');
      buf.writeln('- User goal: ${p.profile.goal}; level: ${p.profile.level}; diet: ${p.profile.dietPreference}.');
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
    return buf.toString();
  }

  String _topicFor(String currentText, List<Map<String, String>> older) {
    final combined = '$currentText ${older.map((m) => m['text'] ?? '').join(' ')}'
        .toLowerCase();
    if (combined.contains('diet') || combined.contains('protein') ||
        combined.contains('calorie') || combined.contains('meal')) {
      return 'nutrition';
    }
    if (combined.contains('recovery') || combined.contains('sleep') ||
        combined.contains('sore') || combined.contains('fatigue')) {
      return 'recovery';
    }
    if (combined.contains('plan') || combined.contains('workout') ||
        combined.contains('split')) {
      return 'workout planning';
    }
    if (combined.contains('motivation') || combined.contains('consistency') ||
        combined.contains('streak')) {
      return 'consistency';
    }
    return 'general coaching';
  }

  String _constraintsFromHistory(List<Map<String, String>> older) {
    final text = older.map((m) => m['text'] ?? '').join(' ').toLowerCase();
    final constraints = <String>[];
    if (text.contains('bodyweight') || text.contains('no equipment') ||
        text.contains('home workout')) {
      constraints.add('bodyweight/no equipment');
    }
    if (text.contains('vegetarian') || text.contains(' veg ')) {
      constraints.add('vegetarian');
    }
    if (text.contains('eggetarian')) constraints.add('eggetarian');
    if (text.contains('injury') || text.contains('pain')) {
      constraints.add('avoid aggravating pain/injury');
    }
    return constraints.take(4).join(', ');
  }

  String _clip(String value, int maxChars) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars - 3)}...';
  }

  // ── PLAN REQUEST HANDLER ──────────────────────────────────────────────────
  Future<void> _handlePlanRequest(AppProvider p, String text) async {
    // ✅ Check daily AI limit — offer rewarded ad if limit hit
    if (!p.canUseAI() && !p.isPremium) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': 'You\'ve used your free AI plan for today.\n\nWatch an ad for 1 more, or upgrade to Premium for unlimited coaching — no daily caps, ever.',
          'showRewardedAd': true,
        });
      });
      _saveHistory();
      _scrollToBottom();
      return;
    }

    try {
      setState(() => _isTyping = true);
      final plan = await p.getAIWorkoutPlan(bodyweightOnly: _detectBwIntent(text));
      if (!mounted) return;

      final daysList = plan['days'] as List?;
      // Guard: if plan is empty or has no days, show an error instead of
      // attaching an unusable planData that renders as "1 day • 0 exercises".
      if (plan.isEmpty || daysList == null || daysList.isEmpty) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'ai',
            'text': "⚠️ AI is busy right now. Try again in a moment 💪",
          });
        });
        _saveHistory();
        _scrollToBottom();
        return;
      }

      final workoutName = plan['workout_name'] as String? ?? 'AI Workout Plan';
      final days        = daysList.length;

      setState(() {
        _isTyping = false;
        _messages.add({
          'role':     'ai',
          'text':     "🤖 Done! Generated your **$workoutName** — $days days of training.\n\nTap below to preview and apply it to your Planner 👇",
          'planData': plan,
        });
      });
      _saveHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': "⚠️ AI is busy right now. Try again in a moment 💪",
        });
      });
      _saveHistory();
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        _AppBar(),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length && _isTyping) return _TypingIndicator();
              final msg = _messages[i];
              return _MessageBubble(
                text:           msg['text'] as String? ?? '',
                isUser:         msg['role'] == 'user',
                planData:       msg['planData'] as Map<String, dynamic>?,
                showRewardedAd: msg['showRewardedAd'] as bool? ?? false,
                onApplyPlan:    (plan) => _openPlanPreview(plan),
                onAdComplete: () {
                  // Ad watched → retry plan generation
                  final p = context.read<AppProvider>();
                  _handlePlanRequest(p, 'generate plan');
                },
              );
            },
          ),
        ),
        // Quick chips — only at start
        if (_messages.length <= 2) _QuickChips(onTap: _send),
        _InputBar(
          ctrl:     _ctrl,
          focus:    _focus,
          onSend:   _send,
          isTyping: _isTyping,
        ),
      ]),
    );
  }

  void _openPlanPreview(Map<String, dynamic> plan) {
    HapticFeedback.mediumImpact();
    final daysList = plan["days"] as List?;
    debugPrint("🟡 PREVIEW PLAN KEYS: ${plan.keys.toList()}");
    debugPrint("🟡 PREVIEW DAYS COUNT: ${daysList?.length}");
    if (daysList != null && daysList.isNotEmpty) {
      debugPrint("🟡 PREVIEW FIRST DAY: ${daysList.first}");
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIWorkoutScreen(plan: plan)),
    );
  }

  void _showPaywallSheet() {
    final ap = context.read<AppProvider>();
    PaywallSheet.show(
      context,
      trigger: PaywallTrigger.aiLimitHit,
      onUpgrade:    () => ap.refreshMonetization(),
      onAdComplete: () => ap.refreshMonetization(),
    );
  }
}

// ── APP BAR ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, gradient: AppGradients.gold),
          child: ClipOval(
            child: Image.asset(
              'assets/header_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Coach', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w900,
                letterSpacing: 0.4)),
            Text('Adaptive fitness intelligence', style: GoogleFonts.inter(
                color: AppColors.textMuted.withValues(alpha: 0.72),
                fontSize: 10.5,
                fontWeight: FontWeight.w500)),
          ],
        )),
      ]),
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? planData;
  final void Function(Map<String, dynamic>)? onApplyPlan;
  final bool showRewardedAd;
  final VoidCallback? onAdComplete;

  const _MessageBubble({
    required this.text,
    required this.isUser,
    this.planData,
    this.onApplyPlan,
    this.showRewardedAd = false,
    this.onAdComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppGradients.gold),
              child: ClipOval(
                child: Image.asset(
                  'assets/header_logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Text bubble
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 11),
                decoration: BoxDecoration(
                  gradient: null,
                  color: isUser
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF171717),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4  : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: SelectableText(
                  text
                      .replaceAll('•', '\n•')
                      .replaceAll('1.', '\n1.')
                      .replaceAll('2.', '\n2.')
                      .replaceAll('3.', '\n3.'),
                  style: GoogleFonts.inter(
                    color: isUser ? Colors.black : AppColors.textPrimary,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w500,
                    height: 1.62,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              // ✅ Watch Ad button — shown when daily limit hit
              if (showRewardedAd && onAdComplete != null) ...[
                const SizedBox(height: 8),
                // WatchAdForAIButton — enable after flutter pub get
                GestureDetector(
                  onTap: onAdComplete,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text('Watch an ad for 1 extra plan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.gold, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          )),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── TYPING INDICATOR ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.gold,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/header_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.33;
                final opacity = (((_c.value + delay) % 1.0) * 2)
                    .clamp(0.2, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.gold, shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── QUICK CHIPS ────────────────────────────────────────────────────────────────
class _QuickChips extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: AIChatScreen.quickQuestions.map((q) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(q);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderSoft,
                ),
              ),
              child: Text(q, style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── INPUT BAR ────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode             focus;
  final void Function(String) onSend;
  final bool                  isTyping;
  const _InputBar({
    required this.ctrl, required this.focus,
    required this.onSend, required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom;
    final safeBottom = mq.padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom + safeBottom),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode:  focus,
            textInputAction: TextInputAction.send,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ask about training, recovery, or nutrition…',
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppColors.bgCard,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppColors.borderSoft, width: 0.8)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppColors.gold, width: 1.2)),
            ),
            onSubmitted: isTyping ? null : onSend,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isTyping ? null : () => onSend(ctrl.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: null,
              color: isTyping
                  ? AppColors.bgCardLight
                  : const Color(0xFFD4AF37),
              shape: BoxShape.circle,
              boxShadow: isTyping ? [] : [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Icon(
              isTyping ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded,
              color: isTyping ? AppColors.textMuted : Colors.black,
              size: 18,
            ),
          ),
        ),
      ]),
    );
  }
}
