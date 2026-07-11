// lib/models/memory_models.dart
//
// AI memory data classes — used by AIProvider and WorkoutProvider for
// periodization (Option B) and exercise history baselines.
//
// These were originally referenced inside the old AppProvider but never
// formally defined. Now extracted as standalone models.

class ExerciseMemory {
  final String name;
  final double bestWeight;
  final int    bestReps;
  final String unit;          // 'kg' | 'reps' | 'min'
  final double totalVolume;   // sum of weight * reps across logs

  const ExerciseMemory({
    required this.name,
    required this.bestWeight,
    required this.bestReps,
    required this.unit,
    required this.totalVolume,
  });

  Map<String, dynamic> toJson() => {
        'name':        name,
        'bestWeight':  bestWeight,
        'bestReps':    bestReps,
        'unit':        unit,
        'totalVolume': totalVolume,
      };

  factory ExerciseMemory.fromJson(Map<String, dynamic> j) => ExerciseMemory(
        name:        j['name']        as String? ?? '',
        bestWeight:  (j['bestWeight'] as num?)?.toDouble() ?? 0,
        bestReps:    j['bestReps']    as int?    ?? 0,
        unit:        j['unit']        as String? ?? 'kg',
        totalVolume: (j['totalVolume']as num?)?.toDouble() ?? 0,
      );

  @override
  String toString() =>
      'ExerciseMemory($name: $bestWeight$unit x $bestReps, vol=$totalVolume)';
}

/// One week of training summarized for periodization.
/// AIProvider feeds this into next week's plan generation prompt.
class WeeklyMemory {
  final int    weekNumber;
  final String weekStartDate;     // YYYY-MM-DD
  final String planName;          // e.g. "Push Day"
  final double totalVolume;       // total kg lifted that week
  final double avgEffortScore;    // 0–100
  final int    completedDays;
  final int    plannedDays;
  final bool   wasDeload;
  final List<ExerciseMemory> topExercises;

  const WeeklyMemory({
    required this.weekNumber,
    required this.weekStartDate,
    required this.planName,
    required this.totalVolume,
    required this.avgEffortScore,
    required this.completedDays,
    required this.plannedDays,
    required this.wasDeload,
    required this.topExercises,
  });

  /// Heuristic next-phase recommendation. AppProvider/AIProvider can use this
  /// to decide whether next week should be a deload, base build, or peak.
  String get nextPhase {
    if (wasDeload) return 'base';
    if (avgEffortScore >= 85 && completedDays >= plannedDays * 0.8) {
      return 'peak';
    }
    if (avgEffortScore < 50 || completedDays < plannedDays * 0.5) {
      return 'deload';
    }
    return 'base';
  }

  Map<String, dynamic> toJson() => {
        'weekNumber':     weekNumber,
        'weekStartDate':  weekStartDate,
        'planName':       planName,
        'totalVolume':    totalVolume,
        'avgEffortScore': avgEffortScore,
        'completedDays':  completedDays,
        'plannedDays':    plannedDays,
        'wasDeload':      wasDeload,
        'topExercises':   topExercises.map((e) => e.toJson()).toList(),
      };

  factory WeeklyMemory.fromJson(Map<String, dynamic> j) => WeeklyMemory(
        weekNumber:     j['weekNumber']     as int?    ?? 0,
        weekStartDate:  j['weekStartDate']  as String? ?? '',
        planName:       j['planName']       as String? ?? '',
        totalVolume:    (j['totalVolume']   as num?)?.toDouble() ?? 0,
        avgEffortScore: (j['avgEffortScore']as num?)?.toDouble() ?? 0,
        completedDays:  j['completedDays']  as int?    ?? 0,
        plannedDays:    j['plannedDays']    as int?    ?? 0,
        wasDeload:      j['wasDeload']      as bool?   ?? false,
        topExercises: ((j['topExercises'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => ExerciseMemory.fromJson(
                Map<String, dynamic>.from(m)))
            .toList(),
      );

  @override
  String toString() =>
      'WeeklyMemory(W$weekNumber: $completedDays/$plannedDays days, '
      'vol=${totalVolume.toStringAsFixed(0)}, '
      'effort=${avgEffortScore.toStringAsFixed(0)}, deload=$wasDeload)';
}
