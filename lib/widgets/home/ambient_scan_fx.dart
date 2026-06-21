// lib/widgets/home/ambient_scan_fx.dart
// Self-contained ambient FX layer — manages its own long-cycle controllers.
// Drop into a Positioned.fill inside the body heatmap Stack.
//
// Layer order (painter's algorithm):
//   1. AmbientBodyGlowPainter  — static warm spotlight + data bands (const, never repaints)
//   2. NeuralLinesPainter      — AI bezier arcs, 20 s drift (isolated RepaintBoundary)
//   3. RecoveryParticlesPainter — floating gold motes, 12 s cycle (isolated RepaintBoundary)

import 'package:flutter/material.dart';

import 'muscle_overlay_painter.dart' show AmbientBodyGlowPainter, NeuralLinesPainter;
import 'recovery_particles_painter.dart';

class AmbientScanFx extends StatefulWidget {
  const AmbientScanFx({super.key});

  @override
  State<AmbientScanFx> createState() => _AmbientScanFxState();
}

class _AmbientScanFxState extends State<AmbientScanFx>
    with TickerProviderStateMixin {
  late final AnimationController _neuralCtrl;
  late final AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();
    _neuralCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _neuralCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Static warm environment — painted once, never re-triggers layout/paint
        const CustomPaint(painter: AmbientBodyGlowPainter()),

        // Neural AI drift lines — 20 s, repaint-isolated
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _neuralCtrl,
            builder: (_, __) => CustomPaint(
              painter: NeuralLinesPainter(tick: _neuralCtrl.value),
            ),
          ),
        ),

        // Gold particle motes — 12 s, repaint-isolated
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: RecoveryParticlesPainter(tick: _particleCtrl.value),
            ),
          ),
        ),
      ],
    );
  }
}
