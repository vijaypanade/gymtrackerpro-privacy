// lib/ai/notifications/notification_message_builder.dart
//
// Pure Dart. No Flutter imports. No side effects.
// All notification wording decisions live here.

import '../maturity/ai_maturity_state.dart';
import 'notification_category.dart';

class NotificationMessage {
  final String title;
  final String body;
  final NotificationCategory category;

  const NotificationMessage({
    required this.title,
    required this.body,
    required this.category,
  });
}

class NotificationMessageBuilder {
  const NotificationMessageBuilder._();

  /// Builds the message for a MOMENTUM PROTECTION notification.
  ///
  /// 'You usually train around now.' is a PATTERN claim — requires
  /// [canMakePatternClaim]. Without it the builder falls back to a
  /// DATA-level reminder with no epistemic claim.
  static NotificationMessage momentumProtection({
    required int daysMissed,
    required int previousStreak,
    required int consistencyScore,
    required AIMaturityState aiMaturity,
  }) {
    if (daysMissed >= 4) {
      return const NotificationMessage(
        title:    'A few days off.',
        body:     'One session resets the rhythm.',
        category: NotificationCategory.consistency,
      );
    }
    if (previousStreak >= 7 && daysMissed >= 2) {
      return const NotificationMessage(
        title:    'Missed a couple of days.',
        body:     "Let's continue today.",
        category: NotificationCategory.consistency,
      );
    }
    if (consistencyScore >= 60 &&
        aiMaturity.allowedClaims.content.canMakePatternClaim) {
      return const NotificationMessage(
        title:    'You usually train around now.',
        body:     'A short session fits.',
        category: NotificationCategory.consistency,
      );
    }
    return const NotificationMessage(
      title:    'No session yet.',
      body:     'A short one counts.',
      category: NotificationCategory.reminder,
    );
  }

  /// Builds the message for a RECOVERY READY notification.
  ///
  /// - 'Good day to push.' is a prescription/increase claim; requires
  ///   [canShowAdaptiveIncrease]. Falls back to DATA-level body.
  /// - 'Recovery looks good.' is an observation; requires
  ///   [canMakeObservation]. Falls back to a DATA-level title.
  static NotificationMessage recoveryReady({
    required int readiness,
    required AIMaturityState aiMaturity,
  }) {
    final claims = aiMaturity.allowedClaims;
    if (readiness >= 5) {
      final body = claims.ui.canShowAdaptiveIncrease
          ? 'Good day to push.'
          : 'A session fits today.';
      return NotificationMessage(
        title:    'Fully recovered.',
        body:     body,
        category: NotificationCategory.recovery,
      );
    }
    // readiness == 4 (caller already filtered readiness < 4)
    final title = claims.content.canMakeObservation
        ? 'Recovery looks good.'
        : 'Ready to train.';
    return NotificationMessage(
      title:    title,
      body:     "Today's workout fits.",
      category: NotificationCategory.recovery,
    );
  }
}
