// lib/services/ad_service.dart — PRODUCTION v3.0
// ══════════════════════════════════════════════════════════════
// ROOT CAUSE FIXES:
//   1. showInterstitialIfAllowed() — removed MonetizationService dependency
//      (was causing double-call + blocking)
//   2. Frequency logic moved entirely into AdService
//   3. _initialized guard prevents double-init
//   4. Proper async/await on all ad loads
//   5. No UI thread blocking
// ══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// AD UNIT IDs
// ─────────────────────────────────────────────────────────────
class _AdIds {
  // Test IDs — safe for development
  static const _testBanner       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded     = 'ca-app-pub-3940256099942544/5224354917';

  // Production IDs — replace XXXXXXXXXX with real IDs from AdMob console
  static const _prodBanner = 'ca-app-pub-8341809363570978/2860767554';

  static const _prodInterstitial = 'ca-app-pub-8341809363570978/6648803476';

  static const _prodRewarded = 'ca-app-pub-8341809363570978/7501578500';


  // Auto-switch: test in debug, real in release
  static String get banner       => kReleaseMode ? _prodBanner       : _testBanner;
  static String get interstitial => kReleaseMode ? _prodInterstitial : _testInterstitial;
  static String get rewarded     => kReleaseMode ? _prodRewarded     : _testRewarded;
}

// ─────────────────────────────────────────────────────────────
// AD STATE
// ─────────────────────────────────────────────────────────────
enum _AdState { idle, loading, ready, showing, failed }

// ─────────────────────────────────────────────────────────────
// AD SERVICE — Singleton
// ─────────────────────────────────────────────────────────────
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _isPremium   = false;

  // Interstitial
  InterstitialAd? _interstitial;
  _AdState _interstitialState   = _AdState.idle;
  int _interstitialRetry        = 0;
  static const _maxRetry        = 3;

  // Rewarded
  RewardedAd? _rewarded;
  _AdState _rewardedState       = _AdState.idle;
  int _rewardedRetry            = 0;

  // Frequency control — entirely inside AdService (no MonetizationService dependency)
  static const String _kWorkoutCountKey = 'ad_workout_count';
  static const String _kDateKey         = 'ad_date';
  static const int    _showEveryN       = 3; // show ad every 3 workouts
  int _workoutsSinceLastAd              = 0;

  // ── Init ─────────────────────────────────────────────────
  Future<void> init({bool isPremium = false}) async {
    if (_initialized) return;
    _initialized = true;
    _isPremium   = isPremium;

    if (_isPremium) {
      debugPrint('AdService: Premium — ads disabled');
      return;
    }

    await _loadFrequencyState();

    // Preload in parallel — don't await together to avoid blocking
    _loadInterstitial();
    _loadRewarded();

    debugPrint('AdService: Initialized ✅ (preloading ads)');
  }

  // ── Frequency state persistence ──────────────────────────
  Future<void> _loadFrequencyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayStr;
      final saved = prefs.getString(_kDateKey) ?? '';
      if (saved != today) {
        // New day — reset count
        await prefs.setString(_kDateKey, today);
        await prefs.setInt(_kWorkoutCountKey, 0);
        _workoutsSinceLastAd = 0;
      } else {
        _workoutsSinceLastAd = prefs.getInt(_kWorkoutCountKey) ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _saveFrequencyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kWorkoutCountKey, _workoutsSinceLastAd);
      await prefs.setString(_kDateKey, _todayStr);
    } catch (_) {}
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Premium gate ─────────────────────────────────────────
  void setPremium(bool value) {
    _isPremium = value;
    if (value) {
      _disposeInterstitial();
      _disposeRewarded();
      debugPrint('AdService: Premium → ads disposed');
    } else {
      _loadInterstitial();
      _loadRewarded();
    }
  }

  // ══════════════════════════════════════════════════════════
  // INTERSTITIAL — Load
  // ══════════════════════════════════════════════════════════
  void _loadInterstitial() {
    if (_isPremium) return;
    if (_interstitialState == _AdState.loading) return;
    if (_interstitialState == _AdState.ready) return;
    if (_interstitialRetry >= _maxRetry) {
      debugPrint('AdService: Interstitial — max retries, giving up');
      return;
    }

    _interstitialState = _AdState.loading;
    debugPrint('AdService: Loading interstitial (attempt ${_interstitialRetry + 1})...');

    InterstitialAd.load(
      adUnitId: _AdIds.interstitial,
      request:  const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial      = ad;
          _interstitialState = _AdState.ready;
          _interstitialRetry = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _interstitialState = _AdState.showing;
              debugPrint('AdService: Interstitial showing');
            },
            onAdDismissedFullScreenContent: (_) {
              debugPrint('AdService: Interstitial dismissed — reloading');
              _disposeInterstitial();
              _loadInterstitial(); // Auto-reload immediately
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('AdService: Interstitial show failed: $error');
              _disposeInterstitial();
              _loadInterstitial();
            },
          );
          debugPrint('AdService: Interstitial ready ✅');
        },
        onAdFailedToLoad: (error) {
          _interstitialState = _AdState.failed;
          _interstitialRetry++;
          debugPrint('AdService: Interstitial load failed (${error.message})');

          // Exponential backoff: 4s, 8s, 16s
          final delay = Duration(seconds: (4 * (1 << _interstitialRetry)).clamp(4, 60));
          Future.delayed(delay, _loadInterstitial);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // INTERSTITIAL — Show
  // FIX: Removed MonetizationService dependency (was causing double-call)
  // Frequency logic is now entirely internal
  // ══════════════════════════════════════════════════════════
  Future<bool> showInterstitialIfAllowed() async {
    if (_isPremium) return false;

    // Frequency check — internal, no external dependency
    _workoutsSinceLastAd++;
    await _saveFrequencyState();

    debugPrint('AdService: Workout count since last ad: $_workoutsSinceLastAd');

    if (_workoutsSinceLastAd < _showEveryN) {
      debugPrint('AdService: Skipping ad (showing every $_showEveryN workouts)');
      return false;
    }

    // Ready check
    if (_interstitial == null || _interstitialState != _AdState.ready) {
      debugPrint('AdService: Interstitial not ready (state: $_interstitialState)');
      _loadInterstitial(); // Trigger reload for next time
      return false;
    }

    // Reset counter
    _workoutsSinceLastAd = 0;
    await _saveFrequencyState();

    try {
      await _interstitial!.show();
      debugPrint('AdService: Interstitial shown ✅');
      return true;
    } catch (e) {
      debugPrint('AdService: Interstitial show error: $e');
      _disposeInterstitial();
      _loadInterstitial();
      return false;
    }
  }

  void _disposeInterstitial() {
    _interstitial?.dispose();
    _interstitial      = null;
    _interstitialState = _AdState.idle;
  }

  // ══════════════════════════════════════════════════════════
  // REWARDED — Load
  // ══════════════════════════════════════════════════════════
  void _loadRewarded() {
    if (_isPremium) return;
    if (_rewardedState == _AdState.loading) return;
    if (_rewardedState == _AdState.ready) return;
    if (_rewardedRetry >= _maxRetry) return;

    _rewardedState = _AdState.loading;

    RewardedAd.load(
      adUnitId: _AdIds.rewarded,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded      = ad;
          _rewardedState = _AdState.ready;
          _rewardedRetry = 0;
          debugPrint('AdService: Rewarded ready ✅');
        },
        onAdFailedToLoad: (error) {
          _rewardedState = _AdState.failed;
          _rewardedRetry++;
          debugPrint('AdService: Rewarded load failed: ${error.message}');
          final delay = Duration(seconds: (4 * (1 << _rewardedRetry)).clamp(4, 60));
          Future.delayed(delay, _loadRewarded);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // REWARDED — Show
  // ══════════════════════════════════════════════════════════
  Future<void> showRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onFailed,
  }) async {
    if (_isPremium) { onFailed?.call(); return; }

    if (_rewarded == null || _rewardedState != _AdState.ready) {
      debugPrint('AdService: Rewarded not ready');
      _loadRewarded();
      onFailed?.call();
      return;
    }

    bool earned = false;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _rewardedState = _AdState.showing,
      onAdDismissedFullScreenContent: (_) {
        _disposeRewarded();
        _loadRewarded();
        if (earned) {
          onRewarded();
        } else {
          onFailed?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('AdService: Rewarded show failed: $error');
        _disposeRewarded();
        _loadRewarded();
        onFailed?.call();
      },
    );

    try {
      await _rewarded!.show(
        onUserEarnedReward: (_, reward) {
          earned = true;
          debugPrint('AdService: Reward earned ✅');
        },
      );
    } catch (e) {
      debugPrint('AdService: Rewarded error: $e');
      _disposeRewarded();
      _loadRewarded();
      onFailed?.call();
    }
  }

  void _disposeRewarded() {
    _rewarded?.dispose();
    _rewarded      = null;
    _rewardedState = _AdState.idle;
  }

  // ── Getters ───────────────────────────────────────────────
  bool get isInterstitialReady => _interstitialState == _AdState.ready;
  bool get isRewardedReady     => _rewardedState == _AdState.ready;
  bool get adsEnabled          => !_isPremium && _initialized;

  void dispose() {
    _disposeInterstitial();
    _disposeRewarded();
  }
}

// ══════════════════════════════════════════════════════════════
// BANNER AD WIDGET — reusable, auto-load, dispose safe
// ══════════════════════════════════════════════════════════════
class GTPBannerAd extends StatefulWidget {
  final bool isPremium;
  const GTPBannerAd({super.key, this.isPremium = false});

  @override
  State<GTPBannerAd> createState() => _GTPBannerAdState();
}

class _GTPBannerAdState extends State<GTPBannerAd> {
  BannerAd? _bannerAd;
  bool      _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isPremium) _load();
  }

  void _load() {
    _bannerAd = BannerAd(
      adUnitId: _AdIds.banner,
      size:     AdSize.banner,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
          debugPrint('AdService: Banner loaded ✅');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdService: Banner failed: ${error.message}');
          ad.dispose();
          _bannerAd = null;
          // Retry after 30s
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && !widget.isPremium) _load();
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPremium) return const SizedBox.shrink();
    if (!_loaded || _bannerAd == null) return const SizedBox(height: 50);

    return SafeArea(
      top: false,
      child: SizedBox(
        width:  _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child:  AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
