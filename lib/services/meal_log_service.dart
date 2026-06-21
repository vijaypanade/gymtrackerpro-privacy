// lib/services/meal_log_service.dart
// ════════════════════════════════════════════════
// Firestore schema:
//   /meal_logs/{uid}/days/{YYYY-MM-DD}
//     logged_meals: {
//       "1_Breakfast": { meal_type, plan_day, foods, kcal, ... },
//       "1_Lunch":     { ... },
//     }
// ════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_log_model.dart';

class MealLogService {
  static final _db = FirebaseFirestore.instance;

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static DocumentReference _ref(String uid, [DateTime? dt]) => _db
      .collection('meal_logs')
      .doc(uid)
      .collection('days')
      .doc(_dateKey(dt ?? DateTime.now()));

  // ── Write ──────────────────────────────────────────────────
  static Future<void> logMeal(String uid, MealLogEntry entry) async {
    await _ref(uid).set({
      'date':         _dateKey(DateTime.now()),
      'logged_meals': {entry.firestoreKey: entry.toJson()},
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> unlogMeal(String uid, MealLogEntry entry) async {
    await _ref(uid).update({
      'logged_meals.${entry.firestoreKey}': FieldValue.delete(),
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  // ── Read (one-shot, used on screen open) ───────────────────
  static Future<DayMealLog> getTodayLog(String uid) async {
    final date = _dateKey(DateTime.now());
    try {
      final snap = await _ref(uid).get();
      return _parse(date, snap.data() as Map<String, dynamic>?);
    } catch (_) {
      return DayMealLog(date: date, entries: {});
    }
  }

  // ── Parse helper ───────────────────────────────────────────
  static DayMealLog _parse(String date, Map<String, dynamic>? data) {
    if (data == null) return DayMealLog(date: date, entries: {});
    final raw = data['logged_meals'] as Map<String, dynamic>? ?? {};
    final entries = <String, MealLogEntry>{};
    for (final kv in raw.entries) {
      try {
        final e = MealLogEntry.fromJson(kv.value as Map<String, dynamic>);
        entries[kv.key] = e;
      } catch (_) {}
    }
    return DayMealLog(date: date, entries: entries);
  }

  // ── Last N days (for pattern analysis — Phase 5) ───────────
  static Future<List<DayMealLog>> getRecentDays(String uid,
      {int days = 7}) async {
    final logs = <DayMealLog>[];
    final now  = DateTime.now();
    for (int i = 0; i < days; i++) {
      final dt   = now.subtract(Duration(days: i));
      final date = _dateKey(dt);
      try {
        final snap = await _ref(uid, dt).get();
        logs.add(_parse(date, snap.data() as Map<String, dynamic>?));
      } catch (_) {
        logs.add(DayMealLog(date: date, entries: {}));
      }
    }
    return logs;
  }
}
