// lib/utils/recovery_grid_data.dart
// Single source of truth for muscle recovery grid configuration.
// Used by stats_screen.dart — do NOT duplicate.
import 'package:flutter/material.dart';

class MuscleGridEntry {
  final String key;
  final String label;
  final String svgAsset;
  final IconData icon;
  const MuscleGridEntry({
    required this.key,
    required this.label,
    required this.svgAsset,
    required this.icon,
  });
}

class RecoveryGridData {
  RecoveryGridData._();

  static const List<MuscleGridEntry> muscles = [
    MuscleGridEntry(key: 'chest',     label: 'Chest',     svgAsset: 'assets/icons/chest.svg',     icon: Icons.expand_rounded),
    MuscleGridEntry(key: 'back',      label: 'Back',      svgAsset: 'assets/icons/back.svg',      icon: Icons.open_with_rounded),
    MuscleGridEntry(key: 'legs',      label: 'Legs',      svgAsset: 'assets/icons/legs.svg',      icon: Icons.directions_run_rounded),
    MuscleGridEntry(key: 'shoulders', label: 'Shoulders', svgAsset: 'assets/icons/shoulders.svg', icon: Icons.arrow_upward_rounded),
    MuscleGridEntry(key: 'biceps',    label: 'Biceps',    svgAsset: 'assets/icons/arms.svg',      icon: Icons.north_east_rounded),
    MuscleGridEntry(key: 'triceps',   label: 'Triceps',   svgAsset: 'assets/icons/arms.svg',      icon: Icons.south_east_rounded),
    MuscleGridEntry(key: 'core',      label: 'Core',      svgAsset: 'assets/icons/core.svg',      icon: Icons.crop_square_rounded),
  ];

  /// Shared GridView delegate — identical layout across home & stats screens.
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount:   2,
    mainAxisSpacing:  14,
    crossAxisSpacing: 14,
    mainAxisExtent:   132,
  );
}
