// lib/services/health_sync_engine.dart
// Sole orchestrator for health workout import.
//
// Pipeline: Fetch → Map → Build → Merge → UpdateSyncAnchor
//
// Rules:
//   • WorkoutProvider is accessed ONLY via mergeImportedHistory().
//   • package:health types never enter WorkoutProvider.
//   • Never blocks app startup — all errors are caught and logged.
//   • lastSyncDate is written AFTER a successful merge, not before.
//   • Initial import (no prior sync date) uses WriteBatch via mergeImportedHistory.
//   • Incremental sync (lastSyncDate exists) uses per-entry upload.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_models.dart';
import '../models/models.dart';
import '../providers/workout_provider.dart';
import 'health_entry_builder.dart';
import 'health_mapper.dart';
import 'health_platform_service.dart';
import 'storage_service.dart';

export '../models/health_models.dart' show HealthWorkout;

class HealthSyncEngine {
  HealthSyncEngine._();
  static final HealthSyncEngine instance = HealthSyncEngine._();

  // Epoch anchor for first-ever sync — fetches all available workouts.
  static final DateTime _epoch = DateTime(2020, 1, 1);

  /// Sync Apple Watch workouts into [workoutProvider].
  ///
  /// SEQUENCING CONSTRAINT (RFC-002.6, BC-5 — locked):
  ///   Must ONLY be called from AppProvider._initHealthPlatform(), which runs
  ///   during AppProvider.init() — AFTER tryRestoreHistoryFromCloud() has
  ///   completed in LoginScreen._signIn(). Never call from LoginScreen.
  ///   Violating this order causes duplicate imports on new-device setup
  ///   because the cloud-restored (externalSource, externalId) pairs are not
  ///   yet in the local history dedup set.
  Future<void> syncWorkouts(WorkoutProvider workoutProvider) async {
    try {
      final prefs = await StorageService.instance.prefs();
      final lastSyncStr = prefs.getString(StorageKeys.healthLastSyncDate);
      final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
      final isInitialImport = lastSync == null;
      final since = lastSync ?? _epoch;

      // Fetch raw HealthDataPoints from the platform.
      final rawPoints =
          await HealthPlatformService.instance.fetchWorkouts(since: since);

      if (rawPoints.isEmpty) {
        await _updateSyncAnchor(prefs);
        return;
      }

      // Map: HealthDataPoint → HealthWorkout? (nulls silently filtered).
      final workouts = rawPoints
          .map(HealthMapper.toHealthWorkout)
          .whereType<HealthWorkout>()
          .toList();

      if (workouts.isEmpty) {
        await _updateSyncAnchor(prefs);
        return;
      }

      // Build: HealthWorkout → HistoryEntry.
      final entries = workouts
          .map<HistoryEntry>(HealthEntryBuilder.fromHealthWorkout)
          .toList();

      // Merge into WorkoutProvider — dedup, local save, cloud sync.
      await workoutProvider.mergeImportedHistory(
        entries,
        isInitialImport: isInitialImport,
      );

      // Update sync anchor AFTER successful merge.
      await _updateSyncAnchor(prefs);

      debugPrint(
        '☁️ HealthSyncEngine: synced ${entries.length} workouts '
        '(${isInitialImport ? "initial bulk" : "incremental"}, '
        'since: ${since.toIso8601String().substring(0, 10)})',
      );
    } catch (e) {
      // Health sync is optional — never block app startup.
      debugPrint('HealthSyncEngine.syncWorkouts failed: $e');
    }
  }

  Future<void> _updateSyncAnchor(SharedPreferences prefs) async {
    try {
      await prefs.setString(
        StorageKeys.healthLastSyncDate,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }
}
