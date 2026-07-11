// lib/widgets/profile/timeline_event_tile.dart
//
// TimelineEventTile — one row in the vertical timeline list.
// Read-only. No business logic.

import 'package:flutter/material.dart';

import '../../timeline/models/timeline_event.dart';
import '../../utils/app_constants.dart';

class TimelineEventTile extends StatelessWidget {
  final TimelineEvent event;
  final bool isLast;

  const TimelineEventTile({
    super.key,
    required this.event,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);
    final dateStr = _formatDate(event.date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline spine ───────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.40),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.borderSoft,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_eventIcon(event.type), size: 13, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.title,
                          style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      if (event.value != null)
                        Text(
                          '${_formatValue(event.value!)} ${event.valueUnit ?? ''}',
                          style: AppTextStyles.caption.copyWith(color: color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.detail,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _eventColor(TimelineEventType type) {
  switch (type) {
    case TimelineEventType.firstWorkout:
      return AppColors.gold;
    case TimelineEventType.streak7:
    case TimelineEventType.streak30:
      return AppColors.orange;
    case TimelineEventType.workout50:
    case TimelineEventType.workout100:
      return AppColors.goldHero;
    case TimelineEventType.identityEvolution:
      return AppColors.textSecondary;
    case TimelineEventType.prAchieved:
      return AppColors.gold;
    case TimelineEventType.recoveryImprovement:
      return AppColors.textMuted;
    case TimelineEventType.consistencyMilestone:
      return AppColors.goldSoft;
    case TimelineEventType.deloadCompleted:
      return AppColors.textSecondary;
    case TimelineEventType.comebackCompleted:
      return AppColors.goldSoft;
    case TimelineEventType.weeklyHighlight:
      return AppColors.textMuted;
  }
}

IconData _eventIcon(TimelineEventType type) {
  switch (type) {
    case TimelineEventType.firstWorkout:         return Icons.flag_rounded;
    case TimelineEventType.streak7:              return Icons.local_fire_department_outlined;
    case TimelineEventType.streak30:             return Icons.bolt_rounded;
    case TimelineEventType.workout50:            return Icons.fitness_center_rounded;
    case TimelineEventType.workout100:           return Icons.emoji_events_outlined;
    case TimelineEventType.identityEvolution:    return Icons.auto_awesome_outlined;
    case TimelineEventType.prAchieved:           return Icons.trending_up_rounded;
    case TimelineEventType.recoveryImprovement:  return Icons.favorite_outline_rounded;
    case TimelineEventType.consistencyMilestone: return Icons.bar_chart_rounded;
    case TimelineEventType.deloadCompleted:      return Icons.shield_outlined;
    case TimelineEventType.comebackCompleted:    return Icons.rocket_launch_outlined;
    case TimelineEventType.weeklyHighlight:      return Icons.calendar_today_outlined;
  }
}

String _formatDate(DateTime date) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month]} ${date.day}, ${date.year}';
}

String _formatValue(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}
