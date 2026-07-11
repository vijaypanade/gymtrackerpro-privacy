// lib/coach/services/coach_brain_service.dart
//
// CoachBrainService V1 — deterministic rule-based coaching engine.
//
// Architecture:
//   Rules are evaluated highest-priority-first. The first rule whose
//   condition fires returns the BrainCoachMessage. No rule can see another
//   rule's output; this is a flat priority cascade, not a chain.
//
// Priority bands:
//   P5 — Critical safety  (deload required)
//   P4 — High urgency     (fatigue warning | peak performance window)
//   P3 — Momentum signals (comeback | high-confidence push | rest session)
//   P2 — Mission-aligned  (focus-specific coaching | low confidence)
//   P1 — Identity         (default, always fires)
//
// Constraints (enforced, not assumed):
//   - Pure deterministic. No randomness, no state.
//   - No AI, no Provider, no Firebase, no UI.
//   - AthleteMemory signals are advisory only — they never override safety.
//   - Recovery always wins over performance framing.

import '../../services/adaptive_programming_service.dart';
import '../models/coach_context.dart';
import '../models/coach_intent.dart';
import '../models/coach_message.dart';
import '../models/coach_mode.dart';

class CoachBrainService {
  const CoachBrainService();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generates a single, deterministic BrainCoachMessage from [context].
  ///
  /// Rules fire in descending priority order. The first matching rule wins.
  /// Rule P1 (identity reinforcement) always matches, so this method
  /// never returns null.
  BrainCoachMessage generate(CoachBrainContext context) {
    return _deloadRequired(context)        ??
           _highFatigueWarning(context)    ??
           _peakWindow(context)            ??
           _comeback(context)              ??
           _highConfidenceOverload(context) ??
           _restSession(context)           ??
           _missionAligned(context)        ??
           _lowConfidence(context)         ??
           _identityReinforcement(context);
  }

  // ── P5 — Critical safety ─────────────────────────────────────────────────

  /// P5: Fires when a deload is medically advised by recovery tracking.
  /// Highest priority — safety always wins.
  BrainCoachMessage? _deloadRequired(CoachBrainContext ctx) {
    final r = ctx.recoveryState;
    if (!r.needsDeload) return null;

    return const BrainCoachMessage(
      title:         'Rest Today. Grow Tomorrow.',
      subtitle:      'Your muscles repair and grow during rest — not during training. '
                     'Pushing through today will slow your results and increase injury risk.',
      primaryAction: 'Take a rest day',
      tone:          CoachMode.protect,
      intent:        CoachIntent.suggestRecovery,
      priority:      5,
      hasWarning:    true,
      isCelebration: false,
    );
  }

  // ── P4 — High urgency ─────────────────────────────────────────────────────

  /// P4: Fires when fatigue is high and readiness is critically low.
  BrainCoachMessage? _highFatigueWarning(CoachBrainContext ctx) {
    final r = ctx.recoveryState;
    if (!(r.highFatigue && r.isRecoverySuppressed)) return null;

    return const BrainCoachMessage(
      title:         'Your Body Hasn\'t Fully Recovered',
      subtitle:      'Going heavy on tired muscles increases injury risk and slows progress. '
                     'Keep today light — movement without max effort.',
      primaryAction: 'Train at lower intensity',
      tone:          CoachMode.protect,
      intent:        CoachIntent.warnOvertraining,
      priority:      4,
      hasWarning:    true,
      isCelebration: false,
    );
  }

  /// P4: Fires when recovery is peak AND memory shows strong progression momentum.
  /// The athlete is in a genuine performance window — celebrate and capitalize.
  BrainCoachMessage? _peakWindow(CoachBrainContext ctx) {
    final r   = ctx.recoveryState;
    final mem = ctx.athleteMemorySnapshot;

    if (!(r.isReadyToPush && mem.progressionVelocity > 0.70)) return null;

    return const BrainCoachMessage(
      title:         'Your Best Day to Train',
      subtitle:      'Recovery is high and your training is consistent. '
                     'You\'ll get more muscle stimulus from today\'s session than any other day this week.',
      primaryAction: 'Make it count',
      tone:          CoachMode.celebrate,
      intent:        CoachIntent.celebratePR,
      priority:      4,
      hasWarning:    false,
      isCelebration: true,
    );
  }

  // ── P3 — Momentum signals ─────────────────────────────────────────────────

  /// P3: Fires when long-term memory shows very low consistency and adherence —
  /// the athlete is returning after a meaningful absence.
  BrainCoachMessage? _comeback(CoachBrainContext ctx) {
    final mem = ctx.athleteMemorySnapshot;
    final isComeback = ctx.adaptiveDecision.focus == AdaptiveTrainingFocus.comebackSession ||
        (mem.consistencyScore < 0.20 && mem.adherenceScore < 0.20);

    if (!isComeback) return null;

    return const BrainCoachMessage(
      title:         'Good to Have You Back.',
      subtitle:      'After a break, your body adapts quickly — you\'ll regain strength '
                     'faster than you think. Start lighter today and build back up.',
      primaryAction: 'Start easy, build back',
      tone:          CoachMode.nudge,
      intent:        CoachIntent.triggerComeback,
      priority:      3,
      hasWarning:    false,
      isCelebration: false,
    );
  }

  /// P3: Fires when decision confidence is high and the focus is overload —
  /// all signals align for a meaningful training stimulus.
  BrainCoachMessage? _highConfidenceOverload(CoachBrainContext ctx) {
    final isOverload = ctx.adaptiveDecision.focus == AdaptiveTrainingFocus.overload ||
                       ctx.adaptiveDecision.focus == AdaptiveTrainingFocus.hypertrophyPush ||
                       ctx.adaptiveDecision.focus == AdaptiveTrainingFocus.strengthPush;
    final isHighConfidence = ctx.decisionConfidence.overallConfidence >= 0.72;

    if (!(isOverload && isHighConfidence)) return null;

    return const BrainCoachMessage(
      title:         'Ready to Lift More.',
      subtitle:      'Your recovery is solid and you\'ve been consistent. '
                     'Today is the right day to add a little more weight than last time.',
      primaryAction: 'Push a bit harder today',
      tone:          CoachMode.motivate,
      intent:        CoachIntent.encourageConsistency,
      priority:      3,
      hasWarning:    false,
      isCelebration: true,
    );
  }

  /// P3: Fires when the adaptive focus explicitly calls for rest or recovery.
  BrainCoachMessage? _restSession(CoachBrainContext ctx) {
    final focus = ctx.adaptiveDecision.focus;
    if (focus != AdaptiveTrainingFocus.recovery &&
        focus != AdaptiveTrainingFocus.deload) {
      return null;
    }

    final isDeload = focus == AdaptiveTrainingFocus.deload;
    return BrainCoachMessage(
      title:         isDeload ? 'Train Light This Week.' : 'Light Movement Day.',
      subtitle:      isDeload
          ? 'Lifting at 60% of your usual weight this week lets your joints and '
            'nervous system fully recover. You\'ll come back noticeably stronger.'
          : 'Light movement — a walk, stretch, or easy session — helps muscles '
            'repair faster than complete rest. No heavy lifting today.',
      primaryAction: isDeload ? 'Reduce weights today' : 'Keep it light',
      tone:          CoachMode.guide,
      intent:        CoachIntent.suggestRecovery,
      priority:      3,
      hasWarning:    false,
      isCelebration: false,
    );
  }

  // ── P2 — Mission-aligned ──────────────────────────────────────────────────

  /// P2: Maps the adaptive training focus to a specific coaching message.
  /// Fires for all focus values not already handled by higher-priority rules.
  BrainCoachMessage? _missionAligned(CoachBrainContext ctx) {
    switch (ctx.adaptiveDecision.focus) {
      case AdaptiveTrainingFocus.maintain:
        return const BrainCoachMessage(
          title:         'Show Up. It Counts.',
          subtitle:      'Muscle is built over weeks, not single sessions. '
                         'Showing up consistently — even on low-energy days — is what drives results.',
          primaryAction: 'Complete today\'s session',
          tone:          CoachMode.nudge,
          intent:        CoachIntent.encourageConsistency,
          priority:      2,
          hasWarning:    false,
          isCelebration: false,
        );

      case AdaptiveTrainingFocus.technicalSession:
        return const BrainCoachMessage(
          title:         'Perfect the Form Today.',
          subtitle:      'Muscles respond to controlled, correct movement — not just heavy weight. '
                         'Slow each rep down. 2 seconds up, 3 seconds down.',
          primaryAction: 'Focus on form',
          tone:          CoachMode.educate,
          intent:        CoachIntent.redirectFocus,
          priority:      2,
          hasWarning:    false,
          isCelebration: false,
        );

      // overload, hypertrophyPush, strengthPush, comebackSession, recovery, deload
      // are handled by P3–P5 rules; null here routes them to P1.
      default:
        return null;
    }
  }

  /// P2: Fires when decision confidence is low — the system has limited data.
  BrainCoachMessage? _lowConfidence(CoachBrainContext ctx) {
    if (ctx.decisionConfidence.overallConfidence >= 0.50) return null;

    return const BrainCoachMessage(
      title:         'Building Your Profile.',
      subtitle:      'A few more workouts and your coach will give you specific, '
                     'personalized guidance based on how your body actually responds.',
      primaryAction: 'Keep logging sessions',
      tone:          CoachMode.educate,
      intent:        CoachIntent.redirectFocus,
      priority:      2,
      hasWarning:    false,
      isCelebration: false,
    );
  }

  // ── P1 — Identity reinforcement (always fires) ────────────────────────────

  /// Default rule — always matches. Derives coaching from the athlete's
  /// long-term memory identity signals.
  BrainCoachMessage _identityReinforcement(CoachBrainContext ctx) {
    final mem = ctx.athleteMemorySnapshot;
    return _identityMessage(
      identityStage:    mem.identityStage,
      experienceLevel:  mem.experienceLevel,
      consistencyScore: mem.consistencyScore,
      reliabilityScore: mem.reliabilityScore,
    );
  }

  // ── Identity message builder ──────────────────────────────────────────────

  /// Selects a coaching message that resonates with the athlete's identity
  /// stage and experience level.
  ///
  /// Identity-based rules (evaluated in order):
  ///   1. Elite + high reliability     → acknowledge mastery
  ///   2. Disciplined / elite          → reinforce discipline
  ///   3. Consistent + good reliability → reinforce habit
  ///   4. Developing                   → encourage growth
  ///   5. Beginner / default           → welcome + foundation
  static BrainCoachMessage _identityMessage({
    required String identityStage,
    required String experienceLevel,
    required double consistencyScore,
    required double reliabilityScore,
  }) {
    final stage = identityStage.toLowerCase();
    final exp   = experienceLevel.toLowerCase();

    // Elite athlete with demonstrated reliability
    if ((stage == 'elite' || stage == 'disciplined') && reliabilityScore >= 0.65) {
      return const BrainCoachMessage(
        title:         'You\'re One of the Consistent Ones.',
        subtitle:      'Most people stop training within 3 months. '
                       'You\'ve built a habit that produces real, lasting results.',
        primaryAction: 'Keep the standard',
        tone:          CoachMode.celebrate,
        intent:        CoachIntent.reinforceIdentity,
        priority:      1,
        hasWarning:    false,
        isCelebration: true,
      );
    }

    // Disciplined or elite athlete still building reliability
    if (stage == 'elite' || stage == 'disciplined') {
      return const BrainCoachMessage(
        title:         'Discipline Is the Skill.',
        subtitle:      'You\'ve trained consistently when motivation was low. '
                       'That\'s what separates athletes who actually progress.',
        primaryAction: 'Show up',
        tone:          CoachMode.motivate,
        intent:        CoachIntent.reinforceIdentity,
        priority:      1,
        hasWarning:    false,
        isCelebration: false,
      );
    }

    // Consistent athlete with decent adherence
    if (stage == 'consistent' && consistencyScore >= 0.40) {
      return const BrainCoachMessage(
        title:         'The Habit Is Sticking.',
        subtitle:      'Regular training is now rewiring your body — more muscle, '
                       'stronger joints, better metabolism. Keep going.',
        primaryAction: 'Keep the rhythm',
        tone:          CoachMode.nudge,
        intent:        CoachIntent.encourageConsistency,
        priority:      1,
        hasWarning:    false,
        isCelebration: false,
      );
    }

    // Developing athlete (8–25 workouts)
    if (stage == 'developing' || exp == 'intermediate') {
      return const BrainCoachMessage(
        title:         'The First 3 Months Matter Most.',
        subtitle:      'Your body is in its fastest adaptation phase right now. '
                       'Every session builds muscle memory and strength that sticks for years.',
        primaryAction: 'Add another session',
        tone:          CoachMode.motivate,
        intent:        CoachIntent.acknowledgeMilestone,
        priority:      1,
        hasWarning:    false,
        isCelebration: false,
      );
    }

    // Beginner / novice / unknown — default welcome message
    return const BrainCoachMessage(
      title:         'Beginners Gain the Fastest.',
      subtitle:      'Science shows new lifters build muscle and strength faster than anyone else. '
                     'Right now, every workout produces visible results within weeks.',
      primaryAction: 'Start today\'s session',
      tone:          CoachMode.guide,
      intent:        CoachIntent.reinforceIdentity,
      priority:      1,
      hasWarning:    false,
      isCelebration: false,
    );
  }
}
