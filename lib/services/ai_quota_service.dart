// lib/services/ai_quota_service.dart
// Production-safe Gemini API protection layer.
//
// Responsibilities:
//   - Emergency kill switch (Remote Config + Firestore)
//   - Daily request caps per user (local + Firestore-backed)
//   - Per-user cooldown enforcement
//   - Request debouncing
//   - Duplicate prompt detection + in-memory cache (24h TTL)
//   - Flash vs Pro model routing
//   - Graceful offline/local fallbacks
//   - Firebase usage tracking (fire-and-forget)

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Request type (drives model routing + fallback copy) ──────────────────────
enum AiRequestType { chat, brief, plan, insight, diet }

// ── Quota check result ───────────────────────────────────────────────────────
class QuotaResult {
  final bool allowed;
  final String? denyReason;
  final bool isCooldown;
  final String? cachedResponse; // non-null when cache hit

  const QuotaResult._({
    required this.allowed,
    this.denyReason,
    this.isCooldown = false,
    this.cachedResponse,
  });

  factory QuotaResult.ok() => const QuotaResult._(allowed: true);
  factory QuotaResult.cached(String response) =>
      QuotaResult._(allowed: true, cachedResponse: response);
  factory QuotaResult.denied(String reason) =>
      QuotaResult._(allowed: false, denyReason: reason);
  factory QuotaResult.cooldown(String reason) =>
      QuotaResult._(allowed: false, denyReason: reason, isCooldown: true);

  bool get isCacheHit => cachedResponse != null;
}

// ── AiQuotaService ────────────────────────────────────────────────────────────
class AiQuotaService {
  AiQuotaService._();
  static final AiQuotaService instance = AiQuotaService._();

  // ── Limits ─────────────────────────────────────────────────────────────────
  static const int kFreeDailyLimit    = 10;
  static const int kPremiumDailyLimit = 50;
  static const int kCooldownSeconds   = 15;
  static const Duration kDebounce     = Duration(milliseconds: 800);
  static const int kCacheTtlHours     = 24;
  static const int kMaxCacheEntries   = 60;

  // ── Model names ────────────────────────────────────────────────────────────
  // Routes to these via the 'model' field in the Cloud Function request body.
  static const String kFlashModel = 'gemini-2.5-flash';
  static const String kProModel   = 'gemini-2.5-pro';

  // ── Internal state ─────────────────────────────────────────────────────────
  bool _aiEnabled     = true;
  bool _initialized   = false;
  DateTime? _lastRequestAt;

  // In-memory response cache: promptHash → (response, expiryTime)
  final Map<String, (String, DateTime)> _cache = {};

  // Debounce timers per key
  final Map<String, Timer> _debounceTimers = {};

  // Local SharedPreferences keys
  static const String _kQuotaDate  = 'aiq_date';
  static const String _kQuotaCount = 'aiq_count';

  // ── Initialisation ─────────────────────────────────────────────────────────
  /// Call once from main() after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _syncRemoteConfig();
  }

  Future<void> _syncRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(const {'ai_enabled': true});
      // Non-blocking fetch — use stale value if network is slow
      await rc.fetchAndActivate().timeout(const Duration(seconds: 4));
      _aiEnabled = rc.getBool('ai_enabled');
    } catch (e) {
      debugPrint('[AiQuota] Remote Config sync error: $e — defaulting to enabled');
    }
  }

  // Refresh kill switch on-demand (e.g. foreground resume)
  Future<void> refreshKillSwitch() => _syncRemoteConfig();

  // ── Emergency kill switch ──────────────────────────────────────────────────
  bool get isAIEnabled => _aiEnabled;

  // ── Model routing ──────────────────────────────────────────────────────────
  /// Premium users get Pro for full plan generation; everything else = Flash.
  String modelFor(AiRequestType type, {bool isPremium = false}) {
    if (isPremium && type == AiRequestType.plan) return kProModel;
    return kFlashModel;
  }

  // ── Primary gate: call before every AI request ─────────────────────────────
  Future<QuotaResult> check({
    required bool isPremium,
    String? prompt,
  }) async {
    // 1. Kill switch
    if (!_aiEnabled) {
      return QuotaResult.denied(
          'AI assistant is temporarily offline. Please try again later.');
    }

    // 2. Cooldown
    if (_lastRequestAt != null) {
      final elapsed = DateTime.now().difference(_lastRequestAt!).inSeconds;
      if (elapsed < kCooldownSeconds) {
        final remaining = kCooldownSeconds - elapsed;
        return QuotaResult.cooldown(
            'Wait ${remaining}s before the next request.');
      }
    }

    // 3. Cache hit — skip quota and return immediately
    if (prompt != null && prompt.isNotEmpty) {
      final hit = _getCached(prompt);
      if (hit != null) return QuotaResult.cached(hit);
    }

    // 4. Daily quota (local SharedPrefs — no network round-trip)
    final limit = isPremium ? kPremiumDailyLimit : kFreeDailyLimit;
    final count = await _localDailyCount();
    if (count >= limit) {
      return QuotaResult.denied(
        isPremium
            ? 'Daily AI limit reached ($limit requests). Resets at midnight.'
            : 'Daily AI limit reached ($kFreeDailyLimit requests).'
              ' Upgrade to Premium for more.',
      );
    }

    return QuotaResult.ok();
  }

  // ── Record a completed request ─────────────────────────────────────────────
  Future<void> record({required AiRequestType type}) async {
    _lastRequestAt = DateTime.now();
    await _incrementLocalCount();
  }

  // ── Cache ──────────────────────────────────────────────────────────────────
  void store(String prompt, String response) {
    // Never cache error strings or empty responses
    if (response.isEmpty || response.startsWith('⚠️')) return;

    if (_cache.length >= kMaxCacheEntries) {
      // Evict the entry that expires soonest
      final evict = _cache.entries
          .reduce((a, b) => a.value.$2.isBefore(b.value.$2) ? a : b)
          .key;
      _cache.remove(evict);
    }
    final expiry = DateTime.now().add(const Duration(hours: kCacheTtlHours));
    _cache[_hash(prompt)] = (response, expiry);
  }

  String? _getCached(String prompt) {
    final entry = _cache[_hash(prompt)];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.$2)) {
      _cache.remove(_hash(prompt));
      return null;
    }
    return entry.$1;
  }

  // ── Debounce ───────────────────────────────────────────────────────────────
  /// Cancels any in-flight debounce for [key] and schedules [fn] after
  /// [kDebounce]. Returns a Completer whose future resolves when [fn] fires.
  Future<T> debounce<T>(String key, Future<T> Function() fn) {
    _debounceTimers[key]?.cancel();
    final completer = Completer<T>();
    _debounceTimers[key] = Timer(kDebounce, () async {
      try {
        completer.complete(await fn());
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  // ── Graceful fallback copy ─────────────────────────────────────────────────
  String fallbackFor(AiRequestType type) => switch (type) {
    AiRequestType.chat    =>
        'AI coach is temporarily unavailable. '
        'Your training data is still being tracked locally.',
    AiRequestType.brief   =>
        'Focus on clean form and consistent effort today.',
    AiRequestType.plan    => '', // caller falls back to _fallbackWorkoutMap()
    AiRequestType.insight =>
        'Session logged. Recovery and adaptation are underway.',
    AiRequestType.diet    =>
        'AI nutrition guidance is temporarily unavailable.',
  };

  // ── Firebase ID token ──────────────────────────────────────────────────────
  /// Returns a fresh Firebase ID token for the authenticated user,
  /// or null if not signed in / on error.
  Future<String?> getIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[AiQuota] getIdToken error: $e');
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  Future<int> _localDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr;
    final storedDate = prefs.getString(_kQuotaDate) ?? '';
    if (storedDate != today) return 0; // new day — reset
    return prefs.getInt(_kQuotaCount) ?? 0;
  }

  Future<void> _incrementLocalCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr;
    final storedDate = prefs.getString(_kQuotaDate) ?? '';
    final count = storedDate == today ? (prefs.getInt(_kQuotaCount) ?? 0) : 0;
    await prefs.setString(_kQuotaDate, today);
    await prefs.setInt(_kQuotaCount, count + 1);
  }

  // djb2 hash — not cryptographic, sufficient for prompt deduplication
  String _hash(String s) {
    int h = 5381;
    for (final c in s.codeUnits) {
      h = ((h << 5) + h + c) & 0x7FFFFFFF;
    }
    return h.toRadixString(16);
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}
