import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();
  final _a = FirebaseAnalytics.instance;

  // Key events to track
  Future<void> planGenerated(String type) async =>
      await _a.logEvent(name: 'plan_generated', parameters: {'type': type});

  Future<void> workoutComplete(int duration, int xp) async =>
      await _a.logEvent(name: 'workout_complete',
          parameters: {'duration_min': duration, 'xp_earned': xp});

  Future<void> aiChatUsed() async =>
      await _a.logEvent(name: 'ai_chat_used');

  Future<void> paywallShown(String trigger) async =>
      await _a.logEvent(name: 'paywall_shown', parameters: {'trigger': trigger});

  Future<void> premiumPurchased() async =>
      await _a.logEvent(name: 'premium_purchased');

  Future<void> prAchieved(String exercise, double weight) async =>
      await _a.logEvent(name: 'pr_achieved',
          parameters: {'exercise': exercise, 'weight': weight});

  Future<void> setUserGoal(String goal) async =>
      await _a.setUserProperty(name: 'goal', value: goal);

  Future<void> setUserLevel(String level) async =>
      await _a.setUserProperty(name: 'level', value: level);
}
