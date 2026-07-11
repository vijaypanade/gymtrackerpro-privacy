// lib/screens/ai_workout_screen.dart — v2.0 FIXED
// ✅ FIXES:
//   1. Uses app theme (black/gold) — was plain grey
//   2. Uses applyAIWorkout() consistently (not applyPlanToWeek directly)
//   3. Handles missing/null fields safely
//   4. Shows exercise count + muscle focus properly
//   5. Mounted check before ScaffoldMessenger
//   6. Context.read safe inside callbacks

import 'package:flutter/material.dart';
import '../data/exercise_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';

class AIWorkoutScreen extends StatelessWidget {
  final Map<String, dynamic> plan;
  const AIWorkoutScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final days = (plan['days'] as List?) ??
        [
          {
            'day': 'Today',
            'focus': plan['focus'] ?? 'Workout',
            'exercises': plan['exercises'] ?? [],
          }
        ];
    final workoutName  = plan['workout_name'] as String? ?? 'Training Plan';
    final totalEx      = days.fold<int>(0, (sum, d) {
      final exList = (d['exercises'] as List?) ?? [];
      return sum + exList.length;
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Plan Preview',
            style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 13),
              const SizedBox(width: 4),
              Text('Generated', style: GoogleFonts.inter(
                  color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        // ── Summary card ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0.12),
                AppColors.gold.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: AppGradients.gold),
                  child: const Center(child: Icon(Icons.fitness_center_rounded, color: Colors.black, size: 22)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(workoutName, style: GoogleFonts.rajdhani(
                      color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('${days.length} days · $totalEx exercises',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                ])),
              ]),
              // Strategy line — new field from smart prompt
              if ((plan['strategy'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🧠 ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Text(
                    plan['strategy'] as String,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11, height: 1.4),
                  )),
                ]),
              ],
              // Coach message — new field
              if ((plan['coach_message'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💬 ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Text(
                    plan['coach_message'] as String,
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 12,
                        fontStyle: FontStyle.italic, height: 1.4),
                  )),
                ]),
              ],
            ]),
          ),
        ),

        // ── Day list ──────────────────────────────────
        Expanded(child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
          itemCount: days.length,
          itemBuilder: (ctx, i) => _DayCard(day: days[i], index: i),
        )),

        // ── Action buttons ────────────────────────────
        _ActionBar(plan: plan),
      ]),
    );
  }
}

class _DayCard extends StatelessWidget {
  final dynamic day;
  final int index;
  const _DayCard({required this.day, required this.index});

  Color _intensityColor(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'hard':    return AppColors.red;
      case 'deload':  return AppColors.textMuted;
      case 'light':   return AppColors.gold;
      default:        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = (day['exercises'] as List?) ?? [];
    final focus     = day['focus']     as String? ?? 'Workout';
    final dayLabel  = day['day']       as String? ?? 'Day ${index + 1}';
    final intensity = day['intensity'] as String? ?? 'Moderate';
    final col       = AppColors.dayColors[index % AppColors.dayColors.length];
    final intCol    = _intensityColor(intensity);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Container(width: 4, height: 36,
                decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayLabel.toUpperCase(), style: GoogleFonts.inter(
                  color: col, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              Text(focus, style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: intCol.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: intCol.withValues(alpha: 0.40)),
              ),
              child: Text(intensity, style: GoogleFonts.inter(
                  color: intCol, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6)),
              child: Text('${exercises.length} ex', style: GoogleFonts.inter(
                  color: col, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        ...exercises.map((ex) {
          // Smart name lookup: try 'name' first, fallback to exercise_id lookup
          var name = ex['name'] as String? ?? '';
          if (name.isEmpty) {
            final id = ex['exercise_id'] as String? ?? '';
            if (id.isNotEmpty) {
              final found = ExerciseData.list.firstWhere(
                (e) => e['id'] == id,
                orElse: () => {},
              );
              name = (found['name'] as String?) ??
                  id.split('_').skip(2).map((w) =>
                      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)
                  ).join(' ');
            }
          }
          final sets  = ex['sets'];
          final reps  = ex['reps'];
          final notes = ex['notes'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 5, height: 5,
                    decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(name, style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                Text('$sets × $reps', style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 13, top: 2),
                  child: Text(notes, style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 10,
                      fontStyle: FontStyle.italic)),
                ),
            ]),
          );
        }),

        const SizedBox(height: AppSpacing.xs),
      ]),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _ActionBar({required this.plan});

  Future<void> _apply(BuildContext context, {bool forceReplace = false}) async {
    final p = context.read<AppProvider>();

    // ✅ FIX: only show confirm if user already has exercises planned
    // Before: p.weekPlan.isNotEmpty → always true (default week exists) → always showed dialog
    // Now: check if any day actually has exercises
    final hasExistingWorkout = p.weekPlan.any((d) => d.exercises.isNotEmpty);

    if (hasExistingWorkout && !forceReplace) {
      _showConfirmDialog(context);
      return;
    }

    final normalizedPlan = plan['days'] != null
        ? plan
        : {
            'workout_name': plan['workout_name'] ?? 'Training Plan',
            'days': List.generate(7, (i) {
              final todayIndex = DateTime.now().weekday - 1;

              if (i == todayIndex) {
                return {
                  'day': 'Today',
                  'focus': plan['focus'] ?? 'Workout',
                  'exercises': plan['exercises'] ?? [],
                };
              }

              return {
                'day': 'Rest',
                'focus': 'Rest',
                'exercises': [],
              };
            }),
          };

    final daysList = plan['days'] as List?;
    final isSingleDay = daysList == null || daysList.length == 1;

    if (isSingleDay) {
      // Single day → add only to today, keep other days untouched
      final todayIndex = DateTime.now().weekday - 1;
      final singleDay = daysList != null && daysList.isNotEmpty
          ? Map<String, dynamic>.from(daysList.first as Map)
          : <String, dynamic>{};

      await p.applySingleDayAIWorkout(
        dayIndex: todayIndex,
        workoutPlan: {
          'focus': singleDay['focus'] ?? plan['focus'] ?? 'Workout',
          'exercises': singleDay['exercises'] ?? plan['exercises'] ?? [],
        },
      );
    } else {
      // Full week plan → replace whole planner
      await p.applyAIWorkout(normalizedPlan);
    }
    if (!context.mounted) return;
    Navigator.pop(context);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🚀 Plan applied! Open Planner to start.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Replace Current Plan?', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text(
          'This will overwrite your existing week plan.\n\nYour workout history will not be deleted.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Current', style: GoogleFonts.inter(color: AppColors.textMuted))),
          GoldButton(text: 'Replace Plan 🚀', onTap: () {
            Navigator.pop(ctx);
            _apply(context, forceReplace: true);
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(children: [
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderMedium),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text('Discard', style: GoogleFonts.rajdhani(
              color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w700)),
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 2, child: GoldButton(
          text: 'Apply to Planner 🚀',
          onTap: () => _apply(context),
        )),
      ]),
    );
  }
}
