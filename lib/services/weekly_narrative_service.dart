// lib/services/weekly_narrative_service.dart
// Generates a short analytical narrative comparing this week to last.
// Never generic ("great week!"). Always data-specific and identity-reinforcing.
// Returns 2–3 sentences max.

import '../models/models.dart' show HistoryEntry;

class WeeklyNarrative {
  final String headline;   // 1 analytical line — the main finding
  final String detail;     // 1 tactical follow-up
  final bool   isPositive; // drives subtle UI tint

  const WeeklyNarrative({
    required this.headline,
    required this.detail,
    required this.isPositive,
  });

  static const empty = WeeklyNarrative(
    headline:   '',
    detail:     '',
    isPositive: true,
  );

  bool get hasContent => headline.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'headline':   headline,
    'detail':     detail,
    'isPositive': isPositive,
  };

  factory WeeklyNarrative.fromJson(Map<String, dynamic> j) => WeeklyNarrative(
    headline:   j['headline']   as String? ?? '',
    detail:     j['detail']     as String? ?? '',
    isPositive: j['isPositive'] as bool?   ?? true,
  );
}

class WeeklyNarrativeService {
  WeeklyNarrativeService._();

  static WeeklyNarrative generate({
    required List<HistoryEntry> history,
    required int                plannedDaysPerWeek,
  }) {
    final now     = DateTime.now();
    final thisMonday = _monday(now);
    final lastMonday = thisMonday.subtract(const Duration(days: 7));

    final thisWeek = _entriesIn(history, thisMonday, now);
    final lastWeek = _entriesIn(history, lastMonday, thisMonday);

    if (thisWeek.isEmpty && lastWeek.isEmpty) return WeeklyNarrative.empty;

    final thisSessions   = thisWeek.length;
    final lastSessions   = lastWeek.length;
    final thisVolume     = thisWeek.fold(0.0, (s, h) => s + h.totalVolume);
    final lastVolume     = lastWeek.fold(0.0, (s, h) => s + h.totalVolume);
    final thisDuration   = thisWeek.fold(0, (s, h) => s + h.durationMinutes);
    final lastDuration   = lastWeek.fold(0, (s, h) => s + h.durationMinutes);

    final avgDurThis = thisSessions > 0 ? thisDuration ~/ thisSessions : 0;
    final avgDurLast = lastSessions > 0 ? lastDuration ~/ lastSessions  : 0;

    final sessionsUp  = thisSessions > lastSessions;
    final sessionsEq  = thisSessions == lastSessions;
    final volumeUp    = thisVolume > lastVolume * 1.04;
    final volumeDown  = thisVolume < lastVolume * 0.90 && lastVolume > 0;
    final durationUp  = avgDurThis > avgDurLast + 5;
    final durationDn  = avgDurThis < avgDurLast - 8 && avgDurLast > 0;

    final volDeltaPct = lastVolume > 0
        ? ((thisVolume / lastVolume - 1) * 100).round()
        : 0;
    final sessDelta   = thisSessions - lastSessions;

    // ── Build headline ──────────────────────────────────────
    String headline;
    bool isPositive = true;

    if (sessionsUp && volumeUp) {
      headline = 'This week improved both frequency (+${sessDelta}d) and volume (+$volDeltaPct%).';
    } else if (sessionsUp && !volumeUp) {
      headline = 'Frequency increased this week (+${sessDelta}d) while intensity stayed controlled.';
    } else if (sessionsEq && volumeUp) {
      headline = 'Same sessions, $volDeltaPct% more volume — efficiency improved.';
    } else if (sessionsEq && volumeDown) {
      headline = 'Volume dropped $volDeltaPct% vs last week — intentional or recovery?';
      isPositive = false;
    } else if (!sessionsUp && lastSessions > 0) {
      headline = '$thisSessions ${thisSessions == 1 ? "session" : "sessions"} completed this week. Rhythm builds from consistency over time.';
      isPositive = false;
    } else if (thisSessions > 0) {
      headline = '$thisSessions training session${thisSessions > 1 ? "s" : ""} logged this week.';
    } else {
      headline = 'No sessions logged this week.';
      isPositive = false;
    }

    // ── Build detail ────────────────────────────────────────
    String detail;

    if (durationUp && isPositive) {
      detail = 'Average session length increased to ${avgDurThis}min — '
          'sustain this if recovery holds.';
    } else if (durationDn && avgDurLast > 0) {
      detail = 'Shorter sessions this week (${avgDurThis}min avg vs ${avgDurLast}min). '
          '${isPositive ? "Efficiency gain." : "Check whether fatigue shortened output."}';
    } else if (volumeUp && thisSessions <= lastSessions) {
      detail = 'Volume growth came from density, not extra sessions — high-quality signal.';
    } else if (!isPositive && plannedDaysPerWeek > 0) {
      final target = plannedDaysPerWeek;
      detail = 'Rhythm returns naturally. $target sessions next week keeps adaptation on track.';
    } else if (thisVolume > 0) {
      detail = 'Recovery and adaptation are pacing the next progression block.';
    } else {
      detail = 'Next week: prioritise session frequency over intensity.';
    }

    return WeeklyNarrative(
      headline:   headline,
      detail:     detail,
      isPositive: isPositive,
    );
  }

  static DateTime _monday(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static List<HistoryEntry> _entriesIn(
    List<HistoryEntry> all,
    DateTime from,
    DateTime to,
  ) {
    return all.where((h) {
      final d = DateTime.tryParse(h.date);
      return d != null && !d.isBefore(from) && d.isBefore(to);
    }).toList();
  }
}
