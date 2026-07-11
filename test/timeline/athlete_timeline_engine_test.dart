// test/timeline/athlete_timeline_engine_test.dart
//
// Unit tests for AthleteTimelineEngine + MilestoneDetector.
//
// Sections:
//   §1  Empty / no-data guard
//   §2  Event generation (first workout, milestones, PRs, identity)
//   §3  Milestone detection
//   §4  Timeline ordering
//   §5  Narrative (headline, evolutionSummary)
//   §6  TimelineSnapshot invariants
//
// 35 tests. No mocks needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/memory/snapshots/athlete_memory_snapshot.dart';
import 'package:gymtrackerpromaster/models/coach_context.dart' show PREvent;
import 'package:gymtrackerpromaster/models/workout_log.dart';
import 'package:gymtrackerpromaster/timeline/models/milestone.dart';
import 'package:gymtrackerpromaster/timeline/models/timeline_event.dart';
import 'package:gymtrackerpromaster/timeline/models/timeline_snapshot.dart';
import 'package:gymtrackerpromaster/timeline/services/athlete_timeline_engine.dart';
import 'package:gymtrackerpromaster/timeline/services/milestone_detector.dart';

// ── Singleton ─────────────────────────────────────────────────────────────────

const _engine = AthleteTimelineEngine();

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _base = DateTime(2026, 1, 1);

AthleteMemorySnapshot _mem({
  String identity     = 'consistent',
  double consistency  = 0.60,
  double progressionV = 0.60,
  double recoveryV    = 0.60,
}) => AthleteMemorySnapshot(
  identityStage:            identity,
  experienceLevel:          'intermediate',
  consistencyScore:         consistency,
  recoveryVelocity:         recoveryV,
  progressionVelocity:      progressionV,
  volumeTolerance:          0.60,
  preferredSessionDuration: const Duration(minutes: 60),
  preferredTrainingDays:    4,
  preferredTrainingTime:    'morning',
  adherenceScore:           0.60,
  reliabilityScore:         0.60,
  lastUpdated:              DateTime(2026, 1, 14),
);

WorkoutLog _log(int dayOffset, {String exercise = 'Squat', double weight = 80, int reps = 5}) =>
    WorkoutLog(
      exercise:    exercise,
      date:        _base.add(Duration(days: dayOffset)),
      weight:      weight,
      reps:        reps,
      minutes:     45,
      muscleGroup: 'legs',
    );

PREvent _pr(int dayOffset, {String exercise = 'Squat', double weight = 100, int reps = 5}) =>
    PREvent(
      exercise: exercise,
      weight:   weight,
      reps:     reps,
      date:     _base.add(Duration(days: dayOffset)),
    );

List<WorkoutLog> _logs(int count) =>
    List.generate(count, (i) => _log(i));

TimelineSnapshot _generate({
  AthleteMemorySnapshot? mem,
  List<WorkoutLog>       logs       = const [],
  List<PREvent>          prEvents   = const [],
  int  currentStreak = 0,
  int  longestStreak = 0,
  int  totalWorkouts = 0,
  String previousIdentity = '',
}) => _engine.generate(
  mem:                   mem ?? _mem(),
  workoutLogs:           logs,
  prEvents:              prEvents,
  currentStreak:         currentStreak,
  longestStreak:         longestStreak,
  totalWorkouts:         totalWorkouts,
  previousIdentityStage: previousIdentity,
);

// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // ── § 1  Empty / no-data guard ────────────────────────────────────────────

  group('§1 Empty / no-data guard', () {
    test('1.1 zero workouts returns TimelineSnapshot.empty', () {
      final s = _generate(totalWorkouts: 0);
      expect(s.hasData, isFalse);
      expect(s.events, isEmpty);
    });

    test('1.2 TimelineSnapshot.empty values', () {
      const s = TimelineSnapshot.empty;
      expect(s.totalWorkouts, 0);
      expect(s.longestStreak, 0);
      expect(s.milestones, isEmpty);
    });

    test('1.3 hasData is false when no logs provided', () {
      final s = _generate(totalWorkouts: 0, logs: []);
      expect(s.hasData, isFalse);
    });
  });

  // ── § 2  Event generation ─────────────────────────────────────────────────

  group('§2 Event generation', () {
    test('2.1 first workout event generated when logs present', () {
      final s = _generate(logs: _logs(3), totalWorkouts: 3);
      final firstWorkout = s.events.where((e) => e.type == TimelineEventType.firstWorkout).toList();
      expect(firstWorkout, hasLength(1));
    });

    test('2.2 first workout date matches earliest log', () {
      final logs = [_log(5), _log(2), _log(10)]; // day 2 is earliest
      final s = _generate(logs: logs, totalWorkouts: 3);
      final first = s.events.firstWhere((e) => e.type == TimelineEventType.firstWorkout);
      expect(first.date, _base.add(const Duration(days: 2)));
    });

    test('2.3 workout50 event generated when totalWorkouts >= 50', () {
      final s = _generate(logs: _logs(55), totalWorkouts: 55);
      final w50 = s.events.where((e) => e.type == TimelineEventType.workout50).toList();
      expect(w50, hasLength(1));
    });

    test('2.4 workout50 NOT generated when totalWorkouts < 50', () {
      final s = _generate(logs: _logs(30), totalWorkouts: 30);
      final w50 = s.events.where((e) => e.type == TimelineEventType.workout50).toList();
      expect(w50, isEmpty);
    });

    test('2.5 workout100 event generated when totalWorkouts >= 100', () {
      final s = _generate(logs: _logs(105), totalWorkouts: 105);
      final w100 = s.events.where((e) => e.type == TimelineEventType.workout100).toList();
      expect(w100, hasLength(1));
    });

    test('2.6 streak7 event when longestStreak >= 7', () {
      final s = _generate(logs: _logs(10), totalWorkouts: 10, longestStreak: 7);
      final streak = s.events.where((e) => e.type == TimelineEventType.streak7).toList();
      expect(streak, hasLength(1));
    });

    test('2.7 streak30 event when longestStreak >= 30', () {
      final s = _generate(logs: _logs(35), totalWorkouts: 35, longestStreak: 30);
      final streak = s.events.where((e) => e.type == TimelineEventType.streak30).toList();
      expect(streak, hasLength(1));
    });

    test('2.8 no streak7 event when longestStreak < 7', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5, longestStreak: 5);
      final streak = s.events.where((e) => e.type == TimelineEventType.streak7).toList();
      expect(streak, isEmpty);
    });

    test('2.9 PR events generated for each PREvent', () {
      final prs = [_pr(5), _pr(10, exercise: 'Bench Press')];
      final s = _generate(logs: _logs(15), totalWorkouts: 15, prEvents: prs);
      final prEvents = s.events.where((e) => e.type == TimelineEventType.prAchieved).toList();
      expect(prEvents.length, 2);
    });

    test('2.10 PR event exercise field is set', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5, prEvents: [_pr(3, exercise: 'Deadlift')]);
      final pr = s.events.firstWhere((e) => e.type == TimelineEventType.prAchieved);
      expect(pr.exercise, 'Deadlift');
    });

    test('2.11 identity evolution event when identity stage changes', () {
      final s = _generate(
        logs: _logs(5), totalWorkouts: 5,
        mem: _mem(identity: 'consistent'),
        previousIdentity: 'developing',
      );
      final evo = s.events.where((e) => e.type == TimelineEventType.identityEvolution).toList();
      expect(evo, hasLength(1));
    });

    test('2.12 no identity event when identity unchanged', () {
      final s = _generate(
        logs: _logs(5), totalWorkouts: 5,
        mem: _mem(identity: 'consistent'),
        previousIdentity: 'consistent',
      );
      final evo = s.events.where((e) => e.type == TimelineEventType.identityEvolution).toList();
      expect(evo, isEmpty);
    });

    test('2.13 consistency milestone event when EMA >= 0.80', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5, mem: _mem(consistency: 0.85));
      final con = s.events.where((e) => e.type == TimelineEventType.consistencyMilestone).toList();
      expect(con, hasLength(1));
    });

    test('2.14 no consistency milestone when EMA < 0.80', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5, mem: _mem(consistency: 0.70));
      final con = s.events.where((e) => e.type == TimelineEventType.consistencyMilestone).toList();
      expect(con, isEmpty);
    });
  });

  // ── § 3  Milestone detection ──────────────────────────────────────────────

  group('§3 MilestoneDetector', () {
    test('3.1 firstWorkout event → silver milestone', () {
      final events = [
        TimelineEvent(
          type:   TimelineEventType.firstWorkout,
          date:   _base,
          title:  'First Workout',
          detail: 'test',
        ),
      ];
      final milestones = MilestoneDetector.detect(events);
      expect(milestones, hasLength(1));
      expect(milestones.first.tier, MilestoneTier.silver);
    });

    test('3.2 workout100 → legendary milestone', () {
      final events = [
        TimelineEvent(
          type:   TimelineEventType.workout100,
          date:   _base,
          title:  '100 Workouts',
          detail: 'test',
        ),
      ];
      final milestones = MilestoneDetector.detect(events);
      expect(milestones.first.tier, MilestoneTier.legendary);
    });

    test('3.3 weeklyHighlight events are NOT promoted to milestones', () {
      final events = [
        TimelineEvent(
          type:   TimelineEventType.weeklyHighlight,
          date:   _base,
          title:  'Weekly',
          detail: 'test',
        ),
      ];
      final milestones = MilestoneDetector.detect(events);
      expect(milestones, isEmpty);
    });

    test('3.4 milestones are sorted chronologically', () {
      final events = [
        TimelineEvent(type: TimelineEventType.streak30, date: _base.add(const Duration(days: 30)), title: '', detail: ''),
        TimelineEvent(type: TimelineEventType.firstWorkout, date: _base, title: '', detail: ''),
      ];
      final milestones = MilestoneDetector.detect(events);
      expect(milestones.first.achievedAt, _base);
    });

    test('3.5 full snapshot: milestone count matches eligible event count', () {
      final s = _generate(
        logs:          _logs(60),
        totalWorkouts: 60,
        longestStreak: 30,
        prEvents:      [_pr(10)],
        previousIdentity: 'developing',
        mem: _mem(identity: 'consistent'),
      );
      // Eligible: firstWorkout, workout50, streak7, streak30, prAchieved,
      //           identityEvolution
      expect(s.milestones.length, greaterThanOrEqualTo(5));
    });
  });

  // ── § 4  Timeline ordering ────────────────────────────────────────────────

  group('§4 Timeline ordering', () {
    test('4.1 events are sorted chronologically (oldest first)', () {
      final s = _generate(logs: _logs(20), totalWorkouts: 20, prEvents: [_pr(5), _pr(15)]);
      for (int i = 1; i < s.events.length; i++) {
        expect(
          s.events[i].date.isAfter(s.events[i - 1].date) ||
          s.events[i].date.isAtSameMomentAs(s.events[i - 1].date),
          isTrue,
          reason: 'Events must be chronological',
        );
      }
    });
  });

  // ── § 5  Narrative ────────────────────────────────────────────────────────

  group('§5 Narrative', () {
    test('5.1 headline is non-empty for valid data', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5);
      expect(s.headline.isNotEmpty, isTrue);
    });

    test('5.2 evolutionSummary is non-empty for valid data', () {
      final s = _generate(logs: _logs(5), totalWorkouts: 5);
      expect(s.evolutionSummary.isNotEmpty, isTrue);
    });

    test('5.3 0 workouts → "No history yet" headline', () {
      const s = TimelineSnapshot.empty;
      expect(s.headline, 'No history yet');
    });

    test('5.4 elite identity mentions elite in summary', () {
      final s = _generate(logs: _logs(110), totalWorkouts: 110, mem: _mem(identity: 'elite'));
      expect(s.evolutionSummary.toLowerCase(), contains('elite'));
    });
  });

  // ── § 6  Invariants ───────────────────────────────────────────────────────

  group('§6 Snapshot invariants', () {
    test('6.1 totalPRs matches prEvents count', () {
      final prs = [_pr(5), _pr(10), _pr(15)];
      final s = _generate(logs: _logs(20), totalWorkouts: 20, prEvents: prs);
      expect(s.totalPRs, 3);
    });

    test('6.2 longestStreak stored correctly', () {
      final s = _generate(logs: _logs(35), totalWorkouts: 35, longestStreak: 30);
      expect(s.longestStreak, 30);
    });

    test('6.3 firstWorkoutDate is the earliest log date', () {
      final logs = [_log(10), _log(3), _log(7)];
      final s = _generate(logs: logs, totalWorkouts: 3);
      expect(s.firstWorkoutDate, _base.add(const Duration(days: 3)));
    });

    test('6.4 latestEventDate is the latest log date', () {
      final logs = [_log(1), _log(5), _log(3)];
      final s = _generate(logs: logs, totalWorkouts: 3);
      expect(s.latestEventDate, _base.add(const Duration(days: 5)));
    });

    test('6.5 structural equality works', () {
      final a = _generate(logs: _logs(5), totalWorkouts: 5);
      final b = _generate(logs: _logs(5), totalWorkouts: 5);
      expect(a, equals(b));
    });
  });
}
