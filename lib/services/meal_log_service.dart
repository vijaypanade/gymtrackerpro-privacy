// lib/services/meal_log_service.dart
// Local-only meal log — stored in SharedPreferences as JSON.
// Key: "meal_log_YYYY-MM-DD"  →  Map<firestoreKey, entryJson>

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_log_model.dart';

class MealLogService {
  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static String _prefKey(DateTime dt) => 'meal_log_${_dateKey(dt)}';

  // ── Write ──────────────────────────────────────────────────
  static Future<void> logMeal(String uid, MealLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _prefKey(DateTime.now());
      final raw   = prefs.getString(key);
      final map   = raw != null
          ? Map<String, dynamic>.from(json.decode(raw) as Map)
          : <String, dynamic>{};
      map[entry.firestoreKey] = entry.toJson();
      await prefs.setString(key, json.encode(map));
    } catch (e) {
      debugPrint('MealLogService.logMeal error: $e');
    }
  }

  static Future<void> unlogMeal(String uid, MealLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _prefKey(DateTime.now());
      final raw   = prefs.getString(key);
      if (raw == null) return;
      final map = Map<String, dynamic>.from(json.decode(raw) as Map);
      map.remove(entry.firestoreKey);
      await prefs.setString(key, json.encode(map));
    } catch (e) {
      debugPrint('MealLogService.unlogMeal error: $e');
    }
  }

  // ── Read ───────────────────────────────────────────────────
  static Future<DayMealLog> getTodayLog(String uid) async {
    return getLogForDate(uid, DateTime.now());
  }

  static Future<DayMealLog> getLogForDate(String uid, DateTime dt) async {
    final date = _dateKey(dt);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefKey(dt));
      return _parse(date, raw);
    } catch (e) {
      debugPrint('MealLogService.getLogForDate error: $e');
      return DayMealLog(date: date, entries: {});
    }
  }

  static DayMealLog _parse(String date, String? raw) {
    if (raw == null) return DayMealLog(date: date, entries: {});
    try {
      final map     = Map<String, dynamic>.from(json.decode(raw) as Map);
      final entries = <String, MealLogEntry>{};
      for (final kv in map.entries) {
        try {
          entries[kv.key] =
              MealLogEntry.fromJson(kv.value as Map<String, dynamic>);
        } catch (_) {}
      }
      return DayMealLog(date: date, entries: entries);
    } catch (_) {
      return DayMealLog(date: date, entries: {});
    }
  }

  // ── Last N days (for future analysis) ─────────────────────
  static Future<List<DayMealLog>> getRecentDays(String uid,
      {int days = 7}) async {
    final prefs  = await SharedPreferences.getInstance();
    final now    = DateTime.now();
    final result = <DayMealLog>[];
    for (int i = 0; i < days; i++) {
      final dt   = now.subtract(Duration(days: i));
      final date = _dateKey(dt);
      final raw  = prefs.getString(_prefKey(dt));
      result.add(_parse(date, raw));
    }
    return result;
  }
}
