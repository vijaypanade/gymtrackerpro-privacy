// lib/services/health_connect_service.dart
// Android Health Connect — steps + sleep only. V2.
// Graceful fallback on any error, unavailability, or denied permission.
// iOS: always returns HealthSnapshot.empty (no-op).

import 'dart:io';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class HealthSnapshot {
  final int    todaySteps;
  final int    yesterdaySteps;
  final double sleepHours;        // last night, hours. 0 = no data.
  final bool   isConnected;       // HC available and authorized
  final bool   hasSleepData;
  final bool   hasStepsData;
  final double? restingHeartRate; // bpm, most recent in last 24 h. null = no reading.
  final double  activeEnergyKcal; // kcal burned today from Apple Watch / HC. 0 = no data.
  final bool    hasRHR;
  final bool    hasActiveEnergy;
  final double? hrv;    // ms, overnight avg (iOS: SDNN, Android: RMSSD). null = no reading.
  final bool    hasHrv;

  const HealthSnapshot({
    required this.todaySteps,
    required this.yesterdaySteps,
    required this.sleepHours,
    required this.isConnected,
    required this.hasSleepData,
    required this.hasStepsData,
    this.restingHeartRate,
    this.activeEnergyKcal  = 0.0,
    this.hasRHR            = false,
    this.hasActiveEnergy   = false,
    this.hrv,
    this.hasHrv            = false,
  });

  static const HealthSnapshot empty = HealthSnapshot(
    todaySteps:     0,
    yesterdaySteps: 0,
    sleepHours:     0,
    isConnected:    false,
    hasSleepData:   false,
    hasStepsData:   false,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class HealthConnectService {
  HealthConnectService._();
  static final HealthConnectService instance = HealthConnectService._();

  // Permission request types — include both sleep subtypes so users see both
  // SLEEP_IN_BED is iOS-only — not available on Android Health Connect.
  // Use SLEEP_ASLEEP (stages) + SLEEP_SESSION (total duration) for Android.
  //
  // RFC-HC-BUG-001: HRV must be RMSSD here. SDNN is iOS-only — Health Connect
  // has no SDNN record type, and the plugin's hasPermissions/requestAuthorization
  // short-circuit to false on any type unknown to Android, which made the
  // Connected state permanently unreachable. Every type in this list MUST also
  // be declared in AndroidManifest.xml (android.permission.health.READ_*) —
  // hasPermissions requires ALL of them granted.
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  ];
  static const List<HealthDataAccess> _perms = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  final Health _health = Health();
  bool _initialized = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (!Platform.isAndroid) return false;
    try {
      await _health.configure();
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Availability ────────────────────────────────────────────────────────────

  Future<bool> isAvailable() async {
    if (!Platform.isAndroid || !_initialized) return false;
    try {
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid || !_initialized) return false;
    try {
      return (await _health.hasPermissions(_types, permissions: _perms)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the Health Connect permission dialog.
  /// Returns true if the user granted read access.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      return await _health.requestAuthorization(_types, permissions: _perms);
    } catch (_) {
      return false;
    }
  }

  /// Opens Health Connect app if installed, otherwise opens Play Store to install it.
  Future<void> openOrInstall() async {
    if (!Platform.isAndroid) return;
    final hcApp = Uri.parse('android-app://com.google.android.apps.healthdata');
    if (await canLaunchUrl(hcApp)) {
      await launchUrl(hcApp, mode: LaunchMode.externalApplication);
      return;
    }
    final store = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );
    if (await canLaunchUrl(store)) {
      await launchUrl(store, mode: LaunchMode.externalApplication);
    }
  }

  // ── Data fetch ──────────────────────────────────────────────────────────────

  /// Fetch today's steps + last night's sleep.
  /// Always returns a valid [HealthSnapshot] — never throws.
  ///
  /// NOTE: hasPermissions() on Android is unreliable — it can return false
  /// even after the user granted access. We skip that guard here and attempt
  /// the fetch directly; the health package surfaces auth errors as exceptions
  /// which are caught per-type below.
  Future<HealthSnapshot> fetchSnapshot() async {
    if (!Platform.isAndroid) return HealthSnapshot.empty;

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return HealthSnapshot.empty;
    }

    try {
      final available = await isAvailable();
      if (!available) return HealthSnapshot.empty;

      // Gate on explicit permission grant. hasPermissions() is unreliable
      // (can return false after grant), so treat null as "maybe granted" and
      // proceed; only block on an explicit false.
      final perms = await _health.hasPermissions(_types, permissions: _perms);
      if (perms == false) return HealthSnapshot.empty;

      final now           = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final yestMidnight  = todayMidnight.subtract(const Duration(days: 1));
      final sleepWinStart = yestMidnight.subtract(const Duration(hours: 4));
      final sleepWinEnd   = DateTime(now.year, now.month, now.day, 12, 0, 0);

      // ── Today steps ───────────────────────────────────────────────────────
      int todaySteps = 0;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: todayMidnight,
          endTime: now,
        );
        for (final p in _health.removeDuplicates(raw)) {
          todaySteps += (p.value as NumericHealthValue).numericValue.toInt();
        }
      } catch (_) {}

      // ── Yesterday steps ───────────────────────────────────────────────────
      int yestSteps = 0;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: yestMidnight,
          endTime: todayMidnight,
        );
        for (final p in _health.removeDuplicates(raw)) {
          yestSteps += (p.value as NumericHealthValue).numericValue.toInt();
        }
      } catch (_) {}

      // ── Sleep — SLEEP_ASLEEP first, fallback to SLEEP_IN_BED ─────────────
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

      // Fallback: SLEEP_SESSION captures the total sleep block (Samsung Health etc.)
      if (sleepHours == 0.0) {
        try {
          final raw = await _health.getHealthDataFromTypes(
            types: [HealthDataType.SLEEP_SESSION],
            startTime: sleepWinStart,
            endTime: sleepWinEnd,
          );
          for (final p in raw) {
            final mins = p.dateTo.difference(p.dateFrom).inMinutes;
            if (mins > 0) sleepHours += mins / 60.0;
          }
        } catch (_) {}
      }

      // ── Resting Heart Rate — most recent reading in last 24 h ────────────
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

      // ── Active Energy — cumulative kcal burned today ──────────────────────
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

      // ── HRV (RMSSD) — overnight average ──────────────────────────────────
      // Health Connect's only HRV record type is RMSSD (SDNN is iOS/HealthKit).
      // Android Health Connect populates this only on devices that record HRV.
      // Returns null gracefully on most phones without a compatible wearable.
      // NOTE: RMSSD values differ numerically from SDNN — the hrvBaseline EMA
      // is per-device local (SharedPreferences), so each platform stays
      // self-consistent. Do not sync baselines cross-device.
      double? hrv;
      try {
        final raw = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
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
}
