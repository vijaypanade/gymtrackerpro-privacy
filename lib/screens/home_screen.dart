import '../services/ad_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'premium_screen.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../utils/app_constants.dart';

import '../utils/app_routes.dart';
import '../utils/recovery_grid_data.dart';
import '../widgets/shared_widgets.dart';
import '../services/ai_engine.dart';

import '../services/monetization_service.dart'; // ✅ Paywall + Usage pill
import 'planner_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_setup_screen.dart';
import 'main_shell.dart';
import '../models/workout_log.dart';
import '../utils/recovery_ui.dart';
import '../widgets/muscle_chip.dart';

// ════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, ap) => ap.loading,
      builder: (context, loading, _) {
        if (loading) return const _HomeSkeletonScreen();
        return Scaffold(
          backgroundColor: AppColors.bg,
          bottomNavigationBar: Selector<AppProvider, bool>(
            selector: (_, ap) => ap.isPremium,
            builder: (_, isPremium, __) => isPremium
                ? const SizedBox.shrink()
                : GTPBannerAd(isPremium: isPremium),
          ),
          body: const _HomeBody(),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _AmbientGlow(),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const _HomeAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed(const [
                  _FadeSlide(delay: 0, child: _XPRankBar()),
                  SizedBox(height: AppSpacing.lg),
                  _FadeSlide(delay: 55, child: _MoodRow()),
                  SizedBox(height: AppSpacing.lg),
                  _FadeSlide(delay: 100, child: _AICoachCard()),
                  SizedBox(height: AppSpacing.lg),
                  _FadeSlide(delay: 140, child: _MissionsCard()),
                  SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                      title: 'Muscle Recovery',
                      sub: 'How your body is bouncing back'),
                  SizedBox(height: AppSpacing.md),
                  _FadeSlide(delay: 170, child: _RecoveryGrid()),
                  SizedBox(height: AppSpacing.xxl),
                  _TodayWorkoutSection(),
                  SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(title: 'Quick Actions', sub: 'One tap, done'),
                  SizedBox(height: AppSpacing.md),
                  _FadeSlide(delay: 230, child: _QuickActions()),
                  SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                      title: 'Your Progress', sub: 'Keep building momentum'),
                  SizedBox(height: AppSpacing.md),
                  _FadeSlide(delay: 255, child: _StatsRow()),
                  SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(title: 'Achievements', sub: 'Every rep counts'),
                  SizedBox(height: AppSpacing.md),
                  _FadeSlide(delay: 280, child: _BadgesScroll()),
                  SizedBox(height: AppSpacing.lg),
                ]),
              ),
            ),
          ],
        ),
        const _OverlayLayer(),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderWithAction(
          title: "Today's Workout",
          sub: 'Your mission for today',
          action: 'Edit Plan',
          onAction: () => context
              .findAncestorStateOfType<MainShellState>()
              ?.changeTab(1),
        ),
        const SizedBox(height: AppSpacing.md),
        const _FadeSlide(delay: 200, child: _TodayWorkoutCard()),
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

  static const _titleStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 11,
  );

  static const _actionStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 15,
                    decoration: BoxDecoration(
                      gradient: AppGradients.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(title.toUpperCase(), style: _titleStyle),
                ],
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 2),
                  child: Text(sub!, style: _subStyle),
                ),
            ],
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Text(action!, style: _actionStyle),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// RECOVERY GRID
// ════════════════════════════════════════════════
class _RecoveryGrid extends StatelessWidget {
  const _RecoveryGrid();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _RecoveryScores>(
      selector: (_, ap) => _RecoveryScores.from(ap),
      builder: (_, scores, __) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: RecoveryGridData.muscles.length,
          gridDelegate: RecoveryGridData.gridDelegate,
          itemBuilder: (_, i) {
            final m = RecoveryGridData.muscles[i];
            return _RecoveryTile(
              muscle: m['label']!,
              emoji: m['emoji']!,
              score: scores.values[i],
              delay: Duration(milliseconds: i * 45),
            );
          },
        );
      },
    );
  }
}

@immutable
class _RecoveryScores {
  final List<int> values;
  const _RecoveryScores(this.values);

  factory _RecoveryScores.from(AppProvider ap) {
    final list = List<int>.generate(
      RecoveryGridData.muscles.length,
      (i) => ap
          .getMuscleRecovery(RecoveryGridData.muscles[i]['key']!)
          .toInt()
          .clamp(0, 100),
      growable: false,
    );
    return _RecoveryScores(list);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _RecoveryScores) return false;
    if (other.values.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] != values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);
}

class _RecoveryTile extends StatefulWidget {
  final String muscle;
  final String emoji;
  final int score;
  final Duration delay;
  const _RecoveryTile({
    required this.muscle,
    required this.score,
    required this.emoji,
    required this.delay,
  });

  @override
  State<_RecoveryTile> createState() => _RecoveryTileState();
}

class _RecoveryTileState extends State<_RecoveryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bar;

  Color get _color {
    final s = widget.score;
    if (s >= 70) return AppColors.green;
    if (s >= 40) return AppColors.yellow;
    return AppColors.red;
  }

  String get _statusLabel {
    final s = widget.score;
    if (s >= 80) return 'Ready';
    if (s >= 60) return 'Good';
    if (s >= 40) return 'Fair';
    return 'Rest';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _bar = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _RecoveryTile old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score && _ctrl.isCompleted) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final status = _statusLabel;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _bar,
        builder: (_, __) {
          final v = _bar.value;
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(
                color: color.withValues(alpha: 0.22 * v),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08 * v),
                  blurRadius: 8,
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji,
                    style: const TextStyle(fontSize: 18, height: 1.0)),
                const SizedBox(height: 2),
                Text(
                  widget.muscle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: LinearProgressIndicator(
                    value: (widget.score / 100) * v,
                    minHeight: 3,
                    backgroundColor: AppColors.bgElevated,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.score}%',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: color.withValues(alpha: 0.75),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════
// SKELETON — single shimmer driver, shared across bones
// ════════════════════════════════════════════════
class _HomeSkeletonScreen extends StatefulWidget {
  const _HomeSkeletonScreen();

  @override
  State<_HomeSkeletonScreen> createState() => _HomeSkeletonScreenState();
}

class _HomeSkeletonScreenState extends State<_HomeSkeletonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _sweep = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _SkeletonShimmer(
          sweep: _sweep,
          child: const _SkeletonLayout(),
        ),
      ),
    );
  }
}

/// Provides shimmer animation to descendants without rebuilding layout.
class _SkeletonShimmer extends InheritedWidget {
  final Animation<double> sweep;
  const _SkeletonShimmer({
    required this.sweep,
    required super.child,
  });

  static Animation<double> of(BuildContext context) {
    final w = context
        .dependOnInheritedWidgetOfExactType<_SkeletonShimmer>();
    assert(w != null, '_SkeletonShimmer ancestor not found');
    return w!.sweep;
  }

  @override
  bool updateShouldNotify(_SkeletonShimmer old) => old.sweep != sweep;
}

class _SkeletonLayout extends StatelessWidget {
  const _SkeletonLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SBone(width: 200, height: 28),
          SizedBox(height: AppSpacing.lg),
          _SBone(width: double.infinity, height: 90, r: 16),
          SizedBox(height: AppSpacing.md),
          _SBone(width: double.infinity, height: 68, r: 14),
          SizedBox(height: AppSpacing.md),
          _SBone(width: double.infinity, height: 100, r: 14),
          SizedBox(height: AppSpacing.lg),
          _SkeletonStatsRow(),
          SizedBox(height: AppSpacing.lg),
          _SkeletonGrid(),
        ],
      ),
    );
  }
}

class _SkeletonStatsRow extends StatelessWidget {
  const _SkeletonStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: _SBone(height: 72, r: 12),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: _SBone(height: 72, r: 12),
          ),
        ),
        Expanded(child: _SBone(height: 72, r: 12)),
      ],
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
      children: const [
        _SBone(height: 80, r: 12),
        _SBone(height: 80, r: 12),
        _SBone(height: 80, r: 12),
        _SBone(height: 80, r: 12),
        _SBone(height: 80, r: 12),
        _SBone(height: 80, r: 12),
      ],
    );
  }
}

class _SBone extends StatelessWidget {
  final double? width;
  final double height;
  final double r;
  const _SBone({this.width, required this.height, this.r = 8});

  @override
  Widget build(BuildContext context) {
    final sweep = _SkeletonShimmer.of(context);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              const ColoredBox(
                color: AppColors.bgCardLight,
                child: SizedBox.expand(),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: sweep,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(sweep.value * 220, 0),
                    child: const _ShimmerBand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBand extends StatelessWidget {
  const _ShimmerBand();

  static const _gradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x0DFFFFFF),
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
// OVERLAY
// ════════════════════════════════════════════════
class _OverlayLayer extends StatelessWidget {
  const _OverlayLayer();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _XPToastSlot(),
        _BadgePopupSlot(),
        _RankUpPopupSlot(),
        _StreakToastSlot(),
      ],
    );
  }
}

class _XPToastSlot extends StatelessWidget {
  const _XPToastSlot();

  @override
  Widget build(BuildContext context) {
    return Selector<GamificationProvider, ({bool show, int xp})>(
      selector: (_, gp) => (show: gp.showXPPopup, xp: gp.lastXPGained),
      builder: (_, s, __) =>
          s.show ? _XPToast(xp: s.xp) : const SizedBox.shrink(),
    );
  }
}

class _BadgePopupSlot extends StatelessWidget {
  const _BadgePopupSlot();

  @override
  Widget build(BuildContext context) {
    return Selector<GamificationProvider, ({bool show, AppBadge? badge})>(
      selector: (_, gp) =>
          (show: gp.showBadgePopup, badge: gp.lastUnlockedBadge),
      shouldRebuild: (a, b) => a.show != b.show || a.badge?.id != b.badge?.id,
      builder: (_, s, __) => (s.show && s.badge != null)
          ? _BadgePopup(badge: s.badge!)
          : const SizedBox.shrink(),
    );
  }
}

class _RankUpPopupSlot extends StatelessWidget {
  const _RankUpPopupSlot();

  @override
  Widget build(BuildContext context) {
   return Selector<GamificationProvider, ({bool show, UserRank? rank})>(
      selector: (_, gp) => (show: gp.showRankUpPopup, rank: gp.newRank),
      shouldRebuild: (a, b) => a.show != b.show || a.rank != b.rank,
      builder: (_, s, __) => (s.show && s.rank != null)
          ? _RankUpPopup(rank: s.rank!)
          : const SizedBox.shrink(),
    );
  }
}

class _StreakToastSlot extends StatelessWidget {
  const _StreakToastSlot();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({bool show, int streak})>(
      selector: (_, ap) =>
          (show: ap.showStreakPopup, streak: ap.streak.currentStreak),
      builder: (_, s, __) =>
          s.show ? _StreakToast(streak: s.streak) : const SizedBox.shrink(),
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
      backgroundColor: _appBarBg,
      elevation: 0,
      floating: true,
      snap: true,
      titleSpacing: AppSpacing.lg,
      title: const _HomeAppBarTitle(),
      actions: const [
        _AICoachAction(),
        _StreakAction(),
      ],
    );
  }
}

class _HomeAppBarTitle extends StatelessWidget {
  const _HomeAppBarTitle();

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.3,
    color: AppColors.textPrimary,
  );

  static const _betaStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 8,
    fontWeight: FontWeight.w800,
    color: AppColors.gold,
    letterSpacing: 2,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.gold,
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            size: 17,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GymTracker Pro',
                style: _titleStyle,
                overflow: TextOverflow.ellipsis,
              ),
              Text('BETA', style: _betaStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _AICoachAction extends StatelessWidget {
  const _AICoachAction();

  static const _label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.gold,
  );

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: () =>
          Navigator.push(context, slideRoute(const AIChatScreen())),
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.gold.withValues(alpha: 0.16),
            AppColors.gold.withValues(alpha: 0.07),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.38),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 13, color: AppColors.gold),
            SizedBox(width: AppSpacing.xs),
            Text('AI Coach', style: _label),
          ],
        ),
      ),
    );
  }
}

class _StreakAction extends StatelessWidget {
  const _StreakAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Selector<AppProvider, int>(
        selector: (_, ap) => ap.streak.currentStreak,
        builder: (_, streak, __) => _StreakBadge(streak: streak),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  static const _streakStyle = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: AppColors.orange,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text('$streak', style: _streakStyle),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// XP RANK BAR
// ════════════════════════════════════════════════
class _XPRankBar extends StatelessWidget {
  const _XPRankBar();

  @override
  Widget build(BuildContext context) {
    return Selector<GamificationProvider, XPSystem>(
      selector: (_, gp) => gp.xp,
      shouldRebuild: (a, b) =>
          a.totalXP != b.totalXP ||
          a.weeklyXP != b.weeklyXP ||
          a.rank != b.rank ||
          a.rankProgress != b.rankProgress ||
          a.xpToNextRank != b.xpToNextRank,
      builder: (_, xp, __) => RepaintBoundary(child: _XPRankBarBody(xp: xp)),
    );
  }
}

class _XPRankBarBody extends StatelessWidget {
  final XPSystem xp;
  const _XPRankBarBody({required this.xp});

  static final _glowShadow = [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: 0.07),
      blurRadius: 20,
    ),
  ];

  static const _rankStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.gold,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.3,
  );

  static const _percentStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.gold,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const _mutedSmall = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 10,
  );

  static const _mutedMicro = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C07),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: _glowShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PulseOrb(
                emoji: xp.rank.emoji,
                gradient: AppGradients.rankGradient(xp.rank.index),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(xp.rank.displayName.toUpperCase(),
                            style: _rankStyle),
                        const SizedBox(width: AppSpacing.xs + 2),
                        _XPPill(xp: xp.totalXP),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      xp.weeklyXP > 0
                          ? '${xp.weeklyXP} XP earned this week 🔥'
                          : 'Start training to earn XP',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(xp.rankProgress * 100).toInt()}%',
                      style: _percentStyle),
                  Text('to ${xp.nextRankName}', style: _mutedSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AnimatedXPBar(progress: xp.rankProgress),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(xp.rank.displayName, style: _mutedMicro),
              Text(
                xp.nextRankName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.gold.withValues(alpha: 0.55),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (xp.xpToNextRank > 0) ...[
            const SizedBox(height: 6),
            _XPNextGoalTease(
              xpToNext: xp.xpToNextRank,
              nextRankName: xp.nextRankName,
              nextRankEmoji: xp.nextRankEmoji,
            ),
          ],
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
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            '$xpToNext XP to $nextRankName $nextRankEmoji',
            style: _goldText,
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

  static const _emojiStyle = TextStyle(fontSize: 26);

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.gradient,
      ),
      child: const Center(child: Text('', style: _emojiStyle)),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final v = _pulse.value;
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.gradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.32 * v),
                  blurRadius: 16 * v,
                  spreadRadius: 2 * v,
                ),
              ],
            ),
            child: Center(
              child: Text(widget.emoji, style: _emojiStyle),
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
// MOOD ROW
// ════════════════════════════════════════════════
class _MoodRow extends StatelessWidget {
  const _MoodRow();

  static const _headerStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static Color _color(MoodType m) {
    switch (m) {
      case MoodType.tired:
        return AppColors.blue;
      case MoodType.energetic:
        return AppColors.green;
      default:
        return AppColors.gold;
    }
  }

  static String _coachText(MoodType m) {
    switch (m) {
      case MoodType.tired:
        return '💙 Body\'s telling you something. Smart recovery is still progress.';
      case MoodType.energetic:
        return '🔥 This is YOUR day. Go break that record — you\'re ready.';
      default:
        return '👊 Solid headspace. Execute the plan and walk out stronger.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, MoodType>(
      selector: (_, ap) => ap.todayMood,
      builder: (_, mood, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text('HOW ARE YOU FEELING TODAY?', style: _headerStyle),
    const SizedBox(height: AppSpacing.md),
    Row(
      children: [
        for (final m in MoodType.values)
          Expanded(
            child: _MoodTile(
              mood: m,
              selected: mood == m,
              color: _color(m),
              onTap: () {
                H.selection();
                context.read<AppProvider>().setMood(m);
              },
            ),
          ),
      ],
    ),
    if (mood != MoodType.normal) ...[
      const SizedBox(height: AppSpacing.md),
      _MoodCoachBubble(color: _color(mood), text: _coachText(mood)),
    ],
  ],
),
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final MoodType mood;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.28 : 1.0,
              duration: AppDurations.fast,
              child: Text(
                mood.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              mood.label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: selected ? color : AppColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodCoachBubble extends StatelessWidget {
  final Color color;
  final String text;
  const _MoodCoachBubble({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// AI COACH CARD — animated glow border
// ════════════════════════════════════════════════
class _AICoachCard extends StatefulWidget {
  const _AICoachCard();

  @override
  State<_AICoachCard> createState() => _AICoachCardState();
}

class _AICoachCardState extends State<_AICoachCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.07, end: 0.22)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _AICoachData>(
      selector: (_, ap) => _AICoachData(
        recovery: ap.getOverallRecovery(),
        suggestion: ap.aiSuggestion,
        canUseAI: ap.canUseAI(),
        isPremium: ap.isPremium,
        aiRemaining: ap.aiUsesRemaining,
      ),
      builder: (context, data, _) {
        return RepaintBoundary(
          child: _AICoachGlowFrame(
            glow: _glow,
            child: _AICoachContent(data: data),
          ),
        );
      },
    );
  }
}

@immutable
class _AICoachData {
  final int recovery;
  final String suggestion;
  final bool canUseAI;
  final bool isPremium;
  final int aiRemaining;

  const _AICoachData({
    required this.recovery,
    required this.suggestion,
    required this.canUseAI,
    required this.isPremium,
    required this.aiRemaining,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _AICoachData &&
          other.recovery == recovery &&
          other.suggestion == suggestion &&
          other.canUseAI == canUseAI &&
          other.isPremium == isPremium &&
          other.aiRemaining == aiRemaining);

  @override
  int get hashCode =>
      Object.hash(recovery, suggestion, canUseAI, isPremium, aiRemaining);
}

class _AICoachGlowFrame extends StatelessWidget {
  final Animation<double> glow;
  final Widget child;
  const _AICoachGlowFrame({required this.glow, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, c) {
        final v = glow.value;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0900),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: v),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: v * 0.55),
                blurRadius: 18,
              ),
            ],
          ),
          child: c,
        );
      },
      child: child,
    );
  }
}

class _AICoachContent extends StatelessWidget {
  final _AICoachData data;
  const _AICoachContent({required this.data});

  static const _label = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  Color _recoveryColor(int r) {
    if (r >= 70) return AppColors.green;
    if (r >= 40) return AppColors.yellow;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final rColor = _recoveryColor(data.recovery);
    return _Tap(
      onTap: () { final ap = context.read<AppProvider>(); if (ap.hasAIPlan) { _showAIPlanSheet(context, ap.lastAIPlan); } else { Navigator.push(context, slideRoute(const AISetupScreen())); } },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const _AIRingOrb(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('AI COACH', style: _label),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${data.recovery}% recovered',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: rColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  if (data.canUseAI)
                    Text(
                      data.suggestion.isEmpty
                          ? '💪 You\'re primed. Let\'s crush today\'s session.'
                          : data.suggestion,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    )
                  else
                    _Tap(
                      onTap: () => PaywallSheet.show(
                        context,
                        trigger: PaywallTrigger.aiLimitHit,
                        onUpgrade: () {},
                        onAdComplete: () {},
                      ),
                      child: const Text(
                        '🔒 Daily AI limit reached — tap to unlock',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _AIRingOrb extends StatefulWidget {
  const _AIRingOrb();

  @override
  State<_AIRingOrb> createState() => _AIRingOrbState();
}

class _AIRingOrbState extends State<_AIRingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _ring = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ring,
              builder: (_, __) {
                final v = _ring.value;
                return Transform.scale(
                  scale: 0.88 + 0.32 * v,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold
                            .withValues(alpha: (1 - v) * 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.gold,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 22,
                color: Colors.black,
              ),
            ),
          ],
        ),
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
      currentWaterMl: ap.profile.currentWaterMl,
      waterGoalMl: ap.profile.dailyWaterGoalMl,
    );

    NotificationService.instance.scheduleStreakReminder(
      currentStreak: ap.streak.currentStreak,
      hasWorkedOutToday: ap.todayPlan.isCompleted,
      userName:
          ap.profile.name.isEmpty ? 'Champion' : ap.profile.name,
    );
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
        borderRadius: BorderRadius.circular(AppSpacing.lg),
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
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data.allDone ? '✅' : '🎯',
                style: const TextStyle(fontSize: 14),
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
    color: AppColors.green,
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
          AppColors.green.withValues(alpha: 0.12),
          AppColors.green.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
          SizedBox(width: 6),
          Text('All missions crushed — beast mode 🦁', style: _text),
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
        child: _MissionRowContent(mission: widget.mission),
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
              borderRadius: BorderRadius.circular(10),
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
              child: Text(
                done ? '✓' : mission.emoji,
                style: TextStyle(
                  fontSize: done ? 14 : 13,
                  color: done ? AppColors.green : null,
                  fontWeight: FontWeight.w800,
                ),
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
// TODAY'S WORKOUT
// ════════════════════════════════════════════════
class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _TodayData>(
      selector: (_, ap) => _TodayData.from(ap),
      builder: (context, data, _) {
        if (data.isRestDay) return const _RestDayCard();
        if (data.isEmpty) return const _EmptyWorkoutCard();
        return _ActiveWorkoutCard(data: data);
      },
    );
  }
}

@immutable
class _TodayData {
  final DayPlan today;
  final int todayIndex;
  final int total;
  final int done;
  final int totalSets;
  final double pct;
  final bool isRestDay;
  final bool isEmpty;
  final bool isCompleted;

  const _TodayData({
    required this.today,
    required this.todayIndex,
    required this.total,
    required this.done,
    required this.totalSets,
    required this.pct,
    required this.isRestDay,
    required this.isEmpty,
    required this.isCompleted,
  });

  factory _TodayData.from(AppProvider ap) {
    final today = ap.todayPlan;
    final total = today.exercises.length;
    final done = today.completedExercises;
    int sets = 0;
    for (final e in today.exercises) {
      sets += e.sets.length;
    }
    final pct = (total > 0 ? done / total : 0.0).clamp(0.0, 1.0);
    return _TodayData(
      today: today,
      todayIndex: ap.todayIndex,
      total: total,
      done: done,
      totalSets: sets,
      pct: pct,
      isRestDay: today.isRestDay,
      isEmpty: total == 0 && !today.isRestDay,
      isCompleted: today.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TodayData &&
        identical(other.today, today) &&
        other.todayIndex == todayIndex &&
        other.total == total &&
        other.done == done &&
        other.totalSets == totalSets &&
        other.isRestDay == isRestDay &&
        other.isEmpty == isEmpty &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(
      today, todayIndex, total, done, totalSets,
      isRestDay, isEmpty, isCompleted);
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w900,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.45,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.borderSoft, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('😴', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest Day', style: _titleStyle),
                SizedBox(height: 3),
                Text(
                  'Smart recovery = stronger tomorrow. You\'ve earned this.',
                  style: _subStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkoutCard extends StatelessWidget {
  const _EmptyWorkoutCard();

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: () =>
          Navigator.push(context, slideRoute(const AISetupScreen())),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.gold.withValues(alpha: 0.16),
                  AppColors.gold.withValues(alpha: 0.06),
                ]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.gold,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No workout yet', style: _titleStyle),
                  Text(
                    'Let AI build your perfect plan in seconds 🤖',
                    style: _subStyle,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.gold,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  final _TodayData data;
  const _ActiveWorkoutCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    return _Tap(
      onTap: () => Navigator.push(
        context,
        slideRoute(PlannerScreen(initialDayIndex: data.todayIndex)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: data.isCompleted
                ? AppColors.green.withValues(alpha: 0.38)
                : AppColors.borderSoft,
            width: 1,
          ),
          boxShadow: data.isCompleted
              ? [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.08),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            _WorkoutHeader(data: data),
            _WorkoutExerciseList(today: today),
            if (today.exercises.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+${today.exercises.length - 3} more exercises',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: data.isCompleted
                  ? const _CompletedBanner()
                  : GoldButton(
                      text: 'Start Workout 💪',
                      icon: Icons.play_arrow_rounded,
                      width: double.infinity,
                      onTap: () => Navigator.push(
                        context,
                        slideRoute(
                          PlannerScreen(initialDayIndex: data.todayIndex),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutHeader extends StatelessWidget {
  final _TodayData data;
  const _WorkoutHeader({required this.data});

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.textPrimary,
    fontSize: 21,
    fontWeight: FontWeight.w900,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
  );

  static const _ringText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.today.title, style: _titleStyle),
                const SizedBox(height: 3),
                Text(
                  '${data.total} exercises · ${data.totalSets} sets',
                  style: _subStyle,
                ),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 5.0,
            percent: data.pct,
            center: Text('${data.done}/${data.total}', style: _ringText),
            progressColor:
                data.isCompleted ? AppColors.green : AppColors.gold,
            backgroundColor: AppColors.bgElevated,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 950,
          ),
        ],
      ),
    );
  }
}

class _WorkoutExerciseList extends StatelessWidget {
  final DayPlan today;
  const _WorkoutExerciseList({required this.today});

  @override
  Widget build(BuildContext context) {
    final count = today.exercises.length < 3 ? today.exercises.length : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            _ExerciseRow(
              key: ValueKey(today.exercises[i].id),
              exercise: today.exercises[i],
            ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final PlannedExercise exercise;
  const _ExerciseRow({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final done = exercise.isComplete;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.green.withValues(alpha: 0.10)
                  : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(exercise.emoji,
                  style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              exercise.name,
              style: TextStyle(
                fontFamily: 'Inter',
                color: done ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${exercise.sets.length}×',
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: done ? AppColors.green : AppColors.borderMedium,
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  static const _text = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.green,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.green.withValues(alpha: 0.14),
          AppColors.green.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.green, size: 15),
          SizedBox(width: 6),
          Text('Crushed it! You\'re unstoppable 🔥', style: _text),
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
        _WaterTile(),
        SizedBox(width: AppSpacing.md),
        _AIChatTile(),
        SizedBox(width: AppSpacing.md),
        _GeneratePlanTile(),
      ],
    );
  }
}

class _WaterTile extends StatelessWidget {
  const _WaterTile();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, double>(
      selector: (_, ap) => ap.waterProgress,
      builder: (context, waterPct, _) {
        final wColor = waterPct >= 0.7 ? AppColors.green : AppColors.blue;
        return _ActionTile(
          emoji: '💧',
          label: 'Water',
          value: '${(waterPct * 100).toInt()}%',
          color: wColor,
          onTap: () => _onWaterTap(context),
        );
      },
    );
  }

  void _onWaterTap(BuildContext context) {
    H.light();
    final ap = context.read<AppProvider>();
    ap.addWater(250);
    context.read<GamificationProvider>().checkAutoMissions(
          waterProgress: ap.waterProgress,
          totalSetsDone: 0,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('💧 +250ml — stay hydrated, champion!'),
        backgroundColor: AppColors.blue,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _AIChatTile extends StatelessWidget {
  const _AIChatTile();

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      emoji: '🤖',
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
      label: 'Generate',
      value: 'Plan',
      color: AppColors.purple,
      onTap: () =>
          Navigator.push(context, slideRoute(const AISetupScreen())),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _Tap(
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: color,
                  fontSize: 17,
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
      selector: (_, ap) => ap.streak.totalWorkouts,
      builder: (_, v, __) => _ImpactStat(
        emoji: '🏋️',
        value: '$v',
        label: 'Sessions',
        color: AppColors.gold,
      ),
    );
  }
}

class _BestStreakStat extends StatelessWidget {
  const _BestStreakStat();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, int>(
      selector: (_, ap) => ap.streak.longestStreak,
      builder: (_, v, __) => _ImpactStat(
        emoji: '🔥',
        value: '${v}d',
        label: 'Best Streak',
        color: AppColors.orange,
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
      builder: (_, v, __) => _ImpactStat(
        emoji: '⚡',
        value: '$v',
        label: 'XP This Week',
        color: AppColors.purple,
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
                fontSize: 9.5,
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
                      ? AppColors.gold.withValues(alpha: 0.10)
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: unlocked
                        ? AppColors.gold.withValues(alpha: 0.38)
                        : AppColors.borderSoft,
                    width: unlocked ? 1 : 0.5,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color:
                                AppColors.gold.withValues(alpha: 0.14),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      unlocked ? badge.emoji : '🔒',
                      style: TextStyle(fontSize: unlocked ? 30 : 22),
                    ),
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
                color: unlocked ? AppColors.gold : AppColors.textMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
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
// OVERLAY TOASTS & POPUPS
// ════════════════════════════════════════════════
class _XPToast extends StatelessWidget {
  final int xp;
  const _XPToast({required this.xp});

  static const _xpStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: AppSpacing.lg,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (_, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              gradient: AppGradients.gold,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppShadows.buttonGlow(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: AppSpacing.xs),
                Text('+$xp XP', style: _xpStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePopup extends StatelessWidget {
  final AppBadge badge;
  const _BadgePopup({required this.badge});

  static const _label = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.gold,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 3,
  );

  static const _xpStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.gold,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 550),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl + 8),
                padding:
                    const EdgeInsets.all(AppSpacing.xxl + 4),
                decoration: BoxDecoration(
                  color: AppColors.bgModal,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.gold.withValues(alpha: 0.28),
                      blurRadius: 44,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(badge.emoji,
                        style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('BADGE UNLOCKED!', style: _label),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(badge.title, style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      badge.description,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.gold.withValues(alpha: 0.18),
                          AppColors.gold.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Text('+${badge.xpReward} XP', style: _xpStyle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankUpPopup extends StatelessWidget {
  final UserRank rank;
  const _RankUpPopup({required this.rank});

  static const _rankUpLabel = TextStyle(
    fontFamily: 'Inter',
    color: Color(0xB3FFFFFF),
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 3.5,
  );

  static const _rankNameStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: Colors.white,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: Color(0xD9FFFFFF),
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl),
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xxl,
                    horizontal: AppSpacing.xxl),
                decoration: BoxDecoration(
                  gradient: AppGradients.rankGradient(rank.index),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.floating,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rank.emoji,
                        style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: AppSpacing.md),
                    const Text('RANK UP!', style: _rankUpLabel),
                    const SizedBox(height: AppSpacing.xs),
                    Text(rank.displayName.toUpperCase(),
                        style: _rankNameStyle),
                    const SizedBox(height: AppSpacing.xs + 2),
                    const Text(
                      'You\'ve levelled up — keep pushing! 🔥',
                      style: _subStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakToast extends StatelessWidget {
  final int streak;
  const _StreakToast({required this.streak});

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.orange,
    fontSize: 19,
    fontWeight: FontWeight.w900,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 98,
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgModal,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.42),
                width: 1,
              ),
              boxShadow: AppShadows.colored(AppColors.orange),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 30)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$streak-Day Streak! 🔥',
                          style: _titleStyle),
                      const Text(
                        'You\'re unstoppable. Never break the chain.',
                        style: _subStyle,
                      ),
                    ],
                  ),
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
// ANIMATION HELPERS — lightweight, no controllers
// ════════════════════════════════════════════════
class _FadeSlide extends StatelessWidget {
  final Widget child;
  final int delay;
  const _FadeSlide({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(
        delay / (380 + delay),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 12),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Scale-down tap feedback wrapper.
class _Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Tap({required this.child, required this.onTap});

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}



void _showAIPlanSheet(BuildContext context, String planText) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgModal,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                const Text('Your AI Plan',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Text(planText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final ap = context.read<AppProvider>();
                  final result = await ap.getAIWorkoutPlan();
                  if (result.isNotEmpty) {
                    await ap.applyAIWorkout(result);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Plan applied to Planner!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '✅ Apply This Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
