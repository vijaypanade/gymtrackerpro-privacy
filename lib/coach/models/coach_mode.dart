// lib/coach/models/coach_mode.dart
//
// CoachMode — the emotional register of a coaching message.
// Determines tone, visual treatment, and how the message is delivered.

enum CoachMode {
  /// Push the athlete toward a performance goal.
  motivate,

  /// Warn against overtraining or injury risk.
  protect,

  /// Recognize an achievement or positive milestone.
  celebrate,

  /// Provide directional advice for a decision.
  guide,

  /// Gentle, low-friction prompt to act.
  nudge,

  /// Explain reasoning or teach a training concept.
  educate,
}

extension CoachModeX on CoachMode {
  String get label {
    switch (this) {
      case CoachMode.motivate:  return 'Motivate';
      case CoachMode.protect:   return 'Protect';
      case CoachMode.celebrate: return 'Celebrate';
      case CoachMode.guide:     return 'Guide';
      case CoachMode.nudge:     return 'Nudge';
      case CoachMode.educate:   return 'Educate';
    }
  }
}
