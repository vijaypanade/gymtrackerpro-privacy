// lib/coach/models/coach_message.dart
//
// BrainCoachMessage — immutable output of CoachBrainService.generate().
// All fields are required; there are no nullable outputs.

import 'package:flutter/foundation.dart';

import 'coach_intent.dart';
import 'coach_mode.dart';

@immutable
class BrainCoachMessage {
  /// Short headline the athlete reads first. Max ~40 chars.
  final String title;

  /// One-sentence expansion. Explains the reason without jargon.
  final String subtitle;

  /// Label for the primary CTA button or action chip.
  final String primaryAction;

  /// Emotional register of the message (motivate, protect, celebrate, …).
  final CoachMode tone;

  /// What the message is trying to accomplish.
  final CoachIntent intent;

  /// Urgency rank 1–5. 5 = highest urgency (e.g., deload required).
  /// Used by the UI to decide surface prominence.
  final int priority;

  /// True when this message carries a safety or overtraining warning.
  final bool hasWarning;

  /// True when this message is celebrating an achievement.
  final bool isCelebration;

  /// True when produced before any workout history exists.
  /// The UI renders a welcome/onboarding coaching card instead of the
  /// normal mission-aligned coaching card.
  final bool isOnboarding;

  const BrainCoachMessage({
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    required this.tone,
    required this.intent,
    required this.priority,
    required this.hasWarning,
    required this.isCelebration,
    this.isOnboarding = false,
  }) : assert(priority >= 1 && priority <= 5,
            'priority must be in [1, 5]');

  /// Safe onboarding state — 0 workouts, no history.
  static const BrainCoachMessage onboarding = BrainCoachMessage(
    title:         'Welcome to LiftOn',
    subtitle:      "Today's goal isn't intensity. Today's goal is showing up. "
                   'Complete your first workout to activate your coach.',
    primaryAction: 'Start First Workout',
    tone:          CoachMode.guide,
    intent:        CoachIntent.reinforceIdentity,
    priority:      1,
    hasWarning:    false,
    isCelebration: false,
    isOnboarding:  true,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BrainCoachMessage) return false;
    return other.title         == title         &&
           other.subtitle      == subtitle      &&
           other.primaryAction == primaryAction &&
           other.tone          == tone          &&
           other.intent        == intent        &&
           other.priority      == priority      &&
           other.hasWarning    == hasWarning    &&
           other.isCelebration == isCelebration &&
           other.isOnboarding  == isOnboarding;
  }

  @override
  int get hashCode => Object.hash(
    title, subtitle, primaryAction, tone, intent,
    priority, hasWarning, isCelebration, isOnboarding,
  );

  @override
  String toString() =>
      'BrainCoachMessage(priority:$priority tone:${tone.label} '
      'intent:${intent.label} warning:$hasWarning celebrate:$isCelebration '
      'title:"$title")';
}
