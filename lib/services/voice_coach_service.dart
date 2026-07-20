import 'dart:io';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/locale_helper.dart';

/// Premium Voice Coach Service — English, personality-aware, gender-selectable.
class VoiceCoachService {
  static final VoiceCoachService _instance = VoiceCoachService._();
  factory VoiceCoachService() => _instance;
  VoiceCoachService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  bool   _enabled           = true;
  bool   _autoRepCounting   = false;
  double _volume            = 1.0;
  double _speechRate        = 0.44;
  String _trainerPersonality = 'friendly'; // no longer hardcoded — read from prefs
  String _voiceGender       = 'default';   // 'default' | 'male' | 'female'

  final Random _random = Random();

  String _pick(List<String> lines) => lines[_random.nextInt(lines.length)];

  // ── Getters ────────────────────────────────────────────────────────────────
  bool   get enabled           => _enabled;
  bool   get autoRepCounting   => _autoRepCounting;
  double get volume            => _volume;
  double get speechRate        => _speechRate;
  String get trainerPersonality => _trainerPersonality;
  String get voiceGender       => _voiceGender;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled            = prefs.getBool('vc_enabled')      ?? true;
    _autoRepCounting    = prefs.getBool('vc_auto_reps')    ?? false;
    _volume             = prefs.getDouble('vc_volume')     ?? 1.0;
    _speechRate         = prefs.getDouble('vc_speech_rate') ?? 0.55;
    _trainerPersonality = prefs.getString('vc_personality') ?? 'friendly';
    _voiceGender        = prefs.getString('vc_voice_gender') ?? 'default';
    await _applyTtsSettings();
    await _configureIosAudioSession();
    _initialized = true;
  }

  /// Called when Voice Coach sheet opens — sets personality from user profile
  /// ONLY if the user has never explicitly chosen one in settings.
  Future<void> syncWithProfile(String profileTrainerType) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('vc_personality')) {
      await setPersonality(profileTrainerType);
    }
  }

  // ── iOS audio session configuration ───────────────────────────────────────
  //
  // setSharedInstance(true): prevents AVAudioSession.setActive(false) after
  // each utterance — the session stays alive between cues so the Dart isolate
  // keeps running when the screen is locked (UIBackgroundModes: audio must
  // also be declared in Info.plist, which it is).
  //
  // IosTextToSpeechAudioCategory.playback + duckOthers:
  //   • Allows TTS to play while the screen is locked.
  //   • Ducks music/podcasts while speaking; iOS automatically unduckes them
  //     (resumes full volume) the moment the utterance ends — the user never
  //     has to manually restart their music.
  Future<void> _configureIosAudioSession() async {
    if (!Platform.isIOS) return;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    } catch (_) {}
  }

  // ── Settings apply ────────────────────────────────────────────────────────
  Future<void> _applyTtsSettings() async {
    // Use device-locale English accent (en-US for USA, en-IN for India, etc.)
    try {
      await _tts.setLanguage(LocaleHelper.ttsLocale);
    } catch (_) {
      try { await _tts.setLanguage('en-US'); } catch (_) {}
    }

    await _tts.setVolume(_volume);

    double rate  = _speechRate;
    double pitch = 1.0;
    switch (_trainerPersonality) {
      case 'strict':
        rate  = (_speechRate - 0.03).clamp(0.35, 1.0);
        pitch = 0.92;
      case 'military':
        rate  = (_speechRate - 0.01).clamp(0.35, 1.0);
        pitch = 0.88;
      case 'motivational':
        rate  = (_speechRate + 0.02).clamp(0.35, 1.0);
        pitch = 1.06;
      default:
        rate  = _speechRate;
        pitch = 1.0;
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);

    if (_voiceGender != 'default') {
      await _pickAndSetVoice();
    }
  }

  // ── Voice gender selection ────────────────────────────────────────────────

  // Well-known iOS TTS voice names by gender
  static const _femaleNames = {
    'samantha', 'allison', 'ava', 'susan', 'zoe', 'victoria',
    'karen', 'moira', 'tessa', 'nicky', 'siri',
  };
  static const _maleNames = {
    'alex', 'daniel', 'fred', 'tom', 'gordon', 'arthur',
    'ryan', 'oliver', 'james', 'lee',
  };

  bool _isFemaleVoice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('female')) return true;
    final first = lower.split(RegExp(r'[-_ ]')).first;
    return _femaleNames.contains(first);
  }

  bool _isMaleVoice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('male') && !lower.contains('female')) return true;
    final first = lower.split(RegExp(r'[-_ ]')).first;
    return _maleNames.contains(first);
  }

  Future<void> _pickAndSetVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw == null) return;
      final voices = (raw as List).cast<Map>();
      final locale = LocaleHelper.ttsLocale;
      final langPrefix = locale.substring(0, 2); // 'en'

      // Filter to English voices only
      final enVoices = voices
          .where((v) => (v['locale'] as String? ?? '').startsWith(langPrefix))
          .toList();

      Map? pick;
      for (final v in enVoices) {
        final name = v['name'] as String? ?? '';
        if (_voiceGender == 'female' && _isFemaleVoice(name)) { pick = v; break; }
        if (_voiceGender == 'male'   && _isMaleVoice(name))   { pick = v; break; }
      }
      pick ??= enVoices.isNotEmpty ? enVoices.first : null;

      if (pick != null) {
        await _tts.setVoice({
          'name':   pick['name']   as String,
          'locale': pick['locale'] as String,
        });
      }
    } catch (_) {}
  }

  // ── Setters ───────────────────────────────────────────────────────────────
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vc_enabled', v);
    if (!v) await _tts.stop();
  }

  Future<void> setAutoRepCounting(bool v) async {
    _autoRepCounting = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vc_auto_reps', v);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vc_volume', _volume);
    await _tts.setVolume(_volume);
  }

  Future<void> setSpeechRate(double v) async {
    _speechRate = v.clamp(0.3, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vc_speech_rate', _speechRate);
    await _applyTtsSettings();
  }

  Future<void> setPersonality(String v) async {
    _trainerPersonality = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vc_personality', v);
    await _applyTtsSettings();
  }

  Future<void> setVoiceGender(String gender) async {
    _voiceGender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vc_voice_gender', gender);
    await _applyTtsSettings();
  }

  // ── Internal speak ────────────────────────────────────────────────────────
  Future<void> _speak(String text) async {
    if (!_enabled || !_initialized) return;
    await Future.delayed(const Duration(milliseconds: 120));
    try { await _tts.awaitSpeakCompletion(true); } catch (_) {}
    await _tts.speak(text);
  }

  Future<void> stop() async => _tts.stop();

  // ── COACHING CUES ─────────────────────────────────────────────────────────

  Future<void> setStart(int setNum) async {
    final cue = switch (_trainerPersonality) {
      'strict' => _pick([
          'Set $setNum. Focus.',
          'Set $setNum. No distractions.',
          'Set $setNum. Move.',
          'Set $setNum. Execute.',
          'Set $setNum. Lock in now.',
        ]),
      'military' => _pick([
          'Set $setNum. Lock in.',
          'Set $setNum. Execute.',
          'Set $setNum. Stay tight.',
          'Set $setNum. Move out.',
          'Set $setNum. On my count — go.',
        ]),
      'motivational' => _pick([
          'Set $setNum. Let\'s go!',
          'Set $setNum. Strong reps!',
          'Set $setNum. Time to work!',
          'Set $setNum. Make it count!',
          'Set $setNum. You\'ve got this!',
        ]),
      _ => _pick([
          'Set $setNum. Ready, go!',
          'Set $setNum. Nice and controlled.',
          'Set $setNum. Let\'s begin.',
          'Set $setNum. Take your time.',
          'Set $setNum. Smooth reps.',
        ]),
    };
    await _speak(cue);
  }

  Future<void> repCount(int rep) async {
    if (!_autoRepCounting) return;
    String cue = '$rep';
    if (rep == 5 || rep == 8 || rep == 10 || rep == 12) {
      cue = switch (_trainerPersonality) {
        'strict' => _pick([
            '$rep. Keep moving.',
            '$rep. Stay tight.',
            '$rep. Again.',
            '$rep. Don\'t slow down.',
          ]),
        'military' => _pick([
            '$rep. Lock in.',
            '$rep. Drive.',
            '$rep. Stay focused.',
            '$rep. Push.',
          ]),
        'motivational' => _pick([
            '$rep. Let\'s go!',
            '$rep. Strong reps!',
            '$rep. Come on!',
            '$rep. Keep it up!',
          ]),
        _ => _pick([
            '$rep. Nice.',
            '$rep. Good control.',
            '$rep. Looking strong.',
            '$rep. Keep it clean.',
          ]),
      };
    }
    await _speak(cue);
  }

  Future<void> halfway() async {
    final cue = switch (_trainerPersonality) {
      'strict' => _pick([
          'Keep pushing.',
          'No slowing down.',
          'Again.',
          'Halfway. Finish it.',
          'Push through.',
        ]),
      'military' => _pick([
          'Stay locked.',
          'Drive through.',
          'Finish strong.',
          'Halfway. Don\'t break.',
          'Execute.',
        ]),
      'motivational' => _pick([
          'Come on! Push!',
          'That\'s strong!',
          'Halfway! Keep it up!',
          'You\'re doing great!',
          'Don\'t stop now!',
        ]),
      _ => _pick([
          'Nice control.',
          'Keep going.',
          'Looking strong.',
          'Halfway there.',
          'Good rhythm.',
        ]),
    };
    await _speak(cue);
  }

  Future<void> setComplete(int restSeconds) async {
    final cue = switch (_trainerPersonality) {
      'strict' => _pick([
          'Good. Rest $restSeconds seconds.',
          'Recover. $restSeconds seconds.',
          'Stay focused. Rest $restSeconds.',
          'Set done. $restSeconds seconds.',
          'Rest. Back in $restSeconds.',
        ]),
      'military' => _pick([
          'Recover fast. $restSeconds seconds.',
          'Rest $restSeconds. Stay ready.',
          'Control your breathing. $restSeconds seconds.',
          'Stand down. $restSeconds seconds.',
          'Recovery window. $restSeconds seconds.',
        ]),
      'motivational' => _pick([
          'Strong set! Rest $restSeconds seconds.',
          'Nice work! Recover for $restSeconds.',
          'That was solid. Rest up!',
          'Crushed it! $restSeconds seconds rest.',
          'Great effort! Breathe for $restSeconds.',
        ]),
      _ => _pick([
          'Good set. Rest $restSeconds seconds.',
          'Nice work. Recover for $restSeconds.',
          'Take a short rest.',
          'Well done. $restSeconds seconds.',
          'Solid set. Rest $restSeconds.',
        ]),
    };
    await _speak(cue);
  }

  Future<void> restTooLong() async {
    final cue = switch (_trainerPersonality) {
      'strict' => _pick([
          'Back to work.',
          'Rest is over.',
          'Move.',
          'Time\'s up. Next set.',
          'No more rest.',
        ]),
      'military' => _pick([
          'Stay sharp.',
          'Get ready.',
          'Next set incoming.',
          'Fall in. Move.',
          'Back on the line.',
        ]),
      'motivational' => _pick([
          'Let\'s keep going!',
          'You\'re not done yet!',
          'Time for another set!',
          'Come on, one more!',
          'Let\'s go, let\'s go!',
        ]),
      _ => _pick([
          'Ready for the next set?',
          'Let\'s continue.',
          'Time to move again.',
          'Next set when you\'re ready.',
          'Take a breath and go.',
        ]),
    };
    await _speak(cue);
  }

  Future<void> restCountdown(int secondsLeft) async {
    if (secondsLeft == 10) {
      final cue = switch (_trainerPersonality) {
        'strict'       => '10 seconds. Get ready.',
        'military'     => '10 seconds. Prepare to execute.',
        'motivational' => '10 seconds! Get pumped!',
        _              => '10 seconds remaining.',
      };
      await _speak(cue);
    } else if (secondsLeft == 3) {
      await _speak('3, 2, 1, go!');
    }
  }

  Future<void> lastSet() async {
    final cue = switch (_trainerPersonality) {
      'strict'       => 'Last set. Leave nothing.',
      'military'     => 'Final set. Execute perfectly.',
      'motivational' => 'Last set! Give everything you\'ve got!',
      _              => 'Last set. Make it your best.',
    };
    await _speak(cue);
  }

  Future<void> exerciseComplete(String exerciseName) async {
    final cue = switch (_trainerPersonality) {
      'strict'       => '$exerciseName done.',
      'military'     => '$exerciseName complete. Move.',
      'motivational' => '$exerciseName done! Great work!',
      _              => '$exerciseName done. Moving on.',
    };
    await _speak(cue);
  }

  Future<void> workoutComplete(int xpEarned) async {
    final cue = switch (_trainerPersonality) {
      'strict'       => 'Session complete. $xpEarned XP. Good work.',
      'military'     => 'Mission complete. $xpEarned XP earned. Dismissed.',
      'motivational' => 'Workout done! $xpEarned XP! You crushed it!',
      _              => 'Session complete. $xpEarned XP earned. Well done.',
    };
    await _speak(cue);
  }

  Future<void> testVoice() async {
    final cue = switch (_trainerPersonality) {
      'strict'       => 'Voice coach active. Stay focused.',
      'military'     => 'Voice coach online. Ready to execute.',
      'motivational' => 'Voice coach on! Let\'s crush this workout!',
      _              => 'Voice coach ready. Let\'s get to work.',
    };
    await _speak(cue);
  }
}
