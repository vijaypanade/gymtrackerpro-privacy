import 'package:flutter/foundation.dart';

@immutable
class WorkoutLog {
  final String exercise;
  final DateTime date;
  final double weight;
  final int reps;
  final int minutes;
  final String? muscleGroup;

  static const int _dataVersion = 1;

  const WorkoutLog({
    required this.exercise,
    required this.date,
    required this.weight,
    required this.reps,
    this.minutes = 0,
    this.muscleGroup,
  });

  /// ─────────────────────────────────────────────
  /// NORMALIZATION (VERY IMPORTANT)
  /// ─────────────────────────────────────────────
  String get normalizedExercise =>
      exercise.trim().toLowerCase().replaceAll(' ', '_');

  DateTime get parsedDate => date;

  double get volume => weight * (reps > 0 ? reps : 1);

  bool get isBodyweight => weight == 0 && reps > 0;

  bool get isTimed => minutes > 0 && weight == 0 && reps == 0;

  WorkoutLog copyWith({
    String? exercise,
    DateTime? date,
    double? weight,
    int? reps,
    int? minutes,
    String? muscleGroup,
  }) {
    return WorkoutLog(
      exercise: exercise ?? this.exercise,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      minutes: minutes ?? this.minutes,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }

  /// ─────────────────────────────────────────────
  /// JSON
  /// ─────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'v': _dataVersion,
        'exercise': normalizedExercise,
        'date': date.toIso8601String(),
        'weight': weight,
        'reps': reps,
        'minutes': minutes,
        'muscleGroup': muscleGroup,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    // ── Date parsing (STRICT SAFE) ──
    DateTime parsedDate;
    final rawDate = json['date'];

    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0); // safer than now()
    }

    // ── Weight ──
    double parsedWeight = 0;
    final w = json['weight'];
    if (w is num) {
      parsedWeight = w.toDouble();
    } else if (w != null) {
      parsedWeight = double.tryParse(w.toString()) ?? 0;
    }
    parsedWeight = parsedWeight.clamp(0, 500).toDouble();

    // ── Reps ──
    int parsedReps = 0;
    final r = json['reps'];
    if (r is int) {
      parsedReps = r;
    } else if (r is num) {
      parsedReps = r.toInt();
    } else if (r != null) {
      parsedReps = int.tryParse(r.toString()) ?? 0;
    }
    parsedReps = parsedReps.clamp(0, 999);

    // ── Minutes ──
    int parsedMinutes = 0;
    final m = json['minutes'];
    if (m is int) {
      parsedMinutes = m;
    } else if (m is num) {
      parsedMinutes = m.toInt();
    } else if (m != null) {
      parsedMinutes = int.tryParse(m.toString()) ?? 0;
    }
    parsedMinutes = parsedMinutes.clamp(0, 600);

    // ── Muscle ──
    final mg = json['muscleGroup'];
    final String? muscleGroup =
        (mg is String && mg.trim().isNotEmpty)
            ? mg.trim().toLowerCase()
            : null;

    return WorkoutLog(
      exercise: json['exercise']?.toString().trim().toLowerCase() ?? '',
      date: parsedDate,
      weight: parsedWeight,
      reps: parsedReps,
      minutes: parsedMinutes,
      muscleGroup: muscleGroup,
    );
  }

  /// ─────────────────────────────────────────────
  /// SAFE FLOAT COMPARISON
  /// ─────────────────────────────────────────────
  bool _doubleEquals(double a, double b) =>
      (a - b).abs() < 0.0001;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkoutLog &&
        other.exercise == exercise &&
        other.date == date &&
        _doubleEquals(other.weight, weight) &&
        other.reps == reps &&
        other.minutes == minutes &&
        other.muscleGroup == muscleGroup;
  }

  @override
  int get hashCode => Object.hash(
        exercise,
        date,
        weight.round(), // safer
        reps,
        minutes,
        muscleGroup,
      );

  @override
  String toString() =>
      'WorkoutLog(exercise: $exercise, date: ${date.toIso8601String()}, '
      'weight: $weight, reps: $reps, minutes: $minutes, muscleGroup: $muscleGroup)';
}