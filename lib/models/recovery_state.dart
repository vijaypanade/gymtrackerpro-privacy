// lib/models/recovery_state.dart
// Immutable contract for the recovery intelligence system.
// Pure Dart — no Flutter, no Provider, no business logic.
// RecoveryEngine populates this; UI and AppProvider consume it.

enum RecoveryReadiness {
  depleted,  // 0–20  — do not train primary movers
  low,       // 20–40 — reduced volume / active recovery only
  moderate,  // 40–65 — normal session with adjusted intensity
  ready,     // 65–85 — full session, standard load
  peak,      // 85–100 — push window: max effort appropriate
}

extension RecoveryReadinessX on RecoveryReadiness {
  String get label {
    switch (this) {
      case RecoveryReadiness.depleted: return 'Depleted';
      case RecoveryReadiness.low:      return 'Low Recovery';
      case RecoveryReadiness.moderate: return 'Moderate Readiness';
      case RecoveryReadiness.ready:    return 'Ready to Push';
      case RecoveryReadiness.peak:     return 'Peak Recovery';
    }
  }

  static RecoveryReadiness fromScore(double score) {
    final s = score.clamp(0.0, 100.0);
    if (s < 20) return RecoveryReadiness.depleted;
    if (s < 40) return RecoveryReadiness.low;
    if (s < 65) return RecoveryReadiness.moderate;
    if (s < 85) return RecoveryReadiness.ready;
    return RecoveryReadiness.peak;
  }
}

class RecoveryState {
  final double overallScore;           // 0–100, clamped
  final Map<String, double> muscleScores; // muscle key → 0–100, clamped

  final RecoveryReadiness readiness;
  final String primaryLimitingMuscle; // '' if none suppressed

  final double strainToday;  // 0–100 training load score for today
  final double strain7d;     // 0–100 rolling 7-day accumulated strain

  final bool needsDeload;
  final bool highFatigue;

  final DateTime updatedAt;

  const RecoveryState({
    required this.overallScore,
    required this.muscleScores,
    required this.readiness,
    required this.primaryLimitingMuscle,
    required this.strainToday,
    required this.strain7d,
    required this.needsDeload,
    required this.highFatigue,
    required this.updatedAt,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  String get readinessLabel => readiness.label;

  bool get isReadyToPush =>
      readiness == RecoveryReadiness.ready ||
      readiness == RecoveryReadiness.peak;

  bool get isRecoverySuppressed =>
      readiness == RecoveryReadiness.depleted ||
      readiness == RecoveryReadiness.low;

  // ── Empty / default state ─────────────────────────────────────────────────

  factory RecoveryState.empty() => RecoveryState(
        overallScore:          75.0,
        muscleScores:          const {},
        readiness:             RecoveryReadiness.moderate,
        primaryLimitingMuscle: '',
        strainToday:           0.0,
        strain7d:              0.0,
        needsDeload:           false,
        highFatigue:           false,
        updatedAt:             DateTime.fromMillisecondsSinceEpoch(0),
      );

  // ── copyWith ──────────────────────────────────────────────────────────────

  RecoveryState copyWith({
    double?               overallScore,
    Map<String, double>?  muscleScores,
    RecoveryReadiness?    readiness,
    String?               primaryLimitingMuscle,
    double?               strainToday,
    double?               strain7d,
    bool?                 needsDeload,
    bool?                 highFatigue,
    DateTime?             updatedAt,
  }) =>
      RecoveryState(
        overallScore:          overallScore          ?? this.overallScore,
        muscleScores:          muscleScores          ?? this.muscleScores,
        readiness:             readiness             ?? this.readiness,
        primaryLimitingMuscle: primaryLimitingMuscle ?? this.primaryLimitingMuscle,
        strainToday:           strainToday           ?? this.strainToday,
        strain7d:              strain7d              ?? this.strain7d,
        needsDeload:           needsDeload           ?? this.needsDeload,
        highFatigue:           highFatigue           ?? this.highFatigue,
        updatedAt:             updatedAt             ?? this.updatedAt,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'overallScore':          overallScore,
        'muscleScores':          muscleScores,
        'readiness':             readiness.name,
        'primaryLimitingMuscle': primaryLimitingMuscle,
        'strainToday':           strainToday,
        'strain7d':              strain7d,
        'needsDeload':           needsDeload,
        'highFatigue':           highFatigue,
        'updatedAt':             updatedAt.toIso8601String(),
      };

  factory RecoveryState.fromJson(Map<String, dynamic> j) {
    final rawMuscle = j['muscleScores'];
    final muscleScores = <String, double>{};
    if (rawMuscle is Map) {
      rawMuscle.forEach((k, v) {
        if (k is String && v is num) {
          muscleScores[k] = v.toDouble().clamp(0.0, 100.0);
        }
      });
    }

    final rawScore = (j['overallScore'] as num?)?.toDouble() ?? 75.0;
    final overallScore = rawScore.clamp(0.0, 100.0);

    final readiness = RecoveryReadiness.values.firstWhere(
      (r) => r.name == (j['readiness'] as String? ?? ''),
      orElse: () => RecoveryReadinessX.fromScore(overallScore),
    );

    return RecoveryState(
      overallScore:          overallScore,
      muscleScores:          muscleScores,
      readiness:             readiness,
      primaryLimitingMuscle: j['primaryLimitingMuscle'] as String? ?? '',
      strainToday:           ((j['strainToday']  as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0),
      strain7d:              ((j['strain7d']      as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0),
      needsDeload:           j['needsDeload']  as bool? ?? false,
      highFatigue:           j['highFatigue']  as bool? ?? false,
      updatedAt:             DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
                             DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
