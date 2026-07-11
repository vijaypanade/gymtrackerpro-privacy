// lib/services/pr_service.dart — PRService v1.0
// Step 1: PR Detection Engine
// Step 2: Classification System
// Step 6: Addiction hooks (streak, tier colors)
// Step 7: Clean architecture
// Step 8: Null-safe, crash-free

// ════════════════════════════════════════════════
// PR RECORD — Step 1: Track previous best
// ════════════════════════════════════════════════
class PRRecord {
  final double weight;
  final int    reps;
  final double volume; // weight * reps
  final String date;
  final String unit;

  const PRRecord({
    required this.weight,
    required this.reps,
    required this.volume,
    required this.date,
    this.unit = 'kg',
  });

  factory PRRecord.from({
    required double weight,
    required int reps,
    String unit = 'kg',
    String? date,
  }) {
    final now = DateTime.now();
    return PRRecord(
      weight: weight.clamp(0, 999),
      reps:   reps.clamp(0, 999),
      volume: (weight * reps).clamp(0, 999999),
      unit:   unit,
      date:   date ?? '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}',
    );
  }

  String get displayStr {
    if (unit == 'reps' || weight == 0) return '$reps reps';
    if (unit == 'min')  return '${weight.toInt()} min';
    return '${weight.toStringAsFixed(1)} $unit × $reps';
  }

  Map<String, dynamic> toJson() => {
    'weight': weight, 'reps': reps,
    'volume': volume, 'date': date, 'unit': unit,
  };

  factory PRRecord.fromJson(Map<String, dynamic> j) => PRRecord(
    weight: (j['weight'] as num?)?.toDouble() ?? 0,
    reps:   (j['reps']   as int?)             ?? 0,
    volume: (j['volume'] as num?)?.toDouble() ?? 0,
    date:    j['date']   as String?           ?? '',
    unit:    j['unit']   as String?           ?? 'kg',
  );

  static PRRecord get empty =>
      const PRRecord(weight: 0, reps: 0, volume: 0, date: '', unit: 'kg');
}

// ════════════════════════════════════════════════
// PR TIER — Step 2: Classification
// ════════════════════════════════════════════════
enum PRTier { normal, strong, legendary }

extension PRTierX on PRTier {
  String get label {
    switch (this) {
      case PRTier.legendary: return 'LEGENDARY PR 🚀';
      case PRTier.strong:    return 'STRONG PR 💪';
      case PRTier.normal:    return 'PR 🔥';
    }
  }

  // Step 6: Special UI color per tier
  int get colorHex {
    switch (this) {
      case PRTier.legendary: return 0xFFBF5FFF; // purple
      case PRTier.strong:    return 0xFFFF4400; // orange-red
      case PRTier.normal:    return 0xFFFFCC00; // gold
    }
  }

  // Step 6: Confetti only for strong+
  bool get showConfetti => this != PRTier.normal;

  // Step 6: "YOU ARE UNSTOPPABLE" only for legendary
  bool get showUnstoppable => this == PRTier.legendary;
}

// ════════════════════════════════════════════════
// PR OUTCOME
// ════════════════════════════════════════════════
enum PROutcome { first, pr, repPR, volumePR, match, drop }

// ════════════════════════════════════════════════
// PR DETECTION RESULT
// ════════════════════════════════════════════════
class PRDetection {
  final PROutcome outcome;
  final PRTier    tier;
  final double    deltaWeight;   // currentWeight - prevWeight
  final double    deltaVolume;   // current vol - prev vol
  final double    improvePct;    // ((current - prev) / prev) * 100
  final PRRecord  current;
  final PRRecord  previous;
  final int       prStreak;      // consecutive PR sessions

  const PRDetection({
    required this.outcome,
    required this.tier,
    required this.deltaWeight,
    required this.deltaVolume,
    required this.improvePct,
    required this.current,
    required this.previous,
    required this.prStreak,
  });

  bool get isPR        => outcome == PROutcome.pr    ||
                          outcome == PROutcome.first  ||
                          outcome == PROutcome.repPR  ||
                          outcome == PROutcome.volumePR;
  bool get isFirst     => outcome == PROutcome.first;
  bool get isMatch     => outcome == PROutcome.match;
  bool get isDrop      => outcome == PROutcome.drop;
  bool get isCelebrate => isPR;

  @override
  String toString() =>
    'PRDetection($outcome, tier=${tier.name}, +${deltaWeight}kg, ${improvePct.toStringAsFixed(1)}%)';
}

// ════════════════════════════════════════════════
// PR SERVICE — Step 1+2+6+7+8
// ════════════════════════════════════════════════
class PRService {

  // Step 1: Map<exerciseKey, PRRecord> — previous best per exercise
  final Map<String, PRRecord> _bestRecord  = {};
  // Step 6: PR streak per exercise
  final Map<String, int>      _prStreak    = {};
  // Consistency: how many times same weight repeated
  final Map<String, int>      _consistency = {};
  final Map<String, double>   _lastWeight  = {};

  // ── MAIN ENTRY: detect PR ──────────────────────
  /// Call BEFORE updating logs/toggleSetDone
  PRDetection detect({
    required String exerciseKey,
    required double weight,
    required int    reps,
    required String unit,
  }) {
    final key  = _normalize(exerciseKey);
    final prev = _bestRecord[key];
    final currVol = weight * reps;

    // ── Step 8: Handle first-time exercise safely ──
    if (prev == null || (prev.weight == 0 && prev.reps == 0)) {
      final current = PRRecord.from(weight: weight, reps: reps, unit: unit);
      _bestRecord[key] = current;
      _prStreak[key]   = 1;
      _updateConsistency(key, weight);
      return PRDetection(
        outcome:     PROutcome.first,
        tier:        PRTier.normal,
        deltaWeight: 0,
        deltaVolume: currVol,
        improvePct:  0,
        current:     current,
        previous:    PRRecord.empty,
        prStreak:    1,
      );
    }

    // ── Step 1+3: Delta calculation — always vs BEST ──
    final deltaWeight = weight - prev.weight;
    final deltaVolume = currVol - prev.volume;
    final prevBase = prev.weight > 0 ? prev.weight : prev.reps.toDouble();
    final currBase = weight      > 0 ? weight      : reps.toDouble();

    // Step 2: % increase — base for classification
    final improvePct = prevBase > 0
        ? ((currBase - prevBase) / prevBase * 100).clamp(-999.0, 999.0)
        : 0.0;

    // ── Classify outcome ───────────────────────────
    final outcome = _classifyOutcome(
      weight: weight, reps: reps,
      prevWeight: prev.weight, prevReps: prev.reps,
      currVol: currVol, prevVol: prev.volume,
    );

    // ── Update streak ──────────────────────────────
    if (outcome == PROutcome.pr    ||
        outcome == PROutcome.repPR ||
        outcome == PROutcome.volumePR) {
      _prStreak[key] = (_prStreak[key] ?? 0) + 1;
    } else {
      _prStreak[key] = 0;
    }
    final streak = _prStreak[key] ?? 0;
    _updateConsistency(key, weight);

    // ── Update best record ─────────────────────────
    final current = PRRecord.from(weight: weight, reps: reps, unit: unit);
    if (outcome == PROutcome.pr    ||
        outcome == PROutcome.repPR ||
        outcome == PROutcome.volumePR) {
      _bestRecord[key] = current;
    }

    // ── Step 2: Tier classification ────────────────
    final tier = _classifyTier(improvePct, outcome);

    return PRDetection(
      outcome:     outcome,
      tier:        tier,
      deltaWeight: deltaWeight,
      deltaVolume: deltaVolume,
      improvePct:  improvePct,
      current:     current,
      previous:    prev,
      prStreak:    streak,
    );
  }

  // ── Seed best record from external logs ─────────
  /// Call this on init with existing PR data from AppProvider
  void seedBest(String key, double weight, int reps, String unit) {
    final k = _normalize(key);
    final existing = _bestRecord[k];
    if (existing == null ||
        weight > existing.weight ||
        (weight >= existing.weight && reps > existing.reps)) {
      _bestRecord[k] = PRRecord.from(
          weight: weight, reps: reps, unit: unit);
    }
  }

  PRRecord? getBest(String key) => _bestRecord[_normalize(key)];
  int getStreak(String key)     => _prStreak[_normalize(key)] ?? 0;
  int getConsistency(String key) => _consistency[_normalize(key)] ?? 0;

  // ── Outcome classification ─────────────────────
  static PROutcome _classifyOutcome({
    required double weight, required int reps,
    required double prevWeight, required int prevReps,
    required double currVol, required double prevVol,
  }) {
    // Weight PR
    if (weight > prevWeight + 0.01) return PROutcome.pr;
    // Rep PR (same weight, more reps)
    if ((weight - prevWeight).abs() < 0.01 && reps > prevReps) {
      return PROutcome.repPR;
    }
    // Volume PR (overall volume improvement even if weight same)
    if (currVol > prevVol + 0.5 &&
        weight >= prevWeight * 0.95) {
      return PROutcome.volumePR;
    }
    // Match
    if ((weight - prevWeight).abs() < 0.01 && reps == prevReps) {
      return PROutcome.match;
    }
    // Drop
    return PROutcome.drop;
  }

  // ── Tier from improvement % ────────────────────
  static PRTier _classifyTier(double pct, PROutcome outcome) {
    if (outcome == PROutcome.first  ||
        outcome == PROutcome.match  ||
        outcome == PROutcome.drop) {
      return PRTier.normal;
    }
    if (pct >= 30) return PRTier.legendary;
    if (pct >= 10) return PRTier.strong;
    return PRTier.normal;
  }

  void _updateConsistency(String key, double weight) {
    final prev = _lastWeight[key];
    if (prev != null && (prev - weight).abs() < 0.01) {
      _consistency[key] = (_consistency[key] ?? 1) + 1;
    } else {
      _consistency[key] = 1;
      _lastWeight[key]  = weight;
    }
  }

  String _normalize(String key) => key.toLowerCase().trim();
}
