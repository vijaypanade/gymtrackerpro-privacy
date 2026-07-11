// lib/screens/pr_wall_screen.dart — Personal Records Wall
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/workout_log.dart';
import '../providers/app_provider.dart';
import '../services/progression_service.dart';
import '../utils/app_constants.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class _PREntry {
  final String displayName;
  final String exerciseKey;
  final String muscleGroup;
  final double prWeight;
  final int    prReps;
  final String prDate;

  const _PREntry({
    required this.displayName,
    required this.exerciseKey,
    required this.muscleGroup,
    required this.prWeight,
    required this.prReps,
    required this.prDate,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class PRWallScreen extends StatefulWidget {
  const PRWallScreen({super.key});

  @override
  State<PRWallScreen> createState() => _PRWallScreenState();
}

class _PRWallScreenState extends State<PRWallScreen> {
  String _selectedMuscle = 'All';

  // Converts "barbell_bench_press" → "Barbell Bench Press"
  static String _toDisplay(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  List<_PREntry> _computePRs(List<WorkoutLog> logs) {
    // Unique weight-based exercises only
    final seen    = <String>{};
    final entries = <_PREntry>[];

    for (final log in logs) {
      if (seen.contains(log.exercise)) continue;
      if (log.weight <= 0) continue; // skip bodyweight / cardio-only logs
      seen.add(log.exercise);

      final prWeight = ProgressionService.getPR(logs, log.exercise, 'kg');
      if (prWeight <= 0) continue;

      final prReps  = ProgressionService.getPRReps(logs, log.exercise);
      final prDate  = ProgressionService.getPRDate(logs, log.exercise, 'kg') ?? '';
      final muscle  = _canonicalMuscle(
          logs.firstWhere((l) => l.exercise == log.exercise).muscleGroup);

      entries.add(_PREntry(
        displayName:  _toDisplay(log.exercise),
        exerciseKey:  log.exercise,
        muscleGroup:  muscle,
        prWeight:     prWeight,
        prReps:       prReps,
        prDate:       prDate,
      ));
    }

    // Sort by PR weight descending
    entries.sort((a, b) => b.prWeight.compareTo(a.prWeight));
    return entries;
  }

  static String _canonicalMuscle(String? raw) {
    if (raw == null || raw.isEmpty) return 'Other';
    final lower = raw.toLowerCase();
    if (lower.contains('chest') || lower.contains('push')) return 'Chest';
    if (lower.contains('back')  || lower.contains('pull') || lower.contains('lat')) return 'Back';
    if (lower.contains('leg')   || lower.contains('quad') || lower.contains('hamstring') ||
        lower.contains('glute') || lower.contains('calf')) {
      return 'Legs';
    }
    if (lower.contains('shoulder') || lower.contains('delt')) return 'Shoulders';
    if (lower.contains('bicep') || lower.contains('arm')) return 'Biceps';
    if (lower.contains('tricep')) return 'Triceps';
    if (lower.contains('core') || lower.contains('abs')) return 'Core';
    return raw.isNotEmpty
        ? raw[0].toUpperCase() + raw.substring(1).toLowerCase()
        : 'Other';
  }

  static const _muscleOrder = [
    'All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Biceps', 'Triceps', 'Core', 'Other',
  ];

  static const _muscleColors = <String, Color>{
    'Chest':     AppColors.gold,
    'Back':      AppColors.gold,
    'Legs':      AppColors.goldSoft,
    'Shoulders': AppColors.goldSoft,
    'Biceps':    AppColors.textSecondary,
    'Triceps':   AppColors.textSecondary,
    'Core':      AppColors.textMuted,
    'Other':     AppColors.textMuted,
  };

  Color _colorFor(String muscle) =>
      _muscleColors[muscle] ?? const Color(0xFF78909C);

  @override
  Widget build(BuildContext context) {
    final logs   = context.read<AppProvider>().logs;
    final all    = _computePRs(logs);
    final muscles = ['All', ...all.map((e) => e.muscleGroup).toSet()
        .toList()..sort((a, b) {
          final ai = _muscleOrder.indexOf(a);
          final bi = _muscleOrder.indexOf(b);
          return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        })];

    final filtered = _selectedMuscle == 'All'
        ? all
        : all.where((e) => e.muscleGroup == _selectedMuscle).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.bg,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text('PERSONAL RECORDS',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 19, fontWeight: FontWeight.w900,
                      letterSpacing: 1.6)),
              Text('${all.length} lifts tracked',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _MuscleFilterBar(
                muscles:  muscles,
                selected: _selectedMuscle,
                colorFor: _colorFor,
                onSelect: (m) => setState(() => _selectedMuscle = m),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          if (all.isEmpty)
            SliverFillRemaining(child: _EmptyState())
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No $_selectedMuscle records yet.',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 14)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final entry  = filtered[i];
                    final isTop  = i == 0 && _selectedMuscle == 'All';
                    return _PRCard(
                      entry:  entry,
                      isTop:  isTop,
                      rank:   i + 1,
                      color:  _colorFor(entry.muscleGroup),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────
class _MuscleFilterBar extends StatelessWidget {
  final List<String>        muscles;
  final String              selected;
  final Color Function(String) colorFor;
  final ValueChanged<String> onSelect;

  const _MuscleFilterBar({
    required this.muscles,
    required this.selected,
    required this.colorFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 6),
      itemCount: muscles.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final m       = muscles[i];
        final active  = m == selected;
        final col     = m == 'All'
            ? AppColors.gold
            : colorFor(m);
        return GestureDetector(
          onTap: () => onSelect(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? col.withValues(alpha: 0.18)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? col.withValues(alpha: 0.60)
                    : AppColors.divider.withValues(alpha: 0.20),
              ),
            ),
            child: Text(m,
                style: GoogleFonts.inter(
                  color: active ? col : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: active
                      ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
        );
      },
    ),
  );
}

// ── PR Card ───────────────────────────────────────────────────────────────────
class _PRCard extends StatelessWidget {
  final _PREntry entry;
  final bool     isTop;
  final int      rank;
  final Color    color;

  const _PRCard({
    required this.entry,
    required this.isTop,
    required this.rank,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final weightStr = entry.prWeight % 1 == 0
        ? '${entry.prWeight.toInt()} kg'
        : '${entry.prWeight} kg';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop
              ? AppColors.gold.withValues(alpha: 0.35)
              : AppColors.divider.withValues(alpha: 0.18),
          width: isTop ? 1.0 : 0.6,
        ),
        gradient: isTop
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.gold.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: Row(children: [
        // Rank badge
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isTop
                ? const Icon(Icons.emoji_events_rounded,
                    color: AppColors.gold, size: 16)
                : Text('$rank',
                    style: GoogleFonts.rajdhani(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),

        // Name + muscle tag
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.displayName,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(entry.muscleGroup,
                    style: GoogleFonts.inter(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600)),
              ),
              if (entry.prDate.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(entry.prDate,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10)),
              ],
            ]),
          ],
        )),

        // PR value
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(weightStr,
              style: GoogleFonts.rajdhani(
                  color: isTop ? AppColors.gold : AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text('× ${entry.prReps} reps',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.emoji_events_outlined,
          color: AppColors.textMuted.withValues(alpha: 0.30), size: 56),
      const SizedBox(height: 16),
      Text('No records yet.',
          style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary,
              fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Complete workouts to set your first PRs.',
          style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 13)),
    ]),
  );
}
