// lib/widgets/home/home_skeleton_widgets.dart
// Skeleton / shimmer loading widgets for HomeScreen.
// Extracted from home_screen.dart — no behavior changes.

import 'package:flutter/material.dart';
import '../../utils/app_constants.dart';

// ════════════════════════════════════════════════
// SKELETON — single shimmer driver, shared across bones
// ════════════════════════════════════════════════
class HomeSkeletonScreen extends StatefulWidget {
  const HomeSkeletonScreen({super.key});

  @override
  State<HomeSkeletonScreen> createState() => _HomeSkeletonScreenState();
}

class _HomeSkeletonScreenState extends State<HomeSkeletonScreen>
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
