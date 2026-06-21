// lib/services/wger_service.dart
// Fetches exercise illustration from Wger open-source API.
// Cached after first run. Falls back gracefully to null → caller shows SVG icon.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WgerService {
  WgerService._();
  static final WgerService instance = WgerService._();

  static const _cachePrefix  = 'wger_gif_v8_';
  static const _mapCacheKey  = 'wger_exercise_map_v5';
  static const _mapTsKey     = 'wger_exercise_map_ts_v5';
  static const _notFound     = '__not_found__';
  static const _timeout      = Duration(seconds: 10);
  static const _mapTtl       = Duration(days: 7);

  Map<String, String>? _map;

  // Returns an image URL for [exerciseName], or null if not found.
  Future<String?> getGifUrl(String exerciseName) async {
    final key   = _cacheKey(exerciseName);
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(key);
    if (cached != null) return cached == _notFound ? null : cached;

    final map  = await _loadMap(prefs);
    final norm = _normalize(exerciseName);

    // 1. Exact match
    String? url = map[norm];

    // 2. Substring containment
    if (url == null) {
      for (final entry in map.entries) {
        if (entry.key.length >= 4 &&
            (norm.contains(entry.key) || entry.key.contains(norm))) {
          url = entry.value;
          break;
        }
      }
    }

    // 3. Token-overlap (Jaccard ≥ 50%, min 2 shared tokens)
    // Catches "incline barbell press" ↔ "incline bench press" (2 shared: incline, press)
    url ??= _tokenMatch(norm, map);

    // 4. Variant aliases — barbell→bench, drop equipment word
    if (url == null) {
      for (final v in _variants(norm)) {
        url = map[v] ?? _tokenMatch(v, map);
        if (url != null) break;
      }
    }

    await prefs.setString(key, url ?? _notFound);
    return url;
  }

  String? _tokenMatch(String norm, Map<String, String> map) {
    final qt = norm.split(' ').toSet();
    String? bestKey;
    int bestScore = 0;
    for (final entry in map.entries) {
      final kt     = entry.key.split(' ').toSet();
      final shared = qt.intersection(kt).length;
      if (shared < 2) continue;
      final score  = shared * 100 ~/ qt.union(kt).length;
      if (score > bestScore && score >= 50) {
        bestScore = score;
        bestKey   = entry.key;
      }
    }
    return bestKey != null ? map[bestKey] : null;
  }

  /// Generates name variants to try when exact + token match both fail.
  List<String> _variants(String norm) {
    final words    = norm.split(' ');
    final variants = <String>[];
    // barbell → bench  (Wger uses "bench press" not "barbell press")
    final benched  = words.map((w) => w == 'barbell' ? 'bench' : w).join(' ');
    if (benched != norm) variants.add(benched);
    // drop equipment word to get bare movement name
    const gear = {'barbell', 'dumbbell', 'cable', 'machine', 'smith', 'ez', 'ez-bar'};
    final stripped = words.where((w) => !gear.contains(w)).join(' ');
    if (stripped != norm && stripped.length >= 4) variants.add(stripped);
    // word-order swap: "barbell incline press" → "incline barbell press"
    if (words.length == 3) variants.add('${words[1]} ${words[0]} ${words[2]}');
    return variants;
  }

  String _cacheKey(String name) => '$_cachePrefix${_normalize(name)}';

  String _normalize(String name) => name
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<Map<String, String>> _loadMap(SharedPreferences prefs) async {
    if (_map != null) return _map!;
    final saved = prefs.getString(_mapCacheKey);
    final ts    = prefs.getString(_mapTsKey);
    final age   = ts != null
        ? DateTime.now().difference(DateTime.parse(ts))
        : _mapTtl + const Duration(seconds: 1); // force refresh if no timestamp
    if (saved != null && age < _mapTtl) {
      try {
        _map = Map<String, String>.from(jsonDecode(saved) as Map);
        return _map!;
      } catch (_) {}
    }
    _map = await _fetchMap(prefs);
    return _map!;
  }

  Future<Map<String, String>> _fetchMap(SharedPreferences prefs) async {
    // Step 1: exercise_id → imageUrl
    final imageMap = <int, String>{};
    for (int offset = 0; offset <= 300; offset += 100) {
      try {
        final uri = Uri.parse(
          'https://wger.de/api/v2/exerciseimage/'
          '?format=json&limit=100&offset=$offset',
        );
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_timeout);
        if (res.statusCode != 200) break;

        final results = (jsonDecode(res.body)['results'] as List)
            .cast<Map<String, dynamic>>();
        for (final img in results) {
          final rawId  = img['exercise'] ?? img['exercise_base'];
          final baseId = rawId is int
              ? rawId
              : rawId is Map
                  ? rawId['id'] as int?
                  : int.tryParse(rawId?.toString() ?? '');
          final url = img['image'] as String?;
          if (baseId != null && url != null && !imageMap.containsKey(baseId)) {
            imageMap[baseId] = url;
          }
        }
        if (results.length < 100) break;
      } catch (_) {
        break;
      }
    }

    // Step 2: exerciseinfo — English name + match to imageMap
    final map = <String, String>{};
    for (int offset = 0; offset <= 400; offset += 100) {
      try {
        final uri = Uri.parse(
          'https://wger.de/api/v2/exerciseinfo/'
          '?format=json&limit=100&offset=$offset',
        );
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_timeout);
        if (res.statusCode != 200) break;

        final results = (jsonDecode(res.body)['results'] as List)
            .cast<Map<String, dynamic>>();

        for (final ex in results) {
          final id         = ex['id'] as int?;
          if (id == null) continue;
          final imageUrl   = imageMap[id];
          if (imageUrl == null) continue;

          final translations = (ex['translations'] as List?)
              ?.cast<Map<String, dynamic>>();
          if (translations == null) continue;

          for (final t in translations.where((t) => t['language'] == 2)) {
            final name = _normalize(t['name'] as String? ?? '');
            if (name.isNotEmpty) map[name] = imageUrl;
          }
        }
        if (results.length < 100) break;
      } catch (_) {
        break;
      }
    }

    if (kDebugMode) debugPrint('[Wger] cached ${map.length} exercises');
    await prefs.setString(_mapCacheKey, jsonEncode(map));
    await prefs.setString(_mapTsKey, DateTime.now().toIso8601String());
    return map;
  }
}
