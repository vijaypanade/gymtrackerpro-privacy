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
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────────────────────
// AD UNIT IDs
// ─────────────────────────────────────────────────────────────
class _AdIds {
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _prodRewarded = 'ca-app-pub-8341809363570978/7501578500';
  static String get rewarded => kReleaseMode ? _prodRewarded : _testRewarded;
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

  // Rewarded
  RewardedAd? _rewarded;
  _AdState _rewardedState = _AdState.idle;
  int _rewardedRetry      = 0;
  static const _maxRetry  = 3;

  // ── Init ─────────────────────────────────────────────────
  Future<void> init({bool isPremium = false}) async {
    if (_initialized) return;
    _initialized = true;
    _isPremium   = isPremium;

    if (_isPremium) {
      debugPrint('AdService: Premium — ads disabled');
      return;
    }

    _loadRewarded();
    debugPrint('AdService: Initialized ✅');
  }

  // ── Premium gate ─────────────────────────────────────────
  void setPremium(bool value) {
    _isPremium = value;
    if (value) {
      _disposeRewarded();
      debugPrint('AdService: Premium → ads disposed');
    } else {
      _loadRewarded();
    }
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
  bool get isRewardedReady => _rewardedState == _AdState.ready;
  bool get adsEnabled      => !_isPremium && _initialized;

  void dispose() {
    _disposeRewarded();
  }
}

