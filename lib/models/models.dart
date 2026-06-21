// lib/models/models.dart — v3 ADDICTION ENGINE
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════
// EXERCISE SET
// ══════════════════════════════════════════════
class ExSet {
  final String id;
  int reps;
  double weight;
  bool done;
  ExSet({required this.id, this.reps = 0, this.weight = 0.0, this.done = false});
  Map<String, dynamic> toJson() => {'id': id, 'reps': reps, 'weight': weight, 'done': done};
  factory ExSet.fromJson(Map<String, dynamic> j) => ExSet(
    id: j['id'] as String? ?? '',
    reps: j['reps'] as int? ?? 10,
    weight: (j['weight'] as num?)?.toDouble() ?? 20.0,
    done: j['done'] as bool? ?? false,
  );
}

// ══════════════════════════════════════════════
// PLANNED EXERCISE
// ══════════════════════════════════════════════
class PlannedExercise {
  final String id;
  final String baseId;
  final String name;
  final String type;
  final String unit;
  final String category;
  final String emoji;
  final List<ExSet> sets;
  final bool isFavorite;
  final bool bodyweight;
  bool isComplete;
  // Ghost Copy fields — set by GhostCopyService each new week
  int    ghostWeekGap;     // 0=no ghost, 1=progressed, 2=skipped, 3+=comeback
  double previousWeight;   // last logged weight, for display only

  bool get isCardio => unit == 'min';
  bool get isBodyweight => bodyweight;
  bool get isWeight => !isCardio && !isBodyweight;

  PlannedExercise({
    required this.id, required this.baseId, required this.name,
    required this.category, required this.emoji, required this.sets,
    this.type = '', this.unit = 'kg', this.isFavorite = false,
    this.bodyweight = false, this.isComplete = false,
    this.ghostWeekGap = 0, this.previousWeight = 0,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
  final rawSets = (json['sets'] as List?) ?? [];

  return PlannedExercise(
    id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),

    baseId: (json['baseId'] ??
            (json['name'] ?? '')
                .toString()
                .toLowerCase()
                .replaceAll(" ", "_")),

    name: json['name'] ?? "",

    category: json['category'] ?? "General",
    emoji: json['emoji'] ?? "🏋️",

    sets: rawSets.map((s) => ExSet.fromJson(s)).toList(),

    type: json['type'] ?? '',
    unit: json['unit'] ?? 'kg',
    isFavorite: json['isFavorite'] ?? false,
    bodyweight: json['bodyweight'] ?? false,
    isComplete: json['isComplete'] ?? false,
    ghostWeekGap:    (json['ghostWeekGap'] as int?)    ?? 0,
    previousWeight:  (json['previousWeight'] as num?)?.toDouble() ?? 0,
  );
}

  Map<String, dynamic> toJson() => {
    'id': id, 'baseId': baseId, 'name': name, 'type': type, 'unit': unit,
    'category': category, 'emoji': emoji, 'sets': sets.map((e) => e.toJson()).toList(),
    'isFavorite': isFavorite, 'bodyweight': bodyweight, 'isComplete': isComplete,
    'ghostWeekGap': ghostWeekGap, 'previousWeight': previousWeight,
  };

  double get totalVolume {
    if (unit == 'min' || unit == 'reps') return 0;
    final activeSets = sets.where((s) => s.weight > 0 && s.reps > 0);
    if (activeSets.isEmpty) return 0;
    return activeSets.fold(0.0, (v, s) => v + (s.reps * s.weight));
  }
}


// ══════════════════════════════════════════════
// DAY PLAN
// ══════════════════════════════════════════════
class DayPlan {
  final String id;
  int dayIndex;
  String title;
  List<PlannedExercise> exercises;
  bool isRestDay;
  bool isCompleted;
  bool isPendingReview;
  int durationMinutes;
  bool wasEdited;
  String? completionDate;

  DayPlan({
    required this.id, required this.dayIndex, required this.title,
    required this.exercises, this.isRestDay = false, this.isCompleted = false,
    this.isPendingReview = false,
    this.durationMinutes = 0, this.wasEdited = false, this.completionDate,
  });

  double get totalVolume => exercises.fold(0.0, (v, e) => v + e.totalVolume);
  int get completedExercises => exercises.where((e) => e.isComplete).length;

  Map<String, dynamic> toJson() => {
    'id': id, 'dayIndex': dayIndex, 'title': title,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isRestDay': isRestDay, 'isCompleted': isCompleted,
    'isPendingReview': isPendingReview,
    'durationMinutes': durationMinutes,
    'wasEdited': wasEdited, 'completionDate': completionDate,
  };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
    id: j['id'] as String? ?? '', dayIndex: j['dayIndex'] as int? ?? 0,
    title: j['title'] as String? ?? '',
    exercises: ((j['exercises'] as List?) ?? const [])
        .map((e) => PlannedExercise.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    isRestDay: j['isRestDay'] as bool? ?? false,
    isCompleted: j['isCompleted'] as bool? ?? false,
    isPendingReview: j['isPendingReview'] as bool? ?? false,
    durationMinutes: j['durationMinutes'] as int? ?? 0,
    wasEdited: j['wasEdited'] as bool? ?? false,
    completionDate: j['completionDate'] as String?,
  );
}

// ══════════════════════════════════════════════
// USER PROFILE
// ══════════════════════════════════════════════
class UserProfile {
  String name;
  int age;
  double weightKg;
  double heightCm;
  String trainerType;
  String goal;
  String level;
  String gender;
  String activityLevel;
  String dietPreference; // 'veg', 'nonveg', 'eggetarian'
  String location; // e.g. 'Maharashtra', 'Delhi'
  bool usesWheyProtein; // true if user takes whey supplement
  bool usesCreatine; // true if user takes creatine
  String workoutTime; // 'morning' | 'evening'
  String bodyType; // 'ectomorph', 'mesomorph', 'endomorph'
  String cuisinePreference; // 'maharashtrian', 'north_indian', 'south_indian', 'mixed'
  String state; // Indian state for local food preferences

  UserProfile({
    this.name = 'Champion', this.age = 25, this.weightKg = 70.0, this.heightCm = 170.0,
    this.goal = 'muscle_gain', this.level = 'beginner', this.gender = 'male',
    this.trainerType = 'friendly', this.activityLevel = 'Moderate',
    this.dietPreference = 'veg',
    this.location = 'India',
    this.usesWheyProtein = false,
    this.usesCreatine = false,
    this.workoutTime = 'evening',
    this.bodyType = 'mesomorph',
    this.cuisinePreference = 'mixed',
    this.state = 'Maharashtra',
  });

  double get bmi => weightKg / ((heightCm / 100.0) * (heightCm / 100.0));

  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  double get bmr => gender == 'male'
      ? (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) + 5.0
      : (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) - 161.0;

  UserProfile copyWith({
    String? name, int? age, double? weightKg, double? heightCm,
    String? goal, String? level, String? gender,
    String? trainerType, String? activityLevel,
    String? dietPreference, String? location,
    bool? usesWheyProtein, bool? usesCreatine,
    String? workoutTime, String? bodyType, String? cuisinePreference,
    String? state,
  }) => UserProfile(
    name: name ?? this.name, age: age ?? this.age,
    weightKg: weightKg ?? this.weightKg, heightCm: heightCm ?? this.heightCm,
    goal: goal ?? this.goal, level: level ?? this.level, gender: gender ?? this.gender,
    dietPreference: dietPreference ?? this.dietPreference,
    location: location ?? this.location,
    usesWheyProtein: usesWheyProtein ?? this.usesWheyProtein,
    usesCreatine: usesCreatine ?? this.usesCreatine,
    workoutTime: workoutTime ?? this.workoutTime,
    bodyType: bodyType ?? this.bodyType,
    cuisinePreference: cuisinePreference ?? this.cuisinePreference,
    state: state ?? this.state,
    trainerType: trainerType ?? this.trainerType,
    activityLevel: activityLevel ?? this.activityLevel,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'age': age, 'weightKg': weightKg, 'heightCm': heightCm,
    'goal': goal, 'level': level, 'gender': gender,
    'trainerType': trainerType, 'activityLevel': activityLevel,
    'dietPreference': dietPreference, 'location': location,
    'usesWheyProtein': usesWheyProtein, 'usesCreatine': usesCreatine,
    'workoutTime': workoutTime,
    'bodyType': bodyType,
    'cuisinePreference': cuisinePreference,
    'state': state,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    String rawGoal = j['goal'] as String? ?? 'muscle_gain';
    if (rawGoal == 'Muscle Gain') rawGoal = 'muscle_gain';
    if (rawGoal == 'Fat Loss') rawGoal = 'fat_loss';
    if (rawGoal == 'Strength') rawGoal = 'strength';
    String rawLevel = (j['level'] as String? ?? 'beginner').toLowerCase();
    return UserProfile(
      name: j['name'] as String? ?? 'Champion', age: j['age'] as int? ?? 25,
      weightKg: (j['weightKg'] as num?)?.toDouble() ?? 70.0,
      heightCm: (j['heightCm'] as num?)?.toDouble() ?? 170.0,
      goal: rawGoal, level: rawLevel, gender: j['gender'] as String? ?? 'male',
      trainerType: j['trainerType'] as String? ?? 'friendly',
      activityLevel: j['activityLevel'] as String? ?? 'Moderate',
      dietPreference: j['dietPreference'] as String? ?? 'veg',
      location: j['location'] as String? ?? 'India',
      usesWheyProtein: j['usesWheyProtein'] as bool? ?? false,
      usesCreatine: j['usesCreatine'] as bool? ?? false,
      workoutTime: _migrateWorkoutTime(j['workoutTime'] as String? ?? 'evening'),      bodyType: j['bodyType'] as String? ?? 'mesomorph',
      cuisinePreference: j['cuisinePreference'] as String? ?? 'mixed',
      state: j['state'] as String? ?? 'Maharashtra',
    );
  }

  // Migrate old 4-option values → 2-option: afternoon/night → evening
  static String _migrateWorkoutTime(String v) =>
      (v == 'morning') ? 'morning' : 'evening';
}

// ══════════════════════════════════════════════
// XP + LEVEL SYSTEM — ADDICTION ENGINE
// ══════════════════════════════════════════════
enum UserRank { recruit, warrior, gladiator, champion, legend, beast }

extension UserRankExt on UserRank {
  String get displayName {
    switch (this) {
      case UserRank.recruit:   return 'Recruit';
      case UserRank.warrior:   return 'Warrior';
      case UserRank.gladiator: return 'Gladiator';
      case UserRank.champion:  return 'Champion';
      case UserRank.legend:    return 'Legend';
      case UserRank.beast:     return 'Beast';
    }
  }
  String get emoji {
    switch (this) {
      case UserRank.recruit:   return '🥋';
      case UserRank.warrior:   return '⚔️';
      case UserRank.gladiator: return '🛡️';
      case UserRank.champion:  return '🏆';
      case UserRank.legend:    return '👑';
      case UserRank.beast:     return '🔱';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRank.recruit:   return Icons.fitness_center_rounded;
      case UserRank.warrior:   return Icons.bolt_rounded;
      case UserRank.gladiator: return Icons.verified_rounded;
      case UserRank.champion:  return Icons.workspace_premium_rounded;
      case UserRank.legend:    return Icons.military_tech_rounded;
      case UserRank.beast:     return Icons.local_fire_department_rounded;
    }
  }
}

class XPSystem {
  int totalXP;
  int weeklyXP;
  String weekStartDate;

  XPSystem({this.totalXP = 0, this.weeklyXP = 0, this.weekStartDate = ''});

  UserRank get rank {
    if (totalXP >= 10000) return UserRank.beast;
    if (totalXP >= 6000)  return UserRank.legend;
    if (totalXP >= 3000)  return UserRank.champion;
    if (totalXP >= 1500)  return UserRank.gladiator;
    if (totalXP >= 500)   return UserRank.warrior;
    return UserRank.recruit;
  }

  int get xpForNextRank {
    switch (rank) {
      case UserRank.recruit:   return 500;
      case UserRank.warrior:   return 1500;
      case UserRank.gladiator: return 3000;
      case UserRank.champion:  return 6000;
      case UserRank.legend:    return 10000;
      case UserRank.beast:     return 99999;
    }
  }

  int get xpForCurrentRank {
    switch (rank) {
      case UserRank.recruit:   return 0;
      case UserRank.warrior:   return 500;
      case UserRank.gladiator: return 1500;
      case UserRank.champion:  return 3000;
      case UserRank.legend:    return 6000;
      case UserRank.beast:     return 10000;
    }
  }

  double get rankProgress {
    if (rank == UserRank.beast) return 1.0;
    final current = totalXP - xpForCurrentRank;
    final needed  = xpForNextRank - xpForCurrentRank;
    return (current / needed).clamp(0.0, 1.0);
  }

  String get nextRankName {
    switch (rank) {
      case UserRank.recruit:   return 'Warrior';
      case UserRank.warrior:   return 'Gladiator';
      case UserRank.gladiator: return 'Champion';
      case UserRank.champion:  return 'Legend';
      case UserRank.legend:    return 'Beast';
      case UserRank.beast:     return 'MAX';
    }
  }


  // XP needed to reach next rank
  int get xpToNextRank {
    if (rank == UserRank.beast) return 0;
    return (xpForNextRank - totalXP).clamp(0, 999999);
  }

  // Next rank emoji
  String get nextRankEmoji {
    switch (rank) {
      case UserRank.recruit:   return '⚔️';
      case UserRank.warrior:   return '🛡️';
      case UserRank.gladiator: return '🏅';
      case UserRank.champion:  return '👑';
      case UserRank.legend:    return '💎';
      case UserRank.beast:     return '🔱';
    }
  }




  // XP reward constants
  static const int xpWorkoutComplete = 100;
  static const int xpStreakBonus     = 25;
  static const int xpPRBroken        = 150;
  static const int xpMissionComplete = 75;
  static const int xpSetCompleted    = 5;

  Map<String, dynamic> toJson() => {
    'totalXP': totalXP, 'weeklyXP': weeklyXP, 'weekStartDate': weekStartDate,
  };

  factory XPSystem.fromJson(Map<String, dynamic> j) => XPSystem(
    totalXP: j['totalXP'] as int? ?? 0,
    weeklyXP: j['weeklyXP'] as int? ?? 0,
    weekStartDate: j['weekStartDate'] as String? ?? '',
  );
}

// ══════════════════════════════════════════════
// DAILY MISSIONS — HABIT LOOP
// ══════════════════════════════════════════════
enum MissionType { workout, sets, streak, pr }

class DailyMission {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int xpReward;
  bool isCompleted;
  final MissionType type;

  DailyMission({
    required this.id, required this.title, required this.description,
    required this.emoji, required this.xpReward, required this.type,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description, 'emoji': emoji,
    'xpReward': xpReward, 'isCompleted': isCompleted, 'type': type.name,
  };

  factory DailyMission.fromJson(Map<String, dynamic> j) => DailyMission(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    emoji: j['emoji'] as String? ?? '🎯',
    xpReward: j['xpReward'] as int? ?? 50,
    isCompleted: j['isCompleted'] as bool? ?? false,
    type: MissionType.values.firstWhere(
      (e) => e.name == (j['type'] as String? ?? 'workout'),
      orElse: () => MissionType.workout,
    ),
  );
}

class MissionGenerator {
  static List<DailyMission> generate({
    required String goal, required int streak, required int totalWorkouts,
  }) {
    final date = DateTime.now();
    return [
      DailyMission(
        id: 'workout_${date.day}',
        title: 'Complete Today\'s Workout',
        description: 'Finish all sets in your plan',
        emoji: '🏋️',
        xpReward: XPSystem.xpWorkoutComplete,
        type: MissionType.workout,
      ),
      if (streak >= 3)
        DailyMission(
          id: 'streak_${date.day}',
          title: '${streak + 1}-Day Streak',
          description: 'Don\'t break the ${streak}-day chain!',
          emoji: '🔥',
          xpReward: XPSystem.xpStreakBonus * (streak ~/ 3 + 1),
          type: MissionType.streak,
        )
      else
        DailyMission(
          id: 'sets_${date.day}',
          title: 'Complete 15 Sets Today',
          description: 'Log at least 15 total sets',
          emoji: '💪',
          xpReward: XPSystem.xpMissionComplete,
          type: MissionType.sets,
        ),
    ];
  }
}

// ══════════════════════════════════════════════
// MOOD TYPE
// ══════════════════════════════════════════════
enum MoodType { tired, normal, energetic }

extension MoodTypeExt on MoodType {
  String get label {
    switch (this) {
      case MoodType.tired:     return 'Tired';
      case MoodType.normal:    return 'Normal';
      case MoodType.energetic: return 'Energetic';
    }
  }
  String get emoji {
    switch (this) {
      case MoodType.tired:     return '😴';
      case MoodType.normal:    return '😐';
      case MoodType.energetic: return '⚡';
    }
  }
  String get advice {
    switch (this) {
      case MoodType.tired:     return '60% intensity — focus on form, not weight';
      case MoodType.normal:    return 'Standard plan — you\'ve got this 💪';
      case MoodType.energetic: return 'Beast mode ON — push for PRs today! 🔥';
    }
  }
  String get coachResponse {
    switch (this) {
      case MoodType.tired:
        return '😴 Feeling tired? That\'s OK — even 60% is better than zero. Let\'s go light today.';
      case MoodType.energetic:
        return '⚡ You\'re FIRED UP! This is the day to push for PRs. Don\'t waste this energy!';
      default:
        return '💪 Solid energy today. Stick to the plan and execute perfectly.';
    }
  }
}

// ══════════════════════════════════════════════
// STREAK DATA
// ══════════════════════════════════════════════
class StreakData {
  int currentStreak;
  int longestStreak;
  int totalWorkouts;
  String lastWorkoutDate;
  List<String> earnedBadges;

  StreakData({
    this.currentStreak = 0, this.longestStreak = 0, this.totalWorkouts = 0,
    this.lastWorkoutDate = '', List<String>? earnedBadges,
  }) : earnedBadges = earnedBadges ?? [];

  Map<String, dynamic> toJson() => {
    'currentStreak': currentStreak, 'longestStreak': longestStreak,
    'totalWorkouts': totalWorkouts, 'lastWorkoutDate': lastWorkoutDate,
    'earnedBadges': earnedBadges,
  };

  factory StreakData.fromJson(Map<String, dynamic> j) => StreakData(
    currentStreak: j['currentStreak'] as int? ?? 0,
    longestStreak: j['longestStreak'] as int? ?? 0,
    totalWorkouts: j['totalWorkouts'] as int? ?? 0,
    lastWorkoutDate: j['lastWorkoutDate'] as String? ?? '',
    earnedBadges: List<String>.from(j['earnedBadges'] as List? ?? const []),
  );
}

// ══════════════════════════════════════════════
// BADGE SYSTEM
// ══════════════════════════════════════════════
class AppBadge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int xpReward;

  const AppBadge({
    required this.id, required this.title, required this.description,
    required this.emoji, this.xpReward = 50,
  });

  IconData get icon {
    switch (id) {
      case 'first_workout':    return Icons.fitness_center_rounded;
      case 'week_streak':      return Icons.local_fire_department_rounded;
      case 'two_week_streak':  return Icons.bolt_rounded;
      case 'month_streak':     return Icons.military_tech_rounded;
      case 'ten_workouts':     return Icons.trending_up_rounded;
      case 'fifty_workouts':   return Icons.workspace_premium_rounded;
      case 'hundred_workouts': return Icons.emoji_events_rounded;
      case 'early_bird':       return Icons.bedtime_rounded;
      case 'volume_king':      return Icons.bar_chart_rounded;
      case 'consistency':      return Icons.calendar_month_rounded;
      case 'pr_smasher':       return Icons.trending_up_rounded;
      default:                 return Icons.star_rounded;
    }
  }
}

class BadgeSystem {
  static const List<AppBadge> all = [
    AppBadge(id: 'first_workout',    emoji: '🥊', title: 'First Blood',    description: 'First workout done!',      xpReward: 100),
    AppBadge(id: 'week_streak',      emoji: '🔥', title: '7-Day Warrior',  description: '7 days in a row!',         xpReward: 200),
    AppBadge(id: 'two_week_streak',  emoji: '🚀', title: 'Unstoppable',    description: '14-day streak!',           xpReward: 400),
    AppBadge(id: 'month_streak',     emoji: '⚔️', title: 'Iron Will',      description: '30-day streak!',           xpReward: 1000),
    AppBadge(id: 'ten_workouts',     emoji: '💪', title: 'Getting Strong', description: '10 workouts done!',        xpReward: 150),
    AppBadge(id: 'fifty_workouts',   emoji: '🐀', title: 'Gym Rat',        description: '50 workouts done!',        xpReward: 500),
    AppBadge(id: 'hundred_workouts', emoji: '👑', title: 'Legend',         description: '100 workouts done!',       xpReward: 2000),
    AppBadge(id: 'early_bird',       emoji: '🌅', title: 'Early Bird',     description: '5 morning workouts!',      xpReward: 200),
    AppBadge(id: 'volume_king',      emoji: '🏋️', title: 'Volume King',    description: '10,000kg total volume!',   xpReward: 500),
    AppBadge(id: 'consistency',      emoji: '📅', title: 'Consistent',     description: '4 weeks completed!',       xpReward: 300),
    AppBadge(id: 'pr_smasher',       emoji: '📈', title: 'PR Smasher',     description: 'Broke a personal record!', xpReward: 150),
  ];

  static List<AppBadge> checkNewBadges(StreakData streak, List<String> existing) {
    final earned = <AppBadge>[];
    for (final badge in all) {
      if (existing.contains(badge.id)) continue;
      bool unlocked = false;
      switch (badge.id) {
        case 'first_workout':    unlocked = streak.totalWorkouts >= 1; break;
        case 'ten_workouts':     unlocked = streak.totalWorkouts >= 10; break;
        case 'fifty_workouts':   unlocked = streak.totalWorkouts >= 50; break;
        case 'hundred_workouts': unlocked = streak.totalWorkouts >= 100; break;
        case 'week_streak':      unlocked = streak.currentStreak >= 7; break;
        case 'two_week_streak':  unlocked = streak.currentStreak >= 14; break;
        case 'month_streak':     unlocked = streak.currentStreak >= 30; break;
      }
      if (unlocked) earned.add(badge);
    }
    return earned;
  }
}

// ══════════════════════════════════════════════
// HISTORY ENTRY
// ══════════════════════════════════════════════
class HistoryEntry {
  final String id;
  final String date;
  final String workoutName;
  final int durationMinutes;
  final double totalVolume;
  final int exerciseCount;
  final int setCount;
  final int xpEarned;

  HistoryEntry({
    required this.id, required this.date, required this.workoutName,
    required this.durationMinutes, required this.totalVolume,
    required this.exerciseCount, required this.setCount, this.xpEarned = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'workoutName': workoutName,
    'durationMinutes': durationMinutes, 'totalVolume': totalVolume,
    'exerciseCount': exerciseCount, 'setCount': setCount, 'xpEarned': xpEarned,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    id: j['id'] as String? ?? '', date: j['date'] as String? ?? '',
    workoutName: j['workoutName'] as String? ?? '',
    durationMinutes: j['durationMinutes'] as int? ?? 0,
    totalVolume: (j['totalVolume'] as num?)?.toDouble() ?? 0.0,
    exerciseCount: j['exerciseCount'] as int? ?? 0,
    setCount: j['setCount'] as int? ?? 0,
    xpEarned: j['xpEarned'] as int? ?? 0,
  );
}

// ══════════════════════════════════════════════
// BODY MEASUREMENT
// ══════════════════════════════════════════════
class BodyMeasurement {
  final String id;
  final String date;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? leftArmCm;
  final double? rightArmCm;
  final double? weightKg;
  final double? bodyFatPct;
  final String? notes;

  BodyMeasurement({
    required this.id, required this.date, this.chestCm, this.waistCm,
    this.hipsCm, this.leftArmCm, this.rightArmCm, this.weightKg,
    this.bodyFatPct, this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'chestCm': chestCm, 'waistCm': waistCm,
    'hipsCm': hipsCm, 'leftArmCm': leftArmCm, 'rightArmCm': rightArmCm,
    'weightKg': weightKg, 'bodyFatPct': bodyFatPct, 'notes': notes,
  };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
    id: j['id'] as String? ?? '', date: j['date'] as String? ?? '',
    chestCm: (j['chestCm'] as num?)?.toDouble(),
    waistCm: (j['waistCm'] as num?)?.toDouble(),
    hipsCm: (j['hipsCm'] as num?)?.toDouble(),
    leftArmCm: (j['leftArmCm'] as num?)?.toDouble(),
    rightArmCm: (j['rightArmCm'] as num?)?.toDouble(),
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    bodyFatPct: (j['bodyFatPct'] as num?)?.toDouble(),
    notes: j['notes'] as String?,
  );
}

// ══════════════════════════════════════════════
// RECOVERY MODEL
// ══════════════════════════════════════════════
class MuscleRecovery {
  final String muscle;
  final int recoveryScore;
  final String lastTrainedDate;
  final double lastVolume;

  const MuscleRecovery({
    required this.muscle, required this.recoveryScore,
    required this.lastTrainedDate, required this.lastVolume,
  });

  String get status {
    if (recoveryScore >= 80) return 'Ready';
    if (recoveryScore >= 50) return 'Recovering';
    return 'Fatigued';
  }

  String get emoji {
    if (recoveryScore >= 80) return '✅';
    if (recoveryScore >= 50) return '🟡';
    return '🔴';
  }
  String get message {
  if (recoveryScore >= 80) return "Ready 🔥";
  if (recoveryScore >= 50) return "Recovering 🟡";
  if (recoveryScore < 30) return "Recently trained 💪 — allow recovery";
  return "Rest recommended ⚠️";
}
}

// ══════════════════════════════════════════════
// NUTRITION LOG
// ══════════════════════════════════════════════
class NutritionDay {
  final String date;
  int proteinG;
  int carbsG;
  int fatG;
  int waterMl;
  int calories;

  NutritionDay({
    required this.date, this.proteinG = 0, this.carbsG = 0,
    this.fatG = 0, this.waterMl = 0, this.calories = 0,
  });

  Map<String, dynamic> toJson() => {
    'date': date, 'proteinG': proteinG, 'carbsG': carbsG,
    'fatG': fatG, 'waterMl': waterMl, 'calories': calories,
  };

  factory NutritionDay.fromJson(Map<String, dynamic> j) => NutritionDay(
    date: j['date'] as String? ?? '',
    proteinG: j['proteinG'] as int? ?? 0,
    carbsG: j['carbsG'] as int? ?? 0,
    fatG: j['fatG'] as int? ?? 0,
    waterMl: j['waterMl'] as int? ?? 0,
    calories: j['calories'] as int? ?? 0,
  );
}
