// lib/widgets/home/layered_body_heatmap.dart
// PNG-based layered body heatmap — LiftOn's premium AI Recovery Scan visualization.
//
// Architecture (bottom → top):
//   AmbientScanFx          — warm environment + neural lines + particles (own controllers)
//   EnergyCorePainter      — pulsing gold vertical-divider presence
//   _BodySide × 2          — PNG silhouette + MuscleGlowPainter + ScanLinePainter
//
// Animation split (this widget owns):
//   _breathCtrl  2 600 ms — fast pulse for fatigued muscle glow + energy core
//   _slowCtrl    4 500 ms — slow body scale breathe + ready-muscle inhale/exhale
//   _scanCtrl    7 000 ms — holographic AI scan sweep
//
// AmbientScanFx owns its own neural (20 s) + particle (12 s) controllers, keeping
// this widget's rebuild budget tight.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_constants.dart';
import 'ambient_scan_fx.dart';
import 'muscle_overlay_painter.dart';
import 'muscle_command_sheet.dart';

class LayeredBodyHeatmap extends StatefulWidget {
  final Map<String, double> scores;
  final List<MuscleRecovery> recoveries;

  /// Optional tap callback — fired in addition to the built-in bottom sheet.
  /// Receives the score key of the tapped muscle (e.g. 'chest', 'legs').
  final void Function(String muscleKey)? onMuscleTapped;

  const LayeredBodyHeatmap({
    super.key,
    required this.scores,
    required this.recoveries,
    this.onMuscleTapped,
  });

  @override
  State<LayeredBodyHeatmap> createState() => _LayeredBodyHeatmapState();
}

class _LayeredBodyHeatmapState extends State<LayeredBodyHeatmap>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _slowCtrl;
  late final AnimationController _scanCtrl;
  late final Animation<double> _breathAnim;
  late final Animation<double> _slowAnim;

  String? _activeFront;
  String? _activeBack;

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _breathAnim = CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut);

    _slowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _slowAnim = CurvedAnimation(parent: _slowCtrl, curve: Curves.easeInOut);

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _slowCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  MuscleRecovery? _recoveryFor(String key) =>
      widget.recoveries.where((r) => r.muscle.toLowerCase() == key).firstOrNull;

  void _handleTap(String? key, bool isFront) {
    if (key == null) return;
    setState(() {
      if (isFront) {
        _activeFront = _activeFront == key ? null : key;
        _activeBack = null;
      } else {
        _activeBack = _activeBack == key ? null : key;
        _activeFront = null;
      }
    });

    widget.onMuscleTapped?.call(key);

    final rec = _recoveryFor(key);
    if (rec != null) {
      MuscleCommandSheet.show(context, rec);
    }

    // Fade focus highlight after the sheet appears
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _activeFront = null;
          _activeBack = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── FRONT / BACK labels — cinematic headspace ───────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
          child: Row(
            children: [
              Expanded(child: _ViewLabel('FRONT')),
              Expanded(child: _ViewLabel('BACK')),
            ],
          ),
        ),

        // ── Main visualization ──────────────────────────────────────────────
        SizedBox(
          height: 380,
          child: Stack(
            children: [
              // Layer 0: True black base — seamless hero foundation
              const Positioned.fill(child: ColoredBox(color: Color(0xFF000000))),

              // Layer 1: Dual radial depth glow — gold core + green halo for 3D pop
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DualRadialGlowPainter(),
                  ),
                ),
              ),

              // Layer 2: Atmospheric FX — fully isolated
              const Positioned.fill(child: AmbientScanFx()),

              // Layer 3: Unified scan sweep — spans full width, zero seam
              AnimatedBuilder(
                animation: _scanCtrl,
                builder: (_, __) => Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ScanLinePainter(progress: _scanCtrl.value),
                    ),
                  ),
                ),
              ),

              // Layer 4: Energy core + bodies
              AnimatedBuilder(
                animation: Listenable.merge([_breathCtrl, _slowCtrl]),
                builder: (_, __) {
                  final breathVal = _breathAnim.value;
                  final slowVal   = _slowAnim.value;

                  return Stack(
                    children: [
                      // Pulsing gold core between bodies
                      Positioned.fill(
                        child: IgnorePointer(
                          child: const SizedBox.shrink(),
                        ),
                      ),

                      // Body row — no gap widget, bodies flush side-by-side
                      Row(
                        children: [
                          // ── Front ──────────────────────────────────────
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: _activeFront != null ? 1.0 : 0.0,
                              ),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              builder: (_, focusAmt, __) => Transform.scale(
                                scale: 1.0 + slowVal * 0.015,
                                child: _BodySide(
                                  isFront:      true,
                                  scores:       widget.scores,
                                  breathAnim:   breathVal,
                                  readyAnim:    slowVal,
                                  focusAmount:  focusAmt,
                                  activeMuscle: _activeFront,
                                  onTap: (key) => _handleTap(key, true),
                                ),
                              ),
                            ),
                          ),

                          // ── Back (inverted breathing phase) ────────────
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: _activeBack != null ? 1.0 : 0.0,
                              ),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              builder: (_, focusAmt, __) => Transform.scale(
                                scale: 1.0 + (1.0 - slowVal) * 0.015,
                                child: _BodySide(
                                  isFront:      false,
                                  scores:       widget.scores,
                                  breathAnim:   breathVal,
                                  readyAnim:    1.0 - slowVal,
                                  focusAmount:  focusAmt,
                                  activeMuscle: _activeBack,
                                  onTap: (key) => _handleTap(key, false),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // ── Tap hint ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16, height: 0.5,
                color: AppColors.borderMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Tap a muscle to inspect',
                  style: AppTextStyles.caption.copyWith(
                    letterSpacing: 0.3,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ),
              Container(
                width: 16, height: 0.5,
                color: AppColors.borderMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── PNG body side ─────────────────────────────────────────────────────────────
// One body (front or back).
// Layer stack:
//   1. Realistic matte PNG silhouette    — base anatomy render
//   2. MuscleGlowPainter                — radial heat / recovery glow
//   3. ScanLinePainter                  — holographic AI sweep
//   4. GestureDetector                  — hit-zone tap detection

class _BodySide extends StatelessWidget {
  final bool isFront;
  final Map<String, double> scores;
  final double breathAnim;
  final double readyAnim;
  final double focusAmount;
  final String? activeMuscle;
  final void Function(String? key) onTap;

  const _BodySide({
    required this.isFront,
    required this.scores,
    required this.breathAnim,
    required this.readyAnim,
    required this.focusAmount,
    required this.activeMuscle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zones    = isFront ? frontZones : backZones;
    final pngAsset = isFront
        ? 'assets/body/body_front.png'
        : 'assets/body/body_back.png';

    return LayoutBuilder(
      builder: (_, constraints) {
        final bodySize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            String? hit;
            for (final zone in zones) {
              if (zone.hitTest(details.localPosition, bodySize)) {
                hit = zone.key;
                break;
              }
            }
            onTap(hit);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // No per-body background — outer Stack's true-black base shows through,
              // keeping both bodies seamlessly unified on one surface.

              // Layer 1: Realistic matte anatomy PNG — centered vertically, no bottom gap.
              Image.asset(
                pngAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                width: bodySize.width,
                height: bodySize.height,
                alignment: Alignment.center,
              ),

              // Layer 2: Recovery heat map — energy beneath the skin
              CustomPaint(
                painter: MuscleGlowPainter(
                  isFront:      isFront,
                  scores:       scores,
                  breathAnim:   breathAnim,
                  readyAnim:    readyAnim,
                  focusAmount:  focusAmount,
                  activeMuscle: activeMuscle,
                ),
              ),

              // (scan line and edge glow handled by the outer unified Stack)
            ],
          ),
        );
      },
    );
  }
}

// ── Dual radial glow — gold core + green biometric halo ──────────────────────

class _DualRadialGlowPainter extends CustomPainter {
  const _DualRadialGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy), size.height * 0.62,
          const [Color(0x18D4AF37), Color(0x0AD4AF37), Color(0x00D4AF37)],
          [0.0, 0.48, 1.0],
        ),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy), size.height * 0.55,
          const [Color(0x00109F6A), Color(0x0C109F6A), Color(0x00109F6A)],
          [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_DualRadialGlowPainter old) => false;
}

// ── View label ────────────────────────────────────────────────────────────────

class _ViewLabel extends StatelessWidget {
  final String label;
  const _ViewLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, const Color(0x40D4AF37)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0x99FFFFFF), // white60 — cinematic muted
                letterSpacing: 4.0,
              ),
            ),
          ),
          Container(
            width: 18, height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0x40D4AF37), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
