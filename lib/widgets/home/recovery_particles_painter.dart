// lib/widgets/home/recovery_particles_painter.dart
// Lightweight gold particle ambient field drawn behind the body heatmap.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class _ParticleDef {
  final double x;          // 0–1 normalized horizontal position
  final double baseY;      // 0–1 normalized starting vertical position
  final double size;       // radius in logical pixels
  final double speed;      // fraction of height moved per tick cycle
  final double maxOpacity;
  final double phase;      // offset into sine cycle

  const _ParticleDef(
      this.x, this.baseY, this.size, this.speed, this.maxOpacity, this.phase);
}

class RecoveryParticlesPainter extends CustomPainter {
  final double tick; // 0–1, monotonically increasing, wraps

  RecoveryParticlesPainter({required this.tick});

  static final List<_ParticleDef> _defs = _seed();

  static List<_ParticleDef> _seed() {
    final rng = math.Random(0xABCD1234);
    return List.generate(38, (_) => _ParticleDef(
      rng.nextDouble(),
      rng.nextDouble(),
      0.7 + rng.nextDouble() * 1.8,
      0.05 + rng.nextDouble() * 0.16,
      0.04 + rng.nextDouble() * 0.15,
      rng.nextDouble() * math.pi * 2,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _defs) {
      // Drift upward, wrap at top
      var rawY = (p.baseY - tick * p.speed) % 1.0;
      if (rawY < 0) rawY += 1.0;

      // Gentle horizontal sway
      final x = (p.x + math.sin(tick * math.pi * 2 * 0.5 + p.phase) * 0.028)
          .clamp(0.01, 0.99);

      // Opacity pulse: 35%–100% of maxOpacity
      final opacity = p.maxOpacity *
          (0.35 + 0.65 * math.sin(tick * math.pi * 2 + p.phase).abs());

      paint.color =
          const Color(0xFFD4A843).withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(x * size.width, rawY * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RecoveryParticlesPainter old) => old.tick != tick;
}
