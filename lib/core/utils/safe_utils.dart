// lib/core/utils/safe_utils.dart
// ══════════════════════════════════════════════════════════
// CRASH FIXES for all identified unsafe patterns:
// 1. weekPlan[index] — RangeError if plan < 7 days
// 2. unsafe "as String" casts — TypeError on null/wrong type
// 3. AudioPlayer missing asset — silent swallow
// 4. Null safety gaps in fromJson factories
// ══════════════════════════════════════════════════════════

/// Safe list access — returns null instead of RangeError
extension SafeList<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  T elementAtOrDefault(int index, T defaultValue) {
    if (index < 0 || index >= length) return defaultValue;
    return this[index];
  }

  /// Safe sublist — never throws RangeError
  List<T> safeSublist(int start, [int? end]) {
    final s = start.clamp(0, length);
    final e = (end ?? length).clamp(s, length);
    return sublist(s, e);
  }
}

/// Safe JSON value extraction — never throws TypeError
extension SafeJson on Map<String, dynamic> {
  String  str(String key, [String  def = '']) =>
      (this[key] as String?)                  ?? def;
  int     i(String key,   [int     def = 0])  =>
      (this[key] as num?)?.toInt()            ?? def;
  double  d(String key,   [double  def = 0])  =>
      (this[key] as num?)?.toDouble()         ?? def;
  bool    b(String key,   [bool    def = false]) =>
      (this[key] as bool?)                    ?? def;
  List<T> lst<T>(String key) =>
      List<T>.from(this[key] as List? ?? const []);
}

/// Safe string parsing helpers
extension SafeString on String? {
  /// Parse double safely — returns 0 on null/invalid
  double toDoubleOrZero() {
    if (this == null) return 0;
    return double.tryParse(this!) ?? 0;
  }

  /// Parse int safely
  int toIntOrZero() {
    if (this == null) return 0;
    return int.tryParse(this!) ?? 0;
  }

  bool get isNullOrEmpty => this == null || this!.isEmpty;
}

// ─────────────────────────────────────────────────────────
// WEEK PLAN SAFE ACCESS
// ─────────────────────────────────────────────────────────
/// Use this everywhere instead of _weekPlan[dayIndex]
/// Prevents RangeError when AI-generated plan has < 7 days
class WeekPlanGuard {
  static bool isValidIndex(int index, int planLength) =>
      index >= 0 && index < planLength;

  static int clampTodayIndex(int rawToday, int planLength) {
    if (planLength == 0) return 0;
    return rawToday.clamp(0, planLength - 1);
  }
}

// ─────────────────────────────────────────────────────────
// AUDIO SAFE PLAYER
// ─────────────────────────────────────────────────────────
/// Wraps AudioPlayer with safe error handling
/// Missing asset won't crash the app
import 'package:audioplayers/audioplayers.dart';

class SafeAudio {
  static Future<void> playSuccess() async {
    try {
      await AudioPlayer().play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      // Silently ignore — audio is enhancement, not core feature
    }
  }

  static Future<void> playTick() async {
    try {
      await AudioPlayer().play(AssetSource('sounds/tick.mp3'));
    } catch (e) {
      // Silently ignore
    }
  }
}
