// lib/ai/generators/session_prophecy_generator.dart
//
// SessionProphecyGenerator — single source of truth for prophecy trust,
// per-exercise data resolution, and claim classification.
//
// Render site (planner_screen.dart) gates on
// AppProvider.aiMaturity.allowedClaims.ui.canShowSessionProphecy before
// constructing SessionProphecyCard. This generator then applies a second
// belt-and-suspenders language-profile check and resolves the concrete
// per-exercise prediction data.

import '../maturity/claim_category.dart';
import '../maturity/language_profile.dart';
import '../../engines/pr_engine.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProphecyData — presentation contract between generator and widget.
//
// All fields are display-ready values. No maturity or trust logic may live
// here — the widget is a pure renderer of this struct.
// ─────────────────────────────────────────────────────────────────────────────

class ProphecyData {
  final PlannedExercise ex;
  final double predWeight;
  final int    predReps;
  final double prevBestWeight;
  final int    prevBestReps;
  /// Readiness-weighted confidence (45–92). Honest bounds — never 100%.
  final int    confidence;
  /// Always [ClaimCategory.prediction] — first production consumer of
  /// prediction claims in LiftOn.
  final ClaimCategory claimCategory;

  const ProphecyData({
    required this.ex,
    required this.predWeight,
    required this.predReps,
    required this.prevBestWeight,
    required this.prevBestReps,
    required this.confidence,
    required this.claimCategory,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionProphecyGenerator — owns trust and data resolution.
//
// Responsibility split:
//   planner_screen.dart  — UI gate (canShowSessionProphecy)
//   this class           — trust + data-sufficiency + claim classification
//   SessionProphecyCard  — presentation only
// ─────────────────────────────────────────────────────────────────────────────

class SessionProphecyGenerator {
  const SessionProphecyGenerator();

  /// Resolves a [ProphecyData] for [day] using [ap]'s exercise logs.
  ///
  /// [lang] must permit prediction language — guards against the edge case
  /// where [AllowedClaimsUi.canShowSessionProphecy] and
  /// [AllowedClaimsContent.canMakePrediction] differ in a future engine
  /// revision, even though both currently require Predictive phase.
  ///
  /// Returns null when no exercise has sufficient data (≥ 3 weighted logs).
  /// The ≥ 3 threshold is a per-exercise *data-sufficiency* guard, not an AI
  /// maturity threshold — it applies regardless of [lang] and must stay here.
  ProphecyData? generate({
    required AppProvider ap,
    required DayPlan day,
    required LanguageProfile lang,
  }) {
    if (!lang.canUsePredictionLanguage) return null;

    for (final ex in day.exercises) {
      if (!ex.isWeight) continue;
      final key  = ap.getKey(ex.baseId);
      final logs = ap.getLogsForExercise(key).where((l) => l.weight > 0).toList();
      if (logs.length < 3) continue;

      var best = logs.first;
      for (final l in logs) {
        if (l.weight > best.weight ||
            (l.weight == best.weight && l.reps > best.reps)) {
          best = l;
        }
      }
      if (best.weight <= 0) continue;

      final fb = calculateWorkoutFeedback(
        weight:             best.weight,
        reps:               best.reps,
        previousBestWeight: best.weight,
        previousBestReps:   best.reps,
        isBodyweight:       ex.isBodyweight,
        unit:               ex.unit,
      );
      if (fb.nextWeight <= 0) continue;

      final readiness   = ap.readinessScore.clamp(0.0, 100.0);
      final confidence  = (42 + readiness * 0.5).round().clamp(45, 92);

      return ProphecyData(
        ex:             ex,
        predWeight:     fb.nextWeight,
        predReps:       fb.nextReps,
        prevBestWeight: best.weight,
        prevBestReps:   best.reps,
        confidence:     confidence,
        claimCategory:  ClaimCategory.prediction,
      );
    }
    return null;
  }
}
