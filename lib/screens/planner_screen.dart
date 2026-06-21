// lib/screens/planner_screen.dart — v9.0 PHASE 1
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../widgets/rest_timer_overlay.dart';
import '../services/workout_session_service.dart';
// PHASE 1 UPGRADES:
//   ① HAPTICS — consistent system throughout (heavy/medium/light/selection)
//   ② PLANNER UI — complete premium redesign:
//      • AppBar: gradient title, workout summary pill
//      • AI Banner: glassmorphism card with animated typing indicator
//      • Day Strip: larger tiles, progress arc, today pulse dot
//      • Day Header: workout stats row (exercises · sets · volume)
//      • Exercise Cards: full-width emoji icon, category chip, live volume display
//      • Set Rows: numbered circles, weight/reps inline display, green fill done
//      • Complete Button: full gold gradient CTA
//      • Streak dialog: large emoji + coach copy + auto-dismiss
//   ③ GOOGLE FONTS FALLBACK — TextStyle fallback when fonts can't load
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/utils/safe_utils.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart'; // ✅ Paywall
import '../models/models.dart';
import '../models/readiness.dart' show RecoveryWarning;
import '../providers/app_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/ai_provider.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/progress_chart.dart';
import '../widgets/exercise_animation_widget.dart';
import '../data/exercise_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/exercise_icon_mapper.dart';
import '../utils/exercise_category_theme.dart';
import '../utils/exercise_difficulty_helper.dart';
import '../utils/exercise_equipment_helper.dart';
import '../utils/exercise_ai_badge_helper.dart';
import '../services/exercise_intelligence_service.dart';
import '../services/weekly_evolution_service.dart';
import 'ai_chat_screen.dart';
import 'main_shell.dart';
import '../widgets/confetti_celebration.dart';
import '../widgets/pr_celebration.dart';
import '../engines/pr_engine.dart' as pre;
import '../utils/haptics.dart';
import '../widgets/planner/planner_video_widgets.dart';
import '../models/coach_visual_state.dart';
import '../services/recovery_session_service.dart';
import '../services/ghost_copy_service.dart';
import '../services/wger_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// ════════════════════════════════════════════════
// HAPTICS HELPER — consistent system
// ════════════════════════════════════════════════
/// Combines feedback message with next target for compact header display.
/// Same logic as PR celebration screen.
String _buildHeaderMessage(
    pre.WorkoutFeedback? fb, String fallback, PlannedExercise ex) {
  if (fb == null) return fallback;

  // Deterministic per-exercise variation — same exercise always gets same coaching
  final slot = ex.name.hashCode.abs() % 5;

  String coaching;
  final raw = fb.message.toLowerCase();
  if (raw.contains('perfect')) {
    const v = [
      'Optimal execution. Push as planned.',
      'Strong performance. Apply progression.',
      'Quality execution — add load today.',
      'Elite form. Progressive overload supported.',
      'Perfect session. Increase weight as planned.',
    ];
    coaching = v[slot];
  } else if (raw.contains('good') || raw.contains('solid')) {
    const v = [
      'Solid execution. Maintain current load.',
      'Good quality. Focus on bar speed.',
      'Consistent. Hold this weight today.',
      'Performance on track. Maintain.',
      'Good tempo. Controlled reps recommended.',
    ];
    coaching = v[slot];
  } else if (raw.contains('maintain') || raw.contains('hold')) {
    const v = [
      'Maintain current load.',
      'Quality execution over volume.',
      'Focus on tempo and control.',
      'Recovery supports this load.',
      'Controlled progression today.',
    ];
    coaching = v[slot];
  } else {
    coaching = fb.message;
  }

  String next;
  if (ex.bodyweight || ex.unit == 'reps') {
    next = '→ ${fb.nextReps} reps';
  } else if (ex.unit == 'min') {
    next = '→ ${fb.nextWeight.toInt()} min';
  } else {
    final current = ex.sets.isNotEmpty ? ex.sets.first.weight : 0.0;
    final suggested = fb.nextWeight;
    if (suggested <= current + 0.01) {
      next = '→ Maintain ${current.toStringAsFixed(1)} kg';
    } else {
      next = '→ ${suggested.toStringAsFixed(1)} kg';
    }
  }
  return '$coaching\n$next';
}

// ════════════════════════════════════════════════
// BADGE DIALOG
// ════════════════════════════════════════════════
void showBadgesDialog(BuildContext context, List<AppBadge> badges) {
  if (badges.isEmpty) return;
  H.success();
  showDialog(context: context, builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: AppCurves.primary,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.bgModal,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 0.8),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18, spreadRadius: 0)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 38),
          const SizedBox(height: AppSpacing.sm),
          Text('Achievement Unlocked', style: GoogleFonts.inter(
              color: AppColors.gold, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          ...badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(b.emoji,
                    style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: GoogleFonts.rajdhani(
                    color: AppColors.gold, fontSize: 17,
                    fontWeight: FontWeight.w700)),
                Text(b.description, style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
              ])),
            ]),
          )),
          const SizedBox(height: AppSpacing.sm),
          GoldButton(text: 'Let\'s Go',
              width: double.infinity,
              onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  ));
}

// ════════════════════════════════════════════════
// PLANNER SCREEN
// ════════════════════════════════════════════════
class PlannerScreen extends StatefulWidget {
  final int? initialDayIndex;
  const PlannerScreen({super.key, this.initialDayIndex});
  @override State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _day = 0;
  static const _names = [
    'Monday','Tuesday','Wednesday',
    'Thursday','Friday','Saturday','Sunday'];
  static const _shorts = ['MON','TUE','WED','THU','FRI','SAT','SUN'];

  @override
  void initState() {
    super.initState();
    final i = widget.initialDayIndex;
    _day = (i != null && i >= 0 && i < 7)
        ? i : (DateTime.now().weekday - 1).clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    // Only subscribe to loading flag and plan length — rare one-time transitions.
    // Set toggles / exercise completions do NOT change these, so the planner root
    // never rebuilds during a live workout. Local setState (day-tab tap) still works.
    final isLoading = context.select<AppProvider, bool>((ap) => ap.loading);
    final planLen   = context.select<AppProvider, int>((ap) => ap.weekPlan.length);

    if (isLoading) return Scaffold(
      backgroundColor: AppColors.bg,
      body: const Center(child: CircularProgressIndicator(
          color: AppColors.gold)));

    if (planLen < 7) return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.gold),
        const SizedBox(height: AppSpacing.lg),
        Text('Setting up your plan…', style: GoogleFonts.inter(
            color: AppColors.textMuted)),
      ])));

    final safe = _day.clamp(0, planLen - 1);
    final col  = AppColors.dayColors[safe % AppColors.dayColors.length];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Column(children: [

        // ── PREMIUM APP BAR ───────────────────────
        // Reacts only to day-completion changes via internal Selector.
        _PlannerAppBar(
          dayIdx: safe,
          dayName: _names[safe],
          color: col,
          onBack: () =>
              context.findAncestorStateOfType<MainShellState>()?.changeTab(0),
        ),

        // ── BANNER SLOT — priority-ordered, max 1 visible ─
        _ContextualBannerSlot(dayIdx: safe),

        // ── REST TIMER — compact inline banner above day strip ──
        const RestTimerBanner(),

        // ── DAY STRIP ─────────────────────────────
        // Self-selects completion bitmask — rebuilds only when a day is completed.
        _DayStrip(
          selected: safe,
          shorts: _shorts,
          onSelect: (i) {
            H.selection();
            setState(() => _day = i);
          },
        ),

        // ── DAY BODY ──────────────────────────────
        // context.watch lives here — this is the sole reactive rebuild boundary
        // for set toggles and exercise list changes.
        Expanded(child: _DayBody(key: ValueKey(safe), idx: safe, name: _names[safe])),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// PREMIUM APP BAR
// ════════════════════════════════════════════════

// Value-type snapshot for AppBar Selector — compared by == so mutable model works.
class _AppBarStats {
  final int exCount, doneCount;
  final bool isRest, isDone;
  const _AppBarStats({
    required this.exCount, required this.doneCount,
    required this.isRest,  required this.isDone,
  });
  const _AppBarStats.empty()
      : exCount = 0, doneCount = 0, isRest = false, isDone = false;
  @override
  bool operator ==(Object o) =>
      o is _AppBarStats &&
      o.exCount   == exCount   && o.doneCount == doneCount &&
      o.isRest    == isRest    && o.isDone    == isDone;
  @override
  int get hashCode => Object.hash(exCount, doneCount, isRest, isDone);
}

class _PlannerAppBar extends StatelessWidget {
  final String dayName;
  final int dayIdx;
  final Color color;
  final VoidCallback onBack;

  const _PlannerAppBar({
    required this.dayName, required this.dayIdx,
    required this.color,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.sm, top + AppSpacing.sm,
          AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
            bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        // Back button
        _Tap(
          onTap: () { H.tap(); onBack(); },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Title + subtitle
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('WEEKLY PLANNER', style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary, fontSize: 16,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 1),
          // Workout stats pill — Selector on scalar values so set-toggles
          // never trigger a rebuild here (only day-completion does).
          Selector<AppProvider, _AppBarStats>(
            selector: (_, ap) {
              if (ap.weekPlan.length <= dayIdx) return const _AppBarStats.empty();
              final day = ap.weekPlan[dayIdx];
              return _AppBarStats(
                exCount:   day.exercises.length,
                doneCount: day.completedExercises,
                isRest:    day.isRestDay,
                isDone:    day.isCompleted,
              );
            },
            builder: (_, s, __) {
              if (!s.isRest && s.exCount > 0) {
                return Row(children: [
                  Text(
                    s.isDone
                        ? '$dayName · Complete'
                        : '$dayName · ${s.doneCount} of ${s.exCount} complete',
                    style: GoogleFonts.inter(
                      color: s.isDone
                          ? AppColors.textMuted.withValues(alpha: 0.55)
                          : color,
                      fontSize: 11, fontWeight: FontWeight.w500,
                    ),
                  ),
                ]);
              }
              return Text(
                s.isRest
                    ? '$dayName · Recovery Day'
                    : '$dayName · No workout',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.75),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ])),

        // Session pill — only visible when a workout is active
        const _SessionPill(),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// ACTIVE SESSION PILL
// Live timer chip shown in AppBar when a workout is in progress.
// ════════════════════════════════════════════════
class _SessionPill extends StatelessWidget {
  const _SessionPill();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WorkoutSessionService.instance,
      builder: (_, __) {
        final svc = WorkoutSessionService.instance;
        if (!svc.isActive) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: AppColors.green.withValues(alpha: 0.28), width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(color: AppColors.green),
            const SizedBox(width: 5),
            Text(svc.elapsedFormatted,
                style: GoogleFonts.rajdhani(
                    color: AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// BANNER PRIORITY SLOT
// ════════════════════════════════════════════════
// PASSIVE STATUS LINE
// Always-on one-liner derived from live analytics.
// No buttons, no interaction — pure signal.
// ════════════════════════════════════════════════
class _PassiveStatusLine extends StatelessWidget {
  const _PassiveStatusLine();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({double risk, String trend, double pct, int daysSince})>(
      selector: (_, ap) => (
        risk:      ap.overTrainingRisk,
        trend:     ap.recoveryTrend,
        pct:       ap.weeklyImprovementPercent,
        daysSince: ap.daysSinceLastWorkout,
      ),
      builder: (_, d, __) {
        final msg = _derive(d.risk, d.trend, d.pct, d.daysSince);
        if (msg == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 5, AppSpacing.lg, 0),
          child: Text(msg,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1)),
        );
      },
    );
  }

  String? _derive(double risk, String trend, double pct, int daysSince) {
    if (risk > 70)    return 'Workload elevated — reduce volume today.';
    if (risk > 45)    return 'Volume accumulation building. Monitor fatigue.';
    if (daysSince >= 4) return 'Extended rest — comeback at 80% intensity.';
    if (trend == 'improving') return 'Recovery trending up — good push window.';
    if (trend == 'declining') return 'Recovery declining — prioritize form over load.';
    if (pct >= 20)    return 'High volume week. Prioritize sleep and hydration.';
    if (pct <= -20)   return 'Low volume this week. Comeback session recommended.';
    return 'Recovery stable.';
  }
}

// Shows ONE banner at a time, highest priority first.
// Priority: Overtraining > Injury > Comeback > RecoveryDirective > Adaptive > NewWeek > AI
// ════════════════════════════════════════════════
enum _ActiveBanner { overtraining, injury, comeback, recoveryDirective, adaptive, newWeek, ai }

class _ContextualBannerSlot extends StatelessWidget {
  final int dayIdx;
  const _ContextualBannerSlot({required this.dayIdx});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({_ActiveBanner which, int extraCount})>(
      selector: (_, ap) {
        final overtraining      = ap.overTrainingRisk > 60;
        final hasRisk           = ap.injuryRisks.isNotEmpty;
        final comeback          = ap.showComebackBanner;
        final recoveryDirective = ap.trainingAdjustment.isModified;
        final adaptive          = ap.shouldSuggestPlanRefresh;
        final newWeek           = ap.showNewWeekBanner;

        _ActiveBanner which;
        int extra = 0;

        if (overtraining) {
          which = _ActiveBanner.overtraining;
          if (hasRisk)           extra++;
          if (comeback)          extra++;
          if (recoveryDirective) extra++;
          if (adaptive)          extra++;
          if (newWeek)           extra++;
        } else if (hasRisk) {
          which = _ActiveBanner.injury;
          if (comeback)          extra++;
          if (recoveryDirective) extra++;
          if (adaptive)          extra++;
          if (newWeek)           extra++;
        } else if (comeback) {
          which = _ActiveBanner.comeback;
          if (recoveryDirective) extra++;
          if (adaptive)          extra++;
          if (newWeek)           extra++;
        } else if (recoveryDirective) {
          which = _ActiveBanner.recoveryDirective;
          if (adaptive) extra++;
          if (newWeek)  extra++;
        } else if (adaptive) {
          which = _ActiveBanner.adaptive;
          if (newWeek)   extra++;
        } else if (newWeek) {
          which = _ActiveBanner.newWeek;
        } else {
          which = _ActiveBanner.ai;
        }

        return (which: which, extraCount: extra);
      },
      builder: (_, s, __) {
        final banner = switch (s.which) {
          _ActiveBanner.overtraining      => const _OvertrainingBanner(),
          _ActiveBanner.injury            => const _InjuryRiskBanner(),
          _ActiveBanner.comeback          => const _ComebackBanner(),
          _ActiveBanner.recoveryDirective => const _RecoveryDirectiveBanner(),
          _ActiveBanner.adaptive          => const _AdaptivePlanBanner(),
          _ActiveBanner.newWeek           => const _NewWeekBanner(),
          _ActiveBanner.ai                => _AIBanner(dayIdx: dayIdx),
        };

        if (s.extraCount == 0) return banner;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          banner,
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, 4),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.textMuted, size: 10),
              const SizedBox(width: 4),
              Text('+${s.extraCount} more ${s.extraCount == 1 ? "insight" : "insights"}',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 9.5,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════
// RECOVERY DIRECTIVE BANNER — session-level coaching
// ════════════════════════════════════════════════
class _RecoveryDirectiveBanner extends StatelessWidget {
  const _RecoveryDirectiveBanner();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({String headline, String directive, double intensity, double volume})>(
      selector: (_, ap) {
        final a = ap.trainingAdjustment;
        return (
          headline:  a.readinessHeadline,
          directive: a.coachDirective,
          intensity: a.intensityMultiplier,
          volume:    a.volumeMultiplier,
        );
      },
      builder: (_, d, __) {
        final col = d.intensity >= 1.05
            ? AppColors.green
            : d.intensity >= 0.90
                ? AppColors.gold
                : AppColors.red;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: col.withValues(alpha: 0.22), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tune_rounded, color: col, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.headline,
                        style: GoogleFonts.inter(
                          color: col,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (d.directive.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          d.directive,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _AdjustmentPills(
                          intensityMult: d.intensity,
                          volumeMult:    d.volume),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdjustmentPills extends StatelessWidget {
  final double intensityMult;
  final double volumeMult;
  const _AdjustmentPills(
      {required this.intensityMult, required this.volumeMult});

  @override
  Widget build(BuildContext context) {
    String label(double mult, String noun) {
      if (mult >= 1.05) return '$noun elevated';
      if (mult >= 0.98) return '$noun unchanged';
      if (mult >= 0.85) return '$noun reduced';
      return '$noun trimmed';
    }

    Color col(double mult) {
      if (mult >= 1.05) return AppColors.green;
      if (mult >= 0.98) return AppColors.textMuted;
      if (mult >= 0.85) return AppColors.gold;
      return AppColors.red;
    }

    return Wrap(spacing: 5, children: [
      _AdjPill(label(intensityMult, 'Intensity'), col(intensityMult)),
      _AdjPill(label(volumeMult, 'Volume'),       col(volumeMult)),
    ]);
  }
}

class _AdjPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _AdjPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ════════════════════════════════════════════════
// AI BANNER — glassmorphism, state-aware accent
// ════════════════════════════════════════════════
class _AIBanner extends StatelessWidget {
  final int dayIdx;
  const _AIBanner({required this.dayIdx});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, String>(
      selector: (_, ap) => ap.plannerNarrativeFor(dayIdx),
      builder: (_, msg, __) {
        final text = msg.isEmpty ? 'Ready to train today.' : msg;
        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 2),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.20), width: 0.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI COACH',
                style: GoogleFonts.inter(
                  color: AppColors.goldAmber.withValues(alpha: 0.60),
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(text,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.visible,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Banner dismiss persistence helpers ─────────────────────────────────────
// Key is stored with today's date so banners auto-reset each new day.
String _todayKey(String name) {
  final d = DateTime.now();
  return 'banner_${name}_${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
}

Future<bool> _isBannerDismissed(String name) async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_todayKey(name)) == true;
}

Future<void> _persistBannerDismiss(String name) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_todayKey(name), true);
}
// ─────────────────────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════
// ADAPTIVE PLAN BANNER — fires when plateau or deload detected
// ════════════════════════════════════════════════
class _AdaptivePlanBanner extends StatefulWidget {
  const _AdaptivePlanBanner();
  @override State<_AdaptivePlanBanner> createState() => _AdaptivePlanBannerState();
}

class _AdaptivePlanBannerState extends State<_AdaptivePlanBanner> {
  bool _dismissed = false;
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    _isBannerDismissed('adaptive_plan').then((v) {
      if (mounted && v) setState(() => _dismissed = true);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _persistBannerDismiss('adaptive_plan');
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({bool show, bool plateau, bool deload})>(
      selector: (_, ap) => (
        show:    ap.shouldSuggestPlanRefresh,
        plateau: ap.isOnPlateau,
        deload:  ap.needsDeloadByVolume,
      ),
      builder: (ctx, data, __) {
        if (!data.show || _dismissed) return const SizedBox.shrink();

        final reason = data.plateau
            ? 'Plateau detected — same weights 3+ weeks'
            : 'High volume — deload week recommended';
        final action = data.plateau
            ? 'AI can rotate exercises to break through'
            : 'AI will reduce volume for recovery';

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.30), width: 0.9),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded,
                color: AppColors.gold, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reason, style: GoogleFonts.inter(
                    color: AppColors.gold, fontSize: 11,
                    fontWeight: FontWeight.w700)),
                Text(action, style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 10)),
              ],
            )),
            const SizedBox(width: AppSpacing.sm),
            if (_loading)
              Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.gold)),
                const SizedBox(height: 3),
                Text('Analyzing...', style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 8.5)),
              ])
            else
              GestureDetector(
                onTap: () async {
                  final p = ctx.read<AppProvider>();
                  if (!p.canUseAI()) {
                    await PaywallSheet.show(ctx,
                      trigger:      PaywallTrigger.aiLimitHit,
                      onUpgrade:    () => p.notifyListeners(),
                      onAdComplete: () => p.notifyListeners(),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    final plan = await p.getAIWorkoutPlan();
                    if (!ctx.mounted) return;
                    await p.applyAIWorkout(plan);
                    final insight = p.workoutGenerationContextLine;
                    if (insight.isNotEmpty && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(insight,
                            style: GoogleFonts.inter(fontSize: 12.5)),
                        backgroundColor: const Color(0xFF1C1C1C),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                    _dismiss();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF8C6A1A), Color(0xFFBF953F),
                    ]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Refresh', style: GoogleFonts.inter(
                      color: Colors.black, fontSize: 11,
                      fontWeight: FontWeight.w800)),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: _dismiss,
              child: Icon(Icons.close_rounded,
                  color: AppColors.textMuted, size: 16),
            ),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// NEW WEEK BANNER — fires on first open after week reset
// ════════════════════════════════════════════════
class _NewWeekBanner extends StatefulWidget {
  const _NewWeekBanner();
  @override State<_NewWeekBanner> createState() => _NewWeekBannerState();
}

class _NewWeekBannerState extends State<_NewWeekBanner> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({bool show, int completed, int planned, double volume})>(
      selector: (_, ap) {
        final mem = ap.lastWeekMemory;
        return (
          show:      ap.showNewWeekBanner,
          completed: mem?.completedDays ?? 0,
          planned:   mem?.plannedDays   ?? 0,
          volume:    mem?.totalVolume   ?? 0,
        );
      },
      builder: (ctx, data, __) {
        if (!data.show) return const SizedBox.shrink();

        final pct = data.planned > 0
            ? '${data.completed}/${data.planned} days'
            : 'new week';
        final vol = data.volume > 0
            ? ' · ${(data.volume / 1000).toStringAsFixed(1)}t lifted'
            : '';

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35), width: 0.9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.date_range_rounded,
                    color: AppColors.gold, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('New week — plan updated',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary, fontSize: 15,
                      fontWeight: FontWeight.w800))),
                GestureDetector(
                  onTap: () => ctx.read<AppProvider>().dismissNewWeekBanner(),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 16),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Last week: $pct$vol · Progressive plan ready',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        ctx.read<AppProvider>().dismissNewWeekBanner(),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: Text('Dismiss',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: _loading
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.gold)),
                          const SizedBox(height: 4),
                          Text('Building plan...', style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 9)),
                        ]))
                      : GoldButton(
                          text: 'Upgrade with AI',
                          small: true,
                          onTap: () async {
                            final p = ctx.read<AppProvider>();
                            if (!p.canUseAI()) {
                              await PaywallSheet.show(ctx,
                                trigger:      PaywallTrigger.aiLimitHit,
                                onUpgrade:    () => p.notifyListeners(),
                                onAdComplete: () => p.notifyListeners(),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              final plan = await p.getAIWorkoutPlan();
                              if (!ctx.mounted) return;
                              await p.applyAIWorkout(plan);
                              final insight = p.workoutGenerationContextLine;
                              if (insight.isNotEmpty && ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(insight,
                                      style: GoogleFonts.inter(fontSize: 12.5)),
                                  backgroundColor: const Color(0xFF1C1C1C),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ));
                              }
                              p.dismissNewWeekBanner();
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                        ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// COMEBACK BANNER — 4+ days since last workout
// ════════════════════════════════════════════════
class _ComebackBanner extends StatefulWidget {
  const _ComebackBanner();
  @override State<_ComebackBanner> createState() => _ComebackBannerState();
}

class _ComebackBannerState extends State<_ComebackBanner> {
  bool _dismissed = false;
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    _isBannerDismissed('comeback').then((v) {
      if (mounted && v) setState(() => _dismissed = true);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _persistBannerDismiss('comeback');
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({bool show, int days})>(
      selector: (_, ap) => (
        show: ap.showComebackBanner,
        days: ap.daysSinceLastWorkout,
      ),
      builder: (ctx, data, __) {
        if (!data.show || _dismissed) return const SizedBox.shrink();

        final intensity = data.days >= 7 ? '70%' : '80%';
        final science   = data.days >= 7
            ? 'Detraining after 7d — restart light'
            : 'Gap detected — ramp up gradually';

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.40), width: 0.9),
          ),
          child: Row(children: [
            const Icon(Icons.fitness_center_rounded,
                color: AppColors.orange, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${data.days}-day gap — comeback time',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w800)),
                Text('$science. Use $intensity of last weights today.',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 10.5,
                      height: 1.4)),
              ],
            )),
            const SizedBox(width: AppSpacing.sm),
            if (_loading)
              Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.orange)),
                const SizedBox(height: 3),
                Text('Analyzing...', style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 8.5)),
              ])
            else
              GestureDetector(
                onTap: () async {
                  final p = ctx.read<AppProvider>();
                  if (!p.canUseAI()) {
                    await PaywallSheet.show(ctx,
                      trigger:      PaywallTrigger.aiLimitHit,
                      onUpgrade:    () => p.notifyListeners(),
                      onAdComplete: () => p.notifyListeners(),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    final plan = await p.getAIWorkoutPlan();
                    if (!ctx.mounted) return;
                    await p.applyAIWorkout(plan);
                    final insight = p.workoutGenerationContextLine;
                    if (insight.isNotEmpty && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(insight,
                            style: GoogleFonts.inter(fontSize: 12.5)),
                        backgroundColor: const Color(0xFF1C1C1C),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                    _dismiss();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.40)),
                  ),
                  child: Text('Adjust Plan',
                    style: GoogleFonts.inter(
                        color: AppColors.orange, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: _dismiss,
              child: Icon(Icons.close_rounded,
                  color: AppColors.textMuted, size: 16),
            ),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// DAY STRIP — larger tiles, progress, today pulse
// ════════════════════════════════════════════════
class _DayStrip extends StatelessWidget {
  final int selected;
  final List<String> shorts;
  final ValueChanged<int> onSelect;

  const _DayStrip({
    required this.selected,
    required this.shorts,
    required this.onSelect,
  });

  DateTime _weekDate(int index) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: index));
  }

  // Encodes isCompleted + isRestDay + exercise count per day into a single int.
  // Selector compares this int with == — rebuilds only when a day is completed,
  // a rest day is toggled, or an exercise is added/removed. NOT on set toggles.
  static int _bitmask(AppProvider ap) {
    var bits = ap.todayIndex;
    final plan = ap.weekPlan;
    for (int i = 0; i < plan.length.clamp(0, 7); i++) {
      if (plan[i].isCompleted) bits |= (1 << (i + 4));
      if (plan[i].isRestDay)   bits |= (1 << (i + 11));
      bits ^= (plan[i].exercises.length & 0xF) << (i * 4 + 18);
    }
    return bits;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, int>(
      selector: (_, ap) => _bitmask(ap),
      builder: (ctx, _, __) {
        final ap = ctx.read<AppProvider>();
        final plan = ap.weekPlan;
        final todayIdx = ap.todayIndex;
        final n = plan.length.clamp(0, 7);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
            bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.4))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Row(
        children: List.generate(n, (i) {
          final day = plan[i];
          final sel = i == selected;
          final tod = i == todayIdx;
          final missed = i < todayIdx &&
              !day.isCompleted &&
              !day.isRestDay &&
              day.exercises.isNotEmpty;
          final col = AppColors.dayColors[i % AppColors.dayColors.length];

          return Expanded(child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.gold.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? AppColors.gold.withValues(alpha: 0.22)
                      : tod
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.transparent,
                  width: sel ? 0.8 : 0.6,
                ),
                boxShadow: const [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Day label
                Text(shorts[i], style: GoogleFonts.inter(
                  color: sel
                      ? AppColors.gold
                      : tod
                          ? col.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                  fontSize: 8.5, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
                const SizedBox(height: 2),

                Text(
                  '${_weekDate(i).day}',
                  style: GoogleFonts.rajdhani(
                    color: sel
                        ? AppColors.textPrimary
                        : tod
                            ? col.withValues(alpha: 0.92)
                            : AppColors.textMuted.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: tod
                        ? FontWeight.w800
                        : FontWeight.w700,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 4),

                // Day indicator dot / icon
                _DayIndicator(
                  day: day,
                  color: col,
                  sel: sel,
                  tod: tod,
                  missed: missed,
                ),

                // Today pulse dot
                if (tod) ...[
                  const SizedBox(height: 4),
                  _PulseDot(color: col),
                ] else
                  const SizedBox(height: 4),

                // Workout title for selected day
                if (sel && !day.isRestDay && day.title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _fixTitleGrammar(day.title),
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      color: AppColors.gold.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const SizedBox(height: 0),
              ]),
            ),
          ));
        }),
      ),
    );
      }, // Selector builder end
    );   // Selector end
  }
}

class _DayIndicator extends StatelessWidget {
  final DayPlan day;
  final Color color;
  final bool sel, tod, missed;

  const _DayIndicator({
    required this.day,
    required this.color,
    required this.sel,
    required this.tod,
    required this.missed,
  });

  @override
  Widget build(BuildContext context) {
    if (day.isRestDay) {
      return Text(
        'REST',
        style: GoogleFonts.inter(
          color: AppColors.textMuted.withValues(alpha: 0.55),
          fontSize: sel ? 9 : 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
    }
    if (missed) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.24),
            width: 0.8,
          ),
        ),
        child: const Icon(
          Icons.close_rounded,
          color: AppColors.red,
          size: 13,
        ),
      );
    }

    if (day.isCompleted) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.20), width: 0.8),
        ),
        child: const Icon(Icons.check_rounded,
            color: AppColors.gold, size: 13),
      );
    }
    if (day.exercises.isEmpty) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.14)
              : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded,
            color: sel ? color : AppColors.textMuted, size: 14),
      );
    }
    // Has exercises — show count with completion arc
    final done  = day.completedExercises;
    final total = day.exercises.length;
    final pct   = done / total;
    return SizedBox(
      width: 30, height: 30,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: pct,
          strokeWidth: 2.5,
          backgroundColor: AppColors.bgElevated,
          valueColor: AlwaysStoppedAnimation(
              done == total ? AppColors.green : color),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$total', style: GoogleFonts.rajdhani(
                color: sel ? color : AppColors.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
            Text('ex', style: GoogleFonts.inter(
                color: (sel ? color : AppColors.textMuted).withValues(alpha: 0.55),
                fontSize: 5.5, fontWeight: FontWeight.w600, letterSpacing: 0.2,
                height: 1)),
          ],
        ),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _p;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _p = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _p,
    builder: (_, __) => Container(
      width: 5, height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: _p.value),
      ),
    ),
  );
}

// ════════════════════════════════════════════════
// DAY BODY
// ════════════════════════════════════════════════
class _DayBody extends StatefulWidget {
  final int idx; final String name;
  const _DayBody({super.key, required this.idx, required this.name});
  @override
  State<_DayBody> createState() => _DayBodyState();
}

class _DayBodyState extends State<_DayBody> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _DayBody old) {
    super.didUpdateWidget(old);
    // Day changed — jump to top so user sees Day Header, not middle of list.
    if (old.idx != widget.idx && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p  = context.watch<AppProvider>();
    final wp = p.weekPlan;
    if (wp.isEmpty) return const SizedBox.shrink();
    final safe = widget.idx.clamp(0, wp.length - 1);
    final day  = wp[safe];
    final col  = AppColors.dayColors[safe % AppColors.dayColors.length];

    return ListView(
      controller: _scroll,
      cacheExtent: 400,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 90),
      children: [
        _DayHeader(day: day, name: widget.name, color: col, idx: safe),
        const SizedBox(height: AppSpacing.md),
        if (day.isRestDay)
          _RestCard(idx: safe, color: col)
        else ...[
          if (safe == p.todayIndex && !day.isCompleted) ...[
            // Phase 2: comeback + recovery session both active → single WELCOME BACK card
            if (p.isComebackSession &&
                p.plannerAdaptiveState == PlannerAdaptiveState.interventionRequired &&
                p.recoverySuggestion.shouldSuggestAlternative)
              _WelcomeBackCard(suggestion: p.recoverySuggestion)
            else ...[
              // Phase 1: comebackSession adaptive card suppressed — top banner covers it
              if (p.plannerAdaptiveState == PlannerAdaptiveState.interventionRequired &&
                  !p.isComebackSession)
                _AdaptiveDecisionCard(idx: safe)
              else if (p.plannerAdaptiveState == PlannerAdaptiveState.recoveryAligned)
                _RecoveryAlignedInsight(message: p.recoveryAlignedMessage),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: (p.recoverySuggestion.shouldSuggestAlternative &&
                        !day.exercises.any((ex) => ex.sets.any((s) => s.done)))
                    ? _RecoverySessionCard(suggestion: p.recoverySuggestion)
                    : p.yesterdayMissedPlan != null
                        ? _MissedDayRecoveryCard(missed: p.yesterdayMissedPlan!)
                        : const SizedBox.shrink(),
              ),
            ],
            if (p.topWeeklyAdjustment != null)
              _WeeklyAdjustmentBanner(adjustment: p.topWeeklyAdjustment!),
            if (!p.onboardingComplete && p.isHighIntimidation)
              const _OnboardingConfidenceNote(),
          ],
          if (day.exercises.isEmpty)
            _EmptyDay(idx: safe, color: col, p: p)
          else ...[
            ...day.exercises.asMap().entries.map((e) =>
                RepaintBoundary(
                  key: ValueKey(e.value.id),
                  child: _ExCard(ex: e.value, idx: safe, color: col,
                      entryDelay: e.key * 50),
                )),
            const SizedBox(height: AppSpacing.sm),
            _AddBtn(idx: safe, color: col),
            if (!day.isCompleted) ...[
              const SizedBox(height: AppSpacing.sm),
              _CompleteBtn(idx: safe),
            ],
          ],
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════
// DAY HEADER — with workout stats row
// ════════════════════════════════════════════════

// Normalise AI-generated or template workout titles: singular muscle names
// like "Tricep" and "Bicep" are corrected to their anatomical plural form.
String _fixTitleGrammar(String t) {
  final cleaned = t
      .replaceAll(RegExp(r'\bTricep\b'), 'Triceps')
      .replaceAll(RegExp(r'\bBicep\b'), 'Biceps')
      .replaceAll('😴', '')
      .replaceAll('😪', '')
      .trim();
  // Title-case every word: "chest and bicep" → "Chest And Bicep"
  return cleaned.split(' ').map((w) {
    if (w.isEmpty) return w;
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }).join(' ');
}

class _DayHeader extends StatelessWidget {
  final DayPlan day; final String name;
  final Color color; final int idx;
  const _DayHeader({required this.day, required this.name,
      required this.color, required this.idx});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final fat = AIEngine.detectFatigue(p.lastWorkouts);
    final exCount  = day.exercises.length;
    final setCount = day.exercises.fold(0, (s, e) => s + e.sets.length);
    final vol      = day.exercises.fold(0.0, (s, e) =>
        s + e.sets.fold(0.0, (ss, set) => ss + set.weight * set.reps));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Fatigue warning
      if (fat.isNotEmpty) Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.red.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.red, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(fat, style: GoogleFonts.inter(
              color: AppColors.red, fontSize: 12,
              fontWeight: FontWeight.w600))),
        ]),
      ),

      // Header card — compact single row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.25), width: 0.4),
        ),
        child: Row(children: [
          Container(
            width: 3, height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.3)]),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Hero(
                    tag: 'planner-workout-title-$idx',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        day.title.isEmpty ? 'Workout' : _fixTitleGrammar(day.title),
                        style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary, fontSize: 15,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                if (day.wasEdited) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
                    ),
                    child: Text('EDITED', style: GoogleFonts.inter(
                        color: AppColors.gold.withValues(alpha: 0.65),
                        fontSize: 7, fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (exCount > 0) ...[
            if (day.isCompleted)
              Text('$setCount sets  •  Complete',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted.withValues(alpha: 0.50),
                      fontSize: 10, fontWeight: FontWeight.w500))
            else ...[
              _StatChip(Icons.fitness_center_rounded, '$exCount ex'),
              const SizedBox(width: 5),
              _StatChip(Icons.refresh_rounded, '$setCount sets'),
              if (vol > 0) ...[
                const SizedBox(width: 5),
                _StatChip(Icons.bar_chart_rounded,
                    '${(vol / 1000).toStringAsFixed(1)}t'),
              ],
            ],
          ],
          const SizedBox(width: 4),
          _HeaderMenu(day: day, idx: idx, p: p),
        ]),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.bgCardLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.textMuted, size: 11),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 11,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ════════════════════════════════════════════════
// ADAPTIVE DECISION CARD — session-level coaching
// Shows focus mode, athlete message, and exercise swap suggestions for today.
// Only renders for today's non-completed day when shouldModifyWorkout is true.
// ════════════════════════════════════════════════
class _AdaptiveDecisionCard extends StatelessWidget {
  final int idx;
  const _AdaptiveDecisionCard({required this.idx});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({bool isModified, String label, String message, int swapCount, int focusIdx})>(
      selector: (_, ap) => (
        isModified: ap.isAdaptiveModified,
        label:      ap.adaptiveFocusLabel,
        message:    ap.adaptiveAthleteMessage,
        swapCount:  ap.adaptiveSwaps.length,
        focusIdx:   ap.adaptiveFocusIndex,
      ),
      builder: (_, d, __) {
        if (!d.isModified || d.message.isEmpty) return const SizedBox.shrink();

        final swaps = context.read<AppProvider>().adaptiveSwaps;

        final (icon, col) = switch (d.focusIdx) {
          0 => (Icons.bolt_rounded,                    AppColors.green),
          2 => (Icons.battery_charging_full_rounded,   AppColors.gold),
          3 => (Icons.nightlight_rounded,              AppColors.textMuted),
          4 => (Icons.trending_up_rounded,             AppColors.green),
          5 => (Icons.fitness_center_rounded,          AppColors.green),
          6 => (Icons.precision_manufacturing_rounded, AppColors.textSecondary),
          7 => (Icons.emoji_events_rounded,            AppColors.gold),
          _ => (Icons.sync_rounded,                    AppColors.textMuted),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: col.withValues(alpha: 0.20), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: icon + focus label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Icon(icon, color: col, size: 14),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      d.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: col,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Athlete-facing message
                Text(
                  d.message,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                // Exercise swaps (first 3 max)
                if (swaps.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'SUGGESTED SWAPS',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ...swaps.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.original,
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: AppColors.textMuted, size: 11),
                        ),
                        Flexible(
                          child: Text(
                            s.replacement,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// RECOVERY ALIGNED INSIGHT
// Calm contextual line shown when recovery conditions exist but don't
// conflict with today's planned session. No warning, no modal.
// ════════════════════════════════════════════════
class _RecoveryAlignedInsight extends StatelessWidget {
  final String message;
  const _RecoveryAlignedInsight({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 34,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary.withValues(alpha: 0.75),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// WEEKLY ADJUSTMENT BANNER — Phase 14
// Advisory-only. Never auto-edits the plan.
// ════════════════════════════════════════════════
class _WeeklyAdjustmentBanner extends StatelessWidget {
  final WeeklyAdjustment adjustment;
  const _WeeklyAdjustmentBanner({required this.adjustment});

  Color _col() => switch (adjustment.priority) {
    AdjustmentPriority.high     => AppColors.orange,
    AdjustmentPriority.moderate => AppColors.blue,
    AdjustmentPriority.low      => AppColors.textMuted,
  };

  IconData _icon() => switch (adjustment.type) {
    WeeklyAdjustmentType.reduceVolume       => Icons.compress_rounded,
    WeeklyAdjustmentType.increaseVolume     => Icons.expand_rounded,
    WeeklyAdjustmentType.shiftFrequency     => Icons.sync_rounded,
    WeeklyAdjustmentType.rotateExercise     => Icons.swap_horiz_rounded,
    WeeklyAdjustmentType.reduceAxialLoad    => Icons.arrow_downward_rounded,
    WeeklyAdjustmentType.addRecoveryDay     => Icons.hotel_rounded,
    WeeklyAdjustmentType.increaseIntensity  => Icons.trending_up_rounded,
    WeeklyAdjustmentType.technicalFocus     => Icons.precision_manufacturing_rounded,
    WeeklyAdjustmentType.restoreConsistency => Icons.calendar_today_rounded,
    WeeklyAdjustmentType.reduceHingeLoading => Icons.accessibility_new_rounded,
    WeeklyAdjustmentType.swapMovement       => Icons.compare_arrows_rounded,
    WeeklyAdjustmentType.recoveryEmphasis   => Icons.self_improvement_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final col = _col();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: col.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(_icon(), color: col, size: 14),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(
              adjustment.title.toUpperCase(),
              style: GoogleFonts.inter(
                color: col, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.8),
              overflow: TextOverflow.ellipsis,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('THIS WEEK', style: GoogleFonts.inter(
                color: col.withValues(alpha: 0.70), fontSize: 7.5,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(adjustment.athleteFacingMessage, style: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 12.5,
            fontWeight: FontWeight.w500, height: 1.45)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// ONBOARDING CONFIDENCE NOTE — Phase 15
// Shown only when intimidation is high and onboarding is not complete.
// Calm, low-pressure encouragement — no metrics, no urgency.
// ════════════════════════════════════════════════
class _OnboardingConfidenceNote extends StatelessWidget {
  const _OnboardingConfidenceNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
              color: AppColors.textMuted.withValues(alpha: 0.14), width: 0.7),
        ),
        child: Row(children: [
          const Icon(Icons.spa_rounded,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(
            'Short, consistent sessions build lasting momentum — there\'s no rush.',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          )),
        ]),
      ),
    );
  }
}

class _HeaderMenu extends StatelessWidget {
  final DayPlan day; final int idx; final AppProvider p;
  const _HeaderMenu({required this.day, required this.idx, required this.p});

  String _type(int i) {
    final s = p.level == 'beginner'
        ? ['Full','Rest','Full','Rest','Full','Rest','Rest']
        : (p.level == 'advanced' && p.goal == 'muscle_gain')
            ? ['Push','Pull','Legs','Push','Pull','Legs','Rest']
            : ['Push','Pull','Legs','Rest','Push','Pull','Rest'];
    final r = i < s.length ? s[i] : 'Full';
    return r == 'Rest' ? 'Full' : r;
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.bgCardLight,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    icon: const Icon(Icons.more_horiz_rounded,
        color: AppColors.textMuted, size: 20),
    onSelected: (v) {
      H.tap();
      switch (v) {
        case 'rename': _renameDialog(context);  break;
        case 'generate': p.generateWorkoutForDay(_type(idx), idx); break;
        case 'rest': p.toggleRestDay(idx); break;
        case 'clear': p.clearDay(idx); break;
      }
    },
    itemBuilder: (_) => [
      _mi('rename',   Icons.edit_outlined,         'Rename'),
      _mi('generate', Icons.auto_awesome_rounded,  'AI Generate'),
      _mi('rest',     Icons.bedtime_outlined,
          day.isRestDay ? 'Unset Rest Day' : 'Set as Rest Day'),
      _mi('clear',    Icons.delete_sweep_outlined,
          'Clear Day', AppColors.red),
    ],
  );

  PopupMenuItem<String> _mi(String v, IconData ic, String t, [Color? c]) =>
      PopupMenuItem(value: v, child: Row(children: [
        Icon(ic, color: c ?? AppColors.textSecondary, size: 17),
        const SizedBox(width: AppSpacing.sm),
        Text(t, style: GoogleFonts.inter(
            color: c ?? AppColors.textPrimary, fontSize: 13)),
      ]));

  void _renameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: p.weekPlan[idx].title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Rename Workout', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: GoogleFonts.inter(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'e.g. Push Day A'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(
                color: AppColors.textMuted))),
        GoldButton(text: 'Save', onTap: () {
          if (ctrl.text.trim().isNotEmpty) {
            p.updateDayTitle(idx, ctrl.text.trim());
          }
          Navigator.pop(ctx);
        }),
      ],
    ));
  }
}

// ════════════════════════════════════════════════
// REST CARD
// ════════════════════════════════════════════════
class _RestCard extends StatelessWidget {
  final int idx; final Color color;
  const _RestCard({required this.idx, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: const Color(0xFF101010),
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.05),
          const Color(0xFF101010),
          const Color(0xFF0B0B0B),
        ],
        stops: const [0.0, 0.26, 1.0],
      ),
      border: Border.all(
        color: color.withValues(alpha: 0.16),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 24,
          spreadRadius: -6,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(children: [

      Text('Rest Day', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 20,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      Text('Recovery is where the gains happen.\nYou\'ve earned this.',
          style: GoogleFonts.inter(color: AppColors.textMuted,
              fontSize: 12, height: 1.4),
          textAlign: TextAlign.center),
      const SizedBox(height: 18),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: 10),
        ),
        onPressed: () {
          H.tap();
          context.read<AppProvider>().toggleRestDay(idx);
        },
        child: Text('Change to Workout Day',
            style: GoogleFonts.rajdhani(
                color: color, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// EMPTY DAY CARD
// ════════════════════════════════════════════════
class _EmptyDay extends StatelessWidget {
  final int idx; final Color color; final AppProvider p;
  const _EmptyDay({required this.idx, required this.color,
      required this.p});

  void _gen(BuildContext ctx) {
    H.medium();
    final split = _type();
    p.generateWorkoutForDay(split, idx);
    final updated = p.weekPlan[idx];
    if (updated.exercises.isEmpty) {
      final workout = AIEngine.generateDayWorkout(
        goal: p.goal, level: p.level, type: split,
        history: p.lastWorkouts, weakMuscle: p.weakMuscle,
        isBeginner: p.level == 'beginner',
      );
      for (final ex in workout) {
        p.addExercise(idx,
          name:         ex['name']       as String? ?? '',
          category:     ex['muscle']     as String? ?? '',
          emoji:        ex['emoji']      as String? ?? '💪',
          type:         ex['type']       as String? ?? '',
          unit:         ex['unit']       as String? ?? 'kg',
          baseId:       '${ex["name"]}_${ex["type"] ?? ""}',
          isBodyweight: ex['bodyweight'] as bool?   ?? false,
        );
      }
    }
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('AI Workout Ready',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _type() {
    final s = p.level == 'beginner'
        ? ['Full','Rest','Full','Rest','Full','Rest','Rest']
        : (p.level == 'advanced' && p.goal == 'muscle_gain')
            ? ['Push','Pull','Legs','Push','Pull','Legs','Rest']
            : ['Push','Pull','Legs','Rest','Push','Pull','Rest'];
    final r = idx < s.length ? s[idx] : 'Full';
    return r == 'Rest' ? 'Full' : r;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
    ),
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.06),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.fitness_center_rounded, color: color, size: 32),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('No Exercises Yet', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 22,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      Text('Build your perfect workout\nby adding exercises below.',
          style: GoogleFonts.inter(color: AppColors.textMuted,
              fontSize: 12, height: 1.4),
          textAlign: TextAlign.center),
      const SizedBox(height: 18),

      // Add Exercises button (manual)
      _Tap(
        onTap: () { H.tap(); _showPicker(context, idx); },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4AF37), Color(0xFFA8892C)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.add_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('Add Exercises', style: GoogleFonts.rajdhani(
                color: Colors.black, fontSize: 17,
                fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// ADD BUTTON
// ════════════════════════════════════════════════
class _AddBtn extends StatelessWidget {
  final int idx; final Color color;
  const _AddBtn({required this.idx, required this.color});
  @override
  Widget build(BuildContext context) => _Tap(
    onTap: () { H.light(); _showPicker(context, idx); },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.add_rounded,
            color: AppColors.textMuted, size: 15),
        const SizedBox(width: 6),
        Text('Add Exercise', style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// DIALOG STAT HELPERS — used in completion dialog
// ════════════════════════════════════════════════
class _DialogStat extends StatelessWidget {
  final String value, label;
  const _DialogStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 16,
          fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 9.5,
          fontWeight: FontWeight.w500)),
    ],
  );
}

class _DialogStatDivider extends StatelessWidget {
  const _DialogStatDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 0.6, height: 24,
    color: AppColors.divider.withValues(alpha: 0.5),
  );
}

// ════════════════════════════════════════════════
// COMPLETE BUTTON
// ════════════════════════════════════════════════
class _CompleteBtn extends StatefulWidget {
  final int idx;
  const _CompleteBtn({required this.idx});
  @override State<_CompleteBtn> createState() => _CompleteBtnState();
}

class _CompleteBtnState extends State<_CompleteBtn> {
  bool _dialogOpen = false;

  void _dialog(BuildContext ctx) {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    H.medium();
    // Auto-fill from active session if available
    final session = WorkoutSessionService.instance;
    int dur = session.isActive
        ? session.elapsed.inMinutes.clamp(5, 120)
        : 45;
    // Pre-capture workout stats for summary row
    final ap = ctx.read<AppProvider>();
    final day = ap.weekPlan.length > widget.idx ? ap.weekPlan[widget.idx] : null;
    final exCount  = day?.exercises.length ?? 0;
    final setCount = day?.exercises.fold(0, (s, e) => s + e.sets.length) ?? 0;
    final vol      = day?.exercises.fold(0.0, (s, e) =>
        s + e.sets.fold(0.0, (ss, set) => ss + set.weight * set.reps)) ?? 0.0;

    showDialog(context: ctx, builder: (d) => StatefulBuilder(
      builder: (d2, ss) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        title: Row(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.gold, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text('Workout Complete', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          ),
        ]),
        // Buttons live inside content — Row + Expanded = zero overflow
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Workout summary row ─────────────────────────
          if (exCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.borderSoft, width: 0.7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DialogStat('$exCount', 'exercises'),
                  _DialogStatDivider(),
                  _DialogStat('$setCount', 'sets'),
                  if (vol > 0) ...[
                    _DialogStatDivider(),
                    _DialogStat(
                        '${(vol / 1000).toStringAsFixed(1)}t', 'volume'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('How long did you train?', style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpacing.md),
          // ── Preset chips ──────────────────────────────────
          Row(children: [
            for (final preset in [30, 45, 60, 90])
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () { H.selection(); ss(() => dur = preset); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: AppCurves.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: dur == preset
                          ? AppColors.gold.withValues(alpha: 0.12)
                          : const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: dur == preset
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.06),
                        width: dur == preset ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text('${preset}m', textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        color: dur == preset
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              )),
          ]),
          const SizedBox(height: AppSpacing.md),
          // ── Fine-tune stepper ─────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_rounded),
              color: AppColors.gold, iconSize: 32,
              onPressed: () {
                H.selection();
                ss(() => dur = (dur - 5).clamp(5, 120));
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8),
              ),
              child: Text('$dur min', style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 34,
                  fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              color: AppColors.gold, iconSize: 32,
              onPressed: () {
                H.selection();
                ss(() => dur = (dur + 5).clamp(5, 120));
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          // ── Buttons — adaptive vertical layout ──────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoldButton(
                  text: 'Complete Workout',
                  icon: Icons.check_circle_rounded,
                  onTap: () async {
                final p  = ctx.read<AppProvider>();
                final gp = ctx.read<GamificationProvider>();
                Navigator.pop(d2);
                await WorkoutSessionService.instance.endSession();
                final badges    = await p.markDayComplete(widget.idx, dur);
                final weightMsg = p.weightSuggestionMessage;
                final xp = XPSystem.xpWorkoutComplete +
                    XPSystem.xpStreakBonus *
                    (p.streak.currentStreak ~/ 7 + 1);
                gp.addXP(xp); gp.onWorkoutComplete();
                for (final b in badges) gp.triggerBadgePopup(b);
                // Coach reaction: build a fresh message after the session is saved.
                final coachMsg  = p.aiSuggestion;
                final hasPR     = p.recentPRs.isNotEmpty &&
                    DateTime.now().difference(p.recentPRs.last.date).inHours < 1;
                final volTonnes = p.weeklyVolumeTotalKg / 1000;
                if (!ctx.mounted) return;
                await showWorkoutCelebration(ctx,
                  xp:                xp,
                  streak:            p.streak.currentStreak,
                  duration:          dur,
                  badges:            badges.map((b) => b.emoji).toList(),
                  coachReaction:     coachMsg.isNotEmpty ? coachMsg : null,
                  hasPR:             hasPR,
                  totalVolumeTonnes: volTonnes > 0 ? volTonnes : 0.0,
                );
                if (!ctx.mounted) return;
                final trigger = p.pendingPaywallTrigger;
                if (trigger != null) {
                  p.clearPaywallTrigger();
                  await PaywallSheet.show(ctx,
                    trigger:   trigger,
                    onUpgrade: () => p.notifyListeners(),
                    onAdComplete: () => p.notifyListeners(),
                  );
                }
                // Session summary sheet — AI analysis of the just-completed workout
                if (!ctx.mounted) return;
                final ap2 = ctx.read<AppProvider>();
                final day2 = ap2.weekPlan.length > widget.idx ? ap2.weekPlan[widget.idx] : null;
                await _showSessionSummarySheet(ctx,
                  duration:  dur,
                  weightMsg: weightMsg,
                  dayTitle:  day2?.title ?? '',
                  exCount:   exCount,
                  setCount:  setCount,
                  volumeKg:  vol,
                  recovery:  ap2.getOverallRecovery(),
                  streak:    ap2.streak.currentStreak,
                );
              }),
            ],
          ),
        ]),
      ),
    )).whenComplete(() {
      if (mounted) setState(() => _dialogOpen = false);
    });
  }

  Future<void> _showSessionSummarySheet(
    BuildContext ctx, {
    required int    duration,
    required String weightMsg,
    required String dayTitle,
    required int    exCount,
    required int    setCount,
    required double volumeKg,
    required int    recovery,
    required int    streak,
  }) {
    return showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Consumer<AIProvider>(
        builder: (_, aiProv, __) {
          final isLoading = aiProv.isGeneratingSessionInsight;
          final insight   = aiProv.lastSessionInsight;
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.bgModal,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25), width: 0.9),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.hub_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Session Analyzed', style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          width: 0.8),
                    ),
                    child: Text('$duration min',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.gold, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                // ── Gemini insight or loading ─────────────────
                if (isLoading)
                  Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Analyzing your session...',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 13,
                        fontStyle: FontStyle.italic)),
                  ])
                else
                  Text(
                    insight.isNotEmpty ? insight : 'Session logged. Keep the momentum going.',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13, height: 1.55),
                  ),
                // ── Weight suggestion chip ────────────────────
                if (weightMsg.isNotEmpty && !weightMsg.startsWith('🔒')) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.22),
                          width: 0.8),
                    ),
                    child: Text(weightMsg,
                      style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 12, fontWeight: FontWeight.w500,
                        height: 1.4)),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12)),
                      child: Text('Got it', style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showShareSheet(ctx,
                          dayTitle: dayTitle,
                          exCount:  exCount,
                          setCount: setCount,
                          volumeKg: volumeKg,
                          duration: duration,
                          recovery: recovery,
                          streak:   streak,
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 15),
                      label: Text('Share', style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.5),
                            width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.button)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: GoldButton(
                      text: 'Chat with Coach',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        Navigator.push(
                            ctx, slideRoute(const AIChatScreen()));
                      },
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showShareSheet(BuildContext ctx, {
    required String dayTitle,
    required int    exCount,
    required int    setCount,
    required double volumeKg,
    required int    duration,
    required int    recovery,
    required int    streak,
  }) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WorkoutShareSheet(
        dayTitle: dayTitle,
        exCount:  exCount,
        setCount: setCount,
        volumeKg: volumeKg,
        duration: duration,
        recovery: recovery,
        streak:   streak,
      ),
    );
  }

  void _streakDialog(BuildContext ctx, int streak) {
    H.success();
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: AppCurves.primary,
        builder: (_, v, child) =>
            Transform.scale(scale: v, child: child),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.bgModal,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.gold, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text('Streak Extended', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Text('$streak ${streak == 1 ? "day" : "days"} strong',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 10),
            Text('You\'re building an unbreakable habit.',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    ));
    Future.delayed(const Duration(seconds: 2), () {
      if (ctx.mounted && Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Select only isPendingReview for this day — avoids rebuilding on
    // unrelated AppProvider changes like set toggles in other exercises.
    final isPending = context.select<AppProvider, bool>((ap) =>
        ap.weekPlan.length > widget.idx
            ? ap.weekPlan[widget.idx].isPendingReview
            : false);

    if (isPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Pending review banner ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35), width: 0.9),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.gold, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'All exercises complete — review your session',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          // ── Glowing Complete button ─────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.40),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GoldButton(
              text: 'Complete Workout',
              icon: Icons.check_circle_rounded,
              width: double.infinity,
              onTap: () => _dialog(context),
            ),
          ),
        ],
      );
    }

    return GoldButton(
      text: 'Complete Workout',
      icon: Icons.check_circle_rounded,
      width: double.infinity,
      onTap: () => _dialog(context),
    );
  }
}

// ════════════════════════════════════════════════
// EXERCISE CARD — premium redesign
// ════════════════════════════════════════════════
class _ExCard extends StatefulWidget {
  final PlannedExercise ex;
  final int idx, entryDelay;
  final Color color;
  const _ExCard({required this.ex, required this.idx,
      required this.color, this.entryDelay = 0});
  @override State<_ExCard> createState() => _ExCardState();
}

class _ExCardState extends State<_ExCard>
    with SingleTickerProviderStateMixin {
  bool    _open       = false;
  String? _gifUrl;
  bool    _gifLoading = false;

  late AnimationController _entryC;
  late Animation<double>   _entryF;
  late Animation<Offset>   _entryS;

  @override
  void initState() {
    super.initState();
    _entryC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 360));
    _entryF = CurvedAnimation(parent: _entryC, curve: AppCurves.primary);
    _entryS = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryC, curve: AppCurves.primary));
    Future.delayed(Duration(milliseconds: widget.entryDelay),
            () { if (mounted) _entryC.forward(); });
  }

  Future<void> _loadGif() async {
    if (_gifUrl != null || _gifLoading) return;
    debugPrint('[GIF] loading for: ${widget.ex.name}');
    setState(() => _gifLoading = true);
    final url = await WgerService.instance.getGifUrl(widget.ex.name);
    debugPrint('[GIF] result: $url');
    if (mounted) setState(() { _gifUrl = url; _gifLoading = false; });
  }

  @override void dispose() { _entryC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ex      = widget.ex;
    final p       = context.read<AppProvider>();
    final key     = p.getKey(ex.baseId);
    final pr      = p.getPR(key, ex.unit);
    final prR     = p.getPRReps(key);
    final trend   = p.getExerciseTrend(ex.baseId);
    // Smart AI feedback (unified — same logic as PR screen via calculateWorkoutFeedback)
    final feedback = p.computeFeedback(ex);
    final msg = _buildHeaderMessage(feedback, p.getTrainerMessage(ex), ex);
    // Exercise intelligence classification — drives movement pattern chip + axial badge
    final exProfile = ExerciseIntelligenceService.classify(ex.name);
    final showPatternChip = exProfile.axialLoading &&
        exProfile.confidence >= 0.50;

    // Completed sets count
    final doneSets = ex.sets.where((s) => s.done).length;
    final totalSets = ex.sets.length;

    return FadeTransition(
      opacity: _entryF,
      child: SlideTransition(
        position: _entryS,
        child: Dismissible(
          key: Key(ex.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirm(context, ex.name),
          onDismissed: (_) {
            H.medium();
            p.removeExercise(widget.idx, ex.id);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_rounded,
                  color: AppColors.red, size: 24),
              Text('Remove', style: GoogleFonts.inter(
                  color: AppColors.red, fontSize: 9.5,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: AppCurves.primary,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _open
                    ? AppColors.goldAmber.withValues(alpha: 0.30)
                    : AppColors.divider.withValues(alpha: 0.25),
                width: _open ? 0.8 : 0.4,
              ),
            ),
            child: Stack(children: [
              Column(children: [


              // ── CARD HEADER ───────────────────
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: ex.category.toLowerCase() == 'rest' ? null : () {
                  H.selection();
                  final wasOpen = _open;
                  setState(() => _open = !_open);
                  if (!wasOpen) _loadGif(); // opening → load GIF
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                  child: Row(children: [
                    // SVG icon → GIF when expanded
                    Stack(clipBehavior: Clip.none, children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: (_open && _gifUrl != null)
                          ? ClipRRect(
                              key: const ValueKey('gif'),
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                _gifUrl!,
                                width: 46, height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ExerciseIconBox(
                                  muscle: ex.category,
                                  color: widget.color,
                                  boxSize: 46, iconSize: 22,
                                  fallbackEmoji: ex.emoji,
                                ),
                              ),
                            )
                          : (_open && _gifLoading)
                              ? Container(
                                  key: const ValueKey('loading'),
                                  width: 46, height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: widget.color.withValues(alpha: 0.25)),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: widget.color.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                )
                              : ExerciseIconBox(
                                  key: const ValueKey('icon'),
                                  muscle: ex.category,
                                  color: (doneSets == totalSets && totalSets > 0)
                                      ? widget.color.withValues(alpha: 0.40)
                                      : widget.color,
                                  boxSize: 46, iconSize: 22,
                                  fallbackEmoji: ex.emoji,
                                ),
                      ),
                      if (doneSets == totalSets && totalSets > 0)
                        Positioned(
                          bottom: -2, right: -2,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.bgCard, width: 1.2),
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 8),
                          ),
                        ),
                    ]),
                    const SizedBox(width: AppSpacing.md),

                    // Name + info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        ex.name,
                        style: GoogleFonts.rajdhani(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: (doneSets == totalSets && totalSets > 0)
                                ? AppColors.textPrimary.withValues(alpha: 0.45)
                                : AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (ex.category.isNotEmpty) Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.goldAmber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            ex.category,
                            style: GoogleFonts.inter(
                                color: (doneSets == totalSets && totalSets > 0)
                                    ? AppColors.goldAmber.withValues(alpha: 0.35)
                                    : AppColors.goldAmber.withValues(alpha: 0.65),
                                fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                        if (trend.isNotEmpty && !(doneSets == totalSets && totalSets > 0)) ...[
                          const SizedBox(width: 5),
                          _TrendBadge(trend: trend),
                        ],
                        if (showPatternChip) ...[
                          const SizedBox(width: 5),
                          _ExIntelChip(
                            label: exProfile.movementPattern.label,
                            isAxial: exProfile.axialLoading,
                          ),
                        ],
                        if (GhostCopyService.showTag(ex.ghostWeekGap) &&
                            !(doneSets == totalSets && totalSets > 0)) ...[
                          const SizedBox(width: 5),
                          _GhostTag(weekGap: ex.ghostWeekGap),
                        ],
                      ]),
                      if (msg.isNotEmpty && !(doneSets == totalSets && totalSets > 0)) ...[
                        const SizedBox(height: 3),
                        Text(
                          msg,
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary.withValues(alpha: 0.70),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ])),

                    const SizedBox(width: AppSpacing.xs),

                    // Right side: PR + sets progress + chevron
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      if (pr > 0) Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.orange.withValues(
                                  alpha: 0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.orange, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            ex.unit == 'min'
                                ? '${pr.toInt()}m'
                                : ex.bodyweight
                                    ? '${prR}r'
                                    : prR > 0
                                        ? '${pr.toStringAsFixed(1)}×$prR'
                                        : pr.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                                color: AppColors.orange, fontSize: 9.5,
                                fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      // Sets done indicator
                      Text('$doneSets/$totalSets sets',
                          style: GoogleFonts.inter(
                            color: doneSets == totalSets
                                ? AppColors.textMuted.withValues(alpha: 0.50)
                                : AppColors.textMuted,
                            fontSize: 11, fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Icon(
                        _open ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textMuted, size: 16),
                    ]),
                  ]),
                ),
              ),

              // ── EXPANDED SECTION ──────────────
              if (_open) ...[
                Divider(color: widget.color.withValues(alpha: 0.15),
                    height: 1, indent: AppSpacing.md,
                    endIndent: AppSpacing.md),
                const SizedBox(height: AppSpacing.sm),

                // ── ▶️ Demo Video Button ──
                ExerciseDemoButton(exerciseName: ex.name),

                // ── AI weight suggestion ──
                _AISuggestionBanner(ex: ex, color: widget.color),

                SizedBox(height: 115, child: ProgressChart(
                    exerciseKey: key, unit: ex.unit)),
                _SetsPanel(ex: ex, idx: widget.idx,
                    color: widget.color),
              ],
              ]),
              if (_open) Positioned(
                left: 0, top: 0, bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16)),
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.goldAmber,
                          AppColors.goldAmber.withValues(alpha: 0.20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext ctx, String name) async =>
      await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Remove Exercise?', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w700)),
        content: Text('Remove "$name" from today\'s plan?',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep it', style: GoogleFonts.inter(
                  color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      )) ?? false;
}

// ════════════════════════════════════════════════
// TREND BADGE — per-exercise strength trend chip
// ════════════════════════════════════════════════
class _TrendBadge extends StatelessWidget {
  final String trend; // 'improving' | 'plateau' | 'declining'
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (trend) {
      'improving' => (Icons.trending_up_rounded,   'Rising',  const Color(0xFF4CAF50)),
      'declining' => (Icons.trending_down_rounded, 'Dipping', const Color(0xFFEF5350)),
      _           => (Icons.trending_flat_rounded, 'Plateau', const Color(0xFFFF9800)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 9),
        const SizedBox(width: 2),
        Text(label, style: GoogleFonts.inter(
          color: color, fontSize: 8, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// EXERCISE INTELLIGENCE CHIP — movement pattern tag
// ════════════════════════════════════════════════
class _ExIntelChip extends StatelessWidget {
  final String label;
  final bool   isAxial;
  const _ExIntelChip({required this.label, required this.isAxial});

  @override
  Widget build(BuildContext context) {
    final col = isAxial
        ? AppColors.orange.withValues(alpha: 0.80)
        : AppColors.textMuted.withValues(alpha: 0.60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: col.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isAxial) ...[
          Icon(Icons.warning_amber_rounded, size: 8, color: col),
          const SizedBox(width: 2),
        ],
        Text(label,
          style: GoogleFonts.inter(
            color: col, fontSize: 8, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// AI SUGGESTION BANNER — shows concrete next weight/reps
// ════════════════════════════════════════════════
class _AISuggestionBanner extends StatelessWidget {
  final PlannedExercise ex;
  final Color color;

  const _AISuggestionBanner({required this.ex, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final hint = p.smartProgression(ex);
    final isBW = ex.bodyweight;
    final isMin = ex.unit == 'min';

    // Build clear next-target message
    String targetText;
    if (isMin) {
      targetText = '${hint.targetReps} min — controlled pace';
    } else if (isBW) {
      targetText = '${hint.targetReps} reps — focus on form';
    } else {
      final wStr = hint.nextWeight == hint.nextWeight.roundToDouble()
          ? hint.nextWeight.toStringAsFixed(0)
          : hint.nextWeight.toStringAsFixed(1);
      targetText = '${wStr}kg × ${hint.targetReps} reps';
    }

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.10),
            AppColors.gold.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.hub_rounded, color: AppColors.gold, size: 16),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetText,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint.message,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// SETS PANEL
// ════════════════════════════════════════════════
class _SetsPanel extends StatelessWidget {
  final PlannedExercise ex; final int idx; final Color color;
  const _SetsPanel({required this.ex, required this.idx,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final isC  = ex.unit == 'min';
    final isBW = ex.bodyweight;

    return Column(children: [
      // Column headers
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 1, AppSpacing.lg, 2),
        child: Row(children: [
          SizedBox(width: 28, child: Text('SET',
              style: GoogleFonts.inter(color: AppColors.textMuted,
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.3))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(isC ? 'MIN' : isBW ? 'REPS' : 'KG',
              style: GoogleFonts.inter(color: AppColors.textMuted,
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.3))),
          const SizedBox(width: AppSpacing.sm),
          if (!isC && !isBW)
            Expanded(child: Text('REPS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textMuted,
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)))
          else const Spacer(),
          const SizedBox(width: 52),
        ]),
      ),

      // Set rows
      ...ex.sets.asMap().entries.map((e) => _SetRow(
          ex: ex, set: e.value, num: e.key + 1,
          idx: idx, color: color)),

      // Add set button
      TextButton.icon(
        onPressed: () {
          H.light();
          p.addSet(idx, ex.id);
        },
        icon: Icon(Icons.add_rounded, size: 14, color: color),
        label: Text('Add Set', style: GoogleFonts.rajdhani(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
      const SizedBox(height: AppSpacing.xs),
    ]);
  }
}

// ════════════════════════════════════════════════
// SET ROW — premium redesign
// ════════════════════════════════════════════════
class _SetRow extends StatelessWidget {
  final PlannedExercise ex; final ExSet set;
  final int num, idx; final Color color;
  const _SetRow({required this.ex, required this.set,
      required this.num, required this.idx, required this.color});

  @override
  Widget build(BuildContext context) {
    final p    = context.read<AppProvider>();
    final isC  = ex.unit == 'min';
    final isBW = ex.bodyweight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: set.done
            ? const Color(0xFF131313)
            : const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: Row(children: [
        // Set number circle
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: set.done
                ? AppColors.gold.withValues(alpha: 0.08)
                : AppColors.bgElevated,
            border: Border.all(
              color: set.done
                  ? AppColors.gold.withValues(alpha: 0.18)
                  : AppColors.borderMedium,
              width: 0.7,
            ),
          ),
          child: Center(child: Text('$num',
              style: GoogleFonts.rajdhani(
                color: set.done
                    ? AppColors.gold.withValues(alpha: 0.70)
                    : AppColors.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Input fields
        Expanded(child: isC
            ? _Num(value: set.weight, done: set.done, color: color,
                hint: '10', isInt: true,
                onSave: (v) => p.updateSet(idx, ex.id, set.id, weight: v))
            : isBW
                ? _Num(value: set.reps.toDouble(), done: set.done,
                    color: color, isInt: true, hint: '10',
                    onSave: (v) => p.updateSet(
                        idx, ex.id, set.id, reps: v.toInt()))
                : _Num(value: set.weight, done: set.done, color: color,
                    hint: '20.0',
                    onSave: (v) => p.updateSet(
                        idx, ex.id, set.id, weight: v))),
        const SizedBox(width: AppSpacing.sm),
        if (!isC && !isBW)
          Expanded(child: _Num(
              value: set.reps.toDouble(), done: set.done, color: color,
              isInt: true, hint: '10',
              onSave: (v) => p.updateSet(
                  idx, ex.id, set.id, reps: v.toInt())))
        else const Spacer(),
        const SizedBox(width: AppSpacing.sm),

        // Done check button
        GestureDetector(
          onTapDown: (_) => set.done ? H.light() : H.medium(),
          onTap: () async {
            final wasDone = set.done;
            if (wasDone) {
              p.toggleSetDone(idx, ex.id, set.id);
              return;
            }

            final key = p.getKey(ex.baseId);

            // ✅ FIXED: get prev values from checkPRResult instead of two separate calls
            // checkPRResult reads the same data but in one atomic operation
            final prevBestWeight = p.getPR(key, ex.unit);
            final prevBestReps   = p.getPRReps(key);

            // ✅ FIXED: safety guard for invalid sets
            if (set.weight < 0 || set.reps <= 0) {
              p.toggleSetDone(idx, ex.id, set.id);
              return;
            }

            // ✅ FIXED: use checkPRResult() — proper weight/reps/first PR logic
            // ── GATE: Block future unplanned days; allow completed session backfill ──
            final isCompletedEdit = idx < p.weekPlan.length && p.weekPlan[idx].isCompleted;
            if (!isCompletedEdit && idx != p.todayIndex) {
              H.medium();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Only today\'s workout can be logged'),
                backgroundColor: AppColors.bgCard,
                duration: const Duration(seconds: 2),
              ));
              return;
            }

            // Completed session backfill: silent update — no XP, no PR celebration.
            if (isCompletedEdit) {
              p.toggleSetDone(idx, ex.id, set.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(children: [
                    Icon(Icons.edit_rounded, color: AppColors.gold, size: 14),
                    SizedBox(width: 8),
                    Text('Session updated',
                        style: TextStyle(fontFamily: 'Inter',
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                  backgroundColor: const Color(0xFF111100),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.25), width: 0.8)),
                  duration: const Duration(seconds: 1),
                ));
              }
              return;
            }

            // Old code used volume (weight×reps) which is WRONG:
            //   50kg×5=250 wouldn't beat 40kg×7=280 even though heavier
            final prResult   = p.checkPRResult(key, set.weight, set.reps, ex.unit);
            final isPR       = prResult.isPR;
            final isFirst    = prResult.isFirst;
            final improvePct = prResult.improvePct.clamp(0.0, 999.0);

            // ── Toggle (log the set) ──────────────────────────────────
            p.toggleSetDone(idx, ex.id, set.id);

            // ── Session milestone check ────────────────────────────────
            final milestone = WorkoutSessionService.instance.consumeMilestone();
            if (milestone != null && context.mounted) {
              H.success();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Text(milestone,
                      style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                backgroundColor: const Color(0xFF141200),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 0.8)),
                duration: const Duration(seconds: 3),
              ));
            }

            // ── XP — tiered by improvement magnitude ──────────────────
            final dynXP = isPR
                ? (improvePct >= 30 ? 500
                   : improvePct >= 15 ? 250
                   : isFirst ? 150 : 100)
                : 50;

            try {
              final gp = Provider.of<GamificationProvider>(
                  context, listen: false);
              gp.addXP(XPSystem.xpSetCompleted);
              if (isPR) { gp.addXP(dynXP); H.heavy(); }
            } catch (_) {}

            if (!context.mounted) return;

            // ✅ FIXED: use prResult.isMatch instead of manual comparison
            if (prResult.isMatch) { showMatchedPR(context, ex.name); return; }

            // ── PR Celebration ────────────────────────────────────────
            if (isPR) {
              await SafeAudio.playSuccess();
              if (context.mounted) {
                // Get first-ever weight for journey display
                final allLogs = p.getLogsForExercise(key);
                final firstW  = allLogs.isNotEmpty
                    ? allLogs.map((l) => l.weight)
                        .where((w) => w > 0)
                        .fold(9999.0, (a, b) => b < a ? b : a)
                    : 0.0;

                await showPRCelebration(context,
                  exerciseName:   ex.name,
                  weight:         set.weight,
                  reps:           set.reps,
                  xpEarned:       dynXP,
                  unit:           ex.unit,
                  prevWeight:     prResult.prevWeight,
                  prevReps:       prResult.prevReps,
                  sessionCount:   p.logs.length,
                  improvePct:     improvePct,
                  firstWeight:    firstW == 9999.0 ? 0 : firstW,
                  sessionPRCount: 1,
                );
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: set.done ? const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF388E3C)]) : null,
              color: set.done ? null : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: set.done
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.borderMedium,
                width: 0.8,
              ),
            ),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('done_${set.id}_${set.done}'),
              tween: Tween(begin: set.done ? 0.0 : 1.0, end: 1.0),
              duration: Duration(milliseconds: set.done ? 320 : 120),
              curve: set.done
                  ? AppCurves.emphasis
                  : AppCurves.primary,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child!),
              child: Icon(
                set.done ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: set.done ? Colors.white : AppColors.textMuted,
                size: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            H.light();
            p.removeSet(idx, ex.id, set.id);
          },
          child: const Icon(Icons.close_rounded,
              color: AppColors.textMuted, size: 15),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// NUMBER INPUT FIELD — comma→dot fix + focus glow
// ════════════════════════════════════════════════
class _Num extends StatefulWidget {
  final double value; final bool done, isInt;
  final Color color; final String hint;
  final ValueChanged<double> onSave;
  const _Num({required this.value, required this.done,
      required this.color, required this.hint,
      this.isInt = false, required this.onSave});
  @override State<_Num> createState() => _NumState();
}

class _NumState extends State<_Num> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _Num old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  String _fmt(double v) => widget.isInt
      ? v.toInt().toString() : v.toStringAsFixed(1);

  void _save(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || v < 0) return;
    if (v > AppLimits.maxWeight) return;
    widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.done
        ? AppColors.divider.withValues(alpha: 0.35)
        : _focused ? widget.color.withValues(alpha: 0.65) : AppColors.divider.withValues(alpha: 0.35);
    final fillColor = widget.done
        ? const Color(0xFF0F0F0F)
        : const Color(0xFF0D0D0D);

    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: AppCurves.primary,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: _focused ? 1.4 : 0.8),
      ),
      child: TextField(
        controller: _ctrl, focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(
            decimal: !widget.isInt, signed: false),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(widget.isInt ? r'[0-9]' : r'[0-9.,]')),
        ],
        style: GoogleFonts.rajdhani(
            color: widget.done
                ? AppColors.textPrimary.withValues(alpha: 0.60)
                : AppColors.textPrimary,
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        decoration: InputDecoration(
          isDense: true, filled: false,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 5),
          hintText: widget.hint,
          hintStyle: GoogleFonts.rajdhani(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: _save, onSubmitted: _save,
      ),
    );
  }
}

// ════════════════════════════════════════════════
// TAP FEEDBACK
// ════════════════════════════════════════════════
class _Tap extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const _Tap({required this.child, required this.onTap});
  @override State<_Tap> createState() => _TapState();
}
class _TapState extends State<_Tap> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: AppDurations.instant,
      reverseDuration: AppDurations.normal,
    );

    _s = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: AppCurves.exit,
        reverseCurve: AppCurves.primary,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          H.selection();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: ScaleTransition(
          scale: _s,
          child: widget.child,
        ),
      );
}

// ════════════════════════════════════════════════
// EXERCISE PICKER
// ════════════════════════════════════════════════
void _showPicker(BuildContext context, int dayIdx) =>
    showExercisePicker(context, dayIdx);

void showExercisePicker(
  BuildContext context,
  int dayIdx, {
  String? initialCategory,
}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickerSheet(dayIdx: dayIdx, initialCategory: initialCategory),
  );
}

class _PickerSheet extends StatefulWidget {
  final int dayIdx;
  final String? initialCategory;
  const _PickerSheet({required this.dayIdx, this.initialCategory});
  @override State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _search = '';
  String _cat = 'All';
  final Set<String> _sel = {};
  Timer? _debounce;

  // Advanced filters
  final Set<String> _diffFilter  = {};
  final Set<String> _equipFilter = {};
  bool _showFilters = false;

  // Recently used
  List<String> _recentlyUsed = [];

  // Search focus glow (Upgrade #6)
  final FocusNode _searchFocus = FocusNode();
  bool _isFocused = false;

  // Expanded "Why this?" badge explanations keyed by exercise key (Upgrade #8)
  final Set<String> _expandedExplain = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) _cat = widget.initialCategory!;
    _loadRecent();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _isFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('recently_used_exercises') ?? [];
    if (mounted) setState(() => _recentlyUsed = keys);
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recently_used_exercises', _recentlyUsed);
  }

  bool get _hasActiveFilters => _diffFilter.isNotEmpty || _equipFilter.isNotEmpty;
  static const _filters = [
    'All','Favorites','Chest','Back','Legs','Calves',
    'Shoulders','Biceps','Triceps','Core','Cardio'];

  List<Map<String, dynamic>> get _all {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    final custom =
        context.read<AppProvider>().workout.customExercises;

    final combined = [
      ...ExerciseData.list,
      ...custom,
    ];

    for (final ex in combined) {
      if (seen.add('${ex["name"]}_${ex["type"]}')) {
        out.add(ex);
      }
    }

    return out;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

  List<Map<String, dynamic>> get _filtered {
    final q = _normalize(_search.trim());
    final favs = context.read<FavoritesProvider>().favoriteIds;
    final isFavFilter = _cat == 'Favorites';

    var result = _all.where((ex) {
      final name      = _normalize((ex['name']      as String? ?? ''));
      final type      = _normalize((ex['type']      as String? ?? ''));
      final muscle    = _normalize((ex['muscle']    as String? ?? ''));
      final id        = (ex['id'] as String? ?? '');
      final equipment = (ex['equipment'] as String? ?? '').toLowerCase();

      final matchSearch = q.isEmpty
          || name.contains(q) || type.contains(q) || muscle.contains(q);
      final matchCat = _cat == 'All' || isFavFilter
          || muscle == _normalize(_cat);
      final matchFav = !isFavFilter || favs.contains(id);

      // Advanced filters
      if (_diffFilter.isNotEmpty) {
        final diff = ExerciseDifficultyHelper.getDifficulty(ex);
        final label = diff == ExerciseDifficulty.intermediate
            ? 'Mid' : ExerciseDifficultyHelper.label(diff);
        if (!_diffFilter.contains(label)) return false;
      }
      if (_equipFilter.isNotEmpty &&
          !_equipFilter.any((f) => f.toLowerCase() == equipment)) {
        return false;
      }

      return matchSearch && matchCat && matchFav;
    }).toList();

    // Smart sort when searching: startsWith scores higher than contains
    if (q.isNotEmpty) {
      result.sort((a, b) {
        final an = _normalize(a['name'] as String? ?? '');
        final bn = _normalize(b['name'] as String? ?? '');
        final aS = an.startsWith(q) ? 0 : 1;
        final bS = bn.startsWith(q) ? 0 : 1;
        return aS.compareTo(bS);
      });
    }

    return result;
  }

  /// Group exercises by muscle when search is empty + category is 'All'
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final ex in _filtered) {
      final m = (ex['muscle'] as String? ?? 'Other');
      groups.putIfAbsent(m, () => []).add(ex);
    }
    return groups;
  }

  bool get _showGrouped => _search.trim().isEmpty && _cat == 'All';

  @override
  Widget build(BuildContext context) {
    // read instead of watch — exercise ranking uses a snapshot of recovery/
    // volume/favorites computed at sheet-open time. No live updates needed.
    final p    = context.read<AppProvider>();
    final list = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: AppSpacing.sm),
        Center(child: Container(width: 44, height: 4,
            decoration: BoxDecoration(color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(AppRadii.pill)))),
        const SizedBox(height: AppSpacing.lg),

        // Header
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl),
          child: Row(children: [
            Text('Add Exercises', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 22,
                fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),

        // Search + custom
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl),
          child: Column(children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: AppCurves.primary,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isFocused
                    ? [BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        blurRadius: 14, spreadRadius: 0)]
                    : [],
              ),
              child: TextField(
                focusNode: _searchFocus,
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search exercises…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true, fillColor: AppColors.bgCardLight,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.0)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250),
                      () => setState(() => _search = v));
                },
              ),
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCustom(context, widget.dayIdx),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Custom'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold),
              )),
            // Category chips + filter toggle
            SizedBox(height: 36, child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._filters.map((t) {
                  final sel = _cat == t;
                  return GestureDetector(
                    onTap: () { H.selection(); setState(() => _cat = t); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.gold : AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? AppColors.gold : AppColors.divider)),
                      child: Text(t, style: GoogleFonts.inter(
                        color: sel ? Colors.black : AppColors.textMuted,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  );
                }),
                // Filters toggle
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () { H.selection(); setState(() => _showFilters = !_showFilters); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? AppColors.gold.withValues(alpha: 0.15)
                          : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _hasActiveFilters
                            ? AppColors.gold.withValues(alpha: 0.45)
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.tune_rounded, size: 13,
                          color: _hasActiveFilters ? AppColors.gold : AppColors.textMuted),
                      if (_hasActiveFilters) ...[
                        const SizedBox(width: 4),
                        Container(width: 5, height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.gold, shape: BoxShape.circle)),
                      ],
                    ]),
                  ),
                ),
              ],
            )),
            // Expanded filter rows (animated)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: AppCurves.primary,
              child: _showFilters ? _buildExpandedFilters() : const SizedBox.shrink(),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Recently used section (above list, only when not searching)
        if (_showGrouped && _recentlyUsed.isNotEmpty)
          _buildRecentlyUsedSection(p),

        // Smart coach insight chips (Upgrade #9)
        if (_showGrouped)
          _buildInsightChips(p),

        // List
        Expanded(child: list.isEmpty
            ? _ExerciseEmptyState(query: _search.trim(), category: _cat)
            : _showGrouped
            ? _buildGroupedList(p)
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.lg),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _buildExerciseTile(list[i], p),
              )),

        // Add selected button
        if (_sel.isNotEmpty) Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border(top: BorderSide(color: AppColors.divider))),
          child: GoldButton(
            text: 'Add ${_sel.length} Exercise'
                '${_sel.length > 1 ? "s" : ""}',
            icon: Icons.add_rounded,
            width: double.infinity,
            onTap: () { H.medium(); _add(context); },
          ),
        ),
      ]),
    );
  }

  void _add(BuildContext context) {
    final p = context.read<AppProvider>();
    for (final key in _sel) {
      final ex = _all.firstWhere(
        (e) => '${e["name"]}_${e["type"]}' == key,
        orElse: () => <String, dynamic>{},
      );
      if (ex.isEmpty) continue;
      p.addExercise(widget.dayIdx,
        name:         ex['name']       as String? ?? '',
        category:     ex['muscle']     as String? ?? '',
        emoji:        ex['emoji']      as String? ?? '💪',
        type:         ex['type']       as String? ?? '',
        unit:         ex['unit']       as String?
            ?? (ex['bodyweight'] == true ? 'reps' : 'kg'),
        baseId:       ex['id'] as String?
            ?? '${ex["name"]}_${ex["type"] ?? ""}',
        isBodyweight: ex['bodyweight'] as bool? ?? false,
      );
    }
    // Update recently used — prepend selected keys, keep last 8 unique
    final updatedRecent = [
      ..._sel,
      ..._recentlyUsed.where((k) => !_sel.contains(k)),
    ].take(8).toList();
    _recentlyUsed = updatedRecent;
    _saveRecent();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_sel.length} exercise'
          '${_sel.length > 1 ? "s" : ""} added',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Grouped list — shows exercises organized by muscle group
  Widget _buildGroupedList(AppProvider p) {
    final groups = _grouped;
    final orderedKeys = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio']
        .where((k) => groups.containsKey(k))
        .toList();
    // Add any unknown muscles at the end
    for (final k in groups.keys) {
      if (!orderedKeys.contains(k)) orderedKeys.add(k);
    }
    final volMap = p.weeklyVolumeByMuscle;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.lg),
      itemCount: orderedKeys.length,
      itemBuilder: (ctx, gi) {
        final muscle = orderedKeys[gi];
        final col = AppColors.categoryColors[muscle] ?? AppColors.gold;
        final muscleVol = volMap[muscle.toLowerCase()] ?? 0.0;
        final fatigueColor = muscleVol > 15000
            ? AppColors.red
            : muscleVol > 5000
                ? const Color(0xFFFF9F0A)
                : null;
        // Intelligent AI ranking — recovery + history + favorites
        final recovery = p.getMuscleRecovery(muscle);

        final recent = p.lastWorkouts
            .map((e) => e.toLowerCase())
            .toList();

        final items = (groups[muscle] ?? []).toList()
          ..sort((a, b) {

            int score(Map<String, dynamic> ex) {
              final key = '${ex['name']}_${ex['type']}';

              final movement =
                  (ex['movement'] as String? ?? '').toLowerCase();

              final equipment =
                  (ex['equipment'] as String? ?? '').toLowerCase();

              var s = 0;

              // Favorites priority
              if (p.favorites.contains(key)) s += 40;

              // Recovery-aware ranking
              if (recovery >= 80) {
                if (movement == 'compound') s += 30;
                if (equipment == 'barbell') s += 18;
              } else if (recovery >= 55) {
                if (equipment == 'machine') s += 18;
                if (equipment == 'cable') s += 16;
                if (movement == 'isolation') s += 12;
              } else {
                if (equipment == 'cable') s += 24;
                if (equipment == 'machine') s += 20;
                if (movement == 'isolation') s += 18;
                if (equipment == 'barbell') s -= 26;
              }

              // Avoid repeating same pattern
              final lower = key.toLowerCase();

              final repeated =
                  recent.any((r) => lower.contains(r));

              if (repeated) s -= 14;

              return s;
            }

            final diff =
                score(b).compareTo(score(a));

            if (diff != 0) return diff;

            return (a['name'] as String)
                .compareTo(b['name'] as String);
          });

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 200 + gi * 50),
          curve: AppCurves.primary,
          builder: (_, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)), child: child),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header — Upgrade #4
            Padding(
              padding: EdgeInsets.only(
                top: gi == 0 ? 4 : AppSpacing.lg,
                bottom: 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 3, height: 16,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExerciseIconMapper.icon(muscle,
                        size: 14, color: col, fallbackEmoji: '💪'),
                    const SizedBox(width: 6),
                    Text(
                      muscle.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        color: col,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${items.length}',
                        style: GoogleFonts.inter(
                          color: col,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (fatigueColor != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: fatigueColor, shape: BoxShape.circle),
                      ),
                    ],
                    const Spacer(),
                    if (fatigueColor != null)
                      Text(
                        fatigueColor == AppColors.red ? 'High fatigue' : 'Moderate fatigue',
                        style: GoogleFonts.inter(
                          color: fatigueColor.withValues(alpha: 0.7),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  // Glow divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          col.withValues(alpha: 0.3),
                          col.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  if (recovery < 55) ...[
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22FF453A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.16),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.red.withValues(alpha: 0.90),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              '$muscle still recovering · avoid heavy compounds today',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Exercise tiles — badges pre-computed per section for cap + adjacency rules
            ...() {
              final dayTitle = p.weekPlan.length > widget.dayIdx
                  ? p.weekPlan[widget.dayIdx].title : '';
              final badges = ExerciseAIBadgeHelper.assignGroupBadges(
                  items, goal: p.goal, level: p.level, dayTitle: dayTitle);
              final featuredIdx = badges.indexWhere((b) => b != null);
              return List.generate(items.length, (i) =>
                  _buildExerciseTile(items[i], p,
                      precomputedBadge: badges[i],
                      usePrecomputedBadge: true,
                      isFeatured: i == featuredIdx));
            }(),
          ],
        ),
        );
      },
    );
  }

  /// Format stat value for "Last" / "Best" display
  String _formatStat(double weight, int reps, String unit) {
    if (unit == 'reps') return '${reps}r';
    if (unit == 'min') return '${weight.toInt()}min';
    if (weight > 0 && reps > 0) return '${weight.toStringAsFixed(1)}kg×$reps';
    if (weight > 0) return '${weight.toStringAsFixed(1)}kg';
    return '${reps}r';
  }

  /// Quick-add a single exercise without closing the sheet
  void _quickAdd(BuildContext ctx, Map<String, dynamic> ex, AppProvider p) {
    final name = ex['name'] as String? ?? '';
    final type = ex['type'] as String? ?? '';
    final k    = '${name}_$type';
    p.addExercise(widget.dayIdx,
      name:         name,
      category:     ex['muscle']     as String? ?? '',
      emoji:        ex['emoji']      as String? ?? '💪',
      type:         type,
      unit:         ex['unit']       as String?
          ?? (ex['bodyweight'] == true ? 'reps' : 'kg'),
      baseId:       k,
      isBodyweight: ex['bodyweight'] as bool? ?? false,
    );
    setState(() {
      _recentlyUsed = [k, ..._recentlyUsed.where((r) => r != k)].take(8).toList();
    });
    _saveRecent();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('$name added',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  /// Reusable tile — all upgrades applied
  Widget _buildExerciseTile(Map<String, dynamic> ex, AppProvider p, {
    String? precomputedBadge,
    bool usePrecomputedBadge = false,
    bool isFeatured = false,
  }) {
    final name      = ex['name']      as String? ?? '';
    final type      = ex['type']      as String? ?? '';
    final cat       = ex['muscle']    as String? ?? 'General';
    final equipment = ex['equipment'] as String? ?? '';
    final movement  =
        (ex['movement'] as String? ?? '').toLowerCase();

    final emoji     = ex['emoji']     as String? ?? '💪';
    final unit      = ex['unit']      as String?
        ?? (ex['bodyweight'] == true ? 'reps' : 'kg');
    final col       = AppColors.categoryColors[cat] ?? AppColors.gold;
    final key       = '${name}_$type';
    final selected  = _sel.contains(key);
    final isFav     = p.favorites.contains(key);

    // Difficulty
    final diff       = ExerciseDifficultyHelper.getDifficulty(ex);
    final diffColor  = ExerciseDifficultyHelper.color(diff);
    final diffLabel  = ExerciseDifficultyHelper.label(diff);

    // Equipment
    final equipLabel = ExerciseEquipmentHelper.label(equipment);
    final equipIcon  = ExerciseEquipmentHelper.icon(equipment);

    // AI badge — use pre-computed group badge (cap + adjacency), else compute fresh
    final badge = usePrecomputedBadge
        ? precomputedBadge
        : ExerciseAIBadgeHelper.getBadge(ex,
            goal:     p.goal,
            level:    p.level,
            dayTitle: p.weekPlan.length > widget.dayIdx
                ? p.weekPlan[widget.dayIdx].title : '');

    // Personal stats
    final logKey    = p.getKey(key);
    final bestWt    = p.getPR(logKey, unit);
    final bestReps  = p.getPRReps(logKey);
    final lastLogs  = p.logs
        .where((l) => l.exercise == logKey)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final lastLog   = lastLogs.isNotEmpty ? lastLogs.first : null;


    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: Key('tile_$key'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          H.medium();
          _quickAdd(context, ex, p);
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_circle_rounded,
                color: AppColors.green, size: 18),
            const SizedBox(width: 4),
            Text('Add', style: GoogleFonts.inter(
                color: AppColors.green, fontSize: 11,
                fontWeight: FontWeight.w700)),
          ]),
        ),
        child: AnimatedScale(
          scale: selected ? 0.975 : 1.0,
          duration: AppDurations.normal,
          curve: AppCurves.primary,
          child: InkWell(
            onTap: () {
              H.selection();
              setState(() => selected ? _sel.remove(key) : _sel.add(key));
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showPreview(context, ex, widget.dayIdx);
            },
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2, vertical: 13),
                decoration: BoxDecoration(
                  color: ExerciseCategoryTheme.backgroundColor(
                      cat, selected: selected, accent: col),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFeatured && !selected
                        ? AppColors.gold.withValues(alpha: 0.5)
                        : ExerciseCategoryTheme.borderColor(
                            cat, selected: selected, accent: col),
                    width: isFeatured && !selected
                        ? 1.4
                        : (selected ? 1.1 : 0.7),
                  ),
                  boxShadow: isFeatured && !selected
                      ? [
                          BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.07),
                              blurRadius: 14,
                              spreadRadius: 0)
                        ]
                      : null,
                ),
                child: Row(children: [
                  ExerciseIconBox(
                    muscle: cat, color: col,
                    boxSize: 38, iconSize: 18,
                    fallbackEmoji: emoji,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 10),

                  // Name + chips + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name row + AI badge
                        Row(children: [
                          if (isFav) ...[
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 10),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(name,
                                style: GoogleFonts.rajdhani(
                                  color: selected ? col : AppColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                border: Border.all(
                                    color: AppColors.gold.withValues(
                                        alpha: 0.65),
                                    width: 1.0),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.gold.withValues(
                                          alpha: 0.12),
                                      blurRadius: 4),
                                ],
                              ),
                              child: Text(badge,
                                  style: GoogleFonts.inter(
                                    color: AppColors.gold,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 5),
                        // Equipment chip + type
                        Row(children: [
                          if (equipLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF2A2A2A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(equipIcon, size: 8,
                                      color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(equipLabel,
                                      style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ],
                              ),
                            ),
                          if (type.isNotEmpty && equipLabel.isNotEmpty)
                            const SizedBox(width: 4),
                          if (type.isNotEmpty)
                            Text(type,
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.6),
                                  fontSize: 8.5,
                                )),
                        ]),

                        const SizedBox(height: 5),

                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [

                            if (badge == 'AI Pick')
                              _miniInsightChip(
                                'IDEAL TODAY',
                                AppColors.green,
                              ),

                            if (badge == 'Recovery Friendly' ||
                                badge == 'Joint Friendly')
                              _miniInsightChip(
                                'LOW FATIGUE LOAD',
                                const Color(0xFF64B5F6),
                              ),

                            if (movement == 'compound')
                              _miniInsightChip(
                                'HIGH OUTPUT',
                                AppColors.gold,
                              ),

                            if (equipment == 'machine')
                              _miniInsightChip(
                                'STABLE FORM',
                                const Color(0xFFB388FF),
                              ),
                          ],
                        ),

                        // Personal stats row — ↺ Last  ⬆ PR
                        if (lastLog != null || bestWt > 0) ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            if (lastLog != null) ...[
                              Icon(Icons.history_rounded,
                                  size: 8,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 2),
                              Text(
                                _formatStat(lastLog.weight,
                                    lastLog.reps, unit),
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.6),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (lastLog != null && bestWt > 0)
                              const SizedBox(width: 8),
                            if (bestWt > 0) ...[
                              Icon(Icons.arrow_upward_rounded,
                                  size: 8,
                                  color: AppColors.gold
                                      .withValues(alpha: 0.75)),
                              const SizedBox(width: 2),
                              Text(
                                'PR  ${_formatStat(bestWt, bestReps, unit)}',
                                style: GoogleFonts.inter(
                                  color: AppColors.gold
                                      .withValues(alpha: 0.75),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ]),
                        ],
                        // "Why this?" expandable AI explanation (Upgrade #3)
                        if (badge != null) ...[
                          const SizedBox(height: 2),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              H.light();
                              setState(() {
                                if (_expandedExplain.contains(key)) {
                                  _expandedExplain.remove(key);
                                } else {
                                  _expandedExplain.add(key);
                                }
                              });
                            },
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 8),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 240),
                                curve: AppCurves.primary,
                                alignment: Alignment.topLeft,
                                child: _expandedExplain.contains(key)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 0.5,
                                            margin: const EdgeInsets.only(
                                                bottom: 6),
                                            color: AppColors.goldSoft
                                                .withValues(alpha: 0.20),
                                          ),
                                          ..._whyBadge(ex, p, badge)
                                              .map((r) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 1),
                                                          child: Icon(
                                                            Icons.check_rounded,
                                                            size: 8,
                                                            color: AppColors
                                                                .goldSoft
                                                                .withValues(
                                                                    alpha: 0.55),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                            child: Text(r,
                                                                style: GoogleFonts
                                                                    .inter(
                                                                  color: AppColors
                                                                      .textMuted
                                                                      .withValues(
                                                                          alpha:
                                                                              0.72),
                                                                  fontSize: 7.5,
                                                                  height: 1.4,
                                                                ))),
                                                      ],
                                                    ),
                                                  )),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedRotation(
                                                turns: 0.5,
                                                duration: const Duration(
                                                    milliseconds: 220),
                                                curve: AppCurves.primary,
                                                child: Icon(
                                                    Icons.expand_more_rounded,
                                                    size: 9,
                                                    color: AppColors.goldSoft
                                                        .withValues(alpha: 0.35)),
                                              ),
                                              const SizedBox(width: 2),
                                              Text('less',
                                                  style: GoogleFonts.inter(
                                                    color: AppColors.goldSoft
                                                        .withValues(alpha: 0.35),
                                                    fontSize: 7,
                                                    fontStyle: FontStyle.italic,
                                                  )),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedRotation(
                                            turns: 0.0,
                                            duration: const Duration(
                                                milliseconds: 220),
                                            curve: AppCurves.primary,
                                            child: Icon(
                                                Icons.expand_more_rounded,
                                                size: 9,
                                                color: AppColors.goldSoft
                                                    .withValues(alpha: 0.45)),
                                          ),
                                          const SizedBox(width: 2),
                                          Text('Why this?',
                                              style: GoogleFonts.inter(
                                                color: AppColors.goldSoft
                                                    .withValues(alpha: 0.45),
                                                fontSize: 7.5,
                                                fontStyle: FontStyle.italic,
                                              )),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Difficulty badge — smaller + muted so AI badge gets visual priority
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: diffColor.withValues(alpha: 0.18),
                          width: 0.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.75),
                          shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        diff == ExerciseDifficulty.intermediate
                            ? 'Mid' : diffLabel,
                        style: GoogleFonts.inter(
                          color: diffColor.withValues(alpha: 0.75),
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 6),

                  if (selected)
                    Icon(Icons.check_circle_rounded, color: col, size: 20),
                ]),
              ),

              // TOP PICK corner badge for featured card (Upgrade #2)
              if (isFeatured && badge != null)
                Positioned(
                  top: 0, left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: Text('TOP PICK',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        )),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }



  Widget _miniInsightChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color.withValues(alpha: 0.92),
          fontSize: 6.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Deterministic "Why this?" reasons for an AI badge — no network, no AI.
  List<String> _whyBadge(Map<String, dynamic> ex, AppProvider p, String badge) {
    final muscle = (ex['muscle'] as String? ?? '').toLowerCase();
    final vol = p.weeklyVolumeByMuscle[muscle] ?? 0.0;
    final reasons = <String>[];
    if (badge == 'Best for Strength' || badge == 'Power Builder') {
      reasons.add('strength goal active');
      if (vol < 5000) reasons.add('$muscle volume low this week');
      reasons.add('barbell maximises mechanical load');
    } else if (badge == 'High ROI') {
      reasons.add('multi-joint = more muscle stimulus');
      if (vol < 8000) reasons.add('$muscle has capacity for more volume');
    } else if (badge == 'Volume Builder') {
      reasons.add('isolation targets growth directly');
      if (vol < 10000) reasons.add('$muscle has room to grow');
    } else if (badge == 'AI Pick') {
      reasons.add("matches today's split focus");
      if (vol < 5000) reasons.add('$muscle underworked this week');
    } else if (badge == 'Athletic Transfer') {
      reasons.add('builds functional strength patterns');
      reasons.add('compound carryover to daily movement');
    } else if (badge == 'Stable Movement') {
      reasons.add('machine guides full range safely');
      reasons.add('ideal for controlled volume');
    } else if (badge == 'Joint Friendly') {
      reasons.add('cable maintains constant tension');
      reasons.add('reduces joint stress vs free weights');
    } else if (badge == 'Recovery Friendly') {
      reasons.add('safe progression for your level');
      reasons.add('joint-friendly mechanics');
    } else if (badge == 'Fat Loss') {
      reasons.add('fat loss goal active');
      reasons.add('cardio drives direct calorie burn');
    } else {
      reasons.add('matches your current training context');
    }
    return reasons.take(3).toList();
  }

  /// Retention motivational line — deterministic, calm tone (Upgrade #10)
  /// Deterministic coach insight chips — returns (label, optional category to jump to).
  List<({String label, String? cat})> _computeInsights(AppProvider p) {
    final insights = <({String label, String? cat})>[];
    final volMap   = p.weeklyVolumeByMuscle;
    final streak   = p.streak.currentStreak;
    const muscles  = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
    const catNames = <String, String>{
      'chest': 'Chest', 'back': 'Back', 'legs': 'Legs',
      'shoulders': 'Shoulders', 'arms': 'Arms', 'core': 'Core',
    };

    for (final entry in volMap.entries) {
      if (entry.value > 10000) {
        final name = '${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
        insights.add((label: '$name volume high this week', cat: null));
      }
    }
    for (final m in muscles) {
      if ((volMap[m] ?? 0) < 500) {
        final cap = catNames[m]!;
        insights.add((label: '$cap undertrained — add it today', cat: cap));
      }
    }
    if (streak >= 7) insights.add((label: '$streak-day streak active', cat: null));
    if (volMap.isNotEmpty) {
      final top  = volMap.entries.reduce((a, b) => a.value > b.value ? a : b);
      final name = '${top.key[0].toUpperCase()}${top.key.substring(1)}';
      if (top.value > 3000) insights.add((label: '$name is your focus this week', cat: null));
    }
    return insights.take(5).toList();
  }

  /// Horizontal chip strip — tappable chips with muscle category filter (Upgrade #9)
  Widget _buildInsightChips(AppProvider p) {
    final insights = _computeInsights(p);
    if (insights.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 28,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          itemCount: insights.length,
          itemBuilder: (_, i) {
            final chip = insights[i];
            final actionable = chip.cat != null;
            return GestureDetector(
              onTap: actionable
                  ? () {
                      H.selection();
                      setState(() => _cat = chip.cat!);
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: actionable
                      ? AppColors.goldAmber.withValues(alpha: 0.07)
                      : AppColors.bgCardLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: actionable
                          ? AppColors.goldSoft.withValues(alpha: 0.28)
                          : AppColors.goldAmber.withValues(alpha: 0.16),
                      width: 0.7),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (actionable) ...[
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 7,
                        color: AppColors.goldSoft.withValues(alpha: 0.55)),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    chip.label,
                    style: GoogleFonts.inter(
                      color: actionable
                          ? AppColors.textSecondary.withValues(alpha: 0.85)
                          : AppColors.textMuted.withValues(alpha: 0.7),
                      fontSize: 9.5,
                      fontWeight: actionable ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Recently used horizontal pill section
  Widget _buildRecentlyUsedSection(AppProvider p) {
    final all = _all;
    final recentExercises = _recentlyUsed
        .map((k) => all.firstWhere(
              (e) => '${e["name"]}_${e["type"]}' == k,
              orElse: () => <String, dynamic>{},
            ))
        .where((e) => e.isNotEmpty)
        .toList();
    if (recentExercises.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, 6),
            child: Text('RECENTLY USED',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                )),
          ),
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl),
              itemCount: recentExercises.length,
              itemBuilder: (ctx, i) {
                final ex   = recentExercises[i];
                final n    = ex['name'] as String? ?? '';
                final cat  = ex['muscle'] as String? ?? 'General';
                final col  = AppColors.categoryColors[cat] ?? AppColors.gold;
                final em   = ex['emoji'] as String? ?? '💪';
                return GestureDetector(
                  onTap: () { H.medium(); _quickAdd(context, ex, p); },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: col.withValues(alpha: 0.18), width: 0.7),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ExerciseIconMapper.icon(cat,
                          size: 13, color: col, fallbackEmoji: em),
                      const SizedBox(width: 6),
                      Text(n,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1),
                      const SizedBox(width: 6),
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.add_rounded,
                              color: col, size: 10)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl),
            child: Divider(
                color: AppColors.divider.withValues(alpha: 0.4),
                height: 1),
          ),
        ],
      ),
    );
  }

  /// Collapsible difficulty + equipment filter rows
  Widget _buildExpandedFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text('DIFFICULTY',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Beginner', 'Mid', 'Advanced'].map((d) {
                final sel = _diffFilter.contains(d);
                final dc = d == 'Beginner'
                    ? const Color(0xFF30D158)
                    : d == 'Mid'
                        ? const Color(0xFFFF9F0A)
                        : const Color(0xFFFF6232);
                return GestureDetector(
                  onTap: () {
                    H.selection();
                    setState(() => sel
                        ? _diffFilter.remove(d)
                        : _diffFilter.add(d));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? dc.withValues(alpha: 0.14)
                          : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? dc.withValues(alpha: 0.5)
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(d,
                        style: GoogleFonts.inter(
                          color: sel ? dc : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text('EQUIPMENT',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Barbell', 'Dumbbell', 'Cable', 'Machine', 'Bodyweight']
                  .map((eq) {
                final sel = _equipFilter.contains(eq);
                return GestureDetector(
                  onTap: () {
                    H.selection();
                    setState(() => sel
                        ? _equipFilter.remove(eq)
                        : _equipFilter.add(eq));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.gold.withValues(alpha: 0.12)
                          : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AppColors.gold.withValues(alpha: 0.4)
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(ExerciseEquipmentHelper.icon(eq),
                          size: 10,
                          color: sel ? AppColors.gold : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(eq,
                          style: GoogleFonts.inter(
                            color: sel ? AppColors.gold : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context, Map<String, dynamic> ex, int dayIdx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePreviewSheet(ex: ex, dayIdx: dayIdx),
    );
  }
}

// ════════════════════════════════════════════════
// CUSTOM EXERCISE SHEET
// ════════════════════════════════════════════════
void _showCustom(BuildContext context, int dayIdx) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomSheet(dayIdx: dayIdx),
  );
}

// ── Premium empty state for exercise search (Upgrade #5) ─────────────────────
class _ExerciseEmptyState extends StatelessWidget {
  final String query;
  final String category;
  const _ExerciseEmptyState({required this.query, required this.category});

  static const _suggestions = ['chest', 'squat', 'curl', 'row', 'press', 'cardio'];

  @override
  Widget build(BuildContext context) {
    final isSearch = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExerciseIconMapper.icon(
              isSearch ? 'general' : category.toLowerCase(),
              size: 52,
              color: AppColors.textMuted.withValues(alpha: 0.35),
              fallbackEmoji: '🔍',
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No results for "$query"' : 'Nothing here yet',
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Try a different term or browse by category'
                  : 'Switch to All to explore every exercise',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearch) ...[
              const SizedBox(height: 20),
              Text('Quick search:',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _suggestions.map((s) {
                  return GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      child: Text(s,
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomSheet extends StatefulWidget {
  final int dayIdx;
  const _CustomSheet({required this.dayIdx});
  @override State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  final _name  = TextEditingController();
  final _emoji = TextEditingController(text: '💪');

  final List<String> _muscles = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Core',
    'Cardio',
  ];

  String _selectedMuscle = 'Chest';

  bool _bw = false;
  String? _err;

  @override void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Please enter a name'); return;
    }
    H.medium();
    context.read<AppProvider>().addCustomExercise(
      dayIndex:     widget.dayIdx,
      name:         _name.text.trim(),
      category:     _selectedMuscle,
      emoji:        _emoji.text.trim().isEmpty ? '💪' : _emoji.text.trim(),
      isBodyweight: _bw,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 24 + kb),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 44, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(AppRadii.pill)))),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Text('Custom Exercise', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name, autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(
                labelText: 'Exercise Name *', errorText: _err),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _emoji,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(labelText: 'Emoji'),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMuscle,
                dropdownColor: AppColors.bgCardLight,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Muscle Group',
                ),
                items: _muscles.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedMuscle = v);
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
            child: SwitchListTile(
              value: _bw,
              onChanged: (v) { H.selection(); setState(() => _bw = v); },
              title: Text('Bodyweight exercise',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(_bw ? 'Tracked in reps' : 'Tracked in kg',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
              activeColor: AppColors.gold,
            ),
          ),
          const SizedBox(height: 18),
          GoldButton(text: 'Add Exercise', width: double.infinity,
              onTap: _submit),
        ],
      )),
    );
  }
}


// ════════════════════════════════════════════════
// GENERATE PLAN SHEET
// ════════════════════════════════════════════════
void _showGeneratePlanSheet(BuildContext context) {
  String goal = 'Build Muscle';
  String level = 'Beginner';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgModal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFA8892C)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: Colors.black, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI PLAN GENERATOR',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        )),
                    Text('Build your perfect week',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),

            Text('YOUR GOAL',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                )),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in ['Build Muscle', 'Lose Fat', 'Get Stronger', 'Stay Fit'])
                _chip(g, goal == g, () => setState(() => goal = g)),
            ]),
            const SizedBox(height: 20),

            Text('YOUR LEVEL',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                )),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in ['Beginner', 'Intermediate', 'Advanced'])
                _chip(l, level == l, () => setState(() => level = l)),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  H.medium();
                  Navigator.pop(ctx);
                  final p = context.read<AppProvider>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Generating your plan...',
                          style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w700)),
                      backgroundColor: AppColors.bgCard,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  try {
                    await p.workout.generateSmartPlan(goal: goal, level: level);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Plan generated',
                              style: GoogleFonts.rajdhani(
                                  fontWeight: FontWeight.w700)),
                          backgroundColor: AppColors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Something went wrong. Please try again.'),
                          backgroundColor: AppColors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.hub_rounded, size: 20),
                label: Text('Generate Plan',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _chip(String label, bool selected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.15)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label,
          style: GoogleFonts.rajdhani(
            color: selected ? AppColors.gold : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// DAILY READINESS SELECTOR
// ══════════════════════════════════════════════════════════════════
// INJURY RISK BANNER
// Deterministic warnings — no AI, no network call.
// ══════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════
// OVERTRAINING RISK BANNER
// Surfaces the analyticsEngine.overtTrainingRisk score
// which was previously computed but never shown in the UI.
// Fires when ACWR-based risk exceeds 60/100.
// ════════════════════════════════════════════════════════
class _OvertrainingBanner extends StatefulWidget {
  const _OvertrainingBanner();
  @override State<_OvertrainingBanner> createState() => _OvertrainingBannerState();
}

class _OvertrainingBannerState extends State<_OvertrainingBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _isBannerDismissed('overtrain').then((v) {
      if (mounted && v) setState(() => _dismissed = true);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _persistBannerDismiss('overtrain');
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, double>(
      selector: (_, ap) => ap.overTrainingRisk,
      builder: (_, risk, __) {
        if (_dismissed || risk <= 60) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF160000),
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
                color: AppColors.red.withValues(alpha: 0.55), width: 0.9),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.red, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Workload spike detected',
                    style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary, fontSize: 14,
                        fontWeight: FontWeight.w800)),
                Text(
                  'ACWR elevated — reduce volume 30% today '
                  '(risk ${risk.toStringAsFixed(0)}/100).',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10.5, height: 1.4),
                ),
              ],
            )),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: _dismiss,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.textMuted, size: 16),
            ),
          ]),
        );
      },
    );
  }
}

class _InjuryRiskBanner extends StatefulWidget {
  const _InjuryRiskBanner();
  @override
  State<_InjuryRiskBanner> createState() => _InjuryRiskBannerState();
}

class _InjuryRiskBannerState extends State<_InjuryRiskBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _isBannerDismissed('injury_risk').then((v) {
      if (mounted && v) setState(() => _dismissed = true);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _persistBannerDismiss('injury_risk');
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Selector<AppProvider, List<RecoveryWarning>>(
      selector: (_, p) => p.injuryRisks,
      builder: (context, warnings, _) {
        if (warnings.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Training Load Note',
                      style: GoogleFonts.rajdhani(
                          color: const Color(0xFFF59E0B),
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _dismiss();
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 16),
                ),
              ]),
              const SizedBox(height: 8),
              ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.emoji,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(w.message,
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              Text(
                'Sleep and nutrition matter more this week.',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// WELCOME BACK CARD — Phase P2
// Shown when comeback + recovery session signals are
// both active. Merges _AdaptiveDecisionCard (comeback)
// and _RecoverySessionCard into one premium surface so
// the athlete never sees two cards saying the same thing.
// ════════════════════════════════════════════════
class _WelcomeBackCard extends StatelessWidget {
  final RecoverySessionSuggestion suggestion;
  const _WelcomeBackCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0A06),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.30), width: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 7),
              Text('WELCOME BACK',
                  style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 9, fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 8),
            // Session message from RecoverySessionService
            Text(s.message,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.5)),
            const SizedBox(height: 10),
            // Intensity + volume pills
            Row(children: [
              _RecoveryPill(
                  icon: Icons.flash_on_rounded,
                  label: '${s.intensityLabel} intensity',
                  color: AppColors.orange),
              const SizedBox(width: 6),
              _RecoveryPill(
                  icon: Icons.layers_rounded,
                  label: '${s.volumeLabel} volume',
                  color: AppColors.blue),
            ]),
            const SizedBox(height: 10),
            // CTA → recovery sheet
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _RecoverySessionCard._showRecoverySheet(context, s);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.gold.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.30), width: 0.7),
                ),
                child: Text('View Session',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// RECOVERY SESSION CARD — Phase C2
// Appears on today's planner day when recovery is
// suppressed. Guides athlete toward a lighter session.
// One tap → sheet shows full adapted session details.
// ════════════════════════════════════════════════
class _RecoverySessionCard extends StatelessWidget {
  final RecoverySessionSuggestion suggestion;
  const _RecoverySessionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0A06),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.gold),
              ),
              const SizedBox(width: 8),
              Text('RECOVERY SESSION AVAILABLE',
                  style: GoogleFonts.inter(
                      color: AppColors.gold.withValues(alpha: 0.78),
                      fontSize: 8.5, fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 8),

            // ── Title + message ──────────────────────────────────
            Text(s.title,
                style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 5),
            Text(s.message,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w400, height: 1.5)),
            const SizedBox(height: 10),

            // ── Quick stats row ───────────────────────────────────
            Row(children: [
              _RecoveryPill(
                  icon: Icons.flash_on_rounded,
                  label: '${s.intensityLabel} intensity',
                  color: AppColors.orange),
              const SizedBox(width: 6),
              _RecoveryPill(
                  icon: Icons.layers_rounded,
                  label: '${s.volumeLabel} volume',
                  color: AppColors.blue),
              if (s.hasSwaps) ...[
                const SizedBox(width: 6),
                _RecoveryPill(
                    icon: Icons.swap_horiz_rounded,
                    label: '${s.replacementExercises.length} swaps',
                    color: AppColors.green),
              ],
            ]),
            const SizedBox(height: 10),

            // ── CTA ──────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showRecoverySheet(context, s);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.gold.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.30), width: 0.7),
                ),
                child: Text('View Recovery Session',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showRecoverySheet(
      BuildContext context, RecoverySessionSuggestion s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecoverySessionSheet(suggestion: s),
    );
  }
}

// ── Compact pill ─────────────────────────────────
class _RecoveryPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _RecoveryPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color.withValues(alpha: 0.80)),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(
              color: color.withValues(alpha: 0.80),
              fontSize: 9.5, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ════════════════════════════════════════════════
// RECOVERY SESSION SHEET
// Full-detail bottom sheet — shows the complete
// adapted session. One-tap reference for the athlete.
// ════════════════════════════════════════════════
class _RecoverySessionSheet extends StatelessWidget {
  final RecoverySessionSuggestion suggestion;
  const _RecoverySessionSheet({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s      = suggestion;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0A),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.16), width: 0.7),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36, height: 3.5,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Title ───────────────────────────────────────
                  Text(s.title,
                      style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(s.message,
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13, fontWeight: FontWeight.w300,
                          height: 1.60)),
                  const SizedBox(height: 18),

                  // ── Today's adaptations ─────────────────────────
                  _SheetSection(label: "TODAY'S ADAPTATIONS"),
                  const SizedBox(height: 8),
                  _AdaptationRow(
                    icon:  Icons.flash_on_rounded,
                    color: AppColors.orange,
                    label: 'Intensity',
                    value: s.intensityLabel,
                    note:  'of your normal training weight',
                  ),
                  const SizedBox(height: 6),
                  _AdaptationRow(
                    icon:  Icons.layers_rounded,
                    color: AppColors.blue,
                    label: 'Volume',
                    value: s.volumeLabel,
                    note:  'of your planned sets',
                  ),
                  if (s.simplifyWorkout) ...[
                    const SizedBox(height: 6),
                    _AdaptationRow(
                      icon:  Icons.view_agenda_outlined,
                      color: AppColors.purple,
                      label: 'Exercises',
                      value: 'Reduced',
                      note:  'fewer exercises, higher quality',
                    ),
                  ],
                  if (s.reduceAxialLoading) ...[
                    const SizedBox(height: 6),
                    _AdaptationRow(
                      icon:  Icons.vertical_align_center_rounded,
                      color: AppColors.yellow,
                      label: 'Loading',
                      value: 'Lighter spine',
                      note:  'axial load reduced today',
                    ),
                  ],

                  // ── Avoid ────────────────────────────────────────
                  if (s.avoidedExercises.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SheetSection(label: 'AVOID TODAY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: s.avoidedExercises.take(6).map((e) =>
                          _ExerciseTag(name: e, color: AppColors.red)).toList(),
                    ),
                  ],

                  // ── Suggested alternatives ───────────────────────
                  if (s.replacementExercises.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SheetSection(label: 'SUGGESTED INSTEAD'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: s.replacementExercises.map((e) =>
                          _ExerciseTag(name: e, color: AppColors.green)).toList(),
                    ),
                  ],

                  // ── Recovery focus ───────────────────────────────
                  if (s.recoveryFocus.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.16),
                            width: 0.6),
                      ),
                      child: Row(children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.gold.withValues(alpha: 0.70),
                            size: 13),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.recoveryFocus,
                            style: GoogleFonts.inter(
                                color: AppColors.gold.withValues(alpha: 0.75),
                                fontSize: 11.5, fontWeight: FontWeight.w500,
                                height: 1.4))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Close CTA ────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppGradients.gold,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 16, offset: const Offset(0, 3))],
                      ),
                      child: Text("Got it — I'll follow this today",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String label;
  const _SheetSection({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 2, height: 9,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.inter(
        color: AppColors.textMuted.withValues(alpha: 0.65),
        fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  ]);
}

class _AdaptationRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, value, note;
  const _AdaptationRow({
      required this.icon, required this.color,
      required this.label, required this.value, required this.note});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 14, color: color.withValues(alpha: 0.80)),
    ),
    const SizedBox(width: 10),
    SizedBox(width: 72,
        child: Text(label, style: GoogleFonts.inter(
            color: AppColors.textMuted, fontSize: 11,
            fontWeight: FontWeight.w500))),
    Text(value, style: GoogleFonts.rajdhani(
        color: color, fontSize: 15, fontWeight: FontWeight.w900, height: 1.0)),
    const SizedBox(width: 6),
    Expanded(child: Text(note, style: GoogleFonts.inter(
        color: AppColors.textMuted.withValues(alpha: 0.50),
        fontSize: 10, fontWeight: FontWeight.w400),
        overflow: TextOverflow.ellipsis)),
  ]);
}

class _ExerciseTag extends StatelessWidget {
  final String name;
  final Color  color;
  const _ExerciseTag({required this.name, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.22), width: 0.6),
    ),
    child: Text(name, style: GoogleFonts.inter(
        color: color.withValues(alpha: 0.82),
        fontSize: 10.5, fontWeight: FontWeight.w600)),
  );
}

// ════════════════════════════════════════════════
// MISSED DAY RECOVERY CARD
// Shows on today's view when yesterday was missed.
// One tap → adds missed exercises to today + marks yesterday complete.
// ════════════════════════════════════════════════
class _MissedDayRecoveryCard extends StatefulWidget {
  final DayPlan missed;
  const _MissedDayRecoveryCard({required this.missed});
  @override
  State<_MissedDayRecoveryCard> createState() => _MissedDayRecoveryCardState();
}

class _MissedDayRecoveryCardState extends State<_MissedDayRecoveryCard> {
  bool _dismissed = false;
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    _isBannerDismissed('missed_day').then((v) {
      if (mounted && v) setState(() => _dismissed = true);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _persistBannerDismiss('missed_day');
  }

  Future<void> _addToToday() async {
    if (_loading) return;
    setState(() => _loading = true);
    final p            = context.read<AppProvider>();
    final missedDayIdx = (p.todayIndex - 1 + 7) % 7;
    await p.appendMissedToToday(missedDayIdx);
    if (mounted) _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final missed = widget.missed;
    final muscles = missed.exercises
        .map((e) => e.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .take(3)
        .toList();
    final preview = missed.exercises.take(3).map((e) => e.name).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: _dismissed
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0B08),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('MISSED YESTERDAY',
                      style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 9.5, fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded,
                      size: 16,
                      color: AppColors.textMuted.withValues(alpha: 0.50)),
                ),
              ]),
            ),

            // ── Day title ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(missed.title,
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
            ),

            // ── Muscle groups ────────────────────────────────
            if (muscles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final m in muscles)
                    _ExerciseTag(name: m, color: AppColors.gold),
                ]),
              ),

            // ── Exercise preview ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in preview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        Container(
                          width: 3, height: 3,
                          margin: const EdgeInsets.only(right: 7, top: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: 0.55),
                          ),
                        ),
                        Text(name, style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12.5, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  if (missed.exercises.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                          '+${missed.exercises.length - 3} more exercises',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted.withValues(alpha: 0.60),
                              fontSize: 11, fontWeight: FontWeight.w400)),
                    ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Divider(
                  color: AppColors.divider.withValues(alpha: 0.30), height: 1),
            ),

            // ── CTA ──────────────────────────────────────────
            GestureDetector(
              onTap: _addToToday,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.14),
                      AppColors.gold.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(AppRadii.lg - 1),
                    bottomRight: Radius.circular(AppRadii.lg - 1),
                  ),
                ),
                child: Center(
                  child: _loading
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold.withValues(alpha: 0.80),
                          ))
                      : Text('Add to Today\'s Session',
                          style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),   // Padding
  );     // AnimatedSize
  }
}

// ════════════════════════════════════════════════════════════
// NUTRITION INTELLIGENCE CARD
// Today's macro targets + meal preview from saved AI diet plan
// ════════════════════════════════════════════════════════════

// ── Ghost Copy tag — shown on exercises pre-filled from a past week ──────────
class _GhostTag extends StatelessWidget {
  final int weekGap;
  const _GhostTag({required this.weekGap});

  @override
  Widget build(BuildContext context) {
    final label = GhostCopyService.tagLabel(weekGap);
    if (label.isEmpty) return const SizedBox.shrink();

    final color = weekGap >= 3
        ? const Color(0xFFE57373) // red — comeback
        : const Color(0xFF90A4AE); // grey-blue — skipped

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// WORKOUT SHARE SHEET + CARD
// ════════════════════════════════════════════════

class _WorkoutShareSheet extends StatefulWidget {
  final String dayTitle;
  final int    exCount, setCount, duration, recovery, streak;
  final double volumeKg;

  const _WorkoutShareSheet({
    required this.dayTitle, required this.exCount, required this.setCount,
    required this.volumeKg, required this.duration, required this.recovery,
    required this.streak,
  });

  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing  = false;

  Future<void> _doShare() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 80)); // let frame render
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/lifton_workout.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Trained with LiftOn 💪\nTrack smarter, lift harder.\nliftonapp.com',
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${_weekday(now.weekday)} · ${now.day} ${months[now.month - 1]}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: AppColors.bgModal,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('Share Workout', style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('Preview', style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Card preview ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RepaintBoundary(
              key: _cardKey,
              child: _WorkoutShareCard(
                dayTitle: widget.dayTitle.isEmpty ? 'Workout' : widget.dayTitle,
                dateStr:  dateStr,
                exCount:  widget.exCount,
                setCount: widget.setCount,
                volumeKg: widget.volumeKg,
                duration: widget.duration,
                recovery: widget.recovery,
                streak:   widget.streak,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Buttons ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GoldButton(
                  text: _sharing ? 'Preparing...' : 'Share',
                  icon: Icons.share_rounded,
                  onTap: _sharing ? () {} : _doShare,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  String _weekday(int w) => const ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'][w];
}

// ── The actual shareable card widget ─────────────────────────────────────────

class _WorkoutShareCard extends StatelessWidget {
  final String dayTitle, dateStr;
  final int    exCount, setCount, duration, recovery, streak;
  final double volumeKg;

  const _WorkoutShareCard({
    required this.dayTitle, required this.dateStr, required this.exCount,
    required this.setCount, required this.volumeKg, required this.duration,
    required this.recovery, required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final recoveryColor = recovery >= 80
        ? AppColors.green
        : recovery >= 50
            ? AppColors.orange
            : AppColors.red;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── App header ─────────────────────────────
          Row(children: [
            Text('LIFTON', style: GoogleFonts.inter(
                color: AppColors.gold, fontSize: 13,
                fontWeight: FontWeight.w800, letterSpacing: 3.0)),
            const Spacer(),
            const Icon(Icons.fitness_center_rounded,
                color: AppColors.gold, size: 14),
          ]),
          const SizedBox(height: 6),
          Container(height: 0.5,
              color: AppColors.gold.withValues(alpha: 0.25)),
          const SizedBox(height: 16),

          // ── Day title ──────────────────────────────
          Text(dayTitle, style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary, fontSize: 32,
              fontWeight: FontWeight.w900, height: 1.0)),
          const SizedBox(height: 4),
          Text(dateStr, style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────
          Row(children: [
            _ShareStat('$exCount', 'exercises'),
            _ShareStatDivider(),
            _ShareStat('$setCount', 'sets'),
            _ShareStatDivider(),
            _ShareStat('${duration}m', 'duration'),
            if (volumeKg > 0) ...[
              _ShareStatDivider(),
              _ShareStat(
                volumeKg >= 1000
                    ? '${(volumeKg / 1000).toStringAsFixed(1)}t'
                    : '${volumeKg.toInt()}kg',
                'volume'),
            ],
          ]),
          const SizedBox(height: 18),

          // ── Recovery + streak chips ────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            _ShareChip('Recovery $recovery%', recoveryColor),
            if (streak > 1)
              _ShareChip('$streak day streak', AppColors.gold),
          ]),
          const SizedBox(height: 16),

          // ── Footer ─────────────────────────────────
          Text('liftonapp.com', style: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.35),
              fontSize: 10, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final String value, label;
  const _ShareStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 22,
          fontWeight: FontWeight.w900, height: 1.0)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 10)),
    ],
  );
}

class _ShareStatDivider extends StatelessWidget {
  const _ShareStatDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 0.5, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.borderSoft,
  );
}

class _ShareChip extends StatelessWidget {
  final String text;
  final Color  color;
  const _ShareChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
    ),
    child: Text(text, style: GoogleFonts.inter(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
