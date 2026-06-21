import 'dart:async';
import 'package:flutter/foundation.dart';
import 'voice_coach_service.dart';

/// Singleton rest timer that drives the overlay
class RestTimerService extends ChangeNotifier {
  static final RestTimerService _instance = RestTimerService._();
  factory RestTimerService() => _instance;
  RestTimerService._();

  Timer? _timer;
  int _totalSeconds = 0;
  int _remaining = 0;
  bool _active = false;

  // Up-next context — set by WorkoutProvider before start()
  String? _nextName;
  String? _nextContext; // e.g. "4 × 10 · 62.5kg"

  int get totalSeconds => _totalSeconds;
  int get remaining => _remaining;
  bool get active => _active;
  double get progress =>
      _totalSeconds > 0 ? 1.0 - (_remaining / _totalSeconds) : 0.0;
  String? get nextName    => _nextName;
  String? get nextContext => _nextContext;

  void setNextExercise({
    required String name,
    required int sets,
    required int reps,
    required double weight,
    required String unit,
    required bool isBodyweight,
  }) {
    _nextName = name;
    if (isBodyweight || unit == 'reps') {
      _nextContext = '$sets × $reps reps';
    } else if (unit == 'min') {
      _nextContext = '$sets × ${weight.toInt()} min';
    } else {
      final w = weight == weight.roundToDouble()
          ? weight.toStringAsFixed(0)
          : weight.toStringAsFixed(1);
      _nextContext = '$sets × $reps · ${w}kg';
    }
  }

  void start({int seconds = 90}) {
    debugPrint('⏱️ RestTimer.start called - resetting to \$seconds sec');
    _timer?.cancel();
    _totalSeconds = seconds;
    _remaining = seconds;
    _active = true;
    notifyListeners();

    final vc = VoiceCoachService();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _remaining--;
      notifyListeners();

      // Voice cues at key milestones (fire-and-forget; no await in timer)

      // Long-rest accountability cue
      if (_totalSeconds >= 75 && _remaining == 20) {
        vc.restTooLong();
      }

      if (_remaining == 10) {
        vc.restCountdown(10);
      } else if (_remaining == 3) {
        vc.restCountdown(3);
      }

      if (_remaining <= 0) {
        stop();
      }
    });
  }

  void addTime(int seconds) {
    if (!_active) return;
    _remaining += seconds;
    _totalSeconds += seconds;
    notifyListeners();
  }

  void skip() {
    VoiceCoachService().stop();
    stop();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _active = false;
    _remaining = 0;
    _nextName = null;
    _nextContext = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
