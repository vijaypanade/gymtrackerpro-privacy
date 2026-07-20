import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

import 'package:provider/provider.dart';
import 'premium_screen.dart';
import '../models/models.dart' hide MissionType;
import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../utils/app_constants.dart';

import '../utils/app_routes.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/home/home_skeleton_widgets.dart';
import '../widgets/home/home_overlay_widgets.dart';
import '../widgets/home/ai_recovery_scan_card.dart';
import '../widgets/home/athlete_brain_card.dart';
import '../widgets/home/decision_hero_card.dart';
import '../widgets/home/workout_strip_card.dart';
import '../widgets/home/coach_insight_block.dart';
import '../widgets/home/daily_protein_card.dart';
import '../screens/weekly_story_screen.dart';

import 'ai_chat_screen.dart';
import '../brain/models/brain_card_data.dart' show MissionType;
import '../engines/recovery_engine.dart' show HrvReadiness, RecoveryEngine;
import '../ai/maturity/recovery_presentation.dart';

// ════════════════════════════════════════════════
// PREMIUM ADAPTIVE SCALE
// Keeps UI proportional across devices.
// ════════════════════════════════════════════════
double rs(BuildContext context, double value) {
  final w = MediaQuery.of(context).size.width;

  double factor = 1.0;

  if (w < 360) {
    factor = 0.90;
  } else if (w > 430) {
    factor = 1.08;
  }

  return value * factor;
}

// ════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════
// HOME SCREEN — Progressive Disclosure FTUE Architecture
// ════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Two targeted selects instead of one root watch — prevents the full
    // home tree from rebuilding on every AppProvider notify.
    final isLoading = context.select<AppProvider, bool>((p) => p.loading);
    if (isLoading) return const HomeSkeletonScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          // ── Bottom ambient fade for nav separation ─────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.gold.withValues(alpha: 0.018),
                      Colors.black.withValues(alpha: 0.10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(child: _FullDashboard()),
          const OverlayLayer(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// FULL DASHBOARD — shown for all users
// ════════════════════════════════════════════════
class _FullDashboard extends StatelessWidget {
  const _FullDashboard();

  @override
  Widget build(BuildContext context) {
    final pad = rs(context, 20.0);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const _HomeAppBar(),
        const SliverToBoxAdapter(child: _ComebackCeremonyGate()),

        // RFC-HOME-010 — decision-first ordering. The page now mirrors the
        // athlete's mental workflow: Can I train? (Recovery) → What am I
        // training? (Today's Workout) → Start (CTA). The CTA sits lower for
        // one-handed reach on large phones. Slot wrappers (padding + stagger
        // delays) are positional and did not move — only the cards swapped.

        // ── 1. RECOVERY INTELLIGENCE — "Can I train today?" ───────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 6), pad, 0),
            child: const _RecoveryIntelligenceCard(),
          ),
        ),

        // ── 2. TODAY'S WORKOUT STRIP — "What am I training?" ──────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 4), pad, 0),
            child: const FadeSlide(delay: 40, child: WorkoutStripCard()),
          ),
        ),

        // ── 3. DECISION HERO — today's verdict + primary CTA ──────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 4), pad, 0),
            child: const FadeSlide(delay: 60, child: DecisionHeroCard()),
          ),
        ),

        // ── 4. COACH INSIGHT — editorial annotation ───────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 12), pad, 0),
            child: const FadeSlide(delay: 80, child: CoachInsightBlock()),
          ),
        ),

        // ── 5. PERFORMANCE — Weekly Progress + Athlete Brain ─────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 6), pad, 0),
            child: const FadeSlide(delay: 100, child: _PerformanceSection()),
          ),
        ),

        // ── 6. PROTEIN / MISSIONS ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 6), pad, 0),
            child: const FadeSlide(delay: 120, child: DailyProteinCard()),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// SECTION HEADERS
// ════════════════════════════════════════════════

// ════════════════════════════════════════════════
// APP BAR — frosted
// ════════════════════════════════════════════════
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  static final _appBarBg = AppColors.bg.withValues(alpha: 0.93);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      snap: true,
      titleSpacing: AppSpacing.lg,
      // BackdropFilter causes compositing errors + white body on Android (Skia).
      // Use blur only on iOS where Impeller handles it correctly.
      flexibleSpace: Platform.isIOS
          ? ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: _appBarBg.withValues(alpha: 0.72),
                    border: Border(bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.04), width: 0.6)),
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: _appBarBg.withValues(alpha: 0.95),
                border: Border(bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04), width: 0.6)),
              ),
            ),
      title: const _HomeAppBarTitle(),
      actions: const [
        _EliteHookAction(),
        _StreakAction(),
      ],
    );
  }
}

class _HomeAppBarTitle extends StatelessWidget {
  const _HomeAppBarTitle();

  static String _contextLine({
    required bool isCompleted,
    required bool isRestDay,
    required String planTitle,
    required int totalWorkouts,
  }) {
    final h = DateTime.now().hour;
    final timeSlot = h < 12 ? 'morning' : h < 17 ? 'afternoon' : h < 21 ? 'evening' : 'night';

    if (totalWorkouts == 0) {
      return h < 12 ? 'Ready to start?' : 'First workout awaits';
    }
    if (isRestDay) {
      return 'Rest $timeSlot — body is recovering';
    }
    if (isCompleted) {
      final plan = planTitle.isNotEmpty ? planTitle : 'Workout';
      return 'Rest $timeSlot — $plan done';
    }
    // Pending workout
    return h < 12 ? 'Morning — time to train' :
           h < 17 ? 'Afternoon session ready' :
           h < 21 ? 'Evening grind' : 'Late session — let\'s go';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({String name, bool isCompleted, bool isRestDay, String planTitle, int totalWorkouts})>(
      selector: (_, ap) {
        final plan = ap.todayPlan;
        return (
          name:          ap.profile.name,
          isCompleted:   plan.isCompleted,
          isRestDay:     plan.isRestDay,
          planTitle:     plan.title,
          totalWorkouts: ap.totalWorkouts,
        );
      },
      builder: (_, d, __) {
        final first = d.name.isEmpty ? null : d.name.split(' ').first;
        final line  = _contextLine(
          isCompleted:   d.isCompleted,
          isRestDay:     d.isRestDay,
          planTitle:     d.planTitle,
          totalWorkouts: d.totalWorkouts,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              line,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withValues(alpha: 0.42),
                letterSpacing: 0.1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              first ?? 'Athlete',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

class _EliteHookAction extends StatelessWidget {
  const _EliteHookAction();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, ap) => ap.isPremium,
      builder: (_, isPremium, __) {
        if (isPremium) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => Navigator.push(context, slideRoute(const PremiumScreen())),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 11,
                    color: AppColors.goldAmber.withValues(alpha: 0.80),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Elite',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.goldAmber.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreakAction extends StatelessWidget {
  const _StreakAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Selector<AppProvider, ({int streak, String lastDate})>(
        selector: (_, ap) => (
          streak: ap.streak.currentStreak,
          lastDate: ap.streak.lastWorkoutDate,
        ),
        builder: (_, s, __) => s.streak == 0
            ? const SizedBox.shrink()
            : _StreakBadge(
                streak: s.streak,
                lastWorkoutDate: s.lastDate,
              ),
      ),
    );
  }
}

class _StreakBadge extends StatefulWidget {
  final int streak;
  final String lastWorkoutDate;
  const _StreakBadge({required this.streak, required this.lastWorkoutDate});
  @override State<_StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<_StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  bool get _isUrgent {
    final now = DateTime.now();
    if (now.hour < 20) return false;
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return widget.lastWorkoutDate != todayStr;
  }

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (_isUrgent) _shake.repeat(reverse: true);
  }

  @override
  void dispose() { _shake.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) {
        return child!;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.goldAmber.withValues(alpha: 0.75),
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.streak}',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseOrb extends StatefulWidget {
  final String emoji;
  final Gradient gradient;
  const _PulseOrb({required this.emoji, required this.gradient});

  @override
  State<_PulseOrb> createState() => _PulseOrbState();
}

class _PulseOrbState extends State<_PulseOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final v = _pulse.value;
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE8E8E8),
                  Color(0xFFB0B0B0),
                  Color(0xFF888888),
                  Color(0xFFD4D4D4),
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.22 * v),
                  blurRadius: 22 * v,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.gradient,
                ),
                child: const Center(
                  child: Icon(
                    Icons.military_tech_rounded,
                    color: AppColors.gold,
                    size: 22,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedXPBar extends StatefulWidget {
  final double progress;
  const _AnimatedXPBar({required this.progress});

  @override
  State<_AnimatedXPBar> createState() => _AnimatedXPBarState();
}

class _AnimatedXPBarState extends State<_AnimatedXPBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;
  late Animation<double> _tween;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _tween = Tween<double>(begin: 0, end: widget.progress).animate(_curve);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedXPBar old) {
    super.didUpdateWidget(old);
    if ((old.progress - widget.progress).abs() > 0.001) {
      _tween = Tween<double>(
        begin: _tween.value,
        end: widget.progress,
      ).animate(_curve);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _tween,
        builder: (_, __) => XPProgressBar(progress: _tween.value),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// RECOVERY RING PAINTER
// ════════════════════════════════════════════════
class _RecoveryRingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color  ringColor;
  const _RecoveryRingPainter({required this.progress, required this.ringColor});

  static const double _strokeWidth = 14.0;
  // 7:30 position start, 270° sweep — gap at bottom (WHOOP/Oura style)
  static const double _startAngle  = math.pi * 0.75;
  static const double _sweepAngle  = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - _strokeWidth;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, _startAngle, _sweepAngle, false,
      Paint()
        ..color       = const Color(0xFF1E1E1E)
        ..strokeWidth = _strokeWidth
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );
    canvas.drawArc(
      rect, _startAngle, _sweepAngle * progress.clamp(0.02, 1.0), false,
      Paint()
        ..color       = ringColor
        ..strokeWidth = _strokeWidth
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RecoveryRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

// ════════════════════════════════════════════════
// RECOVERY INTELLIGENCE CARD
// Hero surface. One ring. One score. One insight.
// WHOOP + Oura + Apple Health aesthetic.
// ════════════════════════════════════════════════
class _RecoveryIntelligenceCard extends StatelessWidget {
  const _RecoveryIntelligenceCard();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({int overall, List<MuscleRecovery> muscles, double readiness,
          double sleepHours, int todaySteps, double activeKcal,
          bool canShowTrendArrow, String trendFallbackCopy,
          double? hrv, double? hrvBaseline,
          MissionType missionType, bool isRestDay})>(
      selector: (_, ap) => (
        overall:           ap.getOverallRecovery(),
        muscles:           ap.muscleRecoveryList,
        readiness:         ap.weeklyReadinessScore,
        sleepHours:        ap.coachSleepHours,
        todaySteps:        ap.healthTodaySteps,
        activeKcal:        ap.healthActiveEnergyKcal,
        canShowTrendArrow: ap.aiMaturity.allowedClaims.ui.canShowTrendArrow,
        trendFallbackCopy: ap.aiMaturity.phase.recoveryTrendFallbackCopy,
        hrv:               ap.healthHrv,
        hrvBaseline:       ap.healthHrvBaseline,
        missionType:       ap.brainCardData.missionType,
        isRestDay:         ap.todayPlan.isRestDay,
      ),
      builder: (ctx, d, __) {
        if (d.muscles.isEmpty) return const _OnboardingRecoveryCard();

        final sorted = [...d.muscles]
          ..sort((a, b) => a.recoveryScore.compareTo(b.recoveryScore));
        final allBalanced = sorted.first.recoveryScore >= 90;
        final trendDelta  = ((d.readiness * 100 - d.overall) * 0.14)
            .round().clamp(-12, 12);

        final ringColor = d.overall >= 70
            ? AppColors.gold
            : d.overall >= 50
                ? AppColors.orange
                : AppColors.red;

        // Score-based label inside the ring arc (visual continuity with ring colour).
        final statusLabel = d.overall >= 70
            ? 'Ready'
            : d.overall >= 50
                ? 'Adapting'
                : 'Under-recovered';

        // Score-based chip — body readiness only, no mission override.
        // Decision Hero already communicates today's training intent.
        final String chipLabel;
        final Color  chipColor;
        if (d.overall >= 70) {
          chipLabel = 'Ready';      chipColor = AppColors.green;
        } else if (d.overall >= 50) {
          chipLabel = 'Adapting';   chipColor = AppColors.goldSoft;
        } else {
          chipLabel = 'Recovering'; chipColor = AppColors.orange;
        }

        final trendLabel = trendDelta > 2
            ? 'Improving'
            : trendDelta < -2
                ? 'Declining'
                : 'Stable';
        final trendColor = trendDelta > 2
            ? AppColors.gold
            : trendDelta < -2
                ? AppColors.red
                : AppColors.orange;

        // HRV classification — single source of truth via RecoveryEngine.
        final hrvState = RecoveryEngine.hrvReadiness(d.hrv, d.hrvBaseline);

        // Sleep — semantic label (no raw hours exposed on home card).
        final String? sleepLabel = d.sleepHours <= 0 ? null
            : d.sleepHours >= 7.5 ? 'Good sleep'
            : d.sleepHours >= 6.0 ? 'Short sleep'
            : 'Poor sleep';
        final Color sleepColor = d.sleepHours >= 7.5
            ? AppColors.green
            : d.sleepHours >= 6.0
                ? AppColors.orange
                : AppColors.red;

        // Muscles needing most attention — bottom 2 by recovery score.
        // Only shown when at least one muscle is not fully recovered.
        final attentionMuscles = allBalanced ? <MuscleRecovery>[] : sorted.take(2).toList();
        final attentionLabel   = !allBalanced && sorted.first.recoveryScore < 40
            ? 'Needs attention'
            : 'Still recovering';

        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); _openScan(ctx); },
          behavior: HitTestBehavior.opaque,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: const Color(0xFF242424), width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Ring (left) · Status info (right) ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Recovery ring — 128px, score + semantic label inside
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ringColor.withValues(alpha: 0.14),
                              blurRadius: 24,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _RecoveryRingPainter(
                            progress:  d.overall / 100.0,
                            ringColor: ringColor,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${d.overall}',
                                  style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    color: AppColors.textPrimary,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: ringColor.withValues(alpha: 0.30),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: ringColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Status info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status chip — unified label matching Decision Hero chip.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                              ),
                              child: Text(
                                chipLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: chipColor.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Primary headline
                            Text(
                              allBalanced
                                  ? 'All muscles ready'
                                  : sorted.last.recoveryScore >= 80
                                      ? '${_abbr(sorted.last.muscle)} ready to train'
                                      : 'Recovery in progress',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Trend row — shown once canShowTrendArrow is earned
                            if (d.canShowTrendArrow)
                              Row(children: [
                                Icon(
                                  trendDelta > 2
                                      ? Icons.trending_up_rounded
                                      : trendDelta < -2
                                          ? Icons.trending_down_rounded
                                          : Icons.trending_flat_rounded,
                                  size: 13,
                                  color: trendColor.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trendLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: trendColor.withValues(alpha: 0.75),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ])
                            else
                              Text(
                                d.trendFallbackCopy,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted.withValues(alpha: 0.40),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                            // Muscles needing most attention (2 lowest scores)
                            if (attentionMuscles.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                attentionLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted.withValues(alpha: 0.55),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: attentionMuscles.map((m) =>
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _MuscleAttentionPill(muscle: m),
                                  ),
                                ).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Context signals ───────────────────────────────
                  // Primary: Sleep (semantic) + HRV status
                  // Secondary: Steps + Calories (de-emphasised)
                  if (sleepLabel != null || hrvState != HrvReadiness.unavailable ||
                      d.todaySteps > 0 || d.activeKcal > 0) ...[
                    const SizedBox(height: 6),
                    Container(height: 0.5, color: AppColors.borderSoft),
                    const SizedBox(height: 6),

                    // Primary signals
                    if (sleepLabel != null || hrvState != HrvReadiness.unavailable)
                      Row(
                        children: [
                          if (sleepLabel != null) ...[
                            Icon(Icons.bedtime_rounded, size: 11, color: sleepColor),
                            const SizedBox(width: 4),
                            Text(
                              sleepLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: sleepColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (sleepLabel != null && hrvState != HrvReadiness.unavailable)
                            Container(
                              width: 3, height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.textMuted.withValues(alpha: 0.4),
                              ),
                            ),
                          if (hrvState != HrvReadiness.unavailable) ...[
                            Icon(Icons.monitor_heart_outlined, size: 11,
                                color: _hrvColor(hrvState)),
                            const SizedBox(width: 4),
                            Text(
                              _hrvLabel(hrvState),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: _hrvColor(hrvState),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),

                    // Secondary signals — steps + kcal, visually subordinate
                    if (d.todaySteps > 0 || d.activeKcal > 0) ...[
                      if (sleepLabel != null || hrvState != HrvReadiness.unavailable)
                        const SizedBox(height: 2),
                      Opacity(
                        opacity: 0.40,
                        child: Row(
                          children: [
                            if (d.todaySteps > 0) ...[
                              const Icon(Icons.directions_walk_rounded,
                                  size: 10, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                d.todaySteps >= 1000
                                    ? '${(d.todaySteps / 1000).toStringAsFixed(1)}k steps'
                                    : '${d.todaySteps} steps',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            if (d.todaySteps > 0 && d.activeKcal > 0)
                              Container(
                                width: 3, height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textMuted.withValues(alpha: 0.4),
                                ),
                              ),
                            if (d.activeKcal > 0) ...[
                              const Icon(Icons.local_fire_department_rounded,
                                  size: 10, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                '${d.activeKcal.round()} kcal',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _hrvLabel(HrvReadiness state) {
    switch (state) {
      case HrvReadiness.elevated:     return 'HRV Elevated';
      case HrvReadiness.normal:       return 'HRV Normal';
      case HrvReadiness.suppressed:   return 'HRV Suppressed';
      case HrvReadiness.unavailable:  return '';
    }
  }

  static Color _hrvColor(HrvReadiness state) {
    switch (state) {
      case HrvReadiness.elevated:     return AppColors.green;
      case HrvReadiness.normal:       return AppColors.textMuted;
      case HrvReadiness.suppressed:   return AppColors.orange;
      case HrvReadiness.unavailable:  return AppColors.textMuted;
    }
  }

  String _abbr(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':     return 'Chest';
      case 'back':      return 'Back';
      case 'legs':      return 'Legs';
      case 'shoulders': return 'Shoulders';
      case 'biceps':    return 'Biceps';
      case 'triceps':   return 'Triceps';
      case 'core':      return 'Core';
      case 'calves':    return 'Calves';
      case 'arms':      return 'Arms';
      default:
        final n = muscle.isEmpty ? '' : muscle[0].toUpperCase() + muscle.substring(1);
        return n.length > 5 ? n.substring(0, 5) : n;
    }
  }

  void _openScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.50,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C0C0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
          ),
          child: Column(
            children: [
              // Handle + close row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 44, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderMedium,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderMedium, width: 0.5),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: const AiRecoveryScanCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// MUSCLE ATTENTION PILL
// ════════════════════════════════════════════════

class _MuscleAttentionPill extends StatelessWidget {
  final MuscleRecovery muscle;
  const _MuscleAttentionPill({required this.muscle});

  @override
  Widget build(BuildContext context) {
    final score = muscle.recoveryScore.toDouble();
    final color = score >= 70 ? AppColors.gold
        : score >= 40        ? AppColors.orange
        : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.5),
      ),
      child: Text(
        muscle.muscle,
        style: TextStyle(
          fontFamily: 'Inter',
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// ONBOARDING STATES — shown when no workout history
// ════════════════════════════════════════════════

class _OnboardingRecoveryCard extends StatelessWidget {
  const _OnboardingRecoveryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.07),
            AppColors.bgCard,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppGradients.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.monitor_heart_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECOVERY',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Log your first session to unlock recovery tracking.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingAIVerdictCard extends StatelessWidget {
  const _OnboardingAIVerdictCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: AppColors.gold.withValues(alpha: 0.06),
          highlightColor: AppColors.gold.withValues(alpha: 0.03),
          onTap: () {
            const seed = 'I am a new LiftOn user ready to start training.';
            Navigator.push(context, slideRoute(const AIChatScreen(seedContext: seed)));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.gold.withValues(alpha: 0.09),
                  AppColors.bgCard,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.22), width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppGradients.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COACH',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your first workout activates personalised coaching.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.gold.withValues(alpha: 0.60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// AI VERDICT CARD
// Bridge between recovery analytics and coaching.
// Tappable → AIChatScreen opens pre-contextualized.
// Scale 1.0→0.985 on press, 200ms.
// ════════════════════════════════════════════════
class _AIVerdictCard extends StatefulWidget {
  const _AIVerdictCard();
  @override State<_AIVerdictCard> createState() => _AIVerdictCardState();
}

class _AIVerdictCardState extends State<_AIVerdictCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _scale, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() { _scale.dispose(); super.dispose(); }

  // ── Build the pre-loaded coach context ──────────────────────────────────
  // This becomes the AI's opening message when the chat has no prior history.
  String _buildSeedContext(AppProvider ap) {
    final recovery   = ap.getOverallRecovery();
    final readiness  = ap.weeklyReadinessScore;
    final trendDelta = ((readiness * 100 - recovery) * 0.14).round().clamp(-12, 12);
    final trend      = trendDelta > 2 ? 'Improving' : trendDelta < -2 ? 'Declining' : 'Stable';
    final readLabel  = readiness > 0.70 ? 'High' : readiness > 0.40 ? 'Moderate' : 'Low';
    final limiting   = ap.weakestMuscle.isNotEmpty
        ? '${ap.weakestMuscle[0].toUpperCase()}${ap.weakestMuscle.substring(1)}'
        : null;
    final trainFocus = ap.topMuscleGroup.isNotEmpty ? ap.topMuscleGroup : null;
    final isCompleted = ap.todayPlan.isCompleted;

    // Post-workout: shift to recovery framing — use actual plan title
    if (isCompleted) {
      final planTitle = ap.todayPlan.title;
      final session   = planTitle.isNotEmpty ? planTitle : (trainFocus ?? 'Today\'s session');
      final recoveryHrs = ((100 - recovery) * 0.28).toInt().clamp(4, 40);
      final buf = StringBuffer();
      buf.writeln('$session complete. Here is your recovery breakdown.');
      buf.writeln();
      buf.write('Recovery: $recovery%  ·  Readiness: $readLabel  ·  Trend: $trend');
      buf.write('\nRecovery window: ~${recoveryHrs}h');
      if (limiting != null) buf.write('\nMost fatigued: $limiting');
      buf.write('\nPrioritise sleep and protein intake to accelerate adaptation.');
      return buf.toString();
    }

    // Pre-workout: training readiness framing
    final insight = ap.coachInsight;
    final buf = StringBuffer();
    if (insight.title.isNotEmpty) {
      buf.writeln(insight.title);
      buf.writeln();
    }
    buf.write('Recovery: $recovery%  ·  Readiness: $readLabel  ·  Trend: $trend');
    if (limiting != null)   buf.write('\nLimiting Factor: $limiting');
    if (trainFocus != null) buf.write("\nToday's Focus: $trainFocus Training");
    return buf.toString();
  }

  // ── Generic-text filters ────────────────────────────────────────────────
  static bool _isGenericText(String t) {
    if (t.isEmpty) return true;
    final l = t.toLowerCase();
    return l.contains('session complete') ||
        l.contains('recovery demand elevated') ||
        l.contains('lifton ai') ||
        l.contains('analyzes training') ||
        l.contains('adaptive guidance');
  }

  // Extract the primary trained muscle from plan title (e.g. "Chest + Triceps" → "Chest")
  static String _primaryMuscleName(String planTitle, String train) {
    final l = planTitle.toLowerCase();
    if (l.contains('chest'))    return 'Chest';
    if (l.contains('back'))     return 'Back';
    if (l.contains('leg'))      return 'Legs';
    if (l.contains('shoulder')) return 'Shoulders';
    if (l.contains('push'))     return 'Push muscles';
    if (l.contains('pull'))     return 'Pull muscles';
    if (l.contains('arm') || l.contains('bicep') || l.contains('tricep')) return 'Arms';
    if (train.isNotEmpty) {
      return '${train[0].toUpperCase()}${train.substring(1)}';
    }
    return 'Trained muscles';
  }

  // Movement-specific recovery advice based on what was trained
  static String _movementAdvice(String planTitle, String train) {
    final l = planTitle.toLowerCase();
    if (l.contains('chest') || l.contains('push')) {
      return 'Avoid pressing movements tomorrow morning.';
    }
    if (l.contains('back') || l.contains('pull')) {
      return 'Avoid heavy rows and pulls tomorrow.';
    }
    if (l.contains('leg') || l.contains('squat')) {
      return 'Skip squats and lunges tomorrow morning.';
    }
    if (l.contains('shoulder')) {
      return 'Avoid overhead pressing tomorrow.';
    }
    if (l.contains('arm') || l.contains('bicep') || l.contains('tricep')) {
      return 'Keep direct arm work light tomorrow.';
    }
    final lt = train.toLowerCase();
    if (lt == 'chest')    return 'Avoid pressing movements tomorrow morning.';
    if (lt == 'back')     return 'Avoid heavy rows and pulls tomorrow.';
    if (lt == 'legs')     return 'Skip squats and lunges tomorrow morning.';
    return 'Keep intensity low tomorrow morning.';
  }

  static String _specificInsight({
    required int recovery,
    required double readiness,
    required String limiting,
    required String train,
    required bool isCompleted,
    required String planTitle,
    double sleepHours = 0.0,
    String nextWorkout = '',
    String etaMuscle   = '',
    int    etaHours    = 0,
  }) {
    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
    final trendDelta = ((readiness * 100 - recovery) * 0.14).round().clamp(-12, 12);
    final hasNext  = nextWorkout.isNotEmpty;
    // Real muscle-specific ETA from RecoveryEngine — never a fabricated estimate.
    final hasEta   = etaHours > 1 && etaMuscle.isNotEmpty;
    final etaLabel = hasEta ? '${cap(etaMuscle)} requires ~${etaHours}h more recovery.' : '';

    // ── Post-workout ──────────────────────────────────────────────────────────
    // Priority: ETA + next > next only > ETA only > detailed recovery fallback.
    if (isCompleted) {
      final primaryMuscle = _primaryMuscleName(planTitle, train);
      if (hasNext && hasEta) {
        return '$primaryMuscle recovery is underway.\n'
            'Estimated readiness in ~${etaHours}h.\n'
            'Tomorrow\'s $nextWorkout session is positioned well.';
      }
      if (hasNext) {
        return '$primaryMuscle recovery is underway.\n'
            'Tomorrow\'s $nextWorkout session is positioned well.';
      }
      if (hasEta) {
        final movementAdvice = _movementAdvice(planTitle, train);
        return '$primaryMuscle recovery is underway.\n'
            'Estimated readiness in ~${etaHours}h. $movementAdvice';
      }
      // No ETA, no next: existing detailed recovery coaching.
      final movementAdvice = _movementAdvice(planTitle, train);
      final protein = recovery < 65 ? '160g' : recovery < 78 ? '140g' : '130g';
      if (recovery < 65) {
        return '$primaryMuscle recovery is underway. $movementAdvice Protein target tonight: $protein.';
      }
      if (recovery < 78) {
        return '$primaryMuscle recovery is underway. $movementAdvice Aim for 7–8h sleep tonight.';
      }
      return 'Strong session. $primaryMuscle will adapt overnight — hit $protein protein today to lock in the gains.';
    }

    // ── Pre-workout: sleep-aware enhancement ─────────────────────────────────
    // sleepHours == 0.0 = "no data" sentinel — never mention sleep in that case.
    // Critical limiting state (suppressed muscle + low overall) falls through.
    final bool sleepKnown = sleepHours >= 1.0;
    if (sleepKnown) {
      final bool isCriticalLimiting = limiting.isNotEmpty && recovery < 60;
      if (!isCriticalLimiting) {
        final sleepStr = sleepHours.toStringAsFixed(1);

        // Sleep + ETA: 3-line format for non-poor sleep only.
        // Poor sleep (<6h) keeps its limitation warning as the primary signal.
        if (hasEta && sleepHours >= 6.0) {
          final nextLine = hasNext
              ? 'Tomorrow\'s $nextWorkout session remains fully supported.'
              : 'Train around ${etaMuscle.toLowerCase()} loading today.';
          return 'Sleep logged at ${sleepStr}h.\n$etaLabel\n$nextLine';
        }

        if (sleepHours < 6.0) {
          return 'Sleep logged at ${sleepStr}h.\n'
              'Recovery supports training, but peak output may be limited today.';
        } else if (sleepHours >= 8.0) {
          final suffix = hasNext
              ? 'Strong recovery foundation supports tomorrow\'s $nextWorkout session.'
              : 'Strong recovery foundation supports full training intensity.';
          return 'Sleep logged at ${sleepStr}h.\n$suffix';
        } else {
          final suffix = hasNext
              ? '$nextWorkout is next — recovery supports productive training today.'
              : 'Recovery supports productive training today.';
          return 'Sleep logged at ${sleepStr}h.\n$suffix';
        }
      }
    }

    // ── Pre-workout: training recommendation ──────────────────────────────────
    // Rotates every 6h so the message feels fresh throughout the day.
    final slot = DateTime.now().hour ~/ 6; // 0=night 1=morning 2=afternoon 3=evening

    if (limiting.isNotEmpty && recovery < 60) {
      if (hasEta && hasNext) {
        return '$etaLabel\n'
            'Tomorrow\'s $nextWorkout session remains fully supported.';
      }
      if (hasEta) {
        return slot.isEven
            ? '$etaLabel Train around it today.'
            : '${cap(etaMuscle)} hasn\'t cleared yet (~${etaHours}h remaining). Redirect to a fresh muscle group.';
      }
      // No reliable ETA — directional message without a fabricated time estimate.
      return slot.isEven
          ? '${cap(limiting)} recovery still elevated. Skip direct work today — train around it.'
          : 'Your ${limiting.toLowerCase()} hasn\'t cleared yet. Redirect to a fresh muscle group.';
    }
    if (train.isNotEmpty && recovery >= 70) {
      return slot.isEven
          ? '${cap(train)} window is open. Recovery markers support full intensity — load up today.'
          : 'Prime window for ${train.toLowerCase()}. This kind of readiness is worth pushing — go for it.';
    }
    if (trendDelta > 2 && recovery >= 55) {
      if (hasNext) {
        return 'Recovery is trending upward.\n'
            '$nextWorkout is next in the training rotation.';
      }
      return slot.isEven
          ? 'Recovery improving. Stay consistent.'
          : 'Momentum building. Each session counts.';
    }
    if (recovery >= 80) {
      return slot.isEven
          ? 'High readiness. If there\'s a PR to chase, today is the day to go for it.'
          : 'Recovered and ready. Add weight today.';
    }
    return slot.isEven
        ? 'Moderate recovery. Prioritise compound lifts — avoid failure and control intensity.'
        : 'Recovery at $recovery%. Good session possible — lead with technique, earn the load.';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({
      String rawTitle,
      String secondary,
      String badge,
      Color  accent,
      int    recovery,
      double readiness,
      String limiting,
      String train,
      bool   isCompleted,
      String planTitle,
      double sleepHours,
      String nextWorkout,
      String etaMuscle,
      int    etaHours,
    })>(
      selector: (_, ap) {
        final ci  = ap.coachInsight;
        final eta = ap.limitingMuscleEta;
        return (
          rawTitle:    ci.title,
          secondary:   ci.secondary,
          badge:       ci.badge,
          accent:      ci.accentColor,
          recovery:    ap.getOverallRecovery(),
          readiness:   ap.weeklyReadinessScore,
          limiting:    ap.weakestMuscle,
          train:       ap.topMuscleGroup,
          isCompleted: ap.todayPlan.isCompleted,
          planTitle:   ap.todayPlan.title,
          sleepHours:  ap.coachSleepHours,
          nextWorkout: ap.nextWorkoutTitle,
          etaMuscle:   eta.muscle,
          etaHours:    eta.hours,
        );
      },
      builder: (ctx, d, __) {
        final title = _isGenericText(d.rawTitle) || d.isCompleted
            ? _specificInsight(
                recovery:    d.recovery,
                readiness:   d.readiness,
                limiting:    d.limiting,
                train:       d.train,
                isCompleted: d.isCompleted,
                planTitle:   d.planTitle,
                sleepHours:  d.sleepHours,
                nextWorkout: d.nextWorkout,
                etaMuscle:   d.etaMuscle,
                etaHours:    d.etaHours,
              )
            : d.rawTitle;
        if (title.isEmpty) return const _OnboardingAIVerdictCard();

        return ScaleTransition(
          scale: _scaleAnim,
          // GestureDetector: scale animation only — no navigation here
          child: GestureDetector(
            onTapDown:   (_) { _scale.forward(); HapticFeedback.lightImpact(); },
            onTapCancel: () => _scale.reverse(),
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: Material(
                color: const Color(0xFF111111),
                child: InkWell(
                  splashColor:    Colors.white.withValues(alpha: 0.05),
                  highlightColor: Colors.white.withValues(alpha: 0.03),
                  // InkWell owns navigation — single entry point
                  onTap: () {
                    _scale.reverse();
                    final ap = context.read<AppProvider>();
                    final seed = _buildSeedContext(ap);
                    Navigator.push(ctx, slideRoute(AIChatScreen(seedContext: seed)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header — no badge, just subtle CTA ──────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Coach',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textMuted.withValues(alpha: 0.38),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: AppColors.textMuted.withValues(alpha: 0.30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        // ── Specific coaching insight ─────────────────────
                        _TypewriterText(
                          text: title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


// ════════════════════════════════════════════════
// TYPEWRITER TEXT — reveals text character by character
// ════════════════════════════════════════════════
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _TypewriterText({required this.text, required this.style});

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayed = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping(widget.text);
  }

  @override
  void didUpdateWidget(_TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _timer?.cancel();
      setState(() { _displayed = ''; });
      _startTyping(widget.text);
    }
  }

  void _startTyping(String text) {
    int idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx >= text.length) {
        t.cancel();
        if (mounted) setState(() {});
        return;
      }
      setState(() => _displayed = text.substring(0, ++idx));
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      Text(_displayed, style: widget.style);
}

class _RecoveryMuscleBar extends StatefulWidget {
  const _RecoveryMuscleBar({required this.label, required this.score});
  final String label;
  final int    score;
  @override State<_RecoveryMuscleBar> createState() => _RecoveryMuscleBarState();
}

class _RecoveryMuscleBarState extends State<_RecoveryMuscleBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    // Small delay so the card fade-in completes first
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.score > 60
        ? AppColors.gold
        : widget.score > 40
            ? AppColors.goldAmber
            : widget.score > 20
                ? AppColors.orange
                : AppColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => FractionallySizedBox(
                    widthFactor: (widget.score / 100.0) * _anim.value,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              widget.score >= 80
                  ? 'Ready'
                  : widget.score >= 50
                      ? '~${((100 - widget.score) * 0.48).round()}h'
                      : 'Resting',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color.withValues(alpha: 0.60),
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// MISSIONS CARD
// ════════════════════════════════════════════════
class _MissionsCard extends StatefulWidget {
  const _MissionsCard();

  @override
  State<_MissionsCard> createState() => _MissionsCardState();
}

class _MissionsCardState extends State<_MissionsCard> {
  bool _initScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInit());
  }

  @override
  void didUpdateWidget(covariant _MissionsCard old) {
    super.didUpdateWidget(old);
    if (!_initScheduled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInit());
    }
  }

  void _ensureInit() {
    if (_initScheduled || !mounted) return;
    final ap = context.read<AppProvider>();
    final gp = context.read<GamificationProvider>();
    if (gp.totalMissions != 0) return;
    _initScheduled = true;

    gp.initMissionsIfNeeded(
      streak: ap.streak.currentStreak,
      totalWorkouts: ap.streak.totalWorkouts,
      goal: ap.profile.goal,
      weakMuscle: ap.weakestMuscle,
    );

    if (ap.workoutReminderEnabled) {
      NotificationService.instance.scheduleStreakReminder(
        currentStreak:     ap.streak.currentStreak,
        hasWorkedOutToday: ap.todayPlan.isCompleted,
        userName: ap.profile.name.isEmpty ? 'Champion' : ap.profile.name,
      );
    } else {
      NotificationService.instance.cancelStreakReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<GamificationProvider, _MissionsData>(
      selector: (_, gp) => _MissionsData(
        missions: gp.missions,
        completed: gp.completedMissions,
        total: gp.totalMissions,
        allDone: gp.allMissionsComplete,
      ),
      shouldRebuild: (a, b) =>
          a.completed != b.completed ||
          a.total != b.total ||
          a.allDone != b.allDone ||
          !identical(a.missions, b.missions),
      builder: (_, data, __) {
        return RepaintBoundary(child: _MissionsBody(data: data));
      },
    );
  }
}

@immutable
class _MissionsData {
  final List<DailyMission> missions;
  final int completed;
  final int total;
  final bool allDone;

  const _MissionsData({
    required this.missions,
    required this.completed,
    required this.total,
    required this.allDone,
  });
}

class _MissionsBody extends StatelessWidget {
  final _MissionsData data;
  const _MissionsBody({required this.data});

  static const _titleStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: data.allDone
              ? AppColors.gold.withValues(alpha: 0.38)
              : AppColors.borderSoft,
          width: 1,
        ),
        boxShadow: data.allDone
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.09),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.allDone ? Icons.check_circle_rounded : Icons.track_changes_rounded,
                color: data.allDone ? AppColors.gold : AppColors.gold,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DAILY MISSIONS', style: _titleStyle),
                    Text('Complete them all for bonus XP', style: _subStyle),
                  ],
                ),
              ),
              _MissionRingCounter(
                completed: data.completed,
                total: data.total,
                allDone: data.allDone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < data.missions.length; i++)
            _MissionRow(
              key: ValueKey(data.missions[i].id),
              mission: data.missions[i],
              delay: Duration(milliseconds: i * 55),
            ),
          if (data.allDone) ...[
            const SizedBox(height: AppSpacing.sm),
            const _AllMissionsBanner(),
          ],
        ],
      ),
    );
  }
}

class _AllMissionsBanner extends StatelessWidget {
  const _AllMissionsBanner();

  static const _text = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: 0.12),
          AppColors.gold.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
          SizedBox(width: 6),
          Text('All missions complete — elite performance.', style: _text),
        ],
      ),
    );
  }
}

class _MissionRingCounter extends StatelessWidget {
  final int completed;
  final int total;
  final bool allDone;
  const _MissionRingCounter({
    required this.completed,
    required this.total,
    required this.allDone,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completed / total : 0.0;
    final color = allDone ? AppColors.gold : AppColors.gold;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 3.5,
            backgroundColor: AppColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// XP burst — floats up from the mission row origin
// ────────────────────────────────────────────────
class _XPBurstOverlay extends StatefulWidget {
  final Offset origin;
  final int xp;
  final VoidCallback onDone;
  const _XPBurstOverlay({required this.origin, required this.xp, required this.onDone});
  @override State<_XPBurstOverlay> createState() => _XPBurstOverlayState();
}

class _XPBurstOverlayState extends State<_XPBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rise;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _rise = Tween<double>(begin: 0, end: -56).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1.0)));
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Stack(children: [
      Positioned(
        left: widget.origin.dx - 28,
        top: widget.origin.dy + _rise.value,
        child: IgnorePointer(
          child: Opacity(
            opacity: _fade.value,
            child: Material(
              type: MaterialType.transparency,
              child: Text('+${widget.xp} XP',
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    ]),
  );
}

class _MissionRow extends StatefulWidget {
  final DailyMission mission;
  final Duration delay;
  const _MissionRow({super.key, required this.mission, required this.delay});

  @override
  State<_MissionRow> createState() => _MissionRowState();
}

class _MissionRowState extends State<_MissionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final _rowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _MissionRow old) {
    super.didUpdateWidget(old);
    if (!old.mission.isCompleted && widget.mission.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _burstXP());
    }
  }

  void _burstXP() {
    final rb = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !mounted) return;
    final origin = rb.localToGlobal(Offset(rb.size.width / 2, rb.size.height / 2));
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _XPBurstOverlay(
        origin: origin,
        xp: widget.mission.xpReward,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: KeyedSubtree(
          key: _rowKey,
          child: _MissionRowContent(mission: widget.mission),
        ),
      ),
    );
  }
}

class _MissionRowContent extends StatelessWidget {
  final DailyMission mission;
  const _MissionRowContent({required this.mission});

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.gold.withValues(alpha: 0.14)
                  : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: done ? AppColors.gold : AppColors.borderSoft,
                width: 0.8,
              ),
              boxShadow: done
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: done ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: done ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                Text(
                  mission.description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              '+${mission.xpReward} XP',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal-progress stat card ──

// ════════════════════════════════════════════════
// BADGES SCROLL — shared shimmer driver
// ════════════════════════════════════════════════
class _BadgesScroll extends StatefulWidget {
  const _BadgesScroll();

  @override
  State<_BadgesScroll> createState() => _BadgesScrollState();
}

class _BadgesScrollState extends State<_BadgesScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sweep = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ensureAnimating(bool anyUnlocked) {
    if (anyUnlocked && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!anyUnlocked && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, Set<String>>(
      selector: (_, ap) => ap.streak.earnedBadges.toSet(),
      shouldRebuild: (a, b) =>
          a.length != b.length || !a.containsAll(b),
      builder: (_, earned, __) {
        _ensureAnimating(earned.isNotEmpty);
        return SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BadgeSystem.all.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final badge = BadgeSystem.all[i];
              final unlocked = earned.contains(badge.id);
              return _BadgeTile(
                key: ValueKey(badge.id),
                badge: badge,
                unlocked: unlocked,
                sweep: unlocked ? _sweep : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AppBadge badge;
  final bool unlocked;
  final Animation<double>? sweep;
  const _BadgeTile({
    super.key,
    required this.badge,
    required this.unlocked,
    required this.sweep,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: unlocked
                      ? AppColors.gold.withValues(alpha: 0.08)
                      : const Color(0xFF080808),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: unlocked
                        ? AppColors.gold.withValues(alpha: 0.25)
                        : AppColors.borderSoft.withValues(alpha: 0.40),
                    width: 0.5,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    unlocked
                        ? Text(badge.emoji, style: const TextStyle(fontSize: 28))
                        : Icon(Icons.lock_outline_rounded,
                            color: AppColors.textMuted.withValues(alpha: 0.35),
                            size: 18),
                    if (unlocked && sweep != null)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: sweep!,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(sweep!.value * 74, 0),
                            child: const _BadgeShimmerBand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              badge.title,
              style: TextStyle(
                fontFamily: 'Inter',
                color: unlocked
                    ? AppColors.gold
                    : AppColors.textMuted.withValues(alpha: 0.45),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeShimmerBand extends StatelessWidget {
  const _BadgeShimmerBand();

  static const _gradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x17FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: _gradient),
    );
  }
}

// ════════════════════════════════════════════════
// COMEBACK CEREMONY GATE — Phase A2
// Zero-height trigger widget. Lives in _FullDashboard
// sliver list. Shows comeback sheet once per return.
// ════════════════════════════════════════════════
class _ComebackCeremonyGate extends StatefulWidget {
  const _ComebackCeremonyGate();
  @override
  State<_ComebackCeremonyGate> createState() => _ComebackCeremonyGateState();
}

class _ComebackCeremonyGateState extends State<_ComebackCeremonyGate> {
  static const _kPrefsKey = 'comeback_ceremony_shown_for';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final ap = context.read<AppProvider>();
    if (!ap.showComebackBanner) return;

    final lastDate = ap.lastWorkoutDateStr;
    if (lastDate.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shown  = prefs.getString(_kPrefsKey);
      if (shown == lastDate) return; // already shown for this comeback

      if (!mounted) return;
      await prefs.setString(_kPrefsKey, lastDate);
    } catch (_) {
      return; // prefs unavailable — skip ceremony rather than crash
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor:    Colors.black.withValues(alpha: 0.65),
      builder: (_) => _ComebackCeremonySheet(
        daysSince: ap.daysSinceLastWorkout,
        userName:  ap.user.name,
        hasRecoverySession: ap.recoverySuggestion.shouldSuggestAlternative,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ════════════════════════════════════════════════
// COMEBACK CEREMONY SHEET — Phase A2
// Warm, atmospheric, non-guilt-tripping.
// ════════════════════════════════════════════════
class _ComebackCeremonySheet extends StatelessWidget {
  final int    daysSince;
  final String userName;
  final bool   hasRecoverySession;

  const _ComebackCeremonySheet({
    required this.daysSince,
    required this.userName,
    required this.hasRecoverySession,
  });

  String get _headline {
    if (daysSince >= 14) return 'Long time no see.';
    if (daysSince >= 7)  return 'You\'re back.';
    return 'Welcome back.';
  }

  String get _subline {
    if (daysSince >= 14) return '$daysSince days away. That\'s okay — today counts.';
    if (daysSince >= 7)  return 'A week off. Now let\'s rebuild.';
    return '$daysSince days since your last session. Ready when you are.';
  }

  String get _message {
    if (daysSince >= 14) {
      return 'Every athlete takes breaks. The ones who build lasting fitness '
             'are the ones who come back. That\'s you — right now.';
    }
    if (daysSince >= 7) {
      return 'A week of rest is sometimes exactly what the body needs. '
             'Your muscles are recovered. Your plan is ready. '
             'Today\'s session doesn\'t need to be your best — it just needs to happen.';
    }
    return 'Life gets busy. What matters is that you\'re here. '
           'A controlled session today rebuilds your rhythm faster than you think.';
  }

  @override
  Widget build(BuildContext context) {
    final name = userName.isEmpty ? 'Champion' : userName;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.06),
              blurRadius: 40, spreadRadius: 2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──────────────────────────────────────
            Center(
              child: Container(
                width: 36, height: 3.5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // ── Icon + label row ──────────────────────────────────
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_fire_department_rounded,
                    color: AppColors.gold.withValues(alpha: 0.85), size: 18),
              ),
              const SizedBox(width: 10),
              Text('COMEBACK SESSION',
                  style: GoogleFonts.inter(
                      color: AppColors.gold.withValues(alpha: 0.70),
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
            ]),

            const SizedBox(height: 16),

            // ── Headline ──────────────────────────────────────────
            Text(_headline,
                style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 28, fontWeight: FontWeight.w800, height: 1.05)),

            const SizedBox(height: 4),

            // ── Name + days subline ───────────────────────────────
            Text('$name — $_subline',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14, fontWeight: FontWeight.w400, height: 1.45)),

            const SizedBox(height: 16),

            // ── Separator ─────────────────────────────────────────
            Container(
              height: 0.5,
              color: AppColors.borderSoft.withValues(alpha: 0.20)),

            const SizedBox(height: 16),

            // ── Body message ──────────────────────────────────────
            Text(_message,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.80),
                    fontSize: 15, fontWeight: FontWeight.w400, height: 1.6)),

            // ── Recovery session note (if active) ─────────────────
            if (hasRecoverySession) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.15), width: 0.6),
                ),
                child: Row(children: [
                  Icon(Icons.bolt_rounded,
                      color: AppColors.gold.withValues(alpha: 0.70), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A lighter recovery session has been prepared for today in your Planner.',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 13, fontWeight: FontWeight.w400,
                          height: 1.45)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 22),

            // ── CTA ───────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: AppGradients.gold,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.22),
                      blurRadius: 18, offset: const Offset(0, 4))],
                ),
                child: Text("Start session →",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(
                        color: Colors.black,
                        fontSize: 17, fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PERFORMANCE SECTION — Weekly Progress + Athlete Brain merged
// ════════════════════════════════════════════════
class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekly progress dots (no container shell)
          const _WeeklyProgressStrip(showContainer: false),
          // Story CTA — handles its own visibility
          const _WeeklyStoryCTA(),
          // Divider
          Container(height: 0.5, color: AppColors.borderSoft),
          // Brain section — gold left accent + subtle dark surface
          Selector<AppProvider, int>(
            selector: (_, ap) => ap.totalWorkouts,
            builder: (_, totalWorkouts, __) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border(
                  left: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
              ),
              child: totalWorkouts >= 5
                  ? const AthleteBrainBody()
                  : _BrainLockedTeaser(totalWorkouts: totalWorkouts),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// BRAIN LOCKED TEASER — content-only (no container)
// Used inside _PerformanceSection which provides the shared shell.
// ════════════════════════════════════════════════
class _BrainLockedTeaser extends StatelessWidget {
  final int totalWorkouts;
  const _BrainLockedTeaser({required this.totalWorkouts});

  @override
  Widget build(BuildContext context) {
    final remaining = 5 - totalWorkouts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 18,
              color: AppColors.goldSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Athlete Brain',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$remaining session${remaining == 1 ? '' : 's'} until personalized analysis',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textMuted.withValues(alpha: 0.50),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(5, (i) => Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < totalWorkouts
                    ? AppColors.gold
                    : AppColors.gold.withValues(alpha: 0.12),
              ),
            )),
          ),
        ],
      ),
    );
  }
}


// ════════════════════════════════════════════════
// WEEKLY STORY CTA — earned weekly reward
// Visibility: Sat (if workout done) + Sun (always).
// After viewed: muted confirmation, resets on new week.
// ════════════════════════════════════════════════
class _WeeklyStoryCTA extends StatelessWidget {
  const _WeeklyStoryCTA();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({int weekday, bool todayDone, bool storyViewed, bool hasData, bool canShowWeeklyStory})>(
      selector: (_, ap) => (
        weekday:           DateTime.now().weekday,
        todayDone:         ap.todayPlan.isCompleted,
        storyViewed:       ap.weeklyStoryViewedThisWeek,
        hasData:           ap.weeklyReview.hasData,
        canShowWeeklyStory: ap.aiMaturity.allowedClaims.ui.canShowWeeklyStory,
      ),
      builder: (_, d, __) {
        if (!d.canShowWeeklyStory) return const SizedBox.shrink();
        if (!d.hasData) return const SizedBox.shrink();

        final visible = d.weekday == 7 || (d.weekday == 6 && d.todayDone);
        if (!visible) return const SizedBox.shrink();

        if (d.storyViewed) return const _StoryViewedLabel();
        return const _StoryInviteButton();
      },
    );
  }
}

class _StoryViewedLabel extends StatelessWidget {
  const _StoryViewedLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 36,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded,
                  size: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.30)),
              const SizedBox(width: 5),
              Text(
                'Weekly Story Viewed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.30),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryInviteButton extends StatefulWidget {
  const _StoryInviteButton();
  @override
  State<_StoryInviteButton> createState() => _StoryInviteButtonState();
}

class _StoryInviteButtonState extends State<_StoryInviteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scheduleShimmer();
  }

  void _scheduleShimmer() {
    Future.delayed(const Duration(seconds: 9), () {
      if (!mounted) return;
      _shimmer.forward(from: 0).then((_) {
        if (mounted) _scheduleShimmer();
      });
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          final ap = context.read<AppProvider>();
          ap.markWeeklyStoryViewed();
          openWeeklyStory(context);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 40,
          child: Center(
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (_, __) {
                final v = _shimmer.value;
                final sparkleAlpha = v < 0.5
                    ? (v * 2.0).clamp(0.0, 1.0)
                    : ((1.0 - v) * 2.0).clamp(0.0, 1.0);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✦',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.gold.withValues(
                          alpha: 0.45 + (sparkleAlpha * 0.40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Your Weekly Story',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.gold.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// WEEKLY PROGRESS STRIP
// ════════════════════════════════════════════════
class _WeeklyProgressStrip extends StatelessWidget {
  final bool showContainer;
  const _WeeklyProgressStrip({this.showContainer = true});

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({List<HistoryEntry> history, int planned, List<DayPlan> weekPlan})>(
      selector: (_, ap) => (
        history:  ap.history,
        planned:  ap.weekPlan.where((d) => !d.isRestDay).length,
        weekPlan: ap.weekPlan,
      ),
      builder: (_, d, __) {
        final now      = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));

        final doneSet = <int>{};
        for (final h in d.history) {
          final date = DateTime.tryParse(h.date);
          if (date == null) continue;
          final diff = DateTime(date.year, date.month, date.day)
              .difference(weekStart)
              .inDays;
          if (diff >= 0 && diff < 7) doneSet.add(diff);
        }

        // Which days are planned rest days (0=Mon … 6=Sun)
        final restSet = <int>{};
        for (int i = 0; i < d.weekPlan.length && i < 7; i++) {
          if (d.weekPlan[i].isRestDay) restSet.add(i);
        }

        final done     = doneSet.length;
        final planned  = d.planned > 0 ? d.planned : 5;
        final todayIdx = now.weekday - 1; // 0 = Monday

        final statusText = done == 0
            ? 'Week starts today'
            : done >= planned
                ? 'Week complete'
                : done == 1
                    ? '${planned - done} sessions left'
                    : done == 2
                        ? '${planned - done} sessions left'
                        : '${planned - done} session${planned - done > 1 ? "s" : ""} left';

        final inner = Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── 7 day dots ────────────────────────────────────────
                Expanded(
                  child: Row(
                    children: List.generate(7, (i) {
                      final isDone  = doneSet.contains(i);
                      final isToday = i == todayIdx;
                      final isRest  = restSet.contains(i) && !isDone;
                      final isPast  = i < todayIdx && !isDone && !isRest;

                      final Color bgColor;
                      final Color labelColor;
                      final Color dotColor;
                      final BoxBorder? border;
                      final String indicator;

                      if (isDone) {
                        bgColor    = AppColors.gold.withValues(alpha: 0.14);
                        labelColor = AppColors.gold;
                        dotColor   = AppColors.gold;
                        border     = Border.all(
                            color: AppColors.gold.withValues(alpha: 0.28), width: 0.8);
                        indicator  = 'dot';
                      } else if (isToday && isRest) {
                        bgColor    = Colors.white.withValues(alpha: 0.04);
                        labelColor = AppColors.textMuted.withValues(alpha: 0.40);
                        dotColor   = AppColors.textMuted.withValues(alpha: 0.20);
                        border     = Border.all(
                            color: Colors.white.withValues(alpha: 0.08), width: 0.8);
                        indicator  = 'dot';
                      } else if (isToday) {
                        bgColor    = Colors.white.withValues(alpha: 0.06);
                        labelColor = Colors.white;
                        dotColor   = Colors.white.withValues(alpha: 0.35);
                        border     = Border.all(
                            color: Colors.white.withValues(alpha: 0.20), width: 0.8);
                        indicator  = 'dot';
                      } else if (isRest) {
                        bgColor    = Colors.transparent;
                        labelColor = AppColors.textMuted.withValues(alpha: 0.18);
                        dotColor   = AppColors.textMuted.withValues(alpha: 0.15);
                        border     = null;
                        indicator  = 'dot';
                      } else if (isPast) {
                        bgColor    = Colors.transparent;
                        labelColor = AppColors.textMuted.withValues(alpha: 0.14);
                        dotColor   = Colors.transparent;
                        border     = null;
                        indicator  = 'none';
                      } else {
                        bgColor    = Colors.transparent;
                        labelColor = AppColors.textMuted.withValues(alpha: 0.24);
                        dotColor   = Colors.transparent;
                        border     = null;
                        indicator  = 'none';
                      }

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(7),
                            border: border,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: labelColor,
                                  fontSize: 11,
                                  fontWeight: (isDone || (isToday && !isRest))
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (indicator == 'dot')
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dotColor,
                                    boxShadow: isDone
                                        ? [BoxShadow(
                                            color: AppColors.gold.withValues(alpha: 0.50),
                                            blurRadius: 3)]
                                        : null,
                                  ),
                                )
                              else if (indicator == 'dash')
                                Container(
                                  width: 8,
                                  height: 1,
                                  color: AppColors.textMuted.withValues(alpha: 0.18),
                                )
                              else
                                const SizedBox(height: 3),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Right: count + status ─────────────────────────────
                const SizedBox(width: 10),
                Container(
                  width: 0.5,
                  height: 36,
                  color: const Color(0xFF2A2A2A),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '$done',
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            color: AppColors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: done < 3
                              ? (done == 1 ? ' workout' : ' workouts')
                              : '/$planned',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textMuted.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: done >= planned
                            ? AppColors.gold.withValues(alpha: 0.55)
                            : AppColors.textMuted.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ],
            ),
        );
        if (!showContainer) return inner;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: const Color(0xFF242424), width: 0.5),
          ),
          child: inner,
        );
      },
    );
  }
}
