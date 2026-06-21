// lib/widgets/pr_celebration.dart — v3.0 SMART PROGRESSION ENGINE
// 6 UPGRADES:
//   ① PR Validation — matched vs true PR
//   ② Dynamic XP — improvement % based
//   ③ Memory-based AI feedback — uses workout history
//   ④ Rarity: Normal / Strong / Elite / Legendary
//   ⑤ Visual: scale + shake + XP explosion + micro-vibration
//   ⑥ Continue loop — "Next Set Ready" / "Push Next Target"
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';
import '../engines/pr_engine.dart';

// ════════════════════════════════════════════════
// RARITY ENUM
// ════════════════════════════════════════════════
enum PRRarity { normal, strong, elite, legendary }

// ════════════════════════════════════════════════
// SMART ENGINE — all logic here
// ════════════════════════════════════════════════

// ════════════════════════════════════════════════
// RARITY THEME CONFIG
// ════════════════════════════════════════════════
class _RT {
  static Color primary(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return const Color(0xFFBF5FFF);
      case PRRarity.elite:     return const Color(0xFFFF4400);
      case PRRarity.strong:    return const Color(0xFFFFCC00);
      case PRRarity.normal:    return const Color(0xFFFFAA00);
    }
  }
  static Color secondary(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return const Color(0xFF00FFFF);
      case PRRarity.elite:     return const Color(0xFFFF8800);
      case PRRarity.strong:    return const Color(0xFFFFEE00);
      case PRRarity.normal:    return const Color(0xFFFFCC44);
    }
  }
  static String badge(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return 'Elite Performance';
      case PRRarity.elite:     return 'Performance Peak';
      case PRRarity.strong:    return 'Strength Milestone';
      case PRRarity.normal:    return 'Personal Record';
    }
  }
  static String headline(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return 'Exceptional Progress';
      case PRRarity.elite:     return 'Built Through Consistency';
      case PRRarity.strong:    return 'Strength Is Increasing';
      case PRRarity.normal:    return 'Progress Recorded';
    }
  }
  static String xpLabel(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return 'Elite Bonus';
      case PRRarity.elite:     return 'Performance Bonus';
      case PRRarity.strong:    return 'Strength Bonus';
      case PRRarity.normal:    return 'PR Bonus';
    }
  }
  static List<Color> confetti(PRRarity r) {
    switch (r) {
      case PRRarity.legendary:
        return [
          const Color(0xFFBF5FFF), const Color(0xFF00FFFF),
          const Color(0xFFFF69B4), const Color(0xFFFFD700),
          const Color(0xFFFFFFFF), const Color(0xFF9B59B6),
        ];
      case PRRarity.elite:
        return [
          const Color(0xFFFF4400), const Color(0xFFFF8800),
          const Color(0xFFFFCC00), const Color(0xFFFFFFFF),
          const Color(0xFFFF6600),
        ];
      case PRRarity.strong:
        return [
          const Color(0xFFFFCC00), const Color(0xFFFFEE00),
          const Color(0xFFFFFFFF), const Color(0xFFFF9900),
          const Color(0xFFFFF176),
        ];
      case PRRarity.normal:
        return [
          const Color(0xFFFFAA00), const Color(0xFFFFCC00),
          const Color(0xFFFFFFFF), const Color(0xFFFF9900),
        ];
    }
  }
  static int particleCount(PRRarity r) {
    switch (r) {
      case PRRarity.legendary: return 160;
      case PRRarity.elite:     return 130;
      case PRRarity.strong:    return 100;
      case PRRarity.normal:    return 75;
    }
  }
}

// ════════════════════════════════════════════════
// PUBLIC API
// ════════════════════════════════════════════════

// Helper: convert classification string to PRRarity enum
PRRarity _toRarity(String? classification) {
  if (classification == null) return PRRarity.normal;
  if (classification.contains('LEGENDARY')) return PRRarity.legendary;
  if (classification.contains('ELITE') || classification.contains('STRONG PR 💪'))
    return PRRarity.elite;
  if (classification.contains('STRONG'))    return PRRarity.strong;
  return PRRarity.normal;
}

Future<void> showPRCelebration(
  BuildContext context, {
  required String exerciseName,
  required double weight,
  required int    reps,
  required int    xpEarned,
  String unit           = 'kg',
  double prevWeight     = 0,
  int    prevReps       = 0,
  int    sessionCount   = 0,
  double improvePct     = 0,
  double firstWeight    = 0,   // Fix 5+6: journey tracking
  int    sessionPRCount = 0,   // Fix 7: combo PR counter
}) async {
  // Compute rarity
  final PRRarity rar = improvePct >= 30 ? PRRarity.legendary
      : improvePct >= 15 ? PRRarity.elite
      : improvePct >= 5  ? PRRarity.strong
      : PRRarity.normal;
  final dynXP = xpEarned;

  // Fix 4: Elite haptic + SystemSound
  final isElitePR = rar == PRRarity.legendary || rar == PRRarity.elite;
  if (isElitePR) {
    for (int i = 0; i < (rar == PRRarity.legendary ? 5 : 3); i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 70));
    }
  } else {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();
  }
  SystemSound.play(SystemSoundType.click);

  if (!context.mounted) return;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'PR',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, __) => _PRScreen(
      exerciseName:   exerciseName,
      weight:         weight,
      reps:           reps,
      prevWeight:     prevWeight,
      prevReps:       prevReps,
      xpEarned:       dynXP,
      unit:           unit,
      rarity:         rar,
      sessionCount:   sessionCount,
      improvePct:     improvePct,
      firstWeight:    firstWeight,
      sessionPRCount: sessionPRCount,
    ),
  );
}

// ════════════════════════════════════════════════
// MATCHED PR — not a true PR, just matched
// ════════════════════════════════════════════════
Future<void> showMatchedPR(BuildContext context, String exerciseName) async {
  HapticFeedback.mediumImpact();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      backgroundColor: AppColors.bgCard,
      duration: const Duration(seconds: 3),
      content: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: Text('💪',
              style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('Matched your best!', style: GoogleFonts.rajdhani(
              color: AppColors.gold, fontSize: 15,
              fontWeight: FontWeight.w800)),
          Text('Keep pushing for a new PR 🔥',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 11)),
        ])),
      ]),
    ));
}

// ════════════════════════════════════════════════
// CONFETTI
// ════════════════════════════════════════════════
class _P {
  double x, y, vx, vy, rot, rotV, size, opacity;
  Color color; int shape;
  _P({required this.x, required this.y, required this.vx,
    required this.vy, required this.rot, required this.rotV,
    required this.size, required this.color, required this.shape,
    this.opacity = 1.0});
}

class _CPainter extends CustomPainter {
  final List<_P> p;
  _CPainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    for (final pt in p) {
      canvas.save();
      canvas.translate(pt.x * size.width, pt.y * size.height);
      canvas.rotate(pt.rot);
      final paint = Paint()..color = pt.color.withValues(alpha: pt.opacity);
      switch (pt.shape) {
        case 0:
          canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero,
                width: pt.size, height: pt.size * 0.38),
            const Radius.circular(2)), paint);
        case 1:
          canvas.drawCircle(Offset.zero, pt.size * 0.42, paint);
        case 2:
          final path = Path();
          for (int i = 0; i < 5; i++) {
            final a1 = (i * 4 * pi / 5) - pi / 2;
            final a2 = a1 + 2 * pi / 5;
            if (i == 0) path.moveTo(pt.size*.5*cos(a1), pt.size*.5*sin(a1));
            else path.lineTo(pt.size*.5*cos(a1), pt.size*.5*sin(a1));
            path.lineTo(pt.size*.22*cos(a2), pt.size*.22*sin(a2));
          }
          path.close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }
  @override bool shouldRepaint(_CPainter _) => true;
}

class _Confetti extends StatefulWidget {
  final PRRarity rarity;
  const _Confetti({required this.rarity});
  @override State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_P> _pts = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _spawnBurst(initial: true);
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 50))
      ..addListener(_tick)..repeat();
    final bursts = _RT.particleCount(widget.rarity) > 100 ? 4 : 2;
    for (int i = 1; i <= bursts; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _spawnBurst();
      });
    }
  }

  void _spawnBurst({bool initial = false}) {
    final colors = _RT.confetti(widget.rarity);
    final count  = initial
        ? _RT.particleCount(widget.rarity)
        : (_RT.particleCount(widget.rarity) ~/ 3);
    for (int i = 0; i < count; i++) {
      final cx = initial
          ? (_rng.nextBool() ? 0.08 : 0.92)
              + (_rng.nextDouble() - 0.5) * 0.10
          : 0.2 + _rng.nextDouble() * 0.6;
      _pts.add(_P(
        x: cx, y: -0.02 - _rng.nextDouble() * 0.05,
        vx: (_rng.nextDouble() - 0.5) * 0.011,
        vy: 0.002 + _rng.nextDouble() * 0.008,
        rot: _rng.nextDouble() * 2 * pi,
        rotV: (_rng.nextDouble() - 0.5) * 0.24,
        size: 6 + _rng.nextDouble() * 13,
        color: colors[_rng.nextInt(colors.length)],
        shape: _rng.nextInt(3),
        opacity: 0.85 + _rng.nextDouble() * 0.15,
      ));
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _pts) {
        p.x += p.vx; p.y += p.vy;
        p.vy += 0.00014; p.vx *= 0.997;
        p.rot += p.rotV;
        if (p.y > 0.65) p.opacity = (p.opacity - 0.022).clamp(0, 1);
      }
      _pts.removeWhere((p) => p.y > 1.1 || p.opacity <= 0);
    });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
        painter: _CPainter(List.from(_pts)),
        child: const SizedBox.expand()));
}

// ════════════════════════════════════════════════
// SCREEN SHAKE WIDGET
// ════════════════════════════════════════════════
class _Shake extends StatefulWidget {
  final Widget child;
  final PRRarity rarity;
  const _Shake({required this.child, required this.rarity});
  @override State<_Shake> createState() => _ShakeState();
}
class _ShakeState extends State<_Shake>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    final intensity = widget.rarity == PRRarity.legendary ? 10.0
        : widget.rarity == PRRarity.elite ? 7.0 : 4.0;
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    Future.delayed(const Duration(milliseconds: 150),
        () { if (mounted) _c.forward(); });
    _c.addListener(() => setState(() {}));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final intensity = widget.rarity == PRRarity.legendary ? 10.0
        : widget.rarity == PRRarity.elite ? 7.0 : 4.0;
    final shake = _c.value < 0.7
        ? sin(_c.value * pi * 9) * intensity * (1 - _c.value * 0.8)
        : 0.0;
    return Transform.translate(
        offset: Offset(shake, 0), child: widget.child);
  }
}

// ════════════════════════════════════════════════
// XP EXPLOSION WIDGET
// ════════════════════════════════════════════════
class _XPExplode extends StatefulWidget {
  final int xp;
  final Color color;
  const _XPExplode({required this.xp, required this.color});
  @override State<_XPExplode> createState() => _XPExplodeState();
}
class _XPExplodeState extends State<_XPExplode>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500),
        () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: 10),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.3),
            blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('XP EARNED',
            style: GoogleFonts.inter(
                color: widget.color, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text('+${widget.xp} XP', style: GoogleFonts.rajdhani(
              color: widget.color, fontSize: 28,
              fontWeight: FontWeight.w900)),
        ]),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// PR SCREEN
// ════════════════════════════════════════════════
class _PRScreen extends StatefulWidget {
  final String exerciseName, unit;
  final double weight, prevWeight;
  final int    reps, prevReps, xpEarned, sessionCount;
  final PRRarity rarity;
  final double   improvePct;
  final double   firstWeight;    // Fix 5+6: journey
  final int      sessionPRCount; // Fix 7: combo

  const _PRScreen({
    required this.exerciseName, required this.weight,
    required this.reps,         required this.prevWeight,
    required this.prevReps,     required this.xpEarned,
    required this.unit,         required this.rarity,
    required this.sessionCount,
    this.improvePct     = 0,
    this.firstWeight    = 0,
    this.sessionPRCount = 0,
  });
  @override State<_PRScreen> createState() => _PRScreenState();
}

class _PRScreenState extends State<_PRScreen>
    with TickerProviderStateMixin {

  final ScreenshotController _screenshotCtrl = ScreenshotController();

  late AnimationController _trophyC, _cardC, _weightC, _shimmerC;
  late Animation<double> _trophy, _card, _weightScale, _shimmer;

  Color get _c  => _RT.primary(widget.rarity);
  Color get _c2 => _RT.secondary(widget.rarity);

  @override
  void initState() {
    super.initState();
    _trophyC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950));
    _trophy = CurvedAnimation(parent: _trophyC, curve: Curves.elasticOut);

    _cardC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 620));
    _card = CurvedAnimation(parent: _cardC, curve: Curves.easeOutBack);

    _weightC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _weightScale = CurvedAnimation(
        parent: _weightC, curve: Curves.elasticOut);

    _shimmerC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerC, curve: Curves.easeInOut);

    Future.delayed(const Duration(milliseconds: 100),
        () { if (mounted) _trophyC.forward(); });
    Future.delayed(const Duration(milliseconds: 280),
        () { if (mounted) _cardC.forward(); });
    Future.delayed(const Duration(milliseconds: 480),
        () { if (mounted) _weightC.forward(); });
  }

  @override
  void dispose() {
    _trophyC.dispose(); _cardC.dispose();
    _weightC.dispose(); _shimmerC.dispose();
    super.dispose();
  }


  // ══════════════════════════════════════════════
  // FIX 1: calculateScore + isPR (volume-based)
  // ══════════════════════════════════════════════
  static double calculateScore(double weight, int reps) {
    // Fix 9: safety — prevent negative or zero
    final w = weight.clamp(0.0, 999.0);
    final r = reps.clamp(0, 999);
    return w * r;
  }

  static bool isVolumePR({
    required double newWeight, required int newReps,
    required double oldWeight, required int oldReps,
  }) {
    // Fix 9: safety
    if (newWeight < 0 || newReps <= 0) return false;
    if (oldWeight == 0 && oldReps == 0) return true; // first ever
    return calculateScore(newWeight, newReps) >
           calculateScore(oldWeight, oldReps);
  }

  // Fix 2: calculateIncrease
  static double calculateIncrease(double newWeight, double oldWeight) =>
      newWeight - oldWeight;

  // Fix 2+3: Round to gym-standard weights (2.5kg increments)
  static double _roundToGymWeight(double value) {
    return (value / 2.5).round() * 2.5;
  }

  // Fix 3: getNextTarget — 5% increase, rounded to gym plates
  static double getNextTarget(double currentWeight) {
    if (currentWeight <= 0) return 20.0;
    return _roundToGymWeight(currentWeight * 1.05);
  }

  // Unified: uses calculateWorkoutFeedback — same logic as workout screen
  static String _nextTargetStr(
      double weight, int reps, String unit, double pct,
      {double prevBestWeight = 0, int prevBestReps = 0}) {
    final fb = calculateWorkoutFeedback(
      weight:             weight,
      reps:               reps,
      previousBestWeight: prevBestWeight,
      previousBestReps:   prevBestReps,
      isBodyweight:       unit == 'reps',
      unit:               unit,
    );
    if (fb.nextWeight <= 0) return 'Next: ${fb.nextReps} reps';
    if (unit == 'min') return 'Next: ${fb.nextWeight.toInt()} min';
    return 'Next: ${fb.nextWeight.toStringAsFixed(1)} kg';
  }

  // Inline improvement string
  static String _improvementStr(double nW, int nR,
      double pW, int pR, String unit) {
    if (pW == 0 && pR == 0) return '🎯 First record!';
    if (unit != 'reps' && pW > 0) {
      final d = nW - pW;
      if (d > 0.01)  return '+${d.toStringAsFixed(1)} kg 🔥';
      if (d < -0.01) return '${d.toStringAsFixed(1)} kg';
      final rd = nR - pR;
      if (rd > 0) return 'Rep PR +$rd reps 🔥';
      return 'No change 🔁';
    }
    if (pR > 0) {
      final rd = nR - pR;
      if (rd > 0) return '+$rd reps 🔥';
      if (rd < 0) return '$rd reps';
    }
    return 'No change 🔁';
  }

  // Fix 6: Journey string "Started: 20kg → Now: 35kg 🚀"
  static String _buildJourney(double first, double current) {
    if (first <= 0 || first >= current) return '';
    return 'Started: ${first.toStringAsFixed(0)}kg → Now: ${current.toStringAsFixed(0)}kg 🚀';
  }

  // Compute improvement % for nextTarget logic
  double _computeImprovePct() {
    if (widget.improvePct > 0) return widget.improvePct;
    if (widget.prevWeight > 0 && widget.weight > widget.prevWeight) {
      return ((widget.weight - widget.prevWeight) / widget.prevWeight * 100)
          .clamp(0.0, 999.0);
    }
    if (widget.prevReps > 0 && widget.reps > widget.prevReps) {
      return ((widget.reps - widget.prevReps) / widget.prevReps * 100)
          .clamp(0.0, 999.0);
    }
    return 0.0;
  }

  // Format exercise name: "ez_bar_curl" → "Ez Bar Curl"
  static String _formatName(String raw) {
    if (raw.isEmpty) return 'Exercise';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  // Fix 5: getPRType — tiered by % (40/20 thresholds)
  static String _getPRType(double pct) {
    if (pct >= 40) return 'Elite Performance';
    if (pct >= 20) return 'Performance Peak';
    return 'Personal Record';
  }

  // Fix 4: buildSmartMessage — exact spec messages
  String _coachMsg() {
    final pct      = widget.improvePct;
    final increase = calculateIncrease(widget.weight, widget.prevWeight);
    final fullName = _formatName(widget.exerciseName);
    final name     = fullName.split(' ').last;

    // Fix 9: safety check
    if (widget.weight < 0 || widget.reps <= 0) {
      return 'Keep pushing. Every rep counts 💪';
    }

    // First ever
    if (widget.prevWeight == 0 && widget.prevReps == 0) {
      return 'First milestone unlocked 💪\nLet\'s build something strong.';
    }

    // Fix 4: buildSmartMessage logic — exact spec
    String msg;
    if (pct >= 30) {
      msg = '🚀 Massive jump! ${pct.toStringAsFixed(0)}% improvement.';
    } else if (widget.reps >= 12) {
      msg = '🔥 Endurance improving. Control looks solid.';
    } else if (increase >= 10) {
      msg = '💪 Big strength gain. You\'re leveling up fast.';
    } else {
      msg = '📈 Small progress, big future gains.';
    }

    // Fix 8: Combo PR — append
    if (widget.sessionPRCount >= 2) {
      msg += '\n🔥 COMBO ×${widget.sessionPRCount}';
    }

    return msg;
  }

  String get _prValue {
    if (widget.unit == 'min') return '${widget.weight.toInt()} min';
    if (widget.unit == 'reps' || widget.weight == 0) {
      return '${widget.reps} reps';
    }
    return '${widget.weight.toStringAsFixed(1)} ${widget.unit} × ${widget.reps}';
  }

  String get _prevValue {
    if (widget.prevWeight == 0 && widget.prevReps == 0) return '—';
    if (widget.unit == 'min') return '${widget.prevWeight.toInt()} min';
    if (widget.unit == 'reps' || widget.prevWeight == 0) {
      return '${widget.prevReps} reps';
    }
    return '${widget.prevWeight.toStringAsFixed(1)} × ${widget.prevReps}';
  }


  Future<void> _sharePR() async {
    HapticFeedback.mediumImpact();
    try {
      final image = await _screenshotCtrl.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );
      if (image == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🔥 New PR: ${_formatName(widget.exerciseName)} — $_prValue\n'
              'Powered by LiftOn 💪',
      );
    } catch (e) {
      debugPrint('Share PR error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        _Confetti(rarity: widget.rarity),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: Screenshot(
                controller: _screenshotCtrl,
                child: Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [

                // ── TROPHY ────────────────────────
                _Shake(rarity: widget.rarity, child: ScaleTransition(
                  scale: _trophy,
                  child: Stack(alignment: Alignment.center, children: [
                    AnimatedBuilder(
                      animation: _shimmer,
                      builder: (_, __) => Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: _c.withValues(
                                alpha: 0.22 + 0.22 * _shimmer.value),
                            blurRadius: 55 + 30 * _shimmer.value,
                            spreadRadius: 10,
                          )],
                        ),
                      ),
                    ),
                    Container(
                      width: 74, height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_c, _c2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(child: Text('🏆',
                          style: TextStyle(fontSize: 32))),
                    ),
                  ]),
                )),
                const SizedBox(height: 10),

                // ── RARITY BADGE + HEADLINE ───────
                FadeTransition(opacity: _card, child: Column(
                    mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_c, _c2]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: _c.withValues(alpha: 0.45),
                          blurRadius: 18)],
                    ),
                    child: Text(
                      // Fix 5: Tier label based on % (40/20 thresholds)
                      widget.improvePct > 0
                          ? _getPRType(widget.improvePct)
                          : _RT.badge(widget.rarity),
                        style: GoogleFonts.inter(
                            color: Colors.black, fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _RT.headline(widget.rarity),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 19, fontWeight: FontWeight.w800,
                          height: 1.15)),
                ])),
                const SizedBox(height: 12),

                // ── MAIN CARD ─────────────────────
                ScaleTransition(
                  scale: _card,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090700),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: _c.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [BoxShadow(
                          color: _c.withValues(alpha: 0.16),
                          blurRadius: 22, spreadRadius: 0)],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min,
                        children: [

                      // Exercise name — formatted
                      Text(
                        _formatName(widget.exerciseName),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),

                      // ── NEW PR VALUE — scale + shimmer ──
                      ScaleTransition(
                        scale: _weightScale,
                        child: AnimatedBuilder(
                          animation: _shimmer,
                          builder: (_, __) => ShaderMask(
                            shaderCallback: (b) => LinearGradient(
                              colors: [_c, Colors.white, _c2],
                              stops: [
                                (_shimmer.value - 0.35).clamp(0.0, 1.0),
                                _shimmer.value.clamp(0.0, 1.0),
                                (_shimmer.value + 0.35).clamp(0.0, 1.0),
                              ],
                            ).createShader(b),
                            child: Text(_prValue,
                                style: GoogleFonts.rajdhani(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),

                      // ── COMPARISON ROW ────────────────
                      if (widget.prevWeight > 0 || widget.prevReps > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Previous Best: ${_prevValue}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.green.withValues(
                                        alpha: 0.3)),
                              ),
                              child: Text(
                                _improvementStr(
                                  widget.weight, widget.reps,
                                  widget.prevWeight, widget.prevReps,
                                  widget.unit),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                    color: AppColors.green, fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ]),
                      ],

                      // Fix 5+6: Journey "Started: 20kg → Now: 35kg 🚀"
                      if (widget.firstWeight > 0 &&
                          widget.firstWeight < widget.weight - 0.01) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _c.withValues(alpha: 0.08),
                              _c2.withValues(alpha: 0.04),
                            ]),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _c.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            _buildJourney(
                                widget.firstWeight, widget.weight),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: _c, fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Divider(color: _c.withValues(alpha: 0.18)),
                      const SizedBox(height: 12),

                      // ── XP EXPLOSION ──────────────────
                      _XPExplode(xp: widget.xpEarned, color: AppColors.purple),

                      const SizedBox(height: 12),

                      // ── AI COACH MESSAGE ──────────────
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF080600),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppGradients.gold),
                            child: const Center(child: Text('🤖',
                                style: TextStyle(fontSize: 15))),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(
                              _coachMsg(),
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12, height: 1.4,
                                  fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              // Smart next target
                              _nextTargetStr(
                                widget.weight, widget.reps,
                                widget.unit, widget.improvePct,
                                prevBestWeight: widget.prevWeight,
                                prevBestReps:   widget.prevReps),
                              style: GoogleFonts.inter(
                                  color: _c, fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          ])),
                        ]),
                      ),

                      // ── BRANDING WATERMARK (in screenshot) ──
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 36, height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('LiftOn',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      Text('TRAIN · TRACK · DOMINATE',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── CONTINUE LOOP BUTTON ──────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_c, _c2]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: _c.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 4))],
                    ),
                    child: Text('Continue Workout 🔥',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                            color: Colors.black, fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Share button
                ElevatedButton.icon(
                  onPressed: _sharePR,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text('Share Achievement',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Push Next Target →',
                      style: GoogleFonts.inter(
                          color: _c.withValues(alpha: 0.8),
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
              ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
