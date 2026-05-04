// lib/providers/settings_provider.dart
//
// RESPONSIBILITY: App settings only — notifications, reminders, intervals.
// NOT responsible for: user profile, water goal, mood — those live in UserProvider.
//
// PERSISTENCE: SharedPreferences via StorageService.
// LIFECYCLE: Loaded on init(), saved on every change.

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const Map<String, dynamic> _defaults = {
    'workoutReminderEnabled': false,
    'waterReminderEnabled':   false,
    'notificationsEnabled':   true,
    'waterReminderInterval':  60,
  };

  Map<String, dynamic> _settings = Map.of(_defaults);
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Map<String, dynamic> get all => Map.unmodifiable(_settings);

  // ── Typed accessors ──────────────────────────────────────
  bool get workoutReminderEnabled =>
      (_settings['workoutReminderEnabled'] as bool?) ?? false;
  bool get waterReminderEnabled =>
      (_settings['waterReminderEnabled'] as bool?) ?? false;
  bool get notificationsEnabled =>
      (_settings['notificationsEnabled'] as bool?) ?? true;
  int  get waterReminderInterval =>
      (_settings['waterReminderInterval'] as int?) ?? 60;

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
