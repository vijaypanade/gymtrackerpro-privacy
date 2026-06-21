import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';


/// Premium Voice Coach Service
/// Provides multi-language TTS coaching during workouts
class VoiceCoachService {
  static final VoiceCoachService _instance = VoiceCoachService._();
  factory VoiceCoachService() => _instance;
  VoiceCoachService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  // Settings
  bool _enabled = true;
  bool _autoRepCounting = false;
  String _language = 'en'; // 'en', 'hi', 'mr'
  double _volume = 1.0;
  double _speechRate = 0.44;
  String _trainerPersonality = 'friendly';


  final Random _random = Random();

  String _pick(List<String> lines) {
    return lines[_random.nextInt(lines.length)];
  }

  // Getters
  bool get enabled => _enabled;
  bool get autoRepCounting => _autoRepCounting;
  String get language => _language;
  double get volume => _volume;
  double get speechRate => _speechRate;

  /// Initialize TTS engine + load saved settings
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('vc_enabled') ?? true;
    _autoRepCounting = prefs.getBool('vc_auto_reps') ?? false;
    _language = prefs.getString('vc_language') ?? 'en';
    _volume = prefs.getDouble('vc_volume') ?? 1.0;
    _speechRate = prefs.getDouble('vc_speech_rate') ?? 0.55;

    await _applyTtsSettings();
    _initialized = true;
  }

  Future<void> _applyTtsSettings() async {
    final ttsLang = _toTtsLocale(_language);

    // Check if language is available on device
    try {
      final isAvailable = await _tts.isLanguageAvailable(ttsLang);
      if (isAvailable == true || isAvailable == 1) {
        await _tts.setLanguage(ttsLang);
      } else {
        // Fallback to Indian English if Hindi/Marathi not installed
        await _tts.setLanguage('en-IN');
      }
    } catch (_) {
      await _tts.setLanguage('en-IN');
    }

    await _tts.setVolume(_volume);

    // More natural Indian pacing
    double rate = _speechRate;
    double pitch = 1.0;

    switch (_trainerPersonality) {
      case 'strict':
        rate = (_speechRate - 0.03).clamp(0.35, 1.0);
        pitch = 0.92;
        break;

      case 'military':
        rate = (_speechRate - 0.01).clamp(0.35, 1.0);
        pitch = 0.88;
        break;

      case 'motivational':
        rate = (_speechRate + 0.02).clamp(0.35, 1.0);
        pitch = 1.06;
        break;

      case 'friendly':
      default:
        rate = _speechRate;
        pitch = 1.0;
    }

    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
  }

  /// Check if a specific language is installed on device
  Future<bool> isLanguageInstalled(String langCode) async {
    try {
      final ttsLang = _toTtsLocale(langCode);
      final result = await _tts.isLanguageAvailable(ttsLang);
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }

  String _toTtsLocale(String lang) {
    switch (lang) {
      case 'hi': return 'hi-IN';
      case 'mr': return 'mr-IN';
      default: return 'en-IN';
    }
  }

  // ── SETTINGS UPDATES ──────────────────────

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

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vc_language', lang);
    await _applyTtsSettings();
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
    await _tts.setSpeechRate(_speechRate);
  }

  // ── CORE SPEAK METHOD ──────────────────────

  Future<void> _speak(String text) async {
    if (!_enabled || !_initialized) return;

    // Tiny natural pause between cues
    await Future.delayed(const Duration(milliseconds: 120));

    // Softer queue behaviour instead of harsh cuts
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}

    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  // ── COACHING CUES (multi-language) ──────────────────────

  /// "Set 1 ready" / "सेट 1 तयार" / "सेट 1 तयार"
  Future<void> setStart(int setNum) async {
    final en = switch (_trainerPersonality) {
      'strict' => _pick([
        'Set $setNum. Focus.',
        'Set $setNum. No distractions.',
        'Set $setNum. Move.',
      ]),

      'military' => _pick([
        'Set $setNum. Lock in.',
        'Set $setNum. Execute.',
        'Set $setNum. Stay tight.',
      ]),

      'motivational' => _pick([
        'Set $setNum. Let’s go!',
        'Set $setNum. Strong reps!',
        'Set $setNum. Time to work!',
      ]),

      _ => _pick([
        'Set $setNum. Ready, go!',
        'Set $setNum. Nice and controlled.',
        'Set $setNum. Let’s begin.',
      ]),
    };

    final lines = {
      'en': en,
      'hi': 'सेट $setNum. तैयार हो जाओ!',
      'mr': 'सेट $setNum. तयार रहा!',
    };

    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Rep counter — only if auto rep counting enabled
  Future<void> repCount(int rep) async {
    if (!_autoRepCounting) return;

    String en = '$rep';

    // Occasional coaching accents for realism
    if (rep == 5 || rep == 8 || rep == 10) {

      en = switch (_trainerPersonality) {

        'strict' => _pick([
          '$rep. Keep moving.',
          '$rep. Stay tight.',
          '$rep. Again.',
        ]),

        'military' => _pick([
          '$rep. Lock in.',
          '$rep. Drive.',
          '$rep. Stay focused.',
        ]),

        'motivational' => _pick([
          '$rep. Let’s go!',
          '$rep. Strong reps!',
          '$rep. Come on!',
        ]),

        _ => _pick([
          '$rep. Nice.',
          '$rep. Good control.',
          '$rep. Looking strong.',
        ]),
      };
    }

    final lines = {
      'en': en,
      'hi': _hindiNumber(rep),
      'mr': _marathiNumber(rep),
    };

    await _speak(lines[_language] ?? lines['en']!);
  }

  /// "Halfway! Push!" mid-set motivation
  Future<void> halfway() async {

    final en = switch (_trainerPersonality) {

      'strict' => _pick([
        'Keep pushing.',
        'No slowing down.',
        'Again.',
      ]),

      'military' => _pick([
        'Stay locked.',
        'Drive through.',
        'Finish strong.',
      ]),

      'motivational' => _pick([
        'Come on! Push!',
        'That’s strong!',
        'One more rep!',
      ]),

      _ => _pick([
        'Nice control.',
        'Keep going.',
        'Looking strong.',
      ]),
    };

    final lines = {
      'en': en,
      'hi': 'आधा हो गया! जोर लगाओ!',
      'mr': 'अर्धे झाले! जोर लाव!',
    };

    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Set completed → start rest
  Future<void> setComplete(int restSeconds) async {

    final en = switch (_trainerPersonality) {

      'strict' => _pick([
        'Good. Rest $restSeconds seconds.',
        'Recover. $restSeconds seconds.',
        'Stay focused. Rest $restSeconds.',
      ]),

      'military' => _pick([
        'Recover fast. $restSeconds seconds.',
        'Rest $restSeconds. Stay ready.',
        'Control your breathing. $restSeconds seconds.',
      ]),

      'motivational' => _pick([
        'Strong set! Rest $restSeconds seconds.',
        'Nice work! Recover for $restSeconds.',
        'That was solid. Rest up!',
      ]),

      _ => _pick([
        'Good set. Rest $restSeconds seconds.',
        'Nice work. Recover for $restSeconds.',
        'Take a short rest.',
      ]),
    };

    final lines = {
      'en': en,
      'hi': 'बहुत बढ़िया! $restSeconds सेकंड आराम।',
      'mr': 'छान काम! $restSeconds सेकंद विश्रांती.',
    };

    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Rest timer countdown alert (10 sec remaining)

  /// Long rest reminder
  Future<void> restTooLong() async {

    final en = switch (_trainerPersonality) {

      'strict' => _pick([
        'Back to work.',
        'Rest is over.',
        'Move.',
      ]),

      'military' => _pick([
        'Stay sharp.',
        'Get ready.',
        'Next set incoming.',
      ]),

      'motivational' => _pick([
        'Let’s keep going!',
        'You’re not done yet!',
        'Time for another set!',
      ]),

      _ => _pick([
        'Ready for the next set?',
        'Let’s continue.',
        'Time to move again.',
      ]),
    };

    final lines = {
      'en': en,
      'hi': 'अगले सेट के लिए तैयार?',
      'mr': 'पुढच्या सेटसाठी तयार?',
    };

    await _speak(lines[_language] ?? lines['en']!);
  }

  Future<void> restCountdown(int secondsLeft) async {
    if (secondsLeft == 10) {
      final lines = {
        'en': '10 seconds remaining',
        'hi': '10 सेकंड बाकी',
        'mr': '10 सेकंद बाकी',
      };
      await _speak(lines[_language] ?? lines['en']!);
    } else if (secondsLeft == 3) {
      final lines = {
        'en': '3, 2, 1, go!',
        'hi': '3, 2, 1, चलो!',
        'mr': '3, 2, 1, चला!',
      };
      await _speak(lines[_language] ?? lines['en']!);
    }
  }

  /// "Last set! Give your best"
  Future<void> lastSet() async {
    final lines = {
      'en': 'Last set! Give your best!',
      'hi': 'आखिरी सेट! पूरी ताकत लगाओ!',
      'mr': 'शेवटचा सेट! पूर्ण जोर लाव!',
    };
    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Exercise complete
  Future<void> exerciseComplete(String exerciseName) async {
    final lines = {
      'en': '$exerciseName done. Moving on.',
      'hi': '$exerciseName पूरा। आगे बढ़ो।',
      'mr': '$exerciseName झाले. पुढे चला.',
    };
    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Workout complete celebration
  Future<void> workoutComplete(int xpEarned) async {
    final lines = {
      'en': 'Workout complete! Plus $xpEarned XP. Great session!',
      'hi': 'वर्कआउट पूरा! $xpEarned XP मिले। शानदार!',
      'mr': 'वर्कआउट संपले! $xpEarned XP मिळाले. उत्तम!',
    };
    await _speak(lines[_language] ?? lines['en']!);
  }

  /// Test voice (used in settings)
  Future<void> testVoice() async {
    final lines = {
      'en': 'Voice coach ready. Let\'s crush this workout!',
      'hi': 'वॉइस कोच तैयार है। चलो वर्कआउट शुरू करें!',
      'mr': 'व्हॉइस कोच तयार आहे. चला सुरुवात करूया!',
    };
    await _speak(lines[_language] ?? lines['en']!);
  }

  // ── Helpers for Hindi/Marathi numbers (1-30 enough for reps) ──
  String _hindiNumber(int n) {
    const map = ['', 'एक','दो','तीन','चार','पाँच','छह','सात','आठ','नौ','दस',
        'ग्यारह','बारह','तेरह','चौदह','पंद्रह','सोलह','सत्रह','अठारह','उन्नीस','बीस',
        'इक्कीस','बाईस','तेईस','चौबीस','पच्चीस','छब्बीस','सत्ताईस','अट्ठाईस','उनतीस','तीस'];
    return n >= 1 && n <= 30 ? map[n] : '$n';
  }

  String _marathiNumber(int n) {
    const map = ['', 'एक','दोन','तीन','चार','पाच','सहा','सात','आठ','नऊ','दहा',
        'अकरा','बारा','तेरा','चौदा','पंधरा','सोळा','सतरा','अठरा','एकोणीस','वीस',
        'एकवीस','बावीस','तेवीस','चोवीस','पंचवीस','सव्वीस','सत्तावीस','अठ्ठावीस','एकोणतीस','तीस'];
    return n >= 1 && n <= 30 ? map[n] : '$n';
  }
}
