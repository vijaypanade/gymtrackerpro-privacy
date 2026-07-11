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
  final String proteinInsight;

  const _ScanData(this.recoveries, this.overall, this.proteinInsight);

  factory _ScanData.from(AppProvider ap) => _ScanData(
      ap.muscleRecoveryList, ap.getOverallRecovery(), ap.proteinRecoveryInsight);

  @override
  bool operator ==(Object other) {
    if (other is! _ScanData) return false;
    if (overall != other.overall) return false;
    if (proteinInsight != other.proteinInsight) return false;
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
        proteinInsight,
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
                    _ScanHeader(
                      overallScore:   data.overall,
                      hasData:        data.recoveries.isNotEmpty,
                      proteinInsight: data.proteinInsight,
                    ),
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
  final bool hasData;
  final String proteinInsight;
  const _ScanHeader({
    required this.overallScore,
    required this.hasData,
    this.proteinInsight = '',
  });

  @override
  Widget build(BuildContext context) {
    final color = recoveryColor(overallScore.toDouble());
    final status = recoveryStatus(overallScore.toDouble());

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          const Row(
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
              Spacer(),
              _LiveAiBadge(),
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
                hasData ? 'Body $status' : 'All muscles fresh',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          // New user context line
          if (!hasData) ...[
            const SizedBox(height: 6),
            const Text(
              'Baseline score — updates after your first workout.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
          // Nutrition limiter — one calm explanatory line, never a penalty
          if (hasData && proteinInsight.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              proteinInsight,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
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
            const Text(
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
    if (recoveries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gold.withValues(alpha: 0.07),
                AppColors.bgCard,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.20), width: 0.5),
          ),
          child: Column(
            children: [
              const Icon(Icons.track_changes_rounded,
                  color: AppColors.goldAmber, size: 32),
              const SizedBox(height: 10),
              const Text(
                'Recovery map builds as you train',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'After your first session, this section shows your most fatigued and most ready muscles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ));
  }
}
