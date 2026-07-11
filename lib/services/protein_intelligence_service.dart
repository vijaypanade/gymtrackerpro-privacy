// lib/services/protein_intelligence_service.dart
//
// Protein Intelligence v1 — lightweight analysis on top of MealLogService.
// Pure heuristics, no AI model. All expensive work is computed at most once
// per day and cached in SharedPreferences.
//
//   • todayAdherencePct   — today's protein vs goal (recovery signal input)
//   • weeklyOnTarget      — days on target in the last 7 (Weekly Story slide)
//   • getMemory           — 30-day protein habits (coach personal memory)
//   • observation cadence — at most one observation every few days

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meal_log_service.dart';

const _kMemoryCacheKey  = 'protein_intel_memory_v1';
const _kObservationKey  = 'protein_intel_obs_last_v1';
const _kObservationGapDays = 3;

/// 30-day protein habit summary. All fields are '' when no clear pattern.
class ProteinMemory {
  final String mostFrequentSource; // most logged source overall
  final String eveningSource;      // most common source after 6 PM
  final String snackSource;        // most common snack-slot source (post-workout proxy)
  final String finisherSource;     // most common last-entry-of-day source
  final String consistentSource;   // source appearing on the most distinct days
  final int daysWithLogs;

  const ProteinMemory({
    required this.mostFrequentSource,
    required this.eveningSource,
    required this.snackSource,
    required this.finisherSource,
    required this.consistentSource,
    required this.daysWithLogs,
  });

  bool get hasSignal => daysWithLogs >= 5 && mostFrequentSource.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'mostFrequentSource': mostFrequentSource,
        'eveningSource':      eveningSource,
        'snackSource':        snackSource,
        'finisherSource':     finisherSource,
        'consistentSource':   consistentSource,
        'daysWithLogs':       daysWithLogs,
      };

  factory ProteinMemory.fromJson(Map<String, dynamic> j) => ProteinMemory(
        mostFrequentSource: j['mostFrequentSource'] as String? ?? '',
        eveningSource:      j['eveningSource'] as String? ?? '',
        snackSource:        j['snackSource'] as String? ?? '',
        finisherSource:     j['finisherSource'] as String? ?? '',
        consistentSource:   j['consistentSource'] as String? ?? '',
        daysWithLogs:       j['daysWithLogs'] as int? ?? 0,
      );
}

class ProteinIntelligenceService {
  ProteinIntelligenceService._();

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // Strip the portion suffix: "Whey (1 scoop)" → "Whey".
  static String _baseName(String food) {
    final i = food.indexOf('(');
    return (i > 0 ? food.substring(0, i) : food).trim();
  }

  // ── Today's adherence — recovery signal input ──────────────

  /// Today's protein intake as a percentage of [proteinGoalG].
  /// Returns null when the goal is invalid or nothing was ever logged today.
  static Future<double?> todayAdherencePct(int proteinGoalG) async {
    if (proteinGoalG <= 0) return null;
    final log = await MealLogService.getTodayLog('');
    final consumed =
        log.entries.values.fold<int>(0, (s, e) => s + e.protein);
    return consumed / proteinGoalG * 100.0;
  }

  // ── Weekly on-target — Weekly Story slide ──────────────────

  /// Days in the last 7 where protein reached ≥95% of goal,
  /// plus how many of those days had any log at all.
  static Future<({int onTarget, int daysWithLogs})> weeklyOnTarget(
      int proteinGoalG) async {
    if (proteinGoalG <= 0) return (onTarget: 0, daysWithLogs: 0);
    final days = await MealLogService.getRecentDays('', days: 7);
    int onTarget = 0;
    int logged   = 0;
    for (final day in days) {
      if (day.entries.isEmpty) continue;
      logged++;
      final protein =
          day.entries.values.fold<int>(0, (s, e) => s + e.protein);
      if (protein >= proteinGoalG * 0.95) onTarget++;
    }
    return (onTarget: onTarget, daysWithLogs: logged);
  }

  // ── 30-day memory — computed once per day, cached ──────────

  static Future<ProteinMemory> getMemory() async {
    final prefs = await SharedPreferences.getInstance();

    // Serve today's cached analysis if present.
    final raw = prefs.getString(_kMemoryCacheKey);
    if (raw != null) {
      try {
        final j = json.decode(raw) as Map<String, dynamic>;
        if (j['date'] == _today()) {
          return ProteinMemory.fromJson(j['memory'] as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    final memory = await _analyse();
    try {
      await prefs.setString(_kMemoryCacheKey,
          json.encode({'date': _today(), 'memory': memory.toJson()}));
    } catch (e) {
      debugPrint('ProteinIntelligence cache error: $e');
    }
    return memory;
  }

  static Future<ProteinMemory> _analyse() async {
    final days = await MealLogService.getRecentDays('', days: 30);

    final totalCounts   = <String, int>{}; // source → total logs
    final eveningCounts = <String, int>{}; // source → logs after 6 PM
    final snackCounts   = <String, int>{}; // source → snack-slot logs
    final finisherCounts = <String, int>{}; // source → times it closed the day
    final dayCounts     = <String, Set<String>>{}; // source → distinct dates
    int daysWithLogs = 0;

    for (final day in days) {
      if (day.entries.isEmpty) continue;
      daysWithLogs++;

      final entries = day.entries.values.toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

      for (final e in entries) {
        final name = _baseName(e.foods.first);
        if (name.isEmpty) continue;
        totalCounts[name] = (totalCounts[name] ?? 0) + 1;
        dayCounts.putIfAbsent(name, () => {}).add(day.date);
        if (e.loggedAt.hour >= 18) {
          eveningCounts[name] = (eveningCounts[name] ?? 0) + 1;
        }
        if (e.mealType == 'Snack') {
          snackCounts[name] = (snackCounts[name] ?? 0) + 1;
        }
      }

      final lastName = _baseName(entries.last.foods.first);
      if (lastName.isNotEmpty) {
        finisherCounts[lastName] = (finisherCounts[lastName] ?? 0) + 1;
      }
    }

    String top(Map<String, int> counts, {int minCount = 3}) {
      if (counts.isEmpty) return '';
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.value >= minCount ? sorted.first.key : '';
    }

    String topByDays() {
      if (dayCounts.isEmpty) return '';
      final sorted = dayCounts.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      return sorted.first.value.length >= 5 ? sorted.first.key : '';
    }

    return ProteinMemory(
      mostFrequentSource: top(totalCounts),
      eveningSource:      top(eveningCounts),
      snackSource:        top(snackCounts),
      finisherSource:     top(finisherCounts),
      consistentSource:   topByDays(),
      daysWithLogs:       daysWithLogs,
    );
  }

  // ── Observation cadence — one every few days at most ───────
  // Cooldown is per surface ('hub', 'post', 'evening') so one memory
  // mention doesn't echo on every surface the same day, and no surface
  // repeats itself within [_kObservationGapDays].

  static String _obsKey(String surface) =>
      surface == 'hub' ? _kObservationKey : '${_kObservationKey}_$surface';

  static Future<bool> shouldShowObservation({String surface = 'hub'}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_obsKey(surface));
    if (last == null) return true;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return true;
    return DateTime.now().difference(lastDate).inDays >= _kObservationGapDays;
  }

  static Future<void> markObservationShown({String surface = 'hub'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _obsKey(surface), DateTime.now().toIso8601String());
  }

  /// One calm observational sentence from memory, or '' when no clear habit.
  static String buildObservation(ProteinMemory memory) {
    if (!memory.hasSignal) return '';
    if (memory.consistentSource.isNotEmpty) {
      return '${memory.consistentSource} has become your go-to protein.';
    }
    if (memory.finisherSource.isNotEmpty) {
      return 'You usually finish with ${memory.finisherSource.toLowerCase()}.';
    }
    return '${memory.mostFrequentSource} is your usual choice.';
  }
}
