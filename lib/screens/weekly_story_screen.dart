// lib/screens/weekly_story_screen.dart — CINEMATIC WEEKLY STORY
// Instagram-stories style full-screen recap of the training week.
//   • 6 auto-advancing slides (5s each) with progress bars
//   • Tap right = next, tap left = back, hold = pause
//   • 70% emotion, 30% data — the user remembers the feeling
//   • Final slide: share via Screenshot
//   • Pure presentation — no engines touched
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../review/models/weekly_review.dart';
import '../models/weekly_review_data.dart';
import '../services/observation_engine.dart';
import '../services/protein_intelligence_service.dart';
import '../utils/app_constants.dart';

// ════════════════════════════════════════════════
// ENTRY POINT
// ════════════════════════════════════════════════

void openWeeklyStory(BuildContext context) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const WeeklyStoryScreen(),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 1.06, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  ));
}

// ════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════

class WeeklyStoryScreen extends StatefulWidget {
  const WeeklyStoryScreen({super.key});

  @override
  State<WeeklyStoryScreen> createState() => _WeeklyStoryScreenState();
}

class _WeeklyStoryScreenState extends State<WeeklyStoryScreen>
    with TickerProviderStateMixin {
  static const Duration _slideDur = Duration(seconds: 5);

  final ScreenshotController _shot = ScreenshotController();

  late final AnimationController _progressC;
  int _slide = 0;
  bool _paused = false;

  late WeeklyReview _review;
  late WeeklyReviewData _data;

  // Nutrition slide — included only when the user logged protein this week.
  int _slideCount = 6;
  int _proteinDaysOnTarget = 0;
  bool _hasNutritionSlide = false;
  String _proteinHabit = '';

  @override
  void initState() {
    super.initState();
    final ap = context.read<AppProvider>();
    _review = ap.weeklyReview;
    _data   = ap.weeklyReviewData;
    _loadNutrition(ap.proteinGoalG);

    _progressC = AnimationController(vsync: this, duration: _slideDur)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      })
      ..forward();
  }

  Future<void> _loadNutrition(int proteinGoal) async {
    final week   = await ProteinIntelligenceService.weeklyOnTarget(proteinGoal);
    // One remembered habit at most, picked by the ObservationEngine —
    // confidence-gated at the source, 7-day cooldown across all surfaces.
    final memory = await ProteinIntelligenceService.getMemory();
    final obs = await ObservationEngine.pick(
      // ignore: use_build_context_synchronously
      mounted
          ? context
              .read<AppProvider>()
              .observationCandidates(proteinMemory: memory)
              .where((o) => o.source == 'protein')
              .toList()
          : const [],
    );
    // Only add the slide when nutrition was actually tracked this week,
    // and only while the user is still on the early slides.
    if (!mounted || week.daysWithLogs == 0 || _slide > 3) return;
    setState(() {
      _proteinDaysOnTarget = week.onTarget;
      _hasNutritionSlide   = true;
      _slideCount          = 7;
      _proteinHabit        =
          (obs != null && memory.consistentSource.isNotEmpty)
              ? memory.consistentSource
              : '';
    });
    if (_proteinHabit.isNotEmpty && obs != null) {
      // The slide is part of the story flow — it will be seen.
      ObservationEngine.markSeen(obs);
    }
  }

  @override
  void dispose() {
    _progressC.dispose();
    super.dispose();
  }

  void _next() {
    if (_slide >= _slideCount - 1) {
      _progressC.stop();
      _progressC.value = 1;
      setState(() {});
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _slide++);
    _progressC
      ..reset()
      ..forward();
  }

  void _prev() {
    if (_slide == 0) {
      _progressC
        ..reset()
        ..forward();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _slide--);
    _progressC
      ..reset()
      ..forward();
  }

  void _setPaused(bool v) {
    if (_paused == v) return;
    setState(() => _paused = v);
    if (v) {
      _progressC.stop();
    } else if (_progressC.value < 1) {
      _progressC.forward();
    }
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    _setPaused(true);
    try {
      final img = await _shot.capture(
        delay: const Duration(milliseconds: 80),
        pixelRatio: 3.0,
      );
      if (img == null) return;
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/lifton_week_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(img);
      await Share.shareXFiles(
        [XFile(f.path)],
        text: 'My week on LiftOn.',
      );
    } catch (e) {
      debugPrint('Weekly story share error: $e');
    } finally {
      _setPaused(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w * 0.32) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        child: SafeArea(
          child: Stack(children: [
            // ── SLIDE CONTENT ────────────────────────────────
            Positioned.fill(
              child: Screenshot(
                controller: _shot,
                child: Container(
                  color: Colors.black,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(_slide),
                      child: _buildSlide(_slide),
                    ),
                  ),
                ),
              ),
            ),

            // ── PROGRESS BARS ────────────────────────────────
            Positioned(
              top: 10, left: 14, right: 14,
              child: AnimatedBuilder(
                animation: _progressC,
                builder: (_, __) => Row(
                  children: List.generate(_slideCount, (i) {
                    final v = i < _slide
                        ? 1.0
                        : i == _slide
                            ? _progressC.value
                            : 0.0;
                    return Expanded(
                      child: Container(
                        height: 2.4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── CLOSE ────────────────────────────────────────
            Positioned(
              top: 22, right: 14,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // SLIDES
  // ══════════════════════════════════════════════

  Widget _buildSlide(int i) {
    // Nutrition sits after Recovery; later slides shift by one when present.
    final adjusted = _hasNutritionSlide && i > 4 ? i - 1 : i;
    if (_hasNutritionSlide && i == 4) {
      return _SlideNutrition(
        daysOnTarget: _proteinDaysOnTarget,
        habit:        _proteinHabit,
      );
    }
    switch (adjusted) {
      case 0:  return _SlideYourWeek(data: _data);
      case 1:  return _SlideMomentum(data: _data);
      case 2:  return _SlideAchievement(review: _review, data: _data);
      case 3:  return _SlideRecovery(data: _data);
      case 4:  return _SlideCoachWord(review: _review);
      default: return _SlideNextWeek(review: _review, data: _data, onShare: _share);
    }
  }
}

// ── Shared slide scaffold ─────────────────────────────────────────────────────

class _SlideShell extends StatelessWidget {
  final String kicker;
  final Widget child;
  const _SlideShell({required this.kicker, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker,
              style: GoogleFonts.inter(
                  color: AppColors.gold.withValues(alpha: 0.60),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3)),
          const Spacer(),
          child,
          const Spacer(flex: 2),
          Row(children: [
            Text('LIFTON',
                style: GoogleFonts.rajdhani(
                    color: Colors.white.withValues(alpha: 0.20),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
          ]),
        ],
      ),
    );
  }
}

class _Rise extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const _Rise({required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 550 + delayMs),
      curve: Interval(delayMs / (550 + delayMs), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ── Slide 1: Your Week ──────────────────────────────────────────────────────

class _SlideYourWeek extends StatelessWidget {
  final WeeklyReviewData data;
  const _SlideYourWeek({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Rise(
          child: Text('Your week.\nWorth\nremembering.',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.02)),
        ),
        const SizedBox(height: 32),
        _Rise(
          delayMs: 280,
          child: Row(children: [
            _bigStat('${data.completedSessions}', 'WORKOUTS'),
            const SizedBox(width: 36),
            _bigStat(_fmtVol(data.weekVolumeKg), 'KG MOVED'),
          ]),
        ),
        if (data.currentStreak > 1) ...[
          const SizedBox(height: 24),
          _Rise(
            delayMs: 500,
            child: Text('${data.currentStreak} active days',
                style: GoogleFonts.inter(
                    color: AppColors.gold.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _bigStat(String v, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v,
              style: GoogleFonts.rajdhani(
                  color: AppColors.gold,
                  fontSize: 40,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2)),
        ],
      );
}

String _fmtVol(double kg) {
  if (kg >= 10000) return '${(kg / 1000).toStringAsFixed(1)}T';
  if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}K';
  return '${kg.round()}';
}

// ── Slide 2: Momentum ───────────────────────────────────────────────────────

class _SlideMomentum extends StatelessWidget {
  final WeeklyReviewData data;
  const _SlideMomentum({required this.data});

  @override
  Widget build(BuildContext context) {
    final adherence = data.adherencePercent;
    final hasPrev   = data.previousWeekVolumeKg > 0;
    final up        = data.volumeDeltaPercent >= 0;

    final headline = adherence >= 80
        ? 'You stayed\nconsistent.'
        : adherence >= 50
            ? 'The work\nwas done.'
            : 'You still\nshowed up.';

    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Rise(
          child: Text(headline,
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.04)),
        ),
        const SizedBox(height: 28),
        _Rise(
          delayMs: 250,
          child: Row(children: [
            _stat('${data.completedSessions}/${data.plannedSessions > 0 ? data.plannedSessions : "–"}',
                'COMPLETED'),
            const SizedBox(width: 36),
            if (hasPrev)
              _stat(
                '${up ? "+" : ""}${data.volumeDeltaPercent.round()}%',
                'VS LAST WEEK',
              ),
          ]),
        ),
        // Silence is premium — the headline and metrics are enough.
      ]),
    );
  }

  Widget _stat(String v, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v,
              style: GoogleFonts.rajdhani(
                  color: AppColors.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8)),
        ],
      );
}

// ── Slide 3: Achievement ────────────────────────────────────────────────────

class _SlideAchievement extends StatelessWidget {
  final WeeklyReview review;
  final WeeklyReviewData data;
  const _SlideAchievement({required this.review, required this.data});

  @override
  Widget build(BuildContext context) {
    String heroValue;
    String heroLabel;

    if (data.prCount > 0) {
      heroValue = data.prCount == 1 ? '1 PR' : '${data.prCount} PRs';
      heroLabel = data.prCount == 1 ? 'Personal record.' : 'Personal records.';
    } else if (data.volumeDeltaPercent > 5 && data.previousWeekVolumeKg > 0) {
      heroValue = '+${data.volumeDeltaPercent.round()}%';
      heroLabel = 'More than last week.';
    } else if (data.adherencePercent >= 80) {
      heroValue = '${data.adherencePercent.round()}%';
      heroLabel = 'Plan adherence.';
    } else if (review.achievements.isNotEmpty) {
      heroValue = '';
      heroLabel = review.achievements.first;
    } else {
      heroValue = '${data.completedSessions}';
      heroLabel = 'Sessions this week.';
    }

    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Rise(
          child: Text(heroValue,
              style: GoogleFonts.rajdhani(
                  color: AppColors.gold,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1.0)),
        ),
        const SizedBox(height: 14),
        _Rise(
          delayMs: 300,
          child: Text(heroLabel,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w400)),
        ),
      ]),
    );
  }
}

// ── Slide 4: Recovery ───────────────────────────────────────────────────────

class _SlideRecovery extends StatelessWidget {
  final WeeklyReviewData data;
  const _SlideRecovery({required this.data});

  @override
  Widget build(BuildContext context) {
    final recovery = data.overallRecovery.round().clamp(0, 100);
    final isGood = recovery >= 70;

    final insight = isGood
        ? 'Your body kept pace.'
        : recovery >= 50
            ? 'Recovery in progress.'
            : 'Give it time.';

    return _SlideShell(
      kicker: '',
      child: Center(
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: recovery / 100.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 160, height: 160,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                  size: const Size(160, 160),
                  painter: _RecoveryRingPainter(progress: v),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(v * 100).round()}',
                      style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0)),
                  Text('%',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 12,
                          fontWeight: FontWeight.w400)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          _Rise(
            delayMs: 600,
            child: Text(insight,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5)),
          ),
          if (data.limitingMuscle.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Rise(
              delayMs: 750,
              child: Text(
                '${_cap(data.limitingMuscle)} still recovering.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _RecoveryRingPainter extends CustomPainter {
  final double progress;
  const _RecoveryRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    canvas.drawCircle(
        c, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white.withValues(alpha: 0.06));
    final sweep = 2 * pi * progress;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_RecoveryRingPainter old) => old.progress != progress;
}

// ── Slide: Nutrition (shown only when protein was tracked this week) ────────

class _SlideNutrition extends StatelessWidget {
  final int daysOnTarget;
  final String habit; // one remembered habit; '' = generic insight
  const _SlideNutrition({required this.daysOnTarget, this.habit = ''});

  String get _insight {
    // One remembered habit, at most — never stacked with other observations.
    if (habit.isNotEmpty && daysOnTarget >= 3) {
      return '$habit carried\nmost of the week.';
    }
    if (daysOnTarget >= 5) {
      return 'Recovery was supported by\nconsistent nutrition.';
    }
    if (daysOnTarget >= 3) {
      return 'Protein stayed steady\nmost of the week.';
    }
    return 'Small improvements here can\nsupport recovery next week.';
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Rise(
          child: Text('Protein',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.04)),
        ),
        const SizedBox(height: 24),
        _Rise(
          delayMs: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$daysOnTarget / 7',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.0)),
              const SizedBox(height: 6),
              Text('DAYS ON TARGET',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _Rise(
          delayMs: 500,
          child: Text(_insight,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5)),
        ),
      ]),
    );
  }
}

// ── Slide 5: Coach's Word ───────────────────────────────────────────────────

class _SlideCoachWord extends StatelessWidget {
  final WeeklyReview review;
  const _SlideCoachWord({required this.review});

  String get _text {
    final raw = review.summary.coachLine.trim();
    if (raw.isEmpty) return 'Stay patient.\nResults follow.';
    final words = raw.split(' ');
    if (words.length > 12) return '${words.take(12).join(' ')}.';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 2,
          color: AppColors.gold.withValues(alpha: 0.40),
        ),
        const SizedBox(height: 24),
        _Rise(
          child: Text(_text,
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.3)),
        ),
      ]),
    );
  }
}

// ── Slide 6: Next Week ──────────────────────────────────────────────────────

class _SlideNextWeek extends StatelessWidget {
  final WeeklyReview review;
  final WeeklyReviewData data;
  final VoidCallback onShare;
  const _SlideNextWeek({required this.review, required this.data, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final focus = review.summary.nextWeekFocus.trim();
    final planned = data.plannedSessions > 0 ? data.plannedSessions : 3;

    return _SlideShell(
      kicker: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Rise(
          child: Text('Until next\nweek.',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.04)),
        ),
        const SizedBox(height: 28),
        _Rise(
          delayMs: 200,
          child: Row(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOAL',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('$planned workouts',
                    style: GoogleFonts.rajdhani(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 36),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRIORITY',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(
                  _extractPriority(focus),
                  style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 32),
        _Rise(
          delayMs: 450,
          child: GestureDetector(
            onTap: onShare,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.ios_share_rounded,
                    color: Colors.black, size: 15),
                const SizedBox(width: 8),
                Text('SHARE',
                    style: GoogleFonts.rajdhani(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  String _extractPriority(String focus) {
    if (focus.isEmpty) return 'Consistency';
    final l = focus.toLowerCase();
    if (l.contains('recovery') || l.contains('rest')) return 'Recovery';
    if (l.contains('volume')) return 'Volume';
    if (l.contains('strength') || l.contains('heavy')) return 'Strength';
    if (l.contains('consistency') || l.contains('show up')) return 'Consistency';
    if (l.contains('progressive') || l.contains('overload')) return 'Progression';
    final words = focus.split(' ');
    if (words.length <= 2) return focus;
    return 'Consistency';
  }
}
