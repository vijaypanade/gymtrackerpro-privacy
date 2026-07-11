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
import '../utils/app_constants.dart';

import '../utils/recovery_grid_data.dart';
import '../widgets/empty_state.dart';
import '../services/monetization_service.dart'; // ✅ Paywall triggers
import 'dart:math' as math;
import '../widgets/home/muscle_command_sheet.dart';
import '../services/progression_timeline_service.dart';
import '../models/weekly_review_data.dart';
import '../utils/app_routes.dart';
import 'ai_chat_screen.dart';

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
    _tabs.addListener(() { if (_tabs.indexIsChanging) H.selection(); });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  static String _subtitle(String badge) => switch (badge) {
    'DELOAD PHASE'     => 'Deload phase indicated.',
    'UNDER-RECOVERED'  => 'Elevated fatigue — manage load.',
    'PRIMED'           => 'Full recovery achieved.',
    'LOCKED IN'        => 'Performance rhythm locked in.',
    'PROGRESSING'      => 'Momentum climbing above baseline.',
    'HIGH FATIGUE'     => 'Elevated fatigue — reduce load.',
    'MOMENTUM AT RISK' => 'Consistency rhythm at risk.',
    'PR ACHIEVED'      => 'PR logged — adaptation active.',
    'COMEBACK'         => 'Consistency rebuilding.',
    'REST DAY'         => 'Planned recovery active.',
    _                  => 'Performance intelligence center.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0.2,
        title: Consumer<AppProvider>(
          builder: (_, ap, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Analytics', style: AppTextStyles.h2),
              Text(_subtitle(ap.coachInsight.badge), style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.78), fontSize: 10.5)),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6),
          dividerColor: AppColors.divider.withValues(alpha: 0.28),
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
    final ap = context.read<AppProvider>();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 56),
      children: [

        // ── HERO: ORB + WEEKLY STATS + COACH INSIGHT ──
        _FI(child: _StatsHeroSection(ap: ap)),
        const SizedBox(height: AppSpacing.lg),

        // ── RECOVERY ──────────────────────────────────
        const _Label(text: 'Recovery'),
        const SizedBox(height: AppSpacing.sm),
        _FI(delay: 130, child: _StatsRecoveryRail(ap: ap)),
        const SizedBox(height: AppSpacing.lg),

        // ── WEEKLY BREAKDOWN ───────────────────────────
        const _Label(text: 'Weekly Breakdown'),
        const SizedBox(height: AppSpacing.sm),
        _FI(delay: 160, child: _FatigueProgressionCard(ap: ap)),
        const SizedBox(height: AppSpacing.lg),

        if (!ap.onboardingComplete && ap.onboardingNarrative.isNotEmpty) ...[
          const _Label(text: 'Adapting To You'),
          const SizedBox(height: AppSpacing.sm),
          _FI(delay: 180, child: _OnboardingEvolutionSection(ap: ap)),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── PREDICTIVE FORWARD INTELLIGENCE ──────────
        _FI(delay: 175, child: _PredictiveForwardCard(ap: ap)),
        const SizedBox(height: AppSpacing.lg),

        // ── ACHIEVEMENTS (horizontal scroll) ──────────
        const _Label(text: 'Achievements'),
        const SizedBox(height: AppSpacing.sm),
        _FI(delay: 200, child: _BadgesHScroll(ap: ap)),
        const SizedBox(height: AppSpacing.lg),

        _FI(delay: 220, child: _LockedAdvancedStats(ap: ap)),
        const SizedBox(height: 56),
      ],
    );
  }

}


// ════════════════════════════════════════════════
// STATS HERO SECTION
// Combines orb + weekly stats chip row + coach
// insight into one continuous visual unit —
// replaces 3 separate cards to cut scroll depth.
// ════════════════════════════════════════════════
class _StatsHeroSection extends StatelessWidget {
  final AppProvider ap;
  const _StatsHeroSection({required this.ap});

  @override
  Widget build(BuildContext context) => Column(children: [
    const _OrbSection(),
    const SizedBox(height: AppSpacing.md),
    _HeroCompactPanel(ap: ap),
  ]);
}

class _HeroCompactPanel extends StatelessWidget {
  final AppProvider ap;
  const _HeroCompactPanel({required this.ap});

  static Color _rColor(WeekRating r) => switch (r) {
    WeekRating.excellent    => AppColors.gold,
    WeekRating.strong       => AppColors.goldSoft,
    WeekRating.solid        => AppColors.goldSoft,
    WeekRating.inconsistent => AppColors.textSecondary,
    WeekRating.recoveryWeek => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({
      WeeklyReviewData review,
      int recovery,
      String insightTitle,
      String badge,
      Color accent,
    })>(
      selector: (_, ap) => (
        review:       ap.weeklyReviewData,
        recovery:     ap.getOverallRecovery(),
        insightTitle: ap.coachInsight.title,
        badge:        ap.coachInsight.badge,
        accent:       ap.coachInsight.accentColor,
      ),
      builder: (ctx, d, __) {
        final c   = d.review.hasData ? _rColor(d.review.rating) : AppColors.gold;
        final msg = d.insightTitle.isNotEmpty ? d.insightTitle : '${d.recovery}% recovery — system online.';

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: AppColors.borderSoft.withValues(alpha: 0.12), width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Weekly stats row ────────────────────
            Row(children: [
              Expanded(child: _HeroStat(
                value: d.review.hasData
                    ? '${d.review.completedSessions}/${d.review.plannedSessions}' : '–',
                label: 'SESSIONS', color: c)),
              Container(width: 0.5, height: 28,
                  color: AppColors.borderSoft.withValues(alpha: 0.20)),
              Expanded(child: _HeroStat(
                value: d.review.hasData ? d.review.weekVolumeLabel : '–',
                label: 'LIFTED', color: c)),
              Container(width: 0.5, height: 28,
                  color: AppColors.borderSoft.withValues(alpha: 0.20)),
              Expanded(child: _HeroStat(
                value: d.review.hasData ? '${d.review.prCount}' : '–',
                label: 'PRs', color: c)),
            ]),

            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderSoft.withValues(alpha: 0.18),
                height: 1, thickness: 0.5),
            const SizedBox(height: AppSpacing.md),

            // ── Coach insight (2 lines) → tap opens AI chat ──
            GestureDetector(
              onTap: () {
                H.tap();
                Navigator.push(ctx, slideRoute(AIChatScreen(
                  seedContext: 'Recovery: ${d.recovery}%\nBadge: ${d.badge}\n${d.insightTitle}',
                )));
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Badge + arrow on its own row
                Row(children: [
                  if (d.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: d.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                            color: d.accent.withValues(alpha: 0.22), width: 0.5),
                      ),
                      child: Text(d.badge, style: TextStyle(
                        fontFamily: 'Inter',
                        color: d.accent.withValues(alpha: 0.80),
                        fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.7,
                      )),
                    ),
                  const Spacer(),
                  Text('Discuss with Coach', style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.45),
                    fontSize: 10, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded,
                    size: 11, color: AppColors.textMuted.withValues(alpha: 0.38)),
                ]),
                const SizedBox(height: 8),
                // Full message — typewriter reveal
                _TypewriterText(
                  text: msg,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12.5,
                    fontWeight: FontWeight.w400, height: 1.55)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HeroStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: GoogleFonts.rajdhani(
      color: AppColors.textPrimary, fontSize: 18,
      fontWeight: FontWeight.w700, height: 1.0)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.inter(
      color: AppColors.textMuted.withValues(alpha: 0.45),
      fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 0.9)),
  ]);
}


// ════════════════════════════════════════════════
// TYPEWRITER TEXT — character-by-character reveal.
// Restarts whenever text changes (didUpdateWidget).
// ════════════════════════════════════════════════
class _TypewriterText extends StatefulWidget {
  final String    text;
  final TextStyle style;
  const _TypewriterText({required this.text, required this.style});
  @override State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _visible = 0;
  static const _charDelayMs = 16;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(_TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      setState(() => _visible = 0);
      _startTyping();
    }
  }

  void _startTyping() {
    Future.delayed(const Duration(milliseconds: 300), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (_visible >= widget.text.length) return;
    setState(() => _visible++);
    Future.delayed(const Duration(milliseconds: _charDelayMs), _tick);
  }

  @override
  Widget build(BuildContext context) => Text(
    widget.text.substring(0, _visible.clamp(0, widget.text.length)),
    style: widget.style,
  );
}


class _StatsRecoveryRail extends StatefulWidget {
  final AppProvider ap;
  const _StatsRecoveryRail({required this.ap});
  @override State<_StatsRecoveryRail> createState() => _StatsRecoveryRailState();
}

class _StatsRecoveryRailState extends State<_StatsRecoveryRail>
    with TickerProviderStateMixin {
  late AnimationController _reveal;
  late AnimationController _pulse;
  late Animation<double>   _revealAnim;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _pulse  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _revealAnim = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 60),
        () { if (mounted) _reveal.forward(); });
  }

  @override
  void dispose() { _reveal.dispose(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const allMuscles = RecoveryGridData.muscles;
    final ap = widget.ap;

    // Only show muscles that are NOT fully primed (score < 80).
    // If all are primed, show a compact "all clear" row instead.
    final toShow = allMuscles
        .where((m) => ap.getMuscleRecovery(m.key).toInt() < 80)
        .toList();

    int limitingIdx = 0;
    int lowestScore = 101;
    for (int i = 0; i < toShow.length; i++) {
      final s = ap.getMuscleRecovery(toShow[i].key).toInt().clamp(0, 100);
      if (s < lowestScore) { lowestScore = s; limitingIdx = i; }
    }

    final systemLine  = ap.recoverySystemLine;
    final sleepLine   = ap.sleepContextLine;

    return AnimatedBuilder(
      animation: Listenable.merge([_revealAnim, _pulse]),
      builder: (buildCtx, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: AppColors.borderSoft.withValues(alpha: 0.10), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (systemLine.isNotEmpty) ...[
              Text(systemLine,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.38),
                  fontSize: 9.5, fontWeight: FontWeight.w500,
                  height: 1.4, letterSpacing: 0.1,
                  fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
            ],
            if (sleepLine.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.nightlight_round,
                  size: 9,
                  color: AppColors.textMuted.withValues(alpha: 0.30)),
                const SizedBox(width: 4),
                Expanded(child: Text(sleepLine,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.30),
                    fontSize: 9.0, fontWeight: FontWeight.w400,
                    height: 1.4, letterSpacing: 0.1,
                    fontStyle: FontStyle.italic))),
              ]),
              const SizedBox(height: 12),
            ],
            // All muscles primed — show single compact row
            if (toShow.isEmpty) ...[
              Row(children: [
                Icon(Icons.check_circle_rounded,
                  size: 14, color: AppColors.gold.withValues(alpha: 0.72)),
                const SizedBox(width: 8),
                Text('All muscles primed — ready to train.',
                  style: GoogleFonts.inter(
                    color: AppColors.gold.withValues(alpha: 0.72),
                    fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ],
            ...toShow.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            final score = ap.getMuscleRecovery(m.key).toInt().clamp(0, 100);
            final isLimiting = i == limitingIdx && lowestScore < 60;
            final recoveries = ap.muscleRecoveryList;
            final matches = recoveries.where(
                (r) => r.muscle.toLowerCase() == m.label.toLowerCase());
            final rec = matches.isEmpty ? null : matches.first;

            final scoreColor = score >= 70 ? AppColors.gold
                : score >= 40 ? AppColors.textSecondary : AppColors.textMuted;
            final lbl = score >= 80 ? 'PRIMED'
                : score >= 60 ? 'ADAPTING'
                : score >= 40 ? 'ELEVATED' : 'RECOVERING';

            final limitBorderAlpha = isLimiting
                ? 0.20 + 0.18 * _pulse.value : 0.0;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: i == toShow.length - 1 ? 0 : 14),
              child: GestureDetector(
                onTap: rec != null ? () {
                  H.tap();
                  MuscleCommandSheet.show(buildCtx, rec);
                } : null,
                child: Container(
                  padding: isLimiting
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 7)
                      : const EdgeInsets.symmetric(vertical: 4),
                  decoration: isLimiting ? BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: scoreColor.withValues(alpha: limitBorderAlpha),
                        width: 0.7),
                  ) : null,
                  child: Row(children: [
                    Icon(m.icon, size: 14,
                        color: isLimiting
                            ? scoreColor
                            : AppColors.textMuted.withValues(alpha: 0.50)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 66,
                      child: Text(m.label,
                        style: GoogleFonts.inter(
                          color: isLimiting
                              ? scoreColor.withValues(alpha: 0.90)
                              : AppColors.textSecondary,
                          fontSize: 10.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (score / 100) * _revealAnim.value,
                          minHeight: isLimiting ? 4 : 3,
                          backgroundColor:
                              scoreColor.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              scoreColor.withValues(alpha: 0.72)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$score',
                      style: GoogleFonts.rajdhani(
                        color: scoreColor, fontSize: 14.5,
                        fontWeight: FontWeight.w900, height: 1.0)),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 60,
                      child: Text(lbl,
                        style: GoogleFonts.inter(
                          color: scoreColor.withValues(alpha: 0.62),
                          fontSize: 8.0, fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                    ),
                  ]),
                ),
              ),
            );
          }),
          ],
        ),
      ),
    );
  }
}




// ════════════════════════════════════════════════
// WEEKLY VOLUME CURVE — Phase 17
// ════════════════════════════════════════════════
// BADGE RARITY SYSTEM
// ════════════════════════════════════════════════
enum _BadgeRarity { common, rare, elite, legendary }

class _Rarity {
  static _BadgeRarity of(String id) => switch (id) {
    'hundred_workouts' || 'month_streak' => _BadgeRarity.legendary,
    'fifty_workouts' || 'two_week_streak' ||
    'consistency'    || 'volume_king'    => _BadgeRarity.elite,
    'ten_workouts'   || 'week_streak'    ||
    'early_bird'     || 'pr_smasher'     => _BadgeRarity.rare,
    _ => _BadgeRarity.common,
  };

  static Color color(_BadgeRarity r) => switch (r) {
    _BadgeRarity.legendary => AppColors.gold,
    _BadgeRarity.elite     => AppColors.goldSoft,
    _BadgeRarity.rare      => AppColors.textSecondary,
    _BadgeRarity.common    => AppColors.textMuted,
  };

  static String label(_BadgeRarity r) => switch (r) {
    _BadgeRarity.legendary => 'LEGENDARY',
    _BadgeRarity.elite     => 'ELITE',
    _BadgeRarity.rare      => 'RARE',
    _BadgeRarity.common    => 'COMMON',
  };
}

// ════════════════════════════════════════════════
// BADGE LORE — editorial subtitles per badge id
// ════════════════════════════════════════════════
class _BadgeLore {
  static String of(String id) => switch (id) {
    'first_workout'    => 'The first rep of your journey.',
    'ten_workouts'     => 'Momentum begins here.',
    'fifty_workouts'   => 'Consistency carved into progress.',
    'hundred_workouts' => 'A century of commitment.',
    'week_streak'      => 'Seven unbroken days.',
    'two_week_streak'  => 'Fortnight of focused effort.',
    'month_streak'     => 'Thirty days, unbroken.',
    'early_bird'       => 'Morning sessions compound.',
    'pr_smasher'       => 'Limits exist to be broken.',
    'consistency'      => 'The most underrated trait.',
    'volume_king'      => 'Volume drives growth.',
    _                  => 'A milestone earned.',
  };
}

// ════════════════════════════════════════════════
// BADGES GRID
// ════════════════════════════════════════════════
class _BadgesGrid extends StatefulWidget {
  final AppProvider ap;
  const _BadgesGrid({required this.ap});
  @override
  State<_BadgesGrid> createState() => _BadgesGridState();
}

class _BadgesGridState extends State<_BadgesGrid> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final earned = widget.ap.streak.earnedBadges;
    // Sort: unlocked first (highest rarity first), then locked (highest rarity first)
    final sorted = List<AppBadge>.from(BadgeSystem.all)
      ..sort((a, b) {
        final aU = earned.contains(a.id);
        final bU = earned.contains(b.id);
        if (aU != bU) return aU ? -1 : 1;
        return _Rarity.of(b.id).index.compareTo(_Rarity.of(a.id).index);
      });
    final displayed = _showAll ? sorted : sorted.take(4).toList();

    return Column(children: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        childAspectRatio: 0.88,
        children: displayed
            .map((b) => _GridBadge(
                b: b, unlocked: earned.contains(b.id), ap: widget.ap))
            .toList(),
      ),
      if (BadgeSystem.all.length > 4)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showAll = !_showAll);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                _showAll ? 'Show Less' : 'View All Achievements',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.textMuted,
                size: 15,
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _GridBadge extends StatelessWidget {
  final AppBadge    b;
  final bool        unlocked;
  final AppProvider ap;
  const _GridBadge({required this.b, required this.unlocked, required this.ap});

  // Returns [current, required] for trackable badges; null for others.
  List<int>? _progress() {
    final total  = ap.streak.totalWorkouts;
    final streak = ap.streak.currentStreak;
    switch (b.id) {
      case 'first_workout':    return [total.clamp(0, 1),   1];
      case 'ten_workouts':     return [total.clamp(0, 10),  10];
      case 'fifty_workouts':   return [total.clamp(0, 50),  50];
      case 'hundred_workouts': return [total.clamp(0, 100), 100];
      case 'week_streak':      return [streak.clamp(0, 7),  7];
      case 'two_week_streak':  return [streak.clamp(0, 14), 14];
      case 'month_streak':     return [streak.clamp(0, 30), 30];
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarity      = _Rarity.of(b.id);
    final rarityColor = _Rarity.color(rarity);

    if (unlocked) {
      final isLegendary = rarity == _BadgeRarity.legendary;
      final isElite     = rarity == _BadgeRarity.elite;

      // Multi-layer depth shadows — luxury collectible feel
      final shadows = isLegendary ? [
        BoxShadow(color: rarityColor.withValues(alpha: 0.40),
            blurRadius: 28, spreadRadius: 2),
        BoxShadow(color: rarityColor.withValues(alpha: 0.12),
            blurRadius: 54, spreadRadius: 4),
      ] : isElite ? [
        BoxShadow(color: rarityColor.withValues(alpha: 0.26),
            blurRadius: 16, spreadRadius: 1),
        BoxShadow(color: rarityColor.withValues(alpha: 0.06),
            blurRadius: 30, spreadRadius: 0),
      ] : rarity == _BadgeRarity.rare ? [
        BoxShadow(color: rarityColor.withValues(alpha: 0.16),
            blurRadius: 10, spreadRadius: 1),
      ] : [
        BoxShadow(color: rarityColor.withValues(alpha: 0.06),
            blurRadius: 6),
      ];

      // Metallic gradient for legendary + elite; subtle for rare/common
      final useGradient = isLegendary || isElite;

      final badgeIcon = Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 66, height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: useGradient ? [
                  rarityColor.withValues(alpha: isLegendary ? 0.24 : 0.14),
                  rarityColor.withValues(alpha: isLegendary ? 0.07 : 0.04),
                ] : [
                  rarityColor.withValues(alpha: 0.09),
                  rarityColor.withValues(alpha: 0.04),
                ]),
              border: Border.all(
                color: rarityColor.withValues(
                    alpha: isLegendary ? 0.58 : isElite ? 0.38 : 0.22),
                width: isLegendary ? 1.2 : 0.8),
              boxShadow: shadows,
            ),
            child: Center(child: Icon(b.icon, size: 28, color: rarityColor)),
          ),
          // Specular highlight — top half metallic sheen
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              width: 66, height: 33,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(
                        alpha: isLegendary ? 0.10 : isElite ? 0.06 : 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-edge ambient lighting for legendary + elite
          if (isLegendary || isElite)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22)),
              child: Container(
                width: 66, height: 24,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [
                      rarityColor.withValues(
                          alpha: isLegendary ? 0.20 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

      return Column(mainAxisSize: MainAxisSize.min, children: [
        isLegendary
            ? _PulseGlow(color: rarityColor,
                child: _LegendaryShimmer(color: rarityColor, child: badgeIcon))
            : badgeIcon,
        const SizedBox(height: 5),
        Text(b.title,
            style: GoogleFonts.inter(
                color: rarityColor, fontSize: 8.5, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(_Rarity.label(rarity),
            style: GoogleFonts.inter(
                color: rarityColor.withValues(alpha: 0.50),
                fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(_BadgeLore.of(b.id),
            style: GoogleFonts.inter(
                color: AppColors.textMuted.withValues(alpha: 0.38),
                fontSize: 6.5, fontStyle: FontStyle.italic, height: 1.3),
            textAlign: TextAlign.center, maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]);
    }

    final prog = _progress();
    final frac = prog != null && prog[1] > 0 ? prog[0] / prog[1] : 0.0;

    // Locked — hidden reward silhouette, minimal mystery
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 66, height: 66,
        child: Stack(children: [
          // Dark embossed base
          Container(
            width: 66, height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05), width: 0.5),
            ),
            child: Center(child: Icon(
              b.icon, size: 25,
              color: AppColors.textMuted.withValues(alpha: 0.09),
            )),
          ),
          // Progress fill — bottom edge only
          if (prog != null && frac > 0)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22)),
                child: LinearProgressIndicator(
                  value: frac, minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                      AppColors.textMuted.withValues(alpha: 0.18)),
                ),
              ),
            ),
          // Tiny lock icon — bottom-right corner
          Positioned(
            bottom: 7, right: 7,
            child: Icon(Icons.lock_rounded, size: 10,
                color: Colors.white.withValues(alpha: 0.10)),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      Text(b.title,
          style: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.24),
              fontSize: 8.5, fontWeight: FontWeight.w400),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text('LOCKED', style: GoogleFonts.inter(
          color: AppColors.textMuted.withValues(alpha: 0.14),
          fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    ]);
  }
}

// ════════════════════════════════════════════════
// BADGES HORIZONTAL SCROLL
// Single-row swipeable strip — replaces the
// vertical grid to eliminate ~200px of scroll.
// ════════════════════════════════════════════════
class _BadgesHScroll extends StatelessWidget {
  final AppProvider ap;
  const _BadgesHScroll({required this.ap});

  // Returns "N sessions" / "N days" remaining, or null for non-trackable badges.
  static String? _remaining(AppBadge b, StreakData s) {
    final total  = s.totalWorkouts;
    final streak = s.currentStreak;
    int? rem;
    bool isDay = false;
    switch (b.id) {
      case 'first_workout':    rem = (1  - total).clamp(0, 1);   break;
      case 'ten_workouts':     rem = (10  - total).clamp(0, 10); break;
      case 'fifty_workouts':   rem = (50  - total).clamp(0, 50); break;
      case 'hundred_workouts': rem = (100 - total).clamp(0, 100); break;
      case 'week_streak':      rem = (7  - streak).clamp(0, 7);  isDay = true; break;
      case 'two_week_streak':  rem = (14 - streak).clamp(0, 14); isDay = true; break;
      case 'month_streak':     rem = (30 - streak).clamp(0, 30); isDay = true; break;
      default: return null;
    }
    if (rem <= 0) return null;
    return '$rem ${isDay ? (rem == 1 ? 'day' : 'days') : (rem == 1 ? 'session' : 'sessions')} away';
  }

  @override
  Widget build(BuildContext context) {
    final earned = ap.streak.earnedBadges;
    // Earned first (highest rarity), then locked (highest rarity)
    final sorted = List<AppBadge>.from(BadgeSystem.all)
      ..sort((a, b) {
        final aU = earned.contains(a.id);
        final bU = earned.contains(b.id);
        if (aU != bU) return aU ? -1 : 1;
        return _Rarity.of(b.id).index.compareTo(_Rarity.of(a.id).index);
      });

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final b        = sorted[i];
          final unlocked = earned.contains(b.id);
          final rarity   = _Rarity.of(b.id);
          final color    = _Rarity.color(rarity);
          final progress = unlocked ? null : _remaining(b, ap.streak);

          return SizedBox(
            width: 72,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Badge icon container
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: unlocked
                      ? color.withValues(alpha: 0.12)
                      : const Color(0xFF0B0B0B),
                  border: Border.all(
                    color: unlocked
                        ? color.withValues(alpha: rarity == _BadgeRarity.legendary ? 0.55 : 0.30)
                        : Colors.white.withValues(alpha: 0.05),
                    width: unlocked && rarity == _BadgeRarity.legendary ? 1.2 : 0.7,
                  ),
                  boxShadow: unlocked && rarity.index >= _BadgeRarity.elite.index
                      ? [BoxShadow(
                          color: color.withValues(alpha: rarity == _BadgeRarity.legendary ? 0.36 : 0.20),
                          blurRadius: rarity == _BadgeRarity.legendary ? 24 : 12,
                          spreadRadius: 1)]
                      : null,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(b.icon, size: 24,
                    color: unlocked
                        ? color
                        : AppColors.textMuted.withValues(alpha: 0.10)),
                  if (!unlocked)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Icon(Icons.lock_rounded, size: 9,
                          color: Colors.white.withValues(alpha: 0.10)),
                    ),
                ]),
              ),
              const SizedBox(height: 5),
              Text(b.title,
                style: GoogleFonts.inter(
                  color: unlocked
                      ? color
                      : AppColors.textMuted.withValues(alpha: 0.24),
                  fontSize: 8, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (unlocked)
                Text(_Rarity.label(rarity),
                  style: GoogleFonts.inter(
                    color: color.withValues(alpha: 0.48),
                    fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.7))
              else if (progress != null)
                Text(progress,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.38),
                    fontSize: 6.5, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
              else
                Text('LOCKED',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.18),
                    fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ]),
          );
        },
      ),
    );
  }
}


// ════════════════════════════════════════════════
// PREDICTIVE FORWARD INTELLIGENCE CARD
// Shows forward-looking data: next PR window,
// limiting muscle ETA, next workout, week target.
// Hidden when all forward data is empty.
// ════════════════════════════════════════════════
class _PredictiveForwardCard extends StatelessWidget {
  final AppProvider ap;
  const _PredictiveForwardCard({required this.ap});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({
      String nextPR,
      String nextWorkout,
      String etaMuscle,
      int    etaHours,
      int    completed,
      int    planned,
    })>(
      selector: (_, ap) {
        final eta = ap.limitingMuscleEta;
        final wr  = ap.weeklyReviewData;
        return (
          nextPR:      ap.nextPRWindow,
          nextWorkout: ap.nextWorkoutTitle,
          etaMuscle:   eta.muscle,
          etaHours:    eta.hours,
          completed:   wr.completedSessions,
          planned:     wr.plannedSessions,
        );
      },
      builder: (ctx, d, __) {
        // Only show when at least one forward signal exists
        final hasPR      = d.nextPR.isNotEmpty;
        final hasWorkout = d.nextWorkout.isNotEmpty;
        final hasEta     = d.etaHours > 1 && d.etaMuscle.isNotEmpty;
        final hasSession = d.planned > 0;
        if (!hasPR && !hasWorkout && !hasEta && !hasSession) {
          return const SizedBox.shrink();
        }

        // Cap muscle name
        String cap(String s) => s.isEmpty ? s
            : '${s[0].toUpperCase()}${s.substring(1)}';

        final remaining = (d.planned - d.completed).clamp(0, d.planned);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D09),
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.10),
                AppColors.bgCard,
                const Color(0xFF0D0D09),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.50, 1.0],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.18), width: 0.7),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg - 0.5),
            child: Stack(children: [
              // Left accent beam
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.gold.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Header
                  Row(children: [
                    Icon(Icons.arrow_outward_rounded,
                      size: 11, color: AppColors.gold.withValues(alpha: 0.75)),
                    const SizedBox(width: 6),
                    Text('FORWARD INTELLIGENCE', style: GoogleFonts.inter(
                      color: AppColors.gold.withValues(alpha: 0.72),
                      fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  ]),
                  const SizedBox(height: 12),

                  // Intelligence rows
                  if (hasPR) ...[
                    _ForwardRow(
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.gold,
                      label: 'Next PR window',
                      value: d.nextPR,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasEta) ...[
                    _ForwardRow(
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.orange,
                      label: '${cap(d.etaMuscle)} clears in',
                      value: '~${d.etaHours}h${hasWorkout ? ' · ${d.nextWorkout} positioned' : ''}',
                    ),
                    const SizedBox(height: 8),
                  ] else if (hasWorkout) ...[
                    _ForwardRow(
                      icon: Icons.fitness_center_rounded,
                      color: AppColors.gold,
                      label: 'Next session',
                      value: d.nextWorkout,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasSession)
                    _ForwardRow(
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.goldSoft,
                      label: 'Week target',
                      value: '${d.completed}/${d.planned} done${remaining > 0 ? ' · $remaining remaining' : ' · complete'}',
                    ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ForwardRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  const _ForwardRow({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 11, color: color.withValues(alpha: 0.70)),
      ),
      const SizedBox(width: 8),
      Expanded(child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$label  ', style: GoogleFonts.inter(
            color: AppColors.textMuted.withValues(alpha: 0.50),
            fontSize: 11.5, fontWeight: FontWeight.w400, height: 1.4)),
          TextSpan(text: value, style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4)),
        ]),
      )),
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
    if (ap.isPremium) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Advanced Analytics', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFB8860B)],
            ),
          ),
          child: Text('PRO', style: GoogleFonts.inter(
              color: Colors.black, fontSize: 7.5,
              fontWeight: FontWeight.w900, letterSpacing: 0.6)),
        ),
      ]),
      const SizedBox(height: 12),

      GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          PaywallSheet.show(context,
            trigger: PaywallTrigger.advancedStatsTap,
            onUpgrade: () => ap.refreshMonetization(),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.gold, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Premium Analytics', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('See exactly what\'s limiting your progress',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _ProChip('Fatigue Index'),
                _ProChip('Plateau Detection'),
                _ProChip('Weak Muscle Analysis'),
                _ProChip('Strength Trends'),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: AppGradients.gold,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.28),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Text('Unlock Advanced Analytics',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                      color: Colors.black, fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ),
    ]);
  }
}



class _ProChip extends StatelessWidget {
  final String label;
  const _ProChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
    ),
    child: Text(label, style: GoogleFonts.inter(
        color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
  );
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

        if (_selected == null) {
          final lastLogged = logs.isNotEmpty ? logs.last.exercise : null;
          _selected = (lastLogged != null && exerciseNames.contains(lastLogged))
              ? lastLogged : exerciseNames.first;
        }
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
                  return _TapScale(
                    onTap: () {
                      H.tap();
                      setState(() => _selected = name);
                    },
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
                          fontSize: 10.5,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_selected != null)
              _ExerciseChart(ap: ap, exKey: _selected!),

            // ── Exercise Mastery (moved from Overview) ──
            const SizedBox(height: AppSpacing.lg),
            const _Label(text: 'Exercise Mastery'),
            const SizedBox(height: AppSpacing.sm),
            _MovementMasterySection(ap: ap),
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
    final allLogs = ap.logs
        .where((l) => l.exercise == exKey)
        .toList()..sort((a, b) => a.date.compareTo(b.date));
    final hasWeight = allLogs.any((l) => l.weight > 0);
    final exLogs = hasWeight
        ? allLogs.where((l) => l.weight > 0).toList()
        : allLogs.where((l) => l.reps > 0).toList();

    final pr    = ap.getPR(exKey, 'kg');
    final trend = ap.getStrengthTrend(exKey);

    final tColor = trend == 'improving' ? AppColors.gold
        : trend == 'declining' ? AppColors.orange : AppColors.textMuted;
    final tLabel = trend == 'improving' ? 'Improving'
        : trend == 'declining' ? 'Declining' : 'Plateau';
    final tIcon  = trend == 'improving' ? Icons.trending_up_rounded
        : trend == 'declining' ? Icons.trending_down_rounded
        : Icons.remove_rounded;

    if (exLogs.length < 2) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.show_chart_rounded,
              size: 40, color: AppColors.goldMuted),
          const SizedBox(height: AppSpacing.sm),
          Text('Strength patterns emerge through repetition', style: AppTextStyles.h4),
          const SizedBox(height: AppSpacing.xs),
          Text('Consistency creates the data that shapes your progression.',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 10.5,
                  height: 1.55), textAlign: TextAlign.center),
        ])),
      );
    }

    final spots = exLogs.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(),
            hasWeight ? e.value.weight : e.value.reps.toDouble()))
        .toList();
    final rawMin = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final rawMax = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yRange   = (rawMax - rawMin).clamp(10.0, double.infinity);
    final yInterval = yRange <= 20 ? 5.0 : yRange <= 60 ? 10.0 : yRange <= 120 ? 20.0 : 25.0;
    // Snap minY/maxY to clean multiples of yInterval so no crowded end labels
    final minY = ((rawMin * 0.92) / yInterval).floor() * yInterval;
    final maxY = ((rawMax * 1.08) / yInterval).ceil()  * yInterval;

    // Date label helpers
    final lastIdx = exLogs.length - 1;
    final midIdx  = lastIdx ~/ 2;
    String fmtDate(DateTime d) {
      const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${mo[d.month - 1]} ${d.day}';
    }

    return _FI(child: Container(
      padding: const EdgeInsets.all(14),
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
              Text('Best: ', style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12)),
              Text(
                hasWeight ? '${pr}kg'
                    : '${exLogs.map((l) => l.reps).reduce((a, b) => a > b ? a : b)} reps',
                style: GoogleFonts.rajdhani(
                    color: AppColors.gold, fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.emoji_events_rounded,
                  size: 14, color: AppColors.goldSoft),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tIcon, size: 11, color: tColor),
              const SizedBox(width: 3),
              Text(tLabel, style: GoogleFonts.inter(
                  color: tColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          ),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 192,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 0.5)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                interval: yInterval,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                  return Text('${v.toInt()}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 9));
                },
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i > lastIdx) return const SizedBox.shrink();
                  // show only first, mid, and last; skip mid if it coincides
                  if (i == midIdx && (midIdx == 0 || midIdx == lastIdx)) {
                    return const SizedBox.shrink();
                  }
                  if (i != 0 && i != midIdx && i != lastIdx) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(fmtDate(exLogs[i].date),
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 7.5, fontWeight: FontWeight.w500)),
                  );
                },
              )),
              topTitles:    const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles:  const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: spots, isCurved: true, curveSmoothness: 0.40,
              color: AppColors.gold, barWidth: 2.0,
              dotData: FlDotData(getDotPainter: (s, _, __, idx) {
                final isLast = idx == spots.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 6.0 : 2.8,
                  color: isLast ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.45),
                  strokeWidth: isLast ? 2.0 : 0,
                  strokeColor: AppColors.bg,
                );
              }),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.22),
                    AppColors.gold.withValues(alpha: 0.04),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            )],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF161610),
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                getTooltipItems: (spots) => spots.map((s) {
                  final idx = s.x.toInt();
                  final dateLabel = (idx >= 0 && idx < exLogs.length)
                      ? fmtDate(exLogs[idx].date) : '';
                  final valStr = hasWeight
                      ? '${s.y.toStringAsFixed(1)} kg'
                      : '${s.y.toInt()} reps';
                  return LineTooltipItem(
                    '$dateLabel\n$valStr',
                    GoogleFonts.inter(
                      color: AppColors.gold, fontSize: 10,
                      fontWeight: FontWeight.w700, height: 1.35),
                  );
                }).toList(),
              ),
            ),
          )),
        ),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════
// HISTORY TAB — week-grouped with evolution headers
// ════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  static DateTime _monday(DateTime d) {
    final wd = d.weekday;
    return DateTime(d.year, d.month, d.day - (wd - 1));
  }

  static String _fmtWeekHeader(DateTime monday) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final sunday = monday.add(const Duration(days: 6));
    final mStr = '${months[monday.month - 1]} ${monday.day}';
    final sStr = '${months[sunday.month - 1]} ${sunday.day}';
    return '$mStr – $sStr';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({List<HistoryEntry> history, String identity})>(
      selector: (_, ap) => (
        history:  ap.history,
        identity: ap.athleteIdentitySummary,
      ),
      builder: (_, d, __) {
        if (d.history.isEmpty) return const EmptyHistory();

        // Volume threshold for "high volume" marker
        final vols = d.history.map((h) => h.totalVolume).where((v) => v > 0).toList();
        final avgVol = vols.isEmpty ? 0.0 : vols.reduce((a, b) => a + b) / vols.length;
        final highVolThresh = avgVol * 1.25;

        // Group history by ISO week Monday
        final Map<DateTime, List<HistoryEntry>> weekGroups = {};
        for (final entry in d.history) {
          final parsed = DateTime.tryParse(entry.date) ?? DateTime.now();
          final mon = _monday(parsed);
          weekGroups.putIfAbsent(mon, () => []).add(entry);
        }
        // Sort weeks newest first (for display), oldest first (for milestone calc)
        final sortedWeeks = weekGroups.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        final chronoWeeks = List<DateTime>.from(sortedWeeks)
          ..sort((a, b) => a.compareTo(b));

        // ── Milestone detection ───────────────────────────────────────
        // "First Consistent Week": oldest week with 3+ sessions
        DateTime? firstConsistentWeek;
        for (final mon in chronoWeeks) {
          if ((weekGroups[mon]?.length ?? 0) >= 3) {
            firstConsistentWeek = mon;
            break;
          }
        }
        // "First Overload Week": oldest week where any session is high volume
        DateTime? firstOverloadWeek;
        final allVols = d.history.map((h) => h.totalVolume).where((v) => v > 0).toList();
        final overloadThresh = allVols.isEmpty
            ? double.infinity
            : allVols.reduce((a, b) => a + b) / allVols.length * 1.30;
        for (final mon in chronoWeeks) {
          if (weekGroups[mon]!.any((e) => e.totalVolume >= overloadThresh)) {
            firstOverloadWeek = mon;
            break;
          }
        }
        // "Comeback": oldest week where gap to previous week's entries > 7 days
        DateTime? firstComebackWeek;
        for (int i = 1; i < chronoWeeks.length; i++) {
          final prevWeekMon  = chronoWeeks[i - 1];
          final prevEntries  = weekGroups[prevWeekMon]!;
          final gapStart     = prevEntries
              .map((e) => DateTime.tryParse(e.date) ?? prevWeekMon)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final thisWeekMon  = chronoWeeks[i];
          final gap = thisWeekMon.difference(gapStart).inDays;
          if (gap >= 8) { firstComebackWeek = thisWeekMon; break; }
        }

        // Build flat list: [identity?], [weekHeader, ...entries] per week
        final items = <Object>[];
        if (d.identity.isNotEmpty) items.add(_IdentityMarker(d.identity));
        for (final mon in sortedWeeks) {
          items.add(_WeekHeader(mon));
          items.addAll(weekGroups[mon]!);
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          itemCount: items.length,
          separatorBuilder: (_, i) {
            // No gap before week header
            if (i < items.length - 1 && items[i + 1] is _WeekHeader) {
              return const SizedBox(height: AppSpacing.lg);
            }
            return const SizedBox(height: AppSpacing.sm);
          },
          itemBuilder: (ctx, i) {
            final item = items[i];
            if (item is _IdentityMarker) {
              return _AthleteIdentityCard(summary: item.summary);
            }
            if (item is _WeekHeader) {
              final String ms = item.monday == firstConsistentWeek
                  ? 'First Consistent Week'
                  : item.monday == firstComebackWeek
                      ? 'First Comeback'
                      : item.monday == firstOverloadWeek
                          ? 'First Overload Week'
                          : '';
              return _WeekGroupHeader(
                  label: _fmtWeekHeader(item.monday), milestone: ms);
            }
            final entry = item as HistoryEntry;
            final entryIdx = d.history.indexOf(entry);
            final isHighVol = highVolThresh > 0 && entry.totalVolume >= highVolThresh;
            final isShort   = entry.durationMinutes > 0 && entry.durationMinutes <= 25;
            return _HistoryCard(
              entry: entry,
              isHighVolume: isHighVol,
              isShortSession: isShort,
              isFirst: entryIdx == d.history.length - 1,
            );
          },
        );
      },
    );
  }
}

// Marker types for the flat item list
class _IdentityMarker { final String summary; const _IdentityMarker(this.summary); }
class _WeekHeader { final DateTime monday; const _WeekHeader(this.monday); }

class _WeekGroupHeader extends StatelessWidget {
  final String label;
  final String milestone; // '' = none, else "First Consistent Week" etc.
  const _WeekGroupHeader({required this.label, this.milestone = ''});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 2.5, height: 12,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 10),
    Text(label.toUpperCase(), style: GoogleFonts.inter(
      color: AppColors.textMuted.withValues(alpha: 0.60),
      fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
    if (milestone.isNotEmpty) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28), width: 0.6),
        ),
        child: Text(milestone, style: GoogleFonts.inter(
          color: AppColors.gold, fontSize: 8.5,
          fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      ),
    ],
  ]);
}

class _AthleteIdentityCard extends StatelessWidget {
  final String summary;
  const _AthleteIdentityCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_outline_rounded,
              color: AppColors.gold, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ATHLETE PROFILE', style: GoogleFonts.inter(
              color: AppColors.gold, fontSize: 8.5, fontWeight: FontWeight.w800,
              letterSpacing: 0.9)),
          const SizedBox(height: 3),
          Text(summary, style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 12,
              fontWeight: FontWeight.w400, height: 1.4)),
        ])),
      ]),
    );
  }
}

// Maps workout name to accent colour for icon container.
Color _sessionAccent(String name) => AppColors.gold;

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final bool isHighVolume;
  final bool isShortSession;
  final bool isFirst;
  const _HistoryCard({
    required this.entry,
    this.isHighVolume   = false,
    this.isShortSession = false,
    this.isFirst        = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _sessionAccent(entry.workoutName);
    final volText = entry.totalVolume >= 1000
        ? '${(entry.totalVolume / 1000).toStringAsFixed(1)}t'
        : '${entry.totalVolume.toStringAsFixed(0)}kg';

    // Milestone marker (only one shown per card, priority order)
    final (milestoneLabel, milestoneColor) = isFirst
        ? ('First Session', AppColors.gold)
        : isHighVolume
            ? ('High Volume', AppColors.gold)
            : isShortSession
                ? ('Short Session', AppColors.textMuted)
                : ('', AppColors.textMuted);

    return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: isFirst
                ? AppColors.gold.withValues(alpha: 0.30)
                : AppColors.borderSoft,
            width: isFirst ? 0.8 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: accent.withValues(alpha: 0.22), width: 0.7),
            ),
            child: Icon(Icons.fitness_center_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.workoutName, style: AppTextStyles.h4,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text('${entry.exerciseCount} exercises',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
              if (entry.durationMinutes > 0) ...[
                Text(' · ', style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 11)),
                Text('${entry.durationMinutes}min',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ]),
            if (milestoneLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: milestoneColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: milestoneColor.withValues(alpha: 0.28), width: 0.6),
                ),
                child: Text(milestoneLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: milestoneColor, fontSize: 8.5,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ],
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(entry.date, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            if (entry.totalVolume > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.20), width: 0.5),
                ),
                child: Text(volText, style: GoogleFonts.rajdhani(
                    color: accent, fontSize: 11,
                    fontWeight: FontWeight.w800)),
              ),
            if (entry.xpEarned > 0) ...[
              const SizedBox(height: 3),
              Text('+${entry.xpEarned} XP', style: AppTextStyles.goldSmall),
            ],
          ]),
        ]),
      );
  }
}

// ════════════════════════════════════════════════
// ONBOARDING EVOLUTION SECTION — Phase 15
// Shown only during early onboarding (< 3 sessions / 7 days).
// Surfaces behavioral signals detected so far — calm, non-alarming.
// ════════════════════════════════════════════════
class _OnboardingEvolutionSection extends StatelessWidget {
  final AppProvider ap;
  const _OnboardingEvolutionSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final narrative = ap.onboardingNarrative;
    final signals   = ap.onboardingSignals;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.12), width: 0.7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.goldSoft, size: 13),
          const SizedBox(width: 8),
          Text('ADAPTING TO YOU', style: GoogleFonts.inter(
            color: AppColors.gold.withValues(alpha: 0.68),
            fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: AppSpacing.md),
        // Narrative
        if (narrative.isNotEmpty) ...[
          Text(narrative, style: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 12.5,
            fontWeight: FontWeight.w400, height: 1.5,
            fontStyle: FontStyle.italic)),
          const SizedBox(height: AppSpacing.md),
        ],
        // Signal chips (max 3)
        if (signals.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6,
            children: signals.take(3).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.18), width: 0.6),
              ),
              child: Text(s, style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 9.5,
                fontWeight: FontWeight.w600)),
            )).toList()),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// FATIGUE vs PROGRESSION OVERLAY — Phase 14/19.5
// Animated adaptive accent — alive, not static.
// Fatigue dominant → amber. Progression → gold.
// Balanced → emerald-gold blend.
// ════════════════════════════════════════════════
class _FatigueProgressionCard extends StatefulWidget {
  final AppProvider ap;
  const _FatigueProgressionCard({required this.ap});
  @override
  State<_FatigueProgressionCard> createState() => _FatigueProgressionCardState();
}

class _FatigueProgressionCardState extends State<_FatigueProgressionCard>
    with TickerProviderStateMixin {
  late AnimationController _pulse;
  late AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _pulse  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _reveal = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() { _pulse.dispose(); _reveal.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fatigue     = widget.ap.weeklyFatiguePressure.clamp(0.0, 100.0);
    final progression = widget.ap.weeklyProgressionScore.clamp(0.0, 100.0);

    final fatColor = fatigue >= 65 ? AppColors.orange
        : fatigue >= 40 ? AppColors.textSecondary
        : AppColors.textMuted;
    final progColor = progression >= 65 ? AppColors.gold
        : progression >= 40 ? AppColors.goldSoft
        : AppColors.textMuted;

    // Adaptive accent tint
    final accentColor = fatigue >= 65
        ? AppColors.orange
        : AppColors.gold;

    // Which metric is dominant for emphasis
    final fatigueIsDominant = fatigue >= progression;

    // Phase label — system interpretation of current state
    final phaseLabel = _phaseLabel(fatigue, progression);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _reveal]),
      builder: (_, __) {
        final p  = _pulse.value;
        final rv = CurvedAnimation(
            parent: _reveal, curve: Curves.easeOutCubic).value;
        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppSpacing.lg),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.08 + 0.07 * p),
                width: 0.7),
              boxShadow: [BoxShadow(
                color: accentColor.withValues(alpha: 0.03 + 0.03 * p),
                blurRadius: 18, spreadRadius: 0)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── AI phase indicator ───────────────────────────
              Row(children: [
                // Pulsing AI presence dot
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.62 + 0.38 * p),
                    boxShadow: [BoxShadow(
                      color: accentColor.withValues(alpha: 0.28 + 0.24 * p),
                      blurRadius: 3 + 4 * p)],
                  ),
                ),
                const SizedBox(width: 7),
                Text(phaseLabel, style: GoogleFonts.inter(
                  color: accentColor.withValues(alpha: 0.70 + 0.16 * p),
                  fontSize: 7.5, fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
                const Spacer(),
                Text('WEEKLY BREAKDOWN', style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.32),
                  fontSize: 7, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 14),

              // ── Narrative — primary emotional focus ──────────
              Text(
                _insight(fatigue, progression),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary.withValues(alpha: 0.86),
                  fontSize: 14, fontWeight: FontWeight.w300, height: 1.65),
              ),
              const SizedBox(height: 16),

              // ── Metrics — secondary support signals ──────────
              Row(children: [
                Expanded(child: _EvoMetric(
                  label: 'Fatigue Pressure',
                  value: fatigue,
                  color: fatColor,
                  inverse: true,
                  dominant: fatigueIsDominant,
                  revealProgress: rv,
                )),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _EvoMetric(
                  label: 'Progression Score',
                  value: progression,
                  color: progColor,
                  inverse: false,
                  dominant: !fatigueIsDominant,
                  revealProgress: rv,
                )),
              ]),
              const SizedBox(height: AppSpacing.md),

              // ── Micro balance rail ────────────────────────────
              _MicroTrendRail(
                fatigue: fatigue / 100,
                progression: progression / 100,
                accentColor: accentColor,
                revealProgress: rv,
                pulseValue: p,
              ),
            ]),
          ),
        );
      },
    );
  }

  static String _phaseLabel(double fatigue, double progression) {
    if (fatigue >= 65 && progression >= 55) return 'RECOVERY NEEDED';
    if (fatigue >= 65) return 'RECOVERY FOCUS';
    if (progression >= 65 && fatigue < 40) return 'PUSH PHASE';
    return 'BUILDING PHASE';
  }

  static String _insight(double fatigue, double progression) {
    if (fatigue >= 65 && progression >= 55) {
      return 'Fatigue and output are rising together. Protect recovery before adding further stimulus.';
    }
    if (fatigue >= 65) {
      return 'Fatigue pressure is elevated. Technical precision will serve you better than intensity right now.';
    }
    if (progression >= 65 && fatigue < 40) {
      return 'Your system is absorbing load efficiently. Conditions are aligned for deliberate progress.';
    }
    if (progression < 35) {
      return 'Adaptation is quieter this week. Consistent effort compounds even when output feels flat.';
    }
    return 'Your recent training rhythm remains stable. Recovery is absorbing load efficiently.';
  }
}

// Micro trend rail — 7 animated gradient segments showing balance
class _MicroTrendRail extends StatelessWidget {
  final double fatigue, progression, revealProgress, pulseValue;
  final Color  accentColor;
  const _MicroTrendRail({
    required this.fatigue,    required this.progression,
    required this.accentColor, required this.revealProgress,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    const segments = 7;
    // How many segments lit from left (fatigue) vs right (progression)
    final fatSegs  = (fatigue     * segments * revealProgress).round().clamp(0, segments);
    final progSegs = (progression * segments * revealProgress).round().clamp(0, segments);

    return Row(
      children: List.generate(segments, (i) {
        final fromLeft  = i < fatSegs;
        final fromRight = (segments - 1 - i) < progSegs;
        final lit = fromLeft || fromRight;
        final segColor = fromLeft
            ? (fatigue >= 65 ? AppColors.orange : AppColors.gold)
            : accentColor;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < segments - 1 ? 3 : 0),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: lit
                  ? segColor.withValues(alpha: 0.55 + 0.18 * pulseValue)
                  : AppColors.borderSoft.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

class _EvoMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final bool   inverse;
  final bool   dominant;
  final double revealProgress;
  const _EvoMetric({
    required this.label,   required this.value,
    required this.color,   required this.inverse,
    this.dominant = false, this.revealProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Metrics are now secondary support signals — kept smaller
    final numSize = dominant ? 20.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('${value.round()}', style: GoogleFonts.rajdhani(
            color: color, fontSize: numSize, fontWeight: FontWeight.w900,
            height: 1.0)),
          Text('%', style: GoogleFonts.inter(
            color: color.withValues(alpha: dominant ? 0.75 : 0.55),
            fontSize: dominant ? 11 : 9, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value / 100) * revealProgress,
            minHeight: dominant ? 2.5 : 2.0,
            backgroundColor: AppColors.divider.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(
                color.withValues(alpha: dominant ? 0.80 : 0.55)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted.withValues(alpha: dominant ? 0.65 : 0.45),
          fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// MOVEMENT MASTERY SECTION
// ════════════════════════════════════════════════
class _MovementMasterySection extends StatefulWidget {
  final AppProvider ap;
  const _MovementMasterySection({required this.ap});
  @override
  State<_MovementMasterySection> createState() => _MovementMasterySectionState();
}

class _MovementMasterySectionState extends State<_MovementMasterySection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final mastery = widget.ap.movementMastery;
    if (mastery.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Column(children: [
          const Icon(Icons.bar_chart_rounded, color: AppColors.goldMuted, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your first few sessions teach LiftOn how your body adapts.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12, height: 1.55),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    final sorted = List<ExerciseMastery>.from(mastery)
      ..sort((a, b) => b.masteryScore.compareTo(a.masteryScore));
    final displayed = _showAll ? sorted : sorted.take(1).toList();

    return Column(children: [
      ...displayed.map((m) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _MasteryCard(mastery: m),
      )),
      if (mastery.length > 1)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showAll = !_showAll);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                _showAll ? 'Show Less' : 'View All Movement Intelligence',
                style: GoogleFonts.inter(
                  color: AppColors.gold.withValues(alpha: 0.65),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.gold.withValues(alpha: 0.65),
                size: 15,
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _MasteryCard extends StatelessWidget {
  final ExerciseMastery mastery;
  const _MasteryCard({required this.mastery});

  static (String, Color) _statusBadge(double score, String trend) {
    if (trend == 'improving' && score >= 80) return ('EXPLOSIVE',   AppColors.gold);
    if (trend == 'improving' && score >= 70) return ('PEAKING',     AppColors.gold);
    if (trend == 'improving' && score >= 50) return ('PROGRESSING', AppColors.goldSoft);
    if (trend == 'improving')                return ('IMPROVING',   AppColors.goldSoft);
    if (trend == 'inconsistent' && score >= 65) return ('PLATEAUING', AppColors.textSecondary);
    if (trend == 'inconsistent')             return ('INCONSISTENT', AppColors.textMuted);
    if (score >= 72) return ('EFFICIENT',  AppColors.goldSoft);
    if (score >= 55) return ('RESILIENT',  AppColors.gold);
    if (score >= 35) return ('ADAPTING',   AppColors.textMuted);
    return ('DEVELOPING', AppColors.textMuted);
  }

  // Canonical title-case: strip redundant trailing movement-type words (shown as chip)
  static String _formatName(String raw) {
    final words = raw.replaceAll('_', ' ').toLowerCase().split(' ')
      ..removeWhere((w) => w.isEmpty);
    // Strip trailing pure movement-type suffixes only (not compound names like "bench press")
    const redundant = {'push', 'pull'};
    final cleaned = (redundant.contains(words.last) && words.length > 1)
        ? words.sublist(0, words.length - 1)
        : words;
    return cleaned
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // Detect movement pattern chip label
  static String? _movementChip(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('press') || s.contains('pushdown') ||
        s.contains('dip')   || s.contains('fly')) {
      return 'PUSH';
    }
    if (s.contains('row')   || s.contains('pull') ||
        s.contains('curl')  || s.contains('chin')) {
      return 'PULL';
    }
    if (s.contains('squat') || s.contains('deadlift') ||
        s.contains('lunge') || s.contains('leg')) {
      return 'LEGS';
    }
    if (s.contains('crunch') || s.contains('plank') ||
        s.contains('ab')     || s.contains('core')) {
      return 'CORE';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final score = mastery.masteryScore.clamp(0.0, 100.0);
    final (statusLabel, statusColor) = _statusBadge(score, mastery.trend);
    final scoreColor = score >= 70 ? AppColors.gold
        : score >= 45 ? AppColors.goldSoft
        : AppColors.textMuted;

    // Trend glow border: color matches the status
    final borderColor = statusColor.withValues(alpha: 0.22);
    final glowColor   = statusColor.withValues(alpha: 0.06);

    final chip = _movementChip(mastery.exercise);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: borderColor, width: 0.7),
        boxShadow: [BoxShadow(
          color: glowColor, blurRadius: 16, spreadRadius: 0)],
      ),
      child: Row(children: [
        // Score column — secondary, smaller than name
        SizedBox(
          width: 48,
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('${score.round()}', style: GoogleFonts.rajdhani(
              color: scoreColor, fontSize: 30,
              fontWeight: FontWeight.w900, height: 1.0)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score / 100, minHeight: 2,
                backgroundColor: AppColors.divider.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(
                    scoreColor.withValues(alpha: 0.55)),
              ),
            ),
          ]),
        ),
        const SizedBox(width: AppSpacing.md),
        // Name dominates — large, canonical, with optional movement chip
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatName(mastery.exercise),
              style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.w900, height: 1.1),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text('${mastery.sessionCount} sessions',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.50), fontSize: 9.5)),
              if (chip != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.textMuted.withValues(alpha: 0.18), width: 0.5)),
                  child: Text(chip, style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.60),
                    fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ],
            ]),
          ],
        )),
        // Status badge — right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.24), width: 0.7)),
          child: Text(statusLabel, style: GoogleFonts.inter(
            color: statusColor, fontSize: 8.5,
            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ]),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(
      children: [
        Container(
          width: 1.5,
          height: 9,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.textSecondary.withValues(alpha: 0.68),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    ),
  );
}


// ════════════════════════════════════════════════
// PULSE GLOW — lightweight aura wrapper for
// legendary achievements (Phase 18).
// ════════════════════════════════════════════════
class _PulseGlow extends StatefulWidget {
  final Widget child;
  final Color  color;
  const _PulseGlow({required this.child, required this.color});
  @override State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.22 + 0.22 * _c.value),
            blurRadius: 20 + 24 * _c.value,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: widget.color.withValues(alpha: 0.07 + 0.07 * _c.value),
            blurRadius: 42 + 22 * _c.value,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    ),
    child: widget.child,
  );
}

// ════════════════════════════════════════════════
// LEGENDARY SHIMMER — sweep highlight for top-tier
// badges. Fires once per 3.2s, then holds.
// ════════════════════════════════════════════════
class _LegendaryShimmer extends StatefulWidget {
  final Widget child;
  final Color  color;
  const _LegendaryShimmer({required this.child, required this.color});
  @override State<_LegendaryShimmer> createState() => _LegendaryShimmerState();
}

class _LegendaryShimmerState extends State<_LegendaryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3200))..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      // Sweep active for first 38% of cycle, then holds off-screen until next loop
      final t = _c.value;
      final sweep = t < 0.38 ? t / 0.38 : 1.0;
      final dx = -32.0 + sweep * 98.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 66, height: 66,
          child: Stack(children: [
            child!,
            Positioned(
              left: dx, top: 0, bottom: 0, width: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      widget.color.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    },
    child: widget.child,
  );
}



// ════════════════════════════════════════════════
// ADAPTIVE READINESS ORB — Phase 18
// LiftOn's signature visual identity.
// Breathing glow · readiness-driven tint ·
// fatigue tension arc — minimal and iconic.
// ════════════════════════════════════════════════
class _AdaptiveReadinessOrb extends StatefulWidget {
  const _AdaptiveReadinessOrb();
  @override State<_AdaptiveReadinessOrb> createState() =>
      _AdaptiveReadinessOrbState();
}

class _AdaptiveReadinessOrbState extends State<_AdaptiveReadinessOrb>
    with TickerProviderStateMixin {
  late AnimationController _breathe;
  late AnimationController _innerPulse;
  late AnimationController _haze;
  late AnimationController _countUp;
  late Animation<double>   _countAnim;

  @override
  void initState() {
    super.initState();
    _breathe    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3800))..repeat(reverse: true);
    _innerPulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _haze       = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 6500))..repeat();
    _countUp    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _countAnim  = CurvedAnimation(parent: _countUp, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 120),
        () { if (mounted) _countUp.forward(); });
  }

  @override
  void dispose() {
    _breathe.dispose(); _innerPulse.dispose();
    _haze.dispose(); _countUp.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({double readiness, double fatigue, double progression})>(
      selector: (_, ap) => (
        readiness:   ap.recoveryState.overallScore.clamp(0, 100),
        fatigue:     ap.weeklyFatiguePressure.clamp(0, 100),
        progression: ap.weeklyProgressionScore.clamp(0, 100),
      ),
      builder: (_, d, __) {
        final orbColor = d.readiness >= 75 ? AppColors.gold
            : d.readiness >= 55 ? AppColors.goldSoft
            : d.readiness >= 35 ? AppColors.textSecondary
            : AppColors.textMuted;

        final readLabel = d.readiness >= 80 ? 'PRIMED'
            : d.readiness >= 65 ? 'READY'
            : d.readiness >= 45 ? 'BUILDING'
            : d.readiness >= 25 ? 'LOADING'
            : 'RECOVERING';

        // PRIMED breathes fully; RECOVERING barely moves — motion communicates physiology
        final energyScale = d.readiness >= 80 ? 1.0
            : d.readiness >= 55 ? 0.82 : 0.50;

        return AnimatedBuilder(
          animation: Listenable.merge([_breathe, _innerPulse, _haze, _countUp]),
          builder: (_, __) {
            final b  = _breathe.value * energyScale;
            final ip = _innerPulse.value;

            // Haze particle — single barely-visible orbiting presence
            final hazeAngle = _haze.value * 2 * math.pi;
            const hr = 55.0;
            final hx = hr * math.cos(hazeAngle - math.pi / 2);
            final hy = hr * math.sin(hazeAngle - math.pi / 2);

            return RepaintBoundary(
              child: Center(
                child: SizedBox(
                  width: 200, height: 200,
                  child: Stack(alignment: Alignment.center, children: [

                    // Outer ambient glow — two concentric layers, softer falloff
                    Container(
                      width: 160 + 14 * b,
                      height: 160 + 14 * b,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: orbColor.withValues(alpha: 0.07 + 0.09 * b),
                            blurRadius: 38 + 22 * b, spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: orbColor.withValues(alpha: 0.02 + 0.03 * b),
                            blurRadius: 78 + 38 * b, spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Edge diffusion — atmospheric halo between ring and ambient
                    Container(
                      width: 132 + 6 * b,
                      height: 132 + 6 * b,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            orbColor.withValues(alpha: 0.04 + 0.03 * b),
                            Colors.transparent,
                          ],
                          stops: const [0.55, 0.82, 1.0],
                        ),
                      ),
                    ),

                    // Ring painter — readiness arc + fatigue tension arc
                    SizedBox(
                      width: 148, height: 148,
                      child: CustomPaint(
                        painter: _OrbRingPainter(
                          readiness: d.readiness / 100,
                          fatigue:   d.fatigue / 100,
                          color:     orbColor,
                          breathe:   b,
                        ),
                      ),
                    ),

                    // Haze particle — barely-visible orbiting presence
                    Transform.translate(
                      offset: Offset(hx, hy),
                      child: Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: orbColor.withValues(
                              alpha: (0.08 + 0.08 * ip) * energyScale),
                          boxShadow: [BoxShadow(
                            color: orbColor.withValues(alpha: 0.12 * energyScale),
                            blurRadius: 6,
                          )],
                        ),
                      ),
                    ),

                    // Core orb — radial gradient + border (no child, overlays on top)
                    Container(
                      width: 118, height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.28, -0.32),
                          radius: 1.15,
                          colors: [
                            orbColor.withValues(alpha: 0.17 + 0.08 * ip),
                            const Color(0xFF050505),
                          ],
                        ),
                        border: Border.all(
                          color: orbColor.withValues(alpha: 0.18 + 0.12 * b),
                          width: 0.8,
                        ),
                      ),
                    ),

                    // Inner shadow depth illusion — bottom-right darkening
                    Container(
                      width: 118, height: 118,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(0.32, 0.40),
                          radius: 0.88,
                          colors: [Colors.transparent, Color(0x40000000)],
                        ),
                      ),
                    ),

                    // Specular highlight — top-left atmospheric glint
                    Container(
                      width: 118, height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.62, -0.64),
                          radius: 0.60,
                          colors: [
                            Colors.white.withValues(alpha: 0.07 + 0.04 * ip),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Score content — topmost layer
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(d.readiness * _countAnim.value).round()}',
                            style: GoogleFonts.rajdhani(
                              color: orbColor, fontSize: 42,
                              fontWeight: FontWeight.w900, height: 1.0)),
                        const SizedBox(height: 3),
                        Text(readLabel, style: GoogleFonts.inter(
                          color: orbColor.withValues(alpha: 0.58),
                          fontSize: 6.5, fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                      ],
                    ),

                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Rings: readiness arc + fatigue tension arc
class _OrbRingPainter extends CustomPainter {
  final double readiness, fatigue, breathe;
  final Color  color;
  const _OrbRingPainter({
    required this.readiness, required this.fatigue,
    required this.breathe,  required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - 5) / 2;
    const sw = 3.2;

    // Background track
    canvas.drawCircle(c, r, Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw);

    // Readiness arc (clockwise from top)
    if (readiness > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        readiness * 2 * math.pi,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.62 + 0.22 * breathe)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
      // Energy density dot at arc tip — dynamic intensity near active end
      final tipAngle = -math.pi / 2 + readiness * 2 * math.pi;
      canvas.drawCircle(
        Offset(c.dx + r * math.cos(tipAngle), c.dy + r * math.sin(tipAngle)),
        sw * (0.85 + 0.55 * breathe),
        Paint()..color = color.withValues(alpha: 0.78 + 0.18 * breathe),
      );
    }

    // Fatigue tension arc — only when fatigue > 45%
    if (fatigue > 0.45) {
      final tension = ((fatigue - 0.45) / 0.55).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - sw - 2.5),
        -math.pi / 2,
        -(tension * math.pi * 0.65),
        false,
        Paint()
          ..color = AppColors.orange.withValues(alpha: 0.25 * breathe + 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbRingPainter o) =>
      o.readiness != readiness || o.fatigue != fatigue ||
      o.breathe != breathe || o.color != color;
}

// ════════════════════════════════════════════════
// ANALYTICS HERO INSIGHT CARD — Phase 17
// ONE dominant surface. Priority engine:
// deload warning → overload window → plateau →
// weekly narrative → coach tip fallback.
// Pulsing glow + subtitle line + editorial type.
// ════════════════════════════════════════════════
class _AnalyticsHeroInsightCard extends StatefulWidget {
  const _AnalyticsHeroInsightCard();
  @override State<_AnalyticsHeroInsightCard> createState() =>
      _AnalyticsHeroInsightCardState();
}

class _AnalyticsHeroInsightCardState extends State<_AnalyticsHeroInsightCard>
    with TickerProviderStateMixin {
  late AnimationController _glow;
  late AnimationController _drift;
  late Animation<double> _glowAnim;
  late Animation<double> _driftAnim;

  @override
  void initState() {
    super.initState();
    _glow  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _drift = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 8000))..repeat();
    _glowAnim  = CurvedAnimation(parent: _glow,  curve: Curves.easeInOut);
    _driftAnim = CurvedAnimation(parent: _drift, curve: Curves.linear);
  }

  @override
  void dispose() { _glow.dispose(); _drift.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({
      double fatigue,
      double progression,
      double improvement,
      String narrative,
      String tip,
    })>(
      selector: (_, ap) => (
        fatigue:     ap.weeklyFatiguePressure,
        progression: ap.weeklyProgressionScore,
        improvement: ap.weeklyImprovementPercent,
        narrative:   ap.weeklyEvolutionNarrative,
        tip:         ap.progressionTip,
      ),
      builder: (_, d, __) {
        final r = _resolve(d);
        return AnimatedBuilder(
          animation: Listenable.merge([_glowAnim, _driftAnim]),
          builder: (_, __) {
            final g = _glowAnim.value;
            final t = _driftAnim.value;
            final driftX = 28.0 + 20.0 * math.cos(t * 2 * math.pi);
            final driftY = 14.0 + 9.0  * math.sin(t * 2 * math.pi);
            return RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D09),
                  gradient: LinearGradient(
                    colors: [
                      r.color.withValues(alpha: 0.13),
                      AppColors.bgCard,
                      const Color(0xFF0D0D09),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.48, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: r.color.withValues(alpha: 0.16 + 0.11 * g),
                    width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: r.color.withValues(alpha: 0.07 + 0.09 * g),
                      blurRadius: 32 + 20 * g,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Color(0x28000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xl - 0.5),
                  child: Stack(children: [
                    // Left-edge gold light beam
                    Positioned(
                      left: 0, top: 0, bottom: 0,
                      child: Container(
                        width: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              r.color.withValues(alpha: 0.50 + 0.24 * g),
                              Colors.transparent,
                            ],
                            stops: const [0.05, 0.50, 0.95],
                          ),
                        ),
                      ),
                    ),
                    // Atmospheric drift particle — slow elliptical orbit
                    Positioned(
                      right: driftX,
                      top:   driftY,
                      child: Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.08 + 0.05 * g),
                          boxShadow: [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.07),
                            blurRadius: 6,
                          )],
                        ),
                      ),
                    ),
                    // Internal shadow depth — bottom-right cinematic darkening
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0.88, 0.92),
                            radius: 1.10,
                            colors: [Colors.transparent, Color(0x1C000000)],
                          ),
                        ),
                      ),
                    ),
                    // Editorial content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 20, 23),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(r.icon, color: r.color, size: 12),
                            const SizedBox(width: 7),
                            Text(r.label, style: GoogleFonts.inter(
                              color: r.color.withValues(alpha: 0.80),
                              fontSize: 8, fontWeight: FontWeight.w800,
                              letterSpacing: 1.6)),
                          ]),
                          const SizedBox(height: AppSpacing.lg + 2),
                          Text(r.insight, style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 17, fontWeight: FontWeight.w300,
                            height: 1.78)),
                          if (r.subtitle.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(r.subtitle, style: GoogleFonts.inter(
                              color: AppColors.textMuted.withValues(alpha: 0.52),
                              fontSize: 11.5, fontWeight: FontWeight.w300,
                              height: 1.62)),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static ({String insight, String subtitle, String label, IconData icon, Color color})
      _resolve(({
    double fatigue, double progression, double improvement,
    String narrative, String tip,
  }) d) {
    if (d.fatigue >= 65 && d.improvement <= 2) {
      return (
        insight:  'Fatigue pressure is elevated. Technical precision will serve you better than additional intensity today.',
        subtitle: 'High load without absorption erodes the adaptation that drives strength.',
        label:    'RECOVERY SIGNAL',
        icon:     Icons.spa_rounded,
        color:    AppColors.orange,
      );
    }
    if (d.progression >= 60 && d.fatigue < 40 && d.improvement >= 3) {
      return (
        insight:  'Your system is absorbing load efficiently. Conditions are aligned for deliberate progress this week.',
        subtitle: 'Low fatigue alongside rising output is a rare convergence. Use it with intention.',
        label:    'OVERLOAD WINDOW',
        icon:     Icons.trending_up_rounded,
        color:    AppColors.gold,
      );
    }
    if (d.improvement.abs() < 1.5 && d.progression < 45) {
      return (
        insight:  'Output has stabilized. Deliberate variation in stimulus — volume or intensity — can restart adaptation.',
        subtitle: 'The body adapts to predictable demands. A controlled shift in stimulus reactivates progress.',
        label:    'PLATEAU SIGNAL',
        icon:     Icons.remove_rounded,
        color:    AppColors.textSecondary,
      );
    }
    if (d.narrative.isNotEmpty) {
      return (
        insight:  d.narrative,
        subtitle: 'Derived from this week\'s training patterns.',
        label:    'WEEKLY INTELLIGENCE',
        icon:     Icons.auto_awesome_rounded,
        color:    AppColors.gold,
      );
    }
    return (
      insight:  d.tip.isNotEmpty ? d.tip
          : 'Each session deposits. Consistency is the only strategy that compounds.',
      subtitle: '',
      label:    'COACH INSIGHT',
      icon:     Icons.tips_and_updates_rounded,
      color:    AppColors.gold,
    );
  }
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
        duration: const Duration(milliseconds: 320));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _s = Tween<Offset>(begin: const Offset(0, 0.032), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn));
    Future.delayed(Duration(milliseconds: widget.delay),
            () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _f, child: SlideTransition(position: _s, child: widget.child));
}

// ════════════════════════════════════════════════
// ORB SECTION — hold-to-expand readiness detail.
// LiftOn's iconic interaction — subtle, not gimmick.
// Hold orb → soft detail panel rises below.
// ════════════════════════════════════════════════
class _OrbSection extends StatefulWidget {
  const _OrbSection();
  @override State<_OrbSection> createState() => _OrbSectionState();
}

class _OrbSectionState extends State<_OrbSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _expand;
  late Animation<double>   _expandAnim;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 340));
    _expandAnim = CurvedAnimation(parent: _expand, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() { _expand.dispose(); super.dispose(); }

  void _onHoldStart(_) {
    H.medium();
    _expand.forward();
  }

  void _onHoldEnd() {
    _expand.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onHoldStart,
      onLongPressEnd:   (_) => _onHoldEnd(),
      onLongPressCancel: _onHoldEnd,
      child: Column(children: [
        const _AdaptiveReadinessOrb(),
        AnimatedBuilder(
          animation: _expandAnim,
          builder: (_, __) {
            final v = _expandAnim.value;
            if (v == 0) return const SizedBox.shrink();
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)),
                child: Selector<AppProvider, ({double readiness, double fatigue, double progression})>(
                  selector: (_, ap) => (
                    readiness:   ap.recoveryState.overallScore.clamp(0, 100),
                    fatigue:     ap.weeklyFatiguePressure.clamp(0, 100),
                    progression: ap.weeklyProgressionScore.clamp(0, 100),
                  ),
                  builder: (_, d, __) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: AppColors.borderSoft.withValues(alpha: 0.20),
                          width: 0.6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _OrbDetailStat(
                            label: 'READINESS',
                            value: '${d.readiness.round()}',
                            color: d.readiness >= 75 ? AppColors.gold
                                : d.readiness >= 50 ? AppColors.goldSoft
                                : AppColors.textSecondary,
                          ),
                          Container(width: 0.5, height: 32,
                              color: AppColors.borderSoft.withValues(alpha: 0.28)),
                          _OrbDetailStat(
                            label: 'FATIGUE',
                            value: '${d.fatigue.round()}',
                            color: d.fatigue >= 65 ? AppColors.orange
                                : d.fatigue >= 40 ? AppColors.textSecondary
                                : AppColors.textMuted,
                          ),
                          Container(width: 0.5, height: 32,
                              color: AppColors.borderSoft.withValues(alpha: 0.28)),
                          _OrbDetailStat(
                            label: 'PROGRESS',
                            value: '${d.progression.round()}',
                            color: d.progression >= 65 ? AppColors.gold
                                : d.progression >= 40 ? AppColors.goldSoft
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _OrbDetailStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _OrbDetailStat({
      required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: GoogleFonts.rajdhani(
      color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1.0)),
    const SizedBox(height: 3),
    Text(label, style: GoogleFonts.inter(
      color: color.withValues(alpha: 0.52),
      fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  ]);
}

// Tactile scale feedback wrapper — scale to 0.93 on press.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});
  @override State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _p = true),
    onTapUp:     (_) => setState(() => _p = false),
    onTapCancel: ()  => setState(() => _p = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _p ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}