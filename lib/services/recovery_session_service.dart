// lib/services/recovery_session_service.dart — Phase C2 Auto Recovery Session
// Pure Dart — no Flutter, no Provider, no UI logic.
// Analyzes recovery state and generates an intelligently adapted session suggestion.
// The athlete should feel: supported, not controlled.

import '../models/recovery_state.dart';

// ── Axial-loading exercises (avoid when back/legs depleted) ──────────────────
const _kAxialLoading = [
  'Barbell Deadlift',
  'Romanian Deadlift',
  'Barbell Back Squat',
  'Front Squat',
  'Barbell Row',
  'T-Bar Row',
  'Good Morning',
  'Barbell Overhead Press',
];

// ── Per-muscle: what to avoid and what to suggest instead ────────────────────
const _kAvoid = <String, List<String>>{
  'back': [
    'Barbell Deadlift', 'Romanian Deadlift', 'Barbell Row',
    'T-Bar Row', 'Good Morning',
  ],
  'legs': [
    'Barbell Back Squat', 'Front Squat', 'Leg Press',
    'Romanian Deadlift', 'Bulgarian Split Squat',
  ],
  'chest': [
    'Barbell Bench Press', 'Decline Barbell Press', 'Incline Barbell Press',
  ],
  'shoulders': ['Barbell Overhead Press', 'Behind-the-Neck Press'],
  'biceps':   [],
  'triceps':  [],
  'core':     [],
  'calves':   [],
};

const _kAlternatives = <String, List<String>>{
  'back': [
    'Cable Row', 'Chest-Supported Row', 'Lat Pulldown',
    'Machine Row', 'Face Pull',
  ],
  'legs': [
    'Goblet Squat', 'Leg Extension', 'Leg Curl',
    'Walking Lunges', 'Leg Abductor Machine',
  ],
  'chest': [
    'Cable Fly', 'Pec Deck', 'Dumbbell Fly',
    'Incline Dumbbell Press', 'Push-up',
  ],
  'shoulders': [
    'Lateral Raise', 'Cable Lateral Raise',
    'Machine Shoulder Press', 'Face Pull', 'Rear Delt Fly',
  ],
  'biceps':  ['Cable Curl', 'Incline Dumbbell Curl', 'Hammer Curl'],
  'triceps': ['Cable Pushdown', 'Overhead Tricep Extension', 'Tricep Kickback'],
  'core':    ['Plank', 'Dead Bug', 'Cable Crunch'],
  'calves':  ['Seated Calf Raise', 'Single-Leg Calf Raise'],
};

// ════════════════════════════════════════════════
// RESULT MODEL
// ════════════════════════════════════════════════

class RecoverySessionSuggestion {
  final bool   shouldSuggestAlternative;

  final String title;
  final String message;

  final double recommendedIntensity;  // 0.0–1.0 multiplier of normal load
  final double recommendedVolume;     // 0.0–1.0 multiplier of normal sets

  final bool   reduceAxialLoading;
  final bool   simplifyWorkout;

  final List<String> replacementExercises;
  final List<String> avoidedExercises;

  final String recoveryFocus;

  final DateTime computedAt;

  const RecoverySessionSuggestion({
    required this.shouldSuggestAlternative,
    required this.title,
    required this.message,
    required this.recommendedIntensity,
    required this.recommendedVolume,
    required this.reduceAxialLoading,
    required this.simplifyWorkout,
    required this.replacementExercises,
    required this.avoidedExercises,
    required this.recoveryFocus,
    required this.computedAt,
  });

  factory RecoverySessionSuggestion.none() => RecoverySessionSuggestion(
    shouldSuggestAlternative: false,
    title:                    '',
    message:                  '',
    recommendedIntensity:     1.0,
    recommendedVolume:        1.0,
    reduceAxialLoading:       false,
    simplifyWorkout:          false,
    replacementExercises:     const [],
    avoidedExercises:         const [],
    recoveryFocus:            '',
    computedAt:               DateTime.fromMillisecondsSinceEpoch(0),
  );

  String get intensityLabel => '${(recommendedIntensity * 100).round()}%';
  String get volumeLabel    => '${(recommendedVolume    * 100).round()}%';

  bool get hasSwaps => replacementExercises.isNotEmpty;
}

// ════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════

class RecoverySessionService {
  RecoverySessionService._();

  /// Compute a session suggestion from the current recovery state.
  /// Returns [RecoverySessionSuggestion.none()] when no adaptation is needed.
  static RecoverySessionSuggestion compute({
    required RecoveryState recoveryState,
    required int           daysSinceLastWorkout,
    required int           adherenceBurnoutLevel,    // 0–3; 2+ = elevated
    required int           predictiveCollapseLevel,  // 0–3; 2+ = elevated
    List<String>           todayExerciseCategories = const [],
  }) {
    final rs            = recoveryState;
    final limiting      = rs.primaryLimitingMuscle.toLowerCase();
    final limitingScore = rs.muscleScores[limiting] ?? 100.0;
    final isComeback    = daysSinceLastWorkout >= 4;
    final isHighBurnout = adherenceBurnoutLevel >= 2;

    // Muscles actually targeted today (used to skip irrelevant protection cards)
    final todayMuscles  = _normaliseMuscles(todayExerciseCategories);

    final shouldSuggest =
        rs.isRecoverySuppressed               ||  // readiness depleted or low
        rs.needsDeload                        ||  // sustained volume spike
        rs.highFatigue                        ||  // 2+ major muscles < 40%
        (limiting.isNotEmpty && limitingScore < 45) ||
        isComeback                            ||  // 4+ days off
        isHighBurnout                         ||  // burnout signals elevated
        predictiveCollapseLevel >= 2;             // system predicts collapse

    if (!shouldSuggest) return RecoverySessionSuggestion.none();

    // Priority order: deload > comeback > high fatigue > muscle protection >
    //                 burnout buffer > general light
    if (rs.needsDeload)                        return _deload(limiting);
    if (isComeback)                            return _comeback(daysSinceLastWorkout);
    if (rs.highFatigue || rs.overallScore < 40) return _highFatigue(limiting);
    if (limiting.isNotEmpty && limitingScore < 45) {
      // Only show the muscle-protection card when today's workout
      // actually targets the fatigued muscle. If today is Chest/Triceps
      // and legs are limiting, the card is irrelevant — suppress it.
      if (todayMuscles.isNotEmpty && !todayMuscles.contains(limiting)) {
        return RecoverySessionSuggestion.none();
      }
      return _muscleProtection(limiting, limitingScore);
    }
    if (isHighBurnout || predictiveCollapseLevel >= 2) return _burnoutBuffer();
    return _lightGeneral();
  }

  // Maps raw exercise category strings to canonical muscle-group keys
  // matching the _kAvoid / _kAlternatives tables.
  static Set<String> _normaliseMuscles(List<String> categories) {
    const aliases = <String, String>{
      'chest':      'chest', 'push':        'chest', 'pecs':       'chest',
      'back':       'back',  'pull':        'back',  'lats':       'back',
      'legs':       'legs',  'quads':       'legs',  'hamstrings': 'legs',
      'glutes':     'legs',  'lower':       'legs',
      'shoulders':  'shoulders', 'delts':   'shoulders',
      'biceps':     'biceps',   'arms':     'biceps',
      'triceps':    'triceps',
      'core':       'core',     'abs':      'core',
      'calves':     'calves',
    };
    final result = <String>{};
    for (final cat in categories) {
      final lower = cat.toLowerCase().trim();
      if (aliases.containsKey(lower)) {
        result.add(aliases[lower]!);
      } else {
        for (final entry in aliases.entries) {
          if (lower.contains(entry.key)) {
            result.add(entry.value);
            break;
          }
        }
      }
    }
    return result;
  }

  // ── Scenario builders ─────────────────────────────────────────────────────

  static RecoverySessionSuggestion _deload(String limiting) {
    final avoided      = _kAvoid[limiting]        ?? const <String>[];
    final replacements = _kAlternatives[limiting] ?? const <String>[];
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Light Training Day',
      message:                 'Movement quality takes priority over output today. '
                               'A controlled session now supports a stronger week ahead.',
      recommendedIntensity:    0.65,
      recommendedVolume:       0.60,
      reduceAxialLoading:      true,
      simplifyWorkout:         true,
      replacementExercises:    replacements,
      avoidedExercises:        {..._kAxialLoading, ...avoided}.toList(),
      recoveryFocus:           'Deload — full recovery rebound',
      computedAt:              DateTime.now(),
    );
  }

  static RecoverySessionSuggestion _comeback(int daysSince) {
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Welcome Back Session',
      message:                 'Today\'s session has been adjusted to rebuild training '
                               'rhythm. Controlled movement now builds the momentum '
                               'for your best weeks ahead.',
      recommendedIntensity:    0.75,
      recommendedVolume:       0.65,
      reduceAxialLoading:      false,
      simplifyWorkout:         true,
      replacementExercises:    const [],
      avoidedExercises:        const [],
      recoveryFocus:           'Confidence rebuilding — short, successful session',
      computedAt:              DateTime.now(),
    );
  }

  static RecoverySessionSuggestion _highFatigue(String limiting) {
    final isAxial      = limiting == 'back' || limiting == 'legs';
    final avoided      = _kAvoid[limiting]        ?? const <String>[];
    final replacements = _kAlternatives[limiting] ?? const <String>[];
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Controlled Intensity Session',
      message:                 'Fatigue is elevated across your main muscle groups. '
                               'Reduced loading will support faster recovery rebound.',
      recommendedIntensity:    0.75,
      recommendedVolume:       0.70,
      reduceAxialLoading:      isAxial,
      simplifyWorkout:         false,
      replacementExercises:    replacements,
      avoidedExercises:        avoided,
      recoveryFocus:           'Fatigue management — quality over volume',
      computedAt:              DateTime.now(),
    );
  }

  static RecoverySessionSuggestion _muscleProtection(
      String muscle, double score) {
    final isAxial      = muscle == 'back' || muscle == 'legs';
    final avoided      = _kAvoid[muscle]        ?? const <String>[];
    final replacements = _kAlternatives[muscle] ?? const <String>[];
    final name         = _cap(muscle);
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Recovery Session',
      message:                 'Today\'s session has been adjusted to preserve '
                               '$name recovery quality. '
                               'Movement quality takes priority over output today.',
      recommendedIntensity:    0.80,
      recommendedVolume:       0.75,
      reduceAxialLoading:      isAxial,
      simplifyWorkout:         false,
      replacementExercises:    replacements,
      avoidedExercises:        avoided,
      recoveryFocus:           '$name protection — exercise swaps active',
      computedAt:              DateTime.now(),
    );
  }

  static RecoverySessionSuggestion _burnoutBuffer() {
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Simplified Session',
      message:                 'A focused, shorter session today preserves training '
                               'rhythm while protecting your momentum for the week ahead.',
      recommendedIntensity:    0.80,
      recommendedVolume:       0.70,
      reduceAxialLoading:      false,
      simplifyWorkout:         true,
      replacementExercises:    const [],
      avoidedExercises:        const [],
      recoveryFocus:           'Momentum protection — sustainable rhythm',
      computedAt:              DateTime.now(),
    );
  }

  static RecoverySessionSuggestion _lightGeneral() {
    return RecoverySessionSuggestion(
      shouldSuggestAlternative: true,
      title:                   'Recovery Session',
      message:                 'Today\'s session has been adjusted to support recovery '
                               'quality. Reduced loading today accelerates readiness '
                               'for your next full session.',
      recommendedIntensity:    0.80,
      recommendedVolume:       0.75,
      reduceAxialLoading:      false,
      simplifyWorkout:         false,
      replacementExercises:    const [],
      avoidedExercises:        const [],
      recoveryFocus:           'General recovery management',
      computedAt:              DateTime.now(),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
