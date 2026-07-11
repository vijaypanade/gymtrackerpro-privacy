// lib/brain/models/workout_context.dart
//
// Immutable container for workout-specific values needed by AthleteBrain.
// This object is intentionally small and compositional. It does not contain
// business logic or derived policy fields.

class WorkoutContext {
  final int daysSinceLastWorkout;
  final int totalWorkouts;
  final String goal;
  final List<String> todayExerciseNames;
  final List<String> todayExerciseCategories;

  const WorkoutContext({
    required this.daysSinceLastWorkout,
    required this.totalWorkouts,
    required this.goal,
    required this.todayExerciseNames,
    required this.todayExerciseCategories,
  });
}
