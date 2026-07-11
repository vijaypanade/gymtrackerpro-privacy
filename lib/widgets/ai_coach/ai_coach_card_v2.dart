// lib/widgets/ai_coach/ai_coach_card_v2.dart
// Adaptive AI coach card. Visual identity shifts with CoachVisualState.
// Ambient pulse + message reveal animation. No external state deps.

import 'package:flutter/material.dart';
import '../../models/coach_visual_state.dart';
import '../../utils/app_constants.dart';

class AiCoachCardV2 extends StatefulWidget {
  final String suggestion;
  final CoachVisualState visualState;
  final bool canUseAI;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AiCoachCardV2({
    super.key,
    required this.suggestion,
    required this.visualState,
    required this.canUseAI,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AiCoachCardV2> createState() => _AiCoachCardV2State();
}

class _AiCoachCardV2State extends State<AiCoachCardV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glowAnim;

  CoachVisualTheme get _theme => widget.visualState.theme;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _theme.pulsePeriodMs),
    )..repeat(reverse: true);
    _buildGlowAnim();
  }

  void _buildGlowAnim() {
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AiCoachCardV2 old) {
    super.didUpdateWidget(old);
    if (old.visualState != widget.visualState) {
      final nextDuration = Duration(milliseconds: _theme.pulsePeriodMs);
      if (_pulse.duration != nextDuration) {
        _pulse.duration = nextDuration;
      }
      _pulse
        ..stop()
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) {
            final v = _glowAnim.value;
            final alpha = theme.glowMin + (theme.glowMax - theme.glowMin) * v;
            return Container(
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(
                  color: theme.accent.withValues(alpha: alpha + 0.04),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: alpha * 0.55),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── State icon ──────────────────────────
                _StateIcon(theme: _theme),
                const SizedBox(width: AppSpacing.md),
                // ── Message area ────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(theme: _theme),
                      const SizedBox(height: 5),
                      _MessageBody(
                        suggestion: widget.suggestion,
                        canUseAI: widget.canUseAI,
                        theme: _theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // ── Chevron ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _theme.accent.withValues(alpha: 0.45),
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── State icon badge ──────────────────────────────────────────────────────────
class _StateIcon extends StatelessWidget {
  final CoachVisualTheme theme;
  const _StateIcon({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.iconBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(theme.icon, color: theme.accent, size: 16),
      ),
    );
  }
}

// ── "AI COACH  •  [STATE LABEL]" header row ───────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final CoachVisualTheme theme;
  const _HeaderRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'COACH',
          style: TextStyle(
            fontFamily: 'Inter',
            color: theme.accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        // State chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.25),
              width: 0.7,
            ),
          ),
          child: Text(
            theme.label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: theme.accent,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Message body with AnimatedSwitcher reveal ─────────────────────────────────
class _MessageBody extends StatelessWidget {
  final String suggestion;
  final bool canUseAI;
  final CoachVisualTheme theme;

  const _MessageBody({
    required this.suggestion,
    required this.canUseAI,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!canUseAI) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              color: theme.accent, size: 12),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Elite insights available',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary.withValues(alpha: 0.88),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    final display = suggestion.isEmpty
        ? 'Conditions are stable. Execute today\'s session with intent.'
        : suggestion;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Text(
        display,
        key: ValueKey(display),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: theme.messageFontWeight,
          height: 1.28,
        ),
      ),
    );
  }
}
