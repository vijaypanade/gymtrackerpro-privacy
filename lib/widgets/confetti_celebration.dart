// lib/widgets/confetti_celebration.dart — Phase 2
// Pure Flutter confetti — ZERO external packages
// Usage:
//   import '../widgets/confetti_celebration.dart';
//   await showWorkoutCelebration(context,
//     xp: 250, streak: 5, duration: 47, badges: ['🏆','🔥']);
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';

// ════════════════════════════════════════════════
// PUBLIC API — call this after saving workout
// ════════════════════════════════════════════════
Future<void> showWorkoutCelebration(
  BuildContext context, {
  required int xp,
  required int streak,
  required int duration,
  List<String> badges = const [],
}) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, __) => _CelebrationScreen(
      xp: xp, streak: streak, duration: duration, badges: badges),
  );
}

// ════════════════════════════════════════════════
// CONFETTI PARTICLE DATA
// ════════════════════════════════════════════════
class _Particle {
  double x, y, vx, vy, rotation, rotSpeed, size, opacity;
  Color color;
  int shape; // 0=rect, 1=circle, 2=diamond

  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.rotation, required this.rotSpeed,
    required this.size, required this.color,
    required this.shape, this.opacity = 1.0,
  });
}

// ════════════════════════════════════════════════
// CONFETTI PAINTER
// ════════════════════════════════════════════════
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0: // Rectangle
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero,
                  width: p.size, height: p.size * 0.4),
              const Radius.circular(2)),
            paint);
          break;
        case 1: // Circle
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
          break;
        case 2: // Diamond
          final path = Path()
            ..moveTo(0, -p.size * 0.5)
            ..lineTo(p.size * 0.35, 0)
            ..lineTo(0, p.size * 0.5)
            ..lineTo(-p.size * 0.35, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

// ════════════════════════════════════════════════
// CONFETTI ANIMATION WIDGET
// ════════════════════════════════════════════════
class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();
  @override State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final _rng = Random();

  static const _colors = [
    Color(0xFFFFCC00), Color(0xFFFF9900), Color(0xFF00D4AA),
    Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFF3B82F6),
    Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFFF6B6B),
    Color(0xFF4ECDC4), Color(0xFFFFE66D), Color(0xFFA8E6CF),
  ];

  @override
  void initState() {
    super.initState();
    _spawn();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 50))
      ..addListener(_tick)
      ..repeat();
    // Spawn second burst after 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _spawn(burst: true);
    });
  }

  void _spawn({bool burst = false}) {
    for (int i = 0; i < (burst ? 50 : 90); i++) {
      // Spawn from top center, slight spread
      final cx = burst
          ? 0.3 + _rng.nextDouble() * 0.4
          : (_rng.nextBool() ? 0.15 : 0.85)
              + (_rng.nextDouble() - 0.5) * 0.2;
      _particles.add(_Particle(
        x: cx,
        y: -0.02 - _rng.nextDouble() * 0.05,
        vx: (_rng.nextDouble() - 0.5) * (burst ? 0.012 : 0.007),
        vy: 0.002 + _rng.nextDouble() * 0.006,
        rotation: _rng.nextDouble() * 2 * pi,
        rotSpeed: (_rng.nextDouble() - 0.5) * 0.18,
        size: 6 + _rng.nextDouble() * 10,
        color: _colors[_rng.nextInt(_colors.length)],
        shape: _rng.nextInt(3),
        opacity: 0.85 + _rng.nextDouble() * 0.15,
      ));
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.00012; // gravity
        p.vx *= 0.997;   // air resistance
        p.rotation += p.rotSpeed;
        // Fade out when near bottom
        if (p.y > 0.7) {
          p.opacity = (p.opacity - 0.015).clamp(0.0, 1.0);
        }
      }
      _particles.removeWhere((p) => p.y > 1.15 || p.opacity <= 0);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _ConfettiPainter(List.from(_particles)),
      child: const SizedBox.expand(),
    ),
  );
}

// ════════════════════════════════════════════════
// CELEBRATION SCREEN
// ════════════════════════════════════════════════
class _CelebrationScreen extends StatefulWidget {
  final int xp, streak, duration;
  final List<String> badges;
  const _CelebrationScreen({
    required this.xp, required this.streak,
    required this.duration, required this.badges,
  });
  @override State<_CelebrationScreen> createState() =>
      _CelebrationScreenState();
}

class _CelebrationScreenState extends State<_CelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _trophyC, _cardC, _statsC;
  late Animation<double> _trophy, _card, _stats;

  @override
  void initState() {
    super.initState();

    _trophyC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _trophy = CurvedAnimation(parent: _trophyC, curve: Curves.elasticOut);

    _cardC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _card = CurvedAnimation(parent: _cardC, curve: Curves.easeOutBack);

    _statsC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _stats = CurvedAnimation(parent: _statsC, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 150),
        () { if (mounted) _trophyC.forward(); });
    Future.delayed(const Duration(milliseconds: 350),
        () { if (mounted) _cardC.forward(); });
    Future.delayed(const Duration(milliseconds: 600),
        () { if (mounted) _statsC.forward(); });
  }

  @override
  void dispose() {
    _trophyC.dispose(); _cardC.dispose(); _statsC.dispose();
    super.dispose();
  }

  String get _headline {
    if (widget.duration >= 90) return 'ABSOLUTE BEAST! 🦁';
    if (widget.duration >= 60) return 'CRUSHED IT! 🔥';
    if (widget.duration >= 30) return 'WORKOUT DONE! 💪';
    return 'SESSION COMPLETE!';
  }

  String get _streakLine {
    if (widget.streak >= 30) return '🌟 30-day legend status';
    if (widget.streak >= 14) return '⚡ 2-week warrior achieved!';
    if (widget.streak >= 7)  return '🔥 Week streak is FIRE!';
    if (widget.streak >= 3)  return '💪 ${widget.streak} days in a row!';
    if (widget.streak == 1)  return '🏁 First step taken. Keep going.';
    return '🚀 Building a habit. Day ${widget.streak}!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Confetti
        const _ConfettiOverlay(),

        // Main content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Trophy emoji — bouncy entrance
                  ScaleTransition(
                    scale: _trophy,
                    child: const Text('🏆',
                        style: TextStyle(fontSize: 80)),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Headline
                  FadeTransition(
                    opacity: _card,
                    child: Column(mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(_headline, style: GoogleFonts.rajdhani(
                          color: AppColors.gold, fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('${widget.duration} min of pure grind 💯',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14)),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Main card
                  ScaleTransition(
                    scale: _card,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0A00),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            width: 1.5),
                        boxShadow: [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.20),
                            blurRadius: 50, spreadRadius: 3)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                        // Stats row
                        FadeTransition(
                          opacity: _stats,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                            _Bubble(emoji: '⚡',
                                value: '+${widget.xp}',
                                label: 'XP Earned',
                                color: AppColors.purple),
                            _VDivider(),
                            _Bubble(emoji: '🔥',
                                value: '${widget.streak}d',
                                label: 'Streak',
                                color: AppColors.orange),
                            _VDivider(),
                            _Bubble(emoji: '⏱️',
                                value: '${widget.duration}m',
                                label: 'Duration',
                                color: AppColors.blue),
                          ]),
                        ),

                        // Badges row (if any)
                        if (widget.badges.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: AppSpacing.md),
                          Text('🏅 BADGES UNLOCKED',
                              style: GoogleFonts.inter(
                                  color: AppColors.gold, fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: widget.badges.take(5).map((e) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Text(e,
                                    style: const TextStyle(
                                        fontSize: 28)),
                              )).toList(),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: AppSpacing.md),

                        // Streak message
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.orange
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.orange
                                    .withValues(alpha: 0.30)),
                          ),
                          child: Text(_streakLine,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: AppColors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // CTA button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFCC00),
                                  Color(0xFFFF9900)
                                ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(
                                  color: AppColors.gold
                                      .withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 4))],
                            ),
                            child: Text('Let\'s Go Again! 💪',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rajdhani(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Skip tap
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Continue →',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 13)),
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

// Small helpers
class _Bubble extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _Bubble({required this.emoji, required this.value,
      required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(value, style: GoogleFonts.rajdhani(
        color: color, fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: GoogleFonts.inter(
        color: AppColors.textMuted, fontSize: 10)),
  ]));
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 40,
      color: AppColors.divider.withValues(alpha: 0.5));
}
