// lib/widgets/planner/session_prophecy_card.dart — SESSION PROPHECY
// Pre-workout prediction card shown at the top of today's day view.
//
// This widget is PRESENTATION ONLY:
//   • Renders ProphecyData produced by SessionProphecyGenerator
//   • Animates entry, pulse, fulfillment
//   • Owns dismiss state (session-scoped, resets on restart)
//
// Trust, data resolution, and claim classification live in
// lib/ai/generators/session_prophecy_generator.dart.
//
// The render site (planner_screen.dart) gates this card on
// AppProvider.aiMaturity.allowedClaims.ui.canShowSessionProphecy.
// Before that gate is true the SessionProphecyFallbackCard is shown instead.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../ai/generators/session_prophecy_generator.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';

// ════════════════════════════════════════════════
// VERDICT — live check against logged sets
// ════════════════════════════════════════════════

enum _Verdict { pending, fulfilled, close }

_Verdict _judge(ProphecyData pr) {
  final sets = pr.ex.sets;
  bool hit = false;
  for (final s in sets) {
    if (!s.done) continue;
    final beatPrediction =
        s.weight >= pr.predWeight - 0.01 && s.reps >= pr.predReps;
    final beatBest = s.weight > pr.prevBestWeight + 0.01;
    if (beatPrediction || beatBest) { hit = true; break; }
  }
  if (hit) return _Verdict.fulfilled;
  final allDone = sets.isNotEmpty && sets.every((s) => s.done);
  return allDone ? _Verdict.close : _Verdict.pending;
}

// ════════════════════════════════════════════════
// CARD — predictive-phase renderer
// ════════════════════════════════════════════════

class SessionProphecyCard extends StatefulWidget {
  final DayPlan day;
  final int idx;
  const SessionProphecyCard({super.key, required this.day, required this.idx});

  // Session-scoped dismissals — resets on app restart (intentional)
  static final Set<String> _dismissed = {};

  @override
  State<SessionProphecyCard> createState() => _SessionProphecyCardState();
}

class _SessionProphecyCardState extends State<SessionProphecyCard>
    with TickerProviderStateMixin {
  late final AnimationController _entryC;
  late final Animation<double> _entry;
  late final AnimationController _pulseC;

  bool _accepted = false;
  bool _celebrated = false;

  String get _dayKey {
    final now = DateTime.now();
    return '${widget.idx}-${now.year}-${now.month}-${now.day}';
  }

  @override
  void initState() {
    super.initState();
    _entryC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entry = CurvedAnimation(parent: _entryC, curve: Curves.easeOutCubic);
    _pulseC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryC.forward();
    });
  }

  @override
  void dispose() {
    _entryC.dispose();
    _pulseC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SessionProphecyCard._dismissed.contains(_dayKey)) {
      return const SizedBox.shrink();
    }

    final p = context.read<AppProvider>();

    // Low recovery warning — shown instead of prophecy when readiness is poor.
    // Only when health is connected (otherwise readiness defaults to 72 = normal).
    if (p.healthConnectLinked && p.readinessScore < 50) {
      return _buildRecoveryLowCard();
    }

    final prophecy = const SessionProphecyGenerator().generate(
      ap:   p,
      day:  widget.day,
      lang: p.aiMaturity.languageProfile,
    );
    if (prophecy == null) return const SizedBox.shrink();

    final verdict = _judge(prophecy);

    // One-time haptic on fulfillment
    if (verdict == _Verdict.fulfilled && !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
      });
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_entry, _pulseC]),
      builder: (_, __) {
        final pulse = _pulseC.value;
        return Transform.translate(
          offset: Offset(0, 18 * (1 - _entry.value)),
          child: Opacity(
            opacity: _entry.value.clamp(0.0, 1.0),
            child: _card(prophecy, verdict, pulse),
          ),
        );
      },
    );
  }

  Widget _buildRecoveryLowCard() {
    return AnimatedBuilder(
      animation: _entry,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, 18 * (1 - _entry.value)),
        child: Opacity(
          opacity: _entry.value.clamp(0.0, 1.0),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0E),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.7,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
              child: Row(children: [
                const Text('🌙', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOVERY LOW',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Not the day to go heavy — lighter sets still count.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() =>
                        SessionProphecyCard._dismissed.add(_dayKey));
                  },
                  child: Icon(Icons.close_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.25)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ProphecyData pr, _Verdict verdict, double pulse) {
    final fulfilled = verdict == _Verdict.fulfilled;
    final close     = verdict == _Verdict.close;
    const accent    = AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: fulfilled ? const Color(0xFF141005) : const Color(0xFF0C0A05),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: accent.withValues(
              alpha: fulfilled ? 0.50 : 0.18 + 0.08 * pulse),
          width: fulfilled ? 1.1 : 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ─────────────────────────────────────────
          Row(children: [
            Text(fulfilled ? '⚡' : '🔮',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 7),
            Text(
              fulfilled
                  ? 'PROPHECY FULFILLED'
                  : close
                      ? 'SO CLOSE'
                      : "TODAY'S PROPHECY",
              style: GoogleFonts.inter(
                color: AppColors.gold.withValues(alpha: 0.85),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            if (!fulfilled && !close)
              _ConfidenceRing(confidence: pr.confidence)
            else if (fulfilled)
              const Icon(Icons.verified_rounded,
                  color: AppColors.gold, size: 18),
            // Dismiss
            if (!fulfilled) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() =>
                      SessionProphecyCard._dismissed.add(_dayKey));
                },
                child: Icon(Icons.close_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ]),
          const SizedBox(height: 10),

          // ── Body ───────────────────────────────────────────────
          if (fulfilled) ...[
            Text(
              _cleanName(pr.ex.name).toUpperCase(),
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6),
            ),
            const SizedBox(height: 5),
            Text(
              'Prediction beaten 🏆',
              style: GoogleFonts.rajdhani(
                  color: AppColors.gold,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.0),
            ),
            const SizedBox(height: 6),
            Text(
              'The call was ${_fmtW(pr.predWeight)} ${pr.ex.unit} × ${pr.predReps} — you delivered.',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ] else if (close) ...[
            Text(
              _cleanName(pr.ex.name).toUpperCase(),
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6),
            ),
            const SizedBox(height: 5),
            Text(
              'Close — the bar moves next time.',
              style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.05),
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmtW(pr.predWeight)} ${pr.ex.unit} × ${pr.predReps} is still waiting for you.',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ] else ...[
            // Exercise — metadata tier
            Text(
              _cleanName(pr.ex.name).toUpperCase(),
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6),
            ),
            const SizedBox(height: 5),
            // Prediction — the hero of this card
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${_fmtW(pr.predWeight)} ${pr.ex.unit} × ${pr.predReps}',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1.0),
                ),
                const SizedBox(width: 8),
                Text('possible today',
                    style: GoogleFonts.rajdhani(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your best: ${_fmtW(pr.prevBestWeight)} ${pr.ex.unit} × ${pr.prevBestReps}'
              '  ·  based on today\'s readiness',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 10.5),
            ),
            const SizedBox(height: 13),

            // Challenge button
            GestureDetector(
              onTap: _accepted
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      setState(() => _accepted = true);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: _accepted
                      ? AppColors.gold.withValues(alpha: 0.10)
                      : AppColors.gold,
                  borderRadius: BorderRadius.circular(11),
                  border: _accepted
                      ? Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 0.7)
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _accepted
                        ? Icons.bolt_rounded
                        : Icons.local_fire_department_rounded,
                    size: 14,
                    color: _accepted ? AppColors.gold : Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _accepted ? 'CHALLENGE ACTIVE' : 'CHALLENGE ACCEPTED',
                    style: GoogleFonts.rajdhani(
                      color: _accepted ? AppColors.gold : Colors.black,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  static String _cleanName(String raw) {
    if (raw.isEmpty) return 'Main lift';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String _fmtW(double w) =>
      w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
}

// ════════════════════════════════════════════════
// CONFIDENCE RING — small circular gauge
// ════════════════════════════════════════════════

class _ConfidenceRing extends StatelessWidget {
  final int confidence;
  const _ConfidenceRing({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34, height: 34,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(34, 34),
          painter: _RingGaugePainter(progress: confidence / 100),
        ),
        Text('$confidence%',
            style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 7.5,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double progress;
  const _RingGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    canvas.drawCircle(
        c, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = AppColors.gold.withValues(alpha: 0.12));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_RingGaugePainter old) => old.progress != progress;
}

// RFC-PLANNER-UX-001 amendment to Step 9: the fallback card was removed.
// When canShowSessionProphecy is false the coaching slot simply renders
// nothing — no filler copy while the AI earns predictive authority.
