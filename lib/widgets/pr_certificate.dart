// lib/widgets/pr_certificate.dart — PERSONAL BEST CERTIFICATE (premium polish)
// Apple-Achievement / Garmin-Badge presentation — not a paper certificate.
//   • Clear hierarchy: LiftOn → achievement → NAME (hero) → value → share
//   • Coaching copy, no legal language
//   • Refined engraved frame: subtle outer, dominant inner, corner ornaments
//   • Subtle entrance: fade + scale 0.98 → 1.00, 220ms
//   • Achievement ID (LT-YYYYMMDD-XXXXXX) for authenticity
//   • Share / Save via Screenshot — same pipeline as pr_celebration
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/user_provider.dart';
import '../utils/app_constants.dart';

// ════════════════════════════════════════════════
// PUBLIC API
// ════════════════════════════════════════════════

Future<void> showPRCertificate(
  BuildContext context, {
  required String exerciseName,
  required double weight,
  required int reps,
  String unit       = 'kg',
  double prevWeight = 0,
  int    prevReps   = 0,
  double firstWeight = 0,
  double improvePct  = 0,
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Certificate',
    barrierColor: Colors.black.withValues(alpha: 0.94),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (_, __, ___) => _CertificateScreen(
      exerciseName: exerciseName,
      weight:       weight,
      reps:         reps,
      unit:         unit,
      prevWeight:   prevWeight,
      prevReps:     prevReps,
      firstWeight:  firstWeight,
      improvePct:   improvePct,
    ),
  );
}

// ════════════════════════════════════════════════
// ENGRAVED FRAME PAINTER — subtle outer, dominant inner
// ════════════════════════════════════════════════

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const gold = AppColors.gold;

    // Outer border — quiet
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = gold.withValues(alpha: 0.28);
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(outerRect, outer);

    // Inner border — dominant
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = gold.withValues(alpha: 0.60);
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 14, size.width - 28, size.height - 28),
      const Radius.circular(3),
    );
    canvas.drawRRect(innerRect, inner);

    // Corner ornaments — small filigree diamonds + strokes
    final orn = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = gold.withValues(alpha: 0.75);
    final fill = Paint()..color = gold.withValues(alpha: 0.85);

    void corner(double cx, double cy, double sx, double sy) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(sx, sy);
      // L-shaped double stroke
      final p = Path()
        ..moveTo(22, 4)
        ..lineTo(8, 4)
        ..quadraticBezierTo(4, 4, 4, 8)
        ..lineTo(4, 22);
      canvas.drawPath(p, orn);
      final p2 = Path()
        ..moveTo(26, 9)
        ..lineTo(11, 9)
        ..quadraticBezierTo(9, 9, 9, 11)
        ..lineTo(9, 26);
      canvas.drawPath(p2, orn..strokeWidth = 0.6);
      // Diamond stud
      final d = Path()
        ..moveTo(16, 12)
        ..lineTo(20, 16)
        ..lineTo(16, 20)
        ..lineTo(12, 16)
        ..close();
      canvas.drawPath(d, fill);
      canvas.restore();
    }

    corner(0, 0, 1, 1);                              // top-left
    corner(size.width, 0, -1, 1);                    // top-right
    corner(0, size.height, 1, -1);                   // bottom-left
    corner(size.width, size.height, -1, -1);         // bottom-right
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}

// ════════════════════════════════════════════════
// CERTIFICATE SCREEN
// ════════════════════════════════════════════════

class _CertificateScreen extends StatefulWidget {
  final String exerciseName, unit;
  final double weight, prevWeight, firstWeight, improvePct;
  final int reps, prevReps;

  const _CertificateScreen({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.unit,
    required this.prevWeight,
    required this.prevReps,
    required this.firstWeight,
    required this.improvePct,
  });

  @override
  State<_CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<_CertificateScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey   = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  late final AnimationController _entryC;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  // Achievement ID — generated once per certificate view
  late final String _achievementId;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _entryC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fade  = CurvedAnimation(parent: _entryC, curve: Curves.easeOut);
    _scale = Tween(begin: 0.98, end: 1.0).animate(
        CurvedAnimation(parent: _entryC, curve: Curves.easeOut));
    _entryC.forward();

    final now = DateTime.now();
    final ymd = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final serial =
        (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    _achievementId = 'LT-$ymd-$serial';
  }

  @override
  void dispose() {
    _entryC.dispose();
    super.dispose();
  }

  // ── Strings ────────────────────────────────────────────────────────────────

  String _formatName(String raw) {
    if (raw.isEmpty) return 'Exercise';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String get _prValue {
    if (widget.unit == 'min') return '${widget.weight.toInt()} MIN';
    if (widget.unit == 'reps' || widget.weight == 0) {
      return '${widget.reps} REPS';
    }
    return '${widget.weight.toStringAsFixed(widget.weight % 1 == 0 ? 0 : 1)} '
        '${widget.unit.toUpperCase()} × ${widget.reps}';
  }

  String get _milestone {
    if (widget.improvePct >= 30) return 'ELITE PERFORMANCE';
    if (widget.improvePct >= 15) return 'PERFORMANCE PEAK';
    if (widget.improvePct >= 5)  return 'STRENGTH MILESTONE';
    return 'PERSONAL RECORD';
  }

  String get _subLine {
    // Personal, truthful milestone — journey preferred, then delta
    if (widget.firstWeight > 0 && widget.firstWeight < widget.weight - 0.01) {
      final gain = widget.weight - widget.firstWeight;
      return 'Journey: ${widget.firstWeight.toStringAsFixed(0)} → '
          '${widget.weight.toStringAsFixed(0)} ${widget.unit}  '
          '(+${gain.toStringAsFixed(0)})';
    }
    if (widget.prevWeight > 0) {
      final d = widget.weight - widget.prevWeight;
      if (d > 0.01) {
        return 'Previous best ${widget.prevWeight.toStringAsFixed(1)} '
            '${widget.unit}  ·  +${d.toStringAsFixed(1)} ${widget.unit}';
      }
      if (widget.prevReps > 0 && widget.reps > widget.prevReps) {
        return 'Rep record  ·  +${widget.reps - widget.prevReps} reps';
      }
    }
    return 'First recorded milestone';
  }

  String get _dateLine {
    const months = ['January','February','March','April','May','June','July',
        'August','September','October','November','December'];
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }

  // ── Share / Save ───────────────────────────────────────────────────────────

  Future<File?> _capture() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      await Future.delayed(const Duration(milliseconds: 60));
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/lifton_certificate_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(byteData.buffer.asUint8List());
      return f;
    } catch (e) {
      debugPrint('Certificate capture error: $e');
      return null;
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final f = await _capture();
      if (f == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not capture certificate — try again.')),
          );
        }
        return;
      }
      // Verify file actually exists on disk before handing to share sheet
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Certificate file not found — try again.')),
          );
        }
        return;
      }
      // Compute share button rect so iPad can anchor the popover correctly.
      // share_plus 10.x requires sharePositionOrigin on iPad; without it the
      // native plugin returns FlutterError and the sheet is never presented.
      Rect? shareRect;
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        shareRect = box.localToGlobal(Offset.zero) & box.size;
      }
      final result = await Share.shareXFiles(
        [XFile(f.path)],
        text: '🏆 ${_formatName(widget.exerciseName)} — $_prValue\n'
            'Certified by LiftOn 💪',
        sharePositionOrigin: shareRect,
      );
      debugPrint('Certificate share result: ${result.status}');
    } catch (e) {
      debugPrint('Certificate share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed — please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userName = context.read<UserProvider>().name.trim();
    final displayName =
        userName.isEmpty ? 'LIFTON ATHLETE' : userName.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── CERTIFICATE — fade + scale 0.98 → 1.00 ─────────────
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _certificateBody(displayName),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── ACTIONS ────────────────────────────────────────────
              FadeTransition(
                opacity: _fade,
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  _actionButton(
                    key: _shareButtonKey,
                    icon: Icons.share_rounded,
                    label: 'SHARE',
                    filled: true,
                    onTap: _share,
                  ),
                  const SizedBox(width: 12),
                  _actionButton(
                    icon: Icons.close_rounded,
                    label: 'CLOSE',
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    Key? key,
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: filled ? Colors.black : Colors.white70),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.rajdhani(
                  color: filled ? Colors.black : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
        ]),
      ),
    );
  }

  Widget _certificateBody(String displayName) {
    const gold = AppColors.gold;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: const _FramePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── 1. BRAND — quiet authority ─────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _crestLine(true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Transform.rotate(
                  angle: pi / 4,
                  child: Container(width: 7, height: 7, color: gold),
                ),
              ),
              _crestLine(false),
            ]),
            const SizedBox(height: 16),
            Text('LIFTON',
                style: GoogleFonts.rajdhani(
                    color: gold, fontSize: 17,
                    fontWeight: FontWeight.w900, letterSpacing: 7)),
            const SizedBox(height: 26),

            // ── 2. ACHIEVEMENT TITLE — emotional, not corporate ────
            Text('NEW PERSONAL BEST',
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.2)),
            const SizedBox(height: 26),

            // ── 3. NAME — the hero ─────────────────────────────────
            Text(displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5)),
            const SizedBox(height: 10),
            Container(
              width: 130, height: 1,
              color: gold.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),

            // Coaching copy — short, human
            Text('completed a new personal record',
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4)),
            const SizedBox(height: 22),

            // ── 4. VALUE — second strongest, pure typography ───────
            Text(_prValue,
                style: GoogleFonts.rajdhani(
                    color: gold,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.0)),
            const SizedBox(height: 8),

            // ── 5. CATEGORY — metadata ─────────────────────────────
            Text(_formatName(widget.exerciseName),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(_subLine,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),

            // ── 6. MILESTONE BADGE — pill, thin border, roomy ──────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: gold.withValues(alpha: 0.45), width: 0.7),
                color: gold.withValues(alpha: 0.06),
              ),
              child: Text(_milestone,
                  style: GoogleFonts.inter(
                      color: gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.6)),
            ),
            const SizedBox(height: 24),

            // ── 7. FOOTER — date · calm line · achievement ID ──────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _crestLine(true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_dateLine,
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6)),
              ),
              _crestLine(false),
            ]),
            const SizedBox(height: 12),
            Text('Built Through Consistency',
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            // Achievement ID — authenticity mark
            Text('ACHIEVEMENT ID  ·  $_achievementId',
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8)),
          ]),
        ),
      ),
    );
  }

  Widget _crestLine(bool fadeLeft) => Container(
        width: 44, height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fadeLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fadeLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              AppColors.gold.withValues(alpha: 0.0),
              AppColors.gold.withValues(alpha: 0.55),
            ],
          ),
        ),
      );
}
