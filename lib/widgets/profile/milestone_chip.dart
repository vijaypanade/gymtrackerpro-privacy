// lib/widgets/profile/milestone_chip.dart
//
// MilestoneChip — compact pill displaying a single Milestone.
// Read-only. No business logic.

import 'package:flutter/material.dart';

import '../../timeline/models/milestone.dart';
import '../../utils/app_constants.dart';

class MilestoneChip extends StatelessWidget {
  final Milestone milestone;
  const MilestoneChip({super.key, required this.milestone});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(milestone.tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(milestone.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            milestone.title,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

Color _tierColor(MilestoneTier tier) {
  switch (tier) {
    case MilestoneTier.legendary: return AppColors.goldHero;
    case MilestoneTier.gold:      return AppColors.gold;
    case MilestoneTier.silver:    return AppColors.textSecondary;
    case MilestoneTier.bronze:    return AppColors.orange;
  }
}
