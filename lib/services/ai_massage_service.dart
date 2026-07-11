// lib/services/ai_message_service.dart — AIMessageService v1.0
// Step 4: Dynamic coach messages
// Step 5: Smart next target logic
// Step 7: Clean architecture
import 'dart:math';
import 'pr_service.dart';

// ════════════════════════════════════════════════
// AI MESSAGE RESULT
// ════════════════════════════════════════════════
class AIMessage {
  final String headline;      // "YOU ARE UNSTOPPABLE"
  final String coachLine;     // "+10kg progress 🔥 Consistency is paying off."
  final String nextTarget;    // "Next: 17.5 kg"
  final bool   showStreak;    // show streak tag?
  final int    prStreak;

  const AIMessage({
    required this.headline,
    required this.coachLine,
    required this.nextTarget,
    required this.showStreak,
    required this.prStreak,
  });

  // Full message with streak appended if relevant
  String get fullCoachMessage {
    if (showStreak && prStreak >= 2) {
      return '$coachLine\n$prStreak records in a row.';
    }
    return coachLine;
  }
}

// ════════════════════════════════════════════════
// AI MESSAGE SERVICE — Step 4+5+7
// ════════════════════════════════════════════════
class AIMessageService {

  static final Random _rng = Random();

  /// Generate full AI message from a PRDetection
  static AIMessage generate({
    required String    exerciseName,
    required PRDetection detection,
    int sessionCount = 0,
  }) {
    final formatted = formatExerciseName(exerciseName);
    final lastName  = formatted.split(' ').last; // "Curl" from "EZ Bar Curl"
    final pct       = detection.improvePct;
    final delta     = detection.deltaWeight;
    final streak    = detection.prStreak;

    return AIMessage(
      headline:   _headline(detection.tier, detection.outcome),
      coachLine:  _coachLine(
          detection.outcome, pct, delta, formatted, lastName, sessionCount),
      nextTarget: _nextTarget(
          detection.current.weight, detection.current.reps,
          detection.current.unit,   pct, detection.outcome),
      showStreak: streak >= 2,
      prStreak:   streak,
    );
  }

  // ── Step 6: Headline — "UNSTOPPABLE" only for legendary ──
  static String _headline(PRTier tier, PROutcome outcome) {
    if (outcome == PROutcome.first) return 'FIRST MILESTONE';
    switch (tier) {
      case PRTier.legendary:
        return _pick(['YOU ARE UNSTOPPABLE',
            'ELITE LEVEL REACHED', 'LEGENDARY LIFT']);
      case PRTier.strong:
        return _pick(['YOU ARE GETTING STRONGER',
            'THIS IS HOW WARRIORS ARE BUILT', 'STRONG PROGRESS']);
      case PRTier.normal:
        return _pick(['YOU JUST LEVELED UP',
            'PERSONAL RECORD', 'KEEP PUSHING']);
    }
  }

  // ── Step 4: Coach line ─────────────────────────
  static String _coachLine(
    PROutcome outcome, double pct, double delta,
    String name, String lastName, int sessions,
  ) {
    switch (outcome) {
      case PROutcome.first:
        return 'First lift on record.\nEverything builds from here.';

      case PROutcome.pr:
      case PROutcome.volumePR:
        // Legendary
        if (pct >= 30) {
          return 'A big jump.\nWell earned.';
        }
        // Strong
        if (pct >= 15) {
          return '+${delta.toStringAsFixed(1)}kg.\n$lastName is moving fast.';
        }
        // Normal — with delta
        if (delta > 0.01) {
          return '+${delta.toStringAsFixed(1)}kg.\nConsistency is paying off.';
        }
        return '$lastName strength improving.\nKeep showing up.';

      case PROutcome.repPR:
        return '$lastName endurance growing.\n'
            'Same weight, more reps. Progress.';

      case PROutcome.match:
        return 'Matched your best.\n'
            'Go heavier next session.';

      case PROutcome.drop:
        return 'Recovery matters 📈\nCome back stronger next session.';
    }
  }

  // ── Step 5: Smart next target ─────────────────
  static String _nextTarget(
    double weight, int reps, String unit,
    double pct, PROutcome outcome,
  ) {
    if (unit == 'min') {
      return 'Next: ${(weight + 5).toInt()} min';
    }
    if (unit == 'reps' || weight == 0) {
      return 'Next: ${reps + 2} reps';
    }

    // Drop or match — hold or small increase
    if (outcome == PROutcome.drop) {
      return 'Next: ${weight.toStringAsFixed(1)} kg (hold steady)';
    }
    if (outcome == PROutcome.match || outcome == PROutcome.repPR) {
      if (reps < 12) return 'Next: ${reps + 1} reps';
    }

    // Step 5: increasePercent-based next target
    double nextWeight;
    if (pct >= 30) {
      nextWeight = weight + 5.0;       // legendary — big jump
    } else if (pct >= 15) {
      nextWeight = weight + 2.5;       // strong — medium jump
    } else {
      nextWeight = weight + 1.25;      // normal — small progressive
    }

    // Clean display: avoid ".00" → show 1 decimal
    final nextStr = nextWeight == nextWeight.roundToDouble()
        ? '${nextWeight.toStringAsFixed(1)} kg'
        : '${nextWeight.toStringAsFixed(2)} kg';

    return 'Next: $nextStr';
  }

  // ── Format exercise name: "ez_bar_curl" → "Ez Bar Curl" ──
  static String formatExerciseName(String raw) {
    if (raw.isEmpty) return 'Exercise';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  static String _pick(List<String> opts) {
    if (opts.isEmpty) return '';
    return opts[_rng.nextInt(opts.length)];
  }
}
