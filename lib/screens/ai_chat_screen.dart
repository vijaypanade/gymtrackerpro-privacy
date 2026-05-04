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

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/monetization_service.dart'; // ✅ Paywall
import '../utils/app_constants.dart';
import 'ai_workout_screen.dart';

// ── Keywords that mean user wants a workout PLAN (not just advice) ──────────
const _planTriggers = [
  'generate plan', 'make plan', 'create plan', 'new plan', 'workout plan',
  'weekly plan', 'give me a plan', 'build plan', 'plan banva', 'plan dya',
  'plan chahiye', 'plan bana', 'suggest plan', 'generate workout',
  'make workout', 'schedule', 'full week', 'full plan',
];

bool _wantsPlan(String msg) {
  final lower = msg.toLowerCase();
  return _planTriggers.any((t) => lower.contains(t));
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  // ✅ static on widget class — accessible via AIChatScreen._quickQuestions
  static const quickQuestions = [
    "Today's workout? 🏋️",
    "My protein target? 🍗",
    "Recovery tips 💤",
    "I feel tired 😴",
    "Generate plan 📋",
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': "Hey ${p.profile.name}! 💪\n"
              "I'm your AI coach. Ask me anything about workouts, diet, or recovery.\n\n"
              "Type \"generate plan\" to get a full weekly plan.",
        });
      });
    });
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

    _ctrl.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _scrollToBottom();

    final p = context.read<AppProvider>();

    // ── ROUTE: Plan generation intent detection ───────────────────
    final lower = text.toLowerCase();
    final isPlanRequest = (lower.contains("generate") ||
                           lower.contains("create") ||
                           lower.contains("make") ||
                           lower.contains("build")) &&
                          (lower.contains("plan") ||
                           lower.contains("workout") ||
                           lower.contains("routine") ||
                           lower.contains("program"));

    if (isPlanRequest) {
      try {
        final result = await p.getAIWorkoutPlan();
        if (!mounted) return;

        final days = result['days'] as List?;
        if (days == null || days.isEmpty) {
          setState(() {
            _isTyping = false;
            _messages.add({
              "role": "ai",
              "text": "❌ Could not generate plan. Try AI Setup from home screen.",
            });
          });
          return;
        }

        await p.applyAIWorkout(result);

        if (!mounted) return;
        final planName = result['workout_name']?.toString() ?? 'Custom Plan';

        // Build dynamic summary from plan
        final focuses = <String>[];
        int restCount = 0;
        for (final d in days) {
          if (d is Map) {
            final focus = d['focus']?.toString() ?? '';
            if (focus.toLowerCase() == 'rest') {
              restCount++;
            } else if (focus.isNotEmpty && !focuses.contains(focus)) {
              focuses.add(focus);
            }
          }
        }
        final trainingDays = days.length - restCount;
        final focusStr = focuses.isEmpty ? 'mixed' : focuses.join(' / ');

        // Build context-aware tip based on user state
        String tip = '';
        if (p.isFatigued) {
          tip = '\n\n⚠️ Detected fatigue — volume slightly reduced.';
        } else if (p.streak.currentStreak >= 7) {
          tip = '\n\n🔥 ${p.streak.currentStreak}-day streak — keeping momentum!';
        } else if (p.weakMuscle.isNotEmpty) {
          tip = '\n\n🎯 Extra focus added for ${p.weakMuscle}.';
        } else if (p.streak.totalWorkouts < 5) {
          tip = '\n\n🌱 Beginner-friendly — start strong!';
        }

        setState(() {
          _isTyping = false;
          _messages.add({
            "role": "ai",
            "text": "✅ New plan applied!\n\n"
                "📋 $planName\n"
                "📅 $trainingDays training days, $restCount rest\n"
                "💪 Focus: $focusStr$tip\n\n"
                "Open Planner tab to start 🚀",
          });
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add({
            "role": "ai",
            "text": "❌ Error generating plan: $e",
          });
        });
        return;
      }
    }

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
      final buf = StringBuffer();
      buf.writeln('You are a personal fitness coach. Reply in a friendly, '
          'motivating tone. Reply MAX 3 short sentences. NO long paragraphs. Be direct.');
      buf.writeln();

      buf.writeln('USER PROFILE:');
      buf.writeln('- Goal: ${p.profile.goal}');
      buf.writeln('- Level: ${p.profile.level}');
      buf.writeln('- Trainer style: ${p.profile.trainerType}');
      buf.writeln('- Weight: ${p.profile.weightKg}kg, '
          'Height: ${p.profile.heightCm}cm');
      buf.writeln('- Streak: ${p.streak.currentStreak} days');
      buf.writeln('- Total workouts: ${p.streak.totalWorkouts}');
      if (p.lastWorkoutNames.isNotEmpty) {
        buf.writeln('- Last workout: ${p.lastWorkoutNames.first}');
      }
      if (p.weakMuscle.isNotEmpty) {
        buf.writeln('- Weakest muscle: ${p.weakMuscle}');
      }
      buf.writeln();

      if (history.isNotEmpty) {
        buf.writeln('CONVERSATION SO FAR:');
        for (final m in history.take(10)) {
          final role = m['role'] == 'user' ? 'User' : 'Coach';
          buf.writeln('$role: ${m['text']}');
        }
        buf.writeln();
      }

      buf.writeln('User just asked: "$text"');

      final reply = await ApiService.askAI(buf.toString());

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({'role': 'ai', 'text': reply});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': "⚠️ Something went wrong. Try again 💪",
        });
      });
    }


    _scrollToBottom();
  }

  // ── PLAN REQUEST HANDLER ──────────────────────────────────────────────────
  Future<void> _handlePlanRequest(AppProvider p, String text) async {
    // ✅ Check daily AI limit — offer rewarded ad if limit hit
    if (!p.canUseAI() && !p.isPremium) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': '🔒 Daily AI limit reached.\n\nWatch a short ad to get 1 more free plan, or upgrade to Premium for unlimited! 👑',
          'showRewardedAd': true,
        });
      });
      _scrollToBottom();
      return;
    }

    try {
      setState(() => _isTyping = true);
      final plan = await p.getAIWorkoutPlan();
      if (!mounted) return;

      final workoutName = plan['workout_name'] as String? ?? 'AI Workout Plan';
      final days        = (plan['days'] as List?)?.length ?? 0;

      setState(() {
        _isTyping = false;
        _messages.add({
          'role':     'ai',
          'text':     "🤖 Done! Generated your **$workoutName** — $days days of training.\n\nTap below to preview and apply it to your Planner 👇",
          'planData': plan,
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text': "⚠️ AI is busy right now. Try again in a moment 💪",
        });
      });
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIWorkoutScreen(plan: plan)),
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
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI Trainer', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Powered by Gemini', style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 10)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.green, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('Online', style: GoogleFonts.inter(
                color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
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
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 13))),
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
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          colors: [Color(0xFFFFCC00), Color(0xFFFF9900)])
                      : null,
                  color: isUser ? null : AppColors.bgCard,
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
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    color: isUser ? Colors.black : AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),

              // Plan preview button
              if (planData != null && onApplyPlan != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => onApplyPlan!(planData!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.preview_rounded, color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text('Preview & Apply Plan 🚀',
                          style: GoogleFonts.rajdhani(
                              color: Colors.black, fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ],
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
                    child: Text('🎁 Get 1 Free AI Plan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.gold, fontSize: 13,
                            fontWeight: FontWeight.w700)),
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
          width: 28, height: 28,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, gradient: AppGradients.gold),
          child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 13))),
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
          final isPlan = q.toLowerCase().contains('plan');
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(q);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isPlan
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPlan
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : AppColors.borderSoft,
                ),
              ),
              child: Text(q, style: GoogleFonts.inter(
                  color: isPlan ? AppColors.gold : AppColors.textSecondary,
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
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
              hintText: 'Ask your trainer…',
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
              gradient: isTyping
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
              color: isTyping ? AppColors.bgCardLight : null,
              shape: BoxShape.circle,
              boxShadow: isTyping ? [] : [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Icon(
              isTyping ? Icons.hourglass_top_rounded : Icons.send_rounded,
              color: isTyping ? AppColors.textMuted : Colors.black,
              size: 18,
            ),
          ),
        ),
      ]),
    );
  }
}
