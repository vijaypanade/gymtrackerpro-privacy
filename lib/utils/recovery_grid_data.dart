// lib/utils/recovery_grid_data.dart
// Single source of truth for muscle recovery grid configuration.
// Used by home_screen.dart and stats_screen.dart — do NOT duplicate.
import 'package:flutter/material.dart';

class RecoveryGridData {
  RecoveryGridData._();

  static const List<Map<String, String>> muscles = [
    {'key': 'chest',     'label': 'Chest',    'emoji': '🏋️'},
    {'key': 'back',      'label': 'Back',     'emoji': '💪'},
    {'key': 'legs',      'label': 'Legs',     'emoji': '🦵'},
    {'key': 'shoulders', 'label': 'Shoulders','emoji': '📦'},
    {'key': 'arms',      'label': 'Arms',     'emoji': '💥'},
    {'key': 'core',      'label': 'Core',     'emoji': '🔥'},
  ];

  /// Shared GridView delegate — identical layout across home & stats screens.
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount:   3,
    mainAxisSpacing:  8,
    crossAxisSpacing: 8,
    mainAxisExtent:   100, // fixed height — no overflow regardless of screen size
  );
}
