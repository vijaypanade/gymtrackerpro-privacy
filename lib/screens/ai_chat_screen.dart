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

import '../ai/models/chat_prompt_input.dart';
import '../ai/services/chat_prompt_builder.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/monetization_service.dart';
import '../services/observation_engine.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';
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
    "What should I train today?",
    "How's my recovery?",
    "How much protein do I need?",
    "Help me lose fat",
    "Help me stay consistent",
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
        final streak = p.streak.currentStreak;
        final opening = (seed != null && seed.isNotEmpty)
            ? seed
            : isTravel
                ? "Traveling? Bodyweight work still counts.\n\nWhat do you want to train?"
                : streak >= 3
                    ? "Good to see you. $streak days straight.\n\nWhat's on for today?"
                    : "Good to see you.\n\nWhat are you training today?";
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

      final lowerText = text.toLowerCase();

      // Pre-fetch verified memory observation (async) before building the prompt.
      // ObservationEngine.pick() is async; the builder receives the text synchronously.
      final memoryObs = await ObservationEngine.pick(p.observationCandidates());
      // Mark seen only if the maturity gate will actually include it in the prompt.
      if (memoryObs != null &&
          p.aiMaturity.allowedClaims.content.canMakeObservation) {
        ObservationEngine.markSeen(memoryObs);
      }

      // Delegate prompt construction to ChatPromptBuilder.
      // Prompt Builder owns all trust decisions — widget only passes raw data.
      final prompt = const ChatPromptBuilder().build(ChatPromptInput(
        aiMaturity:          p.aiMaturity,
        profile:             p.profile,
        streak:              p.streak,
        recoveryScore:       p.recoveryScore.round(),
        readinessScore:      p.readinessScore,
        isFatigued:          p.isFatigued,
        needsDeloadByVolume: p.needsDeloadByVolume,
        muscleRecoveryList:  p.muscleRecoveryList,
        exerciseHistory:     p.workout.buildExerciseHistory(),
        lastWorkoutNames:    p.lastWorkoutNames,
        weakMuscle:          p.weakMuscle,
        isTravelMode:        p.settings.travelMode,
        conversationHistory: history,
        userMessage:         text,
        intent:              intent,
        memoryObservation:   memoryObs?.text,
      ));

      final reply = await ApiService.askAI(
        prompt,
        timeout:   const Duration(seconds: 60),
        isPremium: p.isPremium,
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
      final isNetwork = e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection refused');
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': isNetwork
              ? "⚠️ No internet connection. Check your network and try again."
              : "⚠️ Something went wrong. Try again 💪",
        });
      });
      _saveHistory();
    }


    _scrollToBottom();
  }

  // ── PLAN REQUEST HANDLER ──────────────────────────────────────────────────
  Future<void> _handlePlanRequest(AppProvider p, String text) async {
    if (!p.canUseAI() && !p.isPremium) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': 'You\'ve used your 3 free AI plans for today. Upgrade to Premium for unlimited coaching — no daily caps, ever.',
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
      if (!mounted) return;
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!pos.hasContentDimensions) return;
      try {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {}
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
                onApplyPlan: (plan) => _openPlanPreview(plan),
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
    Navigator.push(context, slideUpRoute(AIWorkoutScreen(plan: plan)));
  }

  void _showPaywallSheet() {
    final ap = context.read<AppProvider>();
    PaywallSheet.show(
      context,
      trigger:   PaywallTrigger.aiLimitHit,
      onUpgrade: () => ap.refreshMonetization(),
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
                fontSize: 20, fontWeight: FontWeight.w900,
                letterSpacing: 0.4)),
            Text('Adaptive fitness intelligence', style: GoogleFonts.inter(
                color: AppColors.textMuted.withValues(alpha: 0.72),
                fontSize: 12,
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
  const _MessageBubble({
    required this.text,
    required this.isUser,
    this.planData,
    this.onApplyPlan,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.62,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
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
                  fontSize: 14, fontWeight: FontWeight.w600)),
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
                color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ask about training, recovery, or nutrition…',
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 16),
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
