// lib/services/connectivity_service.dart — Phase S1
// Thin wrapper around connectivity_plus 5.0.2.
// v5.0.2 emits ConnectivityResult (single, not List).
// Call ConnectivityService.instance.init() once at app startup.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _conn = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  // Broadcast stream of online/offline state changes.
  Stream<bool> get onlineStream => _conn.onConnectivityChanged.map((result) {
        _isOnline = result != ConnectivityResult.none;
        return _isOnline;
      });

  /// Call once at app startup to set the initial synchronous value.
  Future<void> init() async {
    try {
      final result = await _conn.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('ConnectivityService.init error: $e');
      _isOnline = true; // optimistic — better than false negative
    }
  }
}
