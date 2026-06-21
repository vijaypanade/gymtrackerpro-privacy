// lib/widgets/home/momentum_arc_card.dart
// Momentum arc — compact WHOOP-style score card.
// Shows score arc, status label, one-line narrative.
// Calm, performance-oriented. No gamification noise.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/momentum_state.dart';
import '../../models/athlete_identity.dart';
import '../../models/daily_mission.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ── Data snapshot — structural equality prevents rebuild storms ──────────────
@immutable
class _MomentumData {
  final MomentumState     momentum;
  final AthleteIdentityStage identity;
  final CoachMission      mission;

  const _MomentumData({
    required this.momentum,
    required this.identity,
    required this.mission,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _MomentumData &&
          other.momentum.score          == momentum.score &&
          other.momentum.atRisk         == momentum.atRisk &&
          other.momentum.rising         == momentum.rising &&
          other.momentum.lockedIn       == momentum.lockedIn &&
          other.momentum.workedOutToday == momentum.workedOutToday &&
          other.identity                == identity &&
          other.mission.title           == mission.title);

  @override
  int get hashCode =>
      Object.hash(momentum.score, momentum.atRisk, momentum.rising,
          momentum.lockedIn, momentum.workedOutToday, identity, mission.title);
}

// ── Public widget ────────────────────────────────────────────────────────────
class MomentumArcCard extends StatelessWidget {
  const MomentumArcCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _MomentumData>(
      selector: (_, ap) => _MomentumData(
        momentum: ap.momentumState,
        identity: ap.identityStage,
        mission:  ap.dailyMission,
      ),
      builder: (_, data, __) => RepaintBoundary(
        child: _MomentumCardContent(data: data),
      ),
    );
  }
}

// ── Card content ─────────────────────────────────────────────────────────────
class _MomentumCardContent extends StatelessWidget {
  final _MomentumData data;
  const _MomentumCardContent({required this.data});

  Color get _accentColor {
    switch (data.momentum.colorSignal) {
      case 1:  return const Color(0xFF22D3EE); // rising — cyan
      case 2:  return const Color(0xFFF59E0B); // at risk — amber
      case 3:  return const Color(0xFFFF6B35); // locked in — orange
      default: return const Color(0xFFD4AF37); // neutral — gold
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          // ── Score arc ─────────────────────────────────────
          _ScoreArc(
            score:  data.momentum.score,
            accent: accent,
          ),
          const SizedBox(width: AppSpacing.lg),
          // ── Text area ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status header row
                Row(
                  children: [
                    Text(
                      'MOMENTUM',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.25), width: 0.7),
                      ),
                      child: Text(
                        data.momentum.statusLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: accent,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Narrative
                Text(
                  data.momentum.narrativeLine,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Daily mission chip
                _MissionChip(mission: data.mission, accent: accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arc gauge ────────────────────────────────────────────────────────────────
class _ScoreArc extends StatelessWidget {
  final int   score;
  final Color accent;

  const _ScoreArc({required this.score, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _ArcPainter(score: score, accent: accent),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: GoogleFonts.rajdhani(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final int   score;
  final Color accent;

  _ArcPainter({required this.score, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const startAngle = math.pi * 0.75;
    const sweepFull  = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepFull, false, trackPaint,
    );

    // Fill
    if (score > 0) {
      final fillPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      final sweep = sweepFull * (score / 100).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, false, fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.score != score || old.accent != accent;
}

// ── Mission chip ─────────────────────────────────────────────────────────────
class _MissionChip extends StatelessWidget {
  final CoachMission mission;
  final Color        accent;

  const _MissionChip({required this.mission, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: accent.withValues(alpha: 0.18), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mission.typeTag,
            style: TextStyle(
              fontFamily: 'Inter',
              color: accent.withValues(alpha: 0.80),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              mission.title,
              maxLines: 2,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
