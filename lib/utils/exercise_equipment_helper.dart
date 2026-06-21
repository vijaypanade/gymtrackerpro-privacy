// lib/utils/exercise_equipment_helper.dart
// Maps equipment strings → display label + Material icon.

import 'package:flutter/material.dart';

abstract final class ExerciseEquipmentHelper {
  static const _map = <String, ({String label, IconData icon})>{
    'barbell':    (label: 'Barbell',    icon: Icons.fitness_center),
    'dumbbell':   (label: 'Dumbbell',   icon: Icons.fitness_center),
    'cable':      (label: 'Cable',      icon: Icons.settings_input_component),
    'machine':    (label: 'Machine',    icon: Icons.precision_manufacturing),
    'bodyweight': (label: 'Bodyweight', icon: Icons.accessibility_new),
  };

  static String label(String equipment) {
    final key = equipment.toLowerCase().trim();
    return _map[key]?.label
        ?? (equipment.isEmpty ? '' : '${equipment[0].toUpperCase()}${equipment.substring(1)}');
  }

  static IconData icon(String equipment) =>
      _map[equipment.toLowerCase().trim()]?.icon ?? Icons.fitness_center;
}
