// lib/widgets/home/recovery_bottom_sheet.dart
// Luxury glassmorphism bottom sheet shown when user taps a muscle group.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_constants.dart';
import 'muscle_overlay_painter.dart';

const _kExercises = <String, List<String>>{
  'chest':     ['Bench Press', 'Push-Ups', 'Cable Flyes', 'Dips'],
  'back':      ['Pull-Ups', 'Barbell Rows', 'Lat Pulldown', 'Deadlift'],
  'legs':      ['Squats', 'Leg Press', 'Romanian Deadlift', 'Lunges'],
  'shoulders': ['Overhead Press', 'Lateral Raises', 'Face Pulls', 'Upright Rows'],
  'arms':      ['Bicep Curls', 'Hammer Curls', 'Tricep Extensions', 'Dips'],
  'core':      ['Planks', 'Hanging Leg Raises', 'Cable Crunches', 'Dead Bug'],
};

String _intensityLabel(double score) {
  if (score >= 80) return 'Ready for heavy work';
  if (score >= 60) return 'Moderate — keep reps clean';
  if (score >= 40) return 'Light sets today';
  return 'Rest or easy stretching';
}

class RecoveryBottomSheet {
  RecoveryBottomSheet._();

  static void show(
    BuildContext context,
    MuscleRecovery recovery, {
    bool isFront = true,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecoverySheet(recovery: recovery, isFront: isFront),
    );
  }
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _RecoverySheet extends StatelessWidget {
  final MuscleRecovery recovery;
  final bool isFront;
  const _RecoverySheet({required this.recovery, required this.isFront});

  String get _displayName {
    if (recovery.muscle == 'Arms') {
      return isFront ? 'Arms  ·  Biceps' : 'Arms  ·  Triceps';
    }
    return recovery.muscle;
  }

  @override
  Widget build(BuildContext context) {
    final score = recovery.recoveryScore.toDouble();
    final color = recoveryColor(score);
    final status = recoveryStatus(score);
    final exercises = _kExercises[recovery.muscle.toLowerCase()] ?? [];

    final margin = EdgeInsets.only(
      left: 12, right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
    );

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              // Slight color tint from recovery status + semi-transparent dark base
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bgModal.withValues(alpha: 0.92),
                  Color.lerp(AppColors.bgModal, color, 0.04)!
                      .withValues(alpha: 0.92),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 6),
                  width: 36, height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: AppTextStyles.h3.copyWith(letterSpacing: 0.2),
                                ),
                                const SizedBox(height: 4),
                                _StatusChip(status: status, color: color),
                              ],
                            ),
                          ),
                          _ScoreRing(score: score, color: color),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        children: [
                          Expanded(child: _StatBox(
                            label: 'Readiness',
                            value: status,
                            color: color,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _StatBox(
                            label: 'Fatigue',
                            value: score >= 80 ? 'Normal'
                                : score >= 60 ? 'Elevated'
                                : 'High',
                            color: AppColors.textMuted,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _StatBox(
                            label: 'Last trained',
                            value: recovery.lastTrainedDate == 'Never'
                                ? '—'
                                : recovery.lastTrainedDate,
                            color: AppColors.textSecondary,
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AI Recommendation
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                              color: color.withValues(alpha: 0.18), width: 0.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: color, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Coach note',
                                    style: AppTextStyles.caption.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(recovery.message,
                                      style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Intensity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bgCardLight,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border:
                              Border.all(color: AppColors.borderSoft, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt, color: color, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Suggested intensity',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _intensityLabel(score).split('—').first.trim(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (exercises.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Exercises to try',
                            style: AppTextStyles.sectionTitle.copyWith(letterSpacing: 0.2)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children:
                              exercises.map((e) => _ExerciseChip(e)).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  final Color color;
  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64, height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: score / 100.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => CircularProgressIndicator(
              value: v,
              strokeWidth: 4,
              backgroundColor: AppColors.bgElevated,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            score >= 80 ? 'PEAK'
                : score >= 65 ? 'GOOD'
                : score >= 45 ? 'LOW'
                : 'REST',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.borderSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  final String label;
  const _ExerciseChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.borderMedium, width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
