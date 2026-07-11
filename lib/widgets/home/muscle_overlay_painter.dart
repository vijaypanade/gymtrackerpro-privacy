// lib/widgets/home/muscle_overlay_painter.dart
// Hit-zone geometry, glow overlay painter, scan-line painter, ambient glow painter,
// neural-lines painter, energy-core painter.
// The body silhouette is rendered from SVG assets — this file handles only
// the dynamic layers placed on top of or behind those assets.
// Logical coordinate space: 100 × 175 units (matches SVG viewBox).

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Recovery colour/status helpers ───────────────────────────────────────────
// Luxury cinematic palette — WHOOP × Apple Fitness × sci-fi biometric HUD.

Color recoveryColor(double score) {
  if (score >= 80) return const Color(0xFF10B981);  // emerald-teal READY
  if (score >= 60) return const Color(0xFFFBBF24);  // muted amber   RECOVERING
  return const Color(0xFF8B1E1E);                    // clinical deep red  FATIGUED / OVERTRAINED
}

String recoveryStatus(double score) {
  if (score >= 95) return 'PEAK RECOVERY';
  if (score >= 80) return 'READY';
  if (score >= 65) return 'MODERATE FATIGUE';
  if (score >= 45) return 'FATIGUED';
  return 'SUPPRESSED';
}

Color recoveryStatusColor(double score) => recoveryColor(score);

// ── Hit zone ──────────────────────────────────────────────────────────────────

class BodyHitZone {
  final String key;
  final List<Rect> rects; // in 100 × 175 logical space
  final bool isOval;

  const BodyHitZone(this.key, this.rects, {this.isOval = false});

  bool hitTest(Offset local, Size canvasSize) {
    final sx = canvasSize.width / 100.0;
    final sy = canvasSize.height / 175.0;
    final lx = local.dx / sx;
    final ly = local.dy / sy;
    for (final r in rects) {
      if (isOval) {
        final cx = r.left + r.width / 2;
        final cy = r.top + r.height / 2;
        final rx = r.width / 2 + 4.0;
        final ry = r.height / 2 + 4.0;
        final dx = (lx - cx) / rx;
        final dy = (ly - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) return true;
      } else {
        if (r.inflate(4.0).contains(Offset(lx, ly))) return true;
      }
    }
    return false;
  }

  /// Pixel-space bounding rect — used for gradient centre calculation.
  Rect pixelBounds(double sx, double sy) {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final rect in rects) {
      l = math.min(l, rect.left * sx);
      t = math.min(t, rect.top * sy);
      r = math.max(r, (rect.left + rect.width) * sx);
      b = math.max(b, (rect.top + rect.height) * sy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}

// ── Zones ─────────────────────────────────────────────────────────────────────

// Zones calibrated to new 1400×2400 anatomy PNGs.
// Logical space: 100×175 (matches BoxFit.fill stretch of PNG).
// Body opaque region: lx=[6.6,93.4], ly=[10.5,164.4].
// Landmark rows (pixel-precise from luminance analysis):
//   shoulders y≈30–52  |  chest y≈38–63  |  abs y≈65–98
//   hip       y≈93–110 |  thigh y≈100–142 |  calf y≈142–164

const List<BodyHitZone> frontZones = [
  BodyHitZone('chest', [
    Rect.fromLTWH(34, 52, 13, 10),
    Rect.fromLTWH(52, 52, 13, 10),
  ]),
  BodyHitZone('shoulders', [
    Rect.fromLTWH(30, 48, 7, 7),
    Rect.fromLTWH(63, 48, 7, 7),
  ], isOval: true),
  BodyHitZone('biceps', [
    Rect.fromLTWH(28, 54, 6, 18),
    Rect.fromLTWH(66, 54, 6, 18),
  ]),
  BodyHitZone('core', [
    Rect.fromLTWH(38, 64, 24, 18),
  ]),
  BodyHitZone('legs', [
    Rect.fromLTWH(38, 79, 11, 26),
    Rect.fromLTWH(51, 79, 11, 26),
  ]),
];

const List<BodyHitZone> backZones = [
  BodyHitZone('back', [
    Rect.fromLTWH(36, 48, 13, 22),
    Rect.fromLTWH(50, 48, 13, 22),
  ]),
  BodyHitZone('shoulders', [
    Rect.fromLTWH(30, 48, 7, 7),
    Rect.fromLTWH(63, 48, 7, 7),
  ], isOval: true),
  BodyHitZone('triceps', [
    Rect.fromLTWH(29, 53, 5, 16),
    Rect.fromLTWH(66, 53, 5, 16),
  ]),
  BodyHitZone('glutes', [
    Rect.fromLTWH(38, 76, 10, 10),
    Rect.fromLTWH(52, 76, 10, 10),
  ]),
  BodyHitZone('legs', [
    Rect.fromLTWH(38, 89, 11, 24),
    Rect.fromLTWH(51, 89, 11, 24),
  ]),
  BodyHitZone('calves', [
    Rect.fromLTWH(39, 118, 7, 10),
    Rect.fromLTWH(54, 118, 7, 10),
  ]),
];

// ── Muscle glow overlay painter ───────────────────────────────────────────────
// Two distinct rendering paths — darkness dominant throughout.
//
// READY (score ≥ 80): controlled, elegant emerald-cyan at ~38% of fatigue intensity
//   R1 — self-fading radial diffuse  (1.7×, 5% alpha)
//   R2 — subtle atmospheric bloom    (1.20×, blur 8)
//   R3 — clean surface glow          (1.00×, blur 4)
//   R4 — precise emerald hot centre  (0.45×, blur 2.5)
//
// FATIGUED / MODERATE (score < 80): deep crimson edge → orange-red → cream core
//   F1 — tight radial diffuse, crimson-tinted  (2.1×)
//   F2 — atmospheric bloom (1.5×, blur 11)
//   F3 — mid heat layer (1.18×, blur 5)
//   F4 — hot centre, temperature-shifted cream (0.60×, blur 3)
//   F5 — core spark (0.28×, blur 1.2, active only)
//
// All zones iterate individual rects — bilateral muscles produce tight anatomical
// glows, never a merged blob.

class MuscleGlowPainter extends CustomPainter {
  final bool isFront;
  final Map<String, double> scores;
  final double breathAnim;  // 0–1, fast 2600ms cycle
  final double readyAnim;   // 0–1, slow 4500ms cycle for high-recovery zones
  final double focusAmount; // 0–1, smooth dim transition (0=no focus, 1=focused)
  final String? activeMuscle;
  final int _hash;

  MuscleGlowPainter({
    required this.isFront,
    required this.scores,
    required this.breathAnim,
    required this.readyAnim,
    required this.focusAmount,
    this.activeMuscle,
  }) : _hash = Object.hashAll(
            scores.entries.map((e) => Object.hash(e.key, e.value.toInt())));

  static const double _kSize = 0.70; // anatomical glow scale (tight, no overflow)

  // Anatomical shape multipliers: (wm, hm) relative to hit-zone rect.
  // Chosen to follow muscle fibre orientation — long axis of glow matches muscle belly.
  static const Map<String, (double, double)> _frontShapes = {
    'chest':     (1.20, 0.72), // bilateral pec oval — wider than tall
    'shoulders': (0.88, 0.78), // cap-shaped deltoid cap
    'biceps':    (0.68, 1.05), // narrow vertical bicep streak
    'core':      (1.00, 0.82), // horizontal ab panel
    'legs':      (0.68, 0.88), // tall narrow quad streak — 20% tighter
  };
  static const Map<String, (double, double)> _backShapes = {
    'back':      (1.10, 0.80), // traps + lateral lat sweep (tighter, no overflow)
    'shoulders': (0.88, 0.78), // rear delt cap
    'triceps':   (0.68, 1.05), // narrow tricep streak
    'glutes':    (0.95, 0.75), // compact bilateral glute oval
    'legs':      (0.68, 0.88), // hamstring streak — 20% tighter
    'calves':    (0.56, 0.80), // very narrow calf streak — 20% tighter
  };

  // Zone key → canonical score key. Zones that share a score bucket with another key.
  static const Map<String, String> _zoneToScoreKey = {
    'glutes': 'legs', // glutes are tracked under the 'legs' recovery score
  };

  // Inner hot centre shifts toward warm orange-cream at peak pulse — thermal feel.
  static Color _hotColor(Color base, double heat) =>
      Color.lerp(base, const Color(0xFFFFE0B2), heat * 0.45)!;

  // Outer atmospheric layers shift toward deep crimson for fatigued tissue.
  static Color _outerColor(Color base, double score) {
    if (score < 60) return Color.lerp(base, const Color(0xFF520000), 0.50)!;
    return base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Hard clip to canvas bounds — prevents any glow from bleeding outside the body container.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final sx = size.width / 100.0;
    final sy = size.height / 175.0;
    _drawGlows(canvas, sx, sy, size);
    canvas.restore();
  }

  void _drawGlows(Canvas canvas, double sx, double sy, Size size) {
    final zones    = isFront ? frontZones : backZones;
    final shapeMap = isFront ? _frontShapes : _backShapes;

    for (final z in zones) {
      final scoreKey = _zoneToScoreKey[z.key] ?? z.key;
      final score = scores[scoreKey] ?? 97.0;
      if (score >= 99) continue;

      final isActive      = z.key == activeMuscle;
      final dimMultiplier = 1.0 - focusAmount * (isActive ? 0.0 : 0.82);
      final isReady       = score >= 80;

      final color      = recoveryColor(score);
      final outerColor = isReady ? color : _outerColor(color, score);

      final double animValue;
      final double pulseAmp;
      final double idleAlpha;
      final double activeAlpha;

      if (isReady) {
        animValue   = readyAnim;
        pulseAmp    = isActive ? 0.07 : 0.028;
        idleAlpha   = 0.24;
        activeAlpha = 0.50;
      } else if (score >= 60) {
        animValue   = breathAnim;
        pulseAmp    = isActive ? 0.11 : 0.045;
        idleAlpha   = 0.32;
        activeAlpha = 0.60;
      } else if (score >= 40) {
        // FATIGUED
        animValue   = breathAnim;
        pulseAmp    = isActive ? 0.14 : 0.060;
        idleAlpha   = 0.38;
        activeAlpha = 0.66;
      } else {
        // OVERTRAINED — denser glow + subtle flicker via fast phase shift
        animValue   = breathAnim;
        pulseAmp    = isActive ? 0.18 : 0.080;
        idleAlpha   = 0.44 + math.sin(breathAnim * math.pi * 5 + 0.8).abs() * 0.04;
        activeAlpha = 0.72;
      }

      final pulse     = animValue * pulseAmp;
      final baseAlpha = ((isActive ? activeAlpha : idleAlpha) + pulse) * dimMultiplier;
      if (baseAlpha < 0.005) continue;

      final (wm, hm) = shapeMap[z.key] ?? (1.0, 1.0);

      for (final rect in z.rects) {
        final pxRect = Rect.fromLTWH(
          rect.left * sx, rect.top * sy,
          rect.width * sx, rect.height * sy,
        );
        final center = pxRect.center;
        final w = pxRect.width;
        final h = pxRect.height;

        // Anatomically-shaped glow extents — _kSize applies 35% global reduction.
        final gw = w * wm * _kSize;
        final gh = h * hm * _kSize;
        // Blur capped to short axis so elongated shapes don't spread circularly.
        final blurMid = math.min(gw, gh) * 0.28;

        if (isReady) {
          // ── READY: emerald-teal, low-opacity sub-skin embedded ──

          // R1: Atmospheric diffuse haze — wide, soft biometric bloom
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 1.70, height: gh * 1.70),
            Paint()
              ..shader = ui.Gradient.radial(
                center, math.max(gw, gh) * 0.85,
                [
                  outerColor.withValues(alpha: baseAlpha * 0.14),
                  outerColor.withValues(alpha: baseAlpha * 0.020),
                  outerColor.withValues(alpha: 0),
                ],
                [0.0, 0.55, 1.0],
              )
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10.0),
          );

          // R2: Anatomical bloom — contour shape definition
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 1.15, height: gh * 1.15),
            Paint()
              ..color = outerColor.withValues(alpha: baseAlpha * 0.22)
              ..maskFilter = ui.MaskFilter.blur(
                  ui.BlurStyle.normal, blurMid.clamp(2.0, 8.0)),
          );

          // R3: Surface glow — primary visibility, tight to muscle shape
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw, height: gh),
            Paint()
              ..color = color.withValues(alpha: baseAlpha * 0.58)
              ..maskFilter = ui.MaskFilter.blur(
                  ui.BlurStyle.normal, (blurMid * 0.50).clamp(1.2, 5.0)),
          );

          // R4: Core spark — precise centre, stays emerald
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 0.40, height: gh * 0.40),
            Paint()
              ..color = color.withValues(alpha: baseAlpha * 0.90)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0),
          );

          if (isActive) {
            canvas.drawOval(
              Rect.fromCenter(
                center: center,
                width: gw + 2.5 + pulse * 8,
                height: gh + 2.5 + pulse * 8,
              ),
              Paint()
                ..color = color.withValues(alpha: 0.50)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.7,
            );
            canvas.drawCircle(
              center, 2.2,
              Paint()
                ..color = color.withValues(alpha: 0.75)
                ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0),
            );
          }
        } else {
          // ── FATIGUED/MODERATE: crimson outer → ember-red → cream core ──

          // F1: Atmospheric diffuse — deep crimson dermal haze, genuine biometric bloom
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 1.90, height: gh * 1.90),
            Paint()
              ..shader = ui.Gradient.radial(
                center, math.max(gw, gh) * 0.95,
                [
                  outerColor.withValues(alpha: baseAlpha * 0.14),
                  outerColor.withValues(alpha: baseAlpha * 0.020),
                  outerColor.withValues(alpha: 0),
                ],
                [0.0, 0.55, 1.0],
              )
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12.0),
          );

          // F2: Anatomical bloom — contour shape definition
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 1.40, height: gh * 1.40),
            Paint()
              ..color = outerColor.withValues(alpha: baseAlpha * 0.25)
              ..maskFilter = ui.MaskFilter.blur(
                  ui.BlurStyle.normal, blurMid.clamp(2.5, 10.0)),
          );

          // F3: Mid heat — primary visibility, follows muscle contour
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw, height: gh),
            Paint()
              ..color = color.withValues(alpha: baseAlpha * 0.68)
              ..maskFilter = ui.MaskFilter.blur(
                  ui.BlurStyle.normal, (blurMid * 0.50).clamp(1.5, 6.0)),
          );

          // F4: Hot centre — temperature-shifted toward cream
          final hotColor = _hotColor(color, animValue);
          canvas.drawOval(
            Rect.fromCenter(center: center, width: gw * 0.52, height: gh * 0.52),
            Paint()
              ..color = hotColor.withValues(alpha: baseAlpha * 0.96)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
          );

          if (isActive) {
            // F5: Core spark (active only)
            canvas.drawOval(
              Rect.fromCenter(center: center, width: gw * 0.24, height: gh * 0.24),
              Paint()
                ..color = hotColor.withValues(alpha: baseAlpha * 0.88)
                ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.0),
            );
            canvas.drawOval(
              Rect.fromCenter(
                center: center,
                width: gw + 3.5 + pulse * 10,
                height: gh + 3.5 + pulse * 10,
              ),
              Paint()
                ..color = color.withValues(alpha: 0.62)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.85,
            );
            canvas.drawCircle(
              center, 2.8,
              Paint()
                ..color = hotColor.withValues(alpha: 0.85)
                ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(MuscleGlowPainter old) =>
      old.breathAnim != breathAnim ||
      old.readyAnim  != readyAnim  ||
      old.focusAmount != focusAmount ||
      old.activeMuscle != activeMuscle ||
      old.isFront != isFront ||
      old._hash != _hash;
}

// ── Scan-line painter ─────────────────────────────────────────────────────────
// 4-pass holographic AI scanner with depth and directional bloom.
//   Pass 1: Wide atmospheric bloom (symmetric, 60px)
//   Pass 2: Trailing wake below leading edge (30px)
//   Pass 3: Core scan line — horizontal gold-white-gold gradient
//   Pass 4: Bright centre spark on leading edge

class ScanLinePainter extends CustomPainter {
  final double progress; // 0–1

  const ScanLinePainter({required this.progress});

  // Fixed data-dot positions along the scan line — deterministic, no Random in paint
  static const List<double> _dotX = [0.14, 0.24, 0.39, 0.52, 0.66, 0.78, 0.89];

  @override
  void paint(Canvas canvas, Size size) {
    // Scan sweeps only across the upper body (head → upper chest): 0–40% of height.
    // Keeps beam within chest/shoulder zone — never crosses pelvis or legs.
    final y = (progress * size.height * 0.40).clamp(0.0, size.height);
    final w = size.width;

    // Pass 0: Body illumination — warm wash over anatomy when beam sweeps through
    final illumT = (y - 32.0).clamp(0.0, size.height);
    final illumB = (y + 20.0).clamp(0.0, size.height);
    if (illumB > illumT) {
      canvas.drawRect(
        Rect.fromLTRB(0, illumT, w, illumB),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, illumT), Offset(0, illumB),
            [
              const Color(0x00FFFDE7),
              const Color(0x09FFFDE7), // warm body illumination at beam centre
              const Color(0x05D4A843),
              const Color(0x00D4A843),
            ],
            [0.0, 0.40, 0.70, 1.0],
          ),
      );
    }

    // Pass 1: Wide atmospheric bloom
    final bloomT = (y - 22.0).clamp(0.0, size.height);
    final bloomB = (y + 22.0).clamp(0.0, size.height);
    if (bloomB > bloomT) {
      canvas.drawRect(
        Rect.fromLTRB(0, bloomT, w, bloomB),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, bloomT), Offset(0, bloomB),
            [
              const Color(0x00D4A843),
              const Color(0x08D4A843),
              const Color(0x00D4A843),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
    }

    // Pass 2: Trailing wake below leading edge
    if (y + 18 <= size.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, 18),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, y), Offset(0, y + 18),
            [const Color(0x14D4A843), const Color(0x00D4A843)],
          ),
      );
    }

    // Pass 3: Core holographic scan line — gold-white-gold
    canvas.drawLine(
      Offset(0, y), Offset(w, y),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y), Offset(w, y),
          [
            const Color(0x00D4A843),
            const Color(0x22D4A843),
            const Color(0x66FFFDE7), // bright warm-white centre
            const Color(0x22D4A843),
            const Color(0x00D4A843),
          ],
          [0.0, 0.15, 0.50, 0.85, 1.0],
        )
        ..strokeWidth = 1.1,
    );

    // Pass 4: Bright centre spark — narrow crisp white
    canvas.drawLine(
      Offset(w * 0.22, y), Offset(w * 0.78, y),
      Paint()
        ..color = const Color(0xFFFFFFEE).withValues(alpha: 0.22)
        ..strokeWidth = 0.55,
    );

    // Pass 5: Data dots along beam — holographic data readout
    final dotPaint = Paint()
      ..color = const Color(0xFFD4A843).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    for (final dx in _dotX) {
      canvas.drawCircle(Offset(dx * w, y), 0.85, dotPaint);
    }
  }

  @override
  bool shouldRepaint(ScanLinePainter old) => old.progress != progress;
}

// ── Ambient body glow painter ─────────────────────────────────────────────────
// Cinematic warm radial environment behind the body — drawn once, never repaints.
// Creates a focused centre lighting pool (like a spotlight from above) and
// subtle dark-edge vignette for depth separation.

class AmbientBodyGlowPainter extends CustomPainter {
  const AmbientBodyGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;

    // Primary warm gold torso pool — concentrated oval spotlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.88,
        height: size.height * 0.72,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          size.height * 0.42,
          [
            const Color(0x28D4A843),
            const Color(0x12D4A843),
            const Color(0x00D4A843),
          ],
          [0.0, 0.50, 1.0],
        ),
    );

    // Secondary outer warm halo
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 1.20,
        height: size.height * 1.05,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          size.height * 0.55,
          [
            const Color(0x00000000),
            const Color(0x0CD4A843),
            const Color(0x00D4A843),
          ],
          [0.0, 0.65, 1.0],
        ),
    );

    // Cinematic vignette — dark heavy edges frame the bodies
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          size.height * 0.55,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0x44000000),
          ],
          [0.0, 0.50, 1.0],
        ),
    );

    // Top edge dark frame — cinematic letterbox feel
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.06),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, size.height * 0.06),
          [const Color(0x55000000), const Color(0x00000000)],
        ),
    );

    // Horizontal data-field bands — very faint scan texture
    for (int i = 0; i < 8; i++) {
      final fy = size.height * (0.12 + i * 0.11);
      canvas.drawLine(
        Offset(0, fy), Offset(size.width, fy),
        Paint()
          ..color = const Color(0x05D4A843)
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(AmbientBodyGlowPainter _) => false;
}

// ── Neural lines painter ──────────────────────────────────────────────────────
// Faint animated bezier arcs suggesting AI neural activity.
// Drawn behind SVG bodies — visible only in background negative space.

class NeuralLinesPainter extends CustomPainter {
  final double tick; // 0–1, from 20s controller

  const NeuralLinesPainter({required this.tick});

  static const List<List<double>> _arcs = [
    [0.02, 0.10, 0.18, 0.04, 0.35, 0.18, 0.48, 0.08, 0.0],
    [0.52, 0.07, 0.65, 0.20, 0.80, 0.04, 0.98, 0.16, 1.1],
    [0.01, 0.38, 0.14, 0.28, 0.32, 0.50, 0.48, 0.40, 2.2],
    [0.52, 0.38, 0.68, 0.52, 0.84, 0.32, 0.99, 0.45, 3.3],
    [0.03, 0.65, 0.20, 0.58, 0.38, 0.76, 0.48, 0.68, 0.7],
    [0.52, 0.63, 0.67, 0.78, 0.82, 0.60, 0.97, 0.72, 1.8],
    [0.08, 0.88, 0.28, 0.95, 0.42, 0.82, 0.48, 0.92, 2.9],
    [0.52, 0.86, 0.66, 0.96, 0.80, 0.80, 0.94, 0.90, 4.0],
  ];

  static const List<List<double>> _nodes = [
    [0.48, 0.08], [0.48, 0.40], [0.48, 0.68], [0.48, 0.92],
    [0.52, 0.07], [0.52, 0.38], [0.52, 0.63], [0.52, 0.86],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = tick * math.pi * 2;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;

    for (final a in _arcs) {
      final phase = a[8];
      final shift = math.sin(t + phase) * 0.05;

      final path = Path()
        ..moveTo(w * a[0], h * (a[1] + shift * 0.3))
        ..cubicTo(
          w * a[2], h * (a[3] + shift),
          w * a[4], h * (a[5] - shift * 0.5),
          w * a[6], h * (a[7] + shift * 0.2),
        );

      final opacity = 0.044 + 0.026 * math.sin(t * 0.7 + phase).abs();
      canvas.drawPath(
        path,
        linePaint..color = const Color(0xFFD4A843).withValues(alpha: opacity),
      );
    }

    // Faint pulsing nodes at arc endpoints near the centre divider
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (final n in _nodes) {
      final np = 0.5 + 0.5 * math.sin(t + n[0] * 15).abs();
      canvas.drawCircle(
        Offset(w * n[0], h * n[1]),
        0.9 + np * 0.5,
        nodePaint..color = const Color(0xFFD4A843).withValues(alpha: 0.07 + np * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(NeuralLinesPainter old) => old.tick != tick;
}

// ── Energy core painter ───────────────────────────────────────────────────────
// Ambient radial gold glow centred on the vertical divider between bodies.
// Three staggered expanding rings create a living data-pulse effect.

class EnergyCorePainter extends CustomPainter {
  final double pulse; // 0–1, 2600ms (breathCtrl)
  final double slow;  // 0–1, 4500ms (slowCtrl)

  const EnergyCorePainter({required this.pulse, required this.slow});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;

    // Wide outer warm field — sets cinematic mood
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.70,
        height: size.height * 0.88,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          size.width * 0.38,
          [
            const Color(0x1ED4A843),
            const Color(0x08D4A843),
            const Color(0x00D4A843),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    // Bright core dot — the signature emotional focal point
    canvas.drawCircle(
      Offset(cx, cy),
      2.2 + pulse * 1.2,
      Paint()
        ..color = const Color(0xFFD4A843).withValues(alpha: 0.55 + pulse * 0.25)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5),
    );
    // Inner pure-white spark
    canvas.drawCircle(
      Offset(cx, cy),
      0.9,
      Paint()..color = const Color(0xFFFFEDB2).withValues(alpha: 0.80 + pulse * 0.20),
    );
  }

  @override
  bool shouldRepaint(EnergyCorePainter old) =>
      old.pulse != pulse || old.slow != slow;
}

// ── Body edge glow painter ────────────────────────────────────────────────────
// Cinematic integration layer — embeds the PNG body into the dark dashboard.
// Paints: gold left rim · cool blue right rim · bottom feet fade · edge vignette.
// Sits on top of the PNG and scan line, pointer-ignored (decorative only).

class BodyEdgeGlowPainter extends CustomPainter {
  final bool isFront;

  const BodyEdgeGlowPainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mirror edge lighting: front = gold-left / blue-right (outer key, inner fill).
    //                       back  = blue-left / gold-right (inner fill, outer key).
    // This prevents the "tilt" optical illusion at the seam between the two bodies.
    final outerGoldLeft  =  isFront;
    final goldEdgeX      =  outerGoldLeft ? 0.0        : w * 0.72;
    final goldGradEnd    =  outerGoldLeft ? w * 0.28   : w;
    final goldStart      =  outerGoldLeft ? Offset.zero : Offset(w * 0.72, 0);
    final goldEnd        =  Offset(goldGradEnd, 0);

    final blueEdgeX      =  outerGoldLeft ? w * 0.72  : 0.0;
    final blueGradStart  =  outerGoldLeft ? Offset(w * 0.72, 0) : Offset.zero;
    final blueGradEnd    =  outerGoldLeft ? Offset(w, 0)        : Offset(w * 0.28, 0);

    // Outer key-light rim — warm gold
    canvas.drawRect(
      Rect.fromLTWH(goldEdgeX, 0, w * 0.28, h),
      Paint()
        ..shader = ui.Gradient.linear(
          goldStart, goldEnd,
          outerGoldLeft
              ? [const Color(0x1ED4A843), const Color(0x08D4A843), const Color(0x00D4A843)]
              : [const Color(0x00D4A843), const Color(0x08D4A843), const Color(0x1ED4A843)],
          [0.0, 0.55, 1.0],
        ),
    );

    // Inner fill-light rim — cool blue-grey (faces the centre / seam)
    canvas.drawRect(
      Rect.fromLTWH(blueEdgeX, 0, w * 0.28, h),
      Paint()
        ..shader = ui.Gradient.linear(
          blueGradStart, blueGradEnd,
          outerGoldLeft
              ? [const Color(0x004477BB), const Color(0x0C4477BB), const Color(0x184477BB)]
              : [const Color(0x184477BB), const Color(0x0C4477BB), const Color(0x004477BB)],
          [0.0, 0.45, 1.0],
        ),
    );

    // Bottom cinematic fade — feet dissolve into the true-black background
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.88, w, h * 0.12),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.88), Offset(0, h),
          const [
            Color(0x00000000),
            Color(0x55000000),
            Color(0xCC000000),
          ],
          [0.0, 0.50, 1.0],
        ),
    );

    // Soft ambient vignette — edges merge with background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.42),
          math.max(w, h) * 0.60,
          const [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x44000000),
          ],
          [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(BodyEdgeGlowPainter old) => old.isFront != isFront;
}
