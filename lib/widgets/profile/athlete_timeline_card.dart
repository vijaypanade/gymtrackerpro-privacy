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
  final int    totalWorkouts;
  final int    longestStreak;
  final int    totalPRs;
  final String identityLabel;
  final String evolutionSummary;
  final String headline;
  final bool   hasData;

  const _TimelineCardData({
    required this.events,
    required this.milestones,
    required this.totalWorkouts,
    required this.longestStreak,
    required this.totalPRs,
    required this.identityLabel,
    required this.evolutionSummary,
    required this.headline,
    required this.hasData,
  });

  factory _TimelineCardData.from(AppProvider ap) {
    final t = ap.timelineSnapshot;
    return _TimelineCardData(
      events:          t.events,
      milestones:      t.milestones,
      totalWorkouts:   t.totalWorkouts,
      longestStreak:   t.longestStreak,
      totalPRs:        t.totalPRs,
      identityLabel:   t.currentIdentityLabel,
      evolutionSummary: t.evolutionSummary,
      headline:        t.headline,
      hasData:         t.hasData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _TimelineCardData) return false;
    return other.totalWorkouts == totalWorkouts &&
           other.longestStreak == longestStreak &&
           other.totalPRs      == totalPRs      &&
           other.identityLabel == identityLabel &&
           other.hasData       == hasData;
  }

  @override
  int get hashCode => Object.hash(
    totalWorkouts, longestStreak, totalPRs, identityLabel, hasData,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.18),
          width: 0.5,
        ),
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
          _StatCell(
            value: '${data.totalWorkouts}',
            label: 'Sessions',
            color: AppColors.gold,
          ),
          _StatCell(
            value: '${data.longestStreak}d',
            label: 'Peak Streak',
            color: AppColors.orange,
          ),
          _StatCell(
            value: '${data.totalPRs}',
            label: 'Lifetime PRs',
            color: AppColors.green,
          ),
          _StatCell(
            value: '${data.milestones.length}',
            label: 'Milestones',
            color: AppColors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _StatCell({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
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
    ('\u{1F4AA}', 'First Workout',   'Log your first session'),
    ('\u{1F525}', 'First Streak',    '3 sessions in a row'),
    ('\u{1F3C6}', 'First PR',        'Beat your best weight or reps'),
    ('\u{1F4C5}', '7-Day Streak',    'Train 7 days in a row'),
    ('\u{1F4AF}', '50 Workouts',     'Reach 50 logged sessions'),
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
              const Text('\u{1F3C1}', style: TextStyle(fontSize: 24)),
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
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.textMuted.withValues(alpha: 0.12),
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.$1, style: const TextStyle(fontSize: 16)),
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
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
