// lib/utils/id_helper.dart
//
// Centralized UUID + Random utilities. Providers should NOT carry their
// own Uuid/Random instances — use these singletons instead.
//
// USAGE:
//   final id = IdHelper.uuid();
//   final n  = IdHelper.randomInt(100);
//   final j  = IdHelper.jitter(3.0);

import 'dart:math';
import 'package:uuid/uuid.dart';

class IdHelper {
  IdHelper._();

  static const Uuid   _uuid   = Uuid();
  static final Random _random = Random();

  /// Generate a v4 UUID string.
  static String uuid() => _uuid.v4();

  /// Random int in [0, max).
  static int randomInt(int max) => _random.nextInt(max);

  /// Random double in [0.0, 1.0).
  static double randomDouble() => _random.nextDouble();

  /// Symmetric jitter in [-range, +range]. Used for human-like score variance.
  static double jitter(double range) =>
      (_random.nextDouble() * range * 2) - range;

  /// Pick one element at random; returns empty string for empty list.
  static String pickString(List<String> options) {
    if (options.isEmpty) return '';
    return options[_random.nextInt(options.length)];
  }

  /// Generic pick — null for empty list.
  static T? pick<T>(List<T> options) {
    if (options.isEmpty) return null;
    return options[_random.nextInt(options.length)];
  }
}
