// lib/widgets/home/athlete_brain_card.dart
//
// AthleteBrain Home Card — surfaces mission intelligence to the athlete.
// Pure UI. All computation is in AppProvider.brainCardData.
// Follows the Selector<AppProvider, T> + RepaintBoundary pattern.
// Expansion state is local — only this widget rebuilds on toggle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../ai/maturity/athlete_brain_presentation.dart';
import '../../brain/models/brain_card_data.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ── Widget ───────────────────────────────────────────────────────────────────

class AthleteBrainCard extends StatelessWidget {
  const AthleteBrainCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({BrainCardData data, String headerLabel, bool canShowWhyToggle, double progressPct, String footerCopy})>(
      selector: (_, ap) => (
        data:             ap.brainCardData,
        headerLabel:      ap.aiMaturity.phase.athleteBrainHeaderLabel,
        canShowWhyToggle: ap.aiMaturity.allowedClaims.ui.canShowWhyToggle,
        progressPct:      ap.aiMaturity.progressPct,
        footerCopy:       ap.aiMaturity.phase.calibratingFooterCopy,
      ),
      builder: (_, snap, __) => RepaintBoundary(
        child: _BrainCardContent(
          data:             snap.data,
          headerLabel:      snap.headerLabel,
          canShowWhyToggle: snap.canShowWhyToggle,
          progressPct:      snap.progressPct,
          footerCopy:       snap.footerCopy,
        ),
      ),
    );
  }
}

/// Content-only variant — no outer card shell.
/// Used inside [_PerformanceSection] which provides the shared container.
class AthleteBrainBody extends StatelessWidget {
  const AthleteBrainBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({BrainCardData data, String headerLabel, bool canShowWhyToggle, double progressPct, String footerCopy})>(
      selector: (_, ap) => (
        data:             ap.brainCardData,
        headerLabel:      ap.aiMaturity.phase.athleteBrainHeaderLabel,
        canShowWhyToggle: ap.aiMaturity.allowedClaims.ui.canShowWhyToggle,
        progressPct:      ap.aiMaturity.progressPct,
        footerCopy:       ap.aiMaturity.phase.calibratingFooterCopy,
      ),
      builder: (_, snap, __) => RepaintBoundary(
        child: _BrainCardContent(
          data:             snap.data,
          headerLabel:      snap.headerLabel,
          canShowWhyToggle: snap.canShowWhyToggle,
          progressPct:      snap.progressPct,
          footerCopy:       snap.footerCopy,
          showContainer:    false,
        ),
      ),
    );
  }
}

// ── Content (stateful for local expand/collapse) ──────────────────────────────

class _BrainCardContent extends StatefulWidget {
  final BrainCardData data;
  final String        headerLabel;
  final bool          canShowWhyToggle;
  final double        progressPct;
  final String        footerCopy;
  final bool          showContainer;
  const _BrainCardContent({
    required this.data,
    required this.headerLabel,
    required this.canShowWhyToggle,
    required this.progressPct,
    required this.footerCopy,
    this.showContainer = true,
  });

  @override
  State<_BrainCardContent> createState() => _BrainCardContentState();
}

class _BrainCardContentState extends State<_BrainCardContent> {
  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isOnboarding) {
      return const _OnboardingBrainContent(totalWorkouts: 0);
    }

    final data = widget.data;

    final column = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Always visible: icon + title + one human sentence ───────────
          _Header(headerLabel: widget.headerLabel),
          const SizedBox(height: 6),
          _MissionRow(data: data),
          const SizedBox(height: 4),
          _MissionVoice(data: data),
          const SizedBox(height: 4),

          // ── Expandable detail panel ─────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ExpandedPanel(data: data)
                : const SizedBox.shrink(),
          ),

          // ── Footer — Why toggle when unlocked, calibration bar while learning ──
          Container(height: 0.5, color: AppColors.borderSoft),
          if (widget.canShowWhyToggle)
            _WhyToggleRow(expanded: _expanded, onTap: _toggle)
          else
            _CalibratingFooter(progressPct: widget.progressPct, footerCopy: widget.footerCopy),
        ],
      ),
    );

    if (!widget.showContainer) return column;

    return Container(
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
      child: column,
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String headerLabel;
  const _Header({required this.headerLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.psychology_outlined, size: 16, color: AppColors.goldSoft),
        const SizedBox(width: 8),
        Text(
          headerLabel,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Mission row (label + icon only — recommendation moves to expanded) ────────

class _MissionRow extends StatelessWidget {
  final BrainCardData data;
  const _MissionRow({required this.data});

  // Presentation-only titles — plain language a first-week user understands.
  // Engine labels ("Deload Session") never reach the screen.
  static String _displayTitle(MissionType t) => switch (t) {
    MissionType.protectRecovery     => 'Recover today',
    MissionType.maintainConsistency => 'Train normally',
    MissionType.pushPerformance     => 'Ready to push',
    MissionType.comeback            => 'Ease back in',
    MissionType.deload              => 'Take it lighter today',
    MissionType.volumeReduction     => 'A little less today',
    MissionType.homeAdaptation      => 'Home session today',
    MissionType.technique           => 'Focus on form',
    MissionType.recoverySession     => 'Easy movement today',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MissionIcon(missionType: data.missionType),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _displayTitle(data.missionType),
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mission voice — one human sentence, coach speaking ─────────────────────────
// Presentation-only. Never numbers, never engine phrasing, never a restatement
// of the Recovery card. Recovery Card = body state; this card = today's call.

String _missionSentence(MissionType t) => switch (t) {
  MissionType.protectRecovery     =>
      'Your body is asking for an easier day.',
  MissionType.maintainConsistency =>
      'Showing up is the win today.',
  MissionType.pushPerformance     =>
      'Everything lines up. A good day to push.',
  MissionType.comeback            =>
      'Ease back in. No need to rush.',
  MissionType.deload              =>
      'You\'ve worked hard lately. A lighter day fits better.',
  MissionType.volumeReduction     =>
      'A little less today keeps you moving forward.',
  MissionType.homeAdaptation      =>
      'Today\'s plan works with what you have at home.',
  MissionType.technique           =>
      'Slow it down. Make every rep clean.',
  MissionType.recoverySession     =>
      'Light movement today. Nothing heavy.',
};

class _MissionVoice extends StatelessWidget {
  final BrainCardData data;
  const _MissionVoice({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Text(
        _missionSentence(data.missionType),
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Mission icon ──────────────────────────────────────────────────────────────

class _MissionIcon extends StatelessWidget {
  final MissionType missionType;
  const _MissionIcon({required this.missionType});

  IconData get _icon {
    switch (missionType) {
      case MissionType.protectRecovery:     return Icons.shield_outlined;
      case MissionType.maintainConsistency: return Icons.bar_chart_rounded;
      case MissionType.pushPerformance:     return Icons.bolt_rounded;
      case MissionType.comeback:            return Icons.local_fire_department_outlined;
      case MissionType.deload:              return Icons.remove_circle_outline_rounded;
      case MissionType.volumeReduction:     return Icons.trending_down_rounded;
      case MissionType.homeAdaptation:      return Icons.home_outlined;
      case MissionType.technique:           return Icons.track_changes_rounded;
      case MissionType.recoverySession:     return Icons.self_improvement_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.20), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, size: 18, color: AppColors.gold),
    );
  }
}

// ── Why? toggle row ───────────────────────────────────────────────────────────

class _WhyToggleRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _WhyToggleRow({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded ? 'Hide' : 'Why this?',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.goldSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.goldSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded detail panel ─────────────────────────────────────────────────────

class _ExpandedPanel extends StatelessWidget {
  final BrainCardData data;
  const _ExpandedPanel({required this.data});

  // Translate an engine signal into one quiet human line.
  // Numbers, scores and engine phrasing never reach the screen — a signal
  // that can't be said plainly is not shown. Presentation-only mapping.
  static String? _humanize(String signal) {
    final l = signal.toLowerCase();
    if (l.contains('%') || RegExp(r'\d').hasMatch(l)) {
      // Any numeric signal is a report, not a sentence.
      if (l.contains('fatigue'))  return 'Fatigue has been building.';
      if (l.contains('recover'))  return 'Recovery still needs time.';
      if (l.contains('volume'))   return 'Training has been heavy lately.';
      if (l.contains('streak') || l.contains('consisten')) {
        return 'You\'ve been showing up steadily.';
      }
      return null;
    }
    if (l.contains('fatigue'))   return 'Fatigue has been building.';
    if (l.contains('recover'))   return 'Recovery still needs time.';
    // Sleep belongs to other surfaces — this card never mentions it.
    if (l.contains('sleep'))     return null;
    if (l.contains('volume'))    return 'Training has been heavy lately.';
    if (l.contains('pr') || l.contains('record') || l.contains('strength')) {
      return 'Strength is trending up.';
    }
    if (l.contains('streak') || l.contains('consisten')) {
      return 'You\'ve been showing up steadily.';
    }
    if (l.contains('missed') || l.contains('gap') || l.contains('inactive')) {
      return 'There\'s been a gap in training.';
    }
    return null;
  }

  // Two short decision lines per mission — what to do, what comes next.
  static List<String> _decisionLines(MissionType t) => switch (t) {
    MissionType.protectRecovery     => [
      'Keep today easy.',
      'Normal training returns soon.',
    ],
    MissionType.maintainConsistency => [
      'A steady session is enough.',
      'No need to push for more.',
    ],
    MissionType.pushPerformance     => [
      'Push your main lifts today.',
      'This is a good window for it.',
    ],
    MissionType.comeback            => [
      'Start lighter than you think.',
      'Strength comes back fast.',
    ],
    MissionType.deload              => [
      'Keep today\'s volume lower.',
      'Normal training can return soon.',
    ],
    MissionType.volumeReduction     => [
      'Fewer sets today.',
      'Quality over quantity.',
    ],
    MissionType.homeAdaptation      => [
      'Work with what\'s available.',
      'The plan adapts with you.',
    ],
    MissionType.technique           => [
      'Lighter weight, cleaner reps.',
      'Control every rep.',
    ],
    MissionType.recoverySession     => [
      'A walk or light session is plenty.',
      'Heavy work waits a day.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    // Max 3 humanized signals, deduplicated. A silent panel is fine.
    final signals = <String>[];
    for (final s in data.dominantSignals) {
      final h = _humanize(s);
      if (h != null && !signals.contains(h)) signals.add(h);
      if (signals.length == 3) break;
    }
    final decision = _decisionLines(data.missionType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Container(height: 0.5, color: AppColors.borderSoft),
        const SizedBox(height: 12),

        // ── What the coach noticed ────────────────────────────────────────
        ...signals.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            s,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        )),
        if (signals.isNotEmpty) const SizedBox(height: 8),

        // ── The decision ──────────────────────────────────────────────────
        ...decision.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            s,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        )),

        const SizedBox(height: 6),
        Text(
          'We\'ll check again after your next session.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Calibrating footer — shown in place of toggle for workouts 1-4 ───────────

class _CalibratingFooter extends StatelessWidget {
  final double progressPct;
  final String footerCopy;
  const _CalibratingFooter({required this.progressPct, required this.footerCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    minHeight: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Recovery Intelligence',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.goldSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            footerCopy,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onboarding state (0 workouts) ────────────────────────────────────────────

class _OnboardingBrainContent extends StatelessWidget {
  final int totalWorkouts;
  const _OnboardingBrainContent({required this.totalWorkouts});

  @override
  Widget build(BuildContext context) {
    return Container(

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — identical pattern to active card _Header
            Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 16, color: AppColors.goldSoft),
                const SizedBox(width: 8),
                const Text(
                  'Athlete Brain',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.22),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Inactive',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.goldSoft,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Hero message
            Text(
              'Train once to activate.',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Recovery intelligence unlocks after your first session.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 0.5, color: AppColors.borderSoft),
            const SizedBox(height: 8),
            // Signal collection footer — no CTA
            // At 0 workouts skip LinearProgressIndicator entirely (avoids
            // Material 3 rounded-indicator dot artifact at value=0).
            if (totalWorkouts == 0)
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalWorkouts / 5.0,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  minHeight: 2,
                ),
              ),
            const SizedBox(height: 5),
            Text(
              'Recovery Intelligence',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.goldSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Activates after first session',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
