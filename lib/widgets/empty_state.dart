// lib/widgets/empty_state.dart — Phase 2 PREMIUM
// Engaging empty states across all screens
// Each state has: big emoji, title, subtitle, optional CTA
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';

// ════════════════════════════════════════════════
// BASE EMPTY STATE WIDGET
// ════════════════════════════════════════════════
class EmptyState extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Color accentColor;
  final bool compact;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.accentColor = AppColors.gold,
    this.compact = false,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f, _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _s = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _f,
    child: ScaleTransition(
      scale: _s,
      child: Padding(
        padding: EdgeInsets.all(widget.compact
            ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Emoji in glowing container
          Container(
            width: widget.compact ? 64 : 88,
            height: widget.compact ? 64 : 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withValues(alpha: 0.08),
              border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.20),
                  width: 1.5),
              boxShadow: [BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  blurRadius: 24, spreadRadius: 4)],
            ),
            child: Center(child: Text(widget.emoji,
                style: TextStyle(
                    fontSize: widget.compact ? 28 : 38))),
          ),
          SizedBox(height: widget.compact
              ? AppSpacing.md : AppSpacing.lg),

          // Title
          Text(widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: widget.compact ? 18 : 22,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: widget.compact ? 4 : AppSpacing.xs),

          // Subtitle
          Text(widget.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: widget.compact ? 12 : 13,
                  height: 1.5)),

          // CTA button
          if (widget.ctaLabel != null && widget.onCta != null) ...[
            SizedBox(height: widget.compact
                ? AppSpacing.lg : AppSpacing.xl),
            _CTAButton(
              label: widget.ctaLabel!,
              onTap: widget.onCta!,
              color: widget.accentColor,
              compact: widget.compact,
            ),
          ],
        ]),
      ),
    ),
  );
}

class _CTAButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool compact;
  const _CTAButton({required this.label, required this.onTap,
      required this.color, required this.compact});
  @override State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 160));
    _s = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp:   (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: Container(
      padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? AppSpacing.xl : AppSpacing.xxl,
          vertical: widget.compact ? 10 : 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          widget.color,
          widget.color.withValues(alpha: 0.8),
        ]),
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 14),
        boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.35),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Text(widget.label,
          style: GoogleFonts.rajdhani(
              color: Colors.black,
              fontSize: widget.compact ? 14 : 16,
              fontWeight: FontWeight.w900)),
    )),
  );
}

// ════════════════════════════════════════════════
// PRE-BUILT EMPTY STATES — ready to use
// ════════════════════════════════════════════════

/// Stats → Progress tab: no workout logged yet
class EmptyProgress extends StatelessWidget {
  final VoidCallback? onStart;
  const EmptyProgress({super.key, this.onStart});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Center(child: EmptyState(
      emoji: '📈',
      title: 'No Progress Data Yet',
      subtitle: 'Log your first workout and watch\nyour strength curve climb.',
      accentColor: AppColors.goldSoft,
      ctaLabel: onStart != null ? '🏋️ Start First Workout' : null,
      onCta: onStart,
    )),
  );
}

/// Stats → History tab: no history yet
class EmptyHistory extends StatelessWidget {
  final VoidCallback? onPlan;
  const EmptyHistory({super.key, this.onPlan});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Center(child: EmptyState(
      emoji: '🗓️',
      title: 'History Starts Today',
      subtitle: 'Complete your first session and\nthis page comes alive.',
      accentColor: AppColors.textSecondary,
      ctaLabel: onPlan != null ? '📋 Go to Planner' : null,
      onCta: onPlan,
    )),
  );
}

/// Home → No today workout
class EmptyTodayWorkout extends StatelessWidget {
  final VoidCallback? onGenerate;
  const EmptyTodayWorkout({super.key, this.onGenerate});

  @override
  Widget build(BuildContext context) => EmptyState(
    emoji: '💪',
    title: 'No Workout Today',
    subtitle: 'Start with a plan built around your goal.',
    accentColor: AppColors.gold,
    ctaLabel: onGenerate != null ? 'Generate Plan' : null,
    onCta: onGenerate,
    compact: true,
  );
}

/// Stats → No missions completed
class EmptyMissions extends StatelessWidget {
  const EmptyMissions({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    emoji: '🎯',
    title: 'No Active Missions',
    subtitle: 'Complete workouts to unlock\ndaily missions and bonus XP.',
    accentColor: AppColors.orange,
    compact: true,
  );
}

/// Planner → Exercise picker: no results
class EmptySearchResults extends StatelessWidget {
  final String query;
  const EmptySearchResults({super.key, required this.query});

  @override
  Widget build(BuildContext context) => Center(child: EmptyState(
    emoji: '🔍',
    title: 'No Results for "$query"',
    subtitle: 'Try a different name or category,\nor add a custom exercise.',
    accentColor: AppColors.textMuted,
    compact: true,
  ));
}

/// Generic — fallback for any screen
class EmptyGeneric extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  const EmptyGeneric({
    super.key,
    this.title = 'Nothing Here Yet',
    this.subtitle = 'Start using the app to see data here.',
    this.emoji = '✨',
  });

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Center(child: EmptyState(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
    )),
  );
}
