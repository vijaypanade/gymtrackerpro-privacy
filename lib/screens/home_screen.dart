import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

import 'package:provider/provider.dart';
import 'premium_screen.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../utils/app_constants.dart';

import '../utils/app_routes.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/home/home_skeleton_widgets.dart';
import '../widgets/home/home_workout_widgets.dart';
import '../widgets/home/home_overlay_widgets.dart';
import '../widgets/home/ai_recovery_scan_card.dart';

import '../engines/personalization_engine.dart';
import '../engines/correlation_engine.dart';
import 'ai_chat_screen.dart';
import 'ai_setup_screen.dart';
import 'main_shell.dart';
import '../models/unified_coach_insight.dart';

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

    final bool isFirstTimeUser = context.select<AppProvider, bool>(
        (p) => p.totalWorkouts == 0 && !p.hasActivePlan);

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
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 650),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                );
              },
              child: isFirstTimeUser
                  ? const _FirstTimeUserExperience(key: ValueKey('ftue'))
                  : const _FullDashboard(key: ValueKey('dashboard')),
            ),
          ),
          const OverlayLayer(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// FIRST-TIME USER EXPERIENCE
// Focused onboarding state — no dashboard clutter.
// ════════════════════════════════════════════════
class _FirstTimeUserExperience extends StatelessWidget {
  const _FirstTimeUserExperience({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: const _NewUserHeroCard(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// FULL LUXURY DASHBOARD
// Only shown AFTER first plan creation.
// ════════════════════════════════════════════════
class _FullDashboard extends StatelessWidget {
  const _FullDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = rs(context, 20.0);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const _HomeAppBar(),
        const SliverToBoxAdapter(child: _ComebackCeremonyGate()),

        // ── 1. RECOVERY INTELLIGENCE — hero surface ───────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 8), pad, 0),
            child: const FadeSlide(delay: 0, child: _RecoveryIntelligenceCard()),
          ),
        ),

        // ── 2. AI VERDICT — bridge: analytics → coaching ──────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 16), pad, 0),
            child: const FadeSlide(delay: 40, child: _AIVerdictCard()),
          ),
        ),

        // ── 3. TODAY'S WORKOUT ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 16), pad, 0),
            child: const FadeSlide(delay: 70, child: _TrainingDecisionCard()),
          ),
        ),

        // ── 4. WEEKLY PROGRESS ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, rs(context, 16), pad, 0),
            child: const FadeSlide(delay: 110, child: _WeeklyProgressStrip()),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _NewUserHeroCard extends StatelessWidget {
  const _NewUserHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: AppBorders.glow(),
        boxShadow: AppShadows.cardGlow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gold top accent line
            Container(height: 2, color: AppColors.gold),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI coach chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.28)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.hub_rounded,
                          color: AppColors.gold, size: 9),
                      const SizedBox(width: 5),
                      Text('LIFTON AI COACH',
                          style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          )),
                    ]),
                  ),
                  const SizedBox(height: 6),

                  Selector<AppProvider, String>(
                    selector: (_, ap) => ap.profile.name,
                    builder: (_, name, __) => Text(
                      name.isEmpty
                          ? 'Ready to train?'
                          : 'Ready, ${name.split(' ').first}?',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary: AI Plan CTA (gold gradient, press animation) ────────────────────
class _PrimaryAICTA extends StatefulWidget {
  final VoidCallback onTap;
  const _PrimaryAICTA({required this.onTap});

  @override
  State<_PrimaryAICTA> createState() => _PrimaryAICTAState();
}

class _PrimaryAICTAState extends State<_PrimaryAICTA>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0.0, end: 1.4)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _pressed ? 0 : _floatAnim.value),
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: _pressed
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.22),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: Colors.black, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Build My Plan with AI',
                        style: GoogleFonts.rajdhani(
                          color: Colors.black,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        )),
                    Text('Describe your goal — plan ready in seconds',
                        style: GoogleFonts.inter(
                          color: Colors.black.withValues(alpha: 0.60),
                          fontSize: 11,
                          height: 1.3,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.black.withValues(alpha: 0.75), size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Secondary: Manual plan CTA (muted, simple) ───────────────────────────────
class _SecondaryManualCTA extends StatefulWidget {
  final VoidCallback onTap;
  const _SecondaryManualCTA({required this.onTap});

  @override
  State<_SecondaryManualCTA> createState() => _SecondaryManualCTAState();
}

class _SecondaryManualCTAState extends State<_SecondaryManualCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.22)),
          ),
          child: Row(children: [
            const Icon(Icons.tune_rounded,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Build My Own Plan',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  Text('Create custom routines & track progress',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.3,
                      )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.5), size: 12),
          ]),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      left: -60,
      right: -60,
      child: IgnorePointer(
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 0.75,
              colors: [
                AppColors.gold.withValues(alpha: 0.055),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayWorkoutSection extends StatelessWidget {
  const _TodayWorkoutSection();

  @override
  Widget build(BuildContext context) {
    final sub = context.select<AppProvider, String>((p) {
      final plan = p.todayPlan;
      return plan.isRestDay
          ? 'Recovery & rebuild day'
          : '${plan.title} • ${plan.exercises.length} exercises ready';
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderWithAction(
          title: "Today's Workout",
          sub: sub,
          action: 'Edit Plan',
          onAction: () => context
              .findAncestorStateOfType<MainShellState>()
              ?.changeTab(1),
        ),
        const SizedBox(height: 12),
        const FadeSlide(delay: 200, child: TodayWorkoutCard()),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// SECTION HEADERS
// ════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? sub;
  const _SectionHeader({required this.title, this.sub});

  @override
  Widget build(BuildContext context) =>
      _SectionHeaderBase(title: title, sub: sub);
}

class _SectionHeaderWithAction extends StatelessWidget {
  final String title;
  final String action;
  final String? sub;
  final VoidCallback onAction;
  const _SectionHeaderWithAction({
    required this.title,
    required this.action,
    required this.onAction,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => _SectionHeaderBase(
        title: title,
        sub: sub,
        action: action,
        onAction: onAction,
      );
}

class _SectionHeaderBase extends StatelessWidget {
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeaderBase({
    required this.title,
    this.sub,
    this.action,
    this.onAction,
  });

  // Editorial section label — no gold bar, depth through spacing alone.
  static const _titleStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 11,
    height: 1.3,
  );

  static const _actionStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.goldAmber,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: _titleStyle),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub!, style: _subStyle),
                ),
            ],
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(action!, style: _actionStyle),
            ),
          ),
      ],
    );
  }
}

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
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: _appBarBg.withValues(alpha: 0.72),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 0.6,
                ),
              ),
            ),
          ),
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

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, String>(
      selector: (_, ap) => ap.profile.name,
      builder: (_, name, __) {
        final first = name.isEmpty ? null : name.split(' ').first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _greeting(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
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
                      fontSize: 11,
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
  static const _streakStyle = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: AppColors.gold,
  );

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
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// XP RANK BAR
// ════════════════════════════════════════════════
// Metallic gold gradient for the rank orb — uniform across all ranks.
// Replaces the per-rank colour (purple for Gladiator, blue for Warrior, etc.)
// with a single luxury metallic finish. Stops: shadow → metal → highlight → core.
const _kRankOrbGold = LinearGradient(
  colors: [
    Color(0xFF2E1A00), // deep shadow
    Color(0xFF8B6914), // dark metal body
    Color(0xFFFFE066), // light catch (highlight peak)
    Color(0xFFD4AF37), // warm gold core
    Color(0xFFA8892C), // receding metal
    Color(0xFF2E1A00), // shadow mirror
  ],
  stops: [0.0, 0.20, 0.42, 0.60, 0.80, 1.0],
  begin: Alignment(-1.0, -1.0),
  end: Alignment(1.0, 1.0),
);
class _XPRankBar extends StatelessWidget {
  const _XPRankBar();

  @override
  Widget build(BuildContext context) {
    final ap = context.read<AppProvider>();
    return Selector<GamificationProvider, XPSystem>(
      selector: (_, gp) => gp.xp,
      shouldRebuild: (a, b) =>
          a.totalXP != b.totalXP ||
          a.weeklyXP != b.weeklyXP ||
          a.rank != b.rank ||
          a.rankProgress != b.rankProgress ||
          a.xpToNextRank != b.xpToNextRank,
      builder: (_, xp, __) => RepaintBoundary(
        child: _XPRankBarBody(
          xp:               xp,
          chronoAge:        ap.age,
          recoveryScore:    ap.getOverallRecovery(),
          readiness:        ap.weeklyReadinessScore,
          fatiguePressure:  ap.weeklyFatiguePressure,
          progressionScore: ap.weeklyProgressionScore,
          streak:           ap.streak.currentStreak,
          totalWorkouts:    ap.totalWorkouts,
        ),
      ),
    );
  }
}

class _XPRankBarBody extends StatelessWidget {
  final XPSystem xp;
  final int    chronoAge;
  final int    recoveryScore;
  final double readiness;
  final double fatiguePressure;
  final double progressionScore;
  final int    streak;
  final int    totalWorkouts;

  const _XPRankBarBody({
    required this.xp,
    required this.chronoAge,
    required this.recoveryScore,
    required this.readiness,
    required this.fatiguePressure,
    required this.progressionScore,
    required this.streak,
    required this.totalWorkouts,
  });

  // ── Performance Age model ─────────────────────────────────────────────
  // Weighted formula: each signal shifts performance age relative to
  // chronological age. Positive delta = performing younger.
  //
  // Inputs and weights:
  //   Recovery Score (0–100)     → ±4 yrs  (centred at 50)
  //   Readiness (0.0–1.0)        → ±3 yrs  (centred at 0.5)
  //   Fatigue Pressure (0.0–1.0) → 0 to -4 yrs penalty
  //   Total Workouts (0–∞)       → 0 to +3 yrs (caps at 150)
  //   Active Streak (0–∞ days)   → 0 to +2 yrs (caps at 21 days)
  //   Progression Score (0.0–1.0)→ ±1.5 yrs (centred at 0.5)
  //
  // Total range: roughly -8 to +12 years vs chronological age.
  // Clamped to (-10, +14) and smoothed to 1 decimal place.
  double _computePerformanceAge() {
    final base = chronoAge > 0 ? chronoAge.toDouble() : 28.0;

    final recoveryDelta   = (recoveryScore - 50) / 50.0 * 4.0;
    final readinessDelta  = (readiness.clamp(0.0, 1.0) - 0.5) * 6.0;
    final fatigueDelta    = fatiguePressure.clamp(0.0, 1.0) * -4.0;
    final workoutDelta    = (totalWorkouts / 150.0).clamp(0.0, 1.0) * 3.0;
    final streakDelta     = (streak / 21.0).clamp(0.0, 1.0) * 2.0;
    final progressDelta   = (progressionScore.clamp(0.0, 1.0) - 0.5) * 3.0;

    final totalDelta = recoveryDelta + readinessDelta + fatigueDelta +
                       workoutDelta + streakDelta + progressDelta;

    final clamped = totalDelta.clamp(-10.0, 14.0);
    final raw = base - clamped;
    return (raw * 10).round() / 10.0;
  }

  String _topPercent(UserRank rank) {
    switch (rank) {
      case UserRank.recruit:   return 'Top 85% of Users';
      case UserRank.warrior:   return 'Top 65% of Users';
      case UserRank.gladiator: return 'Top 45% of Users';
      case UserRank.champion:  return 'Top 25% of Users';
      case UserRank.legend:    return 'Top 8% of Users';
      case UserRank.beast:     return 'Top 2% of Users';
    }
  }

  String _fmtXp(int xpVal) =>
      xpVal >= 1000 ? '${(xpVal / 1000).toStringAsFixed(1)}k' : '$xpVal';

  int _tierLevel(UserRank rank) {
    switch (rank) {
      case UserRank.recruit:   return 1;
      case UserRank.warrior:   return 2;
      case UserRank.gladiator: return 4;
      case UserRank.champion:  return 6;
      case UserRank.legend:    return 8;
      case UserRank.beast:     return 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfAge = _computePerformanceAge();
    final base    = chronoAge > 0 ? chronoAge.toDouble() : 28.0;
    final delta   = base - perfAge;
    final absYrs  = delta.abs().toStringAsFixed(1);
    final perfAgeStr = perfAge.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Rank identity ─────────────────────────────────────────
          Text(
            xp.rank.displayName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.goldAmber,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: 4.0,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 0.5, color: const Color(0xFF1C1C1C)),
          const SizedBox(height: 18),
          // ── Performance Age ───────────────────────────────────────
          Text(
            'Performance Age',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$perfAgeStr yrs',
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textSecondary,
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            delta >= 0
                ? 'Performing $absYrs years younger'
                : 'Performing $absYrs years older',
            style: TextStyle(
              fontFamily: 'Inter',
              color: delta >= 0
                  ? AppColors.green.withValues(alpha: 0.65)
                  : AppColors.orange.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 0.5, color: const Color(0xFF1C1C1C)),
          const SizedBox(height: 16),
          // ── Social proof + XP ─────────────────────────────────────
          Text(
            _topPercent(xp.rank),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_fmtXp(xp.totalXP)} XP Earned',
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 0.5, color: const Color(0xFF1C1C1C)),
          const SizedBox(height: 14),
          // ── Tier label ────────────────────────────────────────────
          Text(
            'Level ${_tierLevel(xp.rank)} Performance Tier',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _XPNextGoalTease extends StatelessWidget {
  final int xpToNext;
  final String nextRankName;
  final String nextRankEmoji;
  const _XPNextGoalTease({
    required this.xpToNext,
    required this.nextRankName,
    required this.nextRankEmoji,
  });

  static const _goldText = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.03),
            AppColors.gold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.gold,
              size: 10,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$xpToNext XP until $nextRankName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _goldText.copyWith(
                fontSize: 10.5,
                color: AppColors.textSecondary
                    .withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            nextRankEmoji,
            style: TextStyle(fontSize: 13),
          ),
        ],
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

class _XPPill extends StatelessWidget {
  final int xp;
  const _XPPill({required this.xp});

  static const _pillStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 9,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: 0.18),
          AppColors.gold.withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text('$xp XP', style: _pillStyle),
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
// TREND SPARKLINE — 5-point mini chart
// Derives synthetic history from current score + trend direction.
// ════════════════════════════════════════════════
class _TrendSparkline extends StatelessWidget {
  const _TrendSparkline({
    required this.recovery,
    required this.trendDelta,
    required this.color,
  });

  final int    recovery;
  final int    trendDelta;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 12,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: _buildPoints(),
          color: color,
        ),
      ),
    );
  }

  List<double> _buildPoints() {
    // Reconstruct a plausible 5-day arc ending at today's recovery score.
    // trendDelta >0 = improving (points rise), <0 = declining (points fall).
    final today = recovery.toDouble().clamp(0.0, 100.0);
    final step  = trendDelta.clamp(-12, 12) * 0.22; // daily change rate
    // small sinusoidal noise for natural look
    final noise = [1.5, -1.0, 2.0, -0.5, 0.0];
    return List.generate(5, (i) {
      final base = today - step * (4 - i);
      return (base + noise[i]).clamp(0.0, 100.0);
    });
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color        color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, 100.0);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = size.height - ((points[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Draw dot at last point (today)
    final lastX = size.width;
    final lastY = size.height - ((points.last - minV) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

// ════════════════════════════════════════════════
// RECOVERY RING PAINTER
// ════════════════════════════════════════════════
class _RecoveryRingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color  ringColor;
  const _RecoveryRingPainter({required this.progress, required this.ringColor});

  static const double _strokeWidth = 11.0;
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
          double sleepHours, int todaySteps})>(
      selector: (_, ap) => (
        overall:    ap.getOverallRecovery(),
        muscles:    ap.muscleRecoveryList,
        readiness:  ap.weeklyReadinessScore,
        sleepHours: ap.coachSleepHours,
        todaySteps: ap.healthTodaySteps,
      ),
      builder: (ctx, d, __) {
        if (d.muscles.isEmpty) return const SizedBox.shrink();

        final sorted = [...d.muscles]
          ..sort((a, b) => a.recoveryScore.compareTo(b.recoveryScore));
        final weakest  = sorted.first;
        final strongest = sorted.last;
        final allBalanced = weakest.recoveryScore >= 90;
        final trendDelta = ((d.readiness * 100 - d.overall) * 0.14).round().clamp(-12, 12);

        final recoveryColor = d.overall >= 80
            ? AppColors.green
            : d.overall >= 50
                ? AppColors.orange
                : AppColors.red;

        final statusLabel = d.overall >= 80
            ? 'Ready'
            : d.overall >= 50
                ? 'Adapting'
                : 'Under-recovered';

        final trendLabel = trendDelta > 2
            ? 'Improving'
            : trendDelta < -2
                ? 'Declining'
                : 'Stable';
        final trendColor = trendDelta > 2
            ? AppColors.green
            : trendDelta < -2
                ? AppColors.red
                : AppColors.orange;

        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); _openScan(ctx); },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ring (left) · Status info (right) ────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Recovery ring — atmospheric glow + dominant number
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: recoveryColor.withValues(alpha: 0.22),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _RecoveryRingPainter(
                          progress:  d.overall / 100.0,
                          ringColor: recoveryColor,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${d.overall}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textPrimary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: recoveryColor.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '%',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted.withValues(alpha: 0.60),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Status info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status chip only — no section label needed
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: recoveryColor.withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: recoveryColor.withValues(alpha: 0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 7),
                          // Primary status — hero headline of the card
                          Text(
                            allBalanced
                                ? 'All muscles ready'
                                : '${_abbr(weakest.muscle)} · ${weakest.recoveryScore >= 70 ? "Recovering" : "Needs rest"}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: allBalanced
                                  ? AppColors.green
                                  : weakest.recoveryScore < 50
                                      ? AppColors.red
                                      : weakest.recoveryScore < 70
                                          ? AppColors.orange
                                          : AppColors.textSecondary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Trend + prime muscle — consistent treatment
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
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (strongest.recoveryScore >= 80
                                        ? AppColors.green
                                        : AppColors.goldAmber)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            Text(
                              '${_abbr(strongest.muscle)} primed',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: (strongest.recoveryScore >= 80
                                        ? AppColors.green
                                        : AppColors.goldAmber)
                                    .withValues(alpha: 0.72),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                // ── Muscle bars: only when muscles differ ─────────────
                if (!allBalanced) ...[
                  const SizedBox(height: 9),
                  Container(height: 0.5, color: AppColors.borderSoft),
                  const SizedBox(height: 8),
                  ...sorted.take(3).map(
                    (m) => _RecoveryMuscleBar(
                        label: _abbr(m.muscle), score: m.recoveryScore),
                  ),
                ],
                // ── Health Connect signals ────────────────────────────
                if (d.sleepHours > 0 || d.todaySteps > 0) ...[
                  const SizedBox(height: 9),
                  Container(height: 0.5, color: AppColors.borderSoft),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (d.sleepHours > 0) ...[
                        const Icon(Icons.bedtime_rounded,
                            size: 11,
                            color: Color(0xFF9B8DC4)),
                        const SizedBox(width: 4),
                        Text(
                          '${d.sleepHours.toStringAsFixed(1)}h sleep',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF9B8DC4),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (d.sleepHours > 0 && d.todaySteps > 0)
                        Container(
                          width: 3, height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textMuted,
                          ),
                        ),
                      if (d.todaySteps > 0) ...[
                        const Icon(Icons.directions_walk_rounded,
                            size: 11,
                            color: AppColors.goldAmber),
                        const SizedBox(width: 4),
                        Text(
                          d.todaySteps >= 1000
                              ? '${(d.todaySteps / 1000).toStringAsFixed(1)}k steps'
                              : '${d.todaySteps} steps',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.goldAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _suggestedAction(String muscle, int score) {
    final cap = muscle.isEmpty
        ? 'Muscle'
        : '${muscle[0].toUpperCase()}${muscle.substring(1)}';

    if (score >= 80) return 'Primed for stimulus';

    // Fix 5: graduated, coach-like language — less alarming, more advisory
    if (score >= 65) {
      switch (muscle.toLowerCase()) {
        case 'chest':     return 'Ease off pressing today';
        case 'back':      return 'Ease off heavy rows';
        case 'legs':      return 'Lighter leg work today';
        case 'shoulders': return 'Ease off overhead work';
        case 'biceps':    return 'Light arm work only';
        case 'triceps':   return 'Ease off triceps today';
        case 'core':      return 'Light core only';
        default: return 'Ease off $cap today';
      }
    }

    // Fix 4: muscle-specific recovery message with time estimate
    final recHrs = ((100 - score) * 0.28).toInt().clamp(8, 48);
    return '$cap recovering  •  ~${recHrs}h remaining';
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
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.60,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C0C0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
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
// TODAY'S WORKOUT CARD
// Workout name + state. Tap → Planner.
// Clean. No coaching. No repetition.
// ════════════════════════════════════════════════
class _TrainingDecisionCard extends StatelessWidget {
  const _TrainingDecisionCard();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({
      String trainMuscle,
      String planTitle,
      int    exerciseCount,
      bool   isCompleted,
      bool   isRestDay,
      int    recovery,
      double totalVolume,
    })>(
      selector: (_, ap) {
        final plan = ap.todayPlan;
        return (
          trainMuscle:   ap.topMuscleGroup,
          planTitle:     plan.title,
          exerciseCount: plan.exercises.length,
          isCompleted:   plan.isCompleted,
          isRestDay:     plan.isRestDay,
          recovery:      ap.getOverallRecovery(),
          totalVolume:   plan.exercises
              .expand((e) => e.sets)
              .where((s) => s.done && s.weight > 0 && s.reps > 0)
              .fold(0.0, (v, s) => v + s.weight * s.reps),
        );
      },
      builder: (ctx, d, __) {
        // Determine state label and primary text
        final String stateLabel;
        final String primaryText;
        final Color  primaryColor;
        final bool   showChevron = true;

        if (d.isCompleted) {
          stateLabel  = 'Today';
          primaryText = d.planTitle.isNotEmpty ? d.planTitle : 'Session done';
          primaryColor = AppColors.textSecondary;
        } else if (d.isRestDay) {
          stateLabel  = 'Today';
          primaryText = 'Rest day';
          primaryColor = AppColors.textSecondary;
        } else {
          stateLabel  = 'Today';
          primaryText = d.planTitle.isNotEmpty
              ? d.planTitle
              : d.trainMuscle.isNotEmpty
                  ? '${d.trainMuscle[0].toUpperCase()}${d.trainMuscle.substring(1)} Training'
                  : 'Training Session';
          primaryColor = AppColors.textPrimary;
        }

        // Dynamic chevron color — instant readiness signal
        final chevronColor = d.recovery <= 20
            ? const Color(0xFFEF5350)          // deep red — heavy fatigue (muted)
            : d.recovery <= 40
                ? AppColors.red                // orange-red
                : d.recovery <= 70
                    ? AppColors.orange         // orange — recovering
                    : d.recovery <= 85
                        ? AppColors.goldAmber  // gold — moderate/ready
                        : AppColors.green;     // green — fully ready

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.findAncestorStateOfType<MainShellState>()?.changeTab(1);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── State label ──────────────────────────────
                      Text(
                        stateLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textMuted.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // ── Workout name + volume (if completed) ─────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              primaryText,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (d.isCompleted && d.totalVolume > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              () {
                                final kg = d.totalVolume;
                                return kg >= 1000
                                    ? '${(kg / 1000).toStringAsFixed(1)}t'
                                    : '${kg.toStringAsFixed(0)}kg';
                              }(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.goldAmber.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!d.isRestDay && d.exerciseCount > 0 && !d.isCompleted) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${d.exerciseCount} exercises',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      if (d.isCompleted) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 11,
                                color: AppColors.green.withValues(alpha: 0.60)),
                            const SizedBox(width: 4),
                            Text(
                              'Session complete',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.green.withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron)
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: chevronColor.withValues(alpha: 0.75)),
              ],
            ),
          ),
        );
      },
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
    if (l.contains('chest') || l.contains('push'))
      return 'Avoid pressing movements tomorrow morning.';
    if (l.contains('back') || l.contains('pull'))
      return 'Avoid heavy rows and pulls tomorrow.';
    if (l.contains('leg') || l.contains('squat'))
      return 'Skip squats and lunges tomorrow morning.';
    if (l.contains('shoulder'))
      return 'Avoid overhead pressing tomorrow.';
    if (l.contains('arm') || l.contains('bicep') || l.contains('tricep'))
      return 'Keep direct arm work light tomorrow.';
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
    final cap      = (String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
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
          ? 'Recovery is trending up. This week\'s consistency is compounding — keep the pattern.'
          : 'You\'re building momentum. Each session this week is stacking adaptation.';
    }
    if (recovery >= 80) {
      return slot.isEven
          ? 'High readiness. If there\'s a PR to chase, today is the day to go for it.'
          : 'Body is primed. Optimal window for progressive overload — push the weight today.';
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
        if (title.isEmpty) return const SizedBox.shrink();

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
                    padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
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
                                fontSize: 10,
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
                            fontSize: 12,
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
  bool   _done = false;

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
      setState(() { _displayed = ''; _done = false; });
      _startTyping(widget.text);
    }
  }

  void _startTyping(String text) {
    int idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx >= text.length) {
        t.cancel();
        if (mounted) setState(() => _done = true);
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

class _IntelRow extends StatelessWidget {
  const _IntelRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textSecondary,
  });
  final String label;
  final String value;
  final Color  valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        ? AppColors.green
        : widget.score > 40
            ? AppColors.goldAmber
            : widget.score > 20
                ? AppColors.orange
                : AppColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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
            width: 28,
            child: Text(
              '${widget.score}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted.withValues(alpha: 0.65),
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
        if (data.total == 0 && !_initScheduled) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInit());
        }
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
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 10,
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
              ? AppColors.green.withValues(alpha: 0.38)
              : AppColors.borderSoft,
          width: 1,
        ),
        boxShadow: data.allDone
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.09),
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
                color: data.allDone ? AppColors.green : AppColors.gold,
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
    fontSize: 12,
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
    final color = allDone ? AppColors.green : AppColors.gold;
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
              fontSize: 11,
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
                  ? AppColors.green.withValues(alpha: 0.14)
                  : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: done ? AppColors.green : AppColors.borderSoft,
                width: 0.8,
              ),
              boxShadow: done
                  ? [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: done ? AppColors.green : AppColors.textMuted,
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
                    fontSize: 13,
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
                    fontSize: 11,
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

// ════════════════════════════════════════════════
// QUICK ACTIONS
// ════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _AIChatTile()),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _GeneratePlanTile()),
      ],
    );
  }
}

class _AIChatTile extends StatelessWidget {
  const _AIChatTile();

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      emoji: '🤖',
      iconWidget: const Icon(Icons.chat_bubble_outline_rounded,
          color: AppColors.gold, size: 22),
      label: 'AI Chat',
      value: 'Ask',
      color: AppColors.gold,
      onTap: () =>
          Navigator.push(context, slideRoute(const AIChatScreen())),
    );
  }
}

class _GeneratePlanTile extends StatelessWidget {
  const _GeneratePlanTile();

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      emoji: '⚡',
      iconWidget: const Icon(Icons.auto_fix_high_rounded,
          color: Color(0xFF888888), size: 22),
      label: 'Generate',
      value: 'Plan',
      color: const Color(0xFF888888),
      onTap: () =>
          Navigator.push(context, slideRoute(const AISetupScreen())),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Widget? valueWidget;
  final Widget? iconWidget;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.valueWidget,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return HomeTapButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
              color: color.withValues(alpha: 0.24),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.09),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Center(
                  child: iconWidget ?? Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              valueWidget ?? Text(
                value,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

// ════════════════════════════════════════════════
// STATS ROW
// ════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SessionsStat(),
        SizedBox(width: AppSpacing.md),
        _BestStreakStat(),
        SizedBox(width: AppSpacing.md),
        _WeeklyXPStat(),
      ],
    );
  }
}

class _SessionsStat extends StatelessWidget {
  const _SessionsStat();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, int>(
      selector: (_, ap) {
        // Workouts THIS week
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return ap.workout.logs
            .where((l) => l.date.isAfter(cutoff))
            .map((l) => l.date.day)
            .toSet()
            .length;
      },
      builder: (_, v, __) => _GoalStat(
        emoji: '🏋️',
        icon: Icons.fitness_center_rounded,
        value: '$v',
        goal: 4,
        current: v,
        label: 'This Week',
        sublabel: v >= 4 ? 'Goal hit!' : '${4 - v} to go',
        color: AppColors.gold,
      ),
    );
  }
}

class _BestStreakStat extends StatelessWidget {
  const _BestStreakStat();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({int current, int best})>(
      selector: (_, ap) => (
        current: ap.streak.currentStreak,
        best: ap.streak.longestStreak,
      ),
      builder: (_, v, __) => _GoalStat(
        emoji: '🔥',
        icon: Icons.local_fire_department_rounded,
        value: '${v.current}d',
        goal: v.best > 0 ? v.best : 7,
        current: v.current,
        label: 'Streak',
        sublabel: v.best > 0 ? 'Best: ${v.best}d' : 'Day 1!',
        color: AppColors.gold,
      ),
    );
  }
}

class _WeeklyXPStat extends StatelessWidget {
  const _WeeklyXPStat();

  @override
  Widget build(BuildContext context) {
    return Selector<GamificationProvider, int>(
      selector: (_, gp) => gp.xp.weeklyXP,
      builder: (_, v, __) => _GoalStat(
        emoji: '⚡',
        icon: Icons.bolt_rounded,
        value: '$v',
        goal: 500,
        current: v,
        label: 'XP / Week',
        sublabel: v >= 500 ? 'Crushed it!' : '${500 - v} to go',
        color: const Color(0xFFBF8000),
        barGradient: const LinearGradient(
          colors: [Color(0xFF4A2E00), Color(0xFFBF8000), Color(0xFFD4AF37)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

// ── Goal-progress stat card ──
class _GoalStat extends StatelessWidget {
  final String emoji;
  final IconData? icon;
  final String value;
  final int goal;
  final int current;
  final String label;
  final String sublabel;
  final Color color;
  // When provided, the progress bar renders as a gradient fill instead of
  // a flat colour. Used by XP/Week to avoid the purple LinearProgressIndicator.
  final LinearGradient? barGradient;

  const _GoalStat({
    required this.emoji,
    required this.value,
    required this.goal,
    required this.current,
    required this.label,
    required this.sublabel,
    required this.color,
    this.icon,
    this.barGradient,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.22),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withValues(alpha: 0.18), width: 0.5),
                  ),
                  child: Icon(icon, color: color, size: 15),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Text(value,
                  style: GoogleFonts.rajdhani(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  )),
            ]),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 6),
            // Progress bar — gradient fill when barGradient is supplied,
            // otherwise falls back to the flat accent colour.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: barGradient != null
                  ? LayoutBuilder(builder: (_, box) {
                      final w = box.maxWidth;
                      return Stack(children: [
                        Container(height: 4, color: AppColors.bgElevated),
                        if (w > 0 && pct > 0)
                          Container(
                            height: 4,
                            width: w * pct,
                            decoration: BoxDecoration(gradient: barGradient),
                          ),
                      ]);
                    })
                  : LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: AppColors.bgElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
            ),
            const SizedBox(height: 5),
            Text(sublabel,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;
  const _ImpactStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: color.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// WEEKLY PERFORMANCE REPORT CARD
// Narrative performance summary using existing analytics data.
// ════════════════════════════════════════════════
class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({int sessions, double volumeKg, double pct, String top, String trend,
          String? nextPhase, String? bestExercise})>(
      selector: (_, ap) {
        final mem = ap.lastWeekMemory;
        final best = mem != null && mem.topExercises.isNotEmpty
            ? mem.topExercises.first.name
            : null;
        return (
          sessions:    ap.weeklyCompletedDays,
          volumeKg:    ap.weeklyVolumeTotalKg,
          pct:         ap.weeklyImprovementPercent,
          top:         ap.topMuscleGroup,
          trend:       ap.recoveryTrend,
          nextPhase:   mem?.nextPhase,
          bestExercise: best,
        );
      },
      builder: (_, d, __) {
        if (d.sessions == 0) return const SizedBox.shrink();

        final narrative = _buildNarrative(d.sessions, d.volumeKg, d.pct, d.top);
        final (trendIcon, trendColor) = switch (d.trend) {
          'improving' => (Icons.trending_up_rounded,   const Color(0xFF4CAF50)),
          'declining' => (Icons.trending_down_rounded, const Color(0xFFEF5350)),
          _           => (Icons.trending_flat_rounded, const Color(0xFFFF9800)),
        };

        final nextPhaseLabel = switch (d.nextPhase) {
          'peak'   => 'Peak phase conditions approaching.',
          'deload' => 'Recovery week recommended ahead.',
          'base'   => 'Base building phase — consistency is the driver.',
          _        => null,
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text('THIS WEEK',
                      style: GoogleFonts.inter(
                          color: AppColors.gold, fontSize: 9.5,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const Spacer(),
                  Icon(trendIcon, color: trendColor, size: 13),
                  const SizedBox(width: 3),
                  Text(
                      switch (d.trend) {
                        'declining' => 'reduced',
                        _ => d.trend,
                      },
                      style: GoogleFonts.inter(
                          color: trendColor, fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Text(narrative,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w500, height: 1.4)),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  _MiniStat('${d.sessions}', 'sessions'),
                  const SizedBox(width: AppSpacing.sm),
                  if (d.volumeKg > 0) ...[
                    _MiniStat(
                        '${(d.volumeKg / 1000).toStringAsFixed(1)}t', 'volume'),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (d.top.isNotEmpty && d.top != 'None')
                    _MiniStat(d.top, 'focus'),
                ]),
                // ── Next-phase hint (from WeeklyMemory heuristic) ──
                if (nextPhaseLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.textMuted, size: 10),
                    const SizedBox(width: 4),
                    Text(nextPhaseLabel,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 10,
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildNarrative(
      int sessions, double volumeKg, double pct, String top) {
    final volStr = volumeKg >= 1000
        ? '${(volumeKg / 1000).toStringAsFixed(1)}t'
        : '${volumeKg.toStringAsFixed(0)}kg';

    if (sessions >= 5) {
      return 'Elite week. $sessions sessions, $volStr lifted.'
          '${pct >= 10 ? " Volume up ${pct.toStringAsFixed(0)}%." : ""}';
    }
    if (sessions >= 3) {
      final extra = pct >= 10
          ? ' Volume up ${pct.toStringAsFixed(0)}% from last week.'
          : pct <= -10
              ? ' Volume down — recovery week.'
              : '';
      return '$sessions sessions, $volStr lifted.$extra';
    }
    if (sessions == 2) {
      return '2 sessions this week. '
          '${pct >= 5 ? "Trending up." : "Stay consistent — aim for 4."}';
    }
    return '1 session logged. '
        'Keep the momentum — consistency beats intensity.';
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.bgCardLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 13,
          fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 9,
          fontWeight: FontWeight.w500)),
    ]),
  );
}

// ════════════════════════════════════════════════
// MUSCLE RECOVERY STRIP
// Surfaces per-muscle recovery status using existing
// MuscleRecovery data. Hides when all muscles are ready.
// ════════════════════════════════════════════════
class _MuscleRecoveryStrip extends StatelessWidget {
  const _MuscleRecoveryStrip();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<MuscleRecovery>>(
      selector: (_, ap) => ap.muscleRecoveryList,
      builder: (_, muscles, __) {
        final active = muscles
            .where((m) => m.lastTrainedDate.isNotEmpty && m.recoveryScore < 85)
            .toList()
          ..sort((a, b) => a.recoveryScore.compareTo(b.recoveryScore));
        if (active.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.monitor_heart_rounded,
                    color: AppColors.gold, size: 12),
                const SizedBox(width: 5),
                Text('RECOVERY STATUS',
                    style: GoogleFonts.inter(
                        color: AppColors.gold, fontSize: 9.5,
                        fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 7),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: active.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => _RecoveryChip(active[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _RecoveryChip extends StatelessWidget {
  final MuscleRecovery m;
  const _RecoveryChip(this.m);

  @override
  Widget build(BuildContext context) {
    final color = m.recoveryScore >= 70
        ? AppColors.green
        : m.recoveryScore >= 45
            ? AppColors.orange
            : AppColors.red;

    final label = m.muscle[0].toUpperCase() + m.muscle.substring(1);
    final statusText = m.recoveryScore >= 80
        ? 'Primed'
        : m.recoveryScore >= 50
            ? 'Adapting'
            : 'Under-recovered';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(statusText,
            style: GoogleFonts.inter(
                color: color, fontSize: 9.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// PERSONALIZATION INSIGHT CARD
// Surfaces behavioral insights from PersonalizationEngine
// and CorrelationEngine. Rotates daily — never spammy.
// ════════════════════════════════════════════════
class _PersonalizationInsightCard extends StatelessWidget {
  const _PersonalizationInsightCard();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider,
        ({List logs, int readiness, double volKg, double pct, String top})>(
      selector: (_, ap) => (
        logs:      ap.logs,
        readiness: ap.todayReadiness,
        volKg:     ap.weeklyVolumeTotalKg,
        pct:       ap.weeklyImprovementPercent,
        top:       ap.topMuscleGroup,
      ),
      builder: (_, d, __) {
        // Personalization insight
        final personal = PersonalizationEngine.getAdaptiveInsight(
          logs:                 List.from(d.logs),
          readiness:            d.readiness,
          weeklyImprovementPct: d.pct,
          topMuscle:            d.top == 'None' ? '' : d.top,
        );

        // Correlation insight
        final correlation = CorrelationEngine.getMainInsight(
          logs:             List.from(d.logs),
          currentReadiness: d.readiness,
          weeklyVolumeKg:   d.volKg,
        );

        final insight = personal.isNotEmpty ? personal : correlation;
        if (insight == null || insight.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05), width: 0.7),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                    child: Icon(Icons.hub_rounded,
                        color: AppColors.gold, size: 13)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(insight,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12, fontWeight: FontWeight.w500,
                      height: 1.4))),
            ]),
          ),
        );
      },
    );
  }
}

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

void _showAIPlanSheet(BuildContext context, String planText) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgModal,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // ── Drag handle ──
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 44,
                height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: AppColors.gold, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your AI Plan',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),

          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text(
                planText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // ── Fixed bottom button with SafeArea ──
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgModal,
              border: Border(
                top: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ap = context.read<AppProvider>();
                      Navigator.pop(sheetContext);
                      
                      // Show loading
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Applying AI plan...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                      
                      final result = await ap.getAIWorkoutPlan();
                      if (result.isNotEmpty && context.mounted) {
                        await ap.applyAIWorkout(result);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Plan applied to Planner'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Apply This Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
                      fontSize: 9.5, fontWeight: FontWeight.w700,
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
                    fontSize: 13, fontWeight: FontWeight.w400, height: 1.45)),

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
                    fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.6)),

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
                          fontSize: 11.5, fontWeight: FontWeight.w400,
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
                child: Text("Let's go →",
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
// WEEKLY PROGRESS STRIP
// ════════════════════════════════════════════════
class _WeeklyProgressStrip extends StatelessWidget {
  const _WeeklyProgressStrip();

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
            ? 'Start the week strong'
            : done >= planned
                ? 'Week complete · elite consistency'
                : '${planned - done} session${planned - done > 1 ? "s" : ""} to go';

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'This week',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textMuted.withValues(alpha: 0.50),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: '$done',
                        style: const TextStyle(
                          fontFamily: 'Rajdhani',
                          color: AppColors.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' of $planned',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textMuted.withValues(alpha: 0.50),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── 7 day segment blocks ─────────────────────────────────
              Row(
                children: List.generate(7, (i) {
                  final isDone  = doneSet.contains(i);
                  final isToday = i == todayIdx;
                  final isRest  = restSet.contains(i) && !isDone;
                  final isPast  = i < todayIdx && !isDone && !isRest;

                  final Color bgColor;
                  final Color labelColor;
                  final Color dotColor;
                  final BoxBorder? border;
                  final String indicator; // dot, dash, or empty

                  if (isDone) {
                    bgColor   = AppColors.gold.withValues(alpha: 0.15);
                    labelColor = AppColors.gold;
                    dotColor  = AppColors.gold;
                    border    = Border.all(
                        color: AppColors.gold.withValues(alpha: 0.30), width: 1);
                    indicator = 'dot';
                  } else if (isToday && isRest) {
                    // Today is a rest day
                    bgColor   = Colors.white.withValues(alpha: 0.04);
                    labelColor = AppColors.textMuted.withValues(alpha: 0.45);
                    dotColor  = Colors.transparent;
                    border    = Border.all(
                        color: Colors.white.withValues(alpha: 0.10), width: 1);
                    indicator = 'dash';
                  } else if (isToday) {
                    bgColor   = Colors.white.withValues(alpha: 0.06);
                    labelColor = Colors.white;
                    dotColor  = Colors.white.withValues(alpha: 0.35);
                    border    = Border.all(
                        color: Colors.white.withValues(alpha: 0.22), width: 1);
                    indicator = 'dot';
                  } else if (isRest) {
                    // Planned rest day — intentional, not a miss
                    bgColor   = Colors.transparent;
                    labelColor = AppColors.textMuted.withValues(alpha: 0.22);
                    dotColor  = Colors.transparent;
                    border    = null;
                    indicator = 'dash';
                  } else if (isPast) {
                    bgColor   = Colors.transparent;
                    labelColor = AppColors.textMuted.withValues(alpha: 0.16);
                    dotColor  = Colors.transparent;
                    border    = null;
                    indicator = 'none';
                  } else {
                    bgColor   = Colors.transparent;
                    labelColor = AppColors.textMuted.withValues(alpha: 0.28);
                    dotColor  = Colors.transparent;
                    border    = null;
                    indicator = 'none';
                  }

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 6 ? 5 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
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
                              fontSize: 10,
                              fontWeight: (isDone || (isToday && !isRest))
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (indicator == 'dot')
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                                boxShadow: isDone
                                    ? [BoxShadow(
                                        color: AppColors.gold.withValues(alpha: 0.50),
                                        blurRadius: 4)]
                                    : null,
                              ),
                            )
                          else if (indicator == 'dash')
                            Container(
                              width: 10,
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          else
                            const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              // ── Status line ──────────────────────────────────────────
              Text(
                statusText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: done >= planned
                      ? AppColors.green.withValues(alpha: 0.58)
                      : AppColors.textMuted.withValues(alpha: 0.38),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
