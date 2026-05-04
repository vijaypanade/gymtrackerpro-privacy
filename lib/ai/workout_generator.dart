class WorkoutInput {
  final String goal;        // fat_loss / muscle_gain / strength
  final String experience;  // beginner / intermediate / advanced

  WorkoutInput({
    required this.goal,
    required this.experience,
  });
}

class WorkoutGenerator {
  static Map<String, List<String>> generate(WorkoutInput input) {
    Map<String, List<String>> plan = {};

    // 🔥 PUSH DAY
    plan["Monday"] = _pushWorkout(input);

    // 🔥 PULL DAY
    plan["Tuesday"] = _pullWorkout(input);

    // 🔥 LEGS DAY
    plan["Wednesday"] = _legsWorkout(input);

    // 🔥 REST / LIGHT
    plan["Thursday"] = ["Rest / Cardio"];

    // 🔥 REPEAT VARIATION
    plan["Friday"] = _pushWorkout(input);
    plan["Saturday"] = _pullWorkout(input);
    plan["Sunday"] = ["Rest"];

    return plan;
  }

  // =========================
  // 🔥 WORKOUT LOGIC
  // =========================

  static List<String> _pushWorkout(WorkoutInput input) {
    if (input.experience == "beginner") {
      return [
        "Push Ups",
        "Incline Push Ups",
        "Shoulder Press",
        "Triceps Dips",
      ];
    }

    if (input.goal == "muscle_gain") {
      return [
        "Bench Press",
        "Incline Dumbbell Press",
        "Overhead Press",
        "Cable Fly",
        "Triceps Pushdown",
      ];
    }

    return [
      "Push Ups",
      "Bench Press",
      "Shoulder Press",
    ];
  }

  static List<String> _pullWorkout(WorkoutInput input) {
    if (input.experience == "beginner") {
      return [
        "Inverted Row",
        "Lat Pulldown",
        "Biceps Curl",
      ];
    }

    if (input.goal == "muscle_gain") {
      return [
        "Deadlift",
        "Barbell Row",
        "Lat Pulldown",
        "Hammer Curl",
      ];
    }

    return [
      "Pull Ups",
      "Barbell Row",
      "Biceps Curl",
    ];
  }

  static List<String> _legsWorkout(WorkoutInput input) {
    if (input.experience == "beginner") {
      return [
        "Bodyweight Squats",
        "Lunges",
        "Calf Raises",
      ];
    }

    if (input.goal == "fat_loss") {
      return [
        "Squats",
        "Jump Squats",
        "Lunges",
        "Leg Press",
        "Calf Raises",
      ];
    }

    return [
      "Squats",
      "Leg Press",
      "Romanian Deadlift",
      "Calf Raises",
    ];
  }
}