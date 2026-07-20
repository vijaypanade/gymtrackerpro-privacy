// lib/services/exercise_gif_service.dart
//
// Fetches animated exercise GIFs from the open-source ExerciseDB API.
// • No API key required
// • Cache stored permanently (30-day TTL) in SharedPreferences
// • Exact + fuzzy name matching for our exercise list
// • Falls back to null → caller shows icon / YouTube thumbnail

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseGifService {
  ExerciseGifService._();
  static final ExerciseGifService instance = ExerciseGifService._();

  // ── Cache keys ──────────────────────────────────────────────────────────────
  static const _mapKey    = 'exgif_map_v1';
  static const _mapTsKey  = 'exgif_map_ts_v1';
  static const _gifPrefix = 'exgif_v1_';
  static const _notFound  = '__nf__';
  static const _mapTtl    = Duration(days: 30);
  static const _timeout   = Duration(seconds: 12);

  // ExerciseDB open-source deployment — no API key needed
  static const _baseUrl   = 'https://exercisedb-api.vercel.app/api/v1/exercises';

  Map<String, String>? _nameToGif; // normalized-name → gifUrl

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Returns animated GIF URL for [exerciseName], or null if unavailable.
  Future<String?> getGifUrl(String exerciseName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_gifPrefix${_norm(exerciseName)}';

    // Per-exercise cache hit
    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached == _notFound ? null : cached;

    // Load/build the full name→gif map
    final map = await _loadMap(prefs);
    final url = _lookup(exerciseName, map);

    await prefs.setString(cacheKey, url ?? _notFound);
    return url;
  }

  /// Call once at startup (background) to warm the cache before user opens cards.
  Future<void> prefetch() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadMap(prefs);
  }

  // ── Map loader ───────────────────────────────────────────────────────────────

  Future<Map<String, String>> _loadMap(SharedPreferences prefs) async {
    if (_nameToGif != null) return _nameToGif!;

    final saved = prefs.getString(_mapKey);
    final tsRaw = prefs.getString(_mapTsKey);
    final age   = tsRaw != null
        ? DateTime.now().difference(DateTime.parse(tsRaw))
        : _mapTtl + const Duration(seconds: 1);

    if (saved != null && age < _mapTtl) {
      try {
        _nameToGif = Map<String, String>.from(jsonDecode(saved) as Map);
        return _nameToGif!;
      } catch (_) {}
    }

    _nameToGif = await _fetchAll(prefs);
    return _nameToGif!;
  }

  // ── Fetch all exercises from ExerciseDB ─────────────────────────────────────

  Future<Map<String, String>> _fetchAll(SharedPreferences prefs) async {
    final map = <String, String>{};
    const pageSize = 100;
    int offset = 0;

    while (true) {
      try {
        final uri = Uri.parse('$_baseUrl?limit=$pageSize&offset=$offset');
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_timeout);

        if (res.statusCode != 200) break;

        final body = jsonDecode(res.body) as Map<String, dynamic>;

        // Handle both response shapes from different ExerciseDB deployments:
        // Shape A: { "data": { "exercises": [...] } }
        // Shape B: { "exercises": [...] }
        // Shape C: [ {...}, {...} ]  (direct array)
        List<dynamic> exercises;
        if (body.containsKey('data')) {
          final data = body['data'] as Map<String, dynamic>;
          exercises = (data['exercises'] as List?) ?? [];
        } else if (body.containsKey('exercises')) {
          exercises = body['exercises'] as List;
        } else {
          break;
        }

        if (exercises.isEmpty) break;

        for (final ex in exercises.cast<Map<String, dynamic>>()) {
          final name   = ex['name'] as String?;
          final gifUrl = ex['gifUrl'] as String?;
          if (name != null && gifUrl != null && gifUrl.isNotEmpty) {
            map[_norm(name)] = gifUrl;
          }
        }

        if (exercises.length < pageSize) break;
        offset += pageSize;
      } catch (e) {
        debugPrint('[ExerciseGifService] fetch error at offset=$offset: $e');
        break;
      }
    }

    if (map.isNotEmpty) {
      await prefs.setString(_mapKey, jsonEncode(map));
      await prefs.setString(_mapTsKey, DateTime.now().toIso8601String());
      debugPrint('[ExerciseGifService] cached ${map.length} exercises');
    }

    return map;
  }

  // ── Lookup with fallback tiers ───────────────────────────────────────────────

  String? _lookup(String name, Map<String, String> map) {
    final n = _norm(name);

    // 1. Exact
    if (map.containsKey(n)) return map[n];

    // 2. Equipment-word variants (barbell→bench, drop equipment prefix, word order)
    //    These are safe structural substitutions for the same exercise.
    for (final v in _variants(n)) {
      if (map.containsKey(v)) return map[v];
    }

    // 3. Token overlap ≥ 70%, minimum 2 shared tokens (raised from 50% to avoid false matches)
    final result = _tokenMatch(n, map);
    if (result != null) return result;

    return null;
  }

  String? _tokenMatch(String norm, Map<String, String> map) {
    final qt = norm.split(' ').toSet();
    String? bestKey;
    int bestScore = 0;
    for (final entry in map.entries) {
      final kt    = entry.key.split(' ').toSet();
      final shared = qt.intersection(kt).length;
      if (shared < 2) continue;
      final score = shared * 100 ~/ qt.union(kt).length;
      if (score > bestScore && score >= 70) {
        bestScore = score;
        bestKey   = entry.key;
      }
    }
    return bestKey != null ? map[bestKey] : null;
  }

  List<String> _variants(String norm) {
    final words    = norm.split(' ');
    final variants = <String>[];
    // barbell → bench  (DB sometimes uses "bench" instead of "barbell")
    final benched  = words.map((w) => w == 'barbell' ? 'bench' : w).join(' ');
    if (benched != norm) variants.add(benched);
    // drop equipment word
    const gear = {'barbell', 'dumbbell', 'cable', 'machine', 'smith', 'ez', 'kettlebell'};
    final stripped = words.where((w) => !gear.contains(w)).join(' ');
    if (stripped != norm && stripped.length >= 4) variants.add(stripped);
    // 3-word swap: "barbell incline press" ↔ "incline barbell press"
    if (words.length == 3) variants.add('${words[1]} ${words[0]} ${words[2]}');
    return variants;
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
