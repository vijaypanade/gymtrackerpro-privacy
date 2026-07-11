// lib/brain/models/decision_context.dart
//
// AthleteBrain V1 decision input contract scaffold.
// This context is composed from existing domain objects to keep the
// policy surface stable and future-proof. It contains no business logic.

import '../../services/athlete_trend_service.dart';
import '../../services/adherence_intelligence_service.dart';
import '../../services/predictive_performance_service.dart';
import '../../models/recovery_state.dart';
import '../../services/training_adjustment_service.dart';
import '../../providers/analytics_provider.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import 'environment_context.dart';
import 'workout_context.dart';

class DecisionContext {
  final RecoveryState recoveryState;
  final AnalyticsSnapshot analyticsSnapshot;
  final PredictiveSnapshot predictiveSnapshot;
  final AthleteTrendSnapshot athleteTrend;
  final AdherenceProfile adherenceProfile;
  final TrainingAdjustment trainingAdjustment;
  final WorkoutContext workoutContext;
  final EnvironmentContext environmentContext;
  /// Long-term EMA memory snapshot. Advisory only — does not alter
  /// AdaptiveProgrammingService outputs in this commit.
  final AthleteMemorySnapshot? athleteMemorySnapshot;

  const DecisionContext({
    required this.recoveryState,
    required this.analyticsSnapshot,
    required this.predictiveSnapshot,
    required this.athleteTrend,
    required this.adherenceProfile,
    required this.trainingAdjustment,
    required this.workoutContext,
    required this.environmentContext,
    this.athleteMemorySnapshot,
  });
}
