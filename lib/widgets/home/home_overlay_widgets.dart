// lib/widgets/home/home_overlay_widgets.dart
// Overlay/popup widgets extracted from home_screen.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../utils/app_constants.dart';

// ════════════════════════════════════════════════
// OVERLAY
// ════════════════════════════════════════════════
class OverlayLayer extends StatelessWidget {
  const OverlayLayer({super.key});

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
      builder: (_, s, __) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchOutCurve: Curves.easeInBack,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: s.show
            ? Positioned(
                top: 60,
                right: AppSpacing.lg,
                child: _XPToast(
                  key: const ValueKey('xp_toast'),
                  xp: s.xp,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('xp_empty')),
      ),
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

class _XPToast extends StatelessWidget {
  final int xp;
  const _XPToast({super.key, required this.xp});

  static const _xpStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
                const Icon(Icons.bolt_rounded,
                    size: 16, color: Colors.black),
                const SizedBox(width: AppSpacing.xs),
                Text('+$xp XP', style: _xpStyle),
              ],
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
                    Icon(badge.icon,
                        size: 56, color: AppColors.gold),
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
                    Icon(rank.icon,
                        size: 64, color: Colors.white),
                    const SizedBox(height: AppSpacing.md),
                    const Text('RANK UP!', style: _rankUpLabel),
                    const SizedBox(height: AppSpacing.xs),
                    Text(rank.displayName.toUpperCase(),
                        style: _rankNameStyle),
                    const SizedBox(height: AppSpacing.xs + 2),
                    const Text(
                      'You\'ve levelled up — keep pushing.',
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
                Icon(Icons.local_fire_department_rounded,
                    size: 30, color: AppColors.orange),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$streak-Day Streak',
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
class FadeSlide extends StatelessWidget {
  final Widget child;
  final int delay;
  const FadeSlide({super.key, required this.child, required this.delay});

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
