// lib/widgets/home/home_workout_widgets.dart
// Workout card widgets extracted from home_screen.dart — no behavior changes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../shared_widgets.dart';
import '../../services/workout_session_service.dart';
import '../../screens/planner_screen.dart';
import '../../screens/main_shell.dart';

// ════════════════════════════════════════════════
// TAP-SCALE BUTTON — shared press animation
// (moved here so both home_screen.dart and this
//  file can use it without a circular import)
// ════════════════════════════════════════════════
class HomeTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const HomeTapButton({super.key, required this.child, required this.onTap});

  @override
  State<HomeTapButton> createState() => _HomeTapButtonState();
}

class _HomeTapButtonState extends State<HomeTapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.982).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ════════════════════════════════════════════════
// TODAY WORKOUT CARD
// ════════════════════════════════════════════════
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _TodayData>(
      selector: (_, ap) => _TodayData.from(ap),
      builder: (context, data, _) {
        if (data.isRestDay) return const _RestDayCard();
        if (data.isEmpty) return const _EmptyWorkoutCard();
        return _ActiveWorkoutCard(data: data);
      },
    );
  }
}

@immutable
class _TodayData {
  final DayPlan today;
  final int todayIndex;
  final int total;
  final int done;
  final int totalSets;
  final double totalVolume;
  final int estimatedMinutes;
  final double pct;
  final bool isRestDay;
  final bool isEmpty;
  final bool isCompleted;
  final bool isPendingReview;

  const _TodayData({
    required this.today,
    required this.todayIndex,
    required this.total,
    required this.done,
    required this.totalSets,
    required this.totalVolume,
    required this.estimatedMinutes,
    required this.pct,
    required this.isRestDay,
    required this.isEmpty,
    required this.isCompleted,
    this.isPendingReview = false,
  });

  factory _TodayData.from(AppProvider ap) {
    final today = ap.todayPlan;
    final total = today.exercises.length;
    final done = today.completedExercises;
    int sets = 0;
    double volume = 0;
    for (final e in today.exercises) {
      sets += e.sets.length;
      for (final s in e.sets) {
        volume += s.weight * s.reps;
      }
    }
    // Estimate duration: ~3 min/set including rest
    final estMin = (sets * 3).clamp(0, 240);
    final pct = (total > 0 ? done / total : 0.0).clamp(0.0, 1.0);
    return _TodayData(
      today: today,
      todayIndex: ap.todayIndex,
      total: total,
      done: done,
      totalSets: sets,
      totalVolume: volume,
      estimatedMinutes: estMin,
      pct: pct,
      isRestDay: today.isRestDay,
      isEmpty: total == 0 && !today.isRestDay,
      isCompleted: today.isCompleted,
      isPendingReview: today.isPendingReview,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TodayData &&
        identical(other.today, today) &&
        other.todayIndex == todayIndex &&
        other.total == total &&
        other.done == done &&
        other.totalSets == totalSets &&
        other.isRestDay == isRestDay &&
        other.isEmpty == isEmpty &&
        other.isCompleted == isCompleted &&
        other.isPendingReview == isPendingReview;
  }

  @override
  int get hashCode => Object.hash(
      today, todayIndex, total, done, totalSets,
      isRestDay, isEmpty, isCompleted, isPendingReview);
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  static const _overlineStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.2,
  );

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.45,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.borderSoft, width: 0.5),
      ),
      child: Row(
        children: [
          // Clean icon tile — no emoji. A bedtime icon on a dark card
          // reads as intentional and refined, not playful.
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.borderMedium, width: 0.5),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overline label with gold accent bar — matches section header style
                Row(children: [
                  Container(
                    width: 2, height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text('PLANNED REST', style: _overlineStyle),
                ]),
                const SizedBox(height: 5),
                const Text('Rest Day', style: _titleStyle),
                const SizedBox(height: 4),
                const Text(
                  'Smart recovery = stronger tomorrow.',
                  style: _subStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkoutCard extends StatelessWidget {
  const _EmptyWorkoutCard();

  static const _titleStyle = TextStyle(
    fontFamily: 'Rajdhani',
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const _subStyle = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return HomeTapButton(
      onTap: () => context
          .findAncestorStateOfType<MainShellState>()
          ?.changeTab(1),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.gold.withValues(alpha: 0.16),
                  AppColors.gold.withValues(alpha: 0.06),
                ]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.gold,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan today\'s workout', style: _titleStyle),
                  Text(
                    'Tap to add exercises and start training.',
                    style: _subStyle,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.gold,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  final _TodayData data;
  const _ActiveWorkoutCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isCompleted && !data.isPendingReview) return _CompletedSummaryCard(data: data);
    final today = data.today;
    return HomeTapButton(
      onTap: () => Navigator.push(
        context,
        slideRoute(PlannerScreen(initialDayIndex: data.todayIndex)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 1),
        ),
        child: Column(
          children: [
            _WorkoutHeader(data: data),
            _WorkoutExerciseList(today: today),
            if (today.exercises.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+${today.exercises.length - 3} more exercises',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: GoldButton(
                text: 'Start Workout',
                icon: Icons.play_arrow_rounded,
                width: double.infinity,
                onTap: () => Navigator.push(
                  context,
                  slideRoute(PlannerScreen(initialDayIndex: data.todayIndex)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// COLLAPSED COMPLETED CARD — shown instead of full card after workout done
// ════════════════════════════════════════════════
class _CompletedSummaryCard extends StatelessWidget {
  final _TodayData data;
  const _CompletedSummaryCard({required this.data});

  String _fmtVol(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}t' : '${v.toStringAsFixed(0)}kg';

  @override
  Widget build(BuildContext context) {
    return HomeTapButton(
      onTap: () => Navigator.push(
        context,
        slideRoute(PlannerScreen(initialDayIndex: data.todayIndex)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        child: Row(children: [
          // Minimal completion mark — no orb, no glow
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.textMuted, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✓  Completed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(data.today.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 6),
              Row(children: [
                if (data.totalVolume > 0) ...[
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.goldAmber, size: 12),
                  const SizedBox(width: 3),
                  Text(_fmtVol(data.totalVolume),
                      style: const TextStyle(fontFamily: 'Inter',
                          color: AppColors.textSecondary, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.fitness_center_rounded,
                    color: AppColors.textMuted, size: 12),
                const SizedBox(width: 3),
                Text('${data.total} exercises',
                    style: const TextStyle(fontFamily: 'Inter',
                        color: AppColors.textMuted, fontSize: 11)),
              ]),
            ],
          )),
          const SizedBox(width: AppSpacing.sm),
          const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 14),
            SizedBox(height: 2),
            Text('Edit', style: TextStyle(fontFamily: 'Inter',
                color: AppColors.textMuted, fontSize: 8.5,
                fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}

// Breathing red dot for the LIVE session badge.
// Replaces the solid red background so the indicator reads as a
// sophisticated status signal rather than a danger/error alert.
class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();
  @override State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _alpha;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _alpha = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _alpha,
    builder: (_, __) => Container(
      width: 5, height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE53935).withValues(alpha: _alpha.value),
        boxShadow: [BoxShadow(
          color: const Color(0xFFE53935).withValues(alpha: _alpha.value * 0.55),
          blurRadius: 5, spreadRadius: 1,
        )],
      ),
    ),
  );
}

class _WorkoutHeader extends StatelessWidget {
  final _TodayData data;
  const _WorkoutHeader({required this.data});

  static const _dayNames = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'];

  String _formatVolume(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}t';
    return '${v.toStringAsFixed(0)}kg';
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = _dayNames[data.todayIndex.clamp(0, 6)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day label badge + LIVE session indicator
          AnimatedBuilder(
            animation: WorkoutSessionService.instance,
            builder: (context, _) {
              final session = WorkoutSessionService.instance;
              final isLive = session.isActive && session.dayIndex == data.todayIndex;
              return Row(children: [
                Text(dayLabel,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    )),
                if (isLive) ...[
                  const SizedBox(width: 8),
                  // Dark-grey badge with glowing pulse dot — reads as a
                  // sophisticated status indicator, not a danger alert.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const _LivePulsingDot(),
                      const SizedBox(width: 6),
                      Text('LIVE · ${session.elapsedFormatted}',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          )),
                    ]),
                  ),
                ],
                const Spacer(),
            if (data.isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.gold, size: 12),
                  const SizedBox(width: 4),
                  Text('DONE',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                ]),
              )
            else
              CircularPercentIndicator(
                radius: 22.0,
                lineWidth: 4.0,
                percent: data.pct,
                center: Text(
                  '${data.done}/${data.total}',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                progressColor: AppColors.gold,
                backgroundColor: AppColors.bgElevated,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),
          ]);
            },
          ),
          const SizedBox(height: 6),

          // Big workout title
          Hero(
            tag: 'home-workout-title-${data.todayIndex}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(data.today.title,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  )),
            ),
          ),
          const SizedBox(height: 12),

          // 3-stat row: exercises · sets · time/volume
          Row(children: [
            _statChip(
              icon: Icons.fitness_center_rounded,
              value: '${data.total}',
              label: 'exercises',
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.repeat_rounded,
              value: '${data.totalSets}',
              label: 'sets',
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.access_time_rounded,
              value: '~${data.estimatedMinutes}',
              label: 'min',
            ),
          ]),
          if (data.totalVolume > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 4),
              Text('Total volume: ${_formatVolume(data.totalVolume)}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.borderSoft,
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(label,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _WorkoutExerciseList extends StatelessWidget {
  final DayPlan today;
  const _WorkoutExerciseList({required this.today});

  @override
  Widget build(BuildContext context) {
    final count = today.exercises.length < 3 ? today.exercises.length : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            _ExerciseRow(
              key: ValueKey(today.exercises[i].id),
              exercise: today.exercises[i],
            ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final PlannedExercise exercise;
  const _ExerciseRow({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final done = exercise.isComplete;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.gold.withValues(alpha: 0.10)
                  : const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done
                    ? AppColors.gold.withValues(alpha: 0.20)
                    : AppColors.borderSoft,
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 14,
              color: done
                  ? AppColors.gold.withValues(alpha: 0.65)
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              exercise.name,
              style: TextStyle(
                fontFamily: 'Inter',
                color: done ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${exercise.sets.length}×',
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: done ? AppColors.gold : AppColors.borderMedium,
          ),
        ],
      ),
    );
  }
}

