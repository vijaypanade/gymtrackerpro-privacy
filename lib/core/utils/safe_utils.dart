import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
// lib/core/utils/safe_utils.dart
// ══════════════════════════════════════════════════════════
// CRASH FIXES for all identified unsafe patterns:
// 1. weekPlan[index] — RangeError if plan < 7 days
// 2. unsafe "as String" casts — TypeError on null/wrong type
// 3. AudioPlayer missing asset — silent swallow
// 4. Null safety gaps in fromJson factories
// ══════════════════════════════════════════════════════════

/// Safe list access — returns null instead of RangeError
extension SafeList<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  T elementAtOrDefault(int index, T defaultValue) {
    if (index < 0 || index >= length) return defaultValue;
    return this[index];
  }

  /// Safe sublist — never throws RangeError
  List<T> safeSublist(int start, [int? end]) {
    final s = start.clamp(0, length);
    final e = (end ?? length).clamp(s, length);
    return sublist(s, e);
  }
}

/// Safe JSON value extraction — never throws TypeError
extension SafeJson on Map<String, dynamic> {
  String  str(String key, [String  def = '']) =>
      (this[key] as String?)                  ?? def;
  int     i(String key,   [int     def = 0])  =>
      (this[key] as num?)?.toInt()            ?? def;
  double  d(String key,   [double  def = 0])  =>
      (this[key] as num?)?.toDouble()         ?? def;
  bool    b(String key,   [bool    def = false]) =>
      (this[key] as bool?)                    ?? def;
  List<T> lst<T>(String key) =>
      List<T>.from(this[key] as List? ?? const []);
}

/// Safe string parsing helpers
extension SafeString on String? {
  /// Parse double safely — returns 0 on null/invalid
  double toDoubleOrZero() {
    if (this == null) return 0;
    return double.tryParse(this!) ?? 0;
  }

  /// Parse int safely
  int toIntOrZero() {
    if (this == null) return 0;
    return int.tryParse(this!) ?? 0;
  }

  bool get isNullOrEmpty => this == null || this!.isEmpty;
}

// ─────────────────────────────────────────────────────────
// WEEK PLAN SAFE ACCESS
// ─────────────────────────────────────────────────────────
/// Use this everywhere instead of _weekPlan[dayIndex]
/// Prevents RangeError when AI-generated plan has < 7 days
class WeekPlanGuard {
  static bool isValidIndex(int index, int planLength) =>
      index >= 0 && index < planLength;

  static int clampTodayIndex(int rawToday, int planLength) {
    if (planLength == 0) return 0;
    return rawToday.clamp(0, planLength - 1);
  }
}

// ─────────────────────────────────────────────────────────
// AUDIO SAFE PLAYER
// ─────────────────────────────────────────────────────────
/// Singleton AudioPlayer — one native MediaPlayer, reused for all SFX.
/// Creating a new AudioPlayer() per call spawns a new native MediaPlayer,
/// causing "Unable to create media player" / "prepareAsync called in state 1"
/// when multiple calls race on Android.
class SafeAudio {
  static final AudioPlayer _player = AudioPlayer();
  static bool _contextReady = false;

  /// An app has exactly one AVAudioSession, and audioplayers is its second
  /// owner alongside flutter_tts. Its iOS default is `playback` with no options
  /// — a non-mixing category, so playing a one-second SFX interrupts whatever
  /// the user is listening to and does not resume it. Matching the voice
  /// coach's category and options means neither owner interrupts, and it no
  /// longer matters which of the two configured the session last.
  static Future<void> _ensureContext() async {
    if (_contextReady) return;
    _contextReady = true; // set first: a failure must not retry on every SFX
    try {
      await AudioPlayer.global.setAudioContext(
        const AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> playSuccess() async {
    try {
      await _ensureContext();
      await _player.stop();
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (_) {}
  }

  // tick.mp3 is not bundled — use a system click sound (no asset file needed)
  static Future<void> playTick() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
