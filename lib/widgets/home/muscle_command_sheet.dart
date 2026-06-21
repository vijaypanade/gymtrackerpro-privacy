// lib/widgets/home/muscle_command_sheet.dart
// ─────────────────────────────────────────────────────────
// Muscle Command Center — premium AI recovery intelligence panel.
//
// Architecture:
//   Reuses: WorkoutProvider.logs, WorkoutProvider.weekPlan,
//           WorkoutProvider.addExercise, WorkoutProvider.removeExercise,
//           ExerciseData.list, WorkoutProvider.normalizeMuscle
//   No new providers, no new services.
// ─────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/exercise_data.dart';
import '../../models/models.dart';
import '../../models/workout_log.dart';
import '../../providers/workout_provider.dart';
import '../../providers/ai_provider.dart';
import '../../screens/planner_screen.dart' show showExercisePicker;
import '../../utils/app_constants.dart';

// ─────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ─────────────────────────────────────────────────────────

class MuscleCommandSheet {
  MuscleCommandSheet._();

  static void show(BuildContext context, MuscleRecovery recovery) {
    final wp = context.read<WorkoutProvider>();
    showModalBottomSheet(
      context:             context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => _SheetBody(
        recovery:      recovery,
        wp:            wp,
        parentContext: context,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PURE DATA HELPERS
// ─────────────────────────────────────────────────────────

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _toKey(String name) =>
    name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

String _prettyName(String key) {
  const suffixes = {
    'push', 'pull', 'compound', 'isolation',
    'cardio', 'olympic', 'hinge', 'squat',
  };
  final words = key.split('_');
  if (words.length > 1 && suffixes.contains(words.last)) {
    return words.sublist(0, words.length - 1).map(_cap).join(' ');
  }
  return words.map(_cap).join(' ');
}

String _formatLastTrained(String dateStr) {
  if (dateStr == 'Never') return 'Never trained';
  try {
    final parts = dateStr.split('/');
    if (parts.length == 2) {
      final now  = DateTime.now();
      final date = DateTime(now.year, int.parse(parts[1]), int.parse(parts[0]));
      final days = now.difference(date).inDays.abs();
      if (days == 0) return 'Trained today';
      if (days == 1) return 'Trained yesterday';
      if (days < 7)  return 'Trained ${days}d ago';
      return 'Trained ${(days / 7).floor()}w ago';
    }
  } catch (_) {}
  return 'Trained $dateStr';
}

Color _recoveryColor(int score) {
  if (score >= 80) return AppColors.green;
  if (score >= 50) return AppColors.orange;
  return AppColors.red;
}

String _recoveryLabel(int score) {
  if (score >= 95) return 'PEAK RECOVERY';
  if (score >= 80) return 'READY';
  if (score >= 65) return 'MODERATE FATIGUE';
  if (score >= 45) return 'SUPPRESSED';
  return 'DEPLETED';
}

String _coachReason(int score) {
  if (score >= 80) return 'Recovery high — compound loading recommended.';
  if (score >= 60) return 'Adequate recovery — moderate intensity.';
  if (score >= 40) return 'Partial recovery — isolation work preferred.';
  return 'Still recovering — light activation only.';
}

// Legacy 'arms' covers both subgroups for log filtering
Set<String> _matchKeys(String muscleKey) {
  if (muscleKey == 'arms') return {'biceps', 'triceps', 'arms'};
  return {muscleKey};
}

// ─────────────────────────────────────────────────────────
// LAST SESSION DATA
// ─────────────────────────────────────────────────────────

class _LogEntry {
  final String name;
  final double weight;
  final int    reps;
  final int    minutes;
  const _LogEntry({
    required this.name, required this.weight,
    required this.reps, required this.minutes,
  });
  bool get isTime => minutes > 0;
}

class _LastSession {
  final String          dateLabel;
  final List<_LogEntry> exercises;
  final double          totalVolume;
  const _LastSession({
    required this.dateLabel,
    required this.exercises,
    required this.totalVolume,
  });
}

_LastSession? _getLastSession(String muscleKey, List<WorkoutLog> logs) {
  final keys = _matchKeys(muscleKey);
  final relevant = logs
      .where((l) => keys.contains((l.muscleGroup ?? '').toLowerCase()))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (relevant.isEmpty) return null;

  final last    = relevant.first.date;
  final session = relevant.where((l) =>
      l.date.year  == last.year  &&
      l.date.month == last.month &&
      l.date.day   == last.day).toList();

  final bestByEx = <String, WorkoutLog>{};
  for (final l in session) {
    final existing = bestByEx[l.exercise];
    if (existing == null || l.weight > existing.weight) bestByEx[l.exercise] = l;
  }

  final days  = DateTime.now().difference(last).inDays;
  final label = days == 0 ? 'today'
      : days == 1 ? 'yesterday'
      : days < 7  ? '${days}d ago'
      : '${(days / 7).floor()}w ago';

  final entries  = bestByEx.values.map((l) => _LogEntry(
    name:    _prettyName(l.exercise),
    weight:  l.weight,
    reps:    l.reps,
    minutes: l.minutes,
  )).toList();
  final totalVol = session.fold(0.0, (s, l) => s + l.weight * l.reps);
  return _LastSession(dateLabel: label, exercises: entries, totalVolume: totalVol);
}

// ─────────────────────────────────────────────────────────
// EXERCISE SUGGESTIONS
// ─────────────────────────────────────────────────────────

List<Map<String, dynamic>> _getSuggestions(
    String muscleKey, int recoveryScore, List<WorkoutLog> logs) {
  final all = ExerciseData.list
      .where((e) {
        final m = (e['muscle'] as String? ?? '').toLowerCase();
        if (muscleKey == 'arms') return m == 'arms' || m == 'biceps' || m == 'triceps';
        return m == muscleKey;
      })
      .toList();
  if (all.isEmpty) return [];

  final cutoff    = DateTime.now().subtract(const Duration(days: 7));
  final recentKeys = logs
      .where((l) =>
          _matchKeys(muscleKey).contains((l.muscleGroup ?? '').toLowerCase()) &&
          l.date.isAfter(cutoff))
      .map((l) => l.exercise)
      .toSet();

  all.sort((a, b) {
    final aNew = !recentKeys.contains(_toKey(a['name'] as String? ?? ''));
    final bNew = !recentKeys.contains(_toKey(b['name'] as String? ?? ''));
    if (aNew != bNew) return aNew ? -1 : 1;
    if (recoveryScore >= 70) {
      final aC = a['movement'] == 'compound';
      final bC = b['movement'] == 'compound';
      if (aC != bC) return aC ? -1 : 1;
    }
    return 0;
  });

  return all.take(4).toList();
}

// ─────────────────────────────────────────────────────────
// ANIMATED RECOVERY RING
// ─────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = (math.min(size.width, size.height) / 2) - 4.0;
    const sw   = 3.5;

    // Track ring
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color       = color.withValues(alpha: 0.13));

    if (progress <= 0) return;

    // Filled arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap   = StrokeCap.round
        ..color       = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────
// SHEET BODY
// ─────────────────────────────────────────────────────────

class _SheetBody extends StatefulWidget {
  final MuscleRecovery  recovery;
  final WorkoutProvider wp;
  final BuildContext    parentContext;
  const _SheetBody({
    required this.recovery,
    required this.wp,
    required this.parentContext,
  });
  @override State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  final _adding = <String>{};

  // Live plan check — reads directly from provider state
  bool _isInPlan(String name, String type) {
    final dayIdx = widget.wp.todayIndex;
    final plan   = widget.wp.weekPlan[dayIdx];
    final key    = widget.wp.getKey('${name}_$type');
    return plan.exercises.any((e) => widget.wp.getKey(e.baseId) == key);
  }

  Future<void> _toggle(Map<String, dynamic> ex) async {
    final name = ex['name'] as String? ?? '';
    final type = ex['type'] as String? ?? '';
    if (_adding.contains(name)) return;
    HapticFeedback.selectionClick();
    setState(() => _adding.add(name));
    try {
      final dayIdx = widget.wp.todayIndex;
      if (_isInPlan(name, type)) {
        // Remove
        final plan = widget.wp.weekPlan[dayIdx];
        final key  = widget.wp.getKey('${name}_$type');
        PlannedExercise? found;
        for (final e in plan.exercises) {
          if (widget.wp.getKey(e.baseId) == key) { found = e; break; }
        }
        if (found != null) {
          await widget.wp.removeExercise(dayIdx, found.id);
          HapticFeedback.lightImpact();
        }
      } else {
        // Add
        await widget.wp.addExercise(
          dayIdx,
          name:         name,
          category:     ex['muscle']      as String? ?? '',
          emoji:        ex['emoji']       as String? ?? '',
          type:         type,
          unit:         (ex['bodyweight'] == true) ? 'reps' : 'kg',
          baseId:       '${name}_$type',
          isBodyweight: ex['bodyweight']  == true,
        );
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
    if (mounted) setState(() => _adding.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final rec      = widget.recovery;
    final muscle   = WorkoutProvider.normalizeMuscle(rec.muscle);
    final logs     = widget.wp.logs;
    final lastSess = _getLastSession(muscle, logs);
    final suggests = _getSuggestions(muscle, rec.recoveryScore, logs);
    final ai       = context.watch<AIProvider>().insight;
    final col      = _recoveryColor(rec.recoveryScore);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Color(0xFF111111), Color(0xFF0A0A0A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.14), width: 0.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 30, height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 42),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // 1. HEADER
              _Header(rec: rec, col: col),
              const SizedBox(height: 24),

              // 2. LAST SESSION
              _SectionLabel('LAST SESSION',
                  sub: lastSess != null ? lastSess.dateLabel : null),
              const SizedBox(height: 8),
              if (lastSess != null)
                _LastSessionBlock(session: lastSess)
              else
                _EmptySessionState(muscle: rec.muscle),
              const SizedBox(height: 22),

              // 3. RECOMMENDATIONS
              if (suggests.isNotEmpty) ...[
                _SectionLabel('RECOMMENDED',
                    sub: _coachReason(rec.recoveryScore)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 152,
                  child: ListView.separated(
                    scrollDirection:  Axis.horizontal,
                    physics:          const BouncingScrollPhysics(),
                    itemCount:        suggests.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final ex   = suggests[i];
                      final name = ex['name'] as String? ?? '';
                      final type = ex['type'] as String? ?? '';
                      return _SuggestionCard(
                        exercise: ex,
                        ai: ai,
                        isAdding: _adding.contains(name),
                        isInPlan: _isInPlan(name, type),
                        onToggle: _adding.contains(name)
                            ? null
                            : () => _toggle(ex),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // 4. BROWSE
              _BrowseButton(
                muscleLabel: rec.muscle,
                onTap: () {
                  final parentCtx = widget.parentContext;
                  final dayIdx2   = widget.wp.todayIndex;
                  final category  = rec.muscle;
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showExercisePicker(parentCtx, dayIdx2,
                        initialCategory: category);
                  });
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final MuscleRecovery rec;
  final Color col;
  const _Header({required this.rec, required this.col});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Animated recovery ring
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: rec.recoveryScore / 100.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: 72, height: 72,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: const Size(72, 72),
              painter: _RingPainter(progress: v, color: col),
            ),
            Text(
              rec.recoveryScore >= 80 ? 'PEAK'
                  : rec.recoveryScore >= 65 ? 'GOOD'
                  : rec.recoveryScore >= 45 ? 'LOW'
                  : 'REST',
              style: GoogleFonts.inter(
                  color: col, fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5, height: 1.0),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rec.muscle,
              style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 26,
                  fontWeight: FontWeight.w800, letterSpacing: 0.3, height: 1.0)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withValues(alpha: 0.22), width: 0.5),
            ),
            child: Text(_recoveryLabel(rec.recoveryScore),
                style: GoogleFonts.inter(
                    color: col, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0)),
          ),
          const SizedBox(height: 5),
          Text(
            (rec.lastTrainedDate.isNotEmpty && rec.lastTrainedDate != 'Never')
                ? _formatLastTrained(rec.lastTrainedDate)
                : 'No training history',
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5, fontWeight: FontWeight.w400),
          ),
        ],
      )),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String  label;
  final String? sub;
  const _SectionLabel(this.label, {this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
        style: GoogleFonts.inter(
            color: AppColors.gold, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.0)),
    if (sub != null) ...[
      const SizedBox(width: 7),
      Expanded(
        child: Text(sub!,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 9.5,
                fontWeight: FontWeight.w400)),
      ),
    ],
  ]);
}

class _EmptySessionState extends StatelessWidget {
  final String muscle;
  const _EmptySessionState({required this.muscle});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: Colors.white.withValues(alpha: 0.06), width: 0.7),
    ),
    child: Row(children: [
      Icon(Icons.history_rounded,
          size: 15, color: AppColors.textMuted.withValues(alpha: 0.45)),
      const SizedBox(width: 10),
      Expanded(
        child: Text('Complete 1 $muscle session to unlock smarter recommendations.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5, fontWeight: FontWeight.w400)),
      ),
    ]),
  );
}

class _LastSessionBlock extends StatelessWidget {
  final _LastSession session;
  const _LastSessionBlock({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.18), width: 0.5),
            ),
            child: Text(session.dateLabel,
                style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 9, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 10),
          // Exercise rows
          ...session.exercises.take(4).map((ex) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(ex.name,
                  style: GoogleFonts.inter(
                      color: const Color(0xFFCCCCCC),
                      fontSize: 12, fontWeight: FontWeight.w500))),
              Text(
                ex.isTime
                    ? '${ex.reps} min'
                    : ex.weight > 0
                        ? '${ex.weight % 1 == 0 ? ex.weight.toInt() : ex.weight}kg × ${ex.reps}'
                        : '${ex.reps} reps',
                style: GoogleFonts.rajdhani(
                    color: AppColors.textSecondary,
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ]),
          )),
          if (session.exercises.length > 1) ...[
            Divider(color: Colors.white.withValues(alpha: 0.05), height: 14),
            Row(children: [
              Text('${session.exercises.length} exercises',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10, fontWeight: FontWeight.w500)),
              if (session.totalVolume > 0) ...[
                Text(' · ', style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 10)),
                Text(
                  session.totalVolume >= 1000
                      ? '${(session.totalVolume / 1000).toStringAsFixed(1)}t total'
                      : '${session.totalVolume.toStringAsFixed(0)}kg total',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final AICoachInsight       ai;
  final bool                 isAdding;
  final bool                 isInPlan;
  final VoidCallback?        onToggle;

  const _SuggestionCard({
    required this.exercise,
    required this.ai,
    required this.isAdding,
    required this.isInPlan,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name    = exercise['name']       as String? ?? '';
    final movement= exercise['movement']   as String? ?? '';
    final defReps = exercise['defaultReps']as int?    ?? 10;

    final borderCol = isInPlan
        ? AppColors.green.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.07);
    final bgCol   = isInPlan
        ? AppColors.green.withValues(alpha: 0.04)
        : const Color(0xFF111111);
    final btnCol  = isInPlan ? AppColors.green : AppColors.gold;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 146,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgCol,
              btnCol.withValues(alpha: 0.025),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: btnCol.withValues(alpha: 0.05),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          btnCol.withValues(alpha: 0.22),
                          btnCol.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: btnCol.withValues(alpha: 0.20),
                        width: 0.6,
                      ),
                    ),
                    child: Icon(
                      movement == 'compound'
                          ? Icons.fitness_center_rounded
                          : defReps >= 12
                              ? Icons.bolt_rounded
                              : Icons.auto_graph_rounded,
                      size: 12,
                      color: btnCol,
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3)),
                  ),
                ],
              ),

              const SizedBox(height: 7),
              Text(
                movement.isNotEmpty
                    ? '${exercise['muscle']} • ${_cap(movement)} movement'
                    : '${exercise['muscle']} • ${defReps} reps target',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _MiniTag(
                    label: movement.isNotEmpty
                        ? _cap(movement)
                        : 'Strength',
                  ),
                  _MiniTag(
                    label: defReps <= 6
                        ? 'Heavy'
                        : defReps <= 10
                            ? 'Hypertrophy'
                            : 'Volume',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ai.fatigueLevel == FatigueLevel.fresh
                    ? 'AI: peak readiness — performance focus'
                    : ai.fatigueLevel == FatigueLevel.fatigued
                        ? 'AI: fatigue detected — controlled intensity'
                        : ai.weightModifier < 0.95
                            ? 'AI: recovery-preserving load strategy'
                            : ai.weightModifier > 1.0
                                ? 'AI: progressive overload recommended'
                                : ai.dailyCoachMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.72),
                  fontSize: 7.2,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: btnCol.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: btnCol.withValues(alpha: isInPlan ? 0.20 : 0.22),
                    width: 0.7),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (isAdding)
                  SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: btnCol),
                  )
                else
                  Icon(
                    isInPlan ? Icons.remove_rounded : Icons.add_rounded,
                    size: 11, color: btnCol),
                if (!isAdding) ...[
                  const SizedBox(width: 4),
                  Text(
                    isInPlan ? 'Remove' : 'Add to Today',
                    style: GoogleFonts.inter(
                        color: btnCol, fontSize: 9.5,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}



class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.gold.withValues(alpha: 0.92),
          fontSize: 6.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _BrowseButton extends StatefulWidget {
  final String       muscleLabel;
  final VoidCallback onTap;
  const _BrowseButton({required this.muscleLabel, required this.onTap});

  @override
  State<_BrowseButton> createState() => _BrowseButtonState();
}

class _BrowseButtonState extends State<_BrowseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                      AppColors.gold.withValues(alpha: 0.10),
                      AppColors.gold.withValues(alpha: 0.05),
                    ]
                  : [
                      AppColors.gold.withValues(alpha: 0.06),
                      AppColors.gold.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: _pressed ? 0.28 : 0.18),
              width: 0.8,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Browse ${widget.muscleLabel} Exercises',
                style: GoogleFonts.inter(
                    color: AppColors.gold.withValues(alpha: 0.85),
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            AnimatedSlide(
              offset: _pressed ? const Offset(0.15, 0) : Offset.zero,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: Icon(Icons.arrow_forward_rounded,
                  color: AppColors.gold.withValues(alpha: 0.65), size: 14),
            ),
          ]),
        ),
      ),
    );
  }
}
