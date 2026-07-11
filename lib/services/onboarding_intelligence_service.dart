// lib/services/onboarding_intelligence_service.dart
// Pure Dart — no Flutter imports.
// Infers athlete characteristics from observed behavior within first 7 days / 3 sessions.
//
// FOUNDATION RULE: Reuses ExperienceTier from AthleteMemoryService.
//   Does NOT re-derive calculations available from RecoveryEngine,
//   AthleteMemoryService, AdherenceIntelligenceService, or WeeklyEvolutionService.
//   Onboarding-specific behavioral signals only — derived from raw training data.
//
// SAFETY CONTRACT:
//   advisory only — no user-facing classifications surfaced directly.
//   language is calm, observational, encouraging.
//   never guilt, never shame, never fear-based messaging.
//   AdherenceProbability is internal — not displayed to the user.

import 'dart:math' as math;
import 'athlete_memory_service.dart' show ExperienceTier;
import '../models/models.dart';
import '../models/workout_log.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum ConfidenceLevel { low, moderate, high }

enum OnboardingIntimidationRisk { low, moderate, high }

/// Inferred primary motivation pattern from observed training behavior.
enum MotivationStyle {
  achievementDriven,   // PR chasing, progressive load increases
  disciplineDriven,    // consistent frequency, structured routine
  structureSeeking,    // same exercises, minimal variability
  physiqueFocused,     // isolation-heavy, machine-dominant
  recoveryFocused,     // low intensity, bodyweight emphasis
  exploratory,         // high exercise variety, custom movements
}

extension MotivationStyleLabel on MotivationStyle {
  String get label => switch (this) {
    MotivationStyle.achievementDriven => 'Achievement Driven',
    MotivationStyle.disciplineDriven  => 'Discipline Driven',
    MotivationStyle.structureSeeking  => 'Structure Seeking',
    MotivationStyle.physiqueFocused   => 'Physique Focused',
    MotivationStyle.recoveryFocused   => 'Recovery Focused',
    MotivationStyle.exploratory       => 'Exploratory',
  };
}

/// Inferred session duration and structure preference.
enum SessionPreference {
  shortEfficient,       // avg < 27 min, low variance
  longIntense,          // avg > 62 min, low variance
  moderateBalanced,     // 27–62 min, consistent
  inconsistentVariable, // high duration variance across sessions
}

extension SessionPreferenceLabel on SessionPreference {
  String get label => switch (this) {
    SessionPreference.shortEfficient       => 'Short & Efficient',
    SessionPreference.longIntense          => 'Long & Intense',
    SessionPreference.moderateBalanced     => 'Moderate & Balanced',
    SessionPreference.inconsistentVariable => 'Variable',
  };
}

enum RecoveryTolerance { low, moderate, high }

/// First-30-day retention probability. Internal only — never surfaced to user.
enum AdherenceProbability { fragile, unstable, promising, strong }

/// Recommended coaching tone for this athlete during onboarding.
enum CoachingStyle { gentle, structured, tactical, analytical }

extension CoachingStyleLabel on CoachingStyle {
  String get label => switch (this) {
    CoachingStyle.gentle     => 'Gentle',
    CoachingStyle.structured => 'Structured',
    CoachingStyle.tactical   => 'Tactical',
    CoachingStyle.analytical => 'Analytical',
  };
}

// ── Output model ──────────────────────────────────────────────────────────────

class OnboardingAthleteProfile {
  final ExperienceTier       inferredExperience;
  final ConfidenceLevel      gymConfidence;
  final OnboardingIntimidationRisk     intimidationRisk;
  final MotivationStyle      motivationStyle;
  final SessionPreference    sessionPreference;
  final RecoveryTolerance    recoveryTolerance;
  final AdherenceProbability adherenceProbability;
  final CoachingStyle        recommendedCoachStyle;

  /// Human-readable behavioral signals detected — for internal analytics only.
  final List<String> onboardingSignals;

  /// One calm, observational line shown on home during early sessions.
  final String onboardingNarrative;

  /// True after 3 sessions OR 7 days since first session.
  /// Transitions the athlete into AthleteMemorySnapshot + AdherenceProfile.
  final bool onboardingComplete;

  final DateTime computedAt;

  const OnboardingAthleteProfile({
    required this.inferredExperience,
    required this.gymConfidence,
    required this.intimidationRisk,
    required this.motivationStyle,
    required this.sessionPreference,
    required this.recoveryTolerance,
    required this.adherenceProbability,
    required this.recommendedCoachStyle,
    required this.onboardingSignals,
    required this.onboardingNarrative,
    required this.onboardingComplete,
    required this.computedAt,
  });

  static OnboardingAthleteProfile get baseline => OnboardingAthleteProfile(
    inferredExperience:    ExperienceTier.beginner,
    gymConfidence:         ConfidenceLevel.moderate,
    intimidationRisk:      OnboardingIntimidationRisk.low,
    motivationStyle:       MotivationStyle.disciplineDriven,
    sessionPreference:     SessionPreference.moderateBalanced,
    recoveryTolerance:     RecoveryTolerance.moderate,
    adherenceProbability:  AdherenceProbability.unstable,
    recommendedCoachStyle: CoachingStyle.structured,
    onboardingSignals:     const [],
    onboardingNarrative:   '',
    onboardingComplete:    false,
    computedAt:            DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class OnboardingIntelligenceService {
  OnboardingIntelligenceService._();

  /// Build an OnboardingAthleteProfile from observed training data.
  /// Designed to work with as little as 1 session — confidence scales with data.
  static OnboardingAthleteProfile compute({
    required List<WorkoutLog>   logs,
    required List<HistoryEntry> history,
    required StreakData          streak,
    required List<DayPlan>      weekPlan,
  }) {
    final now = DateTime.now();

    // ── Onboarding complete: 3+ sessions OR first session > 7 days ago ──────
    final bool complete = history.length >= 3 ||
        (history.isNotEmpty &&
         (DateTime.tryParse(history.last.date) ?? now)
             .isBefore(now.subtract(const Duration(days: 7))));

    if (logs.isEmpty && history.isEmpty) {
      return OnboardingAthleteProfile.baseline;
    }

    // ── 1. Experience ────────────────────────────────────────────────────────
    final experience = _inferExperience(logs, streak);

    // ── 2. Gym confidence ────────────────────────────────────────────────────
    final confidence = _inferConfidence(logs, history, experience);

    // ── 3. Intimidation risk ─────────────────────────────────────────────────
    final intimidation = _detectOnboardingIntimidationRisk(history, logs);

    // ── 4. Motivation style ──────────────────────────────────────────────────
    final motivation = _detectMotivationStyle(logs, streak);

    // ── 5. Session preference ────────────────────────────────────────────────
    final preference = _detectSessionPreference(history);

    // ── 6. Recovery tolerance ────────────────────────────────────────────────
    final recovery = _detectRecoveryTolerance(history);

    // ── 7. Adherence probability ─────────────────────────────────────────────
    final adherence = _detectAdherenceProbability(history, streak);

    // ── 8. Coaching style ────────────────────────────────────────────────────
    final coachStyle = _recommendCoachingStyle(
        intimidation, motivation, experience, adherence);

    // ── 9. Signals ───────────────────────────────────────────────────────────
    final signals = _collectSignals(
        logs, history, experience, motivation, preference, intimidation);

    // ── 10. Narrative ────────────────────────────────────────────────────────
    final narrative = _generateNarrative(
      experience:   experience,
      confidence:   confidence,
      intimidation: intimidation,
      motivation:   motivation,
      preference:   preference,
      adherence:    adherence,
      history:      history,
    );

    return OnboardingAthleteProfile(
      inferredExperience:    experience,
      gymConfidence:         confidence,
      intimidationRisk:      intimidation,
      motivationStyle:       motivation,
      sessionPreference:     preference,
      recoveryTolerance:     recovery,
      adherenceProbability:  adherence,
      recommendedCoachStyle: coachStyle,
      onboardingSignals:     signals,
      onboardingNarrative:   narrative,
      onboardingComplete:    complete,
      computedAt:            now,
    );
  }

  // ── Experience inference ────────────────────────────────────────────────────

  static ExperienceTier _inferExperience(
      List<WorkoutLog> logs, StreakData streak) {
    final total = streak.totalWorkouts;
    if (total == 0 && logs.isEmpty) return ExperienceTier.beginner;

    // Compound ratio is the primary early-signal for experience
    final compounds  = logs.where((l) => _isCompound(l.exercise.toLowerCase())).length;
    final compRatio  = logs.isEmpty ? 0.0 : compounds / logs.length;
    final hasCompounds = compRatio >= 0.40;
    final progressing  = _hasWeightProgression(logs);

    // Structural diversity: too few = beginner, too many = beginner overreaching
    final unique = logs.map((l) => l.exercise).toSet().length;
    final isStructured = unique >= 3 && unique <= 10;

    if (total >= 80) return ExperienceTier.advanced;
    if (total >= 20) {
      return (hasCompounds && progressing)
          ? ExperienceTier.intermediate
          : ExperienceTier.developing;
    }
    if (total >= 5) {
      if (hasCompounds && isStructured) return ExperienceTier.developing;
      return ExperienceTier.beginner;
    }
    // Very early (< 5 sessions) — rely on movement type
    if (hasCompounds && isStructured) return ExperienceTier.developing;
    return ExperienceTier.beginner;
  }

  // Keyword-based compound detection — covers primary barbell / dumbbell patterns.
  static bool _isCompound(String lower) =>
      lower.contains('squat')   || lower.contains('deadlift') ||
      lower.contains('bench')   || lower.contains('press')    ||
      lower.contains('row')     || lower.contains('pull_up')  ||
      lower.contains('pullup')  || lower.contains('chin')     ||
      lower.contains('lunge')   || lower.contains('rdl')      ||
      lower.contains('clean')   || lower.contains('snatch')   ||
      lower.contains('thruster') || lower.contains('hinge');

  static bool _hasWeightProgression(List<WorkoutLog> logs) {
    final byEx = <String, List<double>>{};
    for (final l in logs) {
      if (l.weight > 0) byEx.putIfAbsent(l.exercise, () => []).add(l.weight);
    }
    for (final weights in byEx.values) {
      if (weights.length >= 2 && weights.last > weights.first + 0.5) return true;
    }
    return false;
  }

  // ── Gym confidence ──────────────────────────────────────────────────────────

  static ConfidenceLevel _inferConfidence(
      List<WorkoutLog>   logs,
      List<HistoryEntry> history,
      ExperienceTier     exp) {
    if (exp == ExperienceTier.advanced || exp == ExperienceTier.intermediate) {
      return ConfidenceLevel.high;
    }
    final hasWeights = logs.any((l) => l.weight > 0);
    final avgEx = history.isEmpty ? 0.0
        : history.map((h) => h.exerciseCount).reduce((a, b) => a + b) /
          history.length;
    if (!hasWeights || avgEx < 2) return ConfidenceLevel.low;
    return ConfidenceLevel.moderate;
  }

  // ── Intimidation risk ───────────────────────────────────────────────────────

  static OnboardingIntimidationRisk _detectOnboardingIntimidationRisk(
      List<HistoryEntry> history, List<WorkoutLog> logs) {
    if (history.length < 2) return OnboardingIntimidationRisk.low;

    int signals = 0;

    // Exercise count shrinking — commitment decreasing
    final counts = history.take(5).map((h) => h.exerciseCount).toList();
    if (counts.length >= 3 && counts.first < counts.last * 0.60) signals++;

    // Duration collapsing (history is newest-first)
    final durations = history.take(5)
        .where((h) => h.durationMinutes > 0)
        .map((h) => h.durationMinutes.toDouble()).toList();
    if (durations.length >= 3 &&
        durations.first < durations.last * 0.55) {
      signals++;
    }

    // Consistently very short sessions (< 20 min)
    final shortCount = history.take(5)
        .where((h) => h.durationMinutes > 0 && h.durationMinutes < 20).length;
    if (shortCount >= 2) signals++;

    // Consistently low exercise count (≤ 2)
    final lowExCount = history.take(5).where((h) => h.exerciseCount <= 2).length;
    if (lowExCount >= 3) signals++;

    // No compound movements at all after several sessions
    if (logs.length >= 6 && !logs.any((l) => _isCompound(l.exercise.toLowerCase()))) {
      signals++;
    }

    if (signals >= 3) return OnboardingIntimidationRisk.high;
    if (signals >= 1) return OnboardingIntimidationRisk.moderate;
    return OnboardingIntimidationRisk.low;
  }

  // ── Motivation style ────────────────────────────────────────────────────────

  static MotivationStyle _detectMotivationStyle(
      List<WorkoutLog> logs, StreakData streak) {
    if (logs.isEmpty) return MotivationStyle.disciplineDriven;

    // Achievement: consistent weight increases per exercise
    final byEx = <String, List<WorkoutLog>>{};
    for (final l in logs) {
      if (l.weight > 0) byEx.putIfAbsent(l.exercise, () => []).add(l);
    }
    int prChaseCount = 0;
    for (final entry in byEx.entries) {
      final sorted = List<WorkoutLog>.from(entry.value)
        ..sort((a, b) => a.date.compareTo(b.date));
      if (sorted.length >= 2 && sorted.last.weight > sorted.first.weight + 2.5) {
        prChaseCount++;
      }
    }
    if (prChaseCount >= 2) return MotivationStyle.achievementDriven;

    // Exercise variety → exploratory
    final unique  = logs.map((l) => l.exercise).toSet().length;
    final variety = logs.isEmpty ? 0.0 : unique / logs.length;
    if (variety > 0.60 && logs.length >= 6) return MotivationStyle.exploratory;

    // Structure seeking: same exercises repeat across most sessions
    final byDay = <String, Set<String>>{};
    for (final l in logs) {
      final key = '${l.date.year}-${l.date.month}-${l.date.day}';
      byDay.putIfAbsent(key, () => {}).add(l.exercise);
    }
    final days = byDay.values.toList();
    if (days.length >= 3) {
      Set<String> common = Set.from(days[0]);
      for (int i = 1; i < math.min(days.length, 4); i++) {
        common = common.intersection(days[i]);
      }
      final ratio = days[0].isEmpty ? 0.0 : common.length / days[0].length;
      if (ratio >= 0.60) return MotivationStyle.structureSeeking;
    }

    // Recovery focused: bodyweight dominant
    final bwLogs = logs.where((l) => l.isBodyweight).length;
    if (logs.isNotEmpty && bwLogs / logs.length >= 0.60) {
      return MotivationStyle.recoveryFocused;
    }

    // Physique focused: isolation-heavy (non-compound dominant)
    final compounds  = logs.where((l) => _isCompound(l.exercise.toLowerCase())).length;
    final isolation  = logs.length - compounds;
    if (logs.isNotEmpty && isolation / logs.length > 0.65) {
      return MotivationStyle.physiqueFocused;
    }

    // Discipline driven: active streak or regular frequency
    if (streak.currentStreak >= 3) return MotivationStyle.disciplineDriven;

    return MotivationStyle.disciplineDriven;
  }

  // ── Session preference ──────────────────────────────────────────────────────

  static SessionPreference _detectSessionPreference(List<HistoryEntry> history) {
    final durations = history
        .where((h) => h.durationMinutes > 0)
        .map((h) => h.durationMinutes.toDouble()).toList();
    if (durations.length < 2) return SessionPreference.moderateBalanced;

    final avg = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations
        .map((d) => (d - avg) * (d - avg))
        .reduce((a, b) => a + b) / durations.length;
    final stdDev = math.sqrt(variance);

    if (stdDev > avg * 0.40) return SessionPreference.inconsistentVariable;
    if (avg <= 27) return SessionPreference.shortEfficient;
    if (avg >= 62) return SessionPreference.longIntense;
    return SessionPreference.moderateBalanced;
  }

  // ── Recovery tolerance ──────────────────────────────────────────────────────

  static RecoveryTolerance _detectRecoveryTolerance(List<HistoryEntry> history) {
    if (history.length < 4) return RecoveryTolerance.moderate;

    final vols = history.map((h) => h.totalVolume).where((v) => v > 0).toList();
    if (vols.isEmpty) return RecoveryTolerance.moderate;
    final avgVol = vols.reduce((a, b) => a + b) / vols.length;

    // history is newest-first — reverse for chronological analysis
    final chrono = history.reversed.toList();
    int hardSessions = 0, dropAfterHard = 0;

    for (int i = 0; i < chrono.length - 1; i++) {
      final cur  = chrono[i];
      final next = chrono[i + 1];
      if (cur.totalVolume > avgVol * 1.30) {
        hardSessions++;
        final volDrop = next.totalVolume > 0 &&
            next.totalVolume < cur.totalVolume * 0.65;
        final durDrop = next.durationMinutes > 0 && cur.durationMinutes > 0 &&
            next.durationMinutes < cur.durationMinutes * 0.55;
        if (volDrop || durDrop) dropAfterHard++;
      }
    }

    if (hardSessions == 0) return RecoveryTolerance.moderate;
    final dropRatio = dropAfterHard / hardSessions;
    if (dropRatio >= 0.55) return RecoveryTolerance.low;
    if (dropRatio <= 0.15) return RecoveryTolerance.high;
    return RecoveryTolerance.moderate;
  }

  // ── Adherence probability ───────────────────────────────────────────────────

  static AdherenceProbability _detectAdherenceProbability(
      List<HistoryEntry> history, StreakData streak) {
    if (history.isEmpty) return AdherenceProbability.fragile;

    final firstDate = DateTime.tryParse(history.last.date) ?? DateTime.now();
    final daysSinceFirst =
        DateTime.now().difference(firstDate).inDays.clamp(1, 365);
    final sessionsPerWeek = history.length / (daysSinceFirst / 7.0);

    int score = 0;
    if (sessionsPerWeek >= 3.5) {
      score += 3;
    } else if (sessionsPerWeek >= 2.5) score += 2;
    else if (sessionsPerWeek >= 1.5) score += 1;

    if (streak.currentStreak >= 7) {
      score += 2;
    } else if (streak.currentStreak >= 3) score += 1;

    if (history.length >= 5) score += 1;

    if (score >= 5) return AdherenceProbability.strong;
    if (score >= 3) return AdherenceProbability.promising;
    if (score >= 1) return AdherenceProbability.unstable;
    return AdherenceProbability.fragile;
  }

  // ── Coaching style ──────────────────────────────────────────────────────────

  static CoachingStyle _recommendCoachingStyle(
      OnboardingIntimidationRisk   intimidation,
      MotivationStyle    motivation,
      ExperienceTier     experience,
      AdherenceProbability adherence) {
    if (intimidation == OnboardingIntimidationRisk.high ||
        adherence == AdherenceProbability.fragile) {
      return CoachingStyle.gentle;
    }
    if (motivation == MotivationStyle.structureSeeking) {
      return CoachingStyle.structured;
    }
    if (motivation == MotivationStyle.achievementDriven &&
        experience.index >= ExperienceTier.developing.index) {
      return CoachingStyle.tactical;
    }
    if (experience.index >= ExperienceTier.intermediate.index) {
      return CoachingStyle.analytical;
    }
    return CoachingStyle.structured;
  }

  // ── Signals ─────────────────────────────────────────────────────────────────

  static List<String> _collectSignals(
    List<WorkoutLog>   logs,
    List<HistoryEntry> history,
    ExperienceTier     experience,
    MotivationStyle    motivation,
    SessionPreference  preference,
    OnboardingIntimidationRisk   intimidation,
  ) {
    final signals = <String>[];

    if (logs.isNotEmpty) {
      final compounds = logs.where((l) => _isCompound(l.exercise.toLowerCase())).length;
      final ratio = compounds / logs.length;
      if (ratio >= 0.50) {
        signals.add('Compound-focused movement selection');
      } else if (ratio < 0.20 && logs.length >= 4) {
        signals.add('Machine-dominant pattern observed');
      }
    }

    switch (motivation) {
      case MotivationStyle.exploratory:
        signals.add('High exercise variety detected');
      case MotivationStyle.structureSeeking:
        signals.add('Consistent exercise selection across sessions');
      case MotivationStyle.achievementDriven:
        signals.add('Progressive load behavior detected');
      default:
        break;
    }

    switch (preference) {
      case SessionPreference.shortEfficient:
        signals.add('Short session preference');
      case SessionPreference.longIntense:
        signals.add('Long session preference');
      case SessionPreference.inconsistentVariable:
        signals.add('Variable session structure');
      default:
        break;
    }

    if (intimidation == OnboardingIntimidationRisk.high) {
      signals.add('Simplification signals active');
    }
    if (experience == ExperienceTier.advanced) {
      signals.add('Advanced movement competency inferred');
    }
    if (_hasWeightProgression(logs)) {
      signals.add('Progressive load behavior detected');
    }

    return signals.toSet().toList(); // deduplicate
  }

  // ── Narrative ───────────────────────────────────────────────────────────────

  /// Generates one calm, observational line that the athlete sees during onboarding.
  static String _generateNarrative({
    required ExperienceTier      experience,
    required ConfidenceLevel     confidence,
    required OnboardingIntimidationRisk    intimidation,
    required MotivationStyle     motivation,
    required SessionPreference   preference,
    required AdherenceProbability adherence,
    required List<HistoryEntry>  history,
  }) {
    if (history.isEmpty) return '';

    // High intimidation — lead with reassurance
    if (intimidation == OnboardingIntimidationRisk.high) {
      return 'Short, consistent sessions are building your foundation — momentum compounds quietly over time.';
    }

    // Achievement driven — acknowledge the progression instinct
    if (motivation == MotivationStyle.achievementDriven) {
      return 'Your training shows a clear progression focus — weight selection is trending purposefully.';
    }

    // Structure seeking — acknowledge the discipline
    if (motivation == MotivationStyle.structureSeeking) {
      return 'You respond well to structured, repeatable sessions — consistency is stabilizing quickly.';
    }

    // Exploratory — validate the curiosity
    if (motivation == MotivationStyle.exploratory) {
      return 'Your training style is exploratory — you adapt well to varied movement patterns.';
    }

    // Short session preference
    if (preference == SessionPreference.shortEfficient) {
      return 'You seem most effective in focused, efficient sessions — quality over duration.';
    }

    // Strong adherence signal (rare at this stage)
    if (adherence == AdherenceProbability.strong) {
      return 'Your training rhythm is developing faster than average — early consistency is rare.';
    }

    // Experience-based fallbacks
    switch (experience) {
      case ExperienceTier.beginner:
        return 'Each session contributes more than it might feel — early training builds foundation quickly.';
      case ExperienceTier.developing:
        return 'Movement patterns are solidifying — consistency at this stage drives long-term adaptation.';
      case ExperienceTier.intermediate:
        return 'You\'re in a productive phase — keep adding weight steadily.';
      case ExperienceTier.advanced:
        return 'Your recovery management and exercise selection reflect developed training intelligence.';
    }
  }
}
