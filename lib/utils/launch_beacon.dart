// lib/utils/launch_beacon.dart
// One-shot orientation signal: "user arrived at Planner from Home Today's Plan."
//
// Usage:
//   Home  →  LaunchBeacon.arm()   (after changeTab fires)
//   Planner  →  listen to LaunchBeacon.listenable
//
// The counter increments on every arm so ValueNotifier always fires
// even when tapped from Home multiple times in the same session.
// Nothing is persisted to disk.

import 'package:flutter/foundation.dart';

class LaunchBeacon {
  LaunchBeacon._();

  static final ValueNotifier<int> _counter = ValueNotifier(0);

  /// Subscribe to this in State.initState / dispose.
  static ValueListenable<int> get listenable => _counter;

  /// Called by Home card after changeTab(1). Each call fires listeners once.
  static void arm() => _counter.value++;
}
