// lib/widgets/profile/athlete_timeline_card.dart
//
// AthleteTimelineCard — full vertical timeline of athlete evolution.
// Read-only. All data from AppProvider via Selector. No business logic.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../timeline/models/milestone.dart';
import '../../timeline/models/timeline_event.dart';
import '../../utils/app_constants.dart';
import 'milestone_chip.dart';
import 'timeline_event_tile.dart';

// ── Data snapshot ──────────────────────────────────────────────────────────────

@immutable
class _TimelineCardData {
  final List<TimelineEvent> events;
  final List<Milestone>     milestones;
  final int    totalPRs;
  final int    activeWeeks;
  final String identityLabel;
  final String evolutionSummary;
  final String headline;
  final bool   hasData;

  const _TimelineCardData({
    required this.events,
    required this.milestones,
    required this.totalPRs,
    required this.activeWeeks,
    required this.identityLabel,
    required this.evolutionSummary,
    required this.headline,
    required this.hasData,
  });

  factory _TimelineCardData.from(AppProvider ap) {
    final t = ap.timelineSnapshot;
    return _TimelineCardData(
      events:           t.events,
      milestones:       t.milestones,
      totalPRs:         t.totalPRs,
      activeWeeks:      ap.activeWeeks,
      identityLabel:    t.currentIdentityLabel,
      evolutionSummary: t.evolutionSummary,
      headline:         t.headline,
      hasData:          t.hasData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _TimelineCardData) return false;
    return other.activeWeeks   == activeWeeks  &&
           other.totalPRs      == totalPRs     &&
           other.identityLabel == identityLabel &&
           other.hasData       == hasData;
  }

  @override
  int get hashCode => Object.hash(
    activeWeeks, totalPRs, identityLabel, hasData,
  );
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class AthleteTimelineCard extends StatelessWidget {
  const AthleteTimelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Selector<AppProvider, _TimelineCardData>(
        selector: (_, ap) => _TimelineCardData.from(ap),
        builder:  (_, data, __) => _AthleteTimelineBody(data: data),
      ),
    );
  }
}

class _AthleteTimelineBody extends StatelessWidget {
  final _TimelineCardData data;
  const _AthleteTimelineBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimelineHeader(data: data),
          Container(height: 0.5, color: AppColors.borderSoft),
          _StatRow(data: data),
          if (data.milestones.isNotEmpty) ...[
            Container(height: 0.5, color: AppColors.borderSoft),
            _MilestoneSection(milestones: data.milestones),
          ],
          if (data.hasData) ...[
            Container(height: 0.5, color: AppColors.borderSoft),
            _EventList(events: data.events),
          ] else
            _EmptyState(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _TimelineHeader extends StatelessWidget {
  final _TimelineCardData data;
  const _TimelineHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ATHLETE TIMELINE', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  data.identityLabel,
                  style: AppTextStyles.caption.copyWith(color: AppColors.goldSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.headline,
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            data.evolutionSummary,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Stat row ───────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final _TimelineCardData data;
  const _StatRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatCell(value: '${data.events.length}',      label: 'Key Events',   delayMs: 0),
          _StatCell(value: '${data.activeWeeks}w',     label: 'Active Weeks', delayMs: 100),
          _StatCell(value: '${data.totalPRs}',         label: 'Lifetime PRs', delayMs: 200),
          _StatCell(value: '${data.milestones.length}', label: data.milestones.length == 1 ? 'Milestone' : 'Milestones', delayMs: 300),
        ],
      ),
    );
  }
}

class _StatCell extends StatefulWidget {
  final String value;
  final String label;
  final int    delayMs;
  const _StatCell({required this.value, required this.label, this.delayMs = 0});
  @override State<_StatCell> createState() => _StatCellState();
}

class _StatCellState extends State<_StatCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  // Extract leading integer from value strings like "47", "12d", "3".
  // Suffix (e.g. "d") is preserved in display.
  static (int, String) _parse(String v) {
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(v);
    if (match == null) return (0, v);
    return (int.parse(match.group(1)!), match.group(2)!);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final (target, suffix) = _parse(widget.value);
    return Expanded(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final shown = (target * _anim.value).round();
          return Column(
            children: [
              Text('$shown$suffix',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(widget.label,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.55)),
                  textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}

// ── Milestone section ──────────────────────────────────────────────────────────

class _MilestoneSection extends StatelessWidget {
  final List<Milestone> milestones;
  const _MilestoneSection({required this.milestones});

  @override
  Widget build(BuildContext context) {
    // Show up to 8 most-recent milestones as chips.
    final displayed = milestones.length > 8
        ? milestones.sublist(milestones.length - 8)
        : milestones;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MILESTONES', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: displayed.map((m) => MilestoneChip(milestone: m)).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Event list ─────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<TimelineEvent> events;
  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    // Show most recent 20 events (reversed — newest first).
    final displayed = events.length > 20
        ? events.sublist(events.length - 20).reversed.toList()
        : events.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EVENT HISTORY', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 10),
          ...displayed.asMap().entries.map((e) => TimelineEventTile(
            event:  e.value,
            isLast: e.key == displayed.length - 1,
          )),
        ],
      ),
    );
  }
}

// ── Empty state with locked milestone previews ─────────────────────────────────

class _EmptyState extends StatelessWidget {
  static const _locked = [
    (Icons.fitness_center_rounded,    'First Workout',   'Log your first session'),
    (Icons.local_fire_department_outlined, 'First Streak', '3 sessions in a row'),
    (Icons.emoji_events_outlined,     'First PR',        'Beat your best weight or reps'),
    (Icons.calendar_today_outlined,   '7-Day Streak',    'Train 7 days in a row'),
    (Icons.bar_chart_rounded,         '50 Workouts',     'Reach 50 logged sessions'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story start prompt
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 24, color: AppColors.goldSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your story starts here',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete your first workout to begin your evolution.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'UPCOMING MILESTONES',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ..._locked.map(
            (m) => Opacity(
              opacity: 0.55,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.textMuted.withValues(alpha: 0.08),
                          width: 0.3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(m.$1, size: 14, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            m.$3,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline_rounded,
                        size: 12, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
