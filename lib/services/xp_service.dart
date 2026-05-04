// lib/services/xp_service.dart — XPService v1.0
// Step 3: Dynamic XP Engine + streak multiplier
// Step 7: Clean architecture
import 'pr_service.dart';

// ════════════════════════════════════════════════
// XP RESULT
// ════════════════════════════════════════════════
class XPResult {
  final int    baseXP;
  final int    finalXP;       // after streak multiplier
  final double multiplier;    // e.g. 1.2 for 2-streak
  final String label;         // "+150 XP 🔥" display

  const XPResult({
    required this.baseXP,
    required this.finalXP,
    required this.multiplier,
    required this.label,
  });
}

// ════════════════════════════════════════════════
// XP SERVICE — Step 3+7
// ════════════════════════════════════════════════
class XPService {

  /// Calculate XP from a PRDetection result
  static XPResult calculate(PRDetection detection) {
    final base = _baseXP(detection.improvePct, detection.outcome);

    // Step 3: Streak multiplier — xp *= (1 + prStreak * 0.1)
    final streak     = detection.prStreak.clamp(0, 10);
    final multiplier = 1.0 + (streak * 0.1);
    final finalXP    = (base * multiplier).round();

    return XPResult(
      baseXP:     base,
      finalXP:    finalXP,
      multiplier: multiplier,
      label:      _label(finalXP, detection.tier, streak),
    );
  }

  // Step 3: XP tiers based on improve %
  static int _baseXP(double pct, PROutcome outcome) {
    switch (outcome) {
      case PROutcome.first:
        return 100;
      case PROutcome.pr:
      case PROutcome.volumePR:
        if (pct >= 30) return 500;
        if (pct >= 15) return 250;
        return 100;
      case PROutcome.repPR:
        return 120;
      case PROutcome.match:
        return 80;
      case PROutcome.drop:
        return 30;
    }
  }

  static String _label(int xp, PRTier tier, int streak) {
    final streakTag = streak >= 2 ? ' 🔥×$streak' : '';
    switch (tier) {
      case PRTier.legendary:
        return '+$xp XP$streakTag 🚀';
      case PRTier.strong:
        return '+$xp XP$streakTag 💪';
      case PRTier.normal:
        return '+$xp XP$streakTag';
    }
  }
}
