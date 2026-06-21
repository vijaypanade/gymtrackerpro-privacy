// lib/core/constants/app_icons.dart
// Central icon path registry — never hardcode asset paths elsewhere.
import 'package:flutter/material.dart';

abstract final class AppIcons {
  // ── Workout exercises ────────────────────────────────
  static const benchPress    = 'assets/icons/workouts/bench_press.svg';
  static const bicepCurl     = 'assets/icons/workouts/bicep_curl.svg';
  static const squat         = 'assets/icons/workouts/squat.svg';
  static const deadlift      = 'assets/icons/workouts/deadlift.svg';
  static const running       = 'assets/icons/workouts/running.svg';
  static const pushup        = 'assets/icons/workouts/pushup.svg';
  static const latPulldown   = 'assets/icons/workouts/lat_pulldown.svg';
  static const overheadPress = 'assets/icons/workouts/overhead_press.svg';
  static const plank         = 'assets/icons/workouts/plank.svg';
  static const row           = 'assets/icons/workouts/row.svg';
  static const coreWork      = 'assets/icons/workouts/core.svg';
  static const stretch       = 'assets/icons/workouts/stretch.svg';

  // ── Muscle groups ────────────────────────────────────
  static const chest     = 'assets/icons/chest.svg';
  static const back      = 'assets/icons/back.svg';
  static const legs      = 'assets/icons/legs.svg';
  static const shoulders = 'assets/icons/shoulders.svg';
  static const arms      = 'assets/icons/arms.svg';
  static const core      = 'assets/icons/core.svg';
  static const cardio    = 'assets/icons/cardio.svg';

  // ── Equipment ────────────────────────────────────────
  static const dumbbell = 'assets/icons/dumbbell.svg';
  static const barbell  = 'assets/icons/barbell.svg';
  static const machine  = 'assets/icons/machine.svg';
  static const bicycle  = 'assets/icons/bicycle.svg';

  // ── Features ─────────────────────────────────────────
  static const ai       = 'assets/icons/ai.svg';
  static const brain    = 'assets/icons/brain.svg';
  static const recovery = 'assets/icons/recovery.svg';
  static const streak   = 'assets/icons/streak.svg';
  static const target   = 'assets/icons/target.svg';
  static const flame    = 'assets/icons/flame.svg';
  static const person   = 'assets/icons/person.svg';
  static const personRun = 'assets/icons/person-simple-run.svg';
  static const heartbeat = 'assets/icons/heartbeat.svg';
  static const moon     = 'assets/icons/moon.svg';
  static const star     = 'assets/icons/star.svg';

  // ── Equipment → icon path lookup ─────────────────────
  static String forEquipment(String equipment) {
    switch (equipment.toLowerCase().trim()) {
      case 'barbell':   return barbell;
      case 'dumbbell':  return dumbbell;
      case 'machine':
      case 'cable':     return machine;
      case 'bicycle':   return bicycle;
      case 'cardio':    return running;
      default:          return dumbbell;
    }
  }

  // ── Rank → Material icon ─────────────────────────────
  static IconData rankIcon(int rankIndex) {
    switch (rankIndex) {
      case 0: return Icons.fitness_center_rounded;
      case 1: return Icons.bolt_rounded;
      case 2: return Icons.verified_rounded;
      case 3: return Icons.workspace_premium_rounded;
      case 4: return Icons.military_tech_rounded;
      case 5: return Icons.local_fire_department_rounded;
      default: return Icons.star_rounded;
    }
  }
}
