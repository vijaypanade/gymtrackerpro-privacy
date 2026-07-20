// lib/timeline/services/athlete_timeline_engine.dart
//
// AthleteTimelineEngine — builds a complete TimelineSnapshot from raw inputs.
//
// Inputs: AthleteMemorySnapshot, List<WorkoutLog>, List<PREvent>,
//         current streak, total workouts, longestStreak, weekly review outputs.
//
// Outputs: TimelineSnapshot — immutable, chronological, deterministic.
//
// Rules:
//   • Pure deterministic — same inputs always produce the same output.
//   • No AI. No Provider. No Firebase. No UI. No networking.
//   • Milestone detection is delegated to MilestoneDetector.
//   • Narrative text is delegated to TimelineSummaryBuilder.

import '../../memory/snapshots/athlete_memory_snapshot.dart';
import '../../models/coach_context.dart' show PREvent;
import '../../models/workout_log.dart';
import '../models/timeline_event.dart';
import '../models/timeline_snapshot.dart';
import 'milestone_detector.dart';
import 'timeline_summary_builder.dart';

class AthleteTimelineEngine {
  const AthleteTimelineEngine();

  static const _summaryBuilder = TimelineSummaryBuilder();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates a complete [TimelineSnapshot] from the provided data.
  ///
  /// Parameters:
  ///   [mem]            — long-term EMA athlete memory.
  ///   [workoutLogs]    — all logged workout sessions (any order).
  ///   [prEvents]       — all personal records ever set.
  ///   [currentStreak]  — current consecutive training day streak.
  ///   [longestStreak]  — all-time peak streak (days).
  ///   [totalWorkouts]  — all-time session count.
  ///   [previousIdentityStage] — the stage before the last evolution, or empty.
  TimelineSnapshot generate({
    required AthleteMemorySnapshot mem,
    required List<WorkoutLog> workoutLogs,
    required List<PREvent> prEvents,
    required int currentStreak,
    required int longestStreak,
    required int totalWorkouts,
    String previousIdentityStage = '',
  }) {
    if (totalWorkouts == 0 && workoutLogs.isEmpty) {
      return TimelineSnapshot.empty;
    }

    final events = <TimelineEvent>[];

    // ── 1. First workout ────────────────────────────────────────────────────
    final firstDate = _firstDate(workoutLogs);
    if (firstDate != null) {
      events.add(TimelineEvent(
        type:   TimelineEventType.firstWorkout,
        date:   firstDate,
        title:  'First Workout',
        detail: 'The journey begins — every elite athlete started here.',
      ));
    }

    // ── 2. Workout count milestones ─────────────────────────────────────────
    if (totalWorkouts >= 50) {
      final date50 = _approximateMilestoneDate(workoutLogs, 50);
      if (date50 != null) {
        events.add(TimelineEvent(
          type:   TimelineEventType.workout50,
          date:   date50,
          title:  '50 Workouts Completed',
          detail: 'Fifty sessions in — consistency is becoming second nature.',
          value:  50,
          valueUnit: 'sessions',
        ));
      }
    }

    if (totalWorkouts >= 100) {
      final date100 = _approximateMilestoneDate(workoutLogs, 100);
      if (date100 != null) {
        events.add(TimelineEvent(
          type:   TimelineEventType.workout100,
          date:   date100,
          title:  '100 Workouts Completed',
          detail: 'One hundred sessions. A true commitment to the process.',
          value:  100,
          valueUnit: 'sessions',
        ));
      }
    }

    // ── 3. Streak milestones ────────────────────────────────────────────────
    final streakRef = longestStreak > currentStreak ? longestStreak : currentStreak;

    if (streakRef >= 7) {
      // Use the most recent log date as a proxy since we do not store streak history.
      final latestDate = _latestDate(workoutLogs);
      if (latestDate != null) {
        events.add(TimelineEvent(
          type:      TimelineEventType.streak7,
          date:      latestDate,
          title:     '7-Day Streak',
          detail:    'Seven consecutive training days — the habit is real.',
          value:     7,
          valueUnit: 'days',
        ));
      }
    }

    if (streakRef >= 30) {
      final latestDate = _latestDate(workoutLogs);
      if (latestDate != null) {
        events.add(TimelineEvent(
          type:      TimelineEventType.streak30,
          date:      latestDate,
          title:     '30-Day Streak',
          detail:    'Thirty days without missing — elite discipline.',
          value:     30,
          valueUnit: 'days',
        ));
      }
    }

    // ── 4. Personal records ─────────────────────────────────────────────────
    for (final pr in prEvents) {
      events.add(TimelineEvent(
        type:      TimelineEventType.prAchieved,
        date:      pr.date,
        title:     'PR — ${pr.exercise}',
        detail:    pr.isRepPR
            ? '${pr.reps} reps @ ${_fmtKg(pr.weight)} (rep PR)'
            : '${_fmtKg(pr.weight)} × ${pr.reps} (weight PR)',
        value:     pr.weight,
        valueUnit: 'kg',
        exercise:  pr.exercise,
      ));
    }

    // ── 5. Identity evolution ───────────────────────────────────────────────
    if (previousIdentityStage.isNotEmpty &&
        previousIdentityStage != mem.identityStage) {
      final evolutionDate = _latestDate(workoutLogs) ?? DateTime.now();
      events.add(TimelineEvent(
        type:   TimelineEventType.identityEvolution,
        date:   evolutionDate,
        title:  'Identity Evolved: ${_stageLabel(mem.identityStage)}',
        detail: 'Your athlete identity advanced from '
            '${_stageLabel(previousIdentityStage)} to '
            '${_stageLabel(mem.identityStage)}.',
      ));
    }

    // ── 6. Consistency milestone ────────────────────────────────────────────
    if (mem.consistencyScore >= 0.80) {
      final latestDate = _latestDate(workoutLogs);
      if (latestDate != null) {
        events.add(TimelineEvent(
          type:      TimelineEventType.consistencyMilestone,
          date:      latestDate,
          title:     'Elite Consistency',
          detail:    'Your 30-day consistency EMA exceeded 80% — top-tier reliability.',
          value:     (mem.consistencyScore * 100).roundToDouble(),
          valueUnit: '%',
        ));
      }
    }

    // ── 7. Recovery improvement ─────────────────────────────────────────────
    if (mem.recoveryVelocity >= 0.75) {
      final latestDate = _latestDate(workoutLogs);
      if (latestDate != null) {
        events.add(TimelineEvent(
          type:   TimelineEventType.recoveryImprovement,
          date:   latestDate,
          title:  'Recovery Baseline Improved',
          detail: 'Long-term recovery velocity reached '
              '${(mem.recoveryVelocity * 100).round()}% — '
              'your body is adapting efficiently.',
          value:  (mem.recoveryVelocity * 100).roundToDouble(),
          valueUnit: '%',
        ));
      }
    }

    // ── 8. Weekly highlights ────────────────────────────────────────────────
    // (Caller can append WeeklyReview highlights as weeklyHighlight events.
    //  The engine does not read WeeklyReview directly to stay layer-clean.)

    // ── 9. Sort chronologically ─────────────────────────────────────────────
    events.sort((a, b) => a.date.compareTo(b.date));

    // ── 10. Detect milestones ───────────────────────────────────────────────
    final milestones = MilestoneDetector.detect(events);

    // ── 11. Narrative ────────────────────────────────────────────────────────
    final evolutionSummary = _summaryBuilder.buildEvolutionSummary(
      mem:            mem,
      totalWorkouts:  totalWorkouts,
      totalPRs:       prEvents.length,
      longestStreak:  longestStreak,
      milestones:     milestones,
    );

    final headline = _summaryBuilder.buildHeadline(
      totalWorkouts:        totalWorkouts,
      currentIdentityLabel: _stageLabel(mem.identityStage),
      milestones:           milestones,
      firstWorkoutDate:     firstDate,
    );

    // ── 12. Assemble ──────────────────────────────────────────────────────────
    return TimelineSnapshot(
      events:               events,
      milestones:           milestones,
      totalWorkouts:        totalWorkouts,
      longestStreak:        longestStreak,
      totalPRs:             prEvents.length,
      currentIdentityLabel: _stageLabel(mem.identityStage),
      evolutionSummary:     evolutionSummary,
      headline:             headline,
      firstWorkoutDate:     firstDate,
      latestEventDate:      _latestDate(workoutLogs),
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static String _fmtKg(double kg) =>
      kg == kg.truncateToDouble() ? '${kg.toInt()} kg' : '${kg.toStringAsFixed(1)} kg';

  DateTime? _firstDate(List<WorkoutLog> logs) {
    if (logs.isEmpty) return null;
    DateTime? earliest;
    for (final log in logs) {
      if (earliest == null || log.date.isBefore(earliest)) {
        earliest = log.date;
      }
    }
    return earliest;
  }

  DateTime? _latestDate(List<WorkoutLog> logs) {
    if (logs.isEmpty) return null;
    DateTime? latest;
    for (final log in logs) {
      if (latest == null || log.date.isAfter(latest)) {
        latest = log.date;
      }
    }
    return latest;
  }

  /// Approximate the date of the Nth session by indexing into a sorted log list.
  DateTime? _approximateMilestoneDate(List<WorkoutLog> logs, int sessionNumber) {
    if (logs.length < sessionNumber) return null;
    final sorted = logs.toList()..sort((a, b) => a.date.compareTo(b.date));
    return sorted[sessionNumber - 1].date;
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'elite':       return 'Elite Performer';
      case 'disciplined': return 'Disciplined Athlete';
      case 'consistent':  return 'Consistent Athlete';
      case 'developing':  return 'Developing Athlete';
      default:            return 'Building Foundation';
    }
  }
}
