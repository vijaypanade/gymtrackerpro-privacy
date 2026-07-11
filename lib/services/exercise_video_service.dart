import 'dart:convert';
import 'package:flutter/services.dart';

class TrainerVideo {
  final String trainer;
  final String title;
  final String youtubeId;
  final String difficulty;
  final String whySelected;

  TrainerVideo({
    required this.trainer,
    required this.title,
    required this.youtubeId,
    required this.difficulty,
    required this.whySelected,
  });

  factory TrainerVideo.fromJson(Map<String, dynamic> j) => TrainerVideo(
        trainer: j['trainer'] ?? '',
        title: j['title'] ?? '',
        youtubeId: j['youtubeId'] ?? '',
        difficulty: j['difficulty'] ?? 'beginner',
        whySelected: j['why_selected'] ?? '',
      );
}

class ExerciseVideoSet {
  final TrainerVideo? english;
  final TrainerVideo? hindi;
  ExerciseVideoSet({this.english, this.hindi});

  bool get hasAny => english != null || hindi != null;

  List<TrainerVideo> get all =>
      [english, hindi].whereType<TrainerVideo>().toList();
}

class ExerciseVideoService {
  static Map<String, dynamic>? _data;

  static Future<void> init() async {
    if (_data != null) return;
    final raw = await rootBundle
        .loadString('assets/data/exercise_videos.json');
    _data = json.decode(raw) as Map<String, dynamic>;
  }

  static String _slug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[-/]'), ' ')  // hyphens/slashes → space
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Find best match for an exercise name
  static ExerciseVideoSet? find(String exerciseName) {
    if (_data == null) return null;
    final slug = _slug(exerciseName);

    // 1. Exact match
    var entry = _data![slug];

    // 2. Try variations (singular/plural, common aliases)
    if (entry == null) {
      final variants = [
        slug.replaceAll('s_', '_'), // pull_ups → pull_up
        slug.replaceAll('_press', ''), // bench_press → bench
        '${slug}s',
        slug.replaceAll('barbell_', ''),
        slug.replaceAll('dumbbell_', 'db_'),
      ];
      for (final v in variants) {
        if (_data!.containsKey(v)) {
          entry = _data![v];
          break;
        }
      }
    }

    // 3. Partial keyword match
    if (entry == null) {
      for (final key in _data!.keys) {
        if (key == '_meta') continue;
        if (slug.contains(key) || key.contains(slug)) {
          entry = _data![key];
          break;
        }
      }
    }

    if (entry is! Map) return null;
    final m = entry as Map<String, dynamic>;

    return ExerciseVideoSet(
      english: m['english'] is Map
          ? TrainerVideo.fromJson(m['english'])
          : null,
      hindi: m['hindi'] is Map
          ? TrainerVideo.fromJson(m['hindi'])
          : null,
    );
  }
}
