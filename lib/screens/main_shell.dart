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
    _NavItem(icon: Icons.build_rounded,       label: 'Tools'),
    _NavItem(icon: Icons.person_rounded,      label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(5, (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
    ));
    _iconScales = _iconControllers.map((c) =>
      Tween<double>(begin: 1.0, end: 1.25)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack))
    ).toList();
    // Animate initial tab
    _iconControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) c.dispose();
    super.dispose();
  }

  // Public API for HomeScreen to call
  void changeTab(int index) {
    if (index == _current) return;
    HapticFeedback.selectionClick();
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
          setState(() {
            _previous = _current;
            _current = 0;
          });
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: _AnimatedTabBody(
        current:  _current,
        previous: _previous,
        screens:  _screens,
      ),
      bottomNavigationBar: _PremiumNavBar(
        current:    _current,
        items:      _items,
        scales:     _iconScales,
        onSelect:   changeTab,
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

  const _PremiumNavBar({
    required this.current,
    required this.items,
    required this.scales,
    required this.onSelect,
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

  const _NavTile({
    required this.item, required this.selected,
    required this.scale, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Icon with glow indicator
            Stack(alignment: Alignment.topCenter, children: [
              // Gold dot indicator above icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 20 : 0,
                height: selected ? 3 : 0,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  gradient: selected ? AppGradients.gold : null,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: selected ? [BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      blurRadius: 6)] : [],
                ),
              ),
            ]),

            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38, height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 22,
                color: selected ? AppColors.gold : AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 2),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                color: selected ? AppColors.gold : AppColors.textMuted,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(item.label),
            ),
          ]),
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
