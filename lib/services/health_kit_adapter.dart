// lib/services/health_kit_adapter.dart
// iOS HealthKit — metrics snapshot + workout import. V1.
//
// Symmetric counterpart to HealthConnectService (Android).
// Android: every method is a no-op / returns empty / false.
// HealthPlatformService routes to this adapter on iOS.
//
// OWNERSHIP POLICY (RFC-002.6, locked):
//   Imported workouts are immutable point-in-time snapshots.
//   Apple Health is the source of truth. LiftOn never propagates
//   edits or deletions from Apple Health to imported HistoryEntries.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

import 'health_connect_service.dart' show HealthSnapshot;

class HealthKitAdapter {
  HealthKitAdapter._();
  static final HealthKitAdapter instance = HealthKitAdapter._();

  // RFC-002.6A — metric types for the daily snapshot.
  // All confirmed present in dataTypeKeysIOS (health v12.2.1).
  static const List<HealthDataType> _snapshotTypes = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  // RFC-002.6B — workout import type.
  static const List<HealthDataType> _workoutTypes = [
    HealthDataType.WORKOUT,
  ];

  // Combined list shown to the user in the single system permission sheet.
  static final List<HealthDataType> _allTypes = [
    ..._snapshotTypes,
    ..._workoutTypes,
  ];
  static final List<HealthDataAccess> _allPerms =
      List.filled(_allTypes.length, HealthDataAccess.READ);

  final Health _health = Health();
  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (!Platform.isIOS) return false;
    try {
      await _health.configure(); // no-op on iOS; safe to call
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Availability ──────────────────────────────────────────────────────────

  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    // HealthKit is always present on real iOS devices.
    return true;
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  /// iOS HealthKit never reveals whether the user accepted or denied access.
  /// Returns true so _initHealthPlatform proceeds to attempt a fetch.
  /// fetchSnapshot() and fetchWorkouts() return empty if access was denied — safe.
  Future<bool> hasPermissions() async {
    if (!Platform.isIOS || !_initialized) return false;
    try {
      // null = undetermined (iOS platform limitation); treat as "proceed".
      // explicit false = definitely not authorized.
      final result = await _health.hasPermissions(_allTypes, permissions: _allPerms);
      return result != false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return false;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      return await _health.requestAuthorization(_allTypes, permissions: _allPerms);
    } catch (_) {
      return false;
    }
  }

  /// Opens the iOS Health app via URL scheme.
  Future<void> openHealthApp() async {
    if (!Platform.isIOS) return;
    final uri = Uri.parse('x-apple-health://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Metrics snapshot (RFC-002.6A) ─────────────────────────────────────────

  /// Fetch today's steps + last-night sleep. Always returns a valid
  /// [HealthSnapshot] — never throws. Returns [HealthSnapshot.empty] on
  /// any error, permission denial, or simulator without Health.
  Future<HealthSnapshot> fetchSnapshot() async {
    if (!Platform.isIOS) return HealthSnapshot.empty;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return HealthSnapshot.empty;
    }

    try {
      final now           = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final yestMidnight  = todayMidnight.subtract(const Duration(days: 1));
      final sleepWinStart = yestMidnight.subtract(const Duration(hours: 4));
      final sleepWinEnd   = DateTime(now.year, now.month, now.day, 12, 0, 0);

      // ── Steps — HKStatisticsQuery via getTotalStepsInInterval ─────────────
      // Summing raw STEPS samples double-counts: iPhone and Apple Watch each
      // record overlapping samples, and removeDuplicates() only strips exact
      // duplicates. getTotalStepsInInterval uses Apple's deduplicated
      // cumulative sum — the same number the Health app displays.
      int todaySteps = 0;
      try {
        todaySteps =
            await _health.getTotalStepsInInterval(todayMidnight, now) ?? 0;
      } catch (_) {}

      int yestSteps = 0;
      try {
        yestSteps = await _health.getTotalStepsInInterval(
                yestMidnight, todayMidnight) ?? 0;
      } catch (_) {}

      // ── Sleep — SLEEP_ASLEEP first, SLEEP_IN_BED fallback ─────────────────
      double sleepHours = 0.0;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: sleepWinStart,
          endTime: sleepWinEnd,
        );
        for (final p in raw) {
          final mins = p.dateTo.difference(p.dateFrom).inMinutes;
          if (mins > 0) sleepHours += mins / 60.0;
        }
      } catch (_) {}

      if (sleepHours == 0.0) {
        try {
          final raw = await _health.getHealthDataFromTypes(
            types: [HealthDataType.SLEEP_IN_BED],
            startTime: sleepWinStart,
            endTime: sleepWinEnd,
          );
          for (final p in raw) {
            final mins = p.dateTo.difference(p.dateFrom).inMinutes;
            if (mins > 0) sleepHours += mins / 60.0;
          }
        } catch (_) {}
      }

      // ── HRV (SDNN) — overnight average ────────────────────────────────────
      // Apple Watch records SDNN during sleep. Multiple samples per night are
      // averaged to a single nightly value. Use the same sleep window so readings
      // from partial naps earlier in the evening are included.
      double? hrv;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
          startTime: sleepWinStart,
          endTime: now,
        );
        if (raw.isNotEmpty) {
          final values = raw
              .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
              .where((v) => v > 0)
              .toList();
          if (values.isNotEmpty) {
            hrv = values.reduce((a, b) => a + b) / values.length;
          }
        }
      } catch (_) {}

      // ── Resting Heart Rate — most recent reading in last 24 h ─────────────
      // iOS records one RHR measurement per day (overnight). Query yestMidnight
      // to now to catch last night's reading even if today's hasn't recorded yet.
      double? restingHeartRate;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.RESTING_HEART_RATE],
          startTime: yestMidnight,
          endTime: now,
        );
        if (raw.isNotEmpty) {
          raw.sort((a, b) => b.dateTo.compareTo(a.dateTo));
          restingHeartRate =
              (raw.first.value as NumericHealthValue).numericValue.toDouble();
        }
      } catch (_) {}

      // ── Active Energy — cumulative kcal burned today ───────────────────────
      // Apple Watch is the authoritative source. removeDuplicates() strips any
      // overlap between Watch and iPhone motion samples.
      double activeEnergyKcal = 0.0;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: todayMidnight,
          endTime: now,
        );
        for (final p in _health.removeDuplicates(raw)) {
          activeEnergyKcal +=
              (p.value as NumericHealthValue).numericValue.toDouble();
        }
      } catch (_) {}

      return HealthSnapshot(
        todaySteps:       todaySteps,
        yesterdaySteps:   yestSteps,
        sleepHours:       sleepHours,
        isConnected:      true,
        hasSleepData:     sleepHours > 0,
        hasStepsData:     todaySteps > 0 || yestSteps > 0,
        restingHeartRate: restingHeartRate,
        activeEnergyKcal: activeEnergyKcal,
        hasRHR:           restingHeartRate != null,
        hasActiveEnergy:  activeEnergyKcal > 0,
        hrv:              hrv,
        hasHrv:           hrv != null,
      );
    } catch (_) {
      return HealthSnapshot.empty;
    }
  }

  // ── Workout import (RFC-002.6B) ───────────────────────────────────────────

  /// Fetch Apple Watch workouts since [since] (inclusive).
  /// Returns raw [HealthDataPoint]s — HealthMapper converts them to
  /// HealthWorkout?. Never throws. Bounded at 500 results per call to
  /// prevent memory pressure on large histories.
  Future<List<HealthDataPoint>> fetchWorkouts({required DateTime since}) async {
    if (!Platform.isIOS) return [];
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return [];
    }
    try {
      final raw = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: since,
        endTime: DateTime.now(),
      );
      final deduped = _health.removeDuplicates(raw);
      // Cap at 500 per sync to bound memory and Firestore writes per call.
      // HealthSyncEngine advances `since` if the cap is hit (pagination).
      return deduped.length > 500 ? deduped.sublist(0, 500) : deduped;
    } catch (e) {
      debugPrint('HealthKitAdapter.fetchWorkouts failed: $e');
      return [];
    }
  }
}
