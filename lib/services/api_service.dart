// lib/services/api_service.dart — production-safe
//
// Protection layers applied here:
//   - Firebase Auth ID token in every request (server verifies)
//   - AiQuotaService gate: kill switch, cooldown, daily cap, cache check
//   - Retry rules: NEVER retry billing/quota/auth errors (4xx)
//                  ONLY retry transient server/network failures (500+, timeout)
//   - Exponential backoff: 2s → 4s → give up (max 2 retries)
//   - Caches successful responses via AiQuotaService

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_quota_service.dart';

class ApiService {
  static const String _url  = "https://askai-3iarja6fya-uc.a.run.app";
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 2; // max additional attempts after first failure

  /// Send a prompt to the Gemini backend.
  ///
  /// [type]      — drives model routing and fallback copy.
  /// [isPremium] — Premium users get higher limits and Pro model for plans.
  /// [timeout]   — defaults to 30 s. Pass longer for plan/diet generation.
  ///
  /// Returns a clean string on success, or a ⚠️-prefixed error string on failure.
  /// Never throws.
  static Future<String> askAI(
    String prompt, {
    Duration timeout = _defaultTimeout,
    AiRequestType type = AiRequestType.chat,
    bool isPremium = false,
  }) async {
    final quota = AiQuotaService.instance;

    // ── Quota gate ──────────────────────────────────────────────────────────
    final check = await quota.check(isPremium: isPremium, prompt: prompt);

    if (!check.allowed) {
      return '⚠️ ${check.denyReason}';
    }

    if (check.isCacheHit) {
      debugPrint('[AI] cache hit — skipping network request');
      return check.cachedResponse!;
    }

    // ── Get auth token (best-effort — function still works if absent) ────────
    final idToken = await quota.getIdToken();
    final model   = quota.modelFor(type, isPremium: isPremium);

    // ── Request loop with safe retry ────────────────────────────────────────
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('[AI] attempt ${attempt + 1}/${ _maxRetries + 1}'
            ' | model: $model | type: ${type.name}');

        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        };
        if (idToken != null) headers['Authorization'] = 'Bearer $idToken';

        final response = await http
            .post(
              Uri.parse(_url),
              headers: headers,
              body: jsonEncode({
                'prompt': prompt,
                'model':  model,
                'type':   type.name,
              }),
            )
            .timeout(timeout);

        debugPrint('[AI] status ${response.statusCode}');

        // ── 200 OK ──────────────────────────────────────────────────────────
        if (response.statusCode == 200) {
          final body = response.body.trim();

          if (body.isEmpty) {
            return _failOrRetry(attempt, 'Empty response from AI.');
          }
          if (!_isJson(body)) {
            return _failOrRetry(attempt, 'AI servers are busy. Please try again.');
          }

          dynamic decoded;
          try {
            decoded = jsonDecode(body);
          } catch (_) {
            return _failOrRetry(attempt, 'Invalid AI response. Please try again.');
          }

          if (decoded is Map<String, dynamic>) {
            final reply = decoded['reply'];
            if (reply != null && reply.toString().trim().isNotEmpty) {
              final clean = _stripFences(reply.toString().trim());
              debugPrint('[AI] success (${clean.length} chars)');
              // Record quota and cache
              await quota.record(type: type);
              quota.store(prompt, clean);
              return clean;
            }
            if (decoded.containsKey('error')) {
              return '⚠️ ${decoded["error"]}';
            }
          }
          return '⚠️ Invalid AI response format.';
        }

        // ── 4xx — NEVER retry (billing, quota, auth, bad request) ───────────
        if (response.statusCode == 401) return '⚠️ Authentication error. Please sign in again.';
        if (response.statusCode == 402) return '⚠️ AI billing limit reached. Contact support.';
        if (response.statusCode == 403) return '⚠️ Access denied. Please try again later.';
        if (response.statusCode == 429) {
          debugPrint('[AI] 429 body: ${response.body}');
          return '⚠️ Too many requests. Wait a moment and try again.';
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          // Log the raw body so the real Gemini error is visible in debug output.
          debugPrint('[AI] 4xx body: ${response.body}');
          String msg = 'Request failed (${response.statusCode}).';
          try {
            final errBody = jsonDecode(response.body);
            if (errBody is Map && errBody['error'] != null) {
              msg = errBody['error'].toString();
            }
          } catch (_) {}
          return '⚠️ $msg';
        }

        // ── 5xx — retry with exponential backoff ────────────────────────────
        if (response.statusCode >= 500) {
          final msg = 'Server error (${response.statusCode}).';
          if (attempt < _maxRetries) {
            await _backoff(attempt);
            continue;
          }
          return '⚠️ $msg AI servers may be busy. Try again in a few minutes.';
        }

        return '⚠️ Unexpected response (${response.statusCode}).';

      } on Exception catch (e) {
        debugPrint('[AI] exception attempt $attempt: $e');
        final err = e.toString();

        // Timeout and network errors are retriable
        if (attempt < _maxRetries) {
          await _backoff(attempt);
          continue;
        }

        if (err.contains('TimeoutException')) {
          return '⚠️ Request timed out. Please try again.';
        }
        if (err.contains('SocketException') || err.contains('HandshakeException')) {
          return '⚠️ No internet. Please check your connection.';
        }
        return '⚠️ Network error. Please try again.';
      }
    }

    return '⚠️ Failed after retries. Please try again.';
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<void> _backoff(int attempt) async {
    // 2s → 4s (capped) with no jitter needed for simple mobile client
    final delay = Duration(seconds: (attempt + 1) * 2);
    debugPrint('[AI] backoff ${delay.inSeconds}s');
    await Future.delayed(delay);
  }

  static Future<String> _failOrRetry(int attempt, String message) async {
    if (attempt < _maxRetries) {
      await _backoff(attempt);
      return ''; // signal caller to continue loop
    }
    return '⚠️ $message';
  }

  static bool _isJson(String body) {
    final t = body.trim().toLowerCase();
    if (t.startsWith('<html') || t.startsWith('<!doctype') ||
        t.contains('gateway timeout') || t.contains('bad gateway')) {
      return false;
    }
    return body.trim().startsWith('{') || body.trim().startsWith('[');
  }

  static String _stripFences(String s) => s
      .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
      .replaceAll(RegExp(r'\s*```$'), '')
      .trim();
}
