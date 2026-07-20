import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

@immutable
class WorkoutLog {
  final String exercise;
  final DateTime date;

  /// Actual weight lifted by the athlete.
  ///
  /// Used for:
  ///   - PR detection
  ///   - Volume calculations
  ///   - Analytics
  ///   - AthleteBrain learning
  ///
  /// In adaptive sessions this is the weight actually performed (e.g. 95 kg),
  /// which may differ from what the planner prescribed (see [plannedWeight]).
  final double weight;

  final int reps;
  final int minutes;
  final String? muscleGroup;

  // RFC-002.4: soft-delete field. Null = active. Non-null = deleted at UTC time.
  final DateTime? deletedAt;

  /// Original planner target at the time the adaptive session was started.
  ///
  /// Null for all legacy logs and for non-adaptive sessions (i.e. when the
  /// athlete chose "Use Original Plan" or no adaptive session was active).
  ///
  /// Used for:
  ///   - Progressive overload (GhostCopyService progresses from this value)
  ///   - Plan vs Execution gap (AthleteBrain learning signal)
  ///
  /// IMPORTANT: GhostCopyService must use `plannedWeight ?? weight` so that a
  /// temporary adaptive deload never permanently reduces next week's target.
  ///
  /// RFC-006.1 known limitation: if the athlete edits a completed set after
  /// it was first logged (updateSet → _syncLog re-sync path), the re-sync
  /// does not carry plannedWeight and this field becomes null. See RFC-006.1.
  final double? plannedWeight;

  static const int _dataVersion = 1;

  // Sentinel for copyWith() — distinguishes "not provided" from "explicitly null".
  static const Object _kSentinel = Object();

  // ── Crashlytics override for testing (§3.4 / G-13) ──
  @visibleForTesting
  static void Function(Map<String, dynamic>)? crashlyticsReporter;

  // App version string stamped in Crashlytics metadata.
  static const String _appVersion = '2.4.2+45';

  const WorkoutLog({
    required this.exercise,
    required this.date,
    required this.weight,
    required this.reps,
    this.minutes = 0,
    this.muscleGroup,
    this.deletedAt,      // null = active
    this.plannedWeight,  // null = non-adaptive or legacy log
  });

  // ── Soft-delete state ────────────────────────────────────────────────────

  /// True when this log has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  // ─────────────────────────────────────────────
  // NORMALIZATION (VERY IMPORTANT)
  // ─────────────────────────────────────────────
  String get normalizedExercise =>
      exercise.trim().toLowerCase().replaceAll(' ', '_');

  DateTime get parsedDate => date;

  double get volume => weight * (reps > 0 ? reps : 1);

  bool get isBodyweight => weight == 0 && reps > 0;

  bool get isTimed => minutes > 0 && weight == 0 && reps == 0;

  /// Returns a copy with selected fields replaced.
  ///
  /// [deletedAt] uses a sentinel default so that callers can explicitly clear
  /// the field to null (restore path) without ambiguity:
  ///   - `copyWith()` → deletedAt unchanged
  ///   - `copyWith(deletedAt: null)` → clears deletedAt (restore)
  ///   - `copyWith(deletedAt: someDateTime)` → sets deletedAt (softDelete)
  WorkoutLog copyWith({
    String? exercise,
    DateTime? date,
    double? weight,
    int? reps,
    int? minutes,
    String? muscleGroup,
    Object? deletedAt = _kSentinel,
    double? plannedWeight,
  }) {
    return WorkoutLog(
      exercise:      exercise      ?? this.exercise,
      date:          date          ?? this.date,
      weight:        weight        ?? this.weight,
      reps:          reps          ?? this.reps,
      minutes:       minutes       ?? this.minutes,
      muscleGroup:   muscleGroup   ?? this.muscleGroup,
      deletedAt:     identical(deletedAt, _kSentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
      plannedWeight: plannedWeight ?? this.plannedWeight,
    );
  }

  // ─────────────────────────────────────────────
  // JSON
  // ─────────────────────────────────────────────

  /// Serialises to Hive storage format.
  ///
  /// [deletedAt] is omitted entirely when null (§6.1 null-omission contract).
  /// A null key in storage means the log is active; the key is never written
  /// as `"deletedAt": null`.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'v': _dataVersion,
      'exercise': normalizedExercise,
      'date': date.toIso8601String(),
      'weight': weight,
      'reps': reps,
      'minutes': minutes,
      'muscleGroup': muscleGroup,
    };
    if (deletedAt != null) {
      map['deletedAt'] = deletedAt!.toUtc().toIso8601String();
    }
    // null-omission contract (§6.1): key absent when null — never write null.
    if (plannedWeight != null) {
      map['plannedWeight'] = plannedWeight!;
    }
    return map;
  }

  /// Deserialises from any stored or network map.
  ///
  /// [recordKey] is the Hive key (e.g., `"logs|docId"`) included in
  /// Crashlytics metadata — allows the affected record to be located
  /// via Admin SDK without transmitting field values (§3.4).
  ///
  /// The [deletedAt] field is parsed leniently (RFC-002.4 §3.3):
  ///   - Key absent / JSON null → null (active, no Crashlytics)
  ///   - Valid ISO-8601 string → parsed to UTC DateTime
  ///   - Integer (Unix ms) → parsed via fromMillisecondsSinceEpoch;
  ///     Crashlytics migration warning emitted
  ///   - Non-null unparseable → null (active); Crashlytics non-fatal emitted
  factory WorkoutLog.fromJson(
    Map<String, dynamic> json, {
    String recordKey = 'unknown',
  }) {
    // ── Date parsing (STRICT SAFE) ──
    DateTime parsedDate;
    final rawDate = json['date'];

    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate =
          DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
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
        (mg is String && mg.trim().isNotEmpty) ? mg.trim().toLowerCase() : null;

    // ── deletedAt (lenient — RFC-002.4 §3.3) ──
    DateTime? parsedDeletedAt;
    final rawDeletedAt = json['deletedAt'];

    if (rawDeletedAt == null) {
      // Rows 1 & 2: key absent or JSON null → active, no Crashlytics.
      parsedDeletedAt = null;
    } else if (rawDeletedAt is String) {
      final dt = DateTime.tryParse(rawDeletedAt);
      if (dt != null) {
        // Row 3: valid ISO-8601 → parse to UTC.
        parsedDeletedAt = dt.toUtc();
      } else {
        // Row 5: non-null unparseable string → active + non-fatal.
        _emitDeletedAtParseError(
          recordKey: recordKey,
          valueRuntimeType: 'String',
          failureReason: 'invalid_iso8601_format',
          valueLength: rawDeletedAt.length,
        );
        parsedDeletedAt = null;
      }
    } else if (rawDeletedAt is int) {
      // Row 4: integer Unix ms → best-effort migration + warning.
      parsedDeletedAt = DateTime.fromMillisecondsSinceEpoch(rawDeletedAt);
      _emitDeletedAtParseError(
        recordKey: recordKey,
        valueRuntimeType: 'int',
        failureReason: 'integer_migration_warning',
      );
    } else {
      // Row 5: unexpected type → active + non-fatal.
      _emitDeletedAtParseError(
        recordKey: recordKey,
        valueRuntimeType: rawDeletedAt.runtimeType.toString(),
        failureReason: 'unexpected_type',
      );
      parsedDeletedAt = null;
    }

    // ── plannedWeight (RFC-006 — null-omission: absent = non-adaptive log) ──
    double? parsedPlannedWeight;
    final pw = json['plannedWeight'];
    if (pw is num) {
      parsedPlannedWeight = pw.toDouble().clamp(0.0, 500.0);
    }
    // Any non-num value (absent, null, malformed) → null — silent fallback.

    return WorkoutLog(
      exercise:      json['exercise']?.toString().trim().toLowerCase() ?? '',
      date:          parsedDate,
      weight:        parsedWeight,
      reps:          parsedReps,
      minutes:       parsedMinutes,
      muscleGroup:   muscleGroup,
      deletedAt:     parsedDeletedAt,
      plannedWeight: parsedPlannedWeight,
    );
  }

  // ── Crashlytics (§3.4) ───────────────────────────────────────────────────

  /// Emits a structured non-fatal Crashlytics event for a deletedAt parse error.
  ///
  /// Payload contains ONLY the six structured fields from §3.4.
  /// The raw deletedAt value is NEVER included — even truncated (health data).
  static void _emitDeletedAtParseError({
    required String recordKey,
    required String valueRuntimeType,
    required String failureReason,
    int? valueLength,
  }) {
    final metadata = <String, dynamic>{
      'record_key': recordKey,
      'app_version': _appVersion,
      'field_name': 'deletedAt',
      'value_runtime_type': valueRuntimeType,
      'failure_reason': failureReason,
      if (valueLength != null) 'value_length': valueLength,
    };

    final reporter = crashlyticsReporter;
    if (reporter != null) {
      reporter(metadata);
      return;
    }

    try {
      FirebaseCrashlytics.instance.recordError(
        Exception('WorkoutLog.fromJson deletedAt parse error'),
        null,
        reason: failureReason,
        information: [
          for (final e in metadata.entries) '${e.key}: ${e.value}',
        ],
        fatal: false,
      );
    } catch (_) {
      // Crashlytics may not be initialised in test environments.
    }
  }

  // ─────────────────────────────────────────────
  // SAFE FLOAT COMPARISON
  // ─────────────────────────────────────────────
  bool _doubleEquals(double a, double b) => (a - b).abs() < 0.0001;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkoutLog &&
        other.exercise == exercise &&
        other.date == date &&
        _doubleEquals(other.weight, weight) &&
        other.reps == reps &&
        other.minutes == minutes &&
        other.muscleGroup == muscleGroup &&
        other.deletedAt == deletedAt &&
        other.plannedWeight == plannedWeight;
  }

  @override
  int get hashCode => Object.hash(
        exercise,
        date,
        weight.round(),
        reps,
        minutes,
        muscleGroup,
        deletedAt,
        plannedWeight?.round(),
      );

  @override
  String toString() =>
      'WorkoutLog(exercise: $exercise, date: ${date.toIso8601String()}, '
      'weight: $weight, reps: $reps, minutes: $minutes, '
      'muscleGroup: $muscleGroup, deletedAt: ${deletedAt?.toIso8601String()})';
}
