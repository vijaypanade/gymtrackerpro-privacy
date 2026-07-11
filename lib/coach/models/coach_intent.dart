// lib/coach/models/coach_intent.dart
//
// CoachIntent — what the coaching message is trying to accomplish.
// Orthogonal to CoachMode: the same intent can be delivered in different modes.

enum CoachIntent {
  /// Reinforce showing up and building the habit.
  encourageConsistency,

  /// Flag overreaching or overtraining risk.
  warnOvertraining,

  /// Acknowledge a personal record or breakthrough.
  celebratePR,

  /// Recommend rest, deload, or active recovery.
  suggestRecovery,

  /// Speak to the athlete's identity and long-term arc.
  reinforceIdentity,

  /// Motivate return after an absence.
  triggerComeback,

  /// Recognize a training volume or streak milestone.
  acknowledgeMilestone,

  /// Shift the athlete's attention toward a more productive focus.
  redirectFocus,
}

extension CoachIntentX on CoachIntent {
  String get label {
    switch (this) {
      case CoachIntent.encourageConsistency: return 'Encourage Consistency';
      case CoachIntent.warnOvertraining:     return 'Warn: Overtraining';
      case CoachIntent.celebratePR:          return 'Celebrate PR';
      case CoachIntent.suggestRecovery:      return 'Suggest Recovery';
      case CoachIntent.reinforceIdentity:    return 'Reinforce Identity';
      case CoachIntent.triggerComeback:      return 'Trigger Comeback';
      case CoachIntent.acknowledgeMilestone: return 'Acknowledge Milestone';
      case CoachIntent.redirectFocus:        return 'Redirect Focus';
    }
  }
}
