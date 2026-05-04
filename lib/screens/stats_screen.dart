// lib/screens/stats_screen.dart — v8.0 PREMIUM
// Upgrades: animated XP orb, staggered card entrances, glowing trend badge,
// chart with gradient fill + glow dot, recovery grid with score rings,
// history cards with volume pill, coach-tone copy, all empty states engaging.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/workout_log.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../utils/app_constants.dart';

import '../utils/recovery_grid_data.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/empty_state.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart'; // ✅ Paywall triggers
import 'dart:ui'; // ✅ ImageFilter for blur

// ════════════════════════════════════════════════
// HAPTICS — consistent system (Phase 1)
// ════════════════════════════════════════════════
class H{
  static void heavy()     => HapticFeedback.heavyImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void light()     => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success()   => HapticFeedback.heavyImpact();
  static void tap()       => HapticFeedback.lightImpact();
}


class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('Analytics', style: AppTextStyles.h2),
          Text('Track every gain', style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 11)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          dividerColor: AppColors.divider,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'PROGRESS'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_OverviewTab(), _ProgressTab(), _HistoryTab()],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// OVERVIEW TAB
// ════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    // Use watch (not Selector2) so recovery data rebuilds when provider notifies
    final ap = context.watch<AppProvider>();
    final gp = context.watch<GamificationProvider>();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
      children: [

            // XP + Rank card
            _FI(child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C07),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.22)),
                boxShadow: [BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.07),
                    blurRadius: 20)],
              ),
              child: Column(children: [
                Row(children: [
                  _PulseOrb(emoji: gp.xp.rank.emoji,
                      gradient: AppGradients.rankGradient(gp.xp.rank.index)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(gp.xp.rank.displayName.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                            color: AppColors.gold, fontSize: 15,
                            fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                    Text('${gp.xp.totalXP} XP · ${gp.xp.weeklyXP} this week',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${(gp.xp.rankProgress * 100).toInt()}%',
                        style: GoogleFonts.rajdhani(
                            color: AppColors.gold, fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    Text('to ${gp.xp.nextRankName}',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 10)),
                  ]),
                ]),
                const SizedBox(height: AppSpacing.md),
                _AnimBar(progress: gp.xp.rankProgress),
              ]),
            )),

            const SizedBox(height: AppSpacing.lg),

            // Key stats
            _FI(delay: 70, child: Row(children: [
              _BigStat(label: 'Total Sessions', value: '${ap.streak.totalWorkouts}',
                  emoji: '🏋️', color: AppColors.gold),
              const SizedBox(width: AppSpacing.md),
              _BigStat(label: 'Best Streak', value: '${ap.streak.longestStreak}d',
                  emoji: '🔥', color: AppColors.orange),
              const SizedBox(width: AppSpacing.md),
              _BigStat(label: 'Current', value: '${ap.streak.currentStreak}d',
                  emoji: '⚡', color: AppColors.blue),
            ])),

            const SizedBox(height: AppSpacing.lg),

            _FI(delay: 130, child: _WeeklyProgressCard(
                value: ap.weeklyImprovementPercent)),
            const SizedBox(height: AppSpacing.lg),

            if (ap.workoutsByDayOfWeek.any((c) => c > 0)) ...[
              _Label(text: 'Weekly Activity'),
              const SizedBox(height: AppSpacing.md),
              _FI(delay: 160, child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                  border: Border.all(color: AppColors.borderSoft, width: 0.5),
                ),
                child: SizedBox(
                  height: 152,
                  child: _WeekChart(data: ap.workoutsByDayOfWeek)),
              )),
              const SizedBox(height: AppSpacing.lg),
            ],

            _Label(text: 'Muscle Recovery'),
            const SizedBox(height: AppSpacing.md),
            _FI(delay: 200, child: _StatsRecoveryGrid(ap: ap)),
            const SizedBox(height: AppSpacing.lg),

            // AI tip
            _FI(delay: 250, child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0900),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.18)),
              ),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(ap.progressionTip,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 13,
                        height: 1.5))),
              ]),
            )),
            const SizedBox(height: AppSpacing.lg),

            _FI(delay: 290, child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(color: AppColors.borderSoft, width: 0.5),
              ),
              child: Row(children: [
                const Text('⚖️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(ap.muscleImbalance,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 13,
                        height: 1.5))),
              ]),
            )),

            const SizedBox(height: AppSpacing.lg),

            _Label(text: 'Achievements'),
            const SizedBox(height: AppSpacing.md),
            _FI(delay: 330, child: _BadgesGrid(ap: ap)),

            const SizedBox(height: AppSpacing.lg),

            // ✅ STEP 3 — Locked advanced analytics (blur + lock)
            // Visible to all users — curiosity → conversion
            _FI(delay: 370, child: _LockedAdvancedStats(ap: ap)),

            const SizedBox(height: 40),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// STATS RECOVERY GRID
// ════════════════════════════════════════════════
class _StatsRecoveryGrid extends StatelessWidget {
  final AppProvider ap;
  const _StatsRecoveryGrid({required this.ap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: RecoveryGridData.muscles.length,
      gridDelegate: RecoveryGridData.gridDelegate,
      itemBuilder: (_, i) {
        final m     = RecoveryGridData.muscles[i];
        final score = ap.getMuscleRecovery(m['key']!).toInt().clamp(0, 100);
        return _RGridTile(
            muscle: m['label']!, score: score, emoji: m['emoji']!,
            delay: Duration(milliseconds: i * 45));
      },
    );
  }
}

class _RGridTile extends StatefulWidget {
  final String muscle, emoji;
  final int score;
  final Duration delay;
  const _RGridTile({required this.muscle, required this.score,
      required this.emoji, required this.delay});

  @override
  State<_RGridTile> createState() => _RGridTileState();
}

class _RGridTileState extends State<_RGridTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bar;

  Color get _c {
    if (widget.score >= 70) return AppColors.green;
    if (widget.score >= 40) return AppColors.yellow;
    return AppColors.red;
  }

  String get _lbl {
    if (widget.score >= 80) return 'Ready';
    if (widget.score >= 60) return 'Good';
    if (widget.score >= 40) return 'Fair';
    return 'Rest';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 850));
    _bar = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _bar,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
            color: _c.withValues(alpha: 0.22 * _bar.value), width: 1),
        boxShadow: [BoxShadow(
            color: _c.withValues(alpha: 0.08 * _bar.value), blurRadius: 8)],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(widget.emoji, style: const TextStyle(fontSize: 18, height: 1.0)),
        const SizedBox(height: 2),
        Text(widget.muscle, style: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 9,
            fontWeight: FontWeight.w600, height: 1.1),
            overflow: TextOverflow.ellipsis, maxLines: 1,
            textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LinearProgressIndicator(
            value: (widget.score / 100) * _bar.value,
            minHeight: 3,
            backgroundColor: AppColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(_c),
          ),
        ),
        const SizedBox(height: 2),
        Text('${widget.score}%',
            style: GoogleFonts.rajdhani(
                color: _c, fontSize: 11, fontWeight: FontWeight.w800,
                height: 1.1)),
        Text(_lbl, style: GoogleFonts.inter(
            color: _c.withValues(alpha: 0.75), fontSize: 8,
            fontWeight: FontWeight.w600, height: 1.1)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// WEEKLY PROGRESS CARD
// ════════════════════════════════════════════════
class _WeeklyProgressCard extends StatelessWidget {
  final double value;
  const _WeeklyProgressCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final isUp   = value > 0;
    final isDown = value < 0;
    final tColor = isUp ? AppColors.green : isDown ? AppColors.red : AppColors.yellow;
    final tLabel = isUp ? 'Improving 📈' : isDown ? 'Declining 📉' : 'Plateau ⏸️';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF090A06),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: tColor.withValues(alpha: 0.28), width: 1),
        boxShadow: [BoxShadow(
            color: tColor.withValues(alpha: 0.07), blurRadius: 16)],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tColor.withValues(alpha: 0.12),
          ),
          child: Icon(isUp ? Icons.trending_up : Icons.trending_down,
              color: tColor, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Momentum', style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 3),
            Text('${value.toStringAsFixed(1)}%',
                style: GoogleFonts.rajdhani(
                    color: tColor, fontSize: 26, fontWeight: FontWeight.w900)),
            Text(
              context.select<AppProvider, String>((ap) => ap.weeklyMessage),
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 11,
                  fontStyle: FontStyle.italic, height: 1.4),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(tLabel, style: GoogleFonts.inter(
              color: tColor, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// ANIMATED XP BAR
// ════════════════════════════════════════════════
class _AnimBar extends StatefulWidget {
  final double progress;
  const _AnimBar({required this.progress});

  @override
  State<_AnimBar> createState() => _AnimBarState();
}

class _AnimBarState extends State<_AnimBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => XPProgressBar(progress: widget.progress * _a.value),
  );
}

// ════════════════════════════════════════════════
// WEEKLY BAR CHART
// ════════════════════════════════════════════════
class _WeekChart extends StatelessWidget {
  final List<int> data;
  const _WeekChart({required this.data});

  @override
  Widget build(BuildContext context) {
    const days   = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxVal = data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);
    final maxY   = maxVal == 0
        ? 5.0 : (maxVal + 1).toDouble().clamp(2.0, 20.0);

    return BarChart(BarChartData(
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        show: true, drawVerticalLine: false, horizontalInterval: 1,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.divider, strokeWidth: 0.5)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= days.length) return const SizedBox.shrink();
            return Text(days[i], style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 10));
          },
        )),
      ),
      barGroups: data.asMap().entries.map((e) => BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(
          toY: e.value.toDouble(), width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          gradient: e.value > 0 ? AppGradients.gold : null,
          color: e.value == 0 ? AppColors.bgElevated : null,
        )],
      )).toList(),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
            '${rod.toY.toInt()}',
            GoogleFonts.inter(color: Colors.black,
                fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ),
      ),
    ));
  }
}

// ════════════════════════════════════════════════
// BADGES GRID
// ════════════════════════════════════════════════
class _BadgesGrid extends StatelessWidget {
  final AppProvider ap;
  const _BadgesGrid({required this.ap});

  @override
  Widget build(BuildContext context) {
    final earned = ap.streak.earnedBadges;
    return GridView.count(
      crossAxisCount: 4, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm, crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.9,
      children: BadgeSystem.all.map((b) => _GridBadge(
          b: b, unlocked: earned.contains(b.id))).toList(),
    );
  }
}

class _GridBadge extends StatelessWidget {
  final AppBadge b;
  final bool unlocked;
  const _GridBadge({required this.b, required this.unlocked});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: unlocked
              ? AppColors.gold.withValues(alpha: 0.10)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: unlocked
                  ? AppColors.gold.withValues(alpha: 0.38)
                  : AppColors.borderSoft,
              width: unlocked ? 1 : 0.5),
          boxShadow: unlocked ? [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.14), blurRadius: 8)] : null,
        ),
        child: Center(child: Text(
            unlocked ? b.emoji : '🔒',
            style: TextStyle(fontSize: unlocked ? 26 : 20))),
      ),
      const SizedBox(height: 4),
      Text(b.title, style: GoogleFonts.inter(
          color: unlocked ? AppColors.gold : AppColors.textMuted,
          fontSize: 8.5, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    ],
  );
}

// ════════════════════════════════════════════════
// LOCKED ADVANCED STATS — STEP 3
// Blurred cards with lock icon → curiosity → conversion
// Shows to ALL users, tapping opens PaywallSheet
// ════════════════════════════════════════════════
class _LockedAdvancedStats extends StatelessWidget {
  final AppProvider ap;
  const _LockedAdvancedStats({required this.ap});

  @override
  Widget build(BuildContext context) {
    if (ap.isPremium) return const SizedBox.shrink(); // premium users see real data

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Row(children: [
        Text('Advanced Analytics', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Text('PRO', style: GoogleFonts.inter(
              color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 12),

      // 3 blurred metric cards in a row
      Row(children: [
        _BlurMetricCard(label: 'Fatigue Index',  value: '72',  unit: '%',   color: AppColors.orange),
        const SizedBox(width: 10),
        _BlurMetricCard(label: 'Plateau Risk',   value: '34',  unit: '%',   color: AppColors.red),
        const SizedBox(width: 10),
        _BlurMetricCard(label: 'Readiness',      value: '88',  unit: '%',   color: AppColors.green),
      ]),
      const SizedBox(height: 12),

      // Blurred chart card with lock overlay
      GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          PaywallSheet.show(context,
            trigger: PaywallTrigger.advancedStatsTap,
            onUpgrade: () => ap.notifyListeners(),
          );
        },
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Stack(children: [
            // Fake blurred chart underneath
            Positioned.fill(child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ImageFilter.blur(sigmaX: 6, sigmaY: 6) != null
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: _FakeChart(),
                    )
                  : _FakeChart(),
            )),
            // Dark overlay
            Positioned.fill(child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Container(color: AppColors.bg.withValues(alpha: 0.55)),
            )),
            // Lock content
            Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: AppColors.gold, size: 22),
                ),
                const SizedBox(height: 10),
                Text('Strength Progress Chart', style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tap to unlock advanced analytics',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            )),
          ]),
        ),
      ),

      const SizedBox(height: 12),

      // Unlock CTA card
      GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          PaywallSheet.show(context,
            trigger: PaywallTrigger.advancedStatsTap,
            onUpgrade: () => ap.notifyListeners(),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.gold.withValues(alpha: 0.10),
              AppColors.gold.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.30), width: 1),
          ),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock Advanced Analytics',
                    style: GoogleFonts.rajdhani(
                        color: AppColors.gold, fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Fatigue index, plateau detection, strength trends',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            )),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.gold, size: 14),
          ]),
        ),
      ),
    ]);
  }
}

// Blurred metric pill in row
class _BlurMetricCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _BlurMetricCard({
    required this.label, required this.value,
    required this.unit,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        PaywallSheet.show(context,
          trigger: PaywallTrigger.advancedStatsTap,
          onUpgrade: () {},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Stack(alignment: Alignment.center, children: [
          // Blurred content
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$value$unit', style: GoogleFonts.rajdhani(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 9,
                  fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ]),
          ),
          // Lock icon on top
          const Icon(Icons.lock_rounded,
              color: AppColors.gold, size: 16),
        ]),
      ),
    ));
  }
}

// Fake chart drawn behind blur
class _FakeChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FakeChartPainter());
  }
}

class _FakeChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withOpacity(0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [0.1, 0.3, 0.25, 0.5, 0.45, 0.7, 0.65, 0.85, 0.8, 1.0];
    for (int i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i] * 0.7 - 0.15);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // Fill
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()
      ..color = AppColors.gold.withOpacity(0.08)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ════════════════════════════════════════════════
// PROGRESS TAB
// ════════════════════════════════════════════════
class _ProgressTab extends StatefulWidget {
  const _ProgressTab();

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<WorkoutLog>>(
      selector: (_, ap) => ap.logs,
      builder: (context, logs, _) {
        final ap            = context.read<AppProvider>();
        final exerciseNames = logs.map((l) => l.exercise)
            .toSet().toList()..sort();

        if (exerciseNames.isEmpty) {
          return const EmptyProgress();
        }

        _selected ??= exerciseNames.first;
        if (!exerciseNames.contains(_selected)) {
          _selected = exerciseNames.first;
        }

        return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
      children: [
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: exerciseNames.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xs + 2),
                itemBuilder: (ctx, i) {
                  final name = exerciseNames[i];
                  final sel  = name == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.gold : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: sel ? AppColors.gold : AppColors.borderMedium,
                          width: 0.8),
                        boxShadow: sel ? [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 8)] : null,
                      ),
                      child: Text(
                        name.replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                          color: sel ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_selected != null)
              _ExerciseChart(ap: ap, exKey: _selected!),
          ],
        );
      },
    );
  }
}

class _ExerciseChart extends StatelessWidget {
  final AppProvider ap;
  final String exKey;
  const _ExerciseChart({required this.ap, required this.exKey});

  @override
  Widget build(BuildContext context) {
    final exLogs = ap.logs
        .where((l) => l.exercise == exKey && l.weight > 0)
        .toList()..sort((a, b) => a.date.compareTo(b.date));

    final pr    = ap.getPR(exKey, 'kg');
    final trend = ap.getStrengthTrend(exKey);

    final tColor = trend == 'improving' ? AppColors.green
        : trend == 'declining' ? AppColors.red : AppColors.yellow;
    final tLabel = trend == 'improving' ? 'Improving 📈'
        : trend == 'declining' ? 'Declining 📉' : 'Plateau ⏸️';

    if (exLogs.length < 2) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📈', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.sm),
          Text('Log a few more sessions', style: AppTextStyles.h4),
          const SizedBox(height: AppSpacing.xs),
          Text('Your strength curve will appear as you train.',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12,
                  height: 1.4), textAlign: TextAlign.center),
        ])),
      );
    }

    final spots = exLogs.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight)).toList();
    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9)
        .floorToDouble();
    final maxY = (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1)
        .ceilToDouble();

    return _FI(child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.borderSoft, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exKey.replaceAll('_', ' ').toUpperCase(),
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 2),
            Row(children: [
              Text('PR: ', style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12)),
              Text('${pr}kg', style: GoogleFonts.rajdhani(
                  color: AppColors.gold, fontSize: 20,
                  fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              const Text('🏆', style: TextStyle(fontSize: 13)),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tLabel, style: GoogleFonts.inter(
                color: tColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 170,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider, strokeWidth: 0.5)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 42,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 9)),
              )),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles:  const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: spots, isCurved: true, curveSmoothness: 0.38,
              color: AppColors.gold, barWidth: 2.5,
              dotData: FlDotData(getDotPainter: (s, _, __, ___) =>
                  FlDotCirclePainter(
                    radius: 4.5, color: AppColors.gold,
                    strokeWidth: 2, strokeColor: AppColors.bg)),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(1)}kg',
                  GoogleFonts.inter(color: Colors.black,
                      fontSize: 11, fontWeight: FontWeight.w800),
                )).toList(),
              ),
            ),
          )),
        ),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════
// HISTORY TAB
// ════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<HistoryEntry>>(
      selector: (_, ap) => ap.history,
      builder: (_, history, __) {
        if (history.isEmpty) {
          return const EmptyHistory();
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, i) =>
              _HistoryCard(entry: history[i], index: i),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final int index;
  const _HistoryCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    return _FI(
      delay: index * 40,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2), width: 0.5),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.workoutName, style: AppTextStyles.h4,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              '${entry.exerciseCount} exercises · ${entry.durationMinutes}min',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(entry.date, style: AppTextStyles.caption),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${entry.totalVolume.toStringAsFixed(0)}kg vol',
                style: GoogleFonts.inter(
                    color: AppColors.blue, fontSize: 9,
                    fontWeight: FontWeight.w700)),
            ),
            if (entry.xpEarned > 0) ...[
              const SizedBox(height: 3),
              Text('+${entry.xpEarned} XP', style: AppTextStyles.goldSmall),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
        gradient: AppGradients.gold, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text.toUpperCase(), style: GoogleFonts.inter(
      color: AppColors.textPrimary, fontSize: 12,
      fontWeight: FontWeight.w800, letterSpacing: 1.0)),
  ]);
}

class _BigStat extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _BigStat({required this.emoji, required this.value,
      required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
    ),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: GoogleFonts.rajdhani(
          color: color, fontSize: 22, fontWeight: FontWeight.w900)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 9.5),
          textAlign: TextAlign.center),
    ]),
  ));
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
  late AnimationController _c;
  late Animation<double> _p;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _p = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _p,
    builder: (_, __) => Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle, gradient: widget.gradient,
        boxShadow: [BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.32 * _p.value),
          blurRadius: 16 * _p.value, spreadRadius: 2 * _p.value)],
      ),
      child: Center(child: Text(widget.emoji,
          style: const TextStyle(fontSize: 26))),
    ),
  );
}

class _FI extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FI({required this.child, this.delay = 0});

  @override
  State<_FI> createState() => _FIState();
}

class _FIState extends State<_FI> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f;
  late Animation<Offset> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _s = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay),
            () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _f, child: SlideTransition(position: _s, child: widget.child));
}
