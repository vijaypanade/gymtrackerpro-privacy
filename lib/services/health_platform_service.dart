// lib/services/health_platform_service.dart
// Pure platform facade — routing only. Zero platform-specific logic here.
//
//   Android  →  HealthConnectService (unchanged, existing file)
//   iOS      →  HealthKitAdapter     (new file, symmetric pattern)
//
// Rules:
//   • No package:health calls inside this class.
//   • No HKHealthStore references here.
//   • No implementation — only dispatch to the correct delegate.
//
// Re-exports HealthSnapshot so callers only need one import.

import 'dart:io';
import 'package:health/health.dart';

import 'health_connect_service.dart';
import 'health_kit_adapter.dart';

export 'health_connect_service.dart' show HealthSnapshot;

class HealthPlatformService {
  HealthPlatformService._();
  static final HealthPlatformService instance = HealthPlatformService._();

  Future<bool> initialize() async {
    if (Platform.isAndroid) return HealthConnectService.instance.initialize();
    if (Platform.isIOS)     return HealthKitAdapter.instance.initialize();
    return false;
  }

  Future<bool> isAvailable() async {
    if (Platform.isAndroid) return HealthConnectService.instance.isAvailable();
    if (Platform.isIOS)     return HealthKitAdapter.instance.isAvailable();
    return false;
  }

  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) return HealthConnectService.instance.hasPermissions();
    if (Platform.isIOS)     return HealthKitAdapter.instance.hasPermissions();
    return false;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) return HealthConnectService.instance.requestPermissions();
    if (Platform.isIOS)     return HealthKitAdapter.instance.requestPermissions();
    return false;
  }

  Future<HealthSnapshot> fetchSnapshot() async {
    if (Platform.isAndroid) return HealthConnectService.instance.fetchSnapshot();
    if (Platform.isIOS)     return HealthKitAdapter.instance.fetchSnapshot();
    return HealthSnapshot.empty;
  }

  /// Opens the native health platform app (Health Connect on Android, Health on iOS).
  Future<void> openOrInstall() async {
    if (Platform.isAndroid) return HealthConnectService.instance.openOrInstall();
    if (Platform.isIOS)     return HealthKitAdapter.instance.openHealthApp();
  }

  // ── RFC-002.6B ────────────────────────────────────────────────────────────

  /// Fetch raw workout data points since [since].
  /// Android workout import is out of RFC-002.6 scope — returns [].
  /// iOS delegates to HealthKitAdapter which caps at 500 results per call.
  Future<List<HealthDataPoint>> fetchWorkouts({required DateTime since}) async {
    if (Platform.isIOS) return HealthKitAdapter.instance.fetchWorkouts(since: since);
    return [];
  }
}
