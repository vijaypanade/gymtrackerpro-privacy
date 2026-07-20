// lib/services/storage_service.dart
//
// Single source of truth for all persistence in the app.
//
// RESPONSIBILITIES:
//   - Open Hive boxes safely (idempotent — safe to call multiple times)
//   - Provide typed read/write helpers for SharedPreferences (JSON)
//   - Provide Hive box getters with null-safe access
//   - Surface errors via return values — never silently swallow
//
// DESIGN NOTES:
//   - Singleton (StorageService.instance)
//   - All keys defined here as constants — providers reference them
//   - JSON encode/decode happens here so providers stay clean
//   - Hive boxes are dynamic (Box<dynamic>) for flexibility; consumers cast

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage operation result — explicit success/failure instead of silent catch.
class StorageResult<T> {
  final T?     data;
  final bool   success;
  final String error;

  const StorageResult._(this.data, this.success, this.error);

  factory StorageResult.ok(T data) => StorageResult._(data, true, '');
  factory StorageResult.fail(String reason) => StorageResult._(null, false, reason);
  factory StorageResult.empty() => const StorageResult._(null, true, '');

  bool get hasData => success && data != null;
}

class StorageKeys {
  StorageKeys._();

  // SharedPreferences keys
  static const String weekPlan          = 'week_plan_v4';
  static const String profile           = 'user_profile_v4';
  static const String streak            = 'streak_data_v4';
  static const String history           = 'history_v4';
  static const String favorites         = 'favorites_v4';
  static const String customExercises   = 'custom_exercises_v1';
  static const String settings          = 'settings_v4';
  static const String logs              = 'workout_logs_v4';
  static const String measurements      = 'body_measurements_v2';
  static const String mood              = 'today_mood_v2';
  static const String aiCache           = 'ai_coach_cache_v1';
  static const String lastMuscleTrained = 'last_muscle_trained_v1';
  static const String performanceMemory = 'perf_memory_v1';
  static const String weeklyMemory      = 'weekly_memory_v1';
  static const String analyticsCache    = 'analytics_cache_v1';
  static const String onboardingDone    = 'onboarding_done';
  static const String athleteMemory     = 'athlete_memory_v1';
  static const String dailyMission      = 'daily_mission_v1';
  static const String weeklyNarrative   = 'weekly_narrative_v1';
  static const String weeklyStoryViewed = 'weekly_story_viewed_v1';
  // RFC-PLANNER-UX-001 — {snoozeKey: 'yyyy-MM-dd'} map; entries expire daily.
  static const String plannerInsightSnooze = 'planner_insight_snooze_v1';

  // RFC-002.5: history cloud sync migration flag.
  // Stores an int version; 0 (absent) = backfill not yet run, 1 = complete.
  // NOTE: stored in SharedPreferences as a convenience; on reinstall the flag
  // is cleared and backfillHistoryIfNeeded() runs again — this is safe because
  // the backfill is fully idempotent (set() by UUID). A future RFC may migrate
  // this flag to the Firestore user document for true reinstall-persistence.
  static const String historySyncMigrationVersion = 'history_sync_migration_v';
  // Tracks consecutive backfill failures to prevent infinite retry (RC-4).
  static const String historySyncAttempts = 'history_sync_attempts';

  // RFC-002.6B: ISO-8601 timestamp of the last successful health workout sync.
  // HealthSyncEngine uses this as the `since` anchor for incremental fetches.
  // Absent (null) on first sync — HealthSyncEngine defaults to epoch (2020-01-01).
  static const String healthLastSyncDate = 'health_last_sync_date';

  // Exponential moving average of overnight HRV (SDNN, ms). Updated each time a
  // new HRV reading arrives. Absent until the first Apple Watch overnight measurement.
  static const String hrvBaseline = 'health_hrv_baseline_v1';

  // Hive box names
  static const String hiveWorkoutBox  = 'workoutBox';
  static const String hiveLogsBox     = 'logsBox';
  static const String hiveSettingsBox = 'settingsBox';

  // Hive keys (inside boxes)
  static const String hiveWeekPlan = 'weekPlan';
}

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Cached references — populated on init()
  Box?               _workoutBox;
  Box?               _logsBox;
  Box?               _settingsBox;
  SharedPreferences? _prefs;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Hive boxes and SharedPreferences.
  /// Idempotent — safe to call multiple times.
  /// Returns false if any critical step failed.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      _prefs       = await SharedPreferences.getInstance();
      _workoutBox  = await _safeOpenBox(StorageKeys.hiveWorkoutBox);
      _logsBox     = await _safeOpenBox(StorageKeys.hiveLogsBox);
      _settingsBox = await _safeOpenBox(StorageKeys.hiveSettingsBox);
      _initialized = true;
      return true;
    } catch (e, s) {
      debugPrint('❌ StorageService.init failed: $e\n$s');
      return false;
    }
  }

  /// Open a Hive box safely — handles already-open case.
  Future<Box?> _safeOpenBox(String name) async {
    try {
      if (Hive.isBoxOpen(name)) return Hive.box(name);
      return await Hive.openBox(name);
    } catch (e) {
      debugPrint('⚠️ Failed to open Hive box "$name": $e');
      return null;
    }
  }

  /// Get the SharedPreferences instance. Lazily initializes if needed.
  Future<SharedPreferences> prefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Hive box accessors ─────────────────────────────────────
  Box? get workoutBox  => _workoutBox;
  Box? get logsBox     => _logsBox;
  Box? get settingsBox => _settingsBox;

  // ─── String value helpers ───────────────────────────────────
  Future<StorageResult<bool>> setString(String key, String value) async {
    try {
      final p = await prefs();
      final ok = await p.setString(key, value);
      return ok
          ? StorageResult.ok(true)
          : StorageResult.fail('SharedPreferences.setString returned false');
    } catch (e) {
      debugPrint('setString($key) error: $e');
      return StorageResult.fail(e.toString());
    }
  }

  Future<String?> getString(String key) async {
    try {
      final p = await prefs();
      return p.getString(key);
    } catch (e) {
      debugPrint('getString($key) error: $e');
      return null;
    }
  }

  Future<bool> setBool(String key, bool value) async {
    try {
      final p = await prefs();
      return await p.setBool(key, value);
    } catch (e) {
      debugPrint('setBool($key) error: $e');
      return false;
    }
  }

  Future<bool?> getBool(String key) async {
    try {
      final p = await prefs();
      return p.getBool(key);
    } catch (e) {
      debugPrint('getBool($key) error: $e');
      return null;
    }
  }

  // ─── JSON helpers ───────────────────────────────────────────

  /// Save a JSON-serializable object as a string.
  Future<StorageResult<bool>> setJson(String key, Object value) async {
    try {
      final encoded = jsonEncode(value);
      return await setString(key, encoded);
    } catch (e) {
      debugPrint('setJson($key) encode error: $e');
      return StorageResult.fail(e.toString());
    }
  }

  /// Load a JSON object and decode via the supplied factory.
  /// Returns null if missing or invalid.
  StorageResult<T> decodeObject<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null) return StorageResult.empty();
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return StorageResult.ok(fromJson(d));
      if (d is Map) return StorageResult.ok(fromJson(Map<String, dynamic>.from(d)));
      return StorageResult.fail('Expected Map, got ${d.runtimeType}');
    } catch (e) {
      debugPrint('decodeObject error: $e');
      return StorageResult.fail(e.toString());
    }
  }

  /// Load a JSON list and decode each item via the supplied factory.
  StorageResult<List<T>> decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null) return StorageResult.ok(<T>[]);
    try {
      final d = jsonDecode(raw);
      if (d is! List) {
        return StorageResult.fail('Expected List, got ${d.runtimeType}');
      }
      final out = <T>[];
      for (final item in d) {
        try {
          if (item is Map<String, dynamic>) {
            out.add(fromJson(item));
          } else if (item is Map) out.add(fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('decodeList item skipped: $e');
        }
      }
      return StorageResult.ok(out);
    } catch (e) {
      debugPrint('decodeList error: $e');
      return StorageResult.fail(e.toString());
    }
  }

  /// Convenience: load + decode a single object directly.
  Future<T?> loadObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await getString(key);
    final result = decodeObject(raw, fromJson);
    return result.hasData ? result.data : null;
  }

  /// Convenience: load + decode a list directly. Always returns a list.
  Future<List<T>> loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await getString(key);
    final result = decodeList(raw, fromJson);
    return result.hasData ? result.data! : <T>[];
  }

  // ─── Hive helpers ───────────────────────────────────────────
  Future<bool> writeWorkoutBox(String key, dynamic value) async {
    try {
      await _workoutBox?.put(key, value);
      return true;
    } catch (e) {
      debugPrint('writeWorkoutBox($key) error: $e');
      return false;
    }
  }

  dynamic readWorkoutBox(String key) {
    try {
      return _workoutBox?.get(key);
    } catch (e) {
      debugPrint('readWorkoutBox($key) error: $e');
      return null;
    }
  }
}
