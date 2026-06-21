// lib/utils/exercise_ai_badge_helper.dart
// Deterministic badge engine — purely rule-based, no network.
// assignGroupBadges() enforces per-section cap + adjacent-duplicate avoidance.

abstract final class ExerciseAIBadgeHelper {
  /// Assign badges to a sorted list within one muscle section.
  /// Enforces: max 2 'Best for Strength', no adjacent duplicate labels.
  static List<String?> assignGroupBadges(
    List<Map<String, dynamic>> exercises, {
    required String goal,
    required String level,
    required String dayTitle,
  }) {
    final result = <String?>[];
    var strengthCount = 0;
    String? prev;
    for (final ex in exercises) {
      var badge = _compute(ex,
          goal: goal, level: level, dayTitle: dayTitle,
          strengthCount: strengthCount);
      if (badge != null && badge == prev) badge = _rotate(ex, badge);
      if (badge == 'Best for Strength') strengthCount++;
      result.add(badge);
      prev = badge;
    }
    return result;
  }

  /// Single badge for a standalone exercise (no section context).
  /// Use assignGroupBadges() in grouped views for cap + adjacency behaviour.
  static String? getBadge(
    Map<String, dynamic> exercise, {
    required String goal,
    required String level,
    required String dayTitle,
  }) =>
      _compute(exercise,
          goal: goal, level: level, dayTitle: dayTitle, strengthCount: 0);

  // ── Internal ─────────────────────────────────────────────────────────────

  static String? _compute(
    Map<String, dynamic> ex, {
    required String goal,
    required String level,
    required String dayTitle,
    required int strengthCount,
  }) {
    final movement  = (ex['movement']  as String? ?? '').toLowerCase();
    final equipment = (ex['equipment'] as String? ?? '').toLowerCase();
    final muscle    = (ex['muscle']    as String? ?? '').toLowerCase();

    // Beginner-safe isolation/machine → Recovery Friendly
    if (level == 'beginner' &&
        equipment != 'barbell' &&
        movement != 'compound') {
      return 'Recovery Friendly';
    }

    // Machine → Stable Movement (controlled, guided hypertrophy)
    if (equipment == 'machine') return 'Stable Movement';

    // Cable isolation → Joint Friendly (constant tension, low joint stress)
    if (equipment == 'cable' && movement != 'compound') return 'Joint Friendly';

    // Strength goal + barbell compound → Best for Strength (cap 2), else Power Builder
    if (goal == 'strength' &&
        equipment == 'barbell' &&
        movement == 'compound') {
      return strengthCount < 2 ? 'Best for Strength' : 'Power Builder';
    }

    // Fat loss path
    if (goal == 'fat_loss') {
      if (muscle == 'cardio') return 'Fat Loss';
      if (movement == 'compound') return 'High ROI';
    }

    // Muscle gain + compound → Volume Builder
    if (goal == 'muscle_gain' && movement == 'compound') return 'Volume Builder';

    // Any isolation movement → Volume Builder
    if (movement == 'isolation') return 'Volume Builder';

    // Compound matching day split → AI Pick; otherwise Athletic Transfer
    if (movement == 'compound') {
      final day = dayTitle.toLowerCase();
      if ((day.contains('push') || day.contains('chest')) &&
          (muscle == 'chest' || muscle == 'shoulders')) return 'AI Pick';
      if ((day.contains('pull') || day.contains('back')) &&
          muscle == 'back') return 'AI Pick';
      if (day.contains('legs') && muscle == 'legs') return 'AI Pick';
      if (day.contains('full') || day.contains('total')) return 'AI Pick';
      return 'Athletic Transfer';
    }

    return null;
  }

  /// Returns an alternative badge to avoid adjacent duplicates.
  static String? _rotate(Map<String, dynamic> ex, String badge) {
    final movement  = (ex['movement']  as String? ?? '').toLowerCase();
    final equipment = (ex['equipment'] as String? ?? '').toLowerCase();
    return switch (badge) {
      'Best for Strength' => 'Power Builder',
      'Power Builder'     => 'High ROI',
      'High ROI'          => 'Volume Builder',
      'Volume Builder'    => movement == 'compound' ? 'High ROI' : 'Joint Friendly',
      'AI Pick'           => 'Athletic Transfer',
      'Athletic Transfer' => movement == 'compound' ? 'Power Builder' : null,
      'Stable Movement'   => equipment == 'machine' ? null : 'Joint Friendly',
      'Recovery Friendly' => null,
      _                   => null,
    };
  }
}
