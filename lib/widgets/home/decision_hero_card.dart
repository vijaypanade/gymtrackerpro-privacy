// lib/widgets/home/decision_hero_card.dart
//
// RFC-HOME-001: Decision Hero — position 1 on home screen.
// Surfaces today's decision (what + why) and the primary CTA.
// Detailed metrics (recovery score, confidence %) stay in their own cards.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../brain/models/brain_card_data.dart';
import '../../engines/recovery_engine.dart';
import '../../providers/app_provider.dart';
import '../../screens/main_shell.dart';
import '../../utils/app_constants.dart';
import 'home_workout_widgets.dart';

// ── Semantic confidence (no percentages exposed) ──────────────────────────────

enum _ConfidenceLevel { high, moderate, limited }

_ConfidenceLevel _toConfidence(int pct) {
  if (pct >= 75) return _ConfidenceLevel.high;
  if (pct >= 45) return _ConfidenceLevel.moderate;
  return _ConfidenceLevel.limited;
}

extension _ConfidenceX on _ConfidenceLevel {
  String get label {
    switch (this) {
      case _ConfidenceLevel.high:     return 'High confidence';
      case _ConfidenceLevel.moderate: return 'Moderate confidence';
      case _ConfidenceLevel.limited:  return 'Limited data';
    }
  }
}

// ── Mission title mapping ─────────────────────────────────────────────────────
// Mirrors _MissionRow._displayTitle in athlete_brain_card.dart.

String _missionTitle(MissionType t) {
  switch (t) {
    case MissionType.protectRecovery:     return 'Recover today';
    case MissionType.maintainConsistency: return 'Train normally';
    case MissionType.pushPerformance:     return 'Ready to push';
    case MissionType.comeback:            return 'Ease back in';
    case MissionType.deload:              return 'Take it lighter today';
    case MissionType.volumeReduction:     return 'A little less today';
    case MissionType.homeAdaptation:      return 'Home session today';
    case MissionType.technique:           return 'Focus on form';
    case MissionType.recoverySession:     return 'Easy movement today';
  }
}

// ── Hero state ────────────────────────────────────────────────────────────────

enum _HeroState { onboarding, standard, adaptive, completed, restDay }

// ── Data snapshot ─────────────────────────────────────────────────────────────

@immutable
class _DecisionHeroData {
  final MissionType missionType;
  final int         confidencePct;
  final int         overallScore;
  final String      planTitle;
  final int         exerciseCount;
  final bool        isCompleted;
  final bool        isRestDay;
  final int         totalWorkouts;
  final String?     adaptivePrimaryExercise;
  final int         adaptiveExerciseCount;

  const _DecisionHeroData({
    required this.missionType,
    required this.confidencePct,
    required this.overallScore,
    required this.planTitle,
    required this.exerciseCount,
    required this.isCompleted,
    required this.isRestDay,
    required this.totalWorkouts,
    required this.adaptivePrimaryExercise,
    required this.adaptiveExerciseCount,
  });

  bool get hasAdaptiveSession => adaptiveExerciseCount > 0;

  RecoveryPresentation get presentation =>
      RecoveryEngine.readinessPresentation(overallScore, missionType, isRestDay);
  _ConfidenceLevel get confidence => _toConfidence(confidencePct);

  _HeroState get heroState {
    if (totalWorkouts == 0)  return _HeroState.onboarding;
    if (isRestDay)           return _HeroState.restDay;
    if (isCompleted)         return _HeroState.completed;
    if (hasAdaptiveSession)  return _HeroState.adaptive;
    return _HeroState.standard;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _DecisionHeroData) return false;
    return other.missionType             == missionType &&
           other.confidencePct           == confidencePct &&
           other.overallScore            == overallScore &&
           other.planTitle               == planTitle &&
           other.exerciseCount           == exerciseCount &&
           other.isCompleted             == isCompleted &&
           other.isRestDay               == isRestDay &&
           other.totalWorkouts           == totalWorkouts &&
           other.adaptivePrimaryExercise == adaptivePrimaryExercise &&
           other.adaptiveExerciseCount   == adaptiveExerciseCount;
  }

  @override
  int get hashCode => Object.hash(
    missionType, confidencePct, overallScore, planTitle, exerciseCount,
    isCompleted, isRestDay, totalWorkouts,
    adaptivePrimaryExercise, adaptiveExerciseCount,
  );
}

// ── Public entry point ────────────────────────────────────────────────────────

class DecisionHeroCard extends StatelessWidget {
  const DecisionHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _DecisionHeroData>(
      selector: (_, ap) {
        final bd      = ap.brainCardData;
        final plan    = ap.todayPlan;
        final session = ap.adaptiveSession;

        String? primaryName;
        int adaptedCount = 0;
        if (session != null) {
          adaptedCount = session.exercises.length;
          if (adaptedCount > 0) {
            final firstId = session.exercises.first.exerciseId;
            final matches = plan.exercises.where((e) => e.id == firstId);
            primaryName = matches.isEmpty ? null : matches.first.name;
          }
        }

        return _DecisionHeroData(
          missionType:             bd.missionType,
          confidencePct:           bd.confidencePct,
          overallScore:            ap.getOverallRecovery(),
          planTitle:               plan.title,
          exerciseCount:           plan.exercises.length,
          isCompleted:             plan.isCompleted,
          isRestDay:               plan.isRestDay,
          totalWorkouts:           ap.totalWorkouts,
          adaptivePrimaryExercise: primaryName,
          adaptiveExerciseCount:   adaptedCount,
        );
      },
      builder: (_, data, __) => RepaintBoundary(
        child: _DecisionHeroAnimated(data: data),
      ),
    );
  }
}

// ── Entry + state-change animation ───────────────────────────────────────────
// Card mounts with a 250ms Fade + slight Slide (no bounce).
// Herostate transitions cross-fade via AnimatedSwitcher.

class _DecisionHeroAnimated extends StatefulWidget {
  final _DecisionHeroData data;
  const _DecisionHeroAnimated({required this.data});

  @override
  State<_DecisionHeroAnimated> createState() => _DecisionHeroAnimatedState();
}

class _DecisionHeroAnimatedState extends State<_DecisionHeroAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _DecisionHeroContent(
            key: ValueKey(widget.data.heroState),
            data: widget.data,
          ),
        ),
      ),
    );
  }
}

// ── Card shell ────────────────────────────────────────────────────────────────

class _DecisionHeroContent extends StatelessWidget {
  final _DecisionHeroData data;
  const _DecisionHeroContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderMedium, width: 0.5),
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    switch (data.heroState) {
      case _HeroState.onboarding:
        return _OnboardingBody(data: data);
      case _HeroState.standard:
        return _StandardBody(data: data);
      case _HeroState.adaptive:
        return _AdaptiveBody(data: data);
      case _HeroState.completed:
        return _CompletedBody(data: data);
      case _HeroState.restDay:
        return _RestDayBody(data: data);
    }
  }
}

// ── Onboarding ────────────────────────────────────────────────────────────────

class _OnboardingBody extends StatelessWidget {
  final _DecisionHeroData data;
  const _OnboardingBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your training starts here', style: AppTextStyles.h3),
        const SizedBox(height: 6),
        Text(
          'Complete your first session to activate AI coaching',
          style: AppTextStyles.bodySmall,
        ),
        if (data.exerciseCount > 0) ...[
          const SizedBox(height: 16),
          const _CtaButton(label: "Start Today's Workout"),
        ],
      ],
    );
  }
}

// ── Standard ──────────────────────────────────────────────────────────────────

class _StandardBody extends StatelessWidget {
  final _DecisionHeroData data;
  const _StandardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.presentation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SemanticChip(label: p.label, color: p.chipColor),
        const SizedBox(height: 12),
        Text(_missionTitle(data.missionType), style: AppTextStyles.h3),
        if (data.confidence != _ConfidenceLevel.high) ...[
          const SizedBox(height: 4),
          Text(data.confidence.label, style: AppTextStyles.caption),
        ],
        const SizedBox(height: 12),
        const _CtaButton(label: "Start Today's Workout"),
      ],
    );
  }
}

// ── Adaptive ──────────────────────────────────────────────────────────────────

class _AdaptiveBody extends StatelessWidget {
  final _DecisionHeroData data;
  const _AdaptiveBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final count     = data.adaptiveExerciseCount;
    final headline  = data.adaptivePrimaryExercise != null
        ? '${data.adaptivePrimaryExercise} adjusted'
        : "Today's workout adapted";
    final subline   = '$count exercise${count != 1 ? 's' : ''} updated';

    final p = data.presentation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SemanticChip(label: p.label, color: p.chipColor),
        const SizedBox(height: 12),
        Text(headline, style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text(subline, style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        const _CtaButton(label: "Start Today's Workout"),
      ],
    );
  }
}

// ── Completed ─────────────────────────────────────────────────────────────────

class _CompletedBody extends StatelessWidget {
  final _DecisionHeroData data;
  const _CompletedBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.presentation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SemanticChip(label: p.label, color: p.chipColor),
        const SizedBox(height: 12),
        Text('Session Complete', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text(data.planTitle, style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        const _CtaButton(label: 'View Summary →', secondary: true),
      ],
    );
  }
}

// ── Rest Day ──────────────────────────────────────────────────────────────────

class _RestDayBody extends StatelessWidget {
  final _DecisionHeroData data;
  const _RestDayBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.presentation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SemanticChip(label: p.label, color: p.chipColor),
        const SizedBox(height: 12),
        Text('Rest Day', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text(
          'Recovery is your training today',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

// ── Semantic chip ─────────────────────────────────────────────────────────────

class _SemanticChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _SemanticChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── CTA button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final bool   secondary;
  const _CtaButton({required this.label, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return HomeTapButton(
      onTap: () =>
          context.findAncestorStateOfType<MainShellState>()?.changeTab(1),
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          gradient: secondary
              ? null
              : const LinearGradient(
                  colors: [AppColors.goldHero, AppColors.gold],
                ),
          color: secondary ? AppColors.bgElevated : null,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: secondary
              ? Border.all(color: AppColors.borderStrong, width: 0.5)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: secondary
                ? AppTextStyles.buttonSmall
                    .copyWith(color: AppColors.textSecondary)
                : AppTextStyles.button,
          ),
        ),
      ),
    );
  }
}
