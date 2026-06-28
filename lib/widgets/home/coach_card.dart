// lib/widgets/home/coach_card.dart
//
// CoachCard — surfaces the CoachBrain V1 deterministic coaching message.
// Pure UI. All data comes from AppProvider.coachMessage + AppProvider.brainCardData.
// Follows the Selector<AppProvider, T> + RepaintBoundary pattern.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../coach/models/coach_intent.dart';
import '../../coach/models/coach_message.dart';
import '../../coach/models/coach_mode.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ── Combined data snapshot ────────────────────────────────────────────────────

@immutable
class _CoachCardData {
  final BrainCoachMessage coachMessage;
  final String            missionLabel;
  final int               confidencePct;
  final String            identityLabel;
  final int               preferredDurationMinutes;
  final String            recoveryLabel;
  final int               recoveryScore;
  final bool              hasBrainData;

  const _CoachCardData({
    required this.coachMessage,
    required this.missionLabel,
    required this.confidencePct,
    required this.identityLabel,
    required this.preferredDurationMinutes,
    required this.recoveryLabel,
    required this.recoveryScore,
    required this.hasBrainData,
  });

  factory _CoachCardData.from(AppProvider ap) {
    final bd = ap.brainCardData;
    return _CoachCardData(
      coachMessage:             ap.coachMessage,
      missionLabel:             bd.missionLabel,
      confidencePct:            bd.confidencePct,
      identityLabel:            bd.identityLabel,
      preferredDurationMinutes: bd.preferredDurationMinutes,
      recoveryLabel:            bd.recoveryLabel,
      recoveryScore:            bd.recoveryScore,
      hasBrainData:             bd.confidencePct > 0,
    );
  }

  bool get isOnboarding => coachMessage.isOnboarding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _CoachCardData) return false;
    return other.coachMessage             == coachMessage             &&
           other.missionLabel             == missionLabel             &&
           other.confidencePct            == confidencePct            &&
           other.identityLabel            == identityLabel            &&
           other.preferredDurationMinutes == preferredDurationMinutes &&
           other.recoveryLabel            == recoveryLabel            &&
           other.recoveryScore            == recoveryScore            &&
           other.hasBrainData             == hasBrainData;
  }

  @override
  int get hashCode => Object.hash(
    coachMessage, missionLabel, confidencePct, identityLabel,
    preferredDurationMinutes, recoveryLabel, recoveryScore, hasBrainData,
  );
}

// ── Public widget ─────────────────────────────────────────────────────────────

class CoachCard extends StatelessWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _CoachCardData>(
      selector: (_, ap) => _CoachCardData.from(ap),
      builder:  (_, data, __) => RepaintBoundary(
        child: _CoachCardContent(data: data),
      ),
    );
  }
}

// ── Card container ────────────────────────────────────────────────────────────

class _CoachCardContent extends StatelessWidget {
  final _CoachCardData data;
  const _CoachCardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isOnboarding) return const _OnboardingCoachContent();
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            _modeAccent(data.coachMessage.tone).withValues(alpha: 0.06),
            const Color(0xFF0C0C0C),
            const Color(0xFF101010),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: _modeAccent(data.coachMessage.tone).withValues(alpha: 0.22),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.70),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _modeAccent(data.coachMessage.tone).withValues(alpha: 0.05),
            blurRadius: 32,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(data: data),
            if (data.coachMessage.hasWarning) ...[
              const SizedBox(height: 12),
              const _WarningBanner(),
            ],
            if (data.coachMessage.isCelebration) ...[
              const SizedBox(height: 12),
              const _CelebrationBanner(),
            ],
            const SizedBox(height: 16),
            _HeroTitle(data: data),
            const SizedBox(height: 8),
            _Subtitle(data: data),
            const SizedBox(height: 16),
            _PrimaryAction(data: data),
            const SizedBox(height: 16),
            _CardDivider(),
            const SizedBox(height: 14),
            _FooterRow(data: data),
          ],
        ),
      ),
    );
  }

  static Color _modeAccent(CoachMode mode) {
    switch (mode) {
      case CoachMode.motivate:  return AppColors.goldHero;
      case CoachMode.protect:   return AppColors.red;
      case CoachMode.celebrate: return AppColors.green;
      case CoachMode.guide:     return AppColors.goldSoft;
      case CoachMode.nudge:     return AppColors.gold;
      case CoachMode.educate:   return AppColors.goldAmber;
    }
  }
}

// ── Header — Coach Mode badge + mission context ───────────────────────────────

class _Header extends StatelessWidget {
  final _CoachCardData data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeBadge(mode: data.coachMessage.tone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Mission: ${data.missionLabel}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _ConfidenceChip(pct: data.confidencePct),
      ],
    );
  }
}

// ── Mode badge ────────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final CoachMode mode;
  const _ModeBadge({required this.mode});

  Color get _color {
    switch (mode) {
      case CoachMode.motivate:  return AppColors.goldHero;
      case CoachMode.protect:   return AppColors.red;
      case CoachMode.celebrate: return AppColors.green;
      case CoachMode.guide:     return AppColors.goldSoft;
      case CoachMode.nudge:     return AppColors.gold;
      case CoachMode.educate:   return AppColors.goldAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        mode.label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ── Confidence chip ───────────────────────────────────────────────────────────

class _ConfidenceChip extends StatelessWidget {
  final int pct;
  const _ConfidenceChip({required this.pct});

  Color get _color {
    if (pct >= 75) return AppColors.green;
    if (pct >= 50) return AppColors.gold;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$pct%',
          style: AppTextStyles.caption.copyWith(
            color: _color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Warning banner ────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            'Recovery warning — protect your body today',
            style: AppTextStyles.caption.copyWith(color: AppColors.red),
          ),
        ],
      ),
    );
  }
}

// ── Celebration banner ────────────────────────────────────────────────────────

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        children: [
          const Text('\u{1F3C6}', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            'You\'re in a performance window — capitalize on it',
            style: AppTextStyles.caption.copyWith(color: AppColors.green),
          ),
        ],
      ),
    );
  }
}

// ── Hero title ────────────────────────────────────────────────────────────────

class _HeroTitle extends StatelessWidget {
  final _CoachCardData data;
  const _HeroTitle({required this.data});

  @override
  Widget build(BuildContext context) {
    return Text(
      data.coachMessage.title,
      style: AppTextStyles.h2.copyWith(
        color: AppColors.goldHero,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }
}

// ── Subtitle ──────────────────────────────────────────────────────────────────

class _Subtitle extends StatelessWidget {
  final _CoachCardData data;
  const _Subtitle({required this.data});

  @override
  Widget build(BuildContext context) {
    return Text(
      data.coachMessage.subtitle,
      style: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}

// ── Primary action ────────────────────────────────────────────────────────────

class _PrimaryAction extends StatelessWidget {
  final _CoachCardData data;
  const _PrimaryAction({required this.data});

  static Color _accentFor(CoachIntent intent) {
    switch (intent) {
      case CoachIntent.warnOvertraining:  return AppColors.red;
      case CoachIntent.celebratePR:       return AppColors.green;
      case CoachIntent.suggestRecovery:   return AppColors.goldSoft;
      case CoachIntent.triggerComeback:   return AppColors.gold;
      case CoachIntent.encourageConsistency:
      case CoachIntent.reinforceIdentity:
      case CoachIntent.acknowledgeMilestone:
      case CoachIntent.redirectFocus:     return AppColors.goldHero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(data.coachMessage.intent);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data.coachMessage.primaryAction,
            style: AppTextStyles.button.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 14),
        ],
      ),
    );
  }
}

// ── Footer row ────────────────────────────────────────────────────────────────

class _FooterRow extends StatelessWidget {
  final _CoachCardData data;
  const _FooterRow({required this.data});

  Color _recoveryColor(int score) {
    if (score >= 75) return AppColors.green;
    if (score >= 50) return AppColors.gold;
    return AppColors.red;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
        _VSep(),
        Expanded(
          child: _FooterItem(
            icon: '⏱',
            label: 'Session',
            value: '${data.preferredDurationMinutes} min',
          ),
        ),
        _VSep(),
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
}

class _FooterItem extends StatelessWidget {
  final String  icon;
  final String  label;
  final String  value;
  final Color?  valueColor;

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

class _VSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, height: 44, color: AppColors.borderSoft);
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.borderSoft);
}

// ── Onboarding state (0 workouts) ────────────────────────────────────────────

class _OnboardingCoachContent extends StatelessWidget {
  const _OnboardingCoachContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            AppColors.goldSoft.withValues(alpha: 0.06),
            const Color(0xFF0C0C0C),
            const Color(0xFF101010),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.goldSoft.withValues(alpha: 0.22),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.70),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(
                      color: AppColors.goldSoft.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'GUIDE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.goldSoft,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Day one',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              BrainCoachMessage.onboarding.title,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.goldHero,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              BrainCoachMessage.onboarding.subtitle,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Primary action
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () {
                  // Navigate to Planner tab
                  final shell = ctx.findAncestorWidgetOfExactType<Scaffold>();
                  if (shell == null) return;
                  Navigator.of(ctx).popUntil((r) => r.isFirst);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.goldHero.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: Border.all(
                      color: AppColors.goldHero.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        BrainCoachMessage.onboarding.primaryAction,
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.goldHero,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.goldHero,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
