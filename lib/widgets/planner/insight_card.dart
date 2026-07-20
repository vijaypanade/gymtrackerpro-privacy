// lib/widgets/planner/insight_card.dart
//
// RFC-PLANNER-UX-001 — single chrome for the Planner coaching slot.
//
// Collapsed by default: one line + chevron. Tap expands to the full body
// (or [expandedChild] when provided — e.g. SessionProphecyCard). The ×
// in the expanded header snoozes the insight for the rest of today.
//
// Deliberately quieter than the critical-banner chrome: muted border, no
// fill tint, small type. Critical ≠ coaching — the hierarchy is the point.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ai/generators/planner_coaching_arbiter.dart';
import '../../utils/app_constants.dart';

class InsightCard extends StatefulWidget {
  final PlannerCoachingInsight insight;
  final VoidCallback onDismiss;
  /// Replaces the body text in expanded state when non-null.
  final Widget? expandedChild;

  const InsightCard({
    super.key,
    required this.insight,
    required this.onDismiss,
    this.expandedChild,
  });

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  bool _expanded = false;

  IconData get _icon => switch (widget.insight.type) {
    CoachingInsightType.weeklyAdjustment    => Icons.tune_rounded,
    CoachingInsightType.prophecy            => Icons.insights_rounded,
    CoachingInsightType.recoveryObservation => Icons.self_improvement_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
                color: AppColors.goldSoft.withValues(alpha: 0.18), width: 0.7),
          ),
          child: _expanded ? _expandedView() : _collapsedView(),
        ),
      ),
    );
  }

  Widget _collapsedView() => InkWell(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    onTap: () => setState(() => _expanded = true),
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(children: [
        Icon(_icon, color: AppColors.goldSoft.withValues(alpha: 0.75), size: 15),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(
          widget.insight.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13, fontWeight: FontWeight.w600),
        )),
        Icon(Icons.expand_more_rounded,
            color: AppColors.textMuted.withValues(alpha: 0.6), size: 18),
      ]),
    ),
  );

  Widget _expandedView() => Padding(
    padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(_icon, color: AppColors.goldSoft.withValues(alpha: 0.75), size: 15),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _expanded = false),
          child: Text(
            widget.insight.title,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600),
          ),
        )),
        // Snooze for today — Amendment 1
        IconButton(
          onPressed: widget.onDismiss,
          icon: Icon(Icons.close_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.7), size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Hide for today',
        ),
      ]),
      if (widget.expandedChild != null)
        widget.expandedChild!
      else ...[
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            widget.insight.body,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.45),
          ),
        ),
      ],
    ]),
  );
}
