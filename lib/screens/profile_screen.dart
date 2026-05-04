// lib/screens/profile_screen.dart — v9.0 PREMIUM
// FIXES:
//   • NULL CRASH: macros['fats']! → null-safe with fallbacks (NO ! operators on map)
//   • Both 'fat' and 'fats' keys handled
// UPGRADES:
//   • Gradient stat summary row (workouts, streak, XP)
//   • Nutrition tiles with animated progress bars
//   • Info card with icon-prefixed rows
//   • Edit form with gold focus borders
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../models/models.dart';
import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';
import '../services/ai_engine.dart';
import 'body_measurement_screen.dart';
import 'one_rm_screen.dart';

// ════════════════════════════════════════════════
// HAPTICS — consistent system (Phase 1)
// ════════════════════════════════════════════════
class H{
  static void heavy()     => H.heavy();
  static void medium()    => H.medium();
  static void light()     => H.light();
  static void selection() => H.selection();
  static void success()   => H.heavy();
  static void tap()       => H.light();
}


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _name, _age, _weight, _height;
  bool _editing = false;
  String _goal = 'muscle_gain', _level = 'beginner',
      _trainer = 'friendly', _gender = 'male', _activity = 'Moderate';

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>().profile;
    _name   = TextEditingController(text: p.name);
    _age    = TextEditingController(text: '${p.age}');
    _weight = TextEditingController(text: '${p.weightKg}');
    _height = TextEditingController(text: '${p.heightCm}');
    _goal    = p.goal;        _level   = p.level;
    _trainer = p.trainerType; _gender  = p.gender;
    _activity = p.activityLevel;
  }

  @override
  void dispose() {
    _name.dispose(); _age.dispose();
    _weight.dispose(); _height.dispose();
    super.dispose();
  }

  void _save() {
    final ap = context.read<AppProvider>();
    ap.updateProfile(ap.profile.copyWith(
      name:          _name.text.trim().isEmpty ? 'Champion' : _name.text.trim(),
      age:           int.tryParse(_age.text)       ?? 25,
      weightKg:      double.tryParse(_weight.text)  ?? 70.0,
      heightCm:      double.tryParse(_height.text)  ?? 170.0,
      goal:          _goal,     level:         _level,
      trainerType:   _trainer,  gender:        _gender,
      activityLevel: _activity,
    ));
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Profile updated!',
          style: TextStyle(fontFamily: 'Inter',fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Null-safe macro helper ──────────────────────
  // Handles both 'fat' and 'fats' keys, never throws.
  static Map<String, double> _safeMacros(double tdee, double weightKg, String goal) {
    try {
      final raw = AIEngine.getMacros(tdee: tdee, weightKg: weightKg, goal: goal);
      if (raw == null) throw Exception('null map');
      return {
        'protein': ((raw['protein'] as num?)?.toDouble()) ?? (weightKg * 2.0),
        'carbs':   ((raw['carbs']   as num?)?.toDouble()) ?? (tdee * 0.45 / 4),
        'fat':     ((raw['fat']     as num?)?.toDouble() ??
                    (raw['fats']    as num?)?.toDouble()) ?? (tdee * 0.25 / 9),
      };
    } catch (_) {
      // Fallback: standard macro split
      final protein = weightKg * 2.0;
      final fat     = tdee * 0.25 / 9;
      final carbs   = (tdee - protein * 4 - fat * 9) / 4;
      return {
        'protein': protein.clamp(80, 300),
        'carbs':   carbs.clamp(50, 500),
        'fat':     fat.clamp(30, 150),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector2<AppProvider, GamificationProvider,
        ({UserProfile profile, int totalWorkouts, int currentStreak, XPSystem xp, double tdee})>(
      selector: (_, ap, gp) => (
        profile:        ap.profile,
        totalWorkouts:  ap.streak.totalWorkouts,
        currentStreak:  ap.streak.currentStreak,
        xp:             gp.xp,
        tdee:           ap.tdee,
      ),
      builder: (context, d, _) {
        final p      = d.profile;
        final xp     = d.xp;
        // SAFE: no ! operators anywhere on this map
        final macros = _safeMacros(d.tdee, p.weightKg, p.goal);

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Stack(children: [
            // Ambient top glow
            Positioned(top: -80, left: -60, right: -60,
              child: IgnorePointer(child: Container(
                height: 280,
                decoration: BoxDecoration(gradient: RadialGradient(
                  center: Alignment.topCenter, radius: 0.7,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                )),
              )),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── APP BAR ───────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  floating: true, snap: true, elevation: 0,
                  titleSpacing: AppSpacing.lg,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('PROFILE', style: TextStyle(fontFamily: 'Rajdhani',
                          color: AppColors.textPrimary, fontSize: 20,
                          fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                      Text('Your fitness identity', style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: GestureDetector(
                        onTap: () {
                          if (_editing) _save();
                          else setState(() => _editing = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.30)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_editing
                                ? Icons.check_rounded : Icons.edit_rounded,
                                color: AppColors.gold, size: 13),
                            const SizedBox(width: AppSpacing.xs),
                            Text(_editing ? 'Save' : 'Edit',
                                style: TextStyle(fontFamily: 'Inter',
                                    color: AppColors.gold, fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── HERO CARD ─────────────────────
                      _FI(child: _HeroCard(
                          p: p, xp: xp,
                          totalWorkouts: d.totalWorkouts,
                          currentStreak: d.currentStreak)),
                      const SizedBox(height: AppSpacing.md),

                      // ── XP PROGRESS ───────────────────
                      _FI(delay: 50, child: Column(children: [
                        _AnimXPBar(progress: xp.rankProgress),
                        const SizedBox(height: AppSpacing.xs),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                          Text('${xp.rank.displayName} → ${xp.nextRankName}',
                              style: TextStyle(fontFamily: 'Inter',
                                  color: AppColors.textMuted, fontSize: 11)),
                          Text('${(xp.rankProgress * 100).toInt()}%',
                              style: TextStyle(fontFamily: 'Inter',
                                  color: AppColors.gold, fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ])),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── NUTRITION ─────────────────────
                      _SLabel(text: 'DAILY NUTRITION TARGETS'),
                      const SizedBox(height: AppSpacing.md),
                      _FI(delay: 90, child: _NutritionCard(
                          tdee: d.tdee, macros: macros)),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── PERSONAL INFO ─────────────────
                      _SLabel(text: 'PERSONAL DETAILS'),
                      const SizedBox(height: AppSpacing.md),
                      _FI(delay: 130, child: _editing
                          ? _EditForm(
                              name: _name, age: _age,
                              weight: _weight, height: _height,
                              goal: _goal, level: _level,
                              trainer: _trainer, gender: _gender,
                              activity: _activity,
                              onGoal:     (v) => setState(() => _goal = v!),
                              onLevel:    (v) => setState(() => _level = v!),
                              onTrainer:  (v) => setState(() => _trainer = v!),
                              onGender:   (v) => setState(() => _gender = v!),
                              onActivity: (v) => setState(() => _activity = v!),
                              onSave: _save,
                            )
                          : _InfoCard(p: p)),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── TOOLS ─────────────────────────
                      _SLabel(text: 'BODY TOOLS'),
                      const SizedBox(height: AppSpacing.md),
                      _FI(delay: 170, child: Row(children: [
                        Expanded(child: _ToolBtn(
                          emoji: '📏', title: 'Body Stats',
                          sub: 'Track measurements',
                          color: AppColors.blue,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  const BodyMeasurementScreen())),
                        )),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _ToolBtn(
                          emoji: '⚖️', title: '1RM Calculator',
                          sub: 'Find your max lift',
                          color: AppColors.purple,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  const OneRmScreen())),
                        )),
                      ])),
                      const SizedBox(height: AppSpacing.lg),
                      // ── SIGN OUT ─────────────────────
                      GestureDetector(
                        onTap: () async {
                          await AuthService.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                              (_) => false,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Sign Out', style: TextStyle(
                                fontFamily: 'Inter', color: Colors.red,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ]),
                  ),
                ),
              ],
            ),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════
// HERO CARD — rank orb + stats row
// ════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final UserProfile p;
  final XPSystem xp;
  final int totalWorkouts, currentStreak;
  const _HeroCard({required this.p, required this.xp,
      required this.totalWorkouts, required this.currentStreak});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0C07),
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      boxShadow: [BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.07), blurRadius: 22)],
    ),
    child: Column(children: [
      Row(children: [
        _PulseOrb(emoji: xp.rank.emoji,
            gradient: AppGradients.rankGradient(xp.rank.index)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: TextStyle(fontFamily: 'Rajdhani',
              color: AppColors.textPrimary, fontSize: 22,
              fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppGradients.rankGradient(xp.rank.index),
                borderRadius: BorderRadius.circular(6)),
              child: Text(xp.rank.displayName, style: TextStyle(fontFamily: 'Inter',
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(6)),
              child: Text(p.level.toUpperCase(), style: TextStyle(fontFamily: 'Inter',
                  color: AppColors.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text('${xp.totalXP} XP · $totalWorkouts workouts',
              style: TextStyle(fontFamily: 'Inter',
                  color: AppColors.textMuted, fontSize: 11)),
        ])),
        // BMI circle
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CircularPercentIndicator(
            radius: 28, lineWidth: 3.5,
            percent: (p.bmi / 40).clamp(0.0, 1.0),
            center: Text(p.bmi.toStringAsFixed(1), style: TextStyle(fontFamily: 'Rajdhani',
                fontSize: 11, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
            progressColor: p.bmiCategory == 'Normal'   ? AppColors.green
                : p.bmiCategory == 'Overweight' ? AppColors.yellow
                : AppColors.red,
            backgroundColor: AppColors.bgElevated,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(height: 3),
          Text('BMI', style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 9)),
        ]),
      ]),

      const SizedBox(height: AppSpacing.md),
      const Divider(color: AppColors.divider, height: 1),
      const SizedBox(height: AppSpacing.md),

      // Quick stats row
      Row(children: [
        _QuickStat(value: '$totalWorkouts', label: 'Sessions', emoji: '🏋️',
            color: AppColors.gold),
        _vDivider(),
        _QuickStat(value: '${currentStreak}d', label: 'Streak', emoji: '🔥',
            color: AppColors.orange),
        _vDivider(),
        _QuickStat(value: '${xp.weeklyXP}', label: 'Week XP', emoji: '⚡',
            color: AppColors.purple),
        _vDivider(),
        _QuickStat(value: p.bmiCategory, label: 'Status', emoji: '💪',
            color: p.bmiCategory == 'Normal' ? AppColors.green : AppColors.yellow),
      ]),
    ]),
  );

  Widget _vDivider() => Container(
    height: 32, width: 1,
    color: AppColors.divider.withValues(alpha: 0.5));
}

class _QuickStat extends StatelessWidget {
  final String value, label, emoji;
  final Color color;
  const _QuickStat({required this.value, required this.label,
      required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani',
        color: color, fontSize: 13, fontWeight: FontWeight.w900),
        overflow: TextOverflow.ellipsis),
    Text(label, style: TextStyle(fontFamily: 'Inter',
        color: AppColors.textMuted, fontSize: 8.5),
        textAlign: TextAlign.center),
  ]));
}

// ════════════════════════════════════════════════
// ANIMATED XP BAR
// ════════════════════════════════════════════════
class _AnimXPBar extends StatefulWidget {
  final double progress;
  const _AnimXPBar({required this.progress});
  @override State<_AnimXPBar> createState() => _AnimXPBarState();
}
class _AnimXPBarState extends State<_AnimXPBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => XPProgressBar(progress: widget.progress * _a.value),
  );
}

// ════════════════════════════════════════════════
// NUTRITION CARD — NULL-SAFE, no ! operators
// ════════════════════════════════════════════════
class _NutritionCard extends StatelessWidget {
  final double tdee;
  final Map<String, double> macros;
  const _NutritionCard({required this.tdee, required this.macros});

  @override
  Widget build(BuildContext context) {
    // All values null-safe with fallbacks — ZERO ! operators
    final protein = (macros['protein'] ?? 150.0).toDouble();
    final carbs   = (macros['carbs']   ?? 250.0).toDouble();
    final fat     = (macros['fat'] ?? macros['fats'] ?? 60.0).toDouble();

    // Total macros in kcal for progress bars
    final totalKcal = protein * 4 + carbs * 4 + fat * 9;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.borderSoft, width: 0.5),
      ),
      child: Column(children: [
        // Calorie total hero
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('🔥',
                style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tdee.toInt()} kcal', style: TextStyle(fontFamily: 'Rajdhani',
                color: AppColors.orange, fontSize: 24,
                fontWeight: FontWeight.w900)),
            Text('Daily calorie target', style: TextStyle(fontFamily: 'Inter',
                color: AppColors.textMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('TDEE', style: TextStyle(fontFamily: 'Inter',
                color: AppColors.orange, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: AppSpacing.lg),

        // Macro bars
        _MacroBar(
          emoji: '🍗', label: 'Protein', value: protein,
          unit: 'g', color: AppColors.blue,
          percent: totalKcal > 0
              ? (protein * 4 / totalKcal).clamp(0.0, 1.0) : 0.0,
        ),
        const SizedBox(height: AppSpacing.md),
        _MacroBar(
          emoji: '🌾', label: 'Carbs', value: carbs,
          unit: 'g', color: AppColors.purple,
          percent: totalKcal > 0
              ? (carbs * 4 / totalKcal).clamp(0.0, 1.0) : 0.0,
        ),
        const SizedBox(height: AppSpacing.md),
        _MacroBar(
          emoji: '🥑', label: 'Fats', value: fat,
          unit: 'g', color: AppColors.green,
          percent: totalKcal > 0
              ? (fat * 9 / totalKcal).clamp(0.0, 1.0) : 0.0,
        ),
      ]),
    );
  }
}

class _MacroBar extends StatefulWidget {
  final String emoji, label, unit;
  final double value, percent;
  final Color color;
  const _MacroBar({required this.emoji, required this.label,
      required this.value, required this.unit,
      required this.color, required this.percent});
  @override State<_MacroBar> createState() => _MacroBarState();
}

class _MacroBarState extends State<_MacroBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200),
            () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Column(children: [
      Row(children: [
        Text(widget.emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(widget.label, style: TextStyle(fontFamily: 'Inter',
            color: AppColors.textSecondary, fontSize: 13,
            fontWeight: FontWeight.w600))),
        Text(
          '${widget.value.toInt()} ${widget.unit}',
          style: TextStyle(fontFamily: 'Rajdhani',
              color: widget.color, fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${(widget.percent * 100).toInt()}%',
          style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 10),
        ),
      ]),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: widget.percent * _a.value,
          minHeight: 5,
          backgroundColor: AppColors.bgElevated,
          valueColor: AlwaysStoppedAnimation(widget.color),
        ),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// INFO CARD (read-only)
// ════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final UserProfile p;
  const _InfoCard({required this.p});

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle_gain': return 'Muscle Gain 💪';
      case 'fat_loss':    return 'Fat Loss 🔥';
      case 'strength':    return 'Strength ⚡';
      default:            return g;
    }
  }
  String _trainerLabel(String t) {
    switch (t) {
      case 'friendly':     return 'Friendly 🤝';
      case 'strict':       return 'Strict 😈';
      case 'military':     return 'Military 🪖';
      case 'motivational': return 'Hype 🚀';
      default:             return t;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      border: Border.all(color: AppColors.borderSoft, width: 0.5),
    ),
    child: Column(children: [
      _R('👤', 'Name',        p.name),
      _D(), _R('🎂', 'Age',   '${p.age} years'),
      _D(), _R('⚖️', 'Weight','${p.weightKg} kg'),
      _D(), _R('📏', 'Height','${p.heightCm} cm'),
      _D(), _R('🧬', 'Gender', p.gender == 'male' ? 'Male' : 'Female'),
      _D(), _R('🎯', 'Goal',   _goalLabel(p.goal)),
      _D(), _R('📈', 'Level',  p.level.toUpperCase()),
      _D(), _R('🤖', 'Trainer',_trainerLabel(p.trainerType)),
      _D(), _R('🏃', 'Activity',p.activityLevel),
      _D(), _R('📊', 'BMI',   '${p.bmi.toStringAsFixed(1)} · ${p.bmiCategory}'),
    ]),
  );

  Widget _D() => Divider(
      indent: AppSpacing.lg, endIndent: AppSpacing.lg,
      color: AppColors.divider.withValues(alpha: 0.5), height: 1);
}

class _R extends StatelessWidget {
  final String icon, label, value;
  const _R(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(label, style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted, fontSize: 13))),
      Flexible(child: Text(value,
          style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textPrimary, fontSize: 13,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ════════════════════════════════════════════════
// EDIT FORM
// ════════════════════════════════════════════════
class _EditForm extends StatelessWidget {
  final TextEditingController name, age, weight, height;
  final String goal, level, trainer, gender, activity;
  final ValueChanged<String?> onGoal, onLevel, onTrainer, onGender, onActivity;
  final VoidCallback onSave;

  const _EditForm({
    required this.name, required this.age,
    required this.weight, required this.height,
    required this.goal, required this.level,
    required this.trainer, required this.gender, required this.activity,
    required this.onGoal, required this.onLevel,
    required this.onTrainer, required this.onGender, required this.onActivity,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    _TF(ctrl: name, label: 'Name', cap: TextCapitalization.words),
    const SizedBox(height: AppSpacing.sm),
    Row(children: [
      Expanded(child: _TF(ctrl: age, label: 'Age', isNumber: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TF(ctrl: weight, label: 'Weight (kg)', isDecimal: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TF(ctrl: height, label: 'Height (cm)', isDecimal: true)),
    ]),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Gender', value: gender,
        items: ['male', 'female'],
        labels: {'male': 'Male', 'female': 'Female'},
        onChanged: onGender),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Goal', value: goal,
        items: ['muscle_gain', 'fat_loss', 'strength'],
        labels: {'muscle_gain': 'Muscle Gain 💪',
          'fat_loss': 'Fat Loss 🔥', 'strength': 'Strength ⚡'},
        onChanged: onGoal),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Training Level', value: level,
        items: ['beginner', 'intermediate', 'advanced'],
        onChanged: onLevel),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'AI Trainer Style', value: trainer,
        items: ['friendly', 'strict', 'military', 'motivational'],
        labels: {'friendly': 'Friendly 🤝', 'strict': 'Strict 😈',
          'military': 'Military 🪖', 'motivational': 'Hype 🚀'},
        onChanged: onTrainer),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Activity Level', value: activity,
        items: ['Sedentary','Light','Moderate','High','Very High'],
        onChanged: onActivity),
    const SizedBox(height: AppSpacing.lg),
    GoldButton(text: 'Save Profile ✅', width: double.infinity, onTap: onSave),
  ]);
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isNumber, isDecimal;
  final TextCapitalization cap;
  const _TF({required this.ctrl, required this.label,
      this.isNumber = false, this.isDecimal = false,
      this.cap = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    textCapitalization: cap,
    keyboardType: isDecimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : isNumber ? TextInputType.number : TextInputType.text,
    style: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted),
      filled: true, fillColor: AppColors.bgCardLight,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderMedium)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderMedium)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
    ),
  );
}

class _DD extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final Map<String, String>? labels;
  final ValueChanged<String?> onChanged;
  const _DD({required this.label, required this.value,
      required this.items, this.labels, required this.onChanged});

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value, onChanged: onChanged,
    dropdownColor: AppColors.bgModal,
    style: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted),
      filled: true, fillColor: AppColors.bgCardLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderMedium)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
    ),
    items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Text(labels?[i] ?? _cap(i)))).toList(),
  );
}

// ════════════════════════════════════════════════
// TOOL BUTTON
// ════════════════════════════════════════════════
class _ToolBtn extends StatefulWidget {
  final String emoji, title, sub;
  final Color color;
  final VoidCallback onTap;
  const _ToolBtn({required this.emoji, required this.title,
      required this.sub, required this.color, required this.onTap});
  @override State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn>
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
    onTapDown:   (_) => _c.forward(),
    onTapUp:     (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
            color: widget.color.withValues(alpha: 0.22), width: 0.8),
        boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.07), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(widget.emoji,
              style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TextStyle(fontFamily: 'Rajdhani',
              color: AppColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w800)),
          Text(widget.sub, style: TextStyle(fontFamily: 'Inter',
              color: AppColors.textMuted, fontSize: 10)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded,
            color: widget.color, size: 13),
      ]),
    )),
  );
}

// ════════════════════════════════════════════════
// HELPERS
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

class _PulseOrb extends StatefulWidget {
  final String emoji; final Gradient gradient;
  const _PulseOrb({required this.emoji, required this.gradient});
  @override State<_PulseOrb> createState() => _PulseOrbState();
}
class _PulseOrbState extends State<_PulseOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _p;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))
        ..repeat(reverse: true);
    _p = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _p,
    builder: (_, __) => Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle, gradient: widget.gradient,
        boxShadow: [BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.30 * _p.value),
          blurRadius: 18 * _p.value, spreadRadius: 2 * _p.value)],
      ),
      child: Center(child: Text(widget.emoji,
          style: const TextStyle(fontSize: 28))),
    ),
  );
}

class _FI extends StatefulWidget {
  final Widget child; final int delay;
  const _FI({required this.child, this.delay = 0});
  @override State<_FI> createState() => _FIState();
}
class _FIState extends State<_FI> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f;
  late Animation<Offset> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 340));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _s = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay),
            () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(
    opacity: _f, child: SlideTransition(position: _s, child: widget.child));
}
