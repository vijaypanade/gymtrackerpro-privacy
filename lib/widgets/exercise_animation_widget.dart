import 'dart:math' as math;
import 'package:flutter/material.dart';

class InclineBenchPressAnimation extends StatefulWidget {
  const InclineBenchPressAnimation({super.key});

  @override
  State<InclineBenchPressAnimation> createState() =>
      _InclineBenchPressAnimationState();
}

class _InclineBenchPressAnimationState
    extends State<InclineBenchPressAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C1C), width: 0.8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 260),
            painter: _GridPainter(),
          ),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _BenchPressPainter(t: _anim.value),
            ),
          ),
          const Positioned(
            top: 18,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INCLINE BARBELL',
                  style: TextStyle(
                    color: Color(0xFFC9A84C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bench Press',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 18,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC9A84C).withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: const Text(
                'UPPER CHEST',
                style: TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid ─────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ─── Shared proportions ───────────────────────────────────────────────────────

class _HumanProportions {
  static const double upperArmLength = 38;
  static const double forearmLength  = 32;
}

// ─── Bench Press Painter ──────────────────────────────────────────────────────

class _BenchPressPainter extends CustomPainter {
  final double t; // 0 = bar at chest, 1 = lockout

  const _BenchPressPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Bar path: chest at y=122 (t=0), lockout at y=76 (t=1) — above shoulder joint
    final bx = cx + 4.0 - t * 2.0;
    final by = 122.0 - t * 46.0;

    _drawBench(canvas, size, cx);
    _drawTrail(canvas, bx, by);
    _drawHuman(canvas, cx, bx, by);
    if (t > 0.50) _drawBarGlow(canvas, bx, by);

    // Occlusion plane — body disappears behind bar correctly
    final occ = Path()
      ..moveTo(bx - 76, by - 10)
      ..lineTo(bx + 76, by - 4)
      ..lineTo(bx + 76, by + 12)
      ..lineTo(bx - 76, by + 2)
      ..close();
    canvas.drawPath(
      occ,
      Paint()..color = const Color(0xFF090909).withValues(alpha: 0.94),
    );

    _drawBarbell(canvas, bx, by);

    // Foreground pass moved back into _drawHuman().
    _drawPhaseLabel(canvas, size);
  }

  // ── IK solver (law of cosines) ────────────────────────────────────────────
  static Offset _solveElbow(
    Offset sh, Offset wr, double ua, double fa, double side,
  ) {
    final dx = wr.dx - sh.dx;
    final dy = wr.dy - sh.dy;
    final rawD = math.sqrt(dx * dx + dy * dy);
    final d = rawD.clamp(0.5, ua + fa - 0.5);
    final cosA = ((d * d + ua * ua - fa * fa) / (2.0 * d * ua)).clamp(-1.0, 1.0);
    final sinA = math.sqrt(1.0 - cosA * cosA);
    final nx = dx / rawD;
    final ny = dy / rawD;
    return Offset(
      sh.dx + (nx * cosA - ny * sinA * side) * ua,
      sh.dy + (ny * cosA + nx * sinA * side) * ua,
    );
  }

  // ── Straight tapered limb (forearm, shin) ────────────────────────────────
  static void _drawLimb(
    Canvas canvas, Offset a, Offset b, double wA, double wB, Color col,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final nx = -dy / len;
    final ny = dx / len;
    final path = Path()
      ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
      ..lineTo(b.dx + nx * wB / 2, b.dy + ny * wB / 2)
      ..lineTo(b.dx - nx * wB / 2, b.dy - ny * wB / 2)
      ..lineTo(a.dx - nx * wA / 2, a.dy - ny * wA / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
        ..lineTo(b.dx + nx * wB / 2, b.dy + ny * wB / 2),
      Paint()
        ..color = Color.lerp(col, Colors.white, 0.22)!.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Limb with muscle belly (bicep, quad sweep) ────────────────────────────
  static void _drawMuscledLimb(
    Canvas canvas, Offset a, Offset b,
    double wA, double wPeak, double wB, Color col,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final nx = -dy / len;
    final ny = dx / len;
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path()
      ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
      ..quadraticBezierTo(
        mid.dx + nx * wPeak / 2, mid.dy + ny * wPeak / 2,
        b.dx + nx * wB / 2, b.dy + ny * wB / 2,
      )
      ..lineTo(b.dx - nx * wB / 2, b.dy - ny * wB / 2)
      ..quadraticBezierTo(
        mid.dx - nx * wPeak / 2, mid.dy - ny * wPeak / 2,
        a.dx - nx * wA / 2, a.dy - ny * wA / 2,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
        ..quadraticBezierTo(
          mid.dx + nx * wPeak / 2, mid.dy + ny * wPeak / 2,
          b.dx + nx * wB / 2, b.dy + ny * wB / 2,
        ),
      Paint()
        ..color = Color.lerp(col, Colors.white, 0.22)!.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _drawJoint(Canvas canvas, Offset c, double r, Color col) {
    canvas.drawCircle(c, r, Paint()..color = col);
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  // ── Athlete figure ────────────────────────────────────────────────────────
  void _drawHuman(Canvas canvas, double cx, double bx, double by) {
    // Body anchors — head upper-right, legs lower-left (45° incline view)
    final head      = Offset(cx + 18, 108.0);
    final neck      = Offset(cx + 10, 120.0);

    final rShoulder = Offset(cx + 18, 122.0);
    final lShoulder = Offset(cx - 6, 128.0);

    final hip   = Offset(cx - 44, 182.0);
    final rKnee = Offset(cx - 76, 208.0);
    final lKnee = Offset(cx - 66, 216.0);
    final rFoot = Offset(cx - 90, 220.0);
    final lFoot = Offset(cx - 76, 228.0);

    final rWrist = Offset(cx + 42.0, by);
    final lWrist = Offset(cx - 42.0, by);

    const ua = _HumanProportions.upperArmLength;
    const fa = _HumanProportions.forearmLength;
    final rElbow = _solveElbow(rShoulder, rWrist, ua, fa,  1.0) + const Offset(0, 10);
    final lElbow = _solveElbow(lShoulder, lWrist, ua, fa, -1.0) + const Offset(0, 10);

    final chestAct  = (t * 1.4 - 0.18).clamp(0.0, 1.0);
    final deltAct   = (t * 1.1 - 0.04).clamp(0.0, 1.0);
    final tricepAct = (t > 0.45 ? (t - 0.45) * 1.82 : 0.0).clamp(0.0, 1.0);

    const bodyFar  = Color(0xFF0E1620);
    const bodyBase = Color(0xFF162030);
    const bodyFace = Color(0xFF1B2A3C);
    const gold     = Color(0xFFC9A84C);

    // Draw order: back → front

    final lThighStart = hip + const Offset(-4, 10);
    final rThighStart = hip + const Offset(2, 8);

    // Far leg — quad sweep thigh, tapered shin
    _drawMuscledLimb(canvas, lThighStart, lKnee, 9.0, 12.0, 7.0, bodyFar);
    _drawLimb(canvas, lKnee, lFoot, 9.0, 6.0, bodyFar);

    // Torso silhouette
    _drawTorsoSilhouette(canvas, cx, rShoulder, lShoulder, bodyFar, bodyBase, bodyFace);

    // Near leg — quad sweep
    _drawMuscledLimb(canvas, rThighStart, rKnee, 10.0, 13.0, 8.0, bodyFace);
    _drawLimb(canvas, rKnee, rFoot, 10.5, 7.5, bodyFace);
    // Patella oval — not a ball joint
    canvas.drawOval(
      Rect.fromCenter(center: rKnee, width: 13, height: 9),
      Paint()..color = bodyFace,
    );

    // Far arm — bicep belly
    _drawJoint(canvas, lShoulder, 8.5, bodyFar);
    _drawMuscledLimb(canvas, lShoulder, lElbow, 8.5, 11.0, 6.5, bodyFar);
    _drawLimb(canvas, lElbow, lWrist, 6.5, 5.0, bodyFar);
    _drawJoint(canvas, lElbow, 6.5, bodyFar);
    _drawGrip(canvas, lWrist, by, bodyFar);

    // Chest plate
    _drawChestPlate(canvas, rShoulder, lShoulder, chestAct, gold);

    // Near arm — brighter foreground layer for depth
    _drawJoint(canvas, rShoulder, 11.5, const Color(0xFF2A3D52));

    _drawMuscledLimb(
      canvas,
      rShoulder,
      rElbow,
      11.5,
      15.0,
      8.5,
      const Color(0xFF24364A),
    );

    if (tricepAct > 0) {
      final tMid = Offset(
        (rShoulder.dx + rElbow.dx) / 2 - 3,
        (rShoulder.dy + rElbow.dy) / 2,
      );

      canvas.drawOval(
        Rect.fromCenter(center: tMid, width: 18, height: 28),
        Paint()
          ..color = gold.withValues(alpha: 0.16 * tricepAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    _drawLimb(
      canvas,
      rElbow,
      rWrist,
      8.5,
      5.8,
      const Color(0xFF24364A),
    );

    _drawJoint(canvas, rElbow, 8.5, const Color(0xFF24364A));
    _drawGrip(canvas, rWrist, by, const Color(0xFF24364A));

    // Delt glow
    if (deltAct > 0.05) {
      canvas.drawOval(
        Rect.fromCenter(
          center: rShoulder + const Offset(8, -4),
          width: 28,
          height: 25,
        ),
        Paint()
          ..color = gold.withValues(alpha: 0.18 * deltAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
    }

    final headFade = (1.0 - t * 1.15).clamp(0.18, 1.0);

    _drawHead(
      canvas,
      head,
      neck,
      bodyBase.withValues(alpha: headFade),
      bodyFace.withValues(alpha: headFade),
    );
  }

  // ── V-taper torso silhouette ──────────────────────────────────────────────
  static void _drawTorsoSilhouette(
    Canvas canvas, double cx,
    Offset rSh, Offset lSh,
    Color dark, Color mid, Color lit,
  ) {
    // Anatomical landmarks
    final neckR = Offset(cx + 18, rSh.dy - 14);      // trap/neck near
    final neckL = Offset(cx +  8, rSh.dy -  8);      // trap/neck far
    final rDelt = Offset(rSh.dx + 16, rSh.dy + 2);   // delt cap peak
    final lDelt = Offset(lSh.dx -  4, lSh.dy + 4);   // far delt cap
    final rLat  = Offset(rSh.dx + 10, rSh.dy + 28);  // lat flare peak
    final lLat  = Offset(lSh.dx + 8, lSh.dy + 24);   // far lat flare
    final rWst  = Offset(cx - 4, rSh.dy + 52);       // waist (V-taper)
    final lWst  = Offset(cx - 28, lSh.dy + 54);      // far waist
    final rHip  = Offset(cx - 18, rSh.dy + 66);      // hip near
    final lHip  = Offset(cx - 40, lSh.dy + 70);      // hip far

    // Full V-taper silhouette
    final body = Path()
      ..moveTo(neckR.dx, neckR.dy)
      ..quadraticBezierTo(rDelt.dx, rDelt.dy - 10, rDelt.dx, rDelt.dy)
      ..quadraticBezierTo(rLat.dx + 4, rLat.dy - 4, rLat.dx, rLat.dy)
      ..quadraticBezierTo(rWst.dx + 6, rWst.dy + 2, rHip.dx + 4, rHip.dy - 2)
      ..quadraticBezierTo(cx - 14, rHip.dy + 8, lHip.dx + 2, lHip.dy - 2)
      ..quadraticBezierTo(lWst.dx + 2, lWst.dy + 2, lWst.dx, lWst.dy)
      ..quadraticBezierTo(lLat.dx - 4, lLat.dy - 4, lLat.dx, lLat.dy)
      ..quadraticBezierTo(lDelt.dx, lDelt.dy - 10, neckL.dx, neckL.dy)
      ..close();
    canvas.drawPath(body, Paint()..color = mid);

    // Far face darker overlay
    final farFace = Path()
      ..moveTo(neckL.dx, neckL.dy)
      ..quadraticBezierTo(lDelt.dx, lDelt.dy - 10, lDelt.dx, lDelt.dy)
      ..quadraticBezierTo(lLat.dx - 4, lLat.dy - 4, lLat.dx, lLat.dy)
      ..lineTo(lWst.dx, lWst.dy)
      ..lineTo(lHip.dx, lHip.dy)
      ..lineTo(lHip.dx + 6, lHip.dy - 4)
      ..lineTo(lWst.dx + 8, lWst.dy - 6)
      ..quadraticBezierTo(lLat.dx + 4, lLat.dy - 6, lDelt.dx + 8, lDelt.dy - 2)
      ..quadraticBezierTo(neckL.dx + 6, neckL.dy - 4, neckL.dx + 4, neckL.dy - 3)
      ..close();
    canvas.drawPath(farFace, Paint()..color = dark);

    // Ribcage volume — creates real torso mass instead of flat polygon
    final rib = Path()
      ..moveTo(cx + 6, rSh.dy + 6)
      ..quadraticBezierTo(cx + 26, rSh.dy + 18, cx + 18, rSh.dy + 38)
      ..quadraticBezierTo(cx + 8, rSh.dy + 54, cx - 8, rSh.dy + 48)
      ..quadraticBezierTo(cx - 18, rSh.dy + 28, cx - 4, rSh.dy + 12)
      ..close();

    canvas.drawPath(
      rib,
      Paint()
        ..color = const Color(0xFF2A4360).withValues(alpha: 0.34),
    );

    // Spine arc
    canvas.drawPath(
      Path()
        ..moveTo(cx + 4, rSh.dy + 2)
        ..quadraticBezierTo(cx - 2, rSh.dy + 26, cx - 10, rSh.dy + 52),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Lower chest shadow — pushes torso onto bench plane
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - 6, rSh.dy + 44),
        width: 54,
        height: 18,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Near-edge rim light
    canvas.drawPath(
      Path()
        ..moveTo(neckR.dx, neckR.dy)
        ..quadraticBezierTo(rDelt.dx, rDelt.dy - 10, rDelt.dx, rDelt.dy)
        ..quadraticBezierTo(rLat.dx + 4, rLat.dy - 4, rLat.dx, rLat.dy)
        ..quadraticBezierTo(rWst.dx + 4, rWst.dy - 10, rWst.dx, rWst.dy)
        ..lineTo(rHip.dx, rHip.dy),
      Paint()
        ..color = lit.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // Clavicle line
    canvas.drawLine(rSh, lSh, Paint()
      ..color = const Color(0xFF253444)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round);

    // Oblique surface line (anatomical detail)
    canvas.drawLine(
      Offset(rLat.dx - 2, rLat.dy + 2),
      Offset(rWst.dx + 2, rWst.dy - 2),
      Paint()
        ..color = const Color(0xFF1A2C3E)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Pectoralis major — two-lobe contour glow ──────────────────────────────
  static void _drawChestPlate(
    Canvas canvas, Offset rSh, Offset lSh, double act, Color gold,
  ) {
    final mx = (rSh.dx + lSh.dx) / 2;
    final my = (rSh.dy + lSh.dy) / 2 + 5;

    // Near pec (right — closer, larger)
    final nearPec = Path()
      ..moveTo(rSh.dx + 6, rSh.dy + 2)
      ..quadraticBezierTo(mx + 8, my - 10, mx + 2, my + 2)
      ..quadraticBezierTo(rSh.dx - 2, my + 14, rSh.dx - 4, rSh.dy + 22)
      ..quadraticBezierTo(rSh.dx + 6, rSh.dy + 12, rSh.dx + 6, rSh.dy + 2)
      ..close();

    // Far pec (left — partially visible)
    final farPec = Path()
      ..moveTo(lSh.dx + 2, lSh.dy + 4)
      ..quadraticBezierTo(mx - 6, my - 8, mx + 2, my + 2)
      ..quadraticBezierTo(mx - 4, my + 10, lSh.dx + 4, lSh.dy + 16)
      ..close();

    canvas.drawPath(nearPec, Paint()..color = const Color(0xFF192A3C));
    canvas.drawPath(farPec,  Paint()..color = const Color(0xFF152538));

    if (act > 0) {
      // Contour glow follows pec shape
      canvas.drawPath(nearPec, Paint()
        ..color = gold.withValues(alpha: 0.30 * act)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawPath(farPec, Paint()
        ..color = gold.withValues(alpha: 0.18 * act)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Sternum groove
      canvas.drawLine(
        Offset(mx + 2, my - 8),
        Offset(mx, my + 6),
        Paint()
          ..color = gold.withValues(alpha: 0.12 * act)
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ── Palm + knuckle grip ───────────────────────────────────────────────────
  static void _drawGrip(Canvas canvas, Offset wrist, double by, Color col) {
    canvas.drawOval(
      Rect.fromCenter(center: wrist, width: 10, height: 14),
      Paint()..color = col,
    );
    canvas.drawLine(
      Offset(wrist.dx - 5, by), Offset(wrist.dx + 5, by),
      Paint()
        ..color = Color.lerp(col, Colors.white, 0.18)!.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Head — tapered neck, proportional skull ───────────────────────────────
  static void _drawHead(
    Canvas canvas, Offset head, Offset neck, Color base, Color face,
  ) {
    // Tapered neck path: wider at trap base, narrower at skull
    canvas.drawPath(
      Path()
        ..moveTo(neck.dx - 7, neck.dy)
        ..lineTo(head.dx - 4, head.dy + 10)
        ..lineTo(head.dx + 5, head.dy + 10)
        ..lineTo(neck.dx + 8, neck.dy)
        ..close(),
      Paint()..color = base,
    );
    // Trap bulk at neck base
    canvas.drawOval(
      Rect.fromCenter(center: neck, width: 22, height: 11),
      Paint()..color = base,
    );
    canvas.drawCircle(head, 17, Paint()..color = base);
    canvas.drawArc(
      Rect.fromCenter(center: head, width: 34, height: 34),
      math.pi * 0.82, math.pi * 0.70,
      false,
      Paint()
        ..color = face.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()..addArc(
        Rect.fromCenter(center: head, width: 34, height: 32),
        math.pi, math.pi,
      ),
      Paint()..color = const Color(0xFF0A1220),
    );
  }

  // ── Incline bench — repositioned to support the figure ───────────────────
  // Body: head at (cx+50,58), hip at (cx-62,188).
  // Bench surface runs from headrest (upper-right) to foot-end (lower-left).
  void _drawBench(Canvas canvas, Size size, double cx) {
    final padFill = Paint()..color = const Color(0xFF191919);
    final padEdge = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Main inclined pad — top surface parallelogram
    final padTop = Path()
      ..moveTo(cx + 42, 118)     // near edge, head end
      ..lineTo(cx - 86, 214)     // near edge, foot end
      ..lineTo(cx - 70, 232)     // far edge, foot end
      ..lineTo(cx + 58, 136)     // far edge, head end
      ..close();
    canvas.drawPath(padTop, padFill);

    // Pad near-viewer front face (depth edge)
    canvas.drawPath(
      Path()
        ..moveTo(cx + 54, 96)
        ..lineTo(cx + 70, 114)
        ..lineTo(cx + 70, 126)
        ..lineTo(cx + 54, 108)
        ..close(),
      Paint()..color = const Color(0xFF0E0E0E),
    );
    canvas.drawPath(padTop, padEdge);

    // Pad surface highlight
    canvas.drawLine(
      Offset(cx + 52, 98), Offset(cx - 80, 220),
      Paint()..color = const Color(0xFF242424)..strokeWidth = 1.0,
    );

    // Head rest (separate elevated pad at upper-right end)
    final headRest = Path()
      ..moveTo(cx + 54, 86)     // connects to main pad near edge
      ..lineTo(cx + 68, 70)     // headrest top near
      ..lineTo(cx + 82, 82)     // headrest top far
      ..lineTo(cx + 68, 98)     // connects to main pad far edge
      ..close();
    canvas.drawPath(headRest, padFill);

    // Headrest front face
    canvas.drawPath(
      Path()
        ..moveTo(cx + 68, 70)
        ..lineTo(cx + 82, 82)
        ..lineTo(cx + 82, 93)
        ..lineTo(cx + 68, 81)
        ..close(),
      Paint()..color = const Color(0xFF0E0E0E),
    );
    canvas.drawPath(headRest, padEdge);

    // Frame support uprights
    final leg = Paint()
      ..color = const Color(0xFF151515)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 58, 118), Offset(cx + 52, 192), leg);
    canvas.drawLine(Offset(cx - 76, 224), Offset(cx - 72, 254), leg);

    // Ground crossbar
    canvas.drawLine(
      Offset(cx - 72, 254), Offset(cx + 52, 254),
      Paint()..color = const Color(0xFF121212)..strokeWidth = 6..strokeCap = StrokeCap.round,
    );
  }

  void _drawBarGlow(Canvas canvas, double bx, double by) {
    final i = ((t - 0.50) / 0.50).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx, by), width: 140, height: 12),
      Paint()
        ..color = const Color(0xFFC9A84C).withValues(alpha: 0.15 * i)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  void _drawTrail(Canvas canvas, double bx, double by) {
    for (int i = 1; i <= 4; i++) {
      final a = (0.07 * t * (1.0 - i * 0.22)).clamp(0.0, 1.0);
      final dy = by + i * 13.0;
      final p = Paint()
        ..color = const Color(0xFFC9A84C).withValues(alpha: a)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(bx - 72, dy), Offset(bx - 72, dy + 9), p);
      canvas.drawLine(Offset(bx + 72, dy), Offset(bx + 72, dy + 9), p);
    }
  }

  void _drawBarbell(Canvas canvas, double bx, double by) {
    // Drop shadow
    canvas.drawLine(Offset(bx - 84, by + 8), Offset(bx + 70, by + 1),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    // Bar body
    canvas.drawLine(Offset(bx - 84, by + 4), Offset(bx + 70, by - 2),
      Paint()..color = const Color(0xFF747474)..strokeWidth = 8..strokeCap = StrokeCap.round);
    // Highlight
    canvas.drawLine(Offset(bx - 82, by + 1.5), Offset(bx + 68, by - 5),
      Paint()..color = const Color(0xFFCACACA)..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    // Knurling
    final knurl = Paint()..color = const Color(0xFF4E4E4E)..strokeWidth = 1;
    for (double x = bx - 32; x <= bx + 32; x += 6) {
      canvas.drawLine(Offset(x, by - 3.5), Offset(x, by + 3.5), knurl);
    }
    // Plates
    _plate(canvas, bx - 60, by, 26, const Color(0xFFC9A84C), const Color(0xFF8B6914));
    _plate(canvas, bx - 48, by, 20, const Color(0xFF9E7B30), const Color(0xFF6A5018));
    _plate(canvas, bx + 60, by, 26, const Color(0xFFC9A84C), const Color(0xFF8B6914));
    _plate(canvas, bx + 48, by, 20, const Color(0xFF9E7B30), const Color(0xFF6A5018));
    // Collars
    final collar = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(bx - 40, by), width: 8, height: 14),
      const Radius.circular(2)), collar);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(bx + 40, by), width: 8, height: 14),
      const Radius.circular(2)), collar);
  }

  void _plate(Canvas canvas, double x, double y, double r, Color face, Color edge) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: 13, height: r * 2),
      Paint()..color = edge);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 1, y), width: 10, height: r * 2 - 4),
      Paint()..color = face);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 1, y), width: 3.5, height: 7),
      Paint()..color = const Color(0xFF080808));
  }

  void _drawPhaseLabel(Canvas canvas, Size size) {
    final lock = t > 0.82;
    (TextPainter(
      text: TextSpan(
        text: lock ? 'LOCKOUT' : 'DRIVE',
        style: TextStyle(
          color: lock ? const Color(0xFFC9A84C) : const Color(0xFF333333),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(canvas, Offset(size.width - 82, size.height - 26));
  }

  @override
  bool shouldRepaint(_BenchPressPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
// DUMBBELL SHOULDER PRESS  — LiftOn Motion Engine™ v2
// ═══════════════════════════════════════════════════════════════════════════

class DumbbellShoulderPressAnimation extends StatefulWidget {
  const DumbbellShoulderPressAnimation({super.key});

  @override
  State<DumbbellShoulderPressAnimation> createState() =>
      _DumbbellShoulderPressAnimationState();
}

class _DumbbellShoulderPressAnimationState
    extends State<DumbbellShoulderPressAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C1C), width: 0.8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 260),
            painter: _GridPainter(),
          ),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _ShoulderPressPainter(t: _anim.value),
            ),
          ),
          const Positioned(
            top: 18,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DUMBBELL',
                  style: TextStyle(
                    color: Color(0xFFC9A84C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Shoulder Press',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 18,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC9A84C).withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: const Text(
                'SHOULDERS',
                style: TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shoulder Press Painter ───────────────────────────────────────────────────

class _ShoulderPressPainter extends CustomPainter {
  final double t; // 0 = dumbbells at shoulder, 1 = lockout overhead

  const _ShoulderPressPainter({required this.t});

  static Offset _solveElbow(
    Offset sh, Offset wr, double ua, double fa, double side,
  ) {
    final dx = wr.dx - sh.dx;
    final dy = wr.dy - sh.dy;
    final rawD = math.sqrt(dx * dx + dy * dy);
    final d = rawD.clamp(0.5, ua + fa - 0.5);
    final cosA = ((d * d + ua * ua - fa * fa) / (2.0 * d * ua)).clamp(-1.0, 1.0);
    final sinA = math.sqrt(1.0 - cosA * cosA);
    final nx = dx / rawD;
    final ny = dy / rawD;
    return Offset(
      sh.dx + (nx * cosA - ny * sinA * side) * ua,
      sh.dy + (ny * cosA + nx * sinA * side) * ua,
    );
  }

  static void _drawLimb(
    Canvas canvas, Offset a, Offset b, double wA, double wB, Color col,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final nx = -dy / len;
    final ny = dx / len;
    final path = Path()
      ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
      ..lineTo(b.dx + nx * wB / 2, b.dy + ny * wB / 2)
      ..lineTo(b.dx - nx * wB / 2, b.dy - ny * wB / 2)
      ..lineTo(a.dx - nx * wA / 2, a.dy - ny * wA / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
        ..lineTo(b.dx + nx * wB / 2, b.dy + ny * wB / 2),
      Paint()
        ..color = Color.lerp(col, Colors.white, 0.22)!.withValues(alpha: 0.44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  // Limb with muscle belly — bicep volume, delt roundness
  static void _drawMuscledLimb(
    Canvas canvas, Offset a, Offset b,
    double wA, double wPeak, double wB, Color col,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final nx = -dy / len;
    final ny = dx / len;
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path()
      ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
      ..quadraticBezierTo(
        mid.dx + nx * wPeak / 2, mid.dy + ny * wPeak / 2,
        b.dx + nx * wB / 2, b.dy + ny * wB / 2,
      )
      ..lineTo(b.dx - nx * wB / 2, b.dy - ny * wB / 2)
      ..quadraticBezierTo(
        mid.dx - nx * wPeak / 2, mid.dy - ny * wPeak / 2,
        a.dx - nx * wA / 2, a.dy - ny * wA / 2,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + nx * wA / 2, a.dy + ny * wA / 2)
        ..quadraticBezierTo(
          mid.dx + nx * wPeak / 2, mid.dy + ny * wPeak / 2,
          b.dx + nx * wB / 2, b.dy + ny * wB / 2,
        ),
      Paint()
        ..color = Color.lerp(col, Colors.white, 0.22)!.withValues(alpha: 0.44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _drawJoint(Canvas canvas, Offset c, double r, Color col) {
    canvas.drawCircle(c, r, Paint()..color = col);
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Skeletal anchors — scapula pinned, only arms animate
    final rSh = Offset(cx + 30.0, 100.0);
    final lSh = Offset(cx - 24.0, 103.0);

    // Dumbbell trajectory
    final rDbX = cx + 56.0 - t * 18.0;
    final rDbY = 100.0 - t * 58.0;
    final lDbX = cx - 50.0 + t * 16.0;
    final lDbY = 103.0 - t * 58.0;
    final rDb = Offset(rDbX, rDbY);
    final lDb = Offset(lDbX, lDbY);

    const ua = 44.0;
    const fa = 38.0;
    final rElbow = _solveElbow(rSh, rDb, ua, fa,  1.0);
    final lElbow = _solveElbow(lSh, lDb, ua, fa, -1.0);

    final deltAct   = (t * 1.3 - 0.08).clamp(0.0, 1.0);
    final trapAct   = (t * 1.1 - 0.05).clamp(0.0, 1.0);
    final tricepAct = (t > 0.48 ? (t - 0.48) * 1.92 : 0.0).clamp(0.0, 1.0);

    const gold     = Color(0xFFC9A84C);
    const bodyFar  = Color(0xFF0D1520);
    const bodyBase = Color(0xFF162030);
    const bodyFace = Color(0xFF1B2A3C);
    const bodyRim  = Color(0xFF223244);

    _drawSeatedBench(canvas, cx);

    // Far arm — bicep belly
    _drawJoint(canvas, lSh, 9.0, bodyFar);
    _drawMuscledLimb(canvas, lSh, lElbow, 10.0, 13.0, 7.5, bodyFar);
    _drawLimb(canvas, lElbow, lDb, 7.5, 5.5, bodyFar);
    _drawJoint(canvas, lElbow, 7.5, bodyFar);

    // Torso with muscle activation
    _drawTorso(canvas, cx, rSh, lSh, deltAct, trapAct, gold,
               bodyFar, bodyBase, bodyFace, bodyRim);

    // Near arm — bicep belly + tricep glow
    _drawJoint(canvas, rSh, 11.0, bodyRim);
    _drawMuscledLimb(canvas, rSh, rElbow, 12.0, 15.0, 9.0, bodyFace);

    if (tricepAct > 0) {
      // Tricep horseshoe — elongated oval on posterior upper arm
      final tMid = Offset(
        (rSh.dx + rElbow.dx) / 2 - 3,
        (rSh.dy + rElbow.dy) / 2,
      );
      canvas.drawOval(
        Rect.fromCenter(center: tMid, width: 18, height: 30),
        Paint()
          ..color = gold.withValues(alpha: 0.13 * tricepAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    _drawLimb(canvas, rElbow, rDb, 9.0, 6.5, bodyFace);
    _drawJoint(canvas, rElbow, 9.0, bodyFace);

    // Anterior delt glow — oval follows delt cap contour
    if (deltAct > 0.05) {
      canvas.drawOval(
        Rect.fromCenter(center: rSh + const Offset(12, 0), width: 30, height: 28),
        Paint()
          ..color = gold.withValues(alpha: 0.17 * deltAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
    }

    _drawHead(canvas, cx, bodyBase, bodyFace);

    // Dumbbells always foreground
    _drawDumbbell(canvas, lDb, false);
    _drawDumbbell(canvas, rDb, true);

    _drawPhaseLabel(canvas, size);
  }

  // ── V-taper torso (seated, 3/4 front-right) ───────────────────────────────
  static void _drawTorso(
    Canvas canvas, double cx,
    Offset rSh, Offset lSh,
    double deltAct, double trapAct, Color gold,
    Color dark, Color mid, Color lit, Color rim,
  ) {
    // V-taper: wider delt caps → lat flare → oblique waist taper → hip
    final body = Path()
      ..moveTo(cx + 14, rSh.dy - 18)
      ..quadraticBezierTo(cx + 46, rSh.dy - 10, cx + 46, rSh.dy + 4)   // R delt cap
      ..quadraticBezierTo(cx + 46, rSh.dy + 24, cx + 36, rSh.dy + 36)  // R lat peak
      ..quadraticBezierTo(cx + 20, rSh.dy + 52, cx + 16, rSh.dy + 66)  // oblique
      ..lineTo(cx + 12, rSh.dy + 84)                                    // R hip
      ..lineTo(cx - 10, rSh.dy + 82)                                    // L hip
      ..lineTo(cx - 12, rSh.dy + 64)                                    // L waist
      ..quadraticBezierTo(cx - 36, rSh.dy + 26, cx - 36, rSh.dy + 4)   // L lat
      ..quadraticBezierTo(cx - 36, lSh.dy - 10, cx - 12, lSh.dy - 18)  // L delt
      ..close();
    canvas.drawPath(body, Paint()..color = mid);

    // Far-side darker overlay
    final farFace = Path()
      ..moveTo(cx - 12, lSh.dy - 18)
      ..quadraticBezierTo(cx - 36, lSh.dy - 10, cx - 36, lSh.dy + 4)
      ..quadraticBezierTo(cx - 36, rSh.dy + 26, cx - 12, rSh.dy + 64)
      ..lineTo(cx - 10, rSh.dy + 82)
      ..lineTo(cx - 6, rSh.dy + 82)
      ..lineTo(cx - 6, rSh.dy + 62)
      ..quadraticBezierTo(cx - 24, rSh.dy + 24, cx - 24, rSh.dy + 4)
      ..quadraticBezierTo(cx - 24, lSh.dy - 8, cx - 6, lSh.dy - 16)
      ..close();
    canvas.drawPath(farFace, Paint()..color = dark.withValues(alpha: 0.75));

    // Near-edge rim light
    canvas.drawPath(
      Path()
        ..moveTo(cx + 14, rSh.dy - 18)
        ..quadraticBezierTo(cx + 46, rSh.dy - 10, cx + 46, rSh.dy + 4)
        ..quadraticBezierTo(cx + 46, rSh.dy + 24, cx + 36, rSh.dy + 36)
        ..quadraticBezierTo(cx + 20, rSh.dy + 52, cx + 16, rSh.dy + 66)
        ..lineTo(cx + 12, rSh.dy + 84),
      Paint()
        ..color = rim.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round,
    );

    // Clavicle shoulder line
    canvas.drawLine(rSh, lSh, Paint()
      ..color = const Color(0xFF24344A)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round);

    // Sternum / pec separation
    canvas.drawLine(
      Offset(cx, rSh.dy + 2),
      Offset(cx, rSh.dy + 44),
      Paint()..color = const Color(0xFF1E2E40)..strokeWidth = 1.0,
    );

    // Serratus / oblique surface line
    canvas.drawLine(
      Offset(cx + 30, rSh.dy + 34),
      Offset(cx + 16, rSh.dy + 64),
      Paint()
        ..color = const Color(0xFF1A2C3E)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Anterior delt glow — oval follows delt cap contour
    if (deltAct > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 36, rSh.dy + 4), width: 28, height: 32),
        Paint()
          ..color = gold.withValues(alpha: 0.22 * deltAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Upper trap / medial delt glow
    if (trapAct > 0.15) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 6, rSh.dy - 8), width: 52, height: 20),
        Paint()
          ..color = gold.withValues(alpha: 0.12 * trapAct)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  // ── Head — tapered neck, proportional skull ───────────────────────────────
  static void _drawHead(Canvas canvas, double cx, Color base, Color face) {
    final hc = Offset(cx + 4, 48);

    // Tapered neck path: wider at trap base (y=82), narrower at skull
    canvas.drawPath(
      Path()
        ..moveTo(cx - 1, 82)
        ..lineTo(cx + 2, hc.dy + 12)
        ..lineTo(cx + 9, hc.dy + 12)
        ..lineTo(cx + 12, 82)
        ..close(),
      Paint()..color = base,
    );
    // Trap bulk / sternocleidomastoid at neck base
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 5, 84), width: 24, height: 13),
      Paint()..color = base,
    );

    canvas.drawCircle(hc, 16, Paint()..color = base);

    canvas.drawArc(
      Rect.fromCenter(center: hc, width: 32, height: 32),
      math.pi * 0.60, math.pi * 0.72,
      false,
      Paint()
        ..color = face.withValues(alpha: 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      Path()..addArc(
        Rect.fromCenter(center: hc, width: 32, height: 30),
        math.pi, math.pi,
      ),
      Paint()..color = const Color(0xFF0A1220),
    );
  }

  // ── Seated bench ──────────────────────────────────────────────────────────
  static void _drawSeatedBench(Canvas canvas, double cx) {
    final padFill = Paint()..color = const Color(0xFF191919);
    final padEdge = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Back support
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx + 24, 82, cx + 36, 184),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF141414),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx + 24, 82, cx + 36, 184),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0xFF1E1E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Seat top face
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - 46, 184, cx + 46, 197),
        const Radius.circular(4),
      ),
      padFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - 46, 184, cx + 46, 197),
        const Radius.circular(4),
      ),
      padEdge,
    );

    // Seat front face
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - 46, 197, cx + 46, 205),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF0F0F0F),
    );

    final leg = Paint()
      ..color = const Color(0xFF141414)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 40, 205), Offset(cx - 40, 234), leg);
    canvas.drawLine(Offset(cx + 40, 205), Offset(cx + 40, 234), leg);
    canvas.drawLine(Offset(cx + 28, 184), Offset(cx + 32, 234), leg);

    canvas.drawLine(
      Offset(cx - 40, 234), Offset(cx + 40, 234),
      Paint()
        ..color = const Color(0xFF101010)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Hex dumbbell ──────────────────────────────────────────────────────────
  static void _drawDumbbell(Canvas canvas, Offset center, bool isNear) {
    const hh = 11.0;
    const pH = 22.0;
    const pW = 11.0;
    const iH = 17.0;
    const iW =  8.0;

    final faceCol = isNear ? const Color(0xFFC9A84C) : const Color(0xFF9E7B30);
    const edgeCol   = Color(0xFF6A5018);
    const handleCol = Color(0xFF787878);
    const hlCol     = Color(0xFFCDCDCD);

    canvas.drawOval(
      Rect.fromCenter(center: center + const Offset(0, 5), width: 44, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.drawLine(
      Offset(center.dx - hh, center.dy),
      Offset(center.dx + hh, center.dy),
      Paint()..color = handleCol..strokeWidth = 7..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - hh, center.dy - 1.8),
      Offset(center.dx + hh, center.dy - 1.8),
      Paint()..color = hlCol..strokeWidth = 1.6..strokeCap = StrokeCap.round,
    );
    final kPaint = Paint()..color = const Color(0xFF525252)..strokeWidth = 0.8;
    for (double x = center.dx - 7; x <= center.dx + 7; x += 5) {
      canvas.drawLine(Offset(x, center.dy - 3), Offset(x, center.dy + 3), kPaint);
    }

    // Far plate
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - hh - 5, center.dy), width: pW, height: pH),
      Paint()..color = edgeCol,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - hh - 4, center.dy), width: iW, height: iH),
      Paint()..color = faceCol,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - hh - 4, center.dy), width: 3, height: 6),
      Paint()..color = const Color(0xFF080808),
    );

    // Near plate
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + hh + 5, center.dy), width: pW, height: pH),
      Paint()..color = edgeCol,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + hh + 4, center.dy), width: iW, height: iH),
      Paint()..color = faceCol,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + hh + 4, center.dy), width: 3, height: 6),
      Paint()..color = const Color(0xFF080808),
    );
  }

  void _drawPhaseLabel(Canvas canvas, Size size) {
    final lock = t > 0.82;
    (TextPainter(
      text: TextSpan(
        text: lock ? 'LOCKOUT' : 'PRESS',
        style: TextStyle(
          color: lock ? const Color(0xFFC9A84C) : const Color(0xFF333333),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(canvas, Offset(size.width - 78, size.height - 26));
  }

  @override
  bool shouldRepaint(_ShoulderPressPainter old) => old.t != t;
}
