// lib/widgets/profile_rank_badge.dart
// ──────────────────────────────────────────────────────────────────────────────
// Elite rank badge for the Profile header.
// Replaces per-rank purple/blue/red gradient with a unified metallic gold palette.
// Consists of: animated gold orb (breathing pulse) + rank-name pill with Roman tier.
// ──────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_constants.dart';

// Roman tier numeral — differentiates tiers without color.
const Map<UserRank, String> _kRomanTier = {
  UserRank.recruit:   'I',
  UserRank.warrior:   'II',
  UserRank.gladiator: 'III',
  UserRank.champion:  'IV',
  UserRank.legend:    'V',
  UserRank.beast:     'VI',
};

// ─────────────────────────────────────────────────────────────────────────────
// ProfileHeaderBadge
// ─────────────────────────────────────────────────────────────────────────────
/// Drop-in replacement for the `_PulseOrb` + inline rank pill inside HeroCard.
/// All six user ranks share the same metallic gold palette — no purple, no blue,
/// no red. Tier differentiation comes from the Roman numeral on the pill.
class ProfileHeaderBadge extends StatefulWidget {
  final UserRank rank;
  const ProfileHeaderBadge({super.key, required this.rank});
  @override State<ProfileHeaderBadge> createState() => _ProfileHeaderBadgeState();
}

class _ProfileHeaderBadgeState extends State<ProfileHeaderBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => SizedBox(
      width: 60, height: 60,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0C0C0C),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.55 + 0.45 * _pulse.value),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            _kRomanTier[widget.rank] ?? 'I',
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              color: AppColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    ),
  );
}
