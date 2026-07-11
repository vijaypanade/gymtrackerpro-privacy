// lib/widgets/pr_celebration.dart — Phase 4
// Full-screen PR celebration — shown when user breaks a Personal Record
// Pure Flutter — no external packages
// Usage: showPRCelebration(context, exerciseName: 'Bench Press', weight: 100, reps: 8)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';

// ════════════════════════════════════════════════
// PUBLIC API
// ════════════════════════════════════════════════
Future<void> showPRCelebration(
  BuildContext context, {
  required String exerciseName,
  required double weight,
  required int reps,
  required int xpEarned,
  String unit = 'kg',
}) async {
  HapticFeedback.heavyImpact();
  await Future.delayed(const Duration(milliseconds: 100));
  if (!context.mounted) return;
  HapticFeedback.heavyImpact();

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'PR',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, __) => _PRScreen(
      exerciseName: exerciseName,
      weight: weight, reps: reps,
      xpEarned: xpEarned, unit: unit,
    ),
  );
}

// ════════════════════════════════════════════════
// GOLDEN CONFETTI — special PR colors
// ════════════════════════════════════════════════
class _GoldParticle {
  double x, y, vx, vy, rot, rotV, size, opacity;
  Color color;
  int shape;
  _GoldParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.rot, required this.rotV,
    required this.size, required this.color,
    required this.shape, this.opacity = 1.0,
  });
}

class _GoldConfettiPainter extends CustomPainter {
  final List<_GoldParticle> particles;
  _GoldConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rot);
      switch (p.shape) {
        case 0:
          canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero,
                width: p.size, height: p.size * 0.4),
            const Radius.circular(2)), paint);
          break;
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
          break;
        case 2:
          // Star shape
          final path = Path();
          for (int i = 0; i < 5; i++) {
            final a1 = (i * 4 * pi / 5) - pi / 2;
            final a2 = a1 + 2 * pi / 5;
            if (i == 0) {
              path.moveTo(p.size * 0.5 * cos(a1), p.size * 0.5 * sin(a1));
            } else {
              path.lineTo(p.size * 0.5 * cos(a1), p.size * 0.5 * sin(a1));
            }
            path.lineTo(p.size * 0.22 * cos(a2), p.size * 0.22 * sin(a2));
          }
          path.close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override bool shouldRepaint(_GoldConfettiPainter _) => true;
}

class _GoldConfetti extends StatefulWidget {
  const _GoldConfetti();
  @override State<_GoldConfetti> createState() => _GoldConfettiState();
}

class _GoldConfettiState extends State<_GoldConfetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_GoldParticle> _particles = [];
  final _rng = Random();

  // PR special colors: gold, orange, white, yellow
  static const _colors = [
    Color(0xFFFFCC00), Color(0xFFFFAA00), Color(0xFFFF6B00),
    Color(0xFFFFFFFF), Color(0xFFFFF176), Color(0xFFFFD700),
    Color(0xFFFF8C00), Color(0xFFFFA500),
  ];

  @override
  void initState() {
    super.initState();
    _spawn();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 50))
      ..addListener(_tick)
      ..repeat();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _spawn(burst: true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _spawn(burst: true);
    });
  }

  void _spawn({bool burst = false}) {
    for (int i = 0; i < (burst ? 40 : 100); i++) {
      final cx = burst
          ? 0.3 + _rng.nextDouble() * 0.4
          : (_rng.nextBool() ? 0.1 : 0.9)
              + (_rng.nextDouble() - 0.5) * 0.15;
      _particles.add(_GoldParticle(
        x: cx, y: -0.03 - _rng.nextDouble() * 0.05,
        vx: (_rng.nextDouble() - 0.5) * 0.009,
        vy: 0.002 + _rng.nextDouble() * 0.007,
        rot: _rng.nextDouble() * 2 * pi,
        rotV: (_rng.nextDouble() - 0.5) * 0.20,
        size: 7 + _rng.nextDouble() * 11,
        color: _colors[_rng.nextInt(_colors.length)],
        shape: _rng.nextInt(3),
        opacity: 0.9 + _rng.nextDouble() * 0.1,
      ));
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x  += p.vx;
        p.y  += p.vy;
        p.vy += 0.00013;
        p.vx *= 0.997;
        p.rot += p.rotV;
        if (p.y > 0.72) p.opacity = (p.opacity - 0.018).clamp(0.0, 1.0);
      }
      _particles.removeWhere((p) => p.y > 1.1 || p.opacity <= 0);
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _GoldConfettiPainter(List.from(_particles)),
      child: const SizedBox.expand(),
    ),
  );
}

// ════════════════════════════════════════════════
// PR SCREEN
// ════════════════════════════════════════════════
class _PRScreen extends StatefulWidget {
  final String exerciseName, unit;
  final double weight;
  final int reps, xpEarned;
  const _PRScreen({
    required this.exerciseName, required this.weight,
    required this.reps, required this.xpEarned, required this.unit,
  });
  @override State<_PRScreen> createState() => _PRScreenState();
}

class _PRScreenState extends State<_PRScreen>
    with TickerProviderStateMixin {

  late AnimationController _trophyC, _cardC, _shimmerC;
  late Animation<double> _trophy, _card, _shimmer;

  @override
  void initState() {
    super.initState();

    _trophyC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _trophy = CurvedAnimation(parent: _trophyC, curve: Curves.elasticOut);

    _cardC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _card = CurvedAnimation(parent: _cardC, curve: Curves.easeOutBack);

    _shimmerC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerC, curve: Curves.easeInOut);

    Future.delayed(const Duration(milliseconds: 100),
        () { if (mounted) _trophyC.forward(); });
    Future.delayed(const Duration(milliseconds: 350),
        () { if (mounted) _cardC.forward(); });
  }

  @override
  void dispose() {
    _trophyC.dispose(); _cardC.dispose(); _shimmerC.dispose();
    super.dispose();
  }

  String get _prValue {
    if (widget.unit == 'min') return '${widget.weight.toInt()} min';
    if (widget.unit == 'reps' || widget.weight == 0) {
      return '${widget.reps} reps';
    }
    return '${widget.weight.toStringAsFixed(1)} ${widget.unit} × ${widget.reps}';
  }

  String get _motiveLine {
    if (widget.weight >= 100) return 'Triple digits. Earned.';
    if (widget.reps >= 20)    return 'High-rep strength is building.';
    if (widget.weight >= 60)  return 'Strength is trending up.';
    return 'A new best. Noted.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const _GoldConfetti(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // Animated trophy
                  ScaleTransition(
                    scale: _trophy,
                    child: Stack(alignment: Alignment.center, children: [
                      // Glow ring
                      AnimatedBuilder(
                        animation: _shimmer,
                        builder: (_, __) => Container(
                          width: 130, height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: AppColors.gold.withValues(
                                  alpha: 0.3 + 0.2 * _shimmer.value),
                              blurRadius: 40 + 20 * _shimmer.value,
                              spreadRadius: 5,
                            )],
                          ),
                        ),
                      ),
                      Container(
                        width: 110, height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.gold,
                        ),
                        child: const Center(child: Text('🏆',
                            style: TextStyle(fontSize: 52))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // PR label
                  FadeTransition(
                    opacity: _card,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppGradients.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('PERSONAL RECORD',
                            style: GoogleFonts.inter(
                                color: Colors.black, fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('SMASHED! 💥', style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary, fontSize: 32,
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Main card
                  ScaleTransition(
                    scale: _card,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0900),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                            width: 1.5),
                        boxShadow: [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.22),
                            blurRadius: 50, spreadRadius: 3)],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min,
                          children: [

                        // Exercise name
                        Text(widget.exerciseName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                                color: AppColors.textSecondary,
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: AppSpacing.sm),

                        // PR value — BIG
                        AnimatedBuilder(
                          animation: _shimmer,
                          builder: (_, __) => ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Color(0xFFFFCC00), Color(0xFFFFFFFF),
                                Color(0xFFFF9900),
                              ],
                              stops: [
                                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                                _shimmer.value.clamp(0.0, 1.0),
                                (_shimmer.value + 0.3).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds),
                            child: Text(_prValue,
                                style: GoogleFonts.rajdhani(
                                    color: Colors.white,
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: AppSpacing.lg),

                        // XP earned
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.textSecondary.withValues(
                                      alpha: 0.35)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              const Text('⚡',
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(width: AppSpacing.xs),
                              Text('+${ widget.xpEarned} XP',
                                  style: GoogleFonts.rajdhani(
                                      color: AppColors.textSecondary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                            ]),
                          ),
                        ]),

                        const SizedBox(height: AppSpacing.lg),

                        // Motivational line
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.orange.withValues(
                                    alpha: 0.25)),
                          ),
                          child: Text(_motiveLine,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: AppColors.orange, fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4)),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // CTA
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFCC00), Color(0xFFFF9900)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 4))],
                            ),
                            child: Text('Continue',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rajdhani(
                                    color: Colors.black, fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Continue →',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
