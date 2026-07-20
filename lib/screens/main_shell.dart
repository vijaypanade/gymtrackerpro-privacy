// lib/screens/main_shell.dart — Phase 3
// UPGRADES:
//   ① Animated tab transitions — slide + fade between tabs
//   ② Premium bottom nav bar — glow indicator, scale animation
//   ③ Tab switch haptics
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/connectivity_service.dart';
import '../services/monetization_service.dart';
import '../services/workout_session_service.dart';
import '../utils/app_constants.dart';
import 'home_screen.dart';
import 'planner_screen.dart';
import 'stats_screen.dart';
import 'tools_screen.dart';
import 'profile_screen.dart';

// ════════════════════════════════════════════════
// MAIN SHELL — Tab container with animations
// ════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell>
    with TickerProviderStateMixin {

  int _current = 0;
  int _previous = 0;

  // One AnimationController per tab for independent nav icon animations
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  static const _screens = [
    HomeScreen(),
    PlannerScreen(),
    StatsScreen(),
    ToolsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    _NavItem(icon: Icons.home_rounded,        label: 'Home'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Planner'),
    _NavItem(icon: Icons.bar_chart_rounded,   label: 'Stats'),
    _NavItem(icon: Icons.science_outlined,      label: 'Explore'),
    _NavItem(icon: Icons.person_rounded,      label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(5, (_) => AnimationController(
      vsync: this,
      duration: AppDurations.normal,
      reverseDuration: AppDurations.fast,
    ));
    _iconScales = _iconControllers.map((c) =>
      Tween<double>(begin: 1.0, end: 1.25)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack))
    ).toList();
    // Animate initial tab
    _iconControllers[0].forward();

    // Deferred paywall — a trigger earned during a workout (or AI limit)
    // fires here on the next app open, never during the completion moment.
    // Short delay so the home screen settles first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        final ap = context.read<AppProvider>();
        final trigger = ap.pendingPaywallTrigger;
        if (trigger == null) return;
        ap.clearPaywallTrigger();
        PaywallSheet.show(context,
          trigger:      trigger,
          onUpgrade:    () => ap.refreshMonetization(),
        );
      });
    });
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Public API for HomeScreen to call
  void changeTab(int index) {
    if (index == _current) return;
    HapticFeedback.selectionClick();
    // Discard pending intent when navigating away from Planner without training
    if (_current == 1 && index != 1 &&
        !WorkoutSessionService.instance.isActive) {
      WorkoutSessionService.instance.clearIntent();
    }
    setState(() {
      _previous = _current;
      _current  = index;
    });
    _iconControllers[_previous].reverse();
    _iconControllers[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _current == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_current != 0) {
          if (_current == 1 && !WorkoutSessionService.instance.isActive) {
            WorkoutSessionService.instance.clearIntent();
          }
          setState(() {
            _previous = _current;
            _current = 0;
          });
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _OfflineBanner(),
        Expanded(child: _AnimatedTabBody(
          current:  _current,
          previous: _previous,
          screens:  _screens,
        )),
      ]),
      bottomNavigationBar: _PremiumNavBar(
        current:    _current,
        items:      _items,
        scales:     _iconScales,
        onSelect:   changeTab,
        ftueMode:   context.select<AppProvider, bool>(
                      (ap) => ap.streak.totalWorkouts == 0),
      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// ANIMATED TAB BODY
// ════════════════════════════════════════════════
class _AnimatedTabBody extends StatefulWidget {
  final int current, previous;
  final List<Widget> screens;

  const _AnimatedTabBody({
    required this.current,
    required this.previous,
    required this.screens,
  });

  @override
  State<_AnimatedTabBody> createState() => _AnimatedTabBodyState();
}

class _AnimatedTabBodyState extends State<_AnimatedTabBody>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.value = 1.0; // Start fully visible
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabBody old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      // Determine direction
      final goingRight = widget.current > old.current;
      _slide = Tween<Offset>(
        begin: Offset(goingRight ? 0.05 : -0.05, 0),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Keep all screens in memory (IndexedStack behavior)
      // but animate the active one
      for (int i = 0; i < widget.screens.length; i++)
        Offstage(
          offstage: i != widget.current,
          child: i == widget.current
              ? FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: widget.screens[i],
                  ),
                )
              : widget.screens[i],
        ),
    ]);
  }
}

// ════════════════════════════════════════════════
// PREMIUM BOTTOM NAV BAR
// ════════════════════════════════════════════════
class _PremiumNavBar extends StatelessWidget {
  final int current;
  final List<_NavItem> items;
  final List<Animation<double>> scales;
  final ValueChanged<int> onSelect;
  final bool ftueMode;

  const _PremiumNavBar({
    required this.current,
    required this.items,
    required this.scales,
    required this.onSelect,
    this.ftueMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
            top: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.6),
                width: 0.5)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: List.generate(items.length, (i) =>
          Expanded(child: _NavTile(
            item:     items[i],
            selected: i == current,
            scale:    scales[i],
            onTap:    () => onSelect(i),
            ftueMode: ftueMode,
          )),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final Animation<double> scale;
  final VoidCallback onTap;
  final bool ftueMode;

  const _NavTile({
    required this.item, required this.selected,
    required this.scale, required this.onTap,
    this.ftueMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = ftueMode && !selected;
    return AnimatedOpacity(
      opacity: dimmed ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Icon
            AnimatedContainer(
              duration: AppDurations.normal,
              width: 34, height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                item.icon,
                size: 23,
                color: selected
                    ? AppColors.gold
                    : AppColors.textSecondary.withValues(alpha: 0.82),
              ),
            ),

            const SizedBox(height: 2),

            // Label
            AnimatedDefaultTextStyle(
              duration: AppDurations.normal,
              style: GoogleFonts.inter(
                color: selected
                    ? AppColors.gold
                    : AppColors.textSecondary.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 4),
            // WHOOP-style bottom accent line
            AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: AppDurations.normal,
              child: Container(
                width: 14,
                height: 2,
                decoration: BoxDecoration(
                  gradient: AppGradients.gold,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.40),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
    );
  }
}


class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ════════════════════════════════════════════════
// OFFLINE BANNER — Phase S1
// Appears at the top when internet is lost.
// Auto-dismisses when connectivity returns.
// Uses StreamBuilder — no Provider, no state leak.
// ════════════════════════════════════════════════
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      initialData: ConnectivityService.instance.isOnline,
      stream:      ConnectivityService.instance.onlineStream,
      builder: (_, snap) {
        final online = snap.data ?? true;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: online
              ? const SizedBox.shrink()
              : const _OfflineBannerBody(key: ValueKey('offline')),
        );
      },
    );
  }
}

class _OfflineBannerBody extends StatelessWidget {
  const _OfflineBannerBody({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        color: const Color(0xFF1A1208),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded,
              size: 13, color: AppColors.gold.withValues(alpha: 0.70)),
          const SizedBox(width: 8),
          Text('No internet connection',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('Working offline',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.50),
                  fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }
}
