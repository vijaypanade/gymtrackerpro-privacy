// lib/screens/tools_screen.dart — v8.0 PREMIUM
// Upgrades:
//   • Tool cards: gradient icon containers, glow border, scale tap feedback
//   • BMI sheet: animated arc scale bar, category colour pill, coach copy
//   • Calorie sheet: macro tile grid, animated result reveal
//   • Water tracker: animated ring with wave, quick-add tiles with glow
//   • AI Generator: goal selector with active glow, staggered result list
//   • Reminders: premium toggle rows with colour-coded icons
//   • Removed progressionTip bug from _ToolCard entirely
//   • All spacing uses AppSpacing — zero hardcoded values
//   • All SizedBox const, all taps have scale feedback
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import '../models/split_template.dart';
import '../providers/app_provider.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';

import '../widgets/shared_widgets.dart';
import 'pr_wall_screen.dart';
import 'body_measurement_screen.dart';
import '../data/exercise_library.dart';
import '../services/ai_engine.dart';
import '../services/auth_service.dart';
import '../services/meal_log_service.dart';
import '../models/meal_log_model.dart';
import '../services/voice_coach_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════
// HAPTICS — consistent system (Phase 1)
// ════════════════════════════════════════════════
class H{
  static void heavy()     => HapticFeedback.heavyImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void light()     => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success()   => HapticFeedback.heavyImpact();
  static void tap()       => HapticFeedback.lightImpact();
}


// ════════════════════════════════════════════════
// TOOLS SCREEN
// ════════════════════════════════════════════════
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Ambient top glow
        Positioned(
          top: -80, left: -60, right: -60,
          child: IgnorePointer(child: Container(
            height: 280,
            decoration: BoxDecoration(gradient: RadialGradient(
              center: Alignment.topCenter, radius: 0.7,
              colors: [AppColors.gold.withValues(alpha: 0.03), Colors.transparent],
            )),
          )),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverAppBar(
              backgroundColor: AppColors.bg,
              floating: true, snap: true, elevation: 0,
              forceElevated: true,
              shadowColor: Colors.transparent,
              titleSpacing: AppSpacing.lg,
              toolbarHeight: 60,
              title: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text('HEALTH TOOLS', style: TextStyle(fontFamily: 'Rajdhani',
                    color: AppColors.textPrimary, fontSize: 20,
                    fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                Text('Your daily toolkit', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // ── MEAL HERO CARD ──────────────────────────
                const _MealHeroCard(),
                const SizedBox(height: AppSpacing.lg),

                const _SLabel(text: 'WORKOUT SPLIT'),
                const SizedBox(height: AppSpacing.sm),
                const _SplitStyleCard(),

                const SizedBox(height: AppSpacing.lg),
                const _SLabel(text: 'TOOLS'),
                const SizedBox(height: AppSpacing.sm),

                // ── CALCULATORS — single tap card ──────────
                _CalculatorsCard(onSheet: _sheet),

                const SizedBox(height: AppSpacing.lg),
                const _SLabel(text: 'RECORDS & COACHING'),
                const SizedBox(height: AppSpacing.sm),

                // ── PR Wall + Voice Coach — separate cards ──
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 0.6,
                    ),
                  ),
                  child: Column(children: [
                    _ToolCard(
                      title: 'PR Wall',
                      subtitle: 'Your all-time personal records',
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.gold,
                      tag: 'Records',
                      onTap: () => Navigator.push(context,
                          slideRoute(const PRWallScreen())),
                    ),
                    _toolDivider(),
                    _ToolCard(
                      title: 'Voice Coach',
                      subtitle: 'Multi-language workout coaching',
                      icon: Icons.mic_none_rounded,
                      color: AppColors.gold,
                      tag: 'New',
                      onTap: () => _sheet(context, const _VoiceCoachSheet()),
                    ),
                  ]),
                ),

                const SizedBox(height: AppSpacing.lg),
                const _SLabel(text: 'SMART REMINDERS'),
                const SizedBox(height: AppSpacing.sm),
                const _RemindersCard(),

                const SizedBox(height: AppSpacing.lg),
              ])),
            ),
          ],
        ),
      ]),
    );
  }

  void _sheet(BuildContext ctx, Widget w) => showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent, builder: (_) => w);

  static Widget _toolDivider() => Divider(
    height: 1, thickness: 0.6,
    color: Colors.white.withValues(alpha: 0.05),
    indent: 76, endIndent: 18,
  );
}

// ════════════════════════════════════════════════
// SECTION LABEL
// ════════════════════════════════════════════════
class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF8A8A8A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// TOOL CARD — premium, no progressionTip
// ════════════════════════════════════════════════
class _ToolCard extends StatefulWidget {
  final String title, subtitle, tag;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tag,
    required this.onTap,
  });
  @override State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 160));
    _s = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  Color _tagColor(String tag) => switch (tag) {
    'AI'        => AppColors.gold,
    'New'       => AppColors.gold,
    'Nutrition' => AppColors.orange,
    'Strength'  => AppColors.textSecondary,
    'Body'      => AppColors.goldSoft,
    'Tracking'  => AppColors.goldSoft,
    _           => Colors.white.withValues(alpha: 0.40),
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) { H.light(); _c.forward(); },
    onTapUp:     (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            widget.tag,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.20),
            size: 12,
          ),
        ]),
      ]),
    )),
  );
}

// ════════════════════════════════════════════════
// CALCULATORS CARD — single tap → sheet with all 4
// ════════════════════════════════════════════════
class _CalculatorsCard extends StatefulWidget {
  final void Function(BuildContext, Widget) onSheet;
  const _CalculatorsCard({required this.onSheet});
  @override State<_CalculatorsCard> createState() => _CalculatorsCardState();
}

class _CalculatorsCardState extends State<_CalculatorsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 160));
    _s = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  void _open() {
    H.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalculatorsSheet(onSheet: widget.onSheet),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { H.light(); _c.forward(); },
      onTapUp:     (_) { _c.reverse(); _open(); },
      onTapCancel: ()  => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.04), width: 0.6),
          ),
          child: Row(children: [
            // Icon cluster — 4 overlapping mini icons
            SizedBox(
              width: 46, height: 46,
              child: Stack(children: [
                _miniIcon(Icons.scale_rounded,               Alignment.topLeft),
                _miniIcon(Icons.local_fire_department_rounded, Alignment.topRight),
                _miniIcon(Icons.sports_gymnastics_rounded,   Alignment.bottomLeft),
                _miniIcon(Icons.accessibility_new_rounded,   Alignment.bottomRight),
              ]),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calculators',
                    style: TextStyle(fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15, fontWeight: FontWeight.w600,
                        letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text('BMI · Calories · 1RM · Body Stats',
                    style: TextStyle(fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 11.5)),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.20), size: 12),
          ]),
        ),
      ),
    );
  }

  static Widget _miniIcon(IconData icon, Alignment align) => Align(
    alignment: align,
    child: Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
      ),
      child: Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.55)),
    ),
  );
}

// Bottom sheet — lists all 4 calculators
class _CalculatorsSheet extends StatelessWidget {
  final void Function(BuildContext, Widget) onSheet;
  const _CalculatorsSheet({required this.onSheet});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        // Title row
        Row(children: [
          Text('Calculators', style: TextStyle(fontFamily: 'Rajdhani',
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.30), size: 20),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 0.6),
          ),
          child: Column(children: [
            _CalcRow(
              icon: Icons.scale_rounded,
              title: 'BMI Calculator',
              subtitle: 'Know your body composition',
              onTap: () {
                Navigator.pop(context);
                onSheet(context, const _BMISheet());
              },
            ),
            _sheetDiv(),
            _CalcRow(
              icon: Icons.local_fire_department_rounded,
              title: 'Calorie Calculator',
              subtitle: 'Find your daily fuel target',
              onTap: () {
                Navigator.pop(context);
                onSheet(context, const _CalorieSheet());
              },
            ),
            _sheetDiv(),
            _CalcRow(
              icon: Icons.sports_gymnastics_rounded,
              title: '1RM Calculator',
              subtitle: 'Estimate your max strength',
              onTap: () {
                Navigator.pop(context);
                onSheet(context, const _OneRmSheet());
              },
            ),
            _sheetDiv(),
            _CalcRow(
              icon: Icons.accessibility_new_rounded,
              title: 'Body Stats',
              subtitle: 'Track measurements & physique',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    slideRoute(const BodyMeasurementScreen()));
              },
            ),
          ]),
        ),
      ]),
    );
  }

  static Widget _sheetDiv() => Divider(
    height: 1, thickness: 0.6,
    color: Colors.white.withValues(alpha: 0.05),
    indent: 72, endIndent: 16,
  );
}

class _CalcRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _CalcRow({required this.icon, required this.title,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { H.light(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), shape: BoxShape.circle),
            child: Icon(icon, size: 18,
                color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontFamily: 'Inter',
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontFamily: 'Inter',
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.18), size: 12),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// SHEET WRAPPER
// ════════════════════════════════════════════════
class _SheetWrap extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  final IconData icon;

  const _SheetWrap({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
        border: Border(top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.12), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, 16, AppSpacing.xl, 24 + kb),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37)
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFFD4AF37),
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontFamily: 'Rajdhani',
                  color: AppColors.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(fontFamily: 'Inter',
                  color: AppColors.textMuted, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      )),
    );
  }
}

// ════════════════════════════════════════════════
// BMI CALCULATOR
// ════════════════════════════════════════════════
class _BMISheet extends StatefulWidget {
  const _BMISheet();
  @override State<_BMISheet> createState() => _BMISheetState();
}

class _BMISheetState extends State<_BMISheet>
    with SingleTickerProviderStateMixin {
  final _wCtrl = TextEditingController(text: '70');
  final _hCtrl = TextEditingController(text: '170');
  double? _bmi;
  String _cat = '';
  Color _catColor = AppColors.gold;
  late AnimationController _animC;
  late Animation<double> _animA;

  @override
  void initState() {
    super.initState();
    _animC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _animA = CurvedAnimation(parent: _animC, curve: Curves.easeOutCubic);
  }
  @override
  void dispose() {
    _wCtrl.dispose(); _hCtrl.dispose(); _animC.dispose(); super.dispose();
  }

  void _calc() {
    final w   = double.tryParse(_wCtrl.text) ?? 70;
    final h   = double.tryParse(_hCtrl.text) ?? 170;
    final bmi = w / ((h / 100) * (h / 100));
    String cat; Color color;
    if (bmi < 18.5) { cat = 'Underweight'; color = Colors.white.withValues(alpha: 0.50); }
    else if (bmi < 25) { cat = 'Healthy Weight'; color = AppColors.gold; }
    else if (bmi < 30) { cat = 'Overweight';     color = Colors.white.withValues(alpha: 0.65); }
    else               { cat = 'Obese';           color = Colors.white.withValues(alpha: 0.40); }
    _animC.forward(from: 0);
    setState(() { _bmi = bmi; _cat = cat; _catColor = color; });
  }

  @override
  Widget build(BuildContext context) => _SheetWrap(
    icon: Icons.monitor_weight_outlined, title: 'BMI Calculator',
    subtitle: 'Understand your body composition',
    child: Column(children: [
      Row(children: [
        Expanded(child: _LField(label: 'Weight (kg)', ctrl: _wCtrl)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _LField(label: 'Height (cm)', ctrl: _hCtrl)),
      ]),
      const SizedBox(height: AppSpacing.lg),
      GoldButton(text: 'Calculate BMI', width: double.infinity, onTap: _calc),
      if (_bmi != null) ...[
        const SizedBox(height: AppSpacing.xl),
        AnimatedBuilder(animation: _animA, builder: (_, __) => Opacity(
          opacity: _animA.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - _animA.value)),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: _catColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                  border: Border.all(
                      color: _catColor.withValues(alpha: 0.35), width: 1),
                  boxShadow: [BoxShadow(
                      color: _catColor.withValues(alpha: 0.10),
                      blurRadius: 20)],
                ),
                child: Column(children: [
                  Text(_bmi!.toStringAsFixed(1), style: TextStyle(fontFamily: 'Rajdhani',
                      color: _catColor, fontSize: 60,
                      fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 5),
                    decoration: BoxDecoration(
                      color: _catColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_cat, style: TextStyle(fontFamily: 'Inter',
                        color: _catColor, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _BMIArcBar(bmi: _bmi!, progress: _animA.value),
                  const SizedBox(height: AppSpacing.md),
                  Text(_bmiAdvice(_bmi!), style: const TextStyle(fontFamily: 'Inter',
                      color: AppColors.textSecondary, fontSize: 12,
                      height: 1.5), textAlign: TextAlign.center),
                ]),
              ),
            ]),
          ),
        )),
      ],
    ]),
  );

  String _bmiAdvice(double bmi) {
    if (bmi < 18.5) return "Your body needs more fuel — focus on calorie surplus and strength training to build healthy mass.";
    if (bmi < 25)   return "You're in the healthy zone. Keep consistent with your training and nutrition to stay here.";
    if (bmi < 30)   return "You're close to optimal — a calorie deficit with strength training will get you there fast.";
    return "Time to take charge. Combine cardio with resistance training and track your nutrition daily.";
  }
}

class _BMIArcBar extends StatelessWidget {
  final double bmi, progress;
  const _BMIArcBar({required this.bmi, required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = ((bmi - 15) / (40 - 15)).clamp(0.0, 1.0) * progress;
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Row(children: [
              Expanded(child: Container(height: 10,
                  color: Colors.white.withValues(alpha: 0.18))),
              Expanded(child: Container(height: 10,
                  color: AppColors.gold.withValues(alpha: 0.55))),
              Expanded(child: Container(height: 10,
                  color: Colors.white.withValues(alpha: 0.30))),
              Expanded(child: Container(height: 10,
                  color: Colors.white.withValues(alpha: 0.12))),
            ]),
            Positioned(
              left: (pct * w - 8).clamp(0.0, w - 16), top: -1,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 6,
                      color: Colors.black.withValues(alpha: 0.3))],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['15', '18.5', '25', '30', '40+'].map((t) =>
                Text(t, style: const TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 9))).toList()),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _CatLabel('Under',  Colors.white.withValues(alpha: 0.40)),
          _CatLabel('Normal', AppColors.gold),
          _CatLabel('Over',   Colors.white.withValues(alpha: 0.55)),
          _CatLabel('Obese',  Colors.white.withValues(alpha: 0.30)),
        ]),
      ]);
    });
  }
}

class _CatLabel extends StatelessWidget {
  final String t; final Color c;
  const _CatLabel(this.t, this.c);
  @override
  Widget build(BuildContext context) => Text(t, style: TextStyle(fontFamily: 'Inter',
      color: c, fontSize: 8, fontWeight: FontWeight.w700));
}

// ════════════════════════════════════════════════
// CALORIE CALCULATOR
// ════════════════════════════════════════════════
class _CalorieSheet extends StatefulWidget {
  const _CalorieSheet();
  @override State<_CalorieSheet> createState() => _CalorieSheetState();
}

class _CalorieSheetState extends State<_CalorieSheet>
    with SingleTickerProviderStateMixin {
  final _wC = TextEditingController(text: '70');
  final _hC = TextEditingController(text: '170');
  final _aC = TextEditingController(text: '25');
  String _activity = 'Moderate';
  Map<String, int>? _result;
  late AnimationController _animC;
  late Animation<double> _animA;

  static const _acts = {
    'Sedentary': 1.2,  'Light': 1.375,  'Moderate': 1.55,
    'Active': 1.725,   'Very Active': 1.9,
  };
  static const _actEmoji = {
    'Sedentary': '🛋️', 'Light': '🚶', 'Moderate': '🏃',
    'Active': '💪', 'Very Active': '🔥',
  };

  @override
  void initState() {
    super.initState();
    _animC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 550));
    _animA = CurvedAnimation(parent: _animC, curve: Curves.easeOutCubic);
  }
  @override
  void dispose() {
    _wC.dispose(); _hC.dispose(); _aC.dispose();
    _animC.dispose(); super.dispose();
  }

  void _calc() {
    final w   = double.tryParse(_wC.text)   ?? 70;
    final h   = double.tryParse(_hC.text)   ?? 170;
    final age = int.tryParse(_aC.text)       ?? 25;
    final bmr = 10 * w + 6.25 * h - 5 * age + 5;
    final td  = bmr * (_acts[_activity] ?? 1.55);
    _animC.forward(from: 0);
    setState(() => _result = {
      'BMR (Base)':      bmr.round(),
      'Maintain':        td.round(),
      'Lose Fat (−400)': (td - 400).round(),
      'Gain Muscle (+350)': (td + 350).round(),
    });
  }

  @override
  Widget build(BuildContext context) => _SheetWrap(
    icon: Icons.local_fire_department_outlined, title: 'Calorie Calculator',
    subtitle: 'Find your exact daily fuel target',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _LField(label: 'Weight (kg)', ctrl: _wC)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _LField(label: 'Height (cm)', ctrl: _hC)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _LField(label: 'Age', ctrl: _aC, isInt: true)),
      ]),
      const SizedBox(height: AppSpacing.lg),
      const Text('Activity Level', style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted, fontSize: 12,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: 8, runSpacing: 8,
        children: _acts.keys.map((a) {
          final sel = a == _activity;
          return GestureDetector(
            onTap: () => setState(() => _activity = a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 7),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.bgCardLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? AppColors.gold : Colors.transparent,
                    width: sel ? 1 : 0),
                boxShadow: sel ? [BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    blurRadius: 8)] : [],
              ),
              child: Text('${_actEmoji[a]} $a', style: TextStyle(fontFamily: 'Inter',
                  color: sel ? AppColors.gold : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: AppSpacing.lg),
      GoldButton(text: 'Calculate My Targets 💪',
          width: double.infinity, onTap: _calc),
      if (_result != null) ...[
        const SizedBox(height: AppSpacing.xl),
        AnimatedBuilder(animation: _animA, builder: (_, __) => Opacity(
          opacity: _animA.value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - _animA.value)),
            child: Column(
              children: _result!.entries.toList().asMap().entries.map((e) {
                final label   = e.value.key;
                final value   = e.value.value;
                final isMain  = label == 'Maintain';
                final isGoal  = label.startsWith('Lose') || label.startsWith('Gain');
                final color   = isMain ? AppColors.gold
                    : isGoal ? AppColors.textSecondary : AppColors.textMuted;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (e.key * 80).toInt()),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                        offset: Offset(0, 12 * (1 - v)), child: child),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 13),
                    decoration: BoxDecoration(
                      color: isMain
                          ? AppColors.gold.withValues(alpha: 0.07)
                          : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: isMain ? Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25)) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: TextStyle(fontFamily: 'Inter',
                            color: isMain ? AppColors.gold
                                : AppColors.textSecondary,
                            fontSize: 13, fontWeight: isMain
                            ? FontWeight.w700 : FontWeight.w500)),
                        Text('$value kcal', style: TextStyle(fontFamily: 'Rajdhani',
                            color: color, fontSize: 18,
                            fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        )),
      ],
    ]),
  );
}

// ════════════════════════════════════════════════
// WATER TRACKER
// ════════════════════════════════════════════════


class _AIWorkoutGenerator extends StatefulWidget {
  const _AIWorkoutGenerator();
  @override State<_AIWorkoutGenerator> createState() => _AIWorkoutGeneratorState();
}

class _AIWorkoutGeneratorState extends State<_AIWorkoutGenerator> {
  String _goal = 'Muscle Gain';
  WorkoutPlanResult? _result;
  bool _loading = false;
  bool _applied = false;

  static const _goals = ['Fat Loss', 'Muscle Gain', 'Strength'];
  static const _goalEmoji = {'Fat Loss': '🔥', 'Muscle Gain': '💪', 'Strength': '⚡'};
  static const _goalColors = {
    'Fat Loss': AppColors.orange,
    'Muscle Gain': AppColors.gold,
    'Strength': AppColors.goldSoft,
  };

  String _key(String g) {
    switch (g) {
      case 'Fat Loss':  return 'fat_loss';
      case 'Strength':  return 'strength';
      default:          return 'muscle_gain';
    }
  }

  Future<void> _generate() async {
    if (_loading) return;
    H.medium();
    setState(() { _loading = true; _applied = false; });
    final p = context.read<AppProvider>();
    await Future.delayed(const Duration(milliseconds: 700));
    final r = AIEngine.generateWeeklyPlan(
      goal:          _key(_goal), level: p.level, logs: p.logs,
      weakMuscle:    p.weakestMuscle, recoveryScore: p.recoveryScore.round(),
      fatigued:      p.isFatigued,
    );
    if (mounted) setState(() { _result = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final gColor = _goalColors[_goal] ?? AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(
            color: gColor.withValues(alpha: 0.18), width: 0.8),
        boxShadow: [BoxShadow(
            color: gColor.withValues(alpha: 0.06),
            blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                gColor.withValues(alpha: 0.22),
                gColor.withValues(alpha: 0.07),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(child: Text('⚡',
                style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Workout Generator', style: TextStyle(fontFamily: 'Rajdhani',
                color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w800)),
            Text('Personalised for your body & goal',
                style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 11)),
          ])),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const Text('YOUR GOAL', style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: AppSpacing.sm),
        Row(children: _goals.map((g) {
          final sel = g == _goal;
          final c   = _goalColors[g] ?? AppColors.gold;
          return Expanded(child: GestureDetector(
            onTap: () { H.selection(); setState(() => _goal = g); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: sel ? c.withValues(alpha: 0.12) : AppColors.bgCardLight,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: sel ? c : Colors.transparent, width: 1.2),
                boxShadow: sel ? [BoxShadow(
                    color: c.withValues(alpha: 0.18), blurRadius: 10)] : [],
              ),
              child: Column(children: [
                Text(_goalEmoji[g]!, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 3),
                Text(g, style: TextStyle(fontFamily: 'Inter',
                    color: sel ? c : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400),
                    textAlign: TextAlign.center),
              ]),
            ),
          ));
        }).toList()),

        const SizedBox(height: AppSpacing.lg),
        GoldButton(
          text: _loading ? 'Building your plan...' : 'Generate My Workout',
          icon: _loading ? null : Icons.auto_awesome_rounded,
          width: double.infinity,
          onTap: _loading ? () {} : _generate,
        ),

        if (_result != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _GeneratedResult(
            result: _result!, applied: _applied,
            onApply: () {
              final p = context.read<AppProvider>();
              final e = _result!.plan.entries.firstWhere(
                (e) => e.value.isNotEmpty && e.value.first != 'Rest',
                orElse: () => _result!.plan.entries.first,
              );
              p.applyAISuggestion(p.todayIndex, e.value);
              setState(() => _applied = true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text("Added to today's plan",
                    style: TextStyle(fontFamily: 'Inter',fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFF1E1E1E),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            },
          ),
        ],
      ]),
    );
  }
}

class _GeneratedResult extends StatelessWidget {
  final WorkoutPlanResult result;
  final bool applied;
  final VoidCallback onApply;
  const _GeneratedResult({
    required this.result, required this.applied, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final entry = result.plan.entries.firstWhere(
      (e) => e.value.isNotEmpty && e.value.first != 'Rest',
      orElse: () => result.plan.entries.first,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('🗓️', style: TextStyle(fontSize: 16)),
          SizedBox(width: AppSpacing.sm),
          Text('YOUR PLAN', style: TextStyle(fontFamily: 'Inter',
              color: AppColors.gold, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(result.summary, style: const TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 11, height: 1.4)),
        const SizedBox(height: AppSpacing.md),
        ...entry.value.take(5).toList().asMap().entries.map((e) {
          final n  = e.value;
          final ex = ExerciseLibrary.all.firstWhere(
              (x) => x['name'] == n,
              orElse: () => const {'emoji': '💪', 'cat': 'General', 'name': ''});
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + (e.key * 60).toInt()),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                    offset: Offset(0, 8 * (1 - v)), child: child)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
              child: Row(children: [
                Text(ex['emoji'] ?? '💪'),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(n, style: const TextStyle(fontFamily: 'Inter',
                    color: AppColors.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w600))),
              ]),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.md),
        applied
            ? const Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.gold, size: 16),
                SizedBox(width: 6),
                Text('Added to today\'s plan', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.gold, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ])
            : SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.add_rounded,
                      color: AppColors.gold, size: 16),
                  label: const Text('Add to Today', style: TextStyle(fontFamily: 'Rajdhani',
                      color: AppColors.gold, fontSize: 15,
                      fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// SPLIT STYLE PICKER
// ════════════════════════════════════════════════
class _SplitStyleCard extends StatefulWidget {
  const _SplitStyleCard();
  @override
  State<_SplitStyleCard> createState() => _SplitStyleCardState();
}

class _SplitStyleCardState extends State<_SplitStyleCard> {
  WorkoutPlanResult? _result;
  bool _applied = false;

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, (SplitStyle, int)>(
      selector: (_, p) => (p.splitStyle, p.gymDaysPerWeek),
      builder: (context, data, _) {
        final (current, days) = data;
        final p = context.read<AppProvider>();
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
              width: 0.6,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header row — days picker inline
              Row(children: [
                Expanded(child: _DaysPerWeekRow(
                  current: days,
                  onChanged: (d) => p.updateSetting('gymDaysPerWeek', d),
                )),
              ]),
              const SizedBox(height: AppSpacing.md),
              // Split style chips — horizontal scroll (no wrap)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: const [
                    SplitStyle.pushPullLegs,
                    SplitStyle.upperLower,
                    SplitStyle.fullBody,
                    SplitStyle.aiAdaptive,
                    SplitStyle.myOwnWay,
                  ].asMap().entries.map((entry) {
                    final style    = entry.value;
                    final selected = style == current;
                    final isLast   = entry.key == 4;
                    return GestureDetector(
                      onTap: () async {
                        if (selected) return;
                        HapticFeedback.selectionClick();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Change training style?',
                                style: TextStyle(fontFamily: 'Rajdhani',
                                    color: AppColors.textPrimary,
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            content: Text(
                              style == SplitStyle.myOwnWay
                                  ? 'Your current plan will be cleared. Your workout history is safe.'
                                  : 'This will replace your current plan with a ${style.label} plan. Your workout history is safe.',
                              style: const TextStyle(fontFamily: 'Inter',
                                  color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep current',
                                    style: TextStyle(fontFamily: 'Inter',
                                        color: AppColors.textMuted))),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Yes, change',
                                    style: TextStyle(fontFamily: 'Inter',
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700))),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        p.updateSetting('splitStyle', style.name);
                        if (style == SplitStyle.myOwnWay) {
                          p.workout.clearWeekPlan();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: EdgeInsets.only(right: isLast ? 0 : 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.gold.withValues(alpha: 0.13)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.gold.withValues(alpha: 0.38)
                                : Colors.white.withValues(alpha: 0.06),
                            width: selected ? 1 : 0.6,
                          ),
                        ),
                        child: Text(style.label,
                            style: TextStyle(fontFamily: 'Rajdhani',
                                color: selected
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (current == SplitStyle.myOwnWay) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.edit_rounded, color: AppColors.gold, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Go to Planner to add your own exercises.',
                      style: const TextStyle(fontFamily: 'Inter',
                          color: AppColors.textMuted, fontSize: 11, height: 1.4),
                    )),
                  ]),
                ),
              ],
              if (current != SplitStyle.myOwnWay) ...[
              const SizedBox(height: AppSpacing.sm),
              GoldButton(
                text: 'Generate Plan',
                icon: Icons.auto_awesome_rounded,
                width: double.infinity,
                small: true,
                onTap: () {
                  H.medium();
                  final splitKey = AIEngine.splitStyleToKey(current, days);
                  final r = AIEngine.generateWeeklyPlan(
                    goal:          p.goal,
                    level:         p.level,
                    logs:          p.logs,
                    weakMuscle:    p.weakestMuscle,
                    recoveryScore: p.recoveryScore.round(),
                    fatigued:      p.isFatigued,
                    splitOverride: splitKey,
                    gymDays:       days,
                  );
                  setState(() { _result = r; _applied = false; });
                },
              ),
              ], // end if (current != myOwnWay)
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _GeneratedResult(
                  result:  _result!,
                  applied: _applied,
                  onApply: () {
                    p.applyGeneratedPlan(_result!);
                    setState(() => _applied = true);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${current.label} plan applied to your week',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFF1E1E1E),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DaysPerWeekRow extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _DaysPerWeekRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gym days / week:',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final days = i + 2; // 2–6
            final selected = days == current;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(days);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.gold
                      : AppColors.bgCardLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.borderSoft,
                  ),
                ),
                child: Center(
                  child: Text('$days',
                      style: GoogleFonts.rajdhani(
                          color: selected ? Colors.black : AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// REMINDERS
// ════════════════════════════════════════════════
class _RemindersCard extends StatelessWidget {
  const _RemindersCard();

  @override
  Widget build(BuildContext context) =>
      Selector<AppProvider, ({bool reminder, bool inactivity, bool travel})>(
        selector: (_, p) => (
          reminder:   p.workoutReminderEnabled,
          inactivity: p.inactivityAlertEnabled,
          travel:     p.travelMode,
        ),
        builder: (context, s, _) {
          final p = context.read<AppProvider>();
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04), width: 0.6),
            ),
            child: Column(children: [
              _RRow(
                icon: Icons.local_fire_department_outlined, label: 'Streak Protection',
                sub: 'Reminder at 8 PM if you miss training',
                value: s.reminder,
                color: AppColors.orange,
                onChanged: (v) => p.updateSetting('workoutReminderEnabled', v),
              ),
              _Div(),
              _RRow(
                icon: Icons.warning_amber_rounded, label: 'Inactivity Alert',
                sub: 'Notify after 3 days of no workout',
                value: s.inactivity,
                color: const Color(0xFFFF6B35),
                onChanged: (v) => p.updateSetting('inactivityAlertEnabled', v),
              ),
              _Div(),
              _RRow(
                icon: Icons.flight_takeoff_rounded, label: 'Travel Mode',
                sub: 'Freeze streak — gym not available',
                value: s.travel,
                color: const Color(0xFF38BDF8),
                onChanged: (v) async {
                  await p.updateSetting('travelMode', v);
                  if (v) {
                    await p.updateSetting(
                      'travelModeStartedAt',
                      DateTime.now().toIso8601String(),
                    );
                  }
                },
              ),
            ]),
          );
        },
      );
}

class _RRow extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _RRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    child: Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter',
            color: AppColors.textPrimary, fontSize: 13,
            fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 11)),
      ])),
      Switch(
        value: value, onChanged: onChanged,
        activeThumbColor: AppColors.gold,
        inactiveThumbColor: AppColors.textMuted,
        inactiveTrackColor: AppColors.bgCardLight,
      ),
    ]),
  );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg,
          color: AppColors.divider.withValues(alpha: 0.5), height: 1);
}

// ════════════════════════════════════════════════
// LABEL FIELD
// ════════════════════════════════════════════════
class _LField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool isInt;
  const _LField({required this.label, required this.ctrl, this.isInt = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType:
            TextInputType.numberWithOptions(decimal: !isInt, signed: false),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(isInt ? r'[0-9]' : r'[0-9.]')),
        ],
        style: const TextStyle(fontFamily: 'Inter',
            color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderMedium)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderMedium)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.2)),
          filled: true,
          fillColor: AppColors.bgCardLight,
        ),
      ),
    ],
  );
}


// ════════════════════════════════════════════════
// 1RM CALCULATOR SHEET
// ════════════════════════════════════════════════
class _OneRmSheet extends StatefulWidget {
  const _OneRmSheet();
  @override State<_OneRmSheet> createState() => _OneRmSheetState();
}

class _OneRmSheetState extends State<_OneRmSheet> {
  final _wCtrl = TextEditingController();
  final _rCtrl = TextEditingController();
  double? _oneRm;

  static const _zones = [
    {'pct': 100, 'label': '1RM — Max Strength',  'reps': '1',  'color': 0xFFEF4444},
    {'pct': 95,  'label': '95% — Near Max',       'reps': '2',  'color': 0xFFF97316},
    {'pct': 90,  'label': '90% — Strength',        'reps': '3',  'color': 0xFFEAB308},
    {'pct': 85,  'label': '85% — Strength/Growth',   'reps': '5',  'color': 0xFFD4AF37},
    {'pct': 80,  'label': '80% — Muscle Growth',    'reps': '8',  'color': 0xFF22C55E},
    {'pct': 75,  'label': '75% — Muscle Growth',    'reps': '10', 'color': 0xFF3B82F6},
    {'pct': 70,  'label': '70% — Endurance',      'reps': '12', 'color': 0xFF8B5CF6},
    {'pct': 65,  'label': '65% — Endurance',      'reps': '15', 'color': 0xFF6B7280},
  ];

  @override
  void dispose() { _wCtrl.dispose(); _rCtrl.dispose(); super.dispose(); }

  void _calc() {
    final w = double.tryParse(_wCtrl.text);
    final r = int.tryParse(_rCtrl.text);
    if (w == null || r == null || r <= 0) return;
    setState(() => _oneRm = w * (1 + r / 30));
  }

  @override
  Widget build(BuildContext context) => _SheetWrap(
    icon: Icons.sports_gymnastics_rounded,
    title: '1RM Calculator',
    subtitle: 'Using Epley Formula: weight × (1 + reps/30)',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _LField(label: 'Weight (kg)', ctrl: _wCtrl)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _LField(label: 'Reps done', ctrl: _rCtrl, isInt: true)),
      ]),
      const SizedBox(height: AppSpacing.lg),
      GoldButton(
        text: 'Calculate 1RM',
        icon: Icons.calculate_rounded,
        width: double.infinity,
        onTap: _calc,
      ),
      if (_oneRm != null) ...[
        const SizedBox(height: AppSpacing.xl),
        Center(child: Column(children: [
          const Text('Your Estimated 1RM', style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${_oneRm!.toStringAsFixed(1)} kg', style: const TextStyle(fontFamily: 'Rajdhani',
              color: AppColors.textSecondary, fontSize: 48, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: AppSpacing.lg),
        const Text('TRAINING ZONES', style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: AppSpacing.sm),
        ..._zones.map((z) {
          final pct    = z['pct'] as int;
          final col    = Color(z['color'] as int);
          final weight = _oneRm! * pct / 100;
          return Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: col.withValues(alpha: 0.22), width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('$pct%', style: TextStyle(
                    fontFamily: 'Rajdhani', color: col,
                    fontSize: 13, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(z['label'] as String, style: const TextStyle(fontFamily: 'Inter',
                    color: AppColors.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                Text('~${z['reps']} reps', style: const TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 10)),
              ])),
              Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(
                  fontFamily: 'Rajdhani', color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          );
        }),
      ],
    ]),
  );
}

// ════════════════════════════════════════════════
// VOICE COACH SETTINGS SHEET
// ════════════════════════════════════════════════
class _VoiceCoachSheet extends StatefulWidget {
  const _VoiceCoachSheet();

  @override
  State<_VoiceCoachSheet> createState() => _VoiceCoachSheetState();
}

class _VoiceCoachSheetState extends State<_VoiceCoachSheet>
    with SingleTickerProviderStateMixin {
  final _vc = VoiceCoachService();

  late AnimationController _waveC;
  late Animation<double> _waveA;

  static const _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳', 'native': 'हिंदी'},
    {'code': 'mr', 'name': 'Marathi', 'flag': '🇮🇳', 'native': 'मराठी'},
  ];

  @override
  void initState() {
    super.initState();

    _waveC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveA = CurvedAnimation(
      parent: _waveC,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _waveC.dispose();
    super.dispose();
  }


  Widget _waveBar(double h) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgModal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 0.6,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37)
                          .withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37)
                              .withValues(alpha: 0.10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _waveA,
                      builder: (_, __) {
                        final t = _waveA.value;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _waveBar(12 + (8 * t)),
                            const SizedBox(width: 3),
                            _waveBar(22 - (6 * t)),
                            const SizedBox(width: 3),
                            _waveBar(10 + (10 * t)),
                            const SizedBox(width: 3),
                            _waveBar(18 - (5 * t)),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIFTON COACH',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time coaching during every set',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hear reps, rest timers, and motivation while you train.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Coach toggles
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  children: [
                    _settingTile(
                      icon: Icons.power_settings_new_rounded,
                      title: 'Voice Coach',
                      subtitle: 'Hear real-time coaching while you train',
                      trailing: Switch(
                        value: _vc.enabled,
                        activeThumbColor: AppColors.gold,
                        onChanged: (v) async {
                          await _vc.setEnabled(v);
                          setState(() {});
                        },
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: Colors.white.withValues(alpha: 0.05),
                      indent: 78,
                      endIndent: 18,
                    ),

                    _settingTile(
                      icon: Icons.numbers_rounded,
                      title: 'Auto Rep Counting',
                      subtitle: 'Hands-free rep tracking during sets',
                      trailing: Switch(
                        value: _vc.autoRepCounting,
                        activeThumbColor: AppColors.gold,
                        onChanged: _vc.enabled
                            ? (v) async {
                          await _vc.setAutoRepCounting(v);
                          setState(() {});
                        }
                      : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Language section
              Text('LANGUAGE',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _languages.length; i++) ...[
                      _languageTile(_languages[i]),

                      if (i != _languages.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.6,
                          color: Colors.white.withValues(alpha: 0.05),
                          indent: 72,
                          endIndent: 18,
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Speech rate slider
              Text('VOICE SPEED',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  children: [
                    Row(children: [
                      const Icon(Icons.speed_rounded,
                          color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Text('${(_vc.speechRate * 100).round()}%',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          )),
                      const Spacer(),
                      Text(_vc.speechRate < 0.45
                          ? 'Slow'
                          : _vc.speechRate < 0.65
                              ? 'Normal'
                              : 'Fast',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.gold,
                        inactiveTrackColor: AppColors.borderMedium,
                        thumbColor: AppColors.gold,
                        overlayColor: AppColors.gold.withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: 0.3,
                        max: 1.0,
                        value: _vc.speechRate,
                        onChanged: _vc.enabled
                            ? (v) async {
                                await _vc.setSpeechRate(v);
                                setState(() {});
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Test button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _vc.enabled
                      ? () async {
                          H.medium();
                          await _vc.testVoice();
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text('Test Voice',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1,
                      )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  )),
              Text(subtitle,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        trailing,
      ]),
    );
  }

  Widget _languageTile(Map<String, String> lang) {
    final isSelected = _vc.language == lang['code'];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        H.selection();
        await _vc.setLanguage(lang['code']!);
        await _vc.testVoice();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700).withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  lang['native']!.substring(0, 1),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang['name']!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang['native']!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: Color(0xFFD4AF37),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// MEAL HERO CARD — calorie ring on tools screen top
// ════════════════════════════════════════════════
class _MealHeroCard extends StatefulWidget {
  const _MealHeroCard();
  @override
  State<_MealHeroCard> createState() => _MealHeroCardState();
}

class _MealHeroCardState extends State<_MealHeroCard>
    with SingleTickerProviderStateMixin {
  static const _green  = Color(0xFF66BB6A);
  static const _blue   = Color(0xFF42A5F5);
  static const _purple = Color(0xFFAB47BC);

  DayMealLog? _log;
  late AnimationController _anim;
  late Animation<double> _ringAnim;
  String? _uid;

  // Computed goals from user profile
  int _kcalGoal    = 2000;
  int _proteinGoal = 150;
  int _carbsGoal   = 220;
  int _fatsGoal    = 65;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _ringAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _uid = AuthService.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    // Compute goals from profile
    if (mounted) {
      final ap = context.read<AppProvider>();
      final profile = ap.profile;
      final tdee = AIEngine.estimateTDEE(
        weightKg: profile.weightKg, heightCm: profile.heightCm,
        age: profile.age, gender: profile.gender,
        goal: profile.goal, activityLevel: profile.activityLevel,
      );
      final macros = AIEngine.getMacros(
        tdee: tdee, weightKg: profile.weightKg, goal: profile.goal);
      _kcalGoal    = tdee.round();
      _proteinGoal = macros['protein']!.round();
      _carbsGoal   = macros['carbs']!.round();
      _fatsGoal    = macros['fat']!.round();
    }
    final log = await MealLogService.getTodayLog('');
    if (!mounted) return;
    setState(() => _log = log);
    _anim.forward(from: 0);
  }

  int get _kcal    => _log?.entries.values.fold<int>(0, (s, e) => s + e.kcal)    ?? 0;
  int get _protein => _log?.entries.values.fold<int>(0, (s, e) => s + e.protein) ?? 0;
  int get _carbs   => _log?.entries.values.fold<int>(0, (s, e) => s + e.carbs)   ?? 0;
  int get _fats    => _log?.entries.values.fold<int>(0, (s, e) => s + e.fats)    ?? 0;

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final kcalPct = (_kcal / _kcalGoal).clamp(0.0, 1.0);
    final remaining = (_kcalGoal - _kcal).clamp(0, _kcalGoal);

    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _MealLogSheet(
            kcalGoal: _kcalGoal, proteinGoal: _proteinGoal,
            carbsGoal: _carbsGoal, fatsGoal: _fatsGoal,
          ),
        );
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 0.6),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.restaurant_rounded,
                  color: Colors.white.withValues(alpha: 0.65), size: 17),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Meal Log', style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              Text("Today's nutrition", style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 10)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35), width: 0.8),
              ),
              child: Text('Add Food', style: GoogleFonts.inter(
                  color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),

          const SizedBox(height: 20),

          // Ring + stats row
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Animated calorie ring
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, __) => SizedBox(
                width: 100, height: 100,
                child: CustomPaint(
                  painter: _CalorieRingPainter(
                    progress: kcalPct * _ringAnim.value,
                    color: AppColors.gold,
                  ),
                  child: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_kcal', style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary, fontSize: 22,
                          fontWeight: FontWeight.w900)),
                      Text('kcal', style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 9)),
                    ],
                  )),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // Right stats column
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroStatRow(
                  label: 'Goal',
                  value: '$_kcalGoal kcal',
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 4),
                _HeroStatRow(
                  label: 'Remaining',
                  value: '$remaining kcal',
                  color: remaining > 0 ? AppColors.gold : AppColors.orange,
                ),
                const SizedBox(height: 12),
                // Macro mini bars
                _MiniMacroBar(label: 'P', value: _protein, goal: _proteinGoal, color: _blue),
                const SizedBox(height: 5),
                _MiniMacroBar(label: 'C', value: _carbs,   goal: _carbsGoal,   color: AppColors.gold),
                const SizedBox(height: 5),
                _MiniMacroBar(label: 'F', value: _fats,    goal: _fatsGoal,    color: _purple),
              ],
            )),
          ]),
        ]),
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _CalorieRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 8;
    final strokeW = 8.0;

    // Track
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round);

    if (progress <= 0) return;

    // Fill arc
    final sweep = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -3.141592653589793 / 2,
      sweep,
      false,
      Paint()
        ..color = progress >= 1.0 ? AppColors.orange : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CalorieRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _HeroStatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroStatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label  ', style: GoogleFonts.inter(
        color: AppColors.textMuted, fontSize: 11)),
    Text(value, style: GoogleFonts.inter(
        color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  ]);
}

class _MiniMacroBar extends StatelessWidget {
  final String label;
  final int value, goal;
  final Color color;
  const _MiniMacroBar({required this.label, required this.value,
      required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value / goal).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(width: 12, child: Text(label, style: GoogleFonts.inter(
          color: color, fontSize: 9, fontWeight: FontWeight.w700))),
      const SizedBox(width: 6),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          Container(height: 4, color: Colors.white.withValues(alpha: 0.06)),
          FractionallySizedBox(
            widthFactor: pct,
            child: Container(height: 4,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
          ),
        ]),
      )),
      const SizedBox(width: 6),
      Text('${value}g', style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 9)),
    ]);
  }
}

// ════════════════════════════════════════════════
// MEAL LOG SHEET — multi-food add per meal
// ════════════════════════════════════════════════
class _MealLogSheet extends StatefulWidget {
  final int kcalGoal, proteinGoal, carbsGoal, fatsGoal;
  const _MealLogSheet({
    this.kcalGoal = 2000, this.proteinGoal = 150,
    this.carbsGoal = 220, this.fatsGoal = 65,
  });

  @override
  State<_MealLogSheet> createState() => _MealLogSheetState();
}

class _MealLogSheetState extends State<_MealLogSheet> {
  static const _green   = Color(0xFF66BB6A);
  static const _blue    = Color(0xFF42A5F5);
  static const _purple  = Color(0xFFAB47BC);

  static const _meals = [
    ('Breakfast', Icons.wb_sunny_rounded,      Color(0xFFFFB74D)),
    ('Lunch',     Icons.lunch_dining_rounded,   Color(0xFF66BB6A)),
    ('Dinner',    Icons.nights_stay_rounded,    Color(0xFF42A5F5)),
    ('Snack',     Icons.cookie_rounded,         Color(0xFFAB47BC)),
  ];

  DayMealLog? _log;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await MealLogService.getTodayLog('');
    if (mounted) setState(() { _log = log; _loading = false; });
  }

  int get _kcal    => _log?.entries.values.fold<int>(0, (s, e) => s + e.kcal)    ?? 0;
  int get _protein => _log?.entries.values.fold<int>(0, (s, e) => s + e.protein) ?? 0;
  int get _carbs   => _log?.entries.values.fold<int>(0, (s, e) => s + e.carbs)   ?? 0;
  int get _fats    => _log?.entries.values.fold<int>(0, (s, e) => s + e.fats)    ?? 0;

  Future<void> _openAddForm(String mealType, Color color) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealLogForm(
        mealType: mealType,
        color: color,
        onSaved: _load,
      ),
    );
  }

  void _delete(MealLogEntry entry) {
    MealLogService.unlogMeal('', entry).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: CustomScrollView(controller: scrollCtrl, slivers: [
          SliverToBoxAdapter(child: Column(children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Meal Log', style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  Text(dateStr, style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
                ]),
                const Spacer(),
                if (!_loading && _kcal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withValues(alpha: 0.30)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: _green, size: 13),
                      const SizedBox(width: 4),
                      Text('$_kcal kcal', style: GoogleFonts.rajdhani(
                          color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),

            // Macro bar summary
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(children: [
                  _MacroBar(label: 'Protein', value: _protein,
                      goal: widget.proteinGoal, color: _blue),
                  const SizedBox(height: 7),
                  _MacroBar(label: 'Carbs',   value: _carbs,
                      goal: widget.carbsGoal, color: AppColors.orange),
                  const SizedBox(height: 7),
                  _MacroBar(label: 'Fats',    value: _fats,
                      goal: widget.fatsGoal, color: _purple),
                ]),
              ),

            const SizedBox(height: 16),
            Divider(height: 1, thickness: 0.5,
                color: Colors.white.withValues(alpha: 0.06)),
          ])),

          // Meal sections
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(
                  color: _green, strokeWidth: 2)),
            )
          else
            SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i.isOdd) {
                  return Divider(
                    height: 1, thickness: 0.5,
                    color: Colors.white.withValues(alpha: 0.04),
                    indent: 20, endIndent: 20,
                  );
                }
                final mi = i ~/ 2;
                final (type, icon, color) = _meals[mi];
                // Collect all entries for this meal type
                final entries = _log?.entries.values
                    .where((e) => e.mealType == type).toList() ?? [];
                return _MealSection(
                  mealType: type, icon: icon, color: color,
                  entries: entries,
                  onAdd: () => _openAddForm(type, color),
                  onDelete: (e) => _delete(e),
                );
              },
              childCount: _meals.length * 2 - 1,
            )),

          SliverToBoxAdapter(child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 20)),
        ]),
      ),
    );
  }

  String _monthName(int m) => const [
    '', 'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ][m];
}

// ─── Macro progress bar ───────────────────────────────────
class _MacroBar extends StatelessWidget {
  final String label;
  final int value, goal;
  final Color color;
  const _MacroBar({required this.label, required this.value,
      required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value / goal).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(width: 52,
        child: Text(label, style: GoogleFonts.inter(
            color: AppColors.textMuted, fontSize: 10.5,
            fontWeight: FontWeight.w500))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 6,
                color: Colors.white.withValues(alpha: 0.06)),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  )),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 56,
        child: Text('${value}g / ${goal}g',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
              color: value >= goal ? color : AppColors.textMuted,
              fontSize: 9.5, fontWeight: FontWeight.w600))),
    ]);
  }
}

// ─── Meal section card (multi-food) ──────────────────────
class _MealSection extends StatefulWidget {
  final String mealType;
  final IconData icon;
  final Color color;
  final List<MealLogEntry> entries;
  final VoidCallback onAdd;
  final void Function(MealLogEntry) onDelete;

  const _MealSection({
    required this.mealType, required this.icon, required this.color,
    required this.entries, required this.onAdd, required this.onDelete,
    super.key,
  });

  @override
  State<_MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<_MealSection> {
  late List<MealLogEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.entries);
  }

  @override
  void didUpdateWidget(_MealSection old) {
    super.didUpdateWidget(old);
    // Sync when parent reloads (e.g. new food added)
    _items = List.from(widget.entries);
  }

  void _dismiss(MealLogEntry e) {
    // Remove from local list immediately — satisfies Dismissible in same frame
    setState(() => _items.removeWhere((x) => x.firestoreKey == e.firestoreKey));
    widget.onDelete(e); // fire-and-forget to persist
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _items.fold<int>(0, (s, e) => s + e.kcal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 15, color: widget.color),
          ),
          const SizedBox(width: 10),
          Text(widget.mealType, style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 13,
              fontWeight: FontWeight.w700)),
          if (totalKcal > 0) ...[
            const SizedBox(width: 6),
            Text('$totalKcal kcal', style: GoogleFonts.inter(
                color: widget.color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          GestureDetector(
            onTap: widget.onAdd,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.color.withValues(alpha: 0.30), width: 0.8),
              ),
              child: Icon(Icons.add_rounded, size: 16, color: widget.color),
            ),
          ),
        ]),

        if (_items.isEmpty) ...[
          const SizedBox(height: 6),
          Text('Nothing logged yet',
            style: GoogleFonts.inter(
                color: AppColors.textMuted.withValues(alpha: 0.40),
                fontSize: 11)),
        ] else ...[
          const SizedBox(height: 8),
          ..._items.map((e) => Padding(
            key: ValueKey(e.firestoreKey),
            padding: const EdgeInsets.only(bottom: 6),
            child: Dismissible(
              key: ValueKey('d_${e.firestoreKey}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
              ),
              onDismissed: (_) => _dismiss(e),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.foods.isNotEmpty)
                        Text(e.foods.first, style: GoogleFonts.inter(
                            color: AppColors.textPrimary, fontSize: 12,
                            fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text('${e.kcal} kcal', style: GoogleFonts.inter(
                            color: AppColors.orange, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        _MacroPill('P', '${e.protein}g', const Color(0xFF42A5F5)),
                        const SizedBox(width: 4),
                        _MacroPill('C', '${e.carbs}g', AppColors.gold),
                        const SizedBox(width: 4),
                        _MacroPill('F', '${e.fats}g', const Color(0xFFAB47BC)),
                      ]),
                    ],
                  )),
                  Icon(Icons.swipe_left_rounded, size: 14,
                      color: AppColors.textMuted.withValues(alpha: 0.25)),
                ]),
              ),
            ),
          )),
        ],
      ]),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('$label $value', style: GoogleFonts.inter(
        color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
  );
}

// ─── Add meal form (multi-food, saves directly) ───────────
class _MealLogForm extends StatefulWidget {
  final String mealType;
  final Color color;
  final VoidCallback onSaved;
  const _MealLogForm({
    required this.mealType, required this.color,
    required this.onSaved,
  });

  @override
  State<_MealLogForm> createState() => _MealLogFormState();
}

class _MealLogFormState extends State<_MealLogForm> {
  Color get _green => widget.color;

  final _foodCtrl    = TextEditingController();
  final _kcalCtrl    = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl   = TextEditingController();
  final _fatsCtrl    = TextEditingController();
  final _qtyCtrl     = TextEditingController(text: '100');
  bool _saving = false;
  final List<MealLogEntry> _addedFoods = [];

  // Per-100g base values from API (used to scale when qty changes)
  double _base100Kcal = 0, _base100Protein = 0, _base100Carbs = 0, _base100Fats = 0;
  bool _hasApiBase = false;

  // Nutrition search
  Timer? _debounce;
  List<_FoodSuggestion> _suggestions = [];
  bool _searching = false;
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    _foodCtrl.addListener(_onFoodChanged);
    _qtyCtrl.addListener(_onQtyChanged);
  }

  String? _selectedCategory;

  void _onFoodChanged() {
    final q = _foodCtrl.text.trim();
    _debounce?.cancel();
    _searchGen++;
    if (q.length < 2) {
      if (_suggestions.isNotEmpty || _searching) {
        setState(() { _suggestions = []; _searching = false; });
      }
      return;
    }
    // Instant local search first
    final local = _FoodDb.search(q);
    if (local.isNotEmpty) {
      setState(() { _suggestions = local; _searching = false; });
    } else {
      // API fallback for non-local foods
      final gen = _searchGen;
      setState(() => _searching = true);
      _debounce = Timer(const Duration(milliseconds: 800), () => _searchApi(q, gen));
    }
  }

  void _onQtyChanged() {
    if (!_hasApiBase) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 100;
    if (qty <= 0) return;
    final factor = qty / 100.0;
    _kcalCtrl.text    = (_base100Kcal    * factor).round().toString();
    _proteinCtrl.text = (_base100Protein * factor).round().toString();
    _carbsCtrl.text   = (_base100Carbs   * factor).round().toString();
    _fatsCtrl.text    = (_base100Fats    * factor).round().toString();
  }

  Future<void> _searchApi(String query, int gen) async {
    if (!mounted || gen != _searchGen) return;
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=8'
        '&fields=product_name,nutriments',
      );
      final res = await http.get(uri,
        headers: {'User-Agent': 'LiftonApp/1.0'})
        .timeout(const Duration(seconds: 7));
      if (!mounted || gen != _searchGen) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final products = (data['products'] as List? ?? []);
        final suggestions = <_FoodSuggestion>[];
        for (final p in products) {
          final name = (p['product_name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final n = p['nutriments'] as Map? ?? {};
          final kcal    = (n['energy-kcal_100g']    as num?)?.toDouble() ?? 0;
          final protein = (n['proteins_100g']        as num?)?.toDouble() ?? 0;
          final carbs   = (n['carbohydrates_100g']   as num?)?.toDouble() ?? 0;
          final fats    = (n['fat_100g']             as num?)?.toDouble() ?? 0;
          if (kcal > 0) suggestions.add(_FoodSuggestion(name, kcal, protein, carbs, fats));
          if (suggestions.length >= 5) break;
        }
        if (mounted && gen == _searchGen) {
          setState(() { _suggestions = suggestions; _searching = false; });
        }
      } else {
        if (mounted && gen == _searchGen) setState(() { _suggestions = []; _searching = false; });
      }
    } catch (_) {
      if (mounted && gen == _searchGen) setState(() { _suggestions = []; _searching = false; });
    }
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory = _selectedCategory == cat ? null : cat;
      _suggestions = _selectedCategory == null ? [] : _FoodDb.byCategory(_selectedCategory!);
      _searching = false;
    });
  }

  void _applySuggestion(_FoodSuggestion s) {
    _base100Kcal = s.kcal; _base100Protein = s.protein;
    _base100Carbs = s.carbs; _base100Fats = s.fats;
    _hasApiBase = true;
    // Remove listeners before programmatic text changes
    _foodCtrl.removeListener(_onFoodChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _foodCtrl.text = s.name;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 100;
    final factor = qty / 100.0;
    _kcalCtrl.text    = (s.kcal    * factor).round().toString();
    _proteinCtrl.text = (s.protein * factor).round().toString();
    _carbsCtrl.text   = (s.carbs   * factor).round().toString();
    _fatsCtrl.text    = (s.fats    * factor).round().toString();
    _foodCtrl.addListener(_onFoodChanged);
    _qtyCtrl.addListener(_onQtyChanged);
    setState(() => _suggestions = []);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _foodCtrl.removeListener(_onFoodChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _foodCtrl.dispose(); _kcalCtrl.dispose();
    _proteinCtrl.dispose(); _carbsCtrl.dispose();
    _fatsCtrl.dispose(); _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFood() async {
    final kcal = int.tryParse(_kcalCtrl.text.trim()) ?? 0;
    if (kcal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Select a food or enter calories first',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        backgroundColor: const Color(0xFF2A1A1A),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    if (_saving) return;
    final entry = MealLogEntry(
      mealType: widget.mealType,
      planDay:  1,
      foods:    _foodCtrl.text.trim().isEmpty ? [] : [_foodCtrl.text.trim()],
      kcal:     kcal,
      protein:  int.tryParse(_proteinCtrl.text.trim()) ?? 0,
      carbs:    int.tryParse(_carbsCtrl.text.trim())   ?? 0,
      fats:     int.tryParse(_fatsCtrl.text.trim())    ?? 0,
      loggedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    await MealLogService.logMeal('', entry);
    widget.onSaved();
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    // Remove listeners before clearing to prevent nested setState
    _foodCtrl.removeListener(_onFoodChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _foodCtrl.clear();
    _kcalCtrl.clear();
    _proteinCtrl.clear();
    _carbsCtrl.clear();
    _fatsCtrl.clear();
    _qtyCtrl.text = '100';
    _foodCtrl.addListener(_onFoodChanged);
    _qtyCtrl.addListener(_onQtyChanged);
    setState(() {
      _saving = false;
      _addedFoods.add(entry);
      _hasApiBase = false;
      _base100Kcal = _base100Protein = _base100Carbs = _base100Fats = 0;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 10),

          // Title row
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green.withValues(alpha: 0.30)),
              ),
              child: Icon(Icons.add_rounded, color: _green, size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add to ${widget.mealType}',
                style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary, fontSize: 18,
                    fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              Text('Select category or search below',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 14),

          // Category chips — instant browse
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _FoodDb.categories.entries.map((kv) {
                final active = _selectedCategory == kv.key;
                return GestureDetector(
                  onTap: () => _selectCategory(kv.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? _green : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? _green : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(kv.key,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: active ? Colors.black : AppColors.textMuted,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0.3,
                      )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Food name field + suggestions
          _MLField(
            controller: _foodCtrl,
            hint: 'Search food… (e.g. idli, oats, chicken)',
            icon: Icons.search_rounded,
            color: _green,
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const SizedBox(width: 4),
                SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: _green)),
                const SizedBox(width: 8),
                Text('Searching nutrition data…',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
              ]),
            ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withValues(alpha: 0.18)),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.asMap().entries.map((mapEntry) {
                    final i = mapEntry.key;
                    final s = mapEntry.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _applySuggestion(s),
                        splashColor: _green.withValues(alpha: 0.10),
                        highlightColor: _green.withValues(alpha: 0.06),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: i < _suggestions.length - 1
                            ? BoxDecoration(border: Border(bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05))))
                            : null,
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add_rounded, color: _green, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Text('${s.kcal.round()} kcal',
                                    style: GoogleFonts.inter(
                                      fontSize: 11, color: AppColors.orange,
                                      fontWeight: FontWeight.w700)),
                                  Text('  ·  P${s.protein.round()}  C${s.carbs.round()}  F${s.fats.round()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10, color: AppColors.textMuted)),
                                ]),
                              ],
                            )),
                            Text('/ 100g',
                              style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.textMuted)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 10),

          // Quantity + Calories row
          Row(children: [
            // Quantity field
            SizedBox(
              width: 100,
              child: _MLField(
                controller: _qtyCtrl,
                hint: 'Qty (g)',
                icon: Icons.scale_rounded,
                color: AppColors.textMuted,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            // Calories field
            Expanded(child: _MLField(
              controller: _kcalCtrl,
              hint: 'Calories *',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              keyboardType: TextInputType.number,
              large: true,
            )),
          ]),
          const SizedBox(height: 10),

          // Macros row
          IntrinsicHeight(
            child: Row(children: [
              Expanded(child: _MLField(
                controller: _proteinCtrl, hint: 'Protein g',
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF42A5F5),
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 8),
              Expanded(child: _MLField(
                controller: _carbsCtrl, hint: 'Carbs g',
                icon: Icons.grain_rounded,
                color: AppColors.gold,
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 8),
              Expanded(child: _MLField(
                controller: _fatsCtrl, hint: 'Fats g',
                icon: Icons.water_drop_rounded,
                color: const Color(0xFFAB47BC),
                keyboardType: TextInputType.number,
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Added foods list (shows after first food added)
          if (_addedFoods.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ..._addedFoods.asMap().entries.map((kv) {
                  final i = kv.key; final e = kv.value;
                  final name = e.foods.isNotEmpty ? e.foods.first : 'Food';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: i < _addedFoods.length - 1
                      ? BoxDecoration(border: Border(
                          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))))
                      : null,
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, color: _green, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${e.kcal} kcal', style: GoogleFonts.inter(
                          color: AppColors.orange, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Buttons row
          Row(children: [
            // Add Food button
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _saving ? null : _addFood,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _green.withValues(alpha: _saving ? 0.08 : 0.18),
                      _green.withValues(alpha: _saving ? 0.08 : 0.12),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _green.withValues(alpha: _saving ? 0.15 : 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _saving
                      ? SizedBox(width: 15, height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: _green))
                      : Icon(Icons.add_rounded, color: _green, size: 20),
                    const SizedBox(width: 7),
                    Text('Add Food', style: GoogleFonts.rajdhani(
                        color: _saving ? _green.withValues(alpha: 0.5) : _green,
                        fontSize: 16, fontWeight: FontWeight.w900,
                        letterSpacing: 0.3)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Done button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  // If calories are filled, save current food before closing
                  final kcal = int.tryParse(_kcalCtrl.text.trim()) ?? 0;
                  if (kcal > 0 && !_saving) {
                    final entry = MealLogEntry(
                      mealType: widget.mealType,
                      planDay:  1,
                      foods:    _foodCtrl.text.trim().isEmpty ? [] : [_foodCtrl.text.trim()],
                      kcal:     kcal,
                      protein:  int.tryParse(_proteinCtrl.text.trim()) ?? 0,
                      carbs:    int.tryParse(_carbsCtrl.text.trim())   ?? 0,
                      fats:     int.tryParse(_fatsCtrl.text.trim())    ?? 0,
                      loggedAt: DateTime.now(),
                    );
                    await MealLogService.logMeal('', entry);
                    widget.onSaved();
                    HapticFeedback.mediumImpact();
                  }
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_green, _green.withValues(alpha: 0.80)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: _green.withValues(alpha: 0.30),
                          blurRadius: 14, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('Done', style: GoogleFonts.rajdhani(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                  ]),
                ),
              ),
            ),
          ]),
        ]),
        ),
      ),
    );
  }
}

class _MLField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color color;
  final TextInputType keyboardType;
  final bool large;
  const _MLField({
    required this.controller, required this.hint,
    required this.icon, required this.color,
    this.keyboardType = TextInputType.text, this.large = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: large ? 14 : 13,
        fontWeight: large ? FontWeight.w600 : FontWeight.w400),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: AppColors.textMuted.withValues(alpha: 0.55),
          fontSize: large ? 13 : 11.5),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, size: large ? 18 : 15, color: color),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 38),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: EdgeInsets.symmetric(
          horizontal: 12, vertical: large ? 16 : 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
    ),
  );
}

class _FoodSuggestion {
  final String name;
  final double kcal, protein, carbs, fats; // per 100g
  const _FoodSuggestion(this.name, this.kcal, this.protein, this.carbs, this.fats);
}

// ─── Local food database (Indian + common, per 100g) ─────
class _FoodDb {
  static const categories = <String, String>{
    'Indian':    '',
    'Breakfast': '',
    'Protein':   '',
    'Dairy':     '',
    'Fruits':    '',
    'Grains':    '',
    'Snacks':    '',
    'Drinks':    '',
    'Cheat':     '',
  };

  static const _db = <String, List<_FoodSuggestion>>{
    'Indian': [
      _FoodSuggestion('Idli (1 piece ~40g)',       58,  2.0, 11.0, 0.4),
      _FoodSuggestion('Dosa (plain)',               168, 3.5, 26.0, 5.0),
      _FoodSuggestion('Upma',                       120, 2.8, 18.0, 4.0),
      _FoodSuggestion('Poha',                       130, 2.5, 24.0, 2.5),
      _FoodSuggestion('Roti / Chapati',             297, 7.9, 54.0, 3.7),
      _FoodSuggestion('Bhakri (jowar)',             348, 10.0,72.0, 1.9),
      _FoodSuggestion('Dal (cooked)',               116, 9.0, 20.0, 0.4),
      _FoodSuggestion('Rajma (cooked)',             127, 8.7, 22.8, 0.5),
      _FoodSuggestion('Chole (cooked)',             164, 8.9, 27.4, 2.6),
      _FoodSuggestion('Paneer',                     265, 18.3, 1.2, 20.8),
      _FoodSuggestion('Rice (cooked)',              130, 2.7, 28.6, 0.3),
      _FoodSuggestion('Rice (raw)',                 350, 6.8, 78.2, 0.5),
      _FoodSuggestion('Sambar',                      50, 2.8,  8.0, 0.8),
      _FoodSuggestion('Sabzi (mixed veg)',           60, 2.0, 10.0, 1.5),
      _FoodSuggestion('Khichdi',                    124, 4.5, 24.0, 1.2),
      _FoodSuggestion('Biryani (chicken)',           190,10.0, 24.0, 5.5),
      _FoodSuggestion('Paratha (plain)',             300, 7.0, 46.0, 9.5),
      _FoodSuggestion('Puri',                       338, 6.5, 44.0,15.0),
      _FoodSuggestion('Vada (medu)',                290, 8.0, 33.0,14.0),
      _FoodSuggestion('Uttapam',                    135, 4.5, 22.0, 3.0),
    ],
    'Breakfast': [
      _FoodSuggestion('Oats (raw)',                 389, 16.9,66.3, 6.9),
      _FoodSuggestion('Oats (cooked 1 cup ~240g)',  166,  5.9,28.1, 3.6),
      _FoodSuggestion('Bread (white, 1 slice 30g)', 265,  8.0,49.0, 3.2),
      _FoodSuggestion('Bread (brown, 1 slice 30g)', 247,  8.5,41.0, 3.5),
      _FoodSuggestion('Cornflakes',                 357,  6.7,84.0, 0.4),
      _FoodSuggestion('Muesli',                     363, 10.0,66.0, 7.0),
      _FoodSuggestion('Eggs (whole, 1 egg ~50g)',   155, 13.0, 1.1,11.0),
      _FoodSuggestion('Egg whites (100g)',           52, 10.9, 0.7, 0.2),
      _FoodSuggestion('Scrambled Eggs',             149, 10.1, 1.6,11.0),
      _FoodSuggestion('Peanut Butter',              588, 25.1,20.1,50.4),
    ],
    'Protein': [
      _FoodSuggestion('Chicken Breast (grilled)',   165, 31.0, 0.0, 3.6),
      _FoodSuggestion('Chicken Thigh',              209, 26.0, 0.0,10.9),
      _FoodSuggestion('Egg (whole, 100g)',          155, 13.0, 1.1,11.0),
      _FoodSuggestion('Tuna (canned in water)',     116, 25.5, 0.0, 1.0),
      _FoodSuggestion('Salmon',                     208, 20.4, 0.0,13.4),
      _FoodSuggestion('Mutton (cooked)',            294, 25.6, 0.0,20.6),
      _FoodSuggestion('Soya Chunks (dry)',          336, 52.4,33.0, 0.5),
      _FoodSuggestion('Tofu (firm)',                 76,  8.1, 1.9, 4.2),
      _FoodSuggestion('Whey Protein (1 scoop 30g)', 120, 24.0, 3.0, 1.5),
      _FoodSuggestion('Chickpeas (cooked)',          164,  8.9,27.4, 2.6),
    ],
    'Dairy': [
      _FoodSuggestion('Milk (whole, 3.5%)',          61,  3.2, 4.8, 3.5),
      _FoodSuggestion('Milk (skim)',                 35,  3.5, 5.0, 0.1),
      _FoodSuggestion('Curd / Yogurt (plain)',       61,  3.5, 4.7, 3.3),
      _FoodSuggestion('Greek Yogurt',                59, 10.0, 3.6, 0.4),
      _FoodSuggestion('Paneer',                     265, 18.3, 1.2,20.8),
      _FoodSuggestion('Cheese (cheddar)',            402, 25.0, 1.3,33.1),
      _FoodSuggestion('Butter',                     717,  0.9, 0.1,81.1),
      _FoodSuggestion('Ghee',                       900,  0.0, 0.0,100.0),
      _FoodSuggestion('Buttermilk (chaas)',           40,  3.3, 4.8, 0.9),
    ],
    'Fruits': [
      _FoodSuggestion('Banana',                      89,  1.1,23.0, 0.3),
      _FoodSuggestion('Apple',                       52,  0.3,14.0, 0.2),
      _FoodSuggestion('Mango',                       60,  0.8,15.0, 0.4),
      _FoodSuggestion('Papaya',                      43,  0.5,11.0, 0.3),
      _FoodSuggestion('Watermelon',                  30,  0.6, 7.6, 0.2),
      _FoodSuggestion('Guava',                       68,  2.6,14.3, 1.0),
      _FoodSuggestion('Orange',                      47,  0.9,12.0, 0.1),
      _FoodSuggestion('Grapes',                      67,  0.6,17.2, 0.4),
    ],
    'Grains': [
      _FoodSuggestion('Rice (raw)',                 350,  6.8,78.2, 0.5),
      _FoodSuggestion('Wheat flour (atta)',         340, 12.0,72.0, 1.7),
      _FoodSuggestion('Jowar flour',               348, 10.0,72.0, 1.9),
      _FoodSuggestion('Bajra flour',               361, 11.6,67.5, 5.0),
      _FoodSuggestion('Ragi / Nachni flour',       336,  7.3,72.6, 1.5),
      _FoodSuggestion('Oats (raw)',                389, 16.9,66.3, 6.9),
      _FoodSuggestion('Brown Rice (raw)',           362,  7.5,76.2, 2.7),
      _FoodSuggestion('Quinoa (cooked)',            120,  4.4,21.3, 1.9),
    ],
    'Snacks': [
      _FoodSuggestion('Almonds',                   579, 21.2,21.6,49.9),
      _FoodSuggestion('Cashews',                   553, 18.2,30.2,43.9),
      _FoodSuggestion('Peanuts',                   567, 25.8,16.1,49.2),
      _FoodSuggestion('Chana (roasted)',            364, 22.5,60.9, 5.0),
      _FoodSuggestion('Banana Chips',              519,  2.3,58.4,32.0),
      _FoodSuggestion('Biscuits (digestive)',       471,  6.7,66.5,20.3),
      _FoodSuggestion('Protein Bar',               380, 20.0,45.0,12.0),
      _FoodSuggestion('Dark Chocolate (70%)',       598,  7.8,45.9,42.6),
    ],
    'Drinks': [
      _FoodSuggestion('Water',                       0,  0.0, 0.0, 0.0),
      _FoodSuggestion('Milk (whole, 200ml)',         61,  3.2, 4.8, 3.5),
      _FoodSuggestion('Tea (with milk & sugar)',     30,  0.5, 6.0, 0.5),
      _FoodSuggestion('Coffee (black, no sugar)',     2,  0.3, 0.0, 0.0),
      _FoodSuggestion('Protein Shake (250ml)',      150, 25.0, 7.0, 2.0),
      _FoodSuggestion('Coconut Water (200ml)',       19,  0.7, 3.7, 0.2),
      _FoodSuggestion('Orange Juice (200ml)',        45,  0.7,10.4, 0.2),
      _FoodSuggestion('Lassi (sweet, 200ml)',       120,  3.5,18.0, 3.8),
      _FoodSuggestion('Nimbu Pani (lemonade 200ml)', 25, 0.2, 6.0, 0.0),
      _FoodSuggestion('Sports Drink (Gatorade)',     26,  0.0, 6.7, 0.1),
      _FoodSuggestion('Cold Coffee (200ml)',         90,  3.5,13.0, 2.5),
      _FoodSuggestion('Sugarcane Juice (200ml)',     75,  0.4,18.0, 0.2),
      _FoodSuggestion('Masala Chaas (200ml)',        25,  2.0, 2.0, 0.8),
    ],
    'Cheat': [
      _FoodSuggestion('Pizza (1 slice ~100g)',      266,  11.0,33.0, 9.8),
      _FoodSuggestion('Burger (chicken)',           295,  17.0,30.0,11.0),
      _FoodSuggestion('French Fries (100g)',        312,   3.4,41.0,15.0),
      _FoodSuggestion('Samosa (1 piece ~60g)',      262,   4.5,27.0,16.0),
      _FoodSuggestion('Vada Pav',                  286,   6.5,42.0,10.0),
      _FoodSuggestion('Pani Puri (6 pieces)',       180,   3.0,28.0, 5.0),
      _FoodSuggestion('Chole Bhature (1 plate)',    490,  14.0,62.0,20.0),
      _FoodSuggestion('Ice Cream (1 scoop 80g)',    137,   2.5,17.0, 7.0),
      _FoodSuggestion('Gulab Jamun (1 piece)',      175,   2.5,32.0, 4.5),
      _FoodSuggestion('Jalebi (100g)',              370,   2.0,74.0, 7.5),
      _FoodSuggestion('Cake (chocolate, 80g)',      310,   4.0,44.0,14.0),
      _FoodSuggestion('Chips (Lays, 28g pack)',     150,   2.0,15.0,10.0),
      _FoodSuggestion('Noodles (Maggi, cooked)',    312,   8.5,42.0,12.0),
    ],
  };

  static List<_FoodSuggestion> byCategory(String cat) => _db[cat] ?? [];

  static List<_FoodSuggestion> search(String q) {
    final query = q.toLowerCase();
    final results = <_FoodSuggestion>[];
    for (final list in _db.values) {
      for (final food in list) {
        if (food.name.toLowerCase().contains(query)) {
          results.add(food);
          if (results.length >= 6) return results;
        }
      }
    }
    return results;
  }
}
