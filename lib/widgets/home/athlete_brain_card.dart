// lib/widgets/home/athlete_brain_card.dart
//
// AthleteBrain Home Card — surfaces mission intelligence to the athlete.
// Pure UI. All computation is in AppProvider.brainCardData.
// Follows the Selector<AppProvider, T> + RepaintBoundary pattern.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../brain/models/brain_card_data.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ── Widget ───────────────────────────────────────────────────────────────────

class AthleteBrainCard extends StatelessWidget {
  const AthleteBrainCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, BrainCardData>(
      selector: (_, ap) => ap.brainCardData,
      builder:  (_, data, __) => RepaintBoundary(
        child: _BrainCardContent(data: data),
      ),
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _BrainCardContent extends StatelessWidget {
  final BrainCardData data;
  const _BrainCardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isOnboarding) return _OnboardingBrainContent();
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF141414), Color(0xFF0C0C0C), Color(0xFF101010)],
          stops:  [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(data: data),
            const SizedBox(height: 16),
            _MissionRow(data: data),
            const SizedBox(height: 18),
            _Divider(),
            const SizedBox(height: 14),
            _WhySection(data: data),
            const SizedBox(height: 14),
            _Divider(),
            const SizedBox(height: 14),
            _FooterRow(data: data),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final BrainCardData data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '\u{1F9E0}',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8),
        Text(
          "Today's Mission",
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        _ConfidenceBadge(pct: data.confidencePct),
      ],
    );
  }
}

// ── Confidence badge ──────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final int pct;
  const _ConfidenceBadge({required this.pct});

  Color get _color {
    if (pct >= 75) return AppColors.green;
    if (pct >= 55) return AppColors.gold;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$pct% confidence',
            style: AppTextStyles.caption.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}

// ── Mission row ───────────────────────────────────────────────────────────────

class _MissionRow extends StatelessWidget {
  final BrainCardData data;
  const _MissionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MissionIcon(missionType: data.missionType),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.missionLabel,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.goldHero,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.recommendation,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mission icon ──────────────────────────────────────────────────────────────

class _MissionIcon extends StatelessWidget {
  final MissionType missionType;
  const _MissionIcon({required this.missionType});

  String get _emoji {
    switch (missionType) {
      case MissionType.protectRecovery:   return '\u{1F6E1}';  // 🛡
      case MissionType.maintainConsistency: return '\u{1F4CA}'; // 📊
      case MissionType.pushPerformance:   return '\u{26A1}';   // ⚡
      case MissionType.comeback:          return '\u{1F525}';  // 🔥
      case MissionType.deload:            return '\u{1F4AB}';  // 💫
      case MissionType.volumeReduction:   return '\u{1F53D}';  // 🔽
      case MissionType.homeAdaptation:    return '\u{1F3E0}';  // 🏠
      case MissionType.technique:         return '\u{1F3AF}';  // 🎯
      case MissionType.recoverySession:   return '\u{1F9D8}';  // 🧘
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.20), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(_emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

// ── Why section ───────────────────────────────────────────────────────────────

class _WhySection extends StatelessWidget {
  final BrainCardData data;
  const _WhySection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why this decision?',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ...data.dominantSignals.take(3).map(
          (signal) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    signal,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.confidenceNarrative,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── Footer row ────────────────────────────────────────────────────────────────

class _FooterRow extends StatelessWidget {
  final BrainCardData data;
  const _FooterRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FooterItem(
            icon: '\u{1F464}',
            label: 'Identity',
            value: _capitalize(data.identityLabel),
          ),
        ),
        _VerticalSep(),
        Expanded(
          child: _FooterItem(
            icon: '⏱',
            label: 'Session',
            value: '${data.preferredDurationMinutes} min',
          ),
        ),
        _VerticalSep(),
        Expanded(
          child: _FooterItem(
            icon: '\u{1F4AA}',
            label: 'Recovery',
            value: data.recoveryLabel,
            valueColor: _recoveryColor(data.recoveryScore),
          ),
        ),
      ],
    );
  }

  Color _recoveryColor(int score) {
    if (score >= 75) return AppColors.green;
    if (score >= 50) return AppColors.gold;
    return AppColors.red;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _FooterItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _FooterItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VerticalSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 44,
      color: AppColors.borderSoft,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: AppColors.borderSoft);
  }
}

// ── Onboarding state (0 workouts) ────────────────────────────────────────────

class _OnboardingBrainContent extends StatelessWidget {
  static const _stages = [
    'Building',
    'Developing',
    'Consistent',
    'Disciplined',
    'Elite',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF141414), Color(0xFF0C0C0C), Color(0xFF101010)],
          stops:  [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.04),
            blurRadius: 40,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('\u{1F9E0}', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Athlete Brain',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.textMuted.withValues(alpha: 0.20),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Waiting for data',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Hero message
            Text(
              'Your Training Brain is Ready',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.goldHero,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first workout to activate personalised intelligence. '
              'The more you train, the smarter it gets.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 0.5, color: AppColors.borderSoft),
            const SizedBox(height: 16),
            // Progress indicator
            Text(
              'ACTIVATION PROGRESS',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '0 / 1 workout',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 0.5, color: AppColors.borderSoft),
            const SizedBox(height: 16),
            // Identity path
            Text(
              'YOUR PATH',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _stages.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                final color   = isFirst ? AppColors.gold : AppColors.textMuted.withValues(alpha: 0.25);
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              e.value,
                              style: AppTextStyles.caption.copyWith(
                                color: isFirst ? AppColors.gold : AppColors.textMuted.withValues(alpha: 0.35),
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      if (e.key < _stages.length - 1) const SizedBox(width: 4),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
