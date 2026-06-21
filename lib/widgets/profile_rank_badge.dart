// lib/widgets/profile_rank_badge.dart
// ──────────────────────────────────────────────────────────────────────────────
// Elite rank badge for the Profile header.
// Replaces per-rank purple/blue/red gradient with a unified metallic gold palette.
// Consists of: animated gold orb (breathing pulse) + rank-name pill with Roman tier.
// ──────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_constants.dart';

// ─── Metallic gold gradient ───────────────────────────────────────────────────
// Six stops simulate how polished metal catches and loses light across its face:
// deep shadow → dark body → bright highlight → warm core → dark body → shadow.
const LinearGradient _kMetallicGold = LinearGradient(
  colors: [
    Color(0xFF2E1A00), // 0 %  – deep cast shadow
    Color(0xFF8B6914), // 20%  – dark metal body
    Color(0xFFFFE066), // 42%  – highlight peak (light catch)
    Color(0xFFD4AF37), // 60%  – warm gold core
    Color(0xFFA8892C), // 80%  – receding metal
    Color(0xFF2E1A00), // 100% – shadow mirror
  ],
  stops: [0.0, 0.20, 0.42, 0.60, 0.80, 1.0],
  begin: Alignment(-1.0, -1.0),
  end: Alignment(1.0, 1.0),
);

// Pill gradient — lighter, horizontal shimmer for the label.
const LinearGradient _kPillGold = LinearGradient(
  colors: [Color(0xFF4A2E00), AppColors.gold, Color(0xFF4A2E00)],
  stops: [0.0, 0.50, 1.0],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// Roman tier numeral — elevates the badge beyond a simple label.
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
  late final Animation<double> _glowAlpha;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glowAlpha = Tween<double>(begin: 0.16, end: 0.38)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Metallic Orb ─────────────────────────────────────────────────
        SizedBox(
          width: 68, height: 68,
          child: Stack(alignment: Alignment.center, children: [
            // Breathing glow halo — scales slightly with pulse
            Container(
              width: 68 * _pulse.value,
              height: 68 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.gold.withValues(alpha: _glowAlpha.value),
                  blurRadius: 22,
                  spreadRadius: 5,
                )],
              ),
            ),
            // Outer rim — full metallic gradient ring
            Container(
              width: 62, height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: _kMetallicGold,
              ),
            ),
            // Inner recess — near-black core creates coin-rim depth illusion
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF090600),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.18), width: 0.5),
              ),
              child: Center(
                child: Text(
                  _kRomanTier[widget.rank] ?? 'I',
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    color: Color(0xFFD4AF37),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 7),

        // ── Rank Name Pill ────────────────────────────────────────────────
        // Gold gradient pill with Roman tier marker.
        // Text is dark near-black so it reads clearly against the gold fill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            gradient: _kPillGold,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.rank.displayName,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF1A0C00),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '· ${_kRomanTier[widget.rank] ?? ''}',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0x801A0C00), // 50% alpha on the dark ink
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ],
    ),
  );
}
