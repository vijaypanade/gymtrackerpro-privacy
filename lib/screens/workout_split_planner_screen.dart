// lib/screens/workout_split_planner_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Standalone screen reachable from the FTUE "Build My Plan with AI" CTA.
// Shows the AI recommendation card + split selector + generate button.
// All plan state lives in AppProvider — zero duplication with ToolsScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/split_template.dart';
import '../models/workout_readiness_profile.dart';
import '../providers/app_provider.dart';
import '../services/monetization_service.dart';
import '../services/split_recommendation_engine.dart';
import '../utils/app_constants.dart';

// Presentation-layer overrides — model enums are untouched
String _splitDisplayLabel(SplitStyle s) {
  if (s == SplitStyle.aiAdaptive) return 'Adaptive Split';
  return s.label;
}

String _splitDisplayDescription(SplitStyle s) {
  if (s == SplitStyle.aiAdaptive) {
    return 'Your schedule adjusts each week based on recovery and training volume.';
  }
  return s.description;
}

// ═════════════════════════════════════════════════════════════════════════════
class WorkoutSplitPlannerScreen extends StatefulWidget {
  const WorkoutSplitPlannerScreen({super.key});
  @override
  State<WorkoutSplitPlannerScreen> createState() =>
      _WorkoutSplitPlannerScreenState();
}

class _WorkoutSplitPlannerScreenState
    extends State<WorkoutSplitPlannerScreen> {
  bool _loading = false;

  Future<void> _generate(AppProvider p) async {
    if (!p.canUseAI()) {
      HapticFeedback.mediumImpact();
      await PaywallSheet.show(
        context,
        trigger: PaywallTrigger.aiLimitHit,
        onUpgrade: () => p.refreshMonetization(),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await p.workout.generateSmartPlan(
        goal: p.goal,
        level: p.level,
        splitOverride: p.splitStyle == SplitStyle.aiAdaptive
            ? ''
            : _splitToEngineKey(p.splitStyle, p.gymDaysPerWeek),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${_splitDisplayLabel(p.splitStyle)} plan applied to your Planner.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 3),
      ));
      // Pop back to Home so user sees their new plan in the dashboard
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Plan could not be applied. Please try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Map SplitStyle → AIEngine split key
  static String _splitToEngineKey(SplitStyle s, int days) {
    switch (s) {
      case SplitStyle.pushPullLegs:
        return days >= 6 ? 'PPLPPL' : 'PPL';
      case SplitStyle.upperLower:
        return days <= 3 ? 'UpperLower2' : 'UpperLower4';
      case SplitStyle.antagonistPairs:
        return days >= 6 ? 'ChestTriBackBi6' : 'ChestTriBackBi';
      case SplitStyle.fullBody:
        return days >= 4 ? 'FullBody4' : 'FullBody';
      case SplitStyle.broSplit:
        return days >= 6 ? 'BroSplit6' : 'BroSplit5';
      case SplitStyle.dailySingleMuscle:
        return days >= 6 ? 'DailySingleMuscle6' : 'DailySingleMuscle';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Design My Training',
          style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Selector<AppProvider, (SplitStyle, int, String, String, bool, int)>(
        selector: (_, p) => (
          p.splitStyle,
          p.gymDaysPerWeek,
          p.level,
          p.goal,
          p.canUseAI(),
          p.workout.streak.totalWorkouts,
        ),
        builder: (context, data, _) {
          final (splitStyle, gymDays, level, goal, canUse, totalWorkouts) = data;
          final p = context.read<AppProvider>();
          final bool isAdaptiveLocked = totalWorkouts < 8;

          final recommendation = SplitRecommendationEngine.recommend(
            level: level,
            gymDays: gymDays,
            goal: goal,
          );

          final WorkoutReadinessProfile? adaptiveProfile =
              splitStyle == SplitStyle.aiAdaptive
                  ? p.currentAdaptiveProfile
                  : null;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AI Adaptive Intelligence card (AI Adaptive only) ────
                if (adaptiveProfile != null) ...[
                  _AdaptiveIntelligenceCard(
                    profile: adaptiveProfile,
                    selectedDays: gymDays,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── AI Recommendation Card ──────────────────────────────
                _AIRecommendationCard(
                  recommendation: recommendation,
                  currentSplit: splitStyle,
                  onAccept: () {
                    HapticFeedback.selectionClick();
                    p.updateSetting(
                        'splitStyle', recommendation.split.name);
                  },
                ),
                const SizedBox(height: 22),

                // ── Days per week ───────────────────────────────────────
                Text('Gym days / week',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 8),
                _DaysSelector(
                  current: gymDays,
                  onChanged: (d) => p.updateSetting('gymDaysPerWeek', d),
                ),
                const SizedBox(height: 22),

                // ── Split chips ─────────────────────────────────────────
                Text('Training Split',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SplitStyle.values
                      .where((style) =>
                          style != SplitStyle.broSplit &&
                          style != SplitStyle.dailySingleMuscle &&
                          style != SplitStyle.antagonistPairs)
                      .map((style) {
                    final selected = style == splitStyle;
                    final isRecommended = style == recommendation.split;
                    final isLocked =
                        style == SplitStyle.aiAdaptive && isAdaptiveLocked;
                    return _SplitChip(
                      style: style,
                      selected: selected,
                      isRecommended: isRecommended,
                      isLocked: isLocked,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        p.updateSetting('splitStyle', style.name);
                      },
                    );
                  }).toList(),
                ),

                // ── Split description ───────────────────────────────────
                if (splitStyle != SplitStyle.pushPullLegs) ...[
                  const SizedBox(height: 12),
                  Text(
                    _splitDisplayDescription(splitStyle),
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.5),
                  ),
                ],
                const SizedBox(height: 28),

                // ── Generate button ─────────────────────────────────────
                _GenerateButton(
                  splitStyle: splitStyle,
                  loading: _loading,
                  canUse: canUse,
                  onTap: () => _generate(p),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AI RECOMMENDATION CARD
// ═════════════════════════════════════════════════════════════════════════════
class _AIRecommendationCard extends StatelessWidget {
  final SplitRecommendation recommendation;
  final SplitStyle currentSplit;
  final VoidCallback onAccept;

  const _AIRecommendationCard({
    required this.recommendation,
    required this.currentSplit,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final alreadySelected = currentSplit == recommendation.split;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(recommendation.split),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gold top accent
              Container(height: 1.5, color: AppColors.gold),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.psychology_rounded,
                              color: AppColors.gold, size: 10),
                          const SizedBox(width: 4),
                          Text('COACH RECOMMENDATION',
                              style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              )),
                        ]),
                      ),
                      if (recommendation.nudgedDown) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('ADJUSTED FOR YOU',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFF6B35),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              )),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 11),

                    // Recommended split name
                    Text(
                      recommendation.headline,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      recommendation.body,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bullet points
                    ...recommendation.bullets.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(b,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    )),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 14),

                    // Accept button
                    GestureDetector(
                      onTap: alreadySelected ? null : onAccept,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: alreadySelected
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFD4AF37)
                                  ],
                                ),
                          color: alreadySelected
                              ? AppColors.gold.withValues(alpha: 0.10)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          border: alreadySelected
                              ? Border.all(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.35))
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              alreadySelected
                                  ? Icons.check_circle_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 14,
                              color: alreadySelected
                                  ? AppColors.gold
                                  : Colors.black,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              alreadySelected
                                  ? '${recommendation.headline} selected'
                                  : 'Use This Split',
                              style: GoogleFonts.rajdhani(
                                color: alreadySelected
                                    ? AppColors.gold
                                    : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DAYS SELECTOR
// ═════════════════════════════════════════════════════════════════════════════
class _DaysSelector extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _DaysSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final days = i + 2; // 2–6
        final selected = days == current;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(days);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? null
                  : Border.all(color: AppColors.borderSoft, width: 0.8),
            ),
            child: Center(
              child: Text(
                '$days',
                style: GoogleFonts.rajdhani(
                  color: selected ? Colors.black : AppColors.textMuted,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SPLIT CHIP
// ═════════════════════════════════════════════════════════════════════════════

IconData _splitStyleIcon(SplitStyle style) {
  switch (style) {
    case SplitStyle.pushPullLegs:  return Icons.sync_rounded;
    case SplitStyle.upperLower:    return Icons.swap_vert_rounded;
    case SplitStyle.fullBody:      return Icons.fitness_center_rounded;
    case SplitStyle.aiAdaptive:    return Icons.auto_awesome_rounded;
    default:                        return Icons.grid_view_rounded;
  }
}

class _SplitChip extends StatelessWidget {
  final SplitStyle style;
  final bool selected;
  final bool isRecommended;
  final bool isLocked;
  final VoidCallback onTap;

  const _SplitChip({
    required this.style,
    required this.selected,
    required this.isRecommended,
    required this.isLocked,
    required this.onTap,
  });

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgModal,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Adaptive Split',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'Unlock after 8 completed workouts',
                style: GoogleFonts.inter(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This split adjusts based on your recovery, volume, and consistency. Complete 8 workouts to unlock it.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    'Got it',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.50 : 1.0,
      child: GestureDetector(
        onTap: isLocked ? () => _showLockedDialog(context) : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.14)
                : AppColors.bgCardLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : isRecommended
                      ? AppColors.gold.withValues(alpha: 0.40)
                      : AppColors.borderSoft,
              width: selected ? 2.0 : isRecommended ? 1.0 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _splitStyleIcon(style),
                  size: 13,
                  color:
                      selected ? AppColors.gold : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  _splitDisplayLabel(style),
                  style: GoogleFonts.rajdhani(
                    color: selected
                        ? AppColors.gold
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isRecommended && !selected && !isLocked) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Recommended',
                      style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
                if (isLocked) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.lock_outline_rounded,
                      size: 11, color: AppColors.textMuted),
                ],
              ]),
              if (isLocked) ...[
                const SizedBox(height: 3),
                Text(
                  '8 workouts to unlock',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GENERATE BUTTON
// ═════════════════════════════════════════════════════════════════════════════
class _GenerateButton extends StatefulWidget {
  final SplitStyle splitStyle;
  final bool loading;
  final bool canUse;
  final VoidCallback onTap;
  const _GenerateButton({
    required this.splitStyle,
    required this.loading,
    required this.canUse,
    required this.onTap,
  });
  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: (widget.loading || !widget.canUse)
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFD4AF37)]),
            color: widget.loading
                ? AppColors.gold.withValues(alpha: 0.18)
                : !widget.canUse
                    ? const Color(0xFF1A1400)
                    : null,
            borderRadius: BorderRadius.circular(13),
            border: (widget.loading || !widget.canUse)
                ? Border.all(
                    color: AppColors.gold
                        .withValues(alpha: widget.loading ? 0.35 : 0.55),
                    width: widget.canUse ? 1.0 : 1.5)
                : null,
            boxShadow: (!widget.loading && widget.canUse && !_pressed)
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppColors.gold, strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Preparing your plan...',
                      style: GoogleFonts.rajdhani(
                          color: AppColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ])
              : !widget.canUse
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text('Upgrade to Pro',
                            style: GoogleFonts.rajdhani(
                                color: AppColors.gold,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        const Icon(Icons.lock_outline_rounded,
                            size: 14, color: AppColors.gold),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Generate ${_splitDisplayLabel(widget.splitStyle)} Plan',
                            style: GoogleFonts.rajdhani(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            )),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.black, size: 18),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ADAPTIVE INTELLIGENCE CARD
// Shown above the recommendation card when splitStyle == aiAdaptive.
// Clean data-forward design — no decoration layers, no emoji.
// ═════════════════════════════════════════════════════════════════════════════
class _AdaptiveIntelligenceCard extends StatelessWidget {
  final WorkoutReadinessProfile profile;
  final int selectedDays;

  const _AdaptiveIntelligenceCard({
    required this.profile,
    required this.selectedDays,
  });

  @override
  Widget build(BuildContext context) {
    final isReduced = profile.effectiveDaysThisWeek < selectedDays;

    final Color confColor;
    final String confLabel;
    if (profile.confidenceScore >= 70) {
      confColor = AppColors.gold;
      confLabel = 'Well established';
    } else if (profile.confidenceScore >= 30) {
      confColor = AppColors.gold;
      confLabel = 'Building accuracy';
    } else {
      confColor = AppColors.orange;
      confLabel = 'Learning your recovery patterns';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderMedium, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimal top accent line
          Container(
            height: 1,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.gold, size: 11),
                  const SizedBox(width: 5),
                  Text(
                    'ADAPTIVE TRAINING',
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Confidence headline row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      confLabel,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${profile.confidenceScore}% confidence',
                      style: GoogleFonts.inter(
                        color: confColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 12),

                // Readiness explanation
                Text(
                  profile.readinessExplanation,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 12),

                // Recommended training days row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recommended training days',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${profile.effectiveDaysThisWeek} / $selectedDays this week',
                      style: GoogleFonts.inter(
                        color: isReduced
                            ? AppColors.orange
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Deload note
                if (profile.isDeloadWeek) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.trending_down_rounded,
                        size: 12, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text(
                      'Deload week — volume managed at 50%',
                      style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],

                // Recovery-adjusted note
                if (isReduced) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Recovery-adjusted plan active',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
