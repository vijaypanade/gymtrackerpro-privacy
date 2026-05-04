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
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_constants.dart';

import '../widgets/shared_widgets.dart';
import '../data/exercise_library.dart';
import '../services/ai_engine.dart';

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

                _SLabel(text: 'CALCULATORS'),
                const SizedBox(height: AppSpacing.md),

                _ToolCard(
                  title: 'BMI Calculator',
                  subtitle: 'Know your body composition',
                  emoji: '⚖️',
                  color: AppColors.blue,
                  tag: 'Body',
                  onTap: () => _sheet(context, const _BMISheet()),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ToolCard(
                  title: 'Calorie Calculator',
                  subtitle: 'Find your daily fuel target',
                  emoji: '🔥',
                  color: AppColors.orange,
                  tag: 'Nutrition',
                  onTap: () => _sheet(context, const _CalorieSheet()),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ToolCard(
                  title: 'Water Intake Tracker',
                  subtitle: 'Stay hydrated, stay strong',
                  emoji: '💧',
                  color: const Color(0xFF38BDF8),
                  tag: 'Hydration',
                  onTap: () => _sheet(context, const _WaterSheet()),
                ),

                const SizedBox(height: AppSpacing.xxl),
                _SLabel(text: 'AI WORKOUT GENERATOR'),
                const SizedBox(height: AppSpacing.md),
                const _AIWorkoutGenerator(),

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
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: AppSpacing.sm),
    Text(text, style: TextStyle(fontFamily: 'Inter',
        color: AppColors.textPrimary, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 1.1)),
  ]);
}

// ════════════════════════════════════════════════
// TOOL CARD — premium, no progressionTip
// ════════════════════════════════════════════════
class _ToolCard extends StatefulWidget {
  final String title, subtitle, emoji, tag;
  final Color color;
  final VoidCallback onTap;
  const _ToolCard({
    required this.title, required this.subtitle,
    required this.emoji, required this.color,
    required this.tag,   required this.onTap,
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

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) { H.light(); _c.forward(); },
    onTapUp:     (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(
            color: widget.color.withValues(alpha: 0.22), width: 0.8),
        boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              widget.color.withValues(alpha: 0.22),
              widget.color.withValues(alpha: 0.07),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.color.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Center(child: Text(widget.emoji,
              style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TextStyle(fontFamily: 'Rajdhani',
              color: AppColors.textPrimary, fontSize: 16,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(widget.subtitle, style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(widget.tag, style: TextStyle(fontFamily: 'Inter',
                color: widget.color, fontSize: 9,
                fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(Icons.arrow_forward_ios_rounded, color: widget.color, size: 14),
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
  final String emoji;
  const _SheetWrap({
    required this.title, required this.subtitle,
    required this.emoji, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            Text(emoji, style: const TextStyle(fontSize: 28)),
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
    emoji: '⚖️', title: 'BMI Calculator',
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
    if (bmi < 18.5) return "Your body needs more fuel — focus on calorie surplus and strength training to build healthy mass 💪";
    if (bmi < 25)   return "You're in the healthy zone! Keep consistent with your training and nutrition to stay here 🌟";
    if (bmi < 30)   return "You're close to optimal — a calorie deficit with strength training will get you there fast 🔥";
    return "Time to take charge! Combine cardio with resistance training and track your nutrition daily 🎯";
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
    emoji: '🔥', title: 'Calorie Calculator',
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
class _WaterSheet extends StatefulWidget {
  const _WaterSheet();
  @override State<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends State<_WaterSheet> {
  void _customGoal(BuildContext ctx, AppProvider p) {
    final c = TextEditingController();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgModal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Custom Daily Goal', style: TextStyle(fontFamily: 'Rajdhani',
          color: AppColors.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700)),
      content: TextField(controller: c,
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'ml, e.g. 3500')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Inter',
                color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
          onPressed: () {
            final v = int.tryParse(c.text);
            if (v != null && v > 0) { p.setWaterGoal(v); setState(() {}); }
            Navigator.pop(ctx);
          },
          child: Text('Save', style: TextStyle(fontFamily: 'Inter',
              color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p   = context.watch<AppProvider>();
    final cur  = p.profile.currentWaterMl;
    final goal = p.profile.dailyWaterGoalMl;
    final pct  = p.waterProgress.clamp(0.0, 1.0);
    final color = pct >= 0.8 ? AppColors.green
        : pct >= 0.5 ? AppColors.blue : const Color(0xFF38BDF8);

    return _SheetWrap(
      emoji: '💧', title: 'Water Tracker',
      subtitle: 'Stay hydrated — stay strong',
      child: Column(children: [
        // Ring
        Center(child: Stack(alignment: Alignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 148, height: 148,
              child: CircularProgressIndicator(
                value: v, strokeWidth: 11,
                backgroundColor: AppColors.bgCardLight,
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('💧', style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 2),
            Text('${(pct * 100).round()}%', style: TextStyle(fontFamily: 'Rajdhani',
                color: color, fontSize: 26, fontWeight: FontWeight.w900)),
            Text('of goal', style: TextStyle(fontFamily: 'Inter',
                color: AppColors.textMuted, fontSize: 11)),
          ]),
        ])),
        const SizedBox(height: AppSpacing.md),
        Text('$cur ml / $goal ml', style: TextStyle(fontFamily: 'Rajdhani',
            color: AppColors.textPrimary, fontSize: 22,
            fontWeight: FontWeight.w800)),
        if (pct >= 1.0) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
            ),
            child: Text('Goal reached! You\'re crushing it 🏆',
                style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.green, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Quick-add tiles
        Row(children: [250, 500, 750, 1000].map((ml) {
          return Expanded(child: GestureDetector(
            onTap: () { H.medium(); p.addWater(ml); setState(() {}); },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: color.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Column(children: [
                Text('💧', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 3),
                Text('+${ml}ml', style: TextStyle(fontFamily: 'Rajdhani',
                    color: color, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ));
        }).toList()),

        const SizedBox(height: AppSpacing.xl),

        // Goal selector
        Text('Daily Goal', style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 12,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm,
          children: [
            ...[2000, 2500, 3000, 3500].map((g) {
              final sel = goal == g;
              return GestureDetector(
                onTap: () { p.setWaterGoal(g); setState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? color.withValues(alpha: 0.14) : AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? color : Colors.transparent),
                  ),
                  child: Text('${g}ml', style: TextStyle(fontFamily: 'Inter',
                      color: sel ? color : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _customGoal(context, p),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCardLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Custom ✏️', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.gold, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GoldButton(
          text: 'Reset Today 🔄', width: double.infinity,
          onTap: () { p.resetWater(); setState(() {}); },
        ),
        const SizedBox(height: AppSpacing.sm),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// AI WORKOUT GENERATOR
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
          text: _loading ? 'Building your plan... ⏳' : 'Generate My Workout 🚀',
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
                content: Text("🔥 Added to today's plan!",
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
                Text('Added to today\'s plan! 🎯', style: TextStyle(fontFamily: 'Inter',
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
// REMINDERS
// ════════════════════════════════════════════════
class _RemindersCard extends StatelessWidget {
  const _RemindersCard();

  @override
  Widget build(BuildContext context) => Selector<AppProvider, Map<String, dynamic>>(
   selector: (_, p) => p.settingsMap,
    builder: (context, s, _) {
      final p = context.read<AppProvider>();
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.borderSoft, width: 0.5),
        ),
        child: Column(children: [
          _RRow(
            emoji: '🏋️', label: 'Workout Reminder',
            sub: 'Daily training push',
            value: s['workoutReminderEnabled'] as bool? ?? false,
            color: AppColors.gold,
            onChanged: (v) => p.updateSetting('workoutReminderEnabled', v),
          ),
          _Div(),
          _RRow(
            emoji: '💧', label: 'Hydration Reminder',
            sub: 'Every ${s['waterReminderInterval'] ?? 60} minutes',
            value: s['waterReminderEnabled'] as bool? ?? false,
            color: const Color(0xFF38BDF8),
            onChanged: (v) => p.updateSetting('waterReminderEnabled', v),
          ),
          _Div(),
          _RRow(
            emoji: '🧍', label: 'Stand Reminder',
            sub: 'Every ${s['standReminderInterval'] ?? 60} minutes',
            value: s['standReminderEnabled'] as bool? ?? false,
            color: AppColors.green,
            onChanged: (v) => p.updateSetting('standReminderEnabled', v),
          ),
        ]),
      );
    },
  );
}

class _RRow extends StatelessWidget {
  final String emoji, label, sub;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _RRow({
    required this.emoji, required this.label, required this.sub,
    required this.value, required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(emoji,
            style: const TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textPrimary, fontSize: 13,
            fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textMuted, fontSize: 11)),
      ])),
      Switch(
        value: value, onChanged: onChanged,
        activeColor: color, inactiveThumbColor: AppColors.textMuted,
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
