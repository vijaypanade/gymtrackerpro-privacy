// lib/services/workout_session_service.dart
// ─────────────────────────────────────────────
// Active workout session tracking (Hevy/Strong style)
// • Auto-starts on first set logged
// • Tracks duration in real-time
// • Auto-saves on app close
// • 90 min idle → reminder notification
// • 3 hours idle → auto-end session
// ─────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutSessionService extends ChangeNotifier {
  WorkoutSessionService._();
  static final WorkoutSessionService instance = WorkoutSessionService._();

  static const _kStartTime = 'session_start_time';
  static const _kLastActivity = 'session_last_activity';
  static const _kDayIndex = 'session_day_index';

  DateTime? _startTime;
  DateTime? _lastActivity;
  int? _dayIndex;
  Timer? _ticker;

  // Session volume tracking
  double _sessionVolumeKg = 0.0;
  int    _sessionSets     = 0;
  final  _firedMilestones = <int>{};
  String? _pendingMilestone;

  // Volume milestone thresholds in kg
  static const _volumeMilestones = [500, 1000, 2500, 5000, 10000];

  // Idle thresholds
  static const _idleReminderMin = 90; // 90 min → notify
  static const _autoEndMin = 180;     // 3 hr → auto-end

  bool get isActive => _startTime != null;
  double get sessionVolumeKg => _sessionVolumeKg;
  int    get sessionSets     => _sessionSets;

  /// Call after each completed set. Returns a milestone label if one was hit.
  String? addVolume(double weightKg, int reps) {
    if (!isActive) return null;
    final vol = weightKg > 0 ? weightKg * reps : 0.0;
    _sessionVolumeKg += vol;
    _sessionSets++;
    for (final threshold in _volumeMilestones) {
      if (!_firedMilestones.contains(threshold) &&
          _sessionVolumeKg >= threshold) {
        _firedMilestones.add(threshold);
        final label = threshold >= 1000
            ? '${(threshold / 1000).toStringAsFixed(threshold % 1000 == 0 ? 0 : 1)}t lifted'
            : '${threshold}kg lifted';
        _pendingMilestone = label;
        return label;
      }
    }
    return null;
  }

  /// Consumes and clears the pending milestone — call once in UI after showing.
  String? consumeMilestone() {
    final m = _pendingMilestone;
    _pendingMilestone = null;
    return m;
  }
  DateTime? get startTime => _startTime;
  int? get dayIndex => _dayIndex;

  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  String get elapsedFormatted {
    final d = elapsed;
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m >= 60) {
      final h = d.inHours;
      final mm = m % 60;
      return '${h}h ${mm}m';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Duration get idleDuration {
    if (_lastActivity == null) return Duration.zero;
    return DateTime.now().difference(_lastActivity!);
  }

  /// Restore session from disk (call on app start).
  Future<void> restoreFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startMs = prefs.getInt(_kStartTime);
      final activityMs = prefs.getInt(_kLastActivity);
      final dayIdx = prefs.getInt(_kDayIndex);
      if (startMs == null) return;

      _startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
      _lastActivity = activityMs != null
          ? DateTime.fromMillisecondsSinceEpoch(activityMs)
          : _startTime;
      _dayIndex = dayIdx;

      // Auto-end if idle too long
      if (idleDuration.inMinutes >= _autoEndMin) {
        debugPrint('🛑 Session auto-ended (idle ${idleDuration.inMinutes}m)');
        await endSession();
        return;
      }

      _startTicker();
      debugPrint('✅ Session restored - elapsed ${elapsedFormatted}');
      notifyListeners();
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
  }

  /// Start a new session (auto-called on first set logged).
  Future<void> startSession({required int dayIndex}) async {
    if (isActive) {
      // Update activity instead of restarting
      await touchActivity();
      return;
    }
    _startTime = DateTime.now();
    _lastActivity = _startTime;
    _dayIndex = dayIndex;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStartTime, _startTime!.millisecondsSinceEpoch);
    await prefs.setInt(_kLastActivity, _lastActivity!.millisecondsSinceEpoch);
    await prefs.setInt(_kDayIndex, dayIndex);

    _startTicker();
    debugPrint('▶️ Session started for day $dayIndex');
    notifyListeners();
  }

  /// Mark activity (called every time a set is logged).
  Future<void> touchActivity() async {
    if (!isActive) return;
    _lastActivity = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastActivity, _lastActivity!.millisecondsSinceEpoch);
  }

  /// End current session and clear state.
  Future<Duration> endSession() async {
    final dur = elapsed;
    _startTime = null;
    _lastActivity = null;
    _dayIndex = null;
    _ticker?.cancel();
    _ticker = null;
    _sessionVolumeKg = 0.0;
    _sessionSets = 0;
    _firedMilestones.clear();
    _pendingMilestone = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStartTime);
    await prefs.remove(_kLastActivity);
    await prefs.remove(_kDayIndex);

    debugPrint('⏹️ Session ended - total ${dur.inMinutes}m');
    notifyListeners();
    return dur;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      // Auto-end if idle too long
      if (idleDuration.inMinutes >= _autoEndMin) {
        t.cancel();
        _ticker = null;
        endSession();
        return;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
