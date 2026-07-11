// lib/widgets/home/coach_card.dart
//
// CoachCard — surfaces the CoachBrain V1 deterministic coaching message.
// Pure UI. All data comes from AppProvider.coachMessage + AppProvider.brainCardData.
// Follows the Selector<AppProvider, T> + RepaintBoundary pattern.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../brain/models/brain_card_data.dart' show MissionType;
import '../../screens/main_shell.dart' show MainShellState;
import '../../coach/models/coach_message.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ── Combined data snapshot ────────────────────────────────────────────────────

@immutable
class _CoachCardData {
  final BrainCoachMessage coachMessage;
  final MissionType       missionType;
  final String            missionLabel;
  final int               confidencePct;
  final String            identityLabel;
  final int               preferredDurationMinutes;
  final String            recoveryLabel;
  final int               recoveryScore;
  final bool              hasBrainData;
  final int               totalWorkouts;
  // Today's plan fields — same source as _TrainingDecisionCard
  final String            planTitle;
  final int               exerciseCount;
  final bool              isCompleted;
  final bool              isRestDay;
  final double            totalVolume;
  final String            topMuscleGroup;
  final int               todayPRCount;

  const _CoachCardData({
    required this.coachMessage,
    required this.missionType,
    required this.missionLabel,
    required this.confidencePct,
    required this.identityLabel,
    required this.preferredDurationMinutes,
    required this.recoveryLabel,
    required this.recoveryScore,
    required this.hasBrainData,
    required this.totalWorkouts,
    required this.planTitle,
    required this.exerciseCount,
    required this.isCompleted,
    required this.isRestDay,
    required this.totalVolume,
    required this.topMuscleGroup,
    required this.todayPRCount,
  });

  factory _CoachCardData.from(AppProvider ap) {
    final bd   = ap.brainCardData;
    final plan = ap.todayPlan;
    return _CoachCardData(
      coachMessage:             ap.coachMessage,
      missionType:              bd.missionType,
      missionLabel:             bd.missionLabel,
      confidencePct:            bd.confidencePct,
      identityLabel:            bd.identityLabel,
      preferredDurationMinutes: bd.preferredDurationMinutes,
      recoveryLabel:            bd.recoveryLabel,
      recoveryScore:            bd.recoveryScore,
      hasBrainData:             bd.confidencePct > 0,
      totalWorkouts:            ap.totalWorkouts,
      planTitle:                plan.title,
      exerciseCount:            plan.exercises.length,
      isCompleted:              plan.isCompleted,
      isRestDay:                plan.isRestDay,
      totalVolume:              plan.exercises
          .expand((e) => e.sets)
          .where((s) => s.done && s.weight > 0 && s.reps > 0)
          .fold(0.0, (v, s) => v + s.weight * s.reps),
      topMuscleGroup:           ap.topMuscleGroup,
      todayPRCount:             ap.recentPRs
          .where((pr) => DateTime.now().difference(pr.date).inHours < 24)
          .length,
    );
  }

  bool get isOnboarding => coachMessage.isOnboarding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _CoachCardData) return false;
    return other.coachMessage             == coachMessage             &&
           other.missionType              == missionType              &&
           other.missionLabel             == missionLabel             &&
           other.confidencePct            == confidencePct            &&
           other.identityLabel            == identityLabel            &&
           other.preferredDurationMinutes == preferredDurationMinutes &&
           other.recoveryLabel            == recoveryLabel            &&
           other.recoveryScore            == recoveryScore            &&
           other.hasBrainData             == hasBrainData             &&
           other.totalWorkouts            == totalWorkouts            &&
           other.planTitle                == planTitle                &&
           other.exerciseCount            == exerciseCount            &&
           other.isCompleted              == isCompleted              &&
           other.isRestDay                == isRestDay                &&
           other.totalVolume              == totalVolume              &&
           other.topMuscleGroup           == topMuscleGroup           &&
           other.todayPRCount             == todayPRCount;
  }

  @override
  int get hashCode => Object.hash(
    coachMessage, missionType, missionLabel, confidencePct, identityLabel,
    preferredDurationMinutes, recoveryLabel, recoveryScore, hasBrainData,
    totalWorkouts, planTitle, exerciseCount, isCompleted, isRestDay, totalVolume, topMuscleGroup, todayPRCount,
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
    if (data.totalWorkouts == 0) return const _OnboardingCoachContent();
    if (data.totalWorkouts < 5)  return _WarmingUpCoachContent(data: data);
    return Container(

      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: const Color(0xFF242424),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(data: data),
            if (data.coachMessage.hasWarning) ...[
              const SizedBox(height: 8),
              const _WarningBanner(),
            ],
            if (data.coachMessage.isCelebration) ...[
              const SizedBox(height: 8),
              const _CelebrationBanner(),
            ],
            const SizedBox(height: 6),
            _HeroTitle(data: data),
            const SizedBox(height: 4),
            _Subtitle(data: data),
            const SizedBox(height: 6),
            _TodaysPlanSection(data: data),
          ],
        ),
      ),
    );
  }

}

// ── Header — Coach Mode badge + mission context ───────────────────────────────

class _Header extends StatelessWidget {
  final _CoachCardData data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.record_voice_over_outlined, size: 16, color: AppColors.goldSoft),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'LiftOn Coach',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
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
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
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
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            "You're in a performance window — capitalize on it",
            style: AppTextStyles.caption.copyWith(color: AppColors.gold),
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
      style: AppTextStyles.h3.copyWith(
        color: AppColors.textPrimary,
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

// ── Today's Plan section — embedded action layer ──────────────────────────────

class _TodaysPlanSection extends StatelessWidget {
  final _CoachCardData data;
  const _TodaysPlanSection({required this.data});

  Color _chevronColor(int score) {
    if (score <= 20) return const Color(0xFFEF5350);
    if (score <= 40) return AppColors.red;
    if (score <= 70) return AppColors.orange;
    if (score <= 85) return AppColors.goldAmber;
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    final String planDisplay;
    final Color  textColor;

    if (data.isCompleted) {
      planDisplay = '${data.planTitle.isNotEmpty ? data.planTitle : 'Session'}  ✓ Done';
      textColor   = AppColors.textMuted;
    } else if (data.isRestDay) {
      planDisplay = 'Rest day';
      textColor   = AppColors.textSecondary;
    } else {
      planDisplay = data.planTitle.isNotEmpty
          ? data.planTitle
          : data.topMuscleGroup.isNotEmpty
              ? '${data.topMuscleGroup[0].toUpperCase()}${data.topMuscleGroup.substring(1)} Training'
              : 'Training Session';
      textColor = AppColors.textPrimary;
    }

    final chevron = _chevronColor(data.recoveryScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 0.5, color: AppColors.borderSoft),
        const SizedBox(height: 9),

        // ── TODAY'S PLAN · Pull Day — single row ─────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.findAncestorStateOfType<MainShellState>()?.changeTab(1);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label + title inline
              Text(
                "TODAY'S PLAN  ",
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Expanded(
                child: Text(
                  planDisplay,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: chevron.withValues(alpha: 0.60)),
            ],
          ),
        ),


        // ── Small CTA — only when session pending ────────────────────
        if (!data.isRestDay && !data.isCompleted) ...[
          const SizedBox(height: 10),
          const _CtaButton(isCompleted: false),
        ],

        const SizedBox(height: 2),
      ],
    );
  }
}

// ── Warming up state (workouts 1–4) ──────────────────────────────────────────

class _WarmingUpCoachContent extends StatelessWidget {
  final _CoachCardData data;
  const _WarmingUpCoachContent({required this.data});

  int get _totalWorkouts => data.totalWorkouts;

  String get _title {
    if (_totalWorkouts == 1) return 'First workout done.';
    if (_totalWorkouts == 2) return 'Two sessions in.';
    if (_totalWorkouts <= 3) return 'Finding your rhythm.';
    return 'Almost there.';
  }

  String get _body {
    if (_totalWorkouts == 1) {
      return 'Good start. Each session builds on the last.';
    }
    if (_totalWorkouts == 2) {
      return 'Strength is building.';
    }
    if (_totalWorkouts <= 3) {
      return 'Getting to know your recovery pace. One more session.';
    }
    return 'One more session and I\'ll know your pace.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 16, color: AppColors.goldSoft),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LiftOn Coach',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.textMuted.withValues(alpha: 0.20), width: 0.5),
                  ),
                  child: Text(
                    'Adapting',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_title, style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(_body, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 8),
            // Calibration progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _totalWorkouts / 5.0,
                backgroundColor: AppColors.gold.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Session $_totalWorkouts of 5',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            // Today's plan + CTA — same as full coach card
            _TodaysPlanSection(data: data),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding state (0 workouts) ────────────────────────────────────────────

class _OnboardingCoachContent extends StatelessWidget {
  const _OnboardingCoachContent();

  @override
  Widget build(BuildContext context) {
    return Container(

      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — same pattern as all other coach states and brain card
            Row(
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 16, color: AppColors.goldSoft),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LiftOn Coach',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Coach Active',
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
            const SizedBox(height: 6),
            // Title — distinct from Brain: relational, not analytical
            Text(
              'Coach is ready.',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Train once to start building recovery insights.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero CTA button ───────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool isCompleted;
  const _CtaButton({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.findAncestorStateOfType<MainShellState>()?.changeTab(1);
      },
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, AppColors.goldSoft],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 16, color: Colors.black),
            SizedBox(width: 5),
            Text(
              "Start Today's Workout",
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

