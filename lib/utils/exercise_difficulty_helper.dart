// lib/utils/exercise_difficulty_helper.dart
// Infers exercise difficulty from equipment + movement + name heuristics.
// Purely deterministic — no network, no AI.

import 'package:flutter/material.dart';

enum ExerciseDifficulty { beginner, intermediate, advanced }

abstract final class ExerciseDifficultyHelper {
  // Names (lowercase substrings) that are Advanced regardless of equipment.
  static const _advancedNames = <String>{
    'conventional deadlift', 'sumo deadlift', 'trap bar deadlift',
    'barbell back squat', 'front squat', 'overhead squat',
    'barbell row', 'pendlay row',
    'power clean', 'hang clean', 'clean and jerk',
    'power snatch', 'hang snatch',
    'weighted dip',
  };

  // Names (lowercase substrings) forced to Beginner.
  static const _beginnerNames = <String>{
    'leg press', 'leg extension', 'leg curl',
    'chest press machine', 'pec deck', 'cable fly',
    'lat pulldown machine', 'seated row machine',
    'bicep curl machine', 'tricep pushdown',
  };

  static ExerciseDifficulty getDifficulty(Map<String, dynamic> exercise) {
    final name      = (exercise['name']      as String? ?? '').toLowerCase();
    final movement  = (exercise['movement']  as String? ?? '').toLowerCase();
    final equipment = (exercise['equipment'] as String? ?? '').toLowerCase();

    // Name-based overrides take priority.
    for (final kw in _advancedNames) {
      if (name.contains(kw)) return ExerciseDifficulty.advanced;
    }
    for (final kw in _beginnerNames) {
      if (name.contains(kw)) return ExerciseDifficulty.beginner;
    }

    // Structural rules.
    final isCompound  = movement == 'compound';
    final isBarbell   = equipment == 'barbell';
    final isMachine   = equipment == 'machine';
    final isBodyweight = equipment == 'bodyweight';
    final isDumbbell  = equipment == 'dumbbell';

    if (isBarbell && isCompound) return ExerciseDifficulty.advanced;

    if ((isMachine || isBodyweight || isDumbbell) && !isCompound) {
      return ExerciseDifficulty.beginner;
    }

    return ExerciseDifficulty.intermediate;
  }

  static String label(ExerciseDifficulty d) => switch (d) {
    ExerciseDifficulty.beginner     => 'Beginner',
    ExerciseDifficulty.intermediate => 'Intermediate',
    ExerciseDifficulty.advanced     => 'Advanced',
  };

  static Color color(ExerciseDifficulty d) => switch (d) {
    ExerciseDifficulty.beginner     => const Color(0xFF30D158),
    ExerciseDifficulty.intermediate => const Color(0xFFFF9F0A),
    ExerciseDifficulty.advanced     => const Color(0xFFFF6232),
  };
}
