// lib/widgets/home/card_illustrations.dart
//
// Lightweight background illustrations for the four Home screen cards.
// Each is a self-contained StatefulWidget that manages its own AnimationController.
//
// Rules:
//   • Opacity 0.15–0.28 — text always primary.
//   • Positioned right-aligned — never overlaps primary text column.
//   • IgnorePointer by design — caller wraps in IgnorePointer.
//   • RepaintBoundary on every animated painter.
//   • CustomPainter only — no raster assets.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/models.dart' show MuscleRecovery;
import '../../utils/app_constants.dart';
import 'muscle_overlay_painter.dart' show recoveryColor;

// ══════════════════════════════════════════════════════════════════════════════
// 1. RECOVERY — body glyph with optional per-muscle glow
// ══════════════════════════════════════════════════════════════════════════════

class RecoveryBodyIllustration extends StatefulWidget {
  final List<MuscleRecovery> muscles;
  const RecoveryBodyIllustration({super.key, required this.muscles});

  @override
  State<RecoveryBodyIllustration> createState() =>
      _RecoveryBodyIllustrationState();
}

class _RecoveryBodyIllustrationState extends State<RecoveryBodyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RecoveryBodyPainter(
            muscles:   widget.muscles,
            breathVal: _ctrl.value,
          ),
        ),
      ),
    );
  }
}

class _RecoveryBodyPainter extends CustomPainter {
  final List<MuscleRecovery> muscles;
  final double breathVal; // 0–1 slow pulse

  const _RecoveryBodyPainter({
    required this.muscles,
    required this.breathVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Glyph occupies the right 23% of the card, full height.
    final glyphW = size.width * 0.23;
    final glyphL = size.width - glyphW;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(glyphL, 0, glyphW, size.height));
    canvas.translate(glyphL, 0);

    _drawFill(canvas, glyphW, size.height);   // filled silhouette underlay
    _drawOutline(canvas, glyphW, size.height); // thin stroke on top
    if (muscles.isNotEmpty) _drawMuscleGlows(canvas, glyphW, size.height);
    _drawLeftFade(canvas, glyphW, size.height);

    canvas.restore();
  }

  // Filled silhouette at very low opacity — gives premium "solid presence" feel.
  void _drawFill(Canvas canvas, double w, double h) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD4A843).withValues(alpha: 0.038);

    // Head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.09),
        width: w * 0.40, height: h * 0.14,
      ),
      fill,
    );

    // Torso (same bezier path as outline)
    final torso = Path()
      ..moveTo(w * 0.18, h * 0.21)
      ..quadraticBezierTo(w * 0.50, h * 0.18, w * 0.82, h * 0.21)
      ..quadraticBezierTo(w * 0.87, h * 0.34, w * 0.82, h * 0.44)
      ..quadraticBezierTo(w * 0.78, h * 0.52, w * 0.82, h * 0.58)
      ..lineTo(w * 0.62, h * 0.61)
      ..quadraticBezierTo(w * 0.50, h * 0.64, w * 0.38, h * 0.61)
      ..lineTo(w * 0.18, h * 0.58)
      ..quadraticBezierTo(w * 0.22, h * 0.52, w * 0.18, h * 0.44)
      ..quadraticBezierTo(w * 0.13, h * 0.34, w * 0.18, h * 0.21)
      ..close();
    canvas.drawPath(torso, fill);

    // Left leg
    final lLeg = Path()
      ..moveTo(w * 0.38, h * 0.61)
      ..quadraticBezierTo(w * 0.34, h * 0.70, w * 0.33, h * 0.76)
      ..quadraticBezierTo(w * 0.30, h * 0.85, w * 0.33, h * 0.92)
      ..lineTo(w * 0.43, h * 0.92)
      ..quadraticBezierTo(w * 0.45, h * 0.83, w * 0.44, h * 0.76)
      ..quadraticBezierTo(w * 0.44, h * 0.70, w * 0.44, h * 0.61)
      ..close();
    canvas.drawPath(lLeg, fill);

    // Right leg
    final rLeg = Path()
      ..moveTo(w * 0.62, h * 0.61)
      ..quadraticBezierTo(w * 0.66, h * 0.70, w * 0.67, h * 0.76)
      ..quadraticBezierTo(w * 0.70, h * 0.85, w * 0.67, h * 0.92)
      ..lineTo(w * 0.57, h * 0.92)
      ..quadraticBezierTo(w * 0.55, h * 0.83, w * 0.56, h * 0.76)
      ..quadraticBezierTo(w * 0.56, h * 0.70, w * 0.56, h * 0.61)
      ..close();
    canvas.drawPath(rLeg, fill);
  }

  void _drawOutline(Canvas canvas, double w, double h) {
    // Premium minimalist anatomical silhouette — gold-tinted, 10-12% opacity.
    // Smooth bezier curves throughout — no rectangular blocks.
    final stroke = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..color       = const Color(0xFFD4A843).withValues(alpha: 0.11);

    // ── Head: oval with correct proportions ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.09),
        width: w * 0.40, height: h * 0.14,
      ),
      stroke,
    );

    // ── Neck: two short lines ──
    canvas.drawLine(
      Offset(w * 0.40, h * 0.16), Offset(w * 0.38, h * 0.20), stroke,
    );
    canvas.drawLine(
      Offset(w * 0.60, h * 0.16), Offset(w * 0.62, h * 0.20), stroke,
    );

    // ── Torso: smooth hourglass — shoulder arc → waist taper → hip flare ──
    final torso = Path()
      ..moveTo(w * 0.18, h * 0.21)
      ..quadraticBezierTo(w * 0.50, h * 0.18, w * 0.82, h * 0.21)
      ..quadraticBezierTo(w * 0.87, h * 0.34, w * 0.82, h * 0.44)
      ..quadraticBezierTo(w * 0.78, h * 0.52, w * 0.82, h * 0.58)
      ..lineTo(w * 0.62, h * 0.61)
      ..quadraticBezierTo(w * 0.50, h * 0.64, w * 0.38, h * 0.61)
      ..lineTo(w * 0.18, h * 0.58)
      ..quadraticBezierTo(w * 0.22, h * 0.52, w * 0.18, h * 0.44)
      ..quadraticBezierTo(w * 0.13, h * 0.34, w * 0.18, h * 0.21)
      ..close();
    canvas.drawPath(torso, stroke);

    // ── Left arm: open curved stroke ──
    final lArm = Path()
      ..moveTo(w * 0.18, h * 0.21)
      ..quadraticBezierTo(w * 0.08, h * 0.32, w * 0.10, h * 0.46)
      ..quadraticBezierTo(w * 0.12, h * 0.51, w * 0.17, h * 0.52);
    canvas.drawPath(lArm, stroke);

    // ── Right arm ──
    final rArm = Path()
      ..moveTo(w * 0.82, h * 0.21)
      ..quadraticBezierTo(w * 0.92, h * 0.32, w * 0.90, h * 0.46)
      ..quadraticBezierTo(w * 0.88, h * 0.51, w * 0.83, h * 0.52);
    canvas.drawPath(rArm, stroke);

    // ── Left leg: tapered with slight knee bend ──
    final lLeg = Path()
      ..moveTo(w * 0.38, h * 0.61)
      ..quadraticBezierTo(w * 0.34, h * 0.70, w * 0.33, h * 0.76)
      ..quadraticBezierTo(w * 0.30, h * 0.85, w * 0.33, h * 0.92)
      ..lineTo(w * 0.43, h * 0.92)
      ..quadraticBezierTo(w * 0.45, h * 0.83, w * 0.44, h * 0.76)
      ..quadraticBezierTo(w * 0.44, h * 0.70, w * 0.44, h * 0.61)
      ..close();
    canvas.drawPath(lLeg, stroke);

    // ── Right leg ──
    final rLeg = Path()
      ..moveTo(w * 0.62, h * 0.61)
      ..quadraticBezierTo(w * 0.66, h * 0.70, w * 0.67, h * 0.76)
      ..quadraticBezierTo(w * 0.70, h * 0.85, w * 0.67, h * 0.92)
      ..lineTo(w * 0.57, h * 0.92)
      ..quadraticBezierTo(w * 0.55, h * 0.83, w * 0.56, h * 0.76)
      ..quadraticBezierTo(w * 0.56, h * 0.70, w * 0.56, h * 0.61)
      ..close();
    canvas.drawPath(rLeg, stroke);
  }

  void _drawMuscleGlows(Canvas canvas, double w, double h) {
    for (final m in muscles) {
      final score = m.recoveryScore.toDouble();
      if (score >= 99) continue;
      final pos = _muscleCenter(m.muscle.toLowerCase(), w, h);
      if (pos == null) continue;

      final color = recoveryColor(score);
      final pulse = breathVal * 0.07;
      final alpha = ((0.16 + pulse) * (score < 80 ? 1.0 : 0.55))
          .clamp(0.06, 0.28);

      canvas.drawCircle(
        pos,
        4.0 + breathVal * 1.2,
        Paint()
          ..color      = color.withValues(alpha: alpha)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4.0),
      );
    }
  }

  void _drawLeftFade(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w * 0.42, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero, Offset(w * 0.42, 0),
          const [Color(0xFF0F0F0F), Color(0x000F0F0F)],
        ),
    );
  }

  static Offset? _muscleCenter(String m, double w, double h) =>
      switch (m) {
        'chest'     => Offset(w * 0.50, h * 0.33),
        'back'      => Offset(w * 0.50, h * 0.35),
        'shoulders' => Offset(w * 0.50, h * 0.22),
        'biceps'    => Offset(w * 0.08, h * 0.36),
        'triceps'   => Offset(w * 0.92, h * 0.36),
        'core'      => Offset(w * 0.50, h * 0.46),
        'legs'      => Offset(w * 0.50, h * 0.67),
        'glutes'    => Offset(w * 0.50, h * 0.56),
        'calves'    => Offset(w * 0.50, h * 0.79),
        'arms'      => Offset(w * 0.10, h * 0.36),
        _           => null,
      };

  @override
  bool shouldRepaint(_RecoveryBodyPainter old) {
    if (old.breathVal != breathVal) return true;
    if (old.muscles.length != muscles.length) return true;
    for (int i = 0; i < muscles.length; i++) {
      if (old.muscles[i].recoveryScore != muscles[i].recoveryScore) return true;
    }
    return false;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. ATHLETE BRAIN — progressive neural network
// ══════════════════════════════════════════════════════════════════════════════

class NeuralIllustration extends StatefulWidget {
  final int totalWorkouts;
  const NeuralIllustration({super.key, required this.totalWorkouts});

  @override
  State<NeuralIllustration> createState() => _NeuralIllustrationState();
}

class _NeuralIllustrationState extends State<NeuralIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _NeuralCardPainter(
            pulse:         _ctrl.value,
            totalWorkouts: widget.totalWorkouts,
          ),
        ),
      ),
    );
  }
}

// 10 nodes in 100×100 logical space, upper-right heavy.
const List<Offset> _kNeuralNodes = [
  Offset(12, 10), Offset(52, 6),  Offset(90, 18), // top row
  Offset(8,  42), Offset(38, 34), Offset(74, 30), Offset(95, 46), // mid row
  Offset(22, 68), Offset(58, 62), Offset(86, 72), // bottom row
];

// Edges ordered by visual impact — first edges appear as workouts increase.
const List<(int, int)> _kNeuralEdges = [
  (1, 4), (4, 5), (2, 5), (5, 6), (0, 4),
  (3, 4), (4, 8), (5, 9), (6, 9), (7, 8),
  (1, 5), (8, 9), (0, 3), (2, 6), (3, 7),
];

class _NeuralCardPainter extends CustomPainter {
  final double pulse;
  final int    totalWorkouts;

  const _NeuralCardPainter({
    required this.pulse,
    required this.totalWorkouts,
  });

  // Map totalWorkouts → stage 0–15 for progressive unlock.
  int get _stage => totalWorkouts.clamp(0, 15);

  int get _litNodes =>
      (_stage / 15.0 * _kNeuralNodes.length).round()
          .clamp(0, _kNeuralNodes.length);

  int get _litEdges =>
      (_stage / 15.0 * _kNeuralEdges.length).round()
          .clamp(0, _kNeuralEdges.length);

  @override
  void paint(Canvas canvas, Size size) {
    // Illustration occupies the right 46% of the card, full height.
    final illW = size.width * 0.46;
    final illL = size.width - illW;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(illL, 0, illW, size.height));
    canvas.translate(illL, 0);

    _drawEdges(canvas, illW, size.height);
    _drawNodes(canvas, illW, size.height);
    _drawLeftFade(canvas, illW, size.height);

    canvas.restore();
  }

  Offset _nodePos(int i, double w, double h) {
    final n = _kNeuralNodes[i];
    return Offset(n.dx / 100.0 * w, n.dy / 100.0 * h);
  }

  void _drawEdges(Canvas canvas, double w, double h) {
    final litEdges = _litEdges;
    for (int i = 0; i < _kNeuralEdges.length; i++) {
      final isLit  = i < litEdges;
      final (a, b) = _kNeuralEdges[i];
      final p1     = _nodePos(a, w, h);
      final p2     = _nodePos(b, w, h);
      final alpha  = isLit
          ? (0.10 + pulse * 0.06).clamp(0.0, 1.0)
          : 0.035;

      canvas.drawLine(
        p1, p2,
        Paint()
          ..color       = AppColors.gold.withValues(alpha: alpha)
          ..strokeWidth = isLit ? 0.65 : 0.35
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  void _drawNodes(Canvas canvas, double w, double h) {
    final litNodes = _litNodes;
    for (int i = 0; i < _kNeuralNodes.length; i++) {
      final isLit     = i < litNodes;
      final center    = _nodePos(i, w, h);
      final phasedPulse = i.isEven ? pulse : 1.0 - pulse;

      if (isLit) {
        // Outer glow
        canvas.drawCircle(
          center,
          4.5 + phasedPulse * 1.8,
          Paint()
            ..color      =
                AppColors.gold.withValues(alpha: 0.07 + phasedPulse * 0.06)
            ..maskFilter =
                const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5),
        );
        // Core node
        canvas.drawCircle(
          center,
          1.8 + phasedPulse * 0.5,
          Paint()
            ..color =
                AppColors.gold.withValues(alpha: 0.52 + phasedPulse * 0.22),
        );
      } else {
        // Unlit — ghost dot only
        canvas.drawCircle(
          center,
          1.1,
          Paint()..color = AppColors.gold.withValues(alpha: 0.07),
        );
      }
    }
  }

  void _drawLeftFade(Canvas canvas, double w, double h) {
    // Blend illustration into the card's background colour (dark gradient).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w * 0.38, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero, Offset(w * 0.38, 0),
          const [Color(0xFF0C0C0C), Color(0x000C0C0C)],
        ),
    );
  }

  @override
  bool shouldRepaint(_NeuralCardPainter old) =>
      old.pulse != pulse || old.totalWorkouts != totalWorkouts;
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. LIFTON COACH — concentric conversation-bubble glyph
// ══════════════════════════════════════════════════════════════════════════════

class CoachGlyphIllustration extends StatefulWidget {
  const CoachGlyphIllustration({super.key});

  @override
  State<CoachGlyphIllustration> createState() => _CoachGlyphIllustrationState();
}

class _CoachGlyphIllustrationState extends State<CoachGlyphIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _CoachGlyphPainter(breathVal: _ctrl.value),
        ),
      ),
    );
  }
}

class _CoachGlyphPainter extends CustomPainter {
  final double breathVal;
  const _CoachGlyphPainter({required this.breathVal});

  @override
  void paint(Canvas canvas, Size size) {
    // Glyph anchored to top-right quadrant.
    final glyphW = math.min(size.width * 0.22, 82.0);
    final glyphH = glyphW * 0.78;
    final cx     = size.width - glyphW * 0.60;
    final cy     = size.height * 0.30;

    // Subtle scale-breathe
    final scale = 1.0 + breathVal * 0.025;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);

    _drawBubbles(canvas, cx, cy, glyphW, glyphH);
    _drawChatLines(canvas, cx, cy, glyphW, glyphH);
    _drawTail(canvas, cx, cy, glyphW, glyphH);

    canvas.restore();
  }

  void _drawBubbles(Canvas canvas, double cx, double cy,
                    double w, double h) {
    // Three concentric rounded rects — largest to smallest.
    final layers = [
      (1.00, 0.10 + breathVal * 0.04),
      (0.75, 0.13 + breathVal * 0.04),
      (0.50, 0.16 + breathVal * 0.05),
    ];

    for (final (scale, alpha) in layers) {
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width:  w * scale,
          height: h * scale,
        ),
        Radius.circular(w * scale * 0.24),
      );

      canvas.drawRRect(
        rr,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.75
          ..color       = AppColors.gold.withValues(alpha: alpha),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.gold.withValues(alpha: alpha * 0.20),
      );
    }

    // Outer ambient glow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy), width: w * 1.50, height: h * 1.50,
      ),
      Paint()
        ..color      =
            AppColors.gold.withValues(alpha: 0.03 + breathVal * 0.02)
        ..maskFilter =
            const ui.MaskFilter.blur(ui.BlurStyle.normal, 8.0),
    );
  }

  void _drawChatLines(Canvas canvas, double cx, double cy,
                      double w, double h) {
    final lineAlpha = 0.18 + breathVal * 0.07;
    final halfW     = w * 0.75 * 0.42;
    final linePaint = Paint()
      ..color       = AppColors.gold.withValues(alpha: lineAlpha)
      ..strokeWidth = 0.9
      ..strokeCap   = StrokeCap.round;

    // 3 horizontal chat lines at 30 / 50 / 70% of bubble height
    for (final (yOff, widthFrac) in [
      (-h * 0.14, 1.00),
      (0.0,        0.78),
      (h * 0.14,   0.55),
    ]) {
      canvas.drawLine(
        Offset(cx - halfW * widthFrac, cy + yOff),
        Offset(cx + halfW * widthFrac, cy + yOff),
        linePaint,
      );
    }
  }

  void _drawTail(Canvas canvas, double cx, double cy,
                 double w, double h) {
    // Small tail triangle at bottom-left of the outer bubble.
    final tailX = cx - w * 0.25;
    final tailY = cy + h * 0.50;
    final tail  = Path()
      ..moveTo(tailX,              tailY)
      ..lineTo(tailX - w * 0.09,  tailY + h * 0.22)
      ..lineTo(tailX + w * 0.14,  tailY)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.12 + breathVal * 0.04),
    );
  }

  @override
  bool shouldRepaint(_CoachGlyphPainter old) => old.breathVal != breathVal;
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. WEEKLY STRIP — activity glow halos behind day blocks
// ══════════════════════════════════════════════════════════════════════════════

class WeeklyMomentumPainter extends CustomPainter {
  final Set<int> doneSet;
  final int      todayIdx;
  final Set<int> restSet;

  const WeeklyMomentumPainter({
    required this.doneSet,
    required this.todayIdx,
    required this.restSet,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Mirrors the inner layout of _WeeklyProgressStrip.
    // Inner width (card padding 18 left + 18 right).
    final innerW   = size.width - 36.0;
    // 7 blocks with 5px gap between; gap count = 6.
    final blockW   = (innerW - 30.0) / 7;
    const blockGap = 5.0;
    // Approximate vertical centre of the 7-day blocks:
    // 16px top pad + 22px header + 14px gap + 25px (half of ~50px block)
    const blockCY  = 77.0;

    for (int i = 0; i < 7; i++) {
      final blockCX = 18.0 + i * (blockW + blockGap) + blockW / 2;

      if (doneSet.contains(i)) {
        // Gold glow halo behind completed day blocks.
        canvas.drawCircle(
          Offset(blockCX, blockCY),
          blockW * 0.62,
          Paint()
            ..color      = AppColors.gold.withValues(alpha: 0.09)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6.0),
        );
      } else if (i == todayIdx) {
        // Softer white glow for today (if not yet completed).
        canvas.drawCircle(
          Offset(blockCX, blockCY),
          blockW * 0.48,
          Paint()
            ..color      =
                Colors.white.withValues(alpha: 0.04)
            ..maskFilter =
                const ui.MaskFilter.blur(ui.BlurStyle.normal, 4.0),
        );
      }
    }

    // Faint connecting line between consecutive completed days.
    if (doneSet.length >= 2) {
      final sorted = doneSet.toList()..sort();
      for (int k = 0; k < sorted.length - 1; k++) {
        // Only connect adjacent calendar days.
        if (sorted[k + 1] - sorted[k] > 2) continue;
        final x1 = 18.0 + sorted[k]     * (blockW + blockGap) + blockW / 2;
        final x2 = 18.0 + sorted[k + 1] * (blockW + blockGap) + blockW / 2;
        canvas.drawLine(
          Offset(x1, blockCY),
          Offset(x2, blockCY),
          Paint()
            ..color       = AppColors.gold.withValues(alpha: 0.08)
            ..strokeWidth = 0.9
            ..strokeCap   = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WeeklyMomentumPainter old) =>
      old.doneSet.length != doneSet.length ||
      old.todayIdx != todayIdx;
}
