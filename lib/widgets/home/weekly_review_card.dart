// lib/widgets/home/weekly_review_card.dart
//
// WeeklyReviewCard — surfaces WeeklyReview intelligence to the home screen.
// Read-only. All data from AppProvider via Selector. No business logic.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../review/models/weekly_recommendation.dart';
import '../../review/models/weekly_review.dart';
import '../../utils/app_constants.dart';

// ── Data snapshot ──────────────────────────────────────────────────────────────

@immutable
class _ReviewCardData {
  final double overallScore;
  final double recoveryScore;
  final double consistencyScore;
  final double progressScore;
  final WeeklyGrade overallGrade;
  final WeeklyGrade recoveryGrade;
  final WeeklyGrade consistencyGrade;
  final WeeklyGrade progressGrade;
  final String coachLine;
  final String nextWeekFocus;
  final List<WeeklyRecommendation> recommendations;
  final bool hasData;

  const _ReviewCardData({
    required this.overallScore,
    required this.recoveryScore,
    required this.consistencyScore,
    required this.progressScore,
    required this.overallGrade,
    required this.recoveryGrade,
    required this.consistencyGrade,
    required this.progressGrade,
    required this.coachLine,
    required this.nextWeekFocus,
    required this.recommendations,
    required this.hasData,
  });

  factory _ReviewCardData.from(AppProvider ap) {
    final r = ap.weeklyReview;
    return _ReviewCardData(
      overallScore:      r.overallScore,
      recoveryScore:     r.recoveryScore,
      consistencyScore:  r.consistencyScore,
      progressScore:     r.progressScore,
      overallGrade:      r.overallGrade,
      recoveryGrade:     r.recoveryGrade,
      consistencyGrade:  r.consistencyGrade,
      progressGrade:     r.progressGrade,
      coachLine:         r.summary.coachLine,
      nextWeekFocus:     r.summary.nextWeekFocus,
      recommendations:   r.recommendations.take(3).toList(),
      hasData:           r.hasData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ReviewCardData) return false;
    return other.overallScore     == overallScore     &&
           other.recoveryScore    == recoveryScore    &&
           other.consistencyScore == consistencyScore &&
           other.progressScore    == progressScore    &&
           other.overallGrade     == overallGrade     &&
           other.hasData          == hasData;
  }

  @override
  int get hashCode => Object.hash(
    overallScore, recoveryScore, consistencyScore, progressScore,
    overallGrade, hasData,
  );
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class WeeklyReviewCard extends StatelessWidget {
  const WeeklyReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Selector<AppProvider, _ReviewCardData>(
        selector: (_, ap) => _ReviewCardData.from(ap),
        builder:  (_, data, __) => _WeeklyReviewCardBody(data: data),
      ),
    );
  }
}

class _WeeklyReviewCardBody extends StatelessWidget {
  final _ReviewCardData data;
  const _WeeklyReviewCardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _gradeColor(data.overallGrade).withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(grade: data.overallGrade, score: data.overallScore),
          const _Divider(),
          _ScoreRow(
            recovery:    data.recoveryScore,
            consistency: data.consistencyScore,
            progress:    data.progressScore,
            rGrade:      data.recoveryGrade,
            cGrade:      data.consistencyGrade,
            pGrade:      data.progressGrade,
          ),
          if (data.hasData) ...[
            const _Divider(),
            _CoachLine(text: data.coachLine),
            const _Divider(),
            _NextWeekFocus(text: data.nextWeekFocus),
            if (data.recommendations.isNotEmpty) ...[
              const _Divider(),
              _RecommendationList(items: data.recommendations),
            ],
          ] else ...[
            const _Divider(),
            const _OnboardingMessage(),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final WeeklyGrade grade;
  final double score;
  const _Header({required this.grade, required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _gradeColor(grade).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _gradeColor(grade).withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                grade.letter,
                style: AppTextStyles.h3.copyWith(color: _gradeColor(grade)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEEKLY REVIEW', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  grade.label,
                  style: AppTextStyles.h4.copyWith(color: _gradeColor(grade)),
                ),
              ],
            ),
          ),
          Text(
            '${score.round()}',
            style: AppTextStyles.number.copyWith(color: _gradeColor(grade)),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final double recovery, consistency, progress;
  final WeeklyGrade rGrade, cGrade, pGrade;
  const _ScoreRow({
    required this.recovery,
    required this.consistency,
    required this.progress,
    required this.rGrade,
    required this.cGrade,
    required this.pGrade,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: _ScorePill(label: 'Recovery',    score: recovery,    grade: rGrade)),
          const SizedBox(width: 8),
          Expanded(child: _ScorePill(label: 'Consistency', score: consistency, grade: cGrade)),
          const SizedBox(width: 8),
          Expanded(child: _ScorePill(label: 'Progress',    score: progress,    grade: pGrade)),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final double score;
  final WeeklyGrade grade;
  const _ScorePill({required this.label, required this.score, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            '${score.round()}',
            style: AppTextStyles.h4.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(grade.letter, style: AppTextStyles.caption.copyWith(color: color)),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CoachLine extends StatelessWidget {
  final String text;
  const _CoachLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💬 ', style: AppTextStyles.bodySmall),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextWeekFocus extends StatelessWidget {
  final String text;
  const _NextWeekFocus({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 ', style: AppTextStyles.bodySmall),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  final List<WeeklyRecommendation> items;
  const _RecommendationList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT WEEK', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ...items.map((r) => _RecommendationTile(item: r)),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final WeeklyRecommendation item;
  const _RecommendationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.isUrgent ? AppColors.red : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  item.detail,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingMessage extends StatelessWidget {
  const _OnboardingMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F4C5}', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your first review will be ready after your first training week.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('\u{1F3AF}', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Focus this week: show up and complete your first session.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.borderSoft);
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _gradeColor(WeeklyGrade grade) {
  switch (grade) {
    case WeeklyGrade.S: return AppColors.goldHero;
    case WeeklyGrade.A: return AppColors.green;
    case WeeklyGrade.B: return AppColors.blue;
    case WeeklyGrade.C: return AppColors.orange;
    case WeeklyGrade.D: return AppColors.red;
  }
}
