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
//   - Streak at risk       → fires at 8PM if no workout logged
//   - Streak milestone     → fires immediately on milestone hit
//   - Inactivity alert     → fires after 3 days no workout
//   - Weekly summary       → fires every Sunday 9AM
//   - PR celebration       → immediate on new personal record
//   - Recovery coach       → fires next morning if muscle < 50%
//   - Recovery ready       → fires morning after full recovery
// ══════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart'    as tz;

import '../ai/maturity/ai_maturity_state.dart';
import '../ai/notifications/notification_message_builder.dart';

// Notification IDs — must be unique per type
class NotifIds {
  static const streakRisk      = 1001;
  static const inactivity      = 1002;
  static const weeklySummary   = 1003;
  static const prCelebration   = 1004;
  static const missionReminder = 1005;
  static const recoveryCoach   = 1006;
  static const streakMilestone = 1007;
  static const recoveryReady   = 1008;
  static const momentumProtect = 1009;
  static const weeklyNarrative = 1010;
  static const silentDay5      = 2001;
  static const silentDay6      = 2002;
  static const silentDay7      = 2003;
}

// Streak milestone thresholds that warrant a dedicated notification
const _streakMilestones = [7, 14, 30, 60, 100];

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
    debugPrint('NotificationService initialized');
  }

  void _onTap(NotificationResponse response) {
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

    await _plugin.cancel(NotifIds.streakRisk);

    if (hasWorkedOutToday) return;
    if (currentStreak == 0) return;

    final now  = DateTime.now();
    final fire = DateTime(now.year, now.month, now.day, 20, 0);

    if (fire.isBefore(now)) return;

    final String title;
    final String body;

    if (currentStreak >= 7) {
      title = '$currentStreak days so far.';
      body  = 'A short session keeps it going.';
    } else {
      title = 'No session yet today.';
      body  = 'Twenty minutes is enough.';
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
  // STREAK MILESTONE — fires immediately when milestone hit
  // Use: call after workout save when streak crosses threshold
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleStreakMilestoneNotification({
    required int    streak,
    required String userName,
  }) async {
    if (!_initialized) return;
    if (!_streakMilestones.contains(streak)) return;

    final String title;
    final String body;

    switch (streak) {
      case 7:
        title = '7 days straight.';
        body  = 'A full week of training.';
      case 14:
        title = '14 days straight.';
        body  = 'Two weeks, unbroken.';
      case 30:
        title = '30 days straight.';
        body  = 'A full month of showing up.';
      case 60:
        title = '60 days straight.';
        body  = 'Two months. Steady work.';
      case 100:
        title = '100 days straight.';
        body  = 'One hundred sessions of showing up.';
      default:
        return;
    }

    // Show immediately (no scheduling delay needed)
    await _plugin.show(
      NotifIds.streakMilestone,
      title,
      body,
      _notifDetails(),
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

    final daysSince = DateTime.now().difference(lastWorkoutDate).inDays;
    if (daysSince > 3) return;

    final fire = lastWorkoutDate.add(const Duration(days: 3, hours: 9));
    if (fire.isBefore(DateTime.now())) return;

    await _scheduleExact(
      id:      NotifIds.inactivity,
      title:   'Three days off.',
      body:    'You\'re rested. A light session today works.',
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
      now.year, now.month,
      now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      9, 0,
    );

    final String title;
    final String body;

    if (workoutsThisWeek >= 4) {
      title = 'Strong week.';
      body  = '$workoutsThisWeek sessions, ${volumeThisWeek.toStringAsFixed(0)}kg lifted. Rest well.';
    } else if (workoutsThisWeek >= 2) {
      title = 'Week complete.';
      body  = '$workoutsThisWeek sessions logged.';
    } else {
      title = 'New week.';
      body  = 'One session starts it.';
    }

    await _scheduleExact(
      id:      NotifIds.weeklySummary,
      title:   title,
      body:    body,
      time:    nextSunday,
      payload: 'weekly_summary',
    );
  }

  // ─────────────────────────────────────────────────────────
  // PR CELEBRATION — immediate on new personal record
  // ─────────────────────────────────────────────────────────
  Future<void> showPRNotification({
    required String exerciseName,
    required double weight,
    required int    reps,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      NotifIds.prCelebration,
      'New record — $exerciseName.',
      '${weight}kg × $reps reps.',
      _notifDetails(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // RECOVERY COACH — fires next morning if a muscle < 50%
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleRecoveryCoach({
    required String lowestMuscle,
    required int    lowestScore,
    required String userName,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.recoveryCoach);

    if (lowestScore >= 50) return;

    final now  = DateTime.now();
    final fire = DateTime(now.year, now.month, now.day + 1, 7, 30);

    final muscle = lowestMuscle.isNotEmpty
        ? lowestMuscle[0].toUpperCase() + lowestMuscle.substring(1)
        : 'A muscle group';

    await _scheduleExact(
      id:      NotifIds.recoveryCoach,
      title:   '$muscle needs more time.',
      body:    'Train something else today.',
      time:    fire,
      payload: 'recovery_coach',
    );
  }

  // ─────────────────────────────────────────────────────────
  // RECOVERY READY — fires morning after full recovery
  // Use: when readiness score recovers above threshold after low day
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleRecoveryReadyNotification({
    required int             readiness,
    required AIMaturityState aiMaturity,
    required String          userName,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.recoveryReady);

    // Only surface when genuinely recovered (top two tiers)
    if (readiness < 4) return;

    final now  = DateTime.now();
    // Fire tomorrow 7AM — next morning wake-up
    final fire = DateTime(now.year, now.month, now.day + 1, 7, 0);

    final msg = NotificationMessageBuilder.recoveryReady(
      readiness:  readiness,
      aiMaturity: aiMaturity,
    );

    await _scheduleExact(
      id:      NotifIds.recoveryReady,
      title:   msg.title,
      body:    msg.body,
      time:    fire,
      payload: 'recovery_ready',
    );
  }

  // ─────────────────────────────────────────────────────────
  // MISSION REMINDER — fires 7AM on planned workout days
  // Use: schedule after plan is loaded or refreshed, for any
  // day that has exercises (not a rest day).
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleMissionReminder({
    required String planTitle,
    required String userName,
    required DateTime workoutDate,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.missionReminder);

    final fire = DateTime(
        workoutDate.year, workoutDate.month, workoutDate.day, 7, 0);
    if (fire.isBefore(DateTime.now())) return;

    final String title;
    final String body;

    if (planTitle.isNotEmpty) {
      title = '$planTitle today.';
      body  = 'The plan is ready.';
    } else {
      title = 'Training day.';
      body  = 'The session is ready when you are.';
    }

    await _scheduleExact(
      id:      NotifIds.missionReminder,
      title:   title,
      body:    body,
      time:    fire,
      payload: 'mission_reminder',
    );
  }

  // ─────────────────────────────────────────────────────────
  // MOMENTUM PROTECTION — fires mid-afternoon when score is at risk
  // Use: schedule after app open if daysSinceLastWorkout >= 2
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleMomentumProtection({
    required int              daysMissed,
    required int              previousStreak,
    required int              consistencyScore,
    required AIMaturityState  aiMaturity,
    required String           userName,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(NotifIds.momentumProtect);

    final now  = DateTime.now();
    final fire = DateTime(now.year, now.month, now.day, 15, 30);
    if (fire.isBefore(now)) return;

    final msg = NotificationMessageBuilder.momentumProtection(
      daysMissed:       daysMissed,
      previousStreak:   previousStreak,
      consistencyScore: consistencyScore,
      aiMaturity:       aiMaturity,
    );

    await _scheduleExact(
      id:      NotifIds.momentumProtect,
      title:   msg.title,
      body:    msg.body,
      time:    fire,
      payload: 'momentum_protect',
    );
  }

  // ─────────────────────────────────────────────────────────
  // WEEKLY NARRATIVE SUMMARY — fires Sunday evening
  // Use: schedule once per week at plan load
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleWeeklyNarrativeNotification({
    required String headline,
    required String userName,
  }) async {
    if (!_initialized || headline.isEmpty) return;
    await _plugin.cancel(NotifIds.weeklyNarrative);

    final now    = DateTime.now();
    final daysUntilSunday = (7 - now.weekday) % 7;
    final fire   = DateTime(
      now.year, now.month,
      now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      19, 0,
    );

    await _scheduleExact(
      id:      NotifIds.weeklyNarrative,
      title:   'Weekly review ready.',
      body:    headline,
      time:    fire,
      payload: 'weekly_narrative',
    );
  }

  // ─────────────────────────────────────────────────────────
  // SILENT DAY NOTIFICATIONS — Phase C1
  // Day 5, 6, 7 of no training. Each fires at 9AM.
  // Call after every workout save. Cancel when user returns.
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleSilentDayNotifications({
    required DateTime lastWorkoutDate,
    required String   userName,
    required int      streak,
  }) async {
    if (!_initialized) return;

    await cancelSilentDayNotifications();

    // Day 5 — calm check-in
    final day5 = DateTime(lastWorkoutDate.year, lastWorkoutDate.month,
        lastWorkoutDate.day + 5, 9, 0);
    if (day5.isAfter(DateTime.now())) {
      await _scheduleExact(
        id:      NotifIds.silentDay5,
        title:   'Five days off.',
        body:    'A light session restarts it.',
        time:    day5,
        payload: 'silent_day_5',
      );
    }

    // Day 7 — one-week mark, calm and factual.
    // Day 6 intentionally silent — daily pings read as pressure.
    final day7 = DateTime(lastWorkoutDate.year, lastWorkoutDate.month,
        lastWorkoutDate.day + 7, 9, 0);
    if (day7.isAfter(DateTime.now())) {
      await _scheduleExact(
        id:      NotifIds.silentDay7,
        title:   'One week off.',
        body:    'You\'re fully rested. Start lighter than you think.',
        time:    day7,
        payload: 'silent_day_7',
      );
    }
  }

  Future<void> cancelSilentDayNotifications() async {
    await _plugin.cancel(NotifIds.silentDay5);
    await _plugin.cancel(NotifIds.silentDay6);
    await _plugin.cancel(NotifIds.silentDay7);
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

  Future<void> cancelInactivityAlert() async {
    await _plugin.cancel(NotifIds.inactivity);
  }

  // ─────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ─────────────────────────────────────────────────────────
  Future<void> _scheduleExact({
    required int      id,
    required String   title,
    required String   body,
    required DateTime time,
    String?           payload,
  }) async {
    final tzTime = tz.TZDateTime.from(time, tz.local);
    final details = _notifDetails();
    const interp  = UILocalNotificationDateInterpretation.absoluteTime;
    try {
      await _plugin.zonedSchedule(
        id, title, body, tzTime, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: interp,
        payload: payload,
      );
    } catch (e) {
      // exact_alarms_not_permitted → SCHEDULE_EXACT_ALARM not granted.
      // Fallback to inexact: fires within a delivery window, not at exact time.
      if (e.toString().contains('exact_alarms_not_permitted')) {
        try {
          await _plugin.zonedSchedule(
            id, title, body, tzTime, details,
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation: interp,
            payload: payload,
          );
        } catch (_) {}
      }
    }
  }

  NotificationDetails _notifDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'gymtracker_main',
      'LiftOn',
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
