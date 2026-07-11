// lib/widgets/shared_widgets.dart — v5 Premium Components
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_constants.dart';

// ══════════════════════════════════════════════
// GOLD BUTTON — premium press effect
// ══════════════════════════════════════════════
class GoldButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final double? width;
  final IconData? icon;
  final bool small;

  const GoldButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.icon,
    this.small = false,
  });

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: AppDurations.instant);
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _down(_) { HapticFeedback.lightImpact(); _ctrl.forward(); }
  void _up(_)   { _ctrl.reverse(); }

  @override
  Widget build(BuildContext context) {
    final vPad = widget.small ? 10.0 : 14.0;
    final fontSize = widget.small ? 13.0 : 15.0;

    return GestureDetector(
      onTapDown: _down, onTapUp: _up, onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 14 : 18,
            vertical: vPad,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8C6A1A),
                Color(0xFFBF953F),
                Color(0xFFF7E08A),
                Color(0xFFFCF6BA),
              ],
              stops: [0.0, 0.35, 0.75, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.black, size: widget.small ? 15 : 18),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(widget.text,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontFamily: 'Inter',
                    color: Colors.black,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    overflow: TextOverflow.ellipsis,
                  )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// GHOST BUTTON — outlined variant
// ══════════════════════════════════════════════
class GhostButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final double? width;

  const GhostButton({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.color,
    this.width,
  });

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.gold;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_)   => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () { HapticFeedback.lightImpact(); widget.onTap(); },
      child: AnimatedContainer(
        duration: AppDurations.instant,
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? c.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: c.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: c, size: 16),
              const SizedBox(width: 6),
            ],
            Text(widget.text, style: TextStyle(fontFamily: 'Inter',
              color: c, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// PREMIUM CARD — glass effect with glow
// ══════════════════════════════════════════════
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? bgColor;
  final double? radius;
  final List<BoxShadow>? shadow;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.bgColor,
    this.radius,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? AppRadii.lg);
    final container = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: bgColor != null
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A1A),
                  Color(0xFF111111),
                ],
              ),
        color: bgColor,
        borderRadius: r,
        border: Border.all(
          color: borderColor ??
              Colors.white.withValues(alpha: 0.055),
          width: 0.8,
        ),
        boxShadow: shadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return container;

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap!(); },
      child: container,
    );
  }
}

// Alias for backward compat
class GoldCard extends PremiumCard {
  const GoldCard({
    super.key,
    required super.child,
    super.padding,
    super.onTap,
    super.borderColor,
  }) : super(
    bgColor: AppColors.bgCard,
  );
}

// ══════════════════════════════════════════════
// STAT TILE
// ══════════════════════════════════════════════
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? emoji;
  final Color color;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      borderColor: color.withValues(alpha: 0.15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 18))
          else if (icon != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontFamily: 'Rajdhani',
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// SECTION HEADER
// ══════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(
          color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Expanded(child: Text(title.toUpperCase(), style: AppTextStyles.sectionTitle)),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(fontFamily: 'Inter',
            color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════
// XP PROGRESS BAR — animated fill
// ══════════════════════════════════════════════
class XPProgressBar extends StatelessWidget {
  final double progress;  // 0.0 – 1.0
  final double height;
  final Color? color;

  const XPProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (_, val, __) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Stack(children: [
          Container(height: height, color: AppColors.bgElevated),
          FractionallySizedBox(
            widthFactor: val,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: color != null
                    ? LinearGradient(colors: [color!.withValues(alpha: 0.7), color!])
                    : AppGradients.gold,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// STREAK WIDGET
// ══════════════════════════════════════════════
class StreakWidget extends StatelessWidget {
  final int streak;
  final bool mini;

  const StreakWidget({super.key, required this.streak, this.mini = false});

  @override
  Widget build(BuildContext context) {
    if (mini) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 3),
        Text('$streak', style: const TextStyle(fontFamily: 'Inter',
          color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
      ]);
    }
    return PremiumCard(
      borderColor: AppColors.orange.withValues(alpha: 0.3),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Text('$streak Day Streak', style: const TextStyle(fontFamily: 'Rajdhani',
          color: AppColors.orange, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════
// BADGE WIDGET
// ══════════════════════════════════════════════
class BadgeWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final bool unlocked;

  const BadgeWidget({super.key, required this.emoji, required this.title, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.gold.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? AppColors.gold.withValues(alpha: 0.3) : AppColors.borderSoft,
          width: 0.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(unlocked ? emoji : '🔒', style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter',
          fontSize: 9,
          color: unlocked ? AppColors.gold : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ══════════════════════════════════════════════
// LOGO
// ══════════════════════════════════════════════
class AppLogoWidget extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogoWidget({super.key, this.size = 64, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.gold,
          boxShadow: [
            BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)],
        ),
        child: Icon(Icons.fitness_center_rounded, color: Colors.black, size: size * 0.45),
      ),
      if (showText) ...[
        SizedBox(height: size * 0.12),
        Text('LIFTON', style: TextStyle(fontFamily: 'Rajdhani',
          color: AppColors.gold, fontWeight: FontWeight.w900,
          fontSize: size * 0.20, letterSpacing: 1.5)),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════
// MUSCLE RECOVERY CHIP
// ══════════════════════════════════════════════


// ══════════════════════════════════════════════
// INFO CHIP — small label + value
// ══════════════════════════════════════════════
class InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final String? emoji;

  const InfoChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (emoji != null) ...[
          Text(emoji!, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
        ],
        Text(label, style: const TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontFamily: 'Inter',
          color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}


// ══════════════════════════════════════════════
// QUICK STATS ROW — 3 chips
// ══════════════════════════════════════════════
// SNACK HELPER
// ══════════════════════════════════════════════
SnackBar appSnack(String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  Color iconColor = AppColors.gold,
  Color bg = const Color(0xFF1E1E1E),
  Duration duration = const Duration(seconds: 3),
}) {
  return SnackBar(
    backgroundColor: bg,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    content: Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
class QuickStatsRow extends StatelessWidget {
  final List<({String label, String value, String emoji, Color color})> stats;

  const QuickStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
          child: StatTile(
            label: s.label, value: s.value, emoji: s.emoji, color: s.color),
        ));
      }).toList(),
    );
  }
}
