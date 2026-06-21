// lib/providers/settings_provider.dart
//
// RESPONSIBILITY: App settings only — notifications, reminders, intervals.
// NOT responsible for: user profile, water goal, mood — those live in UserProvider.
//
// PERSISTENCE: SharedPreferences via StorageService.
// LIFECYCLE: Loaded on init(), saved on every change.

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../models/split_template.dart';

class SettingsProvider extends ChangeNotifier {
  static const Map<String, dynamic> _defaults = {
    'workoutReminderEnabled': false,
    'notificationsEnabled':   true,
    'travelMode':             false,
    'travelModeStartedAt':    '',
    'splitStyle':             'pushPullLegs',
    'gymDaysPerWeek':         4,
    'readinessScore':         0,    // 0 = not set today
    'readinessDate':          '',   // ISO date string — expires each day
  };

  Map<String, dynamic> _settings = Map.of(_defaults);
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Map<String, dynamic> get all => Map.unmodifiable(_settings);

  // ── Typed accessors ──────────────────────────────────────
  bool get workoutReminderEnabled =>
      (_settings['workoutReminderEnabled'] as bool?) ?? false;
  bool get notificationsEnabled =>
      (_settings['notificationsEnabled'] as bool?) ?? true;
  bool get travelMode =>
      (_settings['travelMode'] as bool?) ?? false;
  bool get inactivityAlertEnabled =>
      (_settings['inactivityAlertEnabled'] as bool?) ?? true;
  String get travelModeStartedAt =>
      (_settings['travelModeStartedAt'] as String?) ?? '';
  SplitStyle get splitStyle =>
      SplitStyleLabel.fromName((_settings['splitStyle'] as String?) ?? 'pushPullLegs');
  int get gymDaysPerWeek =>
      ((_settings['gymDaysPerWeek'] as num?)?.toInt() ?? 4).clamp(2, 6);

  /// Returns today's readiness score (1–5), or 0 if not yet set today.
  int get todayReadiness {
    final date = (_settings['readinessDate'] as String?) ?? '';
    if (date != _todayStr) return 0;
    return ((_settings['readinessScore'] as num?)?.toInt() ?? 0).clamp(0, 5);
  }

  Future<void> setTodayReadiness(int score) async {
    _settings['readinessScore'] = score.clamp(1, 5);
    _settings['readinessDate']  = _todayStr;
    notifyListeners();
    await _persist();
  }

  /// Clears today's readiness so the selector card re-opens.
  Future<void> clearTodayReadiness() async {
    _settings['readinessScore'] = 0;
    _settings['readinessDate']  = '';
    notifyListeners();
    await _persist();
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// Load settings from storage. Idempotent.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await StorageService.instance.getString(StorageKeys.settings);
      if (raw != null) {
        final result = StorageService.instance.decodeObject(
          raw,
          (m) => m,
        );
        if (result.hasData) {
          _settings = Map<String, dynamic>.from(result.data!);
        }
      }
      // Fill any missing defaults
      _defaults.forEach((k, v) => _settings.putIfAbsent(k, () => v));
    } catch (e) {
      debugPrint('SettingsProvider.load error: $e');
      _settings = Map.of(_defaults);
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Update a single setting and persist.
  /// Silently ignores null values to prevent accidental wipes.
  Future<void> update(String key, dynamic value) async {
    if (value == null) return;
    if (_settings[key] == value) return; // no-op
    _settings[key] = value;
    notifyListeners();
    await _persist();
  }

  /// Bulk update — useful for restore-from-backup flows.
  Future<void> replaceAll(Map<String, dynamic> incoming) async {
    _settings = Map<String, dynamic>.from(incoming);
    _defaults.forEach((k, v) => _settings.putIfAbsent(k, () => v));
    notifyListeners();
    await _persist();
  }

  Future<void> resetToDefaults() async {
    _settings = Map.of(_defaults);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final result =
        await StorageService.instance.setJson(StorageKeys.settings, _settings);
    if (!result.success) {
      debugPrint('⚠️ SettingsProvider persist failed: ${result.error}');
    }
  }
}
