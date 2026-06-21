import '../data/exercise_data.dart';
import '../models/memory_models.dart';
import '../models/split_template.dart';

class ExerciseCandidateService {
  ExerciseCandidateService._();

  static const int maxCandidates = 40;
  static const int maxPerTargetMuscle = 8;

  static List<Map<String, dynamic>> select({
    required SplitStyle splitStyle,
    required List<String> targetMuscles,
    required int daysPerWeek,
    required String level,
    required bool travelMode,
    required bool bodyweightOnly,
    required List<ExerciseMemory> recentExerciseHistory,
  }) {
    final targets = _expandTargets(
      targetMuscles.isNotEmpty
          ? targetMuscles
          : _musclesForSplit(splitStyle, daysPerWeek),
    );
    final recent = recentExerciseHistory.map((e) => _norm(e.name)).toSet();
    final selected = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final target in targets) {
      final pool = ExerciseData.list
          .where((e) => _matchesTarget(e, target))
          .where((e) => _isAvailable(e, travelMode || bodyweightOnly))
          .toList()
        ..sort((a, b) => _score(b, target, recent, level)
            .compareTo(_score(a, target, recent, level)));

      for (final exercise in pool.take(maxPerTargetMuscle)) {
        final id = exercise['id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        selected.add(exercise);
        if (selected.length >= maxCandidates) return selected;
      }
    }

    if (selected.length < 24) {
      final fallback = ExerciseData.list
          .where((e) => _isAvailable(e, travelMode || bodyweightOnly))
          .where((e) => _matchesAnyTarget(e, targets))
          .toList()
        ..sort((a, b) => _score(b, '', recent, level)
            .compareTo(_score(a, '', recent, level)));
      for (final exercise in fallback) {
        final id = exercise['id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        selected.add(exercise);
        if (selected.length >= maxCandidates) break;
      }
    }

    return selected;
  }

  static String toPromptLines(List<Map<String, dynamic>> exercises) {
    return exercises.map((e) {
      final id = e['id']?.toString() ?? '';
      final name = e['name']?.toString() ?? '';
      final muscle = e['muscle']?.toString() ?? '';
      final equipment = _cap(e['equipment']?.toString() ?? 'unknown');
      final movement = _cap(e['movement']?.toString() ?? e['type']?.toString() ?? '');
      return '$id|$name|$muscle|$equipment|$movement';
    }).join('\n');
  }

  static List<String> _musclesForSplit(SplitStyle splitStyle, int daysPerWeek) {
    if (splitStyle == SplitStyle.aiAdaptive) {
      return const ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs'];
    }
    final template = SplitTemplate.forStyle(splitStyle, daysPerWeek);
    return template.trainingDays.expand((d) => d.muscles).toSet().toList();
  }

  static List<String> _expandTargets(List<String> raw) {
    final out = <String>{};
    for (final item in raw.map(_norm).where((m) => m.isNotEmpty)) {
      switch (item) {
        case 'arms':
          out.addAll(['biceps', 'triceps']);
          break;
        case 'legs':
          out.addAll(['quads', 'hamstrings', 'glutes', 'calves']);
          break;
        case 'quadriceps':
          out.add('quads');
          break;
        default:
          out.add(item);
      }
    }
    if (out.isEmpty) {
      out.addAll(['chest', 'back', 'shoulders', 'biceps', 'triceps', 'quads']);
    }
    return out.toList();
  }

  static bool _isAvailable(Map<String, dynamic> e, bool bodyweightOnly) {
    if (!bodyweightOnly) return true;
    return e['bodyweight'] == true || _norm(e['equipment']) == 'bodyweight';
  }

  static bool _matchesAnyTarget(Map<String, dynamic> e, List<String> targets) {
    return targets.any((target) => _matchesTarget(e, target));
  }

  static bool _matchesTarget(Map<String, dynamic> e, String target) {
    final haystack = [
      e['id'],
      e['name'],
      e['muscle'],
      e['type'],
    ].map(_norm).join(' ');

    if (target == 'legs') {
      return haystack.contains('legs') ||
          haystack.contains('quad') ||
          haystack.contains('hamstring') ||
          haystack.contains('glute') ||
          haystack.contains('calf');
    }
    if (target == 'quads' || target == 'hamstrings' ||
        target == 'glutes' || target == 'calves') {
      return haystack.contains(target) || haystack.contains('legs');
    }
    return haystack.contains(target);
  }

  static int _score(
    Map<String, dynamic> e,
    String target,
    Set<String> recent,
    String level,
  ) {
    final id = _norm(e['id']);
    final name = _norm(e['name']);
    final movement = _norm(e['movement']);
    final equipment = _norm(e['equipment']);
    var score = 0;

    if (!recent.contains(name) && !recent.contains(id)) score += 50;
    if (movement == 'compound') score += level.toLowerCase() == 'beginner' ? 20 : 30;
    if (target.isNotEmpty && id.contains(target)) score += 18;
    if (equipment == 'machine' && level.toLowerCase() == 'beginner') score += 8;
    if (equipment == 'barbell' && level.toLowerCase() == 'advanced') score += 8;
    if (name.contains('behind the neck')) score -= 25;
    return score;
  }

  static String _norm(Object? value) =>
      (value?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static String _cap(String value) {
    if (value.isEmpty) return value;
    final clean = value.replaceAll('_', ' ');
    return clean[0].toUpperCase() + clean.substring(1);
  }
}
