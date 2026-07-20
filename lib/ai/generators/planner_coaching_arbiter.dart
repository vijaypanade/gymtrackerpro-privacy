// lib/ai/generators/planner_coaching_arbiter.dart
//
// RFC-PLANNER-UX-001 — single arbiter for the Planner coaching slot.
//
// The Planner shows at most ONE coaching insight below the day header.
// This class owns the selection: critical-banner override, contradiction
// guard, confidence floor, snooze filter, and candidate priority.
//
// Responsibility split (mirrors SessionProphecyGenerator):
//   AppProvider.plannerCoachingInsight — caching + snooze persistence
//   this class                         — selection + trust rules
//   _CoachingSlot / InsightCard        — presentation only

import '../maturity/claim_category.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import 'session_prophecy_generator.dart';

/// Which banner occupies the top contextual slot. Moved out of
/// planner_screen.dart so the banner slot and the coaching arbiter read the
/// SAME decision — Amendment 3: critical banner always overrides coaching.
enum PlannerBannerType {
  overtraining, injury, comeback, recoveryDirective, adaptive, newWeek, ai;

  /// Banners that suppress the coaching slot entirely. [newWeek] and [ai]
  /// are informational/idle — coaching may coexist with them.
  bool get isCritical => switch (this) {
    overtraining || injury || comeback || recoveryDirective || adaptive => true,
    newWeek || ai => false,
  };
}

enum CoachingInsightType { weeklyAdjustment, prophecy, recoveryObservation }

/// Presentation contract for the coaching slot. All fields display-ready.
class PlannerCoachingInsight {
  final CoachingInsightType type;
  /// Collapsed one-liner.
  final String title;
  /// Expanded detail (unused for prophecy — SessionProphecyCard renders it).
  final String body;
  /// Normalized 0.0–1.0. Always >= [PlannerCoachingArbiter.kMinConfidence].
  final double confidence;
  /// Stable identity for snoozing, e.g. 'weeklyAdjustment:shiftFrequency'.
  final String snoozeKey;
  final ClaimCategory claimCategory;
  /// Non-null only when [type] == [CoachingInsightType.prophecy].
  final ProphecyData? prophecy;

  const PlannerCoachingInsight({
    required this.type,
    required this.title,
    required this.body,
    required this.confidence,
    required this.snoozeKey,
    required this.claimCategory,
    this.prophecy,
  });
}

class PlannerCoachingArbiter {
  /// Amendment 2 — coaching renders only above this confidence. Single
  /// definition; no other threshold may gate the coaching slot.
  static const double kMinConfidence = 0.55;

  const PlannerCoachingArbiter();

  /// Returns the single coaching insight for today's plan, or null → the
  /// slot renders nothing. Candidates are tried in priority order
  /// (actionable > predictive > observational); a candidate that fails the
  /// confidence floor or is snoozed falls through to the next.
  PlannerCoachingInsight? select({
    required AppProvider ap,
    required DayPlan day,
    required Set<String> snoozedToday,
  }) {
    // Amendment 3 — critical banner overrides coaching entirely.
    if (ap.activePlannerBanner.isCritical) return null;

    final overall = ap.brainCardData.confidencePct / 100.0;

    // 1. Weekly adjustment — most actionable, wins when present.
    final adj = ap.topWeeklyAdjustment;
    if (adj != null && overall >= kMinConfidence) {
      final key = 'weeklyAdjustment:${adj.type.name}';
      if (!snoozedToday.contains(key)) {
        return PlannerCoachingInsight(
          type:          CoachingInsightType.weeklyAdjustment,
          title:         adj.title,
          body:          adj.athleteFacingMessage,
          confidence:    overall,
          snoozeKey:     key,
          claimCategory: ClaimCategory.prescription,
        );
      }
    }

    // 2. Session prophecy — Predictive phase only (Step 9 gate unchanged).
    if (ap.aiMaturity.allowedClaims.ui.canShowSessionProphecy) {
      final pd = const SessionProphecyGenerator().generate(
        ap: ap, day: day, lang: ap.aiMaturity.languageProfile,
      );
      if (pd != null && pd.confidence / 100.0 >= kMinConfidence) {
        final key = 'prophecy:${pd.ex.baseId}';
        if (!snoozedToday.contains(key)) {
          return PlannerCoachingInsight(
            type:          CoachingInsightType.prophecy,
            title:         'Session projection — ${pd.ex.name}',
            body:          '',
            confidence:    pd.confidence / 100.0,
            snoozeKey:     key,
            claimCategory: pd.claimCategory,
            prophecy:      pd,
          );
        }
      }
    }

    // 3. Recovery observation — contradiction guard: never show a
    // "lighter day" note while an elevated-intensity directive is active.
    final msg = ap.recoveryAlignedMessage;
    if (msg.isNotEmpty &&
        ap.trainingAdjustment.intensityMultiplier <= 1.0 &&
        overall >= kMinConfidence) {
      const key = 'recoveryObservation';
      if (!snoozedToday.contains(key)) {
        return PlannerCoachingInsight(
          type:          CoachingInsightType.recoveryObservation,
          title:         'Recovery note',
          body:          msg,
          confidence:    overall,
          snoozeKey:     key,
          claimCategory: ClaimCategory.observation,
        );
      }
    }

    return null; // No filler — nothing worth saying, nothing rendered.
  }
}
