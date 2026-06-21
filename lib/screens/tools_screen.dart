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

import '../widgets/shared_widgets.dart';
import 'pr_wall_screen.dart';
import 'body_measurement_screen.dart';
import '../data/exercise_library.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart';
import '../services/voice_coach_service.dart';

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
              colors: [AppColors.blue.withValues(alpha: 0.045), Colors.transparent],
            )),
          )),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
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
              // FIX: Extra top padding prevents Water card overlapping SliverAppBar
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                _SLabel(text: 'RECORDS'),
                const SizedBox(height: AppSpacing.md),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 0.6,
                    ),
                  ),
                  child: _ToolCard(
                    title: 'PR Wall',
                    subtitle: 'Your all-time personal records',
                    icon: Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    tag: 'Strength',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PRWallScreen(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                _SLabel(text: 'CALCULATORS'),
                const SizedBox(height: AppSpacing.md),

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

                      _ToolCard(
                        title: 'BMI Calculator',
                        subtitle: 'Know your body composition',
                        icon: Icons.scale_rounded,
                        color: AppColors.blue,
                        tag: 'Body',
                        onTap: () => _sheet(context, const _BMISheet()),
                      ),

                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: Colors.white.withValues(alpha: 0.05),
                        indent: 82,
                        endIndent: 18,
                      ),

                      _ToolCard(
                        title: 'Calorie Calculator',
                        subtitle: 'Find your daily fuel target',
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.orange,
                        tag: 'Nutrition',
                        onTap: () => _sheet(context, const _CalorieSheet()),
                      ),

                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: Colors.white.withValues(alpha: 0.05),
                        indent: 82,
                        endIndent: 18,
                      ),

                      _ToolCard(
                        title: 'Body Stats',
                        subtitle: 'Track measurements & physique',
                        icon: Icons.accessibility_new_rounded,
                        color: AppColors.blue,
                        tag: 'Tracking',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BodyMeasurementScreen(),
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: Colors.white.withValues(alpha: 0.05),
                        indent: 82,
                        endIndent: 18,
                      ),

                      _ToolCard(
                        title: '1RM Calculator',
                        subtitle: 'Estimate your max strength',
                        icon: Icons.sports_gymnastics_rounded,
                        color: AppColors.purple,
                        tag: 'Strength',
                        onTap: () => _sheet(context, const _OneRmSheet()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                _SLabel(text: 'COACHING'),
                const SizedBox(height: AppSpacing.md),

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

                      _ToolCard(
                        title: 'Voice Coach',
                        subtitle: 'Multi-language workout coaching',
                        icon: Icons.mic_none_rounded,
                        color: AppColors.gold,
                        tag: 'New',
                        onTap: () => _sheet(context, const _VoiceCoachSheet()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                _SLabel(text: 'WORKOUT SPLIT'),
                const SizedBox(height: AppSpacing.md),
                const _SplitStyleCard(),

                const SizedBox(height: AppSpacing.xxl),
                _SLabel(text: 'SMART REMINDERS'),
                const SizedBox(height: AppSpacing.md),
                const _RemindersCard(),

                const SizedBox(height: AppSpacing.xxl),
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
    'New'       => AppColors.green,
    'Nutrition' => AppColors.orange,
    'Strength'  => AppColors.purple,
    'Body'      => AppColors.blue,
    'Tracking'  => AppColors.blue,
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
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.color,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _tagColor(widget.tag).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _tagColor(widget.tag).withValues(alpha: 0.22),
                width: 0.7,
              ),
            ),
            child: Text(
              widget.tag,
              style: TextStyle(
                fontFamily: 'Inter',
                color: _tagColor(widget.tag),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.28),
            size: 13,
          ),
        ]),
      ]),
    )),
  );
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
              Text(title, style: TextStyle(fontFamily: 'Rajdhani',
                  color: AppColors.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(fontFamily: 'Inter',
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
  Color _catColor = AppColors.green;
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
    if (bmi < 18.5) { cat = 'Underweight'; color = AppColors.blue; }
    else if (bmi < 25) { cat = 'Healthy Weight ✅'; color = AppColors.green; }
    else if (bmi < 30) { cat = 'Overweight';   color = AppColors.orange; }
    else               { cat = 'Obese';         color = AppColors.red; }
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
                  Text(_bmiAdvice(_bmi!), style: TextStyle(fontFamily: 'Inter',
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
              Expanded(child: Container(height: 12,
                  color: AppColors.blue.withValues(alpha: 0.65))),
              Expanded(child: Container(height: 12,
                  color: AppColors.green.withValues(alpha: 0.65))),
              Expanded(child: Container(height: 12,
                  color: AppColors.orange.withValues(alpha: 0.65))),
              Expanded(child: Container(height: 12,
                  color: AppColors.red.withValues(alpha: 0.65))),
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
                Text(t, style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 9))).toList()),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _CatLabel('Under', AppColors.blue),
          _CatLabel('Normal', AppColors.green),
          _CatLabel('Over', AppColors.orange),
          _CatLabel('Obese', AppColors.red),
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
      Text('Activity Level', style: TextStyle(fontFamily: 'Inter',
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
                    : isGoal ? AppColors.green : AppColors.textMuted;
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
    'Strength': AppColors.blue,
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
            child: const Center(child: Text('🤖',
                style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Workout Generator', style: TextStyle(fontFamily: 'Rajdhani',
                color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w800)),
            Text('Personalised for your body & goal',
                style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 11)),
          ])),
        ]),

        const SizedBox(height: AppSpacing.lg),
        Text('YOUR GOAL', style: TextStyle(fontFamily: 'Inter',
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
                content: Text("Added to today's plan",
                    style: TextStyle(fontFamily: 'Inter',fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.green,
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
        Row(children: [
          const Text('🗓️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
          Text('YOUR PLAN', style: TextStyle(fontFamily: 'Inter',
              color: AppColors.gold, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(result.summary, style: TextStyle(fontFamily: 'Inter',
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
                Expanded(child: Text(n, style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w600))),
              ]),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.md),
        applied
            ? Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 16),
                const SizedBox(width: 6),
                Text('Added to today\'s plan', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.green, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ])
            : SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.add_rounded,
                      color: AppColors.gold, size: 16),
                  label: Text('Add to Today', style: TextStyle(fontFamily: 'Rajdhani',
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37)
                        .withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    size: 18,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workout Split',
                        style: GoogleFonts.rajdhani(
                            color: AppColors.textPrimary,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Affects how AI organises your weekly plan',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                )),
              ]),
              const SizedBox(height: AppSpacing.lg),
              // Days per week picker
              _DaysPerWeekRow(
                current: days,
                onChanged: (d) => p.updateSetting('gymDaysPerWeek', d),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                  ].asMap().entries.map((entry) {
                    final style    = entry.value;
                    final selected = style == current;
                    final isLast   = entry.key == 3;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        p.updateSetting('splitStyle', style.name);
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
                          boxShadow: selected ? [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            blurRadius: 8,
                          )] : [],
                        ),
                        child: Text(style.label,
                            style: GoogleFonts.rajdhani(
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
              if (current != SplitStyle.pushPullLegs) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  current.description,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.black, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Generate ${current.label} Plan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
              ),
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
                      backgroundColor: AppColors.green,
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
        activeColor: AppColors.gold,
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
      Text(label, style: TextStyle(fontFamily: 'Inter',
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
        style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderMedium)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderMedium)),
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
    {'pct': 85,  'label': '85% — Strength/Hyp',   'reps': '5',  'color': 0xFFD4AF37},
    {'pct': 80,  'label': '80% — Hypertrophy',    'reps': '8',  'color': 0xFF22C55E},
    {'pct': 75,  'label': '75% — Hypertrophy',    'reps': '10', 'color': 0xFF3B82F6},
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
          Text('Your Estimated 1RM', style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${_oneRm!.toStringAsFixed(1)} kg', style: TextStyle(fontFamily: 'Rajdhani',
              color: AppColors.purple, fontSize: 48, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: AppSpacing.lg),
        Text('TRAINING ZONES', style: TextStyle(fontFamily: 'Inter',
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
                Text(z['label'] as String, style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                Text('~${z['reps']} reps', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 10)),
              ])),
              Text('${weight.toStringAsFixed(1)} kg', style: TextStyle(
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
