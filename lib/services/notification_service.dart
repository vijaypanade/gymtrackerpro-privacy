// lib/services/notification_service.dart
// ══════════════════════════════════════════════════════════
// Push notifications using flutter_local_notifications
//
// SETUP:
// 1. pubspec.yaml: flutter_local_notifications: ^17.2.3
// 2. android/app/src/main/AndroidManifest.xml — add:
//    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//
// NOTIFICATION TYPES:
//   - Streak at risk    → fires at 8PM if no workout logged
//   - Inactivity alert  → fires after 3 days no workout
//   - Weekly summary    → fires every Sunday 9AM
// ══════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart'    as tz;

// Notification IDs — must be unique per type
class NotifIds {
  static const streakRisk      = 1001;
  static const inactivity      = 1002;
  static const weeklySummary   = 1003;
  static const prCelebration   = 1004;
  static const missionReminder = 1005;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS     = DarwinInitializationSettings(
      requestAlertPermission:  true,
      requestBadgePermission:  true,
      requestSoundPermission:  true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Request Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  void _onTap(NotificationResponse response) {
    // TODO: Navigate to relevant screen based on payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ─────────────────────────────────────────────────────────
  // STREAK AT RISK — fires at 8PM if no workout today
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleStreakReminder({
    required int    currentStreak,
    required bool   hasWorkedOutToday,
    required String userName,
  }) async {
    if (!_initialized) return;

    // Cancel existing
    await _plugin.cancel(NotifIds.streakRisk);

    // Don't schedule if already worked out
    if (hasWorkedOutToday) return;
    // Don't schedule for streak = 0 (no streak to protect)
    if (currentStreak == 0) return;

    final now  = DateTime.now();
    final fire = DateTime(now.year, now.month, now.day, 20, 0); // 8PM today

    // Already past 8PM → skip
    if (fire.isBefore(now)) return;

    String title = '🔥 $currentStreak-Day Streak at Risk!';
    String body;
    if (currentStreak >= 14) {
      body = '$userName, don\'t lose a $currentStreak-day streak. '
             'Even 20 minutes counts. Go!';
    } else if (currentStreak >= 7) {
      body = 'Your $currentStreak-day streak ends tonight if you skip. '
             'Quick workout?';
    } else {
      body = 'Keep the $currentStreak-day chain going. Train today!';
    }

    await _scheduleExact(
      id:      NotifIds.streakRisk,
      title:   title,
      body:    body,
      time:    fire,
      payload: 'streak_risk',
    );
  }

  // ─────────────────────────────────────────────────────────
  // INACTIVITY ALERT — fires after 3 days no workout
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleInactivityAlert({
    required DateTime lastWorkoutDate,
    required String   userName,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.inactivity);

    final daysSince  = DateTime.now().difference(lastWorkoutDate).inDays;
    if (daysSince >= 1) return; // Already inactive? Schedule for day 3

    final fire = lastWorkoutDate.add(const Duration(days: 3, hours: 9));
    if (fire.isBefore(DateTime.now())) return;

    await _scheduleExact(
      id:      NotifIds.inactivity,
      title:   '💪 Miss us, $userName?',
      body:    'You haven\'t trained in a while. '
               'Your gains are waiting — come back!',
      time:    fire,
      payload: 'inactivity',
    );
  }

  // ─────────────────────────────────────────────────────────
  // WEEKLY SUMMARY — every Sunday 9AM
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleWeeklySummary({
    required int    workoutsThisWeek,
    required double volumeThisWeek,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.weeklySummary);

    final now     = DateTime.now();
    final daysUntilSunday = (7 - now.weekday) % 7;
    final nextSunday = DateTime(
      now.year, now.month, now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      9, 0,
    );

    final String body;
    if (workoutsThisWeek >= 4) {
      body = '🔥 Amazing week! $workoutsThisWeek workouts, '
             '${volumeThisWeek.toStringAsFixed(0)}kg lifted. '
             'Ready to beat it next week?';
    } else if (workoutsThisWeek >= 2) {
      body = '💪 Solid week! $workoutsThisWeek workouts done. '
             'Next week, aim for ${workoutsThisWeek + 1}!';
    } else {
      body = '📅 New week, new chance. '
             'Let\'s aim for 4 workouts this week!';
    }

    await _scheduleExact(
      id:      NotifIds.weeklySummary,
      title:   '📊 Your Week in Review',
      body:    body,
      time:    nextSunday,
      payload: 'weekly_summary',
    );
  }

  // ─────────────────────────────────────────────────────────
  // IMMEDIATE NOTIFICATION — for PR celebrations
  // ─────────────────────────────────────────────────────────
  Future<void> showPRNotification({
    required String exerciseName,
    required double weight,
    required int    reps,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      NotifIds.prCelebration,
      '🏆 New PR — $exerciseName!',
      '${weight}kg × $reps reps — stronger than ever!',
      _notifDetails(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CANCEL ALL
  // ─────────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelStreakReminder() async {
    await _plugin.cancel(NotifIds.streakRisk);
  }

  // ─────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ─────────────────────────────────────────────────────────
  Future<void> _scheduleExact({
    required int    id,
    required String title,
    required String body,
    required DateTime time,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(time, tz.local),
        _notifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('_scheduleExact error: $e');
    }
  }

  NotificationDetails _notifDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'gymtracker_main',       // channel ID
      'GymTracker Pro',        // channel name
      channelDescription: 'Workout reminders and achievements',
      importance:  Importance.high,
      priority:    Priority.high,
      showWhen:    true,
      icon:        '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
