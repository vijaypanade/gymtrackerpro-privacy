// lib/services/observation_engine.dart
//
// Observation Engine — ONE reusable source of "the coach noticed something".
//
// Architecture contract:
//   • READ-ONLY. The engine owns no business logic and stores no athlete
//     data. It reads what AthleteMemoryService, ProteinIntelligenceService
//     and the workout providers already computed, and turns reliable
//     patterns into one calm sentence.
//   • Confidence-gated. Every observation type has a minimum evidence
//     threshold. Below it → the observation simply doesn't exist.
//     Silence is always better than fake personalization.
//   • Cooldown-gated. One observation id is never shown twice within
//     [cooldownDays]. The cooldown is consumed only when a surface
//     actually displays the observation (markSeen), never on compute.
//
// Consumers: Coach card (max one/day), Weekly Story (max one/story),
// Protein hub (existing behaviour, protein source), future surfaces.

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coach_context.dart' show PREvent;
import '../models/models.dart' show HistoryEntry, StreakData;
import '../models/workout_log.dart';
import 'athlete_memory_service.dart' show AthleteMemorySnapshot;
import 'protein_intelligence_service.dart' show ProteinMemory;

// ── Model ─────────────────────────────────────────────────────────────────────

/// What the engine noticed. One id ↔ one habit; text is the coach's sentence.
class Observation {
  /// Stable identity used for the cooldown ("strongest_lift:rows").
  final String id;

  /// One calm, observational sentence. Max two short clauses.
  final String text;

  /// Which system the evidence came from: workout | memory | protein.
  final String source;

  const Observation({
    required this.id,
    required this.text,
    required this.source,
  });
}

// ── Engine ────────────────────────────────────────────────────────────────────

class ObservationEngine {
  ObservationEngine._();

  static const int cooldownDays = 7;
  static const String _kPrefix = 'observation_seen_v1_';

  // Confidence gates — evidence minimums per observation type.
  static const int _minSessionsFavourite  = 8;
  static const int _minWorkoutsTimeOfDay  = 6;
  static const int _minLogsStrongestLift  = 5;
  static const int _minSessionsWeekday    = 6;
  static const int _minOnWeekday          = 3;
  static const int _minPRsForFrequency    = 3;
  static const int _minLogsTrainedMuscle  = 10;

  // ── Candidates — pure, synchronous, read-only ─────────────────────────────
  //
  // Ordered by how personal they feel: progression first, habits second,
  // frequency last. The picker takes the first candidate off cooldown.
  static List<Observation> candidates({
    required List<WorkoutLog>          logs,
    required List<HistoryEntry>        history,
    required StreakData                streak,
    required AthleteMemorySnapshot     memorySnapshot,
    ProteinMemory?                     proteinMemory,
    List<PREvent>                      recentPRs = const [],
  }) {
    final out = <Observation>[];

    // Strongest lift — needs a real progression trend AND enough exposures.
    final strongest = memorySnapshot.strongestMovements.isNotEmpty
        ? memorySnapshot.strongestMovements.first
        : '';
    if (strongest.isNotEmpty &&
        _logCountFor(logs, strongest) >= _minLogsStrongestLift) {
      out.add(Observation(
        id:     'strongest_lift:${_key(strongest)}',
        text:   '$strongest has become your strongest lift.',
        source: 'memory',
      ));
    }

    // Most improved lift — recent upward trend (last 60 days).
    final improved = memorySnapshot.progressionMovements.isNotEmpty
        ? memorySnapshot.progressionMovements.first
        : '';
    if (improved.isNotEmpty &&
        improved != strongest &&
        _logCountFor(logs, improved) >= _minLogsStrongestLift) {
      out.add(Observation(
        id:     'improved_lift:${_key(improved)}',
        text:   '$improved has improved a lot lately.',
        source: 'memory',
      ));
    }

    // PR frequency — records keep landing.
    final now = DateTime.now();
    final recentPRCount = recentPRs
        .where((p) => now.difference(p.date).inDays <= 30)
        .length;
    if (recentPRCount >= _minPRsForFrequency) {
      out.add(const Observation(
        id:     'pr_frequency',
        text:   'Records keep coming lately.',
        source: 'workout',
      ));
    }

    // Favourite exercise — most logged, with real volume of evidence.
    final favourite = memorySnapshot.favoriteExercises.isNotEmpty
        ? memorySnapshot.favoriteExercises.first
        : '';
    if (favourite.isNotEmpty &&
        favourite != strongest &&
        _logCountFor(logs, favourite) >= _minSessionsFavourite) {
      out.add(Observation(
        id:     'favourite_exercise:${_key(favourite)}',
        text:   '$favourite is your go-to lift.',
        source: 'memory',
      ));
    }

    // Most consistent workout day.
    final weekday = _consistentWeekday(history);
    if (weekday.isNotEmpty) {
      out.add(Observation(
        id:     'consistent_day:$weekday',
        text:   'You\'ve been consistent on ${weekday}s.',
        source: 'workout',
      ));
    }

    // Most consistent workout time.
    final timeOfDay = _consistentTimeOfDay(logs, streak);
    if (timeOfDay.isNotEmpty) {
      out.add(Observation(
        id:     'consistent_time:$timeOfDay',
        text:   'You usually train in the $timeOfDay.',
        source: 'workout',
      ));
    }

    // Most trained muscle.
    final muscle = _mostTrainedMuscle(logs);
    if (muscle.isNotEmpty) {
      out.add(Observation(
        id:     'trained_muscle:${_key(muscle)}',
        text:   '$muscle gets most of your attention.',
        source: 'workout',
      ));
    }

    // Most skipped exercise — planned but rarely logged (AthleteMemoryService
    // already applies the 30-day planned-vs-logged rule; each plan week is
    // several skipped opportunities, so one avoided entry clears the gate).
    final avoided = memorySnapshot.avoidedExercises.isNotEmpty
        ? memorySnapshot.avoidedExercises.first
        : '';
    if (avoided.isNotEmpty && streak.totalWorkouts >= _minSessionsFavourite) {
      out.add(Observation(
        id:     'skipped_exercise:${_key(avoided)}',
        text:   '$avoided keeps getting skipped. Swap it or keep it — your call.',
        source: 'memory',
      ));
    }

    // Protein habits — reuse ProteinIntelligence memory, never recompute.
    final pm = proteinMemory;
    if (pm != null && pm.hasSignal) {
      if (pm.consistentSource.isNotEmpty) {
        out.add(Observation(
          id:     'protein_consistent:${_key(pm.consistentSource)}',
          text:   '${pm.consistentSource} has been your most consistent protein.',
          source: 'protein',
        ));
      } else if (pm.finisherSource.isNotEmpty) {
        out.add(Observation(
          id:     'protein_finisher:${_key(pm.finisherSource)}',
          text:   'You usually finish the day with ${pm.finisherSource.toLowerCase()}.',
          source: 'protein',
        ));
      }
    }

    return out;
  }

  // ── Picker — first candidate whose cooldown window is open ────────────────

  static Future<Observation?> pick(List<Observation> candidates) async {
    if (candidates.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    for (final o in candidates) {
      final raw = prefs.getString('$_kPrefix${o.id}');
      final last = raw != null ? DateTime.tryParse(raw) : null;
      if (last == null || now.difference(last).inDays >= cooldownDays) {
        return o;
      }
    }
    return null;
  }

  /// Consume the cooldown — call ONLY after the observation reached the
  /// screen. Compute never consumes.
  static Future<void> markSeen(Observation o) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_kPrefix${o.id}', DateTime.now().toIso8601String());
  }

  // ── Derivations not owned by any existing system ──────────────────────────

  static int _logCountFor(List<WorkoutLog> logs, String exercise) {
    final k = _key(exercise);
    return logs.where((l) => _key(l.exercise) == k).length;
  }

  static String _consistentWeekday(List<HistoryEntry> history) {
    if (history.length < _minSessionsWeekday) return '';
    final counts = <int, int>{};
    for (final h in history) {
      final d = DateTime.tryParse(h.date);
      if (d == null) continue;
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value < _minOnWeekday) return '';
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
                   'Friday', 'Saturday', 'Sunday'];
    return names[best.key - 1];
  }

  static String _consistentTimeOfDay(List<WorkoutLog> logs, StreakData streak) {
    if (streak.totalWorkouts < _minWorkoutsTimeOfDay || logs.isEmpty) return '';
    int morning = 0, afternoon = 0, evening = 0;
    for (final l in logs) {
      final h = l.date.hour;
      if (h >= 5 && h < 12) {
        morning++;
      } else if (h >= 12 && h < 17) {
        afternoon++;
      } else {
        evening++;
      }
    }
    final total = morning + afternoon + evening;
    if (total < _minWorkoutsTimeOfDay) return '';
    // A time only counts as a habit when it clearly dominates.
    if (morning   > total * 0.6) return 'morning';
    if (afternoon > total * 0.6) return 'afternoon';
    if (evening   > total * 0.6) return 'evening';
    return '';
  }

  static String _mostTrainedMuscle(List<WorkoutLog> logs) {
    if (logs.length < _minLogsTrainedMuscle) return '';
    final counts = <String, int>{};
    for (final l in logs) {
      final m = (l.muscleGroup ?? '').trim();
      if (m.isEmpty) continue;
      counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value < _minLogsTrainedMuscle ~/ 2) return '';
    return best.key[0].toUpperCase() + best.key.substring(1);
  }

  static String _key(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
