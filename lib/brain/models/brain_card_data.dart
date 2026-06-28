// lib/brain/models/brain_card_data.dart
//
// Immutable snapshot for the AthleteBrain Home Card.
// Computed by AppProvider; consumed by AthleteBrainCard widget.
// Structural equality prevents Selector rebuild storms.

import 'package:flutter/foundation.dart';
import '../policy/mission_selection_engine.dart';

export '../policy/mission_selection_engine.dart' show MissionType;

@immutable
class BrainCardData {
  final MissionType missionType;
  final String missionLabel;
  final int confidencePct;
  final String recommendation;
  final String confidenceNarrative;
  final List<String> dominantSignals;
  final String identityLabel;
  final int preferredDurationMinutes;
  final String recoveryLabel;
  final int recoveryScore;

  /// True when this snapshot was produced before the athlete has any workout
  /// history. The UI renders an aspirational onboarding state instead of
  /// mission intelligence.
  final bool isOnboarding;

  const BrainCardData({
    required this.missionType,
    required this.missionLabel,
    required this.confidencePct,
    required this.recommendation,
    required this.confidenceNarrative,
    required this.dominantSignals,
    required this.identityLabel,
    required this.preferredDurationMinutes,
    required this.recoveryLabel,
    required this.recoveryScore,
    this.isOnboarding = false,
  });

  /// Safe onboarding state — 0 workouts, no history.
  /// Returned by AppProvider when totalWorkouts == 0.
  static const BrainCardData onboarding = BrainCardData(
    missionType:             MissionType.maintainConsistency,
    missionLabel:            'First Workout',
    confidencePct:           0,
    recommendation:          'Complete your first workout to activate personalised intelligence.',
    confidenceNarrative:     'Building your athlete profile…',
    dominantSignals:         [],
    identityLabel:           'building foundation',
    preferredDurationMinutes: 45,
    recoveryLabel:           'Ready',
    recoveryScore:           100,
    isOnboarding:            true,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BrainCardData) return false;
    return other.missionType               == missionType &&
           other.confidencePct             == confidencePct &&
           other.recommendation            == recommendation &&
           other.confidenceNarrative       == confidenceNarrative &&
           other.identityLabel             == identityLabel &&
           other.preferredDurationMinutes  == preferredDurationMinutes &&
           other.recoveryLabel             == recoveryLabel &&
           other.recoveryScore             == recoveryScore &&
           other.isOnboarding              == isOnboarding &&
           _signalsEqual(other.dominantSignals, dominantSignals);
  }

  @override
  int get hashCode => Object.hash(
    missionType,
    confidencePct,
    recommendation,
    confidenceNarrative,
    identityLabel,
    preferredDurationMinutes,
    recoveryLabel,
    recoveryScore,
    isOnboarding,
    Object.hashAll(dominantSignals),
  );

  static bool _signalsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
