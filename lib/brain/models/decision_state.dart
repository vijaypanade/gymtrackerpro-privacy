// lib/brain/models/decision_state.dart
//
// AthleteBrain V1 normalized decision state scaffold.
// This model contains the normalized policy inputs for AthleteBrain.
// It intentionally contains no business logic, no policy rules, and no
// signal transformations beyond structural composition.

import '../../models/recovery_state.dart';
import '../../providers/analytics_provider.dart';
import '../../services/athlete_trend_service.dart';
import '../../services/adherence_intelligence_service.dart';
import '../../services/predictive_performance_service.dart';
import '../../services/training_adjustment_service.dart';
import '../../memory/snapshots/athlete_memory_snapshot.dart';
import 'environment_context.dart';
import 'workout_context.dart';

class DecisionState {
  final RecoveryState recoveryState;
  final AnalyticsSnapshot analyticsSnapshot;
  final PredictiveSnapshot predictiveSnapshot;
  final AthleteTrendSnapshot athleteTrend;
  final AdherenceProfile adherenceProfile;
  final TrainingAdjustment trainingAdjustment;
  final WorkoutContext workoutContext;
  final EnvironmentContext environmentContext;
  /// Long-term EMA memory snapshot carried through from DecisionContext.
  /// Available for future policy use; not consumed by AdaptiveProgrammingService.
  final AthleteMemorySnapshot? athleteMemorySnapshot;

  const DecisionState({
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
