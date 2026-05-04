// lib/data/exercise_data.dart — v2.0 Complete Exercise Database
// REPLACE entire file.

class ExerciseData {
  static List<Map<String, dynamic>> list = [

    // ═══════════════════════════════════════
    // CHEST — 12 exercises
    // ═══════════════════════════════════════
    {
      "name": "Barbell Bench Press",
      "type": "push", "muscle": "Chest",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 60.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Incline Barbell Press",
      "type": "push", "muscle": "Chest",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 50.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Decline Barbell Press",
      "type": "push", "muscle": "Chest",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 55.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Dumbbell Bench Press",
      "type": "push", "muscle": "Chest",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 24.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Incline Dumbbell Press",
      "type": "push", "muscle": "Chest",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Decline Dumbbell Press",
      "type": "push", "muscle": "Chest",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 22.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Dumbbell Chest Fly",
      "type": "push", "muscle": "Chest",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 14.0, "defaultReps": 12,
      "emoji": "🕊️",
    },
    {
      "name": "Incline Dumbbell Fly",
      "type": "push", "muscle": "Chest",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 12.0, "defaultReps": 12,
      "emoji": "🕊️",
    },
    {
      "name": "Chest Fly Machine",
      "type": "push", "muscle": "Chest",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 30.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Machine Chest Press",
      "type": "push", "muscle": "Chest",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Cable Crossover",
      "type": "push", "muscle": "Chest",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 15.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Push-ups",
      "type": "push", "muscle": "Chest",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "🔥",
    },

    // ═══════════════════════════════════════
    // BACK — 12 exercises
    // ═══════════════════════════════════════
    {
      "name": "Barbell Deadlift",
      "type": "pull", "muscle": "Back",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 80.0, "defaultReps": 5,
      "emoji": "🏋️",
    },
    {
      "name": "Barbell Row",
      "type": "pull", "muscle": "Back",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 50.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "T-Bar Row",
      "type": "pull", "muscle": "Back",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 10,
      "emoji": "🏋️",
    },
    {
      "name": "Dumbbell Row",
      "type": "pull", "muscle": "Back",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 24.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Lat Pulldown",
      "type": "pull", "muscle": "Back",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 45.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Wide Grip Lat Pulldown",
      "type": "pull", "muscle": "Back",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Close Grip Lat Pulldown",
      "type": "pull", "muscle": "Back",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 42.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Seated Cable Row",
      "type": "pull", "muscle": "Back",
      "equipment": "cable", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 12,
      "emoji": "⚡",
    },
    {
      "name": "Cable Straight Arm Pulldown",
      "type": "pull", "muscle": "Back",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Pull-ups",
      "type": "pull", "muscle": "Back",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 8,
      "emoji": "🔥",
    },
    {
      "name": "Chin-ups",
      "type": "pull", "muscle": "Back",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 8,
      "emoji": "🔥",
    },
    {
      "name": "Machine Row",
      "type": "pull", "muscle": "Back",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 45.0, "defaultReps": 12,
      "emoji": "🤖",
    },

    // ═══════════════════════════════════════
    // SHOULDERS — 10 exercises
    // ═══════════════════════════════════════
    {
      "name": "Barbell Overhead Press",
      "type": "push", "muscle": "Shoulders",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Dumbbell Shoulder Press",
      "type": "push", "muscle": "Shoulders",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 16.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Arnold Press",
      "type": "push", "muscle": "Shoulders",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 14.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Lateral Raise",
      "type": "push", "muscle": "Shoulders",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 8.0, "defaultReps": 15,
      "emoji": "💪",
    },
    {
      "name": "Cable Lateral Raise",
      "type": "push", "muscle": "Shoulders",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 6.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Front Raise",
      "type": "push", "muscle": "Shoulders",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 8.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Rear Delt Fly",
      "type": "pull", "muscle": "Shoulders",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 8.0, "defaultReps": 15,
      "emoji": "🕊️",
    },
    {
      "name": "Face Pulls",
      "type": "pull", "muscle": "Shoulders",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 15.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Machine Shoulder Press",
      "type": "push", "muscle": "Shoulders",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 30.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Upright Row",
      "type": "pull", "muscle": "Shoulders",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 30.0, "defaultReps": 12,
      "emoji": "🏋️",
    },

    // ═══════════════════════════════════════
    // LEGS — 14 exercises
    // ═══════════════════════════════════════
    {
      "name": "Barbell Back Squat",
      "type": "legs", "muscle": "Legs",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 70.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Front Squat",
      "type": "legs", "muscle": "Legs",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 50.0, "defaultReps": 8,
      "emoji": "🏋️",
    },
    {
      "name": "Goblet Squat",
      "type": "legs", "muscle": "Legs",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Leg Press",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 100.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Romanian Deadlift",
      "type": "legs", "muscle": "Legs",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 60.0, "defaultReps": 10,
      "emoji": "🏋️",
    },
    {
      "name": "Dumbbell Romanian Deadlift",
      "type": "legs", "muscle": "Legs",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 10,
      "emoji": "💪",
    },
    {
      "name": "Walking Lunges",
      "type": "legs", "muscle": "Legs",
      "equipment": "dumbbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 10.0, "defaultReps": 12,
      "emoji": "🦵",
    },
    {
      "name": "Bodyweight Lunges",
      "type": "legs", "muscle": "Legs",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "🦵",
    },
    {
      "name": "Leg Extension",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 15,
      "emoji": "🤖",
    },
    {
      "name": "Leg Curl",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 35.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Seated Leg Curl",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 30.0, "defaultReps": 12,
      "emoji": "🤖",
    },
    {
      "name": "Standing Calf Raise",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 60.0, "defaultReps": 15,
      "emoji": "🦵",
    },
    {
      "name": "Seated Calf Raise",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 15,
      "emoji": "🦵",
    },
    {
      "name": "Hack Squat",
      "type": "legs", "muscle": "Legs",
      "equipment": "machine", "movement": "compound",
      "bodyweight": false, "defaultWeight": 60.0, "defaultReps": 10,
      "emoji": "🤖",
    },

    // ═══════════════════════════════════════
    // ARMS — Biceps 8 + Triceps 8
    // ═══════════════════════════════════════

    // — Biceps —
    {
      "name": "Barbell Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "barbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 30.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "EZ Bar Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "barbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 25.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Dumbbell Bicep Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 12.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Hammer Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 12.0, "defaultReps": 12,
      "emoji": "🔨",
    },
    {
      "name": "Incline Dumbbell Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 10.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Concentration Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 10.0, "defaultReps": 12,
      "emoji": "🎯",
    },
    {
      "name": "Cable Bicep Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 15.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Preacher Curl",
      "type": "pull", "muscle": "Arms",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 12,
      "emoji": "🤖",
    },

    // — Triceps —
    {
      "name": "Close Grip Bench Press",
      "type": "push", "muscle": "Arms",
      "equipment": "barbell", "movement": "compound",
      "bodyweight": false, "defaultWeight": 40.0, "defaultReps": 10,
      "emoji": "🏋️",
    },
    {
      "name": "Skull Crushers",
      "type": "push", "muscle": "Arms",
      "equipment": "barbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 25.0, "defaultReps": 12,
      "emoji": "💀",
    },
    {
      "name": "Tricep Pushdown",
      "type": "push", "muscle": "Arms",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Rope Pushdown",
      "type": "push", "muscle": "Arms",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 18.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Overhead Tricep Extension",
      "type": "push", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 14.0, "defaultReps": 12,
      "emoji": "💪",
    },
    {
      "name": "Dumbbell Kickback",
      "type": "push", "muscle": "Arms",
      "equipment": "dumbbell", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 8.0, "defaultReps": 15,
      "emoji": "💪",
    },
    {
      "name": "Tricep Dips",
      "type": "push", "muscle": "Arms",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 12,
      "emoji": "🔥",
    },
    {
      "name": "Machine Tricep Extension",
      "type": "push", "muscle": "Arms",
      "equipment": "machine", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 25.0, "defaultReps": 15,
      "emoji": "🤖",
    },

    // ═══════════════════════════════════════
    // CORE — 8 exercises
    // ═══════════════════════════════════════
    {
      "name": "Plank",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "isometric",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 3,
      "emoji": "🔥",
    },
    {
      "name": "Crunches",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "isolation",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 20,
      "emoji": "🔥",
    },
    {
      "name": "Hanging Leg Raise",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "🔥",
    },
    {
      "name": "Cable Crunch",
      "type": "core", "muscle": "Core",
      "equipment": "cable", "movement": "isolation",
      "bodyweight": false, "defaultWeight": 20.0, "defaultReps": 15,
      "emoji": "⚡",
    },
    {
      "name": "Ab Wheel Rollout",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 12,
      "emoji": "⚙️",
    },
    {
      "name": "Russian Twist",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "isolation",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 20,
      "emoji": "🔄",
    },
    {
      "name": "Decline Sit-ups",
      "type": "core", "muscle": "Core",
      "equipment": "machine", "movement": "compound",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "🔥",
    },
    {
      "name": "Leg Raises",
      "type": "core", "muscle": "Core",
      "equipment": "bodyweight", "movement": "isolation",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "🦵",
    },

    // ═══════════════════════════════════════
    // CARDIO — 6 exercises
    // ═══════════════════════════════════════
    {
      "name": "Treadmill Run",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "machine", "movement": "cardio",
      "bodyweight": false, "defaultWeight": 0.0, "defaultReps": 20,
      "unit": "min", "emoji": "🏃",
    },
    {
      "name": "Cycling",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "machine", "movement": "cardio",
      "bodyweight": false, "defaultWeight": 0.0, "defaultReps": 20,
      "unit": "min", "emoji": "🚴",
    },
    {
      "name": "Rowing Machine",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "machine", "movement": "cardio",
      "bodyweight": false, "defaultWeight": 0.0, "defaultReps": 15,
      "unit": "min", "emoji": "🚣",
    },
    {
      "name": "Jump Rope",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "bodyweight", "movement": "cardio",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 10,
      "unit": "min", "emoji": "🪢",
    },
    {
      "name": "Stair Climber",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "machine", "movement": "cardio",
      "bodyweight": false, "defaultWeight": 0.0, "defaultReps": 15,
      "unit": "min", "emoji": "🏔️",
    },
    {
      "name": "Burpees",
      "type": "cardio", "muscle": "Cardio",
      "equipment": "bodyweight", "movement": "cardio",
      "bodyweight": true, "defaultWeight": 0.0, "defaultReps": 15,
      "emoji": "💥",
    },
  ];
}
