// lib/utils/exercise_icon_mapper.dart
// Maps exercise muscle group / category → SVG asset path.
// Falls back to emoji string if asset is missing.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExerciseIconMapper {
  ExerciseIconMapper._();

  static const _base = 'assets/icons';

  static const _muscleMap = <String, String>{
    'chest':     '$_base/chest.svg',
    'back':      '$_base/back.svg',
    'legs':      '$_base/legs.svg',
    'shoulders': '$_base/shoulders.svg',
    'arms':      '$_base/arms.svg',
    'core':      '$_base/core.svg',
    'cardio':    '$_base/cardio.svg',
    'general':   '$_base/dumbbell.svg',
    // specials
    'strength':    '$_base/barbell.svg',
    'hypertrophy': '$_base/dumbbell.svg',
    'recovery':    '$_base/recovery.svg',
    'ai':          '$_base/ai.svg',
    'streak':      '$_base/streak.svg',
    'machine':     '$_base/machine.svg',
  };

  /// Returns the SVG asset path for a given muscle/category key.
  /// [key] is case-insensitive.
  static String path(String key) =>
      _muscleMap[key.toLowerCase().trim()] ?? '$_base/dumbbell.svg';

  /// Ready-to-use SvgPicture widget with gold tint and optional size.
  /// Falls back to a Text emoji if the asset errors.
  static Widget icon(
    String muscleOrCategory, {
    double size = 28,
    Color color = const Color(0xFFD4AF37),
    String fallbackEmoji = '💪',
  }) {
    final assetPath = path(muscleOrCategory);
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Text(
        fallbackEmoji,
        style: TextStyle(fontSize: size * 0.75),
      ),
    );
  }

  /// Animated icon with subtle scale-on-tap and optional glow.
  static Widget tappableIcon(
    String muscleOrCategory, {
    required VoidCallback onTap,
    double size = 28,
    Color color = const Color(0xFFD4AF37),
    bool glow = false,
    String fallbackEmoji = '💪',
  }) {
    return _TappableSvgIcon(
      assetPath: path(muscleOrCategory),
      size: size,
      color: color,
      glow: glow,
      onTap: onTap,
      fallbackEmoji: fallbackEmoji,
    );
  }
}

// ── Tappable SVG icon with scale animation ────────────────────────────────────
class _TappableSvgIcon extends StatefulWidget {
  final String assetPath;
  final double size;
  final Color color;
  final bool glow;
  final VoidCallback onTap;
  final String fallbackEmoji;

  const _TappableSvgIcon({
    required this.assetPath,
    required this.size,
    required this.color,
    required this.glow,
    required this.onTap,
    required this.fallbackEmoji,
  });

  @override
  State<_TappableSvgIcon> createState() => _TappableSvgIconState();
}

class _TappableSvgIconState extends State<_TappableSvgIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svgWidget = SvgPicture.asset(
      widget.assetPath,
      width: widget.size,
      height: widget.size,
      colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      placeholderBuilder: (_) => Text(
        widget.fallbackEmoji,
        style: TextStyle(fontSize: widget.size * 0.75),
      ),
    );

    Widget child = svgWidget;

    if (widget.glow) {
      child = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: svgWidget,
      );
    }

    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) { _ac.reverse(); widget.onTap(); },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(scale: _scale, child: child),
    );
  }
}

// ── Convenience widget: icon inside a colored rounded-rect container ──────────
class ExerciseIconBox extends StatelessWidget {
  final String muscle;
  final Color color;
  final double boxSize;
  final double iconSize;
  final String fallbackEmoji;
  final BorderRadius? borderRadius;

  const ExerciseIconBox({
    super.key,
    required this.muscle,
    required this.color,
    this.boxSize = 52,
    this.iconSize = 26,
    this.fallbackEmoji = '💪',
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: ExerciseIconMapper.icon(
          muscle,
          size: iconSize,
          color: color,
          fallbackEmoji: fallbackEmoji,
        ),
      ),
    );
  }
}
