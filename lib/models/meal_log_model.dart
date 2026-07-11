// lib/models/meal_log_model.dart
// ════════════════════════════════════════════════
// Meal logging — tracks what user actually ate
// Stored in Firestore: /meal_logs/{uid}/days/{date}
// ════════════════════════════════════════════════

class MealLogEntry {
  final String  mealType;
  final int     planDay;
  final List<String> foods;
  final int     kcal;
  final int     protein;
  final int     carbs;
  final int     fats;
  final DateTime loggedAt;

  const MealLogEntry({
    required this.mealType,
    required this.planDay,
    required this.foods,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.loggedAt,
  });

  // Storage key: unique per food entry (includes timestamp)
  String get firestoreKey => '${planDay}_${mealType}_${loggedAt.microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'meal_type': mealType,
    'plan_day':  planDay,
    'foods':     foods,
    'kcal':      kcal,
    'protein':   protein,
    'carbs':     carbs,
    'fats':      fats,
    'logged_at': loggedAt.toIso8601String(),
  };

  factory MealLogEntry.fromJson(Map<String, dynamic> j) => MealLogEntry(
    mealType:  j['meal_type'] as String,
    planDay:   (j['plan_day']  as num).toInt(),
    foods:     List<String>.from(j['foods'] as List),
    kcal:      (j['kcal']      as num).toInt(),
    protein:   (j['protein']   as num).toInt(),
    carbs:     (j['carbs']     as num).toInt(),
    fats:      (j['fats']      as num).toInt(),
    loggedAt:  DateTime.parse(j['logged_at'] as String),
  );
}

class DayMealLog {
  final String date;
  // key: "{planDay}_{mealType}" → entry
  final Map<String, MealLogEntry> entries;

  const DayMealLog({required this.date, required this.entries});

  // Consumed macros for a specific plan day
  int consumedKcal   (int day) => _sum(day, (e) => e.kcal);
  int consumedProtein(int day) => _sum(day, (e) => e.protein);
  int consumedCarbs  (int day) => _sum(day, (e) => e.carbs);
  int consumedFats   (int day) => _sum(day, (e) => e.fats);

  int _sum(int day, int Function(MealLogEntry) pick) => entries.values
      .where((e) => e.planDay == day)
      .fold(0, (s, e) => s + pick(e));

  bool isLogged(int planDay, String mealType) =>
      entries.containsKey('${planDay}_$mealType');

  Set<String> loggedMealTypes(int planDay) => entries.values
      .where((e) => e.planDay == planDay)
      .map((e) => e.mealType)
      .toSet();
}
