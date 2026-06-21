// lib/services/split_recommendation_engine.dart
// Pure logic — no Flutter dependencies.
// Maps (level, gymDays, goal) → recommended SplitStyle + explanation.

import '../models/split_template.dart';

// ─────────────────────────────────────────────────────────────────────────────
class SplitRecommendation {
  final SplitStyle split;
  final String headline;
  final String body;
  final List<String> bullets;
  // true = user's implied preference was overridden (e.g. beginner asking for 6 days)
  final bool nudgedDown;

  const SplitRecommendation({
    required this.split,
    required this.headline,
    required this.body,
    required this.bullets,
    this.nudgedDown = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class SplitRecommendationEngine {
  SplitRecommendationEngine._();

  static SplitRecommendation recommend({
    required String level,   // 'Beginner' / 'Intermediate' / 'Advanced'
    required int gymDays,    // 2–6
    required String goal,    // 'Build Muscle' / 'Lose Fat' / 'Get Stronger' / etc.
  }) {
    final lvl = level.toLowerCase();
    final g   = goal.toLowerCase();

    final isBeginner     = lvl.contains('beginner');
    final isAdvanced     = lvl.contains('advanced');
    final isFatLoss      = g.contains('fat')  || g.contains('lose') || g.contains('cut') || g.contains('weight');
    final isStrength     = g.contains('strength') || g.contains('strong') || g.contains('power');
    final days           = gymDays.clamp(2, 6);

    // ── Fat loss: calorie burn > isolation ────────────────────────────────
    if (isFatLoss) {
      if (days <= 3) {
        return const SplitRecommendation(
          split: SplitStyle.fullBody,
          headline: 'Full Body Training',
          body: 'For fat loss, full body sessions burn the most calories and keep your metabolism elevated.',
          bullets: [
            'Maximum caloric expenditure per session',
            'Compound movements boost fat burning',
            'Maintains muscle while in deficit',
            'Every session works your whole body',
          ],
        );
      }
      return const SplitRecommendation(
        split: SplitStyle.upperLower,
        headline: 'Upper / Lower Split',
        body: 'Upper/Lower gives you higher frequency and calorie burn — optimal for fat loss with 4+ days.',
        bullets: [
          'Higher weekly training volume',
          'Each muscle hit twice per week',
          'Great for sustainable fat loss',
          'Compound-first structure burns more',
        ],
      );
    }

    // ── Strength: frequency beats isolation ───────────────────────────────
    if (isStrength) {
      if (days <= 4) {
        return const SplitRecommendation(
          split: SplitStyle.fullBody,
          headline: 'Full Body (Strength Focus)',
          body: 'Strength is a skill. More practice per pattern = faster gains. Squat, hinge, and press every session.',
          bullets: [
            'Squat / hinge / press every session',
            'Neural adaptation is the #1 driver',
            'Low fatigue accumulation',
            'Optimal for 1RM progress',
          ],
        );
      }
      return const SplitRecommendation(
        split: SplitStyle.pushPullLegs,
        headline: 'Push Pull Legs',
        body: 'PPL keeps sufficient frequency for the big lifts while adding volume for muscle support.',
        bullets: [
          'Compounds remain the priority',
          'High enough frequency for strength',
          'Accessory work builds weak points',
          'Progressive overload is simple to track',
        ],
      );
    }

    // ── Beginner: protect recovery, avoid bro split ───────────────────────
    if (isBeginner) {
      if (days <= 3) {
        return const SplitRecommendation(
          split: SplitStyle.fullBody,
          headline: 'Full Body Training',
          body: 'As a beginner, full body training will deliver the fastest results. Your nervous system adapts before your muscles.',
          bullets: [
            'Each muscle trained 3× per week',
            'Proven for beginner strength and size gains',
            'Lower injury risk with movement variety',
            'Builds the movement patterns that matter',
          ],
        );
      }
      if (days <= 5) {
        return SplitRecommendation(
          split: SplitStyle.upperLower,
          headline: 'Upper / Lower Split',
          body: 'Upper/Lower is the ideal step up as your training frequency grows. Each muscle group twice a week.',
          bullets: const [
            '2× weekly frequency per muscle group',
            'Simple and science-backed structure',
            'Good recovery built in between sessions',
            'Easy to add volume as you progress',
          ],
          nudgedDown: days == 5,
        );
      }
      // 6 days beginner — nudge to PPL, not Bro Split
      return SplitRecommendation(
        split: SplitStyle.pushPullLegs,
        headline: 'Push Pull Legs',
        body: 'For 6 training days at your level, PPL gives the right frequency without taxing your recovery like a bro split would.',
        bullets: const [
          'Better recovery than a bro split',
          'Each muscle trained twice weekly',
          'Simpler load progression to track',
          'Lower overtraining risk at this stage',
        ],
        nudgedDown: true,
      );
    }

    // ── Intermediate ──────────────────────────────────────────────────────
    if (!isAdvanced) {
      if (days <= 3) {
        return const SplitRecommendation(
          split: SplitStyle.pushPullLegs,
          headline: 'Push Pull Legs',
          body: 'The most proven structure for intermediate lifters. High volume per session, each pattern trained once a week.',
          bullets: [
            'High per-session volume for growth',
            'Focused muscle stimulation per day',
            'Classic intermediate hypertrophy structure',
            'Flexible exercise selection',
          ],
        );
      }
      if (days == 4) {
        return const SplitRecommendation(
          split: SplitStyle.upperLower,
          headline: 'Upper / Lower Split',
          body: 'At 4 days, Upper/Lower delivers twice-weekly frequency per muscle — the evidence-based driver for intermediate hypertrophy.',
          bullets: [
            '2× weekly frequency per muscle group',
            'High-frequency stimulus with manageable session length',
            'Volume distributed evenly across training days',
            'Proven structure for intermediate muscle development',
          ],
        );
      }
      // 5–6 days intermediate
      return const SplitRecommendation(
        split: SplitStyle.pushPullLegs,
        headline: 'Push Pull Legs (×2)',
        body: 'Full PPL run twice a week. Each muscle trained twice — the evidence-based approach for intermediate hypertrophy.',
        bullets: [
          '2× weekly frequency per muscle',
          'High weekly training volume',
          'Manageable session length',
          'Ideal stimulus for muscle growth',
        ],
      );
    }

    // ── Advanced ──────────────────────────────────────────────────────────
    if (days <= 3) {
      return const SplitRecommendation(
        split: SplitStyle.upperLower,
        headline: 'Upper / Lower Split',
        body: 'At 2–3 days, Upper/Lower ensures every muscle receives twice-weekly stimulation — critical for advanced recovery management.',
        bullets: [
          '2× weekly frequency per muscle group',
          'Compound-priority structure for advanced lifters',
          'Recovery-aware session distribution',
          'Evidence-based frequency for experienced athletes',
        ],
      );
    }
    if (days == 4) {
      return const SplitRecommendation(
        split: SplitStyle.upperLower,
        headline: 'Upper / Lower Split',
        body: 'Four days of Upper/Lower gives advanced athletes 2× weekly frequency with volume-managed sessions and full recovery between patterns.',
        bullets: [
          '2× weekly frequency per muscle group',
          'High volume with controlled session fatigue',
          'Structured recovery between upper and lower days',
          'Evidence-based frequency for advanced hypertrophy',
        ],
      );
    }
    // Advanced 5 days → Upper/Lower (2–3× frequency); 6 days → PPL ×2 (maximum volume + frequency).
    // Bro Split removed: 1×/week frequency is suboptimal vs 2×/week for hypertrophy (Schoenfeld 2016).
    if (days == 5) {
      return const SplitRecommendation(
        split: SplitStyle.upperLower,
        headline: 'Upper / Lower Split',
        body: 'At 5 training days, Upper/Lower gives each muscle 2–3× weekly frequency — the proven driver for advanced hypertrophy.',
        bullets: [
          '2–3× weekly frequency per muscle group',
          'High volume with manageable session length',
          'Proven structure for advanced muscle development',
          'Room for intensity techniques within each session',
        ],
      );
    }
    return const SplitRecommendation(
      split: SplitStyle.pushPullLegs,
      headline: 'Push Pull Legs (×2)',
      body: 'Full PPL twice a week. High weekly volume with 2× frequency — the proven advanced hypertrophy standard.',
      bullets: [
        '2× weekly frequency per muscle',
        'High weekly training volume',
        'Manageable session length',
        'Ideal stimulus for experienced muscle growth',
      ],
    );
  }
}
