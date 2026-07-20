// lib/engines/pr_engine.dart — Production PR Engine v1.0
import '../services/exercise_intelligence.dart';
// Complete PR system: detection, delta, XP, classification, AI messages,
// consistency tracking, edge cases, null safety
// ════════════════════════════════════════════════
// DATA STRUCTURES
// ════════════════════════════════════════════════

/// Stores the best performance for a single exercise
class ExercisePR {
  final double weight;
  final int    reps;
  final String unit;
  final String date;

  const ExercisePR({
    required this.weight,
    required this.reps,
    this.unit = 'kg',
    this.date = '',
  });

  /// Display string e.g. "35.0 kg × 10"
  String get displayStr {
    if (unit == 'reps' || weight == 0) return '$reps reps';
    if (unit == 'min')  return '${weight.toInt()} min';
    return '${weight.toStringAsFixed(1)} $unit × $reps';
  }

  Map<String, dynamic> toJson() => {
    'weight': weight, 'reps': reps, 'unit': unit, 'date': date,
  };

  factory ExercisePR.fromJson(Map<String, dynamic> j) => ExercisePR(
    weight: (j['weight'] as num?)?.toDouble() ?? 0,
    reps:   (j['reps']   as int?)             ?? 0,
    unit:    j['unit']   as String?            ?? 'kg',
    date:    j['date']   as String?            ?? '',
  );

  static ExercisePR get empty =>
      const ExercisePR(weight: 0, reps: 0, unit: 'kg', date: '');
}

// ════════════════════════════════════════════════
// PR OUTCOME ENUM
// ════════════════════════════════════════════════
enum PROutcome {
  first,   // First ever log for this exercise
  pr,      // True PR — weight or reps improved
  repPR,   // Same weight, more reps (weight PR unchanged)
  match,   // Same weight + same reps
  drop,    // Performance lower than PR
}

// ════════════════════════════════════════════════
// PR RESULT
// ════════════════════════════════════════════════
class PRResult {
  final PROutcome outcome;
  final double    newWeight;
  final int       newReps;
  final double    prevWeight;
  final int       prevReps;
  final double    delta;        // currentWeight - prevBestWeight
  final double    improvePct;   // % improvement (0 if first/match/drop)
  final int       xp;
  final String    classification; // "LEGENDARY PR 🚀" / "STRONG PR 💪" / "PR 🔥" / ""
  final String    coachMessage;
  final String    deltaDisplay;   // "+5.0 kg 🔥" / "No change 🔁" / "Rep PR 🔥"

  const PRResult({
    required this.outcome,
    required this.newWeight,
    required this.newReps,
    required this.prevWeight,
    required this.prevReps,
    required this.delta,
    required this.improvePct,
    required this.xp,
    required this.classification,
    required this.coachMessage,
    required this.deltaDisplay,
  });

  bool get isPR    => outcome == PROutcome.pr    || outcome == PROutcome.first;
  bool get isRepPR => outcome == PROutcome.repPR;
  bool get isMatch => outcome == PROutcome.match;
  bool get isDrop  => outcome == PROutcome.drop;
  bool get isFirst => outcome == PROutcome.first;
  bool get isCelebrate => isPR || isRepPR; // Show celebration screen

  @override
  String toString() =>
      'PRResult($outcome, $newWeight×$newReps, delta=$delta, xp=$xp)';
}

// ════════════════════════════════════════════════
// PR ENGINE — main logic class
// ════════════════════════════════════════════════
class PREngine {

  // ── Per-exercise consecutive PR counter ───────
  final Map<String, int> _consecutivePR = {};

  // ── Per-exercise consistency counter ──────────
  final Map<String, int>        _consistencyCounter = {};
  final Map<String, double>     _consistencyWeight  = {};

  // ════════════════════════════════════════════
  // CORE: checkPR — main entry point
  // Call this BEFORE updating logs/toggleSetDone
  // ════════════════════════════════════════════
  PRResult checkPR({
    required String exerciseKey,
    required double currentWeight,
    required int    currentReps,
    required String unit,
    /// Previous best — MUST be fetched before toggle
    required double prevBestWeight,
    required int    prevBestReps,
    int sessionCount = 0,
  }) {
    final key = exerciseKey.toLowerCase().trim();

    // ── STEP 1: First ever log ───────────────────
    if (prevBestWeight == 0 && prevBestReps == 0) {
      _updateConsistency(key, currentWeight);
      const xp = 100;
      return PRResult(
        outcome:        PROutcome.first,
        newWeight:      currentWeight,
        newReps:        currentReps,
        prevWeight:     0,
        prevReps:       0,
        delta:          0,
        improvePct:     0,
        xp:             xp,
        classification: 'PR 🔥',
        coachMessage:   _firstTimeMessage(exerciseKey),
        deltaDisplay:   '🎯 First record!',
      );
    }

    // ── STEP 2: Calculate delta (currentWeight - previousBEST) ──
    final delta      = calculateDelta(
        currentWeight:      currentWeight,
        previousBestWeight: prevBestWeight);
    final improvePct = prevBestWeight > 0
        ? ((currentWeight - prevBestWeight) / prevBestWeight * 100)
            .clamp(-100.0, 999.0)
        : 0.0;

    // ── STEP 3: Classify outcome ─────────────────
    final outcome = _classifyOutcome(
      currentWeight: currentWeight, currentReps: currentReps,
      prevWeight: prevBestWeight,   prevReps: prevBestReps,
    );

    // ── STEP 4: Consistency + consecutive PR tracking ─
    _updateConsistency(key, currentWeight);
    final consistency = _consistencyCounter[key] ?? 1;

    // Fix 6: Track consecutive PRs
    if (outcome == PROutcome.pr || outcome == PROutcome.repPR) {
      _consecutivePR[key] = (_consecutivePR[key] ?? 0) + 1;
    } else {
      _consecutivePR[key] = 0;
    }
    final consecutivePRs = _consecutivePR[key] ?? 0;

    // ── STEP 5: XP ───────────────────────────────
    final xp = calculateXP(
        improvePct: improvePct, outcome: outcome);

    // ── STEP 6: Classification label ─────────────
    final classification = _classify(improvePct, outcome);

    // ── STEP 7: Coach message (Fix 4 — upgraded) ──
    final coach = getCoachMessage(
      outcome:          outcome,
      improvePct:       improvePct,
      consistencyCount: consistency,
      exerciseName:     exerciseKey,
      sessionCount:     sessionCount,
      delta:            delta,
      consecutivePRs:   consecutivePRs,
    );

    // ── STEP 8: Delta display string ──────────────
    final deltaDisplay = _buildDeltaDisplay(
        delta, improvePct, currentWeight, currentReps,
        prevBestWeight, prevBestReps, outcome, unit);

    return PRResult(
      outcome:        outcome,
      newWeight:      currentWeight,
      newReps:        currentReps,
      prevWeight:     prevBestWeight,
      prevReps:       prevBestReps,
      delta:          delta,
      improvePct:     improvePct,
      xp:             xp,
      classification: classification,
      coachMessage:   coach,
      deltaDisplay:   deltaDisplay,
    );
  }

  // ════════════════════════════════════════════
  // DELTA CALCULATION — always vs previous BEST
  // ════════════════════════════════════════════
  static double calculateDelta({
    required double currentWeight,
    required double previousBestWeight,
  }) {
    if (previousBestWeight <= 0) return 0;
    return currentWeight - previousBestWeight;
  }

  // ════════════════════════════════════════════
  // OUTCOME CLASSIFICATION
  // ════════════════════════════════════════════
  static PROutcome _classifyOutcome({
    required double currentWeight, required int currentReps,
    required double prevWeight,    required int prevReps,
  }) {
    // Fix 2: Edge case — first time (oldWeight == 0)
    if (prevWeight == 0 && prevReps == 0) return PROutcome.first;

    // Weight improved
    if (currentWeight > prevWeight + 0.01) return PROutcome.pr;

    // Same weight, more reps
    if ((currentWeight - prevWeight).abs() < 0.01 &&
        currentReps > prevReps) {
      return PROutcome.repPR;
    }

    // Exact match
    if ((currentWeight - prevWeight).abs() < 0.01 &&
        currentReps == prevReps) {
      return PROutcome.match;
    }

    // Drop
    return PROutcome.drop;
  }

  // Fix 3: increasePercent calculation — always vs oldWeight (previousBest)
  static double increasePercent({
    required double newWeight,
    required double oldWeight,
  }) {
    if (oldWeight == 0) return 0; // Edge case: first PR
    return ((newWeight - oldWeight) / oldWeight) * 100;
  }

  // ════════════════════════════════════════════
  // PR TYPE CLASSIFICATION
  // ════════════════════════════════════════════
  static String _classify(double improvePct, PROutcome outcome) {
    if (outcome == PROutcome.first)  return 'PR 🔥';
    if (outcome == PROutcome.repPR)  return 'Rep PR 🔥';
    if (outcome != PROutcome.pr)     return '';
    // Fix 2+5: updated thresholds
    if (improvePct >= 30) return 'LEGENDARY PR 🚀';
    if (improvePct >= 15) return 'STRONG PR 💪';
    return 'PR 🔥';
  }

  // Fix 2: Edge case — if oldWeight == 0, always return "PR 🔥"
  static String getPRType(double improvePct, {double oldWeight = 1}) {
    if (oldWeight == 0) return 'PR 🔥';
    if (improvePct >= 30) return 'LEGENDARY PR 🚀';
    if (improvePct >= 15) return 'STRONG PR 💪';
    return 'PR 🔥';
  }

  // ════════════════════════════════════════════
  // DYNAMIC XP SYSTEM
  // ════════════════════════════════════════════
  static int calculateXP({
    required double  improvePct,
    required PROutcome outcome,
  }) {
    switch (outcome) {
      case PROutcome.first:
        return 100;

      case PROutcome.pr:
        // Fix 5: Updated thresholds per spec
        if (improvePct >= 30) return 500; // LEGENDARY
        if (improvePct >= 15) return 300; // STRONG
        if (improvePct >= 5)  return 150; // Normal PR
        return 100;                        // Small PR

      case PROutcome.repPR:
        return 120;

      case PROutcome.match:
        return 100;

      case PROutcome.drop:
        return 50;
    }
  }

  // ════════════════════════════════════════════
  // DELTA DISPLAY STRING
  // ════════════════════════════════════════════
  static String _buildDeltaDisplay(
    double delta, double improvePct,
    double newW, int newR,
    double prevW, int prevR,
    PROutcome outcome, String unit,
  ) {
    if (outcome == PROutcome.first) return '🎯 First record!';

    // Rep PR — same weight, more reps
    if (outcome == PROutcome.repPR) {
      final repDiff = newR - prevR;
      return 'Rep PR +$repDiff reps 🔥';
    }

    // Weight delta
    if (unit != 'reps') {
      if (delta >  0.01) return '+${delta.toStringAsFixed(1)} kg 🔥';
      if (delta < -0.01) return '${delta.toStringAsFixed(1)} kg';
    }

    // Reps only
    if (unit == 'reps') {
      final repDiff = newR - prevR;
      if (repDiff > 0) return '+$repDiff reps 🔥';
      if (repDiff < 0) return '$repDiff reps';
    }

    return 'No change 🔁';
  }

  // ════════════════════════════════════════════
  // AI COACH MESSAGES
  // ════════════════════════════════════════════
  String getCoachMessage({
    required PROutcome outcome,
    required double    improvePct,
    required int       consistencyCount,
    required String    exerciseName,
    int                sessionCount    = 0,
    double             delta           = 0,
    int                consecutivePRs  = 0,
  }) {
    // Fix: Format exercise name properly
    final name = formatExerciseName(
        exerciseName.isNotEmpty ? exerciseName : 'exercise');
    final lastName = name.split(' ').last; // e.g. "Curl" from "EZ Bar Curl"

    // Streak boost — append to message
    String streakSuffix = '';
    if (consecutivePRs >= 2 &&
        (outcome == PROutcome.pr || outcome == PROutcome.repPR)) {
      streakSuffix = '\n🔥 $consecutivePRs PR streak!';
    }

    String msg;
    switch (outcome) {
      case PROutcome.first:
        msg = _firstTimeMessage(name);
      case PROutcome.pr:
        msg = _prMessage(improvePct, delta, name, lastName, sessionCount);
      case PROutcome.repPR:
        msg = _repPRMessage(name, lastName, consistencyCount);
      case PROutcome.match:
        msg = _matchMessage(name, consistencyCount);
      case PROutcome.drop:
        msg = _dropMessage(name);
    }
    return msg + streakSuffix;
  }

  // ── Format exercise name: "ez_bar_curl" → "Ez Bar Curl" ──
  static String formatExerciseName(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _firstTimeMessage(String name) =>
    'First milestone unlocked 💪\nLet\'s build something strong.';

  String _prMessage(double pct, double delta,
      String name, String lastName, int sessions) {
    // Legendary PR
    if (pct >= 30) {
      return '${pct.toStringAsFixed(0)}% jump 😳\nThis is elite level progress 🚀';
    }
    // Strong PR
    if (pct >= 15) {
      return '+${delta.toStringAsFixed(1)}kg progress 🔥\n'
          '$lastName strength improving fast 💪';
    }
    // Normal PR
    if (delta > 0) {
      return '+${delta.toStringAsFixed(1)}kg progress 🔥\n'
          'Consistency is paying off.';
    }
    // Rep improvement (delta == 0 but reps up)
    if (sessions >= 10) {
      return '$lastName strength improving fast 💪\n'
          '$sessions sessions of consistent effort.';
    }
    return '+${delta.abs().toStringAsFixed(1)}kg progress 🔥\n'
        'Consistency is paying off.';
  }

  String _repPRMessage(String name, String lastName, int consistency) =>
    '$lastName strength improving fast 💪\n'
    'Same weight, more reps — endurance growing.';

  String _matchMessage(String name, int consistency) {
    if (consistency >= 3) {
      return '🔁 $consistency sessions at this weight.\nTime to push heavier next session!';
    }
    return '💪 Consistency builds strength.\nNext session — push harder.';
  }

  String _dropMessage(String name) =>
    '📈 Recovery matters.\nCome back stronger next session.';

  // ════════════════════════════════════════════
  // CONSISTENCY TRACKING
  // ════════════════════════════════════════════
  void _updateConsistency(String key, double weight) {
    final prev = _consistencyWeight[key];
    if (prev != null && (prev - weight).abs() < 0.01) {
      // Same weight repeated
      _consistencyCounter[key] = (_consistencyCounter[key] ?? 1) + 1;
    } else {
      // New weight — reset counter
      _consistencyCounter[key]  = 1;
      _consistencyWeight[key]   = weight;
    }
  }

  int getConsistencyCount(String key) =>
      _consistencyCounter[key.toLowerCase().trim()] ?? 0;

  String consistencyMessage(String key) {
    final count = getConsistencyCount(key);
    if (count <= 1) return '';
    if (count >= 4) return '📊 $count sessions at this weight — push heavier!';
    if (count >= 2) return '🔁 $count sessions at this weight';
    return '';
  }

  // ════════════════════════════════════════════
  // PREVIOUS BEST DISPLAY
  // ════════════════════════════════════════════
  static String prevBestDisplay(
      double prevWeight, int prevReps, String unit) {
    if (prevWeight == 0 && prevReps == 0) return 'No history';
    if (unit == 'reps' || prevWeight == 0) return '$prevReps reps';
    if (unit == 'min')  return '${prevWeight.toInt()} min';
    return '${prevWeight.toStringAsFixed(1)} $unit × $prevReps';
  }

  // ════════════════════════════════════════════
  // NEXT TARGET SUGGESTION — increasePercent based
  // ════════════════════════════════════════════
  static String nextTarget(double weight, int reps, String unit,
      PROutcome outcome, {double improvePct = 0}) {
    if (unit == 'min') {
      return 'Next: ${(weight + 5).toInt()} min';
    }
    if (unit == 'reps' || weight == 0) {
      return 'Next: ${reps + 2} reps';
    }

    // AI next target logic based on improvement %
    double nextWeight;
    if (improvePct >= 30) {
      nextWeight = weight + 5.0;
    } else if (improvePct >= 15) {
      nextWeight = weight + 2.5;
    } else {
      nextWeight = weight + 1.25;
    }

    // Rep PR or match — increase reps first if < 12
    if (outcome == PROutcome.repPR || outcome == PROutcome.match) {
      if (reps < 12) return 'Next: ${reps + 1} reps';
      return 'Next: ${nextWeight.toStringAsFixed(2).replaceAll('.00', '.0')} kg';
    }

    // Drop — maintain
    if (outcome == PROutcome.drop) {
      return 'Next: ${weight.toStringAsFixed(1)} kg (hold steady)';
    }

    return 'Next: ${nextWeight.toStringAsFixed(2).replaceAll('.00', '.0')} kg';
  }
}

// ════════════════════════════════════════════════
// STATIC UTILS — use without instantiation
// ════════════════════════════════════════════════
class PRUtils {

  /// Improvement display string — handles all cases
  static String improvementStr({
    required double newWeight,
    required int    newReps,
    required double prevWeight,
    required int    prevReps,
    required String unit,
    required PROutcome outcome,
  }) {
    if (outcome == PROutcome.first)  return '🎯 First record!';
    if (outcome == PROutcome.repPR)  {
      final diff = newReps - prevReps;
      return 'Rep PR +$diff reps 🔥';
    }

    if (unit != 'reps' && prevWeight > 0) {
      final delta = newWeight - prevWeight;
      if (delta >  0.01) return '+${delta.toStringAsFixed(1)} kg 🔥';
      if (delta < -0.01) return '${delta.toStringAsFixed(1)} kg';
      final repDiff = newReps - prevReps;
      if (repDiff > 0)   return '+$repDiff reps 🔥';
    }

    if (unit == 'reps' && prevReps > 0) {
      final diff = newReps - prevReps;
      if (diff > 0) return '+$diff reps 🔥';
      if (diff < 0) return '$diff reps';
    }

    return 'No change 🔁';
  }

  /// Color for PR classification
  static int classificationColor(String classification) {
    if (classification.contains('LEGENDARY')) return 0xFFBF5FFF;
    if (classification.contains('STRONG'))    return 0xFFFF4400;
    return 0xFFFFCC00; // Normal PR — gold
  }

  /// Should show full celebration screen?
  static bool shouldCelebrate(PROutcome outcome) =>
      outcome == PROutcome.pr    ||
      outcome == PROutcome.first ||
      outcome == PROutcome.repPR;

  /// Next target — delegates to PREngine.nextTarget
  static String nextTarget(double weight, int reps, String unit,
      PROutcome outcome, {double improvePct = 0}) =>
      PREngine.nextTarget(weight, reps, unit, outcome,
          improvePct: improvePct);
}

// ════════════════════════════════════════════════
// UNIFIED WORKOUT FEEDBACK — single source of truth
// Used by: planner screen, PR celebration, workout provider
// ════════════════════════════════════════════════

class WorkoutFeedback {
  final String message;        // "🔥 Perfect range — increase slightly"
  final double nextWeight;     // Next session target weight
  final int    nextReps;       // Next session target reps
  final ProgressStatus status; // improved / same / dropped / first
  final int    xpEarned;       // XP for this set

  const WorkoutFeedback({
    required this.message,
    required this.nextWeight,
    required this.nextReps,
    required this.status,
    required this.xpEarned,
  });

  String get nextTargetDisplay {
    if (nextWeight <= 0) return '$nextReps reps';
    return '${nextWeight.toStringAsFixed(1)} kg × $nextReps reps';
  }
}

enum ProgressStatus { first, improved, same, dropped, tooHeavy, tooEasy, perfect }

/// SINGLE source of truth for all workout feedback.
/// Used by workout screen header AND PR celebration screen.
///
/// [equipment] is forwarded to WeightRounder so the suggested next weight
/// lands on a real gym increment. Pass PlannedExercise.equipment directly —
/// WeightRounder owns the fallback for empty strings (dumbbell step, 2.5 kg).
WorkoutFeedback calculateWorkoutFeedback({
  required double weight,
  required int reps,
  required double previousBestWeight,
  required int previousBestReps,
  bool isBodyweight = false,
  String unit = 'kg',
  String equipment = '',
}) {
  // Inner helper — rounds a candidate next-weight to the nearest valid gym
  // increment. Skipped for bodyweight and non-kg units.
  double snap(double w) {
    if (isBodyweight || unit != 'kg' || w <= 0) return w;
    return WeightRounder.round(w, equipment);
  }
  // ── First time ever — give SCIENTIFIC rep-based feedback ──
  if (previousBestWeight == 0 && previousBestReps == 0) {
    String msg;
    double nextW;
    int nextR;

    if (isBodyweight || unit == 'reps') {
      msg   = '🎯 Focus on form';
      nextW = 0;
      nextR = reps + 1;
    } else if (unit == 'min') {
      msg   = '⏱️ Build endurance';
      nextW = weight;
      nextR = reps;
    } else if (reps < 6) {
      msg   = '⚠ Too heavy — reduce';
      nextW = snap((weight - 2.5).clamp(0, 500));
      nextR = 8;
    } else if (reps > 12) {
      msg   = '💪 Too light — increase';
      nextW = snap((weight + 5).clamp(0, 500));
      nextR = 10;
    } else if (reps >= 8 && reps <= 12) {
      msg   = '🔥 Perfect — push slightly';
      nextW = snap((weight + 2.5).clamp(0, 500));
      nextR = reps;
    } else {
      msg   = '👍 Solid — maintain';
      nextW = snap((weight + 2.5).clamp(0, 500));
      nextR = reps + 1;
    }

    return WorkoutFeedback(
      message:    msg,
      nextWeight: nextW,
      nextReps:   nextR,
      status:     ProgressStatus.first,
      xpEarned:   100,
    );
  }

  // ── Bodyweight logic ──
  if (isBodyweight || unit == 'reps') {
    if (reps > previousBestReps) {
      return WorkoutFeedback(
        message:    '📈 Progressing well',
        nextWeight: 0,
        nextReps:   reps + 1,
        status:     ProgressStatus.improved,
        xpEarned:   75,
      );
    }
    if (reps < previousBestReps - 1) {
      return WorkoutFeedback(
        message:    '😐 Slight drop — recover',
        nextWeight: 0,
        nextReps:   previousBestReps,
        status:     ProgressStatus.dropped,
        xpEarned:   20,
      );
    }
    return WorkoutFeedback(
      message:    '💪 Solid — control reps',
      nextWeight: 0,
      nextReps:   reps + 1,
      status:     ProgressStatus.same,
      xpEarned:   30,
    );
  }

  // ── Weighted logic — RULE BASED ──

  // CASE: Too heavy
  if (reps < 6) {
    return WorkoutFeedback(
      message:    '⚠ Too heavy — reduce',
      nextWeight: snap((weight - 2.5).clamp(0, 500)),
      nextReps:   8,
      status:     ProgressStatus.tooHeavy,
      xpEarned:   15,
    );
  }

  // CASE: Too easy
  if (reps > 12) {
    return WorkoutFeedback(
      message:    '💪 Too easy — increase',
      nextWeight: snap((weight + 5).clamp(0, 500)),
      nextReps:   10,
      status:     ProgressStatus.tooEasy,
      xpEarned:   40,
    );
  }

  // CASE: Compare with previous
  final currVolume = weight * reps;
  final prevVolume = previousBestWeight * previousBestReps;

  // True PR — only if weight increased WITHOUT major rep collapse
  if (weight > previousBestWeight &&
      reps >= 6 &&
      reps >= (previousBestReps - 1)) {

    final delta = weight - previousBestWeight;

    return WorkoutFeedback(
      message:    '🔥 NEW PR — +${delta.toStringAsFixed(1)} kg',
      nextWeight: snap((weight + 2.5).clamp(0, 500)),
      nextReps:   reps,
      status:     ProgressStatus.improved,
      xpEarned:   150,
    );
  }

  // Volume improved
  if (currVolume > prevVolume * 1.05) {
    return WorkoutFeedback(
      message:    '📈 Progressing well',
      nextWeight: snap((weight + 2.5).clamp(0, 500)),
      nextReps:   reps,
      status:     ProgressStatus.improved,
      xpEarned:   75,
    );
  }

  // Volume dropped significantly
  if (currVolume < prevVolume * 0.90) {
    return WorkoutFeedback(
      message:    '😐 Slight drop — recover',
      nextWeight: snap(weight.clamp(0, 500)),
      nextReps:   previousBestReps,
      status:     ProgressStatus.dropped,
      xpEarned:   20,
    );
  }

  // Perfect range 8-12, similar to previous
  if (reps >= 8 && reps <= 12) {
    return WorkoutFeedback(
      message:    '🔥 Perfect — push slightly',
      nextWeight: snap((weight + 2.5).clamp(0, 500)),
      nextReps:   reps,
      status:     ProgressStatus.perfect,
      xpEarned:   50,
    );
  }

  // 6-8 range
  return WorkoutFeedback(
    message:    '👍 Good — maintain',
    nextWeight: snap((weight + 2.5).clamp(0, 500)),
    nextReps:   reps + 1,
    status:     ProgressStatus.same,
    xpEarned:   35,
  );
}

