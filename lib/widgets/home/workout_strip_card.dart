// lib/widgets/home/workout_strip_card.dart
// RFC-HOME-003: Persistent Today's Workout Strip

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/adaptive_session.dart';
import '../../providers/app_provider.dart';
import '../../screens/main_shell.dart' show MainShellState;
import '../../utils/app_constants.dart';
import 'home_workout_widgets.dart';

// ── Strip exercise row model ──────────────────────────────────────────────────

@immutable
class _StripExercise {
  final String  name;
  final int     setsCount;
  final bool    isAdapted;
  final double? adaptedWeight;
  final double? plannedWeight;
  final String  unit;

  const _StripExercise({
    required this.name,
    required this.setsCount,
    required this.isAdapted,
    this.adaptedWeight,
    this.plannedWeight,
    required this.unit,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _StripExercise) return false;
    return other.name          == name          &&
           other.setsCount     == setsCount     &&
           other.isAdapted     == isAdapted     &&
           other.adaptedWeight == adaptedWeight &&
           other.plannedWeight == plannedWeight &&
           other.unit          == unit;
  }

  @override
  int get hashCode => Object.hash(name, setsCount, isAdapted, adaptedWeight, plannedWeight, unit);
}

// ── Card state ────────────────────────────────────────────────────────────────

enum _StripState { standard, adaptive, completed }

// ── Data snapshot ─────────────────────────────────────────────────────────────

@immutable
class _StripData {
  final String               title;
  final List<_StripExercise> exercises;       // ≤3 rows to display
  final int                  totalExerciseCount;
  final int                  changedExerciseCount;
  final int                  estimatedMinutes;
  final bool                 isCompleted;
  final bool                 isRestDay;
  final bool                 hasAdaptiveSession;
  final int                  todayIndex;

  const _StripData({
    required this.title,
    required this.exercises,
    required this.totalExerciseCount,
    required this.changedExerciseCount,
    required this.estimatedMinutes,
    required this.isCompleted,
    required this.isRestDay,
    required this.hasAdaptiveSession,
    required this.todayIndex,
  });

  _StripState get state {
    if (isCompleted)        return _StripState.completed;
    if (hasAdaptiveSession) return _StripState.adaptive;
    return _StripState.standard;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _StripData) return false;
    if (other.title                == title                &&
        other.totalExerciseCount   == totalExerciseCount   &&
        other.changedExerciseCount == changedExerciseCount &&
        other.estimatedMinutes     == estimatedMinutes     &&
        other.isCompleted          == isCompleted          &&
        other.isRestDay            == isRestDay            &&
        other.hasAdaptiveSession   == hasAdaptiveSession   &&
        other.todayIndex           == todayIndex           &&
        other.exercises.length     == exercises.length) {
      for (var i = 0; i < exercises.length; i++) {
        if (exercises[i] != other.exercises[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
    title, totalExerciseCount, changedExerciseCount,
    estimatedMinutes, isCompleted, isRestDay, hasAdaptiveSession, todayIndex,
    Object.hashAll(exercises),
  );
}

// ── Selector logic ────────────────────────────────────────────────────────────

_StripData _buildStripData(AppProvider ap) {
  final plan    = ap.todayPlan;
  final session = ap.adaptiveSession;

  final totalCount = plan.exercises.length;
  final totalSets  = plan.exercises.fold(0, (s, e) => s + e.sets.length);
  final estMins    = (totalSets * 3).clamp(0, 240);

  List<_StripExercise> rows;
  int changedCount = 0;
  bool hasAdaptive = false;

  if (session != null && !ap.adaptiveDeclinedToday) {
    final adapted   = <_StripExercise>[];
    final unchanged = <_StripExercise>[];

    for (final pe in plan.exercises) {
      final ae = _findFirst<AdaptiveExercise>(
        session.exercises, (a) => a.exerciseId == pe.id,
      );
      if (ae != null) {
        AdaptiveSet? changedSet;
        for (final s in ae.sets) {
          if (s.adaptedWeight != s.plannedWeight) { changedSet = s; break; }
        }
        if (changedSet != null) {
          adapted.add(_StripExercise(
            name:          pe.name,
            setsCount:     pe.sets.length,
            isAdapted:     true,
            adaptedWeight: changedSet.adaptedWeight,
            plannedWeight: changedSet.plannedWeight,
            unit:          pe.unit,
          ));
          continue;
        }
      }
      unchanged.add(_StripExercise(
        name:      pe.name,
        setsCount: pe.sets.length,
        isAdapted: false,
        unit:      pe.unit,
      ));
    }

    changedCount = adapted.length;
    hasAdaptive  = changedCount > 0;
    // Adapted rows first; fill remaining slots with unchanged to keep height stable.
    rows = [...adapted, ...unchanged].take(3).toList();
  } else {
    rows = plan.exercises.take(3).map((pe) => _StripExercise(
      name:      pe.name,
      setsCount: pe.sets.length,
      isAdapted: false,
      unit:      pe.unit,
    )).toList();
  }

  return _StripData(
    title:                plan.title,
    exercises:            rows,
    totalExerciseCount:   totalCount,
    changedExerciseCount: changedCount,
    estimatedMinutes:     estMins,
    isCompleted:          plan.isCompleted,
    isRestDay:            plan.isRestDay,
    hasAdaptiveSession:   hasAdaptive,
    todayIndex:           ap.todayIndex,
  );
}

T? _findFirst<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

// ── Public entry point ────────────────────────────────────────────────────────

class WorkoutStripCard extends StatelessWidget {
  const WorkoutStripCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _StripData>(
      selector: (_, ap) => _buildStripData(ap),
      builder: (ctx, data, __) {
        if (data.isRestDay) return const SizedBox.shrink();
        return RepaintBoundary(
          child: HomeTapButton(
            onTap: () =>
                ctx.findAncestorStateOfType<MainShellState>()?.changeTab(1),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.borderMedium, width: 0.5),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _StripContent(key: ValueKey(data.state), data: data),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Content switch ────────────────────────────────────────────────────────────

class _StripContent extends StatelessWidget {
  final _StripData data;
  const _StripContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    switch (data.state) {
      case _StripState.completed:
        return _CompletedContent(data: data);
      case _StripState.adaptive:
      case _StripState.standard:
        return _ActiveContent(data: data);
    }
  }
}

// ── Active state (standard + adaptive) ───────────────────────────────────────

class _ActiveContent extends StatelessWidget {
  final _StripData data;
  const _ActiveContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final extra = data.totalExerciseCount - 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow row
        Row(
          children: [
            Text(
              "TODAY'S WORKOUT",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (data.hasAdaptiveSession) ...[
              const SizedBox(width: 8),
              const _AiBadge(),
            ],
          ],
        ),
        const SizedBox(height: 1),
        // Title + duration on one line
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(data.title, style: AppTextStyles.h3)),
            Text(
              '${data.estimatedMinutes} min',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Exercise preview rows (always up to 3)
        ...data.exercises.map((e) => _ExRow(exercise: e)),
        if (extra > 0) ...[
          const SizedBox(height: 2),
          Text(
            '+ $extra more',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── Completed state ───────────────────────────────────────────────────────────

class _CompletedContent extends StatelessWidget {
  final _StripData data;
  const _CompletedContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S WORKOUT",
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(data.title, style: AppTextStyles.h3)),
            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.green),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${data.totalExerciseCount} exercise${data.totalExerciseCount != 1 ? 's' : ''} completed',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}


// ── Exercise preview row ──────────────────────────────────────────────────────

class _ExRow extends StatelessWidget {
  final _StripExercise exercise;
  const _ExRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          // Adapted indicator vs. plain bullet
          if (exercise.isAdapted)
            const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.goldSoft)
          else
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.borderMedium,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          // Exercise name
          Expanded(
            child: Text(
              exercise.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: exercise.isAdapted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Weight diff (adapted rows only)
          if (exercise.isAdapted &&
              exercise.adaptedWeight != null &&
              exercise.plannedWeight != null) ...[
            _WeightDiff(
              adapted: exercise.adaptedWeight!,
              planned: exercise.plannedWeight!,
              unit:    exercise.unit,
            ),
            const SizedBox(width: 6),
          ],
          // Sets count
          Text(
            '${exercise.setsCount}×',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Weight diff label — "95 ← 100 kg" ────────────────────────────────────────

class _WeightDiff extends StatelessWidget {
  final double adapted;
  final double planned;
  final String unit;

  const _WeightDiff({
    required this.adapted,
    required this.planned,
    required this.unit,
  });

  static String _fmt(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: _fmt(adapted),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.goldSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: ' ← ${_fmt(planned)} $unit',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── AI Adapted badge ──────────────────────────────────────────────────────────

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: AppColors.goldSoft.withValues(alpha: 0.30),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 10, color: AppColors.goldSoft),
          const SizedBox(width: 3),
          Text(
            'AI Adapted',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.goldSoft,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

