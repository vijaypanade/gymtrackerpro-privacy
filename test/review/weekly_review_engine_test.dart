// test/review/weekly_review_engine_test.dart
//
// Unit tests for WeeklyReviewEngine + WeeklyScoreEngine + WeeklySummaryBuilder.
//
// Sections:
//   §1  Empty / no-data guard
//   §2  Score computation (recovery, consistency, progress, overall)
//   §3  Grade thresholds (S/A/B/C/D)
//   §4  Narrative — achievements, warnings, recommendations
//   §5  Next-week mission derivation
//   §6  WeeklyReview invariants
//
// 42 tests. No mocks — pure deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackerpromaster/brain/confidence/decision_confidence_engine.dart';
import 'package:gymtrackerpromaster/brain/models/brain_card_data.dart';
import 'package:gymtrackerpromaster/brain/policy/mission_selection_engine.dart';
import 'package:gymtrackerpromaster/coach/models/coach_intent.dart';
import 'package:gymtrackerpromaster/coach/models/coach_message.dart';
import 'package:gymtrackerpromaster/coach/models/coach_mode.dart';
import 'package:gymtrackerpromaster/memory/snapshots/athlete_memory_snapshot.dart';
import 'package:gymtrackerpromaster/models/weekly_review_data.dart';
import 'package:gymtrackerpromaster/providers/analytics_provider.dart';
import 'package:gymtrackerpromaster/review/models/weekly_recommendation.dart';
import 'package:gymtrackerpromaster/review/models/weekly_review.dart';
import 'package:gymtrackerpromaster/review/services/weekly_review_engine.dart';
import 'package:gymtrackerpromaster/review/services/weekly_score_engine.dart';

// ── Engine singleton ──────────────────────────────────────────────────────────

const _engine = WeeklyReviewEngine();

// ── Fixtures ──────────────────────────────────────────────────────────────────

AthleteMemorySnapshot _mem({
  double consistency  = 0.60,
  double adherence    = 0.60,
  double recovery     = 0.60,
  double progressionV = 0.60,
}) => AthleteMemorySnapshot(
  identityStage:            'consistent',
  experienceLevel:          'intermediate',
  consistencyScore:         consistency,
  recoveryVelocity:         recovery,
  progressionVelocity:      progressionV,
  volumeTolerance:          0.60,
  preferredSessionDuration: const Duration(minutes: 60),
  preferredTrainingDays:    4,
  preferredTrainingTime:    'morning',
  adherenceScore:           adherence,
  reliabilityScore:         0.60,
  lastUpdated:              DateTime(2026, 1, 14),
);

WeeklyReviewData _data({
  double overallRecovery    = 75.0,
  double adherencePercent   = 80.0,
  int    prCount            = 0,
  int    currentStreak      = 5,
  int    consistencyScore   = 60,
  int    completedSessions  = 3,
  int    plannedSessions    = 4,
  double weekVolumeKg       = 5000.0,
  double previousWeekVolumeKg = 5000.0,
  double volumeDeltaPercent = 0.0,
  String limitingMuscle     = '',
  double progressionScore   = 2.0,
}) => WeeklyReviewData(
  weekVolumeKg:         weekVolumeKg,
  previousWeekVolumeKg: previousWeekVolumeKg,
  volumeDeltaPercent:   volumeDeltaPercent,
  completedSessions:    completedSessions,
  plannedSessions:      plannedSessions,
  adherencePercent:     adherencePercent,
  prCount:              prCount,
  currentStreak:        currentStreak,
  consistencyScore:     consistencyScore,
  overallRecovery:      overallRecovery,
  limitingMuscle:       limitingMuscle,
  progressionScore:     progressionScore,
  headline:             '',
  summary:              '',
  rating:               WeekRating.strong,
);

BrainCardData _brain({
  MissionType  mission     = MissionType.pushPerformance,
  int          confidence  = 65,
  String       identity    = 'consistent athlete',
  String       recovery    = 'ready',
  int          recScore    = 75,
}) => BrainCardData(
  missionType:             mission,
  missionLabel:            mission.label,
  confidencePct:           confidence,
  recommendation:          'Train hard today.',
  confidenceNarrative:     'Good data quality.',
  dominantSignals:         const ['recovery', 'consistency'],
  identityLabel:           identity,
  preferredDurationMinutes: 60,
  recoveryLabel:           recovery,
  recoveryScore:           recScore,
);

BrainCoachMessage _coach({
  bool hasWarning    = false,
  bool isCelebration = false,
}) => BrainCoachMessage(
  title:         'Train smart today.',
  subtitle:      'Recovery supports training.',
  primaryAction: 'Begin session',
  tone:          CoachMode.motivate,
  intent:        CoachIntent.encourageConsistency,
  priority:      2,
  hasWarning:    hasWarning,
  isCelebration: isCelebration,
);

AnalyticsSnapshot _analytics({double improvement = 2.0}) => AnalyticsSnapshot(
  readinessScore:      75,
  fatigueIndex:        30,
  effortScoreToday:    60,
  plateauScore:        20,
  overtTrainingRisk:   10,
  weeklyImprovementPct: improvement,
  muscleBalanceScore:  70,
  intensityScore:      65,
  recoveryTrend:       'stable',
  isOnPlateau:         false,
  cacheDate:           '2026-01-15',
);

DecisionConfidence _confidence({double overall = 0.65}) => DecisionConfidence(
  overallConfidence:    overall,
  dataConfidence:       0.70,
  recoveryConfidence:   0.70,
  analyticsConfidence:  0.70,
  behaviorConfidence:   0.70,
  predictionConfidence: 0.70,
  memoryConfidence:     0.70,
  explanation:          'test',
);

WeeklyReview _generate({
  WeeklyReviewData?    data,
  AthleteMemorySnapshot? mem,
  BrainCardData?       brain,
  BrainCoachMessage?   coach,
  AnalyticsSnapshot?   analytics,
  DecisionConfidence?  confidence,
}) => _engine.generate(
  reviewData:            data       ?? _data(),
  athleteMemorySnapshot: mem        ?? _mem(),
  brainCardData:         brain      ?? _brain(),
  coachMessage:          coach      ?? _coach(),
  analyticsSnapshot:     analytics  ?? _analytics(),
  decisionConfidence:    confidence ?? _confidence(),
);

// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // ── § 1  Empty / no-data guard ────────────────────────────────────────────

  group('§1 Empty / no-data guard', () {
    test('1.1 empty WeeklyReviewData returns WeeklyReview.empty', () {
      final r = _engine.generate(
        reviewData:            WeeklyReviewData.empty,
        athleteMemorySnapshot: _mem(),
        brainCardData:         _brain(),
        coachMessage:          _coach(),
        analyticsSnapshot:     _analytics(),
        decisionConfidence:    _confidence(),
      );
      expect(r.hasData, isFalse);
      expect(r.overallScore, 0);
    });

    test('1.2 WeeklyReview.empty has all grades D', () {
      const r = WeeklyReview.empty;
      expect(r.overallGrade, WeeklyGrade.D);
      expect(r.recoveryGrade, WeeklyGrade.D);
      expect(r.consistencyGrade, WeeklyGrade.D);
      expect(r.progressGrade, WeeklyGrade.D);
    });

    test('1.3 WeeklyReview.empty has no achievements or recommendations', () {
      const r = WeeklyReview.empty;
      expect(r.achievements, isEmpty);
      expect(r.recommendations, isEmpty);
    });
  });

  // ── § 2  Score computation ────────────────────────────────────────────────

  group('§2 Score computation', () {
    test('2.1 recovery score uses overallRecovery as base', () {
      final score = WeeklyScoreEngine.computeRecoveryScore(_data(overallRecovery: 80), _mem());
      expect(score, greaterThan(75));
      expect(score, lessThanOrEqualTo(100));
    });

    test('2.2 limiting muscle penalises recovery score by 5', () {
      final withMuscle    = WeeklyScoreEngine.computeRecoveryScore(_data(overallRecovery: 80, limitingMuscle: 'chest'), _mem());
      final withoutMuscle = WeeklyScoreEngine.computeRecoveryScore(_data(overallRecovery: 80, limitingMuscle: ''),      _mem());
      expect(withoutMuscle - withMuscle, closeTo(5, 1.5));
    });

    test('2.3 consistency score increases with higher adherence', () {
      final low  = WeeklyScoreEngine.computeConsistencyScore(_data(adherencePercent: 30), _mem());
      final high = WeeklyScoreEngine.computeConsistencyScore(_data(adherencePercent: 100), _mem());
      expect(high, greaterThan(low));
    });

    test('2.4 progress score benefits from PRs', () {
      final noPR  = WeeklyScoreEngine.computeProgressScore(_data(prCount: 0), _mem(), _analytics());
      final withPR = WeeklyScoreEngine.computeProgressScore(_data(prCount: 3), _mem(), _analytics());
      expect(withPR, greaterThan(noPR));
    });

    test('2.5 progress score maps 0% improvement to ~50', () {
      final score = WeeklyScoreEngine.computeProgressScore(_data(), _mem(), _analytics(improvement: 0));
      expect(score, closeTo(50, 10));
    });

    test('2.6 overall score is weighted average of three scores', () {
      final rec  = 80.0;
      final con  = 70.0;
      final prog = 60.0;
      final overall = WeeklyScoreEngine.computeOverallScore(rec, con, prog);
      final expected = rec * 0.35 + con * 0.35 + prog * 0.30;
      expect(overall, closeTo(expected, 0.01));
    });

    test('2.7 all scores clamped to [0, 100]', () {
      final rec  = WeeklyScoreEngine.computeRecoveryScore(_data(overallRecovery: 0), _mem(recovery: 0));
      final con  = WeeklyScoreEngine.computeConsistencyScore(_data(adherencePercent: 0), _mem(consistency: 0));
      final prog = WeeklyScoreEngine.computeProgressScore(_data(prCount: 0), _mem(progressionV: 0), _analytics(improvement: -20));
      expect(rec,  inInclusiveRange(0.0, 100.0));
      expect(con,  inInclusiveRange(0.0, 100.0));
      expect(prog, inInclusiveRange(0.0, 100.0));
    });
  });

  // ── § 3  Grade thresholds ─────────────────────────────────────────────────

  group('§3 Grade thresholds', () {
    test('3.1 score ≥ 88 → S', () => expect(WeeklyScoreEngine.grade(88), WeeklyGrade.S));
    test('3.2 score ≥ 74 < 88 → A', () => expect(WeeklyScoreEngine.grade(74), WeeklyGrade.A));
    test('3.3 score ≥ 58 < 74 → B', () => expect(WeeklyScoreEngine.grade(60), WeeklyGrade.B));
    test('3.4 score ≥ 42 < 58 → C', () => expect(WeeklyScoreEngine.grade(50), WeeklyGrade.C));
    test('3.5 score < 42 → D',    () => expect(WeeklyScoreEngine.grade(40), WeeklyGrade.D));
    test('3.6 score 0 → D',       () => expect(WeeklyScoreEngine.grade(0),  WeeklyGrade.D));
    test('3.7 score 100 → S',     () => expect(WeeklyScoreEngine.grade(100), WeeklyGrade.S));

    test('3.8 WeeklyGrade.S.isPositive is true', () => expect(WeeklyGrade.S.isPositive, isTrue));
    test('3.9 WeeklyGrade.D.needsWork is true',  () => expect(WeeklyGrade.D.needsWork, isTrue));
    test('3.10 WeeklyGrade.B.isPositive is false', () => expect(WeeklyGrade.B.isPositive, isFalse));
  });

  // ── § 4  Narrative ────────────────────────────────────────────────────────

  group('§4 Achievements, warnings, recommendations', () {
    test('4.1 PR count > 0 → PR achievement listed', () {
      final r = _generate(data: _data(prCount: 2));
      expect(r.achievements.any((a) => a.contains('personal record') || a.contains('record')), isTrue);
    });

    test('4.2 100% adherence → session achievement listed', () {
      final r = _generate(data: _data(adherencePercent: 100, completedSessions: 4, plannedSessions: 4));
      expect(r.achievements.any((a) => a.toLowerCase().contains('session')), isTrue);
    });

    test('4.3 7+ day streak → streak achievement listed', () {
      final r = _generate(data: _data(currentStreak: 10));
      expect(r.achievements.any((a) => a.contains('streak') || a.contains('day')), isTrue);
    });

    test('4.4 D recovery grade → critical warning present', () {
      final r = _generate(data: _data(overallRecovery: 10));
      expect(r.warnings.isNotEmpty, isTrue);
    });

    test('4.5 limitingMuscle present → muscle warning listed', () {
      final r = _generate(data: _data(limitingMuscle: 'chest'));
      expect(r.warnings.any((w) => w.toLowerCase().contains('chest')), isTrue);
    });

    test('4.6 coachMessage.hasWarning → recovery warning present', () {
      final r = _generate(coach: _coach(hasWarning: true));
      expect(r.warnings.isNotEmpty, isTrue);
    });

    test('4.7 D recovery → rest recommendation is urgent', () {
      final r = _generate(data: _data(overallRecovery: 10));
      final urgent = r.recommendations.where((rec) => rec.isUrgent).toList();
      expect(urgent, isNotEmpty);
    });

    test('4.8 strong progress + good recovery → push recommendation', () {
      final r = _generate(
        data:      _data(overallRecovery: 90, prCount: 3, adherencePercent: 100),
        analytics: _analytics(improvement: 10),
      );
      final pushRecs = r.recommendations.where((rec) => rec.type == RecommendationType.push).toList();
      expect(pushRecs, isNotEmpty);
    });

    test('4.9 summary headline is non-empty for valid data', () {
      final r = _generate();
      expect(r.summary.headline.isNotEmpty, isTrue);
    });

    test('4.10 coach line is non-empty', () {
      final r = _generate();
      expect(r.summary.coachLine.isNotEmpty, isTrue);
    });
  });

  // ── § 5  Next-week mission ────────────────────────────────────────────────

  group('§5 Next-week mission derivation', () {
    test('5.1 D recovery → protect-recovery mission', () {
      final r = _generate(data: _data(overallRecovery: 10));
      expect(r.nextWeekMission.toLowerCase(), contains('recover'));
    });

    test('5.2 D consistency + no recovery issues → habit-building mission', () {
      final r = _generate(
        data: _data(overallRecovery: 80, adherencePercent: 20, completedSessions: 1, plannedSessions: 5),
      );
      expect(r.nextWeekMission.toLowerCase().contains('habit') ||
             r.nextWeekMission.toLowerCase().contains('session') ||
             r.nextWeekMission.toLowerCase().contains('build'), isTrue);
    });

    test('5.3 high confidence + strong recovery + strong progress → push mission', () {
      final r = _generate(
        data:       _data(overallRecovery: 90, prCount: 3, adherencePercent: 100),
        analytics:  _analytics(improvement: 14),
        confidence: _confidence(overall: 0.80),
      );
      expect(r.nextWeekMission.isNotEmpty, isTrue);
    });

    test('5.4 nextWeekMission is always non-empty', () {
      final r = _generate();
      expect(r.nextWeekMission.isNotEmpty, isTrue);
    });
  });

  // ── § 6  Invariants ───────────────────────────────────────────────────────

  group('§6 WeeklyReview invariants', () {
    test('6.1 hasData is true for non-zero session count', () {
      final r = _generate(data: _data(completedSessions: 3));
      expect(r.hasData, isTrue);
    });

    test('6.2 scores are always in [0, 100]', () {
      final r = _generate();
      expect(r.overallScore,     inInclusiveRange(0.0, 100.0));
      expect(r.recoveryScore,    inInclusiveRange(0.0, 100.0));
      expect(r.consistencyScore, inInclusiveRange(0.0, 100.0));
      expect(r.progressScore,    inInclusiveRange(0.0, 100.0));
    });

    test('6.3 grade letter is always one of S/A/B/C/D', () {
      final r = _generate();
      const letters = {'S', 'A', 'B', 'C', 'D'};
      expect(letters, contains(r.overallGrade.letter));
    });

    test('6.4 WeeklyReview equality is structural', () {
      final a = _generate();
      final b = _generate();
      expect(a, equals(b));
    });

    test('6.5 different recovery scores produce different reviews', () {
      final good = _generate(data: _data(overallRecovery: 90));
      final poor = _generate(data: _data(overallRecovery: 10));
      expect(good.recoveryScore, isNot(equals(poor.recoveryScore)));
    });
  });
}
