// lib/widgets/workout_svg_icon.dart
// Single reusable widget for all workout SVG icons.
// Consistent sizing, tinting, padding, and optional glow.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/app_constants.dart';

class WorkoutSvgIcon extends StatelessWidget {
  final String asset;
  final bool active;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool glow;

  const WorkoutSvgIcon({
    super.key,
    required this.asset,
    this.active = true,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
    this.glow = false,
  });

  Color get _color =>
      active
          ? (activeColor ?? AppColors.gold)
          : (inactiveColor ?? Colors.white.withValues(alpha: 0.38));

  @override
  Widget build(BuildContext context) {
    final svg = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(_color, BlendMode.srcIn),
    );

    if (!glow) return svg;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: svg,
    );
  }
}

// ── Tile variant: icon inside a dark rounded container ────────────────────────
class WorkoutSvgTile extends StatelessWidget {
  final String asset;
  final Color color;
  final double tileSize;
  final double iconSize;
  final bool active;

  const WorkoutSvgTile({
    super.key,
    required this.asset,
    required this.color,
    this.tileSize = 44,
    this.iconSize = 22,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.12)
            : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Center(
        child: WorkoutSvgIcon(
          asset: asset,
          active: active,
          size: iconSize,
          activeColor: color,
        ),
      ),
    );
  }
}
