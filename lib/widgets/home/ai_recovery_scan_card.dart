// lib/widgets/home/ai_recovery_scan_card.dart
// "AI Recovery Scan" — LiftOn's signature premium muscle-recovery feature.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';
import 'layered_body_heatmap.dart';
import 'muscle_command_sheet.dart';
import 'muscle_overlay_painter.dart';

// ── Equality wrapper so Selector avoids unnecessary rebuilds ──────────────────

@immutable
class _ScanData {
  final List<MuscleRecovery> recoveries;
  final int overall;

  const _ScanData(this.recoveries, this.overall);

  factory _ScanData.from(AppProvider ap) =>
      _ScanData(ap.muscleRecoveryList, ap.getOverallRecovery());

  @override
  bool operator ==(Object other) {
    if (other is! _ScanData) return false;
    if (overall != other.overall) return false;
    if (recoveries.length != other.recoveries.length) return false;
    for (var i = 0; i < recoveries.length; i++) {
      if (recoveries[i].recoveryScore != other.recoveries[i].recoveryScore) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        overall,
        Object.hashAll(recoveries.map((r) => r.recoveryScore)),
      );
}

// ── Main card ─────────────────────────────────────────────────────────────────

class AiRecoveryScanCard extends StatelessWidget {
  const AiRecoveryScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _ScanData>(
      selector: (_, ap) => _ScanData.from(ap),
      builder: (ctx, data, _) {
        final scoreMap = {
          for (final r in data.recoveries)
            r.muscle.toLowerCase(): r.recoveryScore.toDouble(),
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          decoration: BoxDecoration(
            // Glass-metal gradient: slightly lighter at top (overhead light)
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF141414), // slightly lighter — catches light
                Color(0xFF0C0C0C), // deep black base
                Color(0xFF101010), // subtle right-side lift
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: const Color(0xFF242424), width: 0.5),
            boxShadow: [
              // Deep ambient drop shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.80),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              // Outer gold glow — very subtle
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: Stack(
              children: [
                // Inner gold edge reflection — top-left corner catch
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00D4A843),
                          Color(0x22D4A843),
                          Color(0x40D4A843),
                          Color(0x22D4A843),
                          Color(0x00D4A843),
                        ],
                        stops: [0.0, 0.20, 0.50, 0.80, 1.0],
                      ),
                    ),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScanHeader(overallScore: data.overall),
                    // Gold gradient divider
                    _GoldDivider(),
                    LayeredBodyHeatmap(
                      scores: scoreMap,
                      recoveries: data.recoveries,
                    ),
                    _GoldDivider(),
                    _KeyInsightsRow(recoveries: data.recoveries),
                    _GoldDivider(),
                    _MuscleStatusRow(recoveries: data.recoveries),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Gold gradient divider ─────────────────────────────────────────────────────

class _GoldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00D4A843),
            Color(0x18D4A843),
            Color(0x28D4A843),
            Color(0x18D4A843),
            Color(0x00D4A843),
          ],
          stops: [0.0, 0.20, 0.50, 0.80, 1.0],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ScanHeader extends StatelessWidget {
  final int overallScore;
  const _ScanHeader({required this.overallScore});

  @override
  Widget build(BuildContext context) {
    final color = recoveryColor(overallScore.toDouble());
    final status = recoveryStatus(overallScore.toDouble());

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row — single badge, no redundancy
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Recovery',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              const _LiveAiBadge(),
            ],
          ),
          const SizedBox(height: 10),
          // Score + status row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$overallScore%',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Body $status',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusDot({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing status dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeInOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'BODY $status',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Score ring in header — more cinematic, larger presence
class _HeaderScoreRing extends StatelessWidget {
  final double score;
  final Color color;
  const _HeaderScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Track
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 2.4,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(
              AppColors.bgElevated,
            ),
            strokeCap: StrokeCap.round,
          ),
          // Progress arc
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: score / 100.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => CircularProgressIndicator(
              value: v,
              strokeWidth: 2.4,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toInt()}',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Live AI badge ─────────────────────────────────────────────────────────────

class _LiveAiBadge extends StatefulWidget {
  const _LiveAiBadge();

  @override
  State<_LiveAiBadge> createState() => _LiveAiBadgeState();
}

class _LiveAiBadgeState extends State<_LiveAiBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1200),
              Color.lerp(const Color(0xFF1A1200), const Color(0xFF221800), _anim.value)!,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35 + _anim.value * 0.20),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08 + _anim.value * 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                color: AppColors.goldHero.withValues(alpha: 0.7 + _anim.value * 0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldHero.withValues(alpha: 0.5 * _anim.value),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Live',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.goldSoft,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Key Insights row ──────────────────────────────────────────────────────────

class _KeyInsightsRow extends StatelessWidget {
  final List<MuscleRecovery> recoveries;
  const _KeyInsightsRow({required this.recoveries});

  @override
  Widget build(BuildContext context) {
    if (recoveries.isEmpty) return const SizedBox.shrink();

    final sorted = [...recoveries]
      ..sort((a, b) => a.recoveryScore.compareTo(b.recoveryScore));
    final fatigued = sorted.first;
    final ready = sorted.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: _InsightCard(
              label: 'Most fatigued',
              muscle: fatigued.muscle,
              score: fatigued.recoveryScore.toDouble(),
              icon: Icons.warning_amber_rounded,
              blurb: _muscleBlurb(fatigued.muscle, fatigued.recoveryScore.toDouble()),
              trendUp: false,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _InsightCard(
              label: 'Most ready',
              muscle: ready.muscle,
              score: ready.recoveryScore.toDouble(),
              icon: Icons.bolt_rounded,
              blurb: _muscleBlurb(ready.muscle, ready.recoveryScore.toDouble()),
              trendUp: true,
            ),
          ),
        ],
      ),
    );
  }

  static String _muscleBlurb(String muscle, double score) {
    if (score >= 80) return 'Primed for heavy loading';
    if (score >= 60) return 'Building back steadily';
    if (score >= 40) {
      final hours = ((100 - score) / 2.8).round();
      return 'Needs ~${hours}h recovery';
    }
    return 'Overtaxed — rest advised';
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String muscle;
  final double score;
  final IconData icon;
  final String blurb;
  final bool trendUp;

  const _InsightCard({
    required this.label,
    required this.muscle,
    required this.score,
    required this.icon,
    required this.blurb,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final color = recoveryColor(score);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        // Glass-metal panel: subtle gradient background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.07),
            color.withValues(alpha: 0.03),
            AppColors.bgCard.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.40, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner highlight — top edge (bevel simulation)
          Positioned(
            top: -11, left: 0, right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0),
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 11),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: color.withValues(alpha: 0.75),
                    size: 13,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                muscle,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              // Score bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score / 100.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 2,
                    backgroundColor: AppColors.bgElevated,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                blurb,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 7.5,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.85),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom muscle legend ──────────────────────────────────────────────────────

class _MuscleStatusRow extends StatelessWidget {
  final List<MuscleRecovery> recoveries;
  const _MuscleStatusRow({required this.recoveries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: recoveries.map((r) => _MuscleChip(recovery: r)).toList(),
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final MuscleRecovery recovery;
  const _MuscleChip({required this.recovery});

  @override
  Widget build(BuildContext context) {
    final score = recovery.recoveryScore.toDouble();
    final color = recoveryColor(score);

    return GestureDetector(
      onTap: () => MuscleCommandSheet.show(context, recovery),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.09),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.09),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            recovery.muscle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ));
  }
}
