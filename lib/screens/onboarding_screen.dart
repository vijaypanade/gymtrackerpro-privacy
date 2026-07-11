// lib/screens/onboarding_screen.dart
// 5-step premium onboarding:
//   Step 1 — Welcome + Name
//   Step 2 — Body stats (age, weight, height, gender)
//   Step 3 — Goal + Level + Activity + Days per week
//   Step 4 — Split style selection
//   Step 5 — Weak muscle (optional)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/split_template.dart';
import '../utils/app_constants.dart';
import 'main_shell.dart';

// ════════════════════════════════════════════════
// ONBOARDING SCREEN
// ════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _page = 0;

  bool _showIntro    = true;
  bool _showBuilding = false;

  // Step 1
  final _nameCtrl = TextEditingController();

  // Step 2
  final _ageCtrl    = TextEditingController(text: '25');
  final _weightCtrl = TextEditingController(text: '70');
  final _heightCtrl = TextEditingController(text: '170');
  String _gender = 'male';

  // Step 3
  String _goal       = 'muscle_gain';
  String _level      = 'beginner';
  String _activity   = 'Moderate';
  int    _daysPerWeek = 4;

  // Step 4 — Split style
  SplitStyle _splitStyle = SplitStyle.pushPullLegs;

  // Step 5
  String _weakMuscle = '';

  static const int _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _showIntro = false);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.mediumImpact();
    if (_page < _totalSteps - 1) {
      _pageCtrl.nextPage(
          duration: AppDurations.slow, curve: AppCurves.primary);
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.heavyImpact();
    setState(() => _showBuilding = true);

    final ap = context.read<AppProvider>();

    ap.updateProfile(ap.profile.copyWith(
      name:           _nameCtrl.text.trim().isEmpty ? 'Champion' : _nameCtrl.text.trim(),
      age:            int.tryParse(_ageCtrl.text)       ?? 25,
      weightKg:       double.tryParse(_weightCtrl.text) ?? 70.0,
      heightCm:       double.tryParse(_heightCtrl.text) ?? 170.0,
      gender:         _gender,
      goal:           _goal,
      level:          _level,
      activityLevel:  _activity,
    ));

    await ap.settings.update('gymDaysPerWeek', _daysPerWeek);
    await ap.settings.update('splitStyle', _splitStyle.name);

    if (_weakMuscle.isNotEmpty) {
      ap.settings.update('weakMusclePreference', _weakMuscle);
    }

    ap.completeOnboarding();
    if (_splitStyle != SplitStyle.myOwnWay) {
      ap.generateAIWorkout().catchError((e) {
        debugPrint('[Onboarding] generateAIWorkout failed: $e');
      });
    }

    // Show "building" overlay for 1.8 s so user feels the AI working
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionDuration: AppDurations.xslow,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppCurves.primary),
          child: child,
        ),
      ),
    );
  }

  bool get _canNext {
    if (_page == 0) return _nameCtrl.text.trim().isNotEmpty;
    return true;
  }

  String get _ctaLabel {
    if (_page < _totalSteps - 1) return 'Continue →';
    return 'Build My Plan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Ambient background glow
        Positioned(top: -100, left: -80, right: -80,
          child: IgnorePointer(child: Container(
            height: 340,
            decoration: BoxDecoration(gradient: RadialGradient(
              center: Alignment.topCenter, radius: 0.6,
              colors: [AppColors.gold.withValues(alpha: 0.07), Colors.transparent],
            )),
          )),
        ),

        SafeArea(
          child: AnimatedOpacity(
            opacity: _showIntro ? 0 : 1,
            duration: const Duration(milliseconds: 700),
            curve: AppCurves.smooth,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 700),
              curve: AppCurves.entrance,
              offset: _showIntro ? const Offset(0, 0.03) : Offset.zero,
              child: Column(children: [
                _ProgressBar(current: _page, total: _totalSteps),
                const SizedBox(height: AppSpacing.lg),

                Expanded(child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1(nameCtrl: _nameCtrl, onChanged: (_) => setState(() {})),
                    _Step2(
                        ageCtrl: _ageCtrl,
                        weightCtrl: _weightCtrl,
                        heightCtrl: _heightCtrl,
                        gender: _gender,
                        onGender: (v) => setState(() => _gender = v)),
                    _Step3(
                        goal: _goal,
                        level: _level,
                        activity: _activity,
                        daysPerWeek: _daysPerWeek,
                        onGoal:     (v) => setState(() => _goal = v),
                        onLevel:    (v) => setState(() => _level = v),
                        onActivity: (v) => setState(() => _activity = v),
                        onDays:     (v) => setState(() => _daysPerWeek = v)),
                    _Step4(
                        selected: _splitStyle,
                        daysPerWeek: _daysPerWeek,
                        onSelect: (v) => setState(() => _splitStyle = v)),
                    _Step5(
                        selected: _weakMuscle,
                        onSelect: (v) => setState(() => _weakMuscle = v)),
                  ],
                )),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                  child: _CTAButton(
                    label: _ctaLabel,
                    enabled: _canNext,
                    onTap: _next,
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Cinematic intro overlay
        IgnorePointer(
          ignoring: !_showIntro,
          child: AnimatedOpacity(
            opacity: _showIntro ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            curve: AppCurves.smooth,
            child: Container(
              color: AppColors.bg,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.gold.withValues(alpha: 0.22),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (r) => AppGradients.gold.createShader(r),
                      blendMode: BlendMode.srcIn,
                      child: const Text('DISCIPLINE',
                        style: TextStyle(
                          fontFamily: 'Rajdhani', fontSize: 34,
                          fontWeight: FontWeight.w900, letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('IS BUILT DAILY',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(width: 42, height: 1,
                        color: AppColors.gold.withValues(alpha: 0.32)),
                    const SizedBox(height: 18),
                    Text('WELCOME TO LIFTON',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.gold.withValues(alpha: 0.82),
                        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Building plan overlay — shown after final CTA tap
        IgnorePointer(
          ignoring: !_showBuilding,
          child: AnimatedOpacity(
            opacity: _showBuilding ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Container(
              color: AppColors.bg,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing orb
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.15),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      builder: (_, scale, child) => Transform.scale(
                        scale: scale, child: child),
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [
                            Color(0xFFF6E27A),
                            Color(0xFFD4AF37),
                            Color(0xFF8B6914),
                          ]),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 32, spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.black, size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ShaderMask(
                      shaderCallback: (r) => AppGradients.gold.createShader(r),
                      blendMode: BlendMode.srcIn,
                      child: Text('Setting Up Your Plan',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w900, letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Preparing your first week...',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// PROGRESS BAR
// ════════════════════════════════════════════════
class _ProgressBar extends StatelessWidget {
  final int current, total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive   = i == current;
        final isComplete = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width:  isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: isActive ? AppGradients.gold : null,
            color: isActive
                ? null
                : isComplete
                    ? AppColors.goldAmber
                    : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(99),
            boxShadow: isActive
                ? [BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )]
                : [],
          ),
        );
      }),
    ),
  );
}

// ════════════════════════════════════════════════
// STEP 1 — Welcome + Name
// ════════════════════════════════════════════════
class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final ValueChanged<String> onChanged;
  const _Step1({required this.nameCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(children: [
      const SizedBox(height: AppSpacing.xl),
      Container(
        width: 92, height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22),
            blurRadius: 28, spreadRadius: 2,
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset('assets/header_logo.png',
              width: 92, height: 92, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('Welcome to', style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 16)),
      const SizedBox(height: 4),
      Text('LiftOn', style: GoogleFonts.rajdhani(
          color: AppColors.gold, fontSize: 36,
          fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: AppSpacing.xxl),
      ...[
        (Icons.trending_up_rounded,   'Progress every week'),
        (Icons.psychology_rounded,    'Your coach adapts as you train.'),
        (Icons.bolt_rounded,          'Build lasting consistency'),
      ].map((f) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(f.$1,
                color: AppColors.gold, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(f.$2, style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w500)),
        ]),
      )),
      const SizedBox(height: AppSpacing.xxl),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("What should we call you?", style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 20,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: nameCtrl,
          onChanged: onChanged,
          autofocus: false,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary, fontSize: 18,
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 15),
            filled: true, fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          ),
        ),
      ]),
    ]),
  );
}

// ════════════════════════════════════════════════
// STEP 2 — Body Stats
// ════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  final TextEditingController ageCtrl, weightCtrl, heightCtrl;
  final String gender;
  final ValueChanged<String> onGender;

  const _Step2({
    required this.ageCtrl, required this.weightCtrl,
    required this.heightCtrl, required this.gender,
    required this.onGender,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.lg),
      Text('Profile', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 30,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: AppSpacing.xs),
      Text('We\'ll personalise your plan around your body.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: AppSpacing.xxl),

      Text('Gender', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _GenderTile(label: 'Male', emoji: '👨',
            selected: gender == 'male', onTap: () => onGender('male')),
        const SizedBox(width: AppSpacing.md),
        _GenderTile(label: 'Female', emoji: '👩',
            selected: gender == 'female', onTap: () => onGender('female')),
      ]),
      const SizedBox(height: AppSpacing.xl),

      Text('Body Stats', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _StatField(ctrl: ageCtrl, label: 'Age', unit: 'yrs', icon: Icons.calendar_today_rounded)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatField(ctrl: weightCtrl, label: 'Weight', unit: 'kg', icon: Icons.monitor_weight_outlined, isDecimal: true)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatField(ctrl: heightCtrl, label: 'Height', unit: 'cm', icon: Icons.height_rounded, isDecimal: true)),
      ]),
      const SizedBox(height: AppSpacing.xxl),

      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: AppColors.gold.withValues(alpha: 0.70), size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(
            'Your stats help personalise workouts and track progress.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12, height: 1.4),
          )),
        ]),
      ),
    ]),
  );
}

class _GenderTile extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _GenderTile({required this.label, required this.emoji,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: selected ? AppColors.gold.withValues(alpha: 0.12) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 0.5,
        ),
        boxShadow: selected ? [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.20), blurRadius: 12)] : [],
      ),
      child: Center(
        child: Text(label, style: GoogleFonts.rajdhani(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 16, letterSpacing: 0.8, fontWeight: FontWeight.w900)),
      ),
    ),
  ));
}

class _StatField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, unit;
  final IconData icon;
  final bool isDecimal;
  const _StatField({required this.ctrl, required this.label,
      required this.unit, required this.icon, this.isDecimal = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderSoft, width: 0.5),
    ),
    child: Column(children: [
      Icon(icon, color: AppColors.gold.withValues(alpha: 0.70), size: 20),
      const SizedBox(height: AppSpacing.xs),
      TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
        style: GoogleFonts.rajdhani(
            color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900),
        decoration: const InputDecoration(
          isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
      ),
      Text(unit, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 10)),
    ]),
  );
}

// ════════════════════════════════════════════════
// STEP 3 — Goal + Level + Activity + Days/week
// ════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  final String goal, level, activity;
  final int daysPerWeek;
  final ValueChanged<String> onGoal, onLevel, onActivity;
  final ValueChanged<int> onDays;

  const _Step3({
    required this.goal, required this.level, required this.activity,
    required this.daysPerWeek,
    required this.onGoal, required this.onLevel, required this.onActivity,
    required this.onDays,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.lg),
      Text('Your Goals', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 30,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: AppSpacing.xs),
      Text('Your first week is built around your goals.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: AppSpacing.xl),

      // Fitness Goal
      Text('Primary Goal', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _GoalTile(label: 'Fat Loss',
            selected: goal == 'fat_loss', onTap: () => onGoal('fat_loss')),
        const SizedBox(width: AppSpacing.sm),
        _GoalTile(label: 'Muscle Gain',
            selected: goal == 'muscle_gain', onTap: () => onGoal('muscle_gain')),
        const SizedBox(width: AppSpacing.sm),
        _GoalTile(label: 'Strength',
            selected: goal == 'strength', onTap: () => onGoal('strength')),
      ]),
      const SizedBox(height: AppSpacing.xl),

      // Training Level
      Text('Training Level', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _LevelTile(label: 'Beginner', sub: '< 1 year',
            selected: level == 'beginner', onTap: () => onLevel('beginner')),
        const SizedBox(width: AppSpacing.sm),
        _LevelTile(label: 'Intermediate', sub: '1-3 yrs',
            selected: level == 'intermediate', onTap: () => onLevel('intermediate')),
        const SizedBox(width: AppSpacing.sm),
        _LevelTile(label: 'Advanced', sub: '3+ years',
            selected: level == 'advanced', onTap: () => onLevel('advanced')),
      ]),
      const SizedBox(height: AppSpacing.xl),

      // Activity Level
      Text('Daily Activity', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Column(children: [
        'Sedentary', 'Light', 'Moderate', 'High', 'Very High',
      ].map((a) => _ActivityTile(
            label: a, sub: _activitySub(a),
            selected: activity == a, onTap: () => onActivity(a),
          )).toList()),

      const SizedBox(height: AppSpacing.xl),

      // Days per week — chip row
      Text('Days per Week', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('How many days can you train?', style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: List.generate(5, (i) {
          final d = i + 2; // 2..6
          final selected = daysPerWeek == d;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onDays(d); },
                child: AnimatedContainer(
                  duration: AppDurations.normal,
                  curve: AppCurves.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.gold.withValues(alpha: 0.18),
                              AppColors.gold.withValues(alpha: 0.06),
                            ],
                          )
                        : null,
                    color: selected ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.gold.withValues(alpha: 0.80)
                          : AppColors.borderSoft,
                      width: selected ? 1.2 : 0.5,
                    ),
                    boxShadow: selected ? [BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.20),
                        blurRadius: 12)] : [],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$d', style: GoogleFonts.rajdhani(
                        color: selected ? AppColors.gold : AppColors.textPrimary,
                        fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('days', style: GoogleFonts.inter(
                        color: selected ? AppColors.gold.withValues(alpha: 0.7) : AppColors.textMuted,
                        fontSize: 9, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]),
  );

  String _activitySub(String a) {
    switch (a) {
      case 'Sedentary': return 'Desk job, little exercise';
      case 'Light':     return '1-3 days/week exercise';
      case 'Moderate':  return '3-5 days/week exercise';
      case 'High':      return '6-7 days/week exercise';
      case 'Very High': return 'Athlete / physical job';
      default: return '';
    }
  }
}

// ════════════════════════════════════════════════
// STEP 4 — Split Style
// ════════════════════════════════════════════════
class _Step4 extends StatelessWidget {
  final SplitStyle selected;
  final int daysPerWeek;
  final ValueChanged<SplitStyle> onSelect;

  const _Step4({required this.selected, required this.daysPerWeek, required this.onSelect});

  static const _splits = [
    SplitStyle.pushPullLegs,
    SplitStyle.upperLower,
    SplitStyle.fullBody,
    SplitStyle.aiAdaptive,
    SplitStyle.myOwnWay,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.lg),
        Text('Training Style', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 30,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        Text('How do you want to structure your week?',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
        const SizedBox(height: AppSpacing.lg),

        ..._splits.map((s) {
          final isSelected = selected == s;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onSelect(s); },
              child: AnimatedContainer(
                duration: AppDurations.normal,
                curve: AppCurves.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold.withValues(alpha: 0.14),
                            AppColors.gold.withValues(alpha: 0.04),
                          ],
                        )
                      : null,
                  color: isSelected ? null : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.75)
                        : AppColors.borderSoft,
                    width: isSelected ? 1.2 : 0.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      blurRadius: 18, spreadRadius: -3, offset: const Offset(0, 4),
                    ),
                  ] : [],
                ),
                child: Row(children: [
                  Icon(_splitIcon(s),
                      color: isSelected ? AppColors.gold : AppColors.textMuted, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayLabel(s), style: GoogleFonts.rajdhani(
                          color: isSelected ? AppColors.gold : AppColors.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(_displayDescription(s), style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 11, height: 1.35),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  if (isSelected)
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.gold),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.black, size: 12),
                    ),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
      ]),
    );
  }

  String _displayLabel(SplitStyle s) {
    if (s == SplitStyle.aiAdaptive) return 'Coach Adaptive';
    return s.label;
  }

  String _displayDescription(SplitStyle s) {
    if (s == SplitStyle.aiAdaptive) {
      return 'Your schedule adapts each week based on how your body is recovering.';
    }
    return s.description;
  }

  IconData _splitIcon(SplitStyle s) {
    switch (s) {
      case SplitStyle.pushPullLegs:      return Icons.compare_arrows_rounded;
      case SplitStyle.upperLower:        return Icons.swap_vert_rounded;
      case SplitStyle.fullBody:          return Icons.local_fire_department_rounded;
      case SplitStyle.aiAdaptive:        return Icons.auto_awesome_rounded;
      case SplitStyle.antagonistPairs:   return Icons.sync_alt_rounded;
      case SplitStyle.broSplit:          return Icons.fitness_center_rounded;
      case SplitStyle.dailySingleMuscle: return Icons.radio_button_checked_rounded;
      case SplitStyle.myOwnWay:          return Icons.edit_rounded;
    }
  }
}

// ════════════════════════════════════════════════
// STEP 5 — Weak Muscle (optional)
// ════════════════════════════════════════════════
class _Step5 extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  static const _muscles = [
    {'key': 'chest',     'label': 'Chest'},
    {'key': 'back',      'label': 'Back'},
    {'key': 'legs',      'label': 'Legs'},
    {'key': 'shoulders', 'label': 'Shoulders'},
    {'key': 'arms',      'label': 'Arms'},
    {'key': 'core',      'label': 'Core'},
  ];

  static IconData _muscleIcon(String key) {
    switch (key) {
      case 'chest':     return Icons.fitness_center_rounded;
      case 'back':      return Icons.accessibility_new_rounded;
      case 'legs':      return Icons.directions_run_rounded;
      case 'shoulders': return Icons.sports_handball_rounded;
      case 'arms':      return Icons.back_hand_rounded;
      case 'core':      return Icons.local_fire_department_rounded;
      default:          return Icons.fitness_center_rounded;
    }
  }

  const _Step5({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.lg),
        Text('Any muscle to focus on?', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 28,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('New to gym? No worries — skip this. We\'ll adjust as you train.',
          style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 14, height: 1.5)),
        const SizedBox(height: AppSpacing.xxl),

        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: _muscles.map((m) {
            final isSelected = selected == m['key'];
            return GestureDetector(
              onTap: () => onSelect(m['key']!),
              child: AnimatedScale(
                scale: isSelected ? 1.03 : 1.0,
                duration: AppDurations.slow,
                curve: AppCurves.primary,
                child: AnimatedContainer(
                  duration: AppDurations.slow,
                  curve: AppCurves.primary,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.gold.withValues(alpha: 0.16),
                              AppColors.gold.withValues(alpha: 0.05),
                            ],
                          )
                        : null,
                    color: isSelected ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.75)
                          : AppColors.divider,
                      width: isSelected ? 1.2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.16),
                        blurRadius: 18, spreadRadius: -2, offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14, offset: const Offset(0, 8),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_muscleIcon(m['key']!),
                          color: isSelected ? AppColors.gold : AppColors.textMuted,
                          size: 26),
                      const SizedBox(height: 6),
                      Text(m['label']!, style: GoogleFonts.inter(
                          color: isSelected ? AppColors.gold : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.xl),

        GestureDetector(
          onTap: () => onSelect(''),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected.isEmpty ? AppColors.bgCard : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected.isEmpty
                    ? AppColors.gold.withValues(alpha: 0.3)
                    : AppColors.divider,
              ),
            ),
            child: Center(
              child: Text(
                selected.isEmpty
                    ? '✓ Skip — no preference yet'
                    : 'Skip — no preference yet',
                style: GoogleFonts.inter(
                    color: selected.isEmpty ? AppColors.gold : AppColors.textMuted,
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// CTA BUTTON
// ════════════════════════════════════════════════
class _CTAButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _CTAButton({required this.label, required this.enabled, required this.onTap});
  @override State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: AppDurations.instant,
        reverseDuration: AppDurations.fast);
    _s = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _c, curve: AppCurves.smooth));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) { if (widget.enabled) _c.forward(); },
    onTapUp:   (_) { _c.reverse(); if (widget.enabled) widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: AnimatedContainer(
      duration: AppDurations.normal,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: widget.enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF6E27A), Color(0xFFD4AF37), Color(0xFF8B6914)],
                stops: [0.0, 0.52, 1.0],
              )
            : null,
        color: widget.enabled ? null : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.enabled
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.borderSoft,
          width: 0.8,
        ),
        boxShadow: widget.enabled ? [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.20),
            blurRadius: 22, offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18, offset: const Offset(0, 10),
          ),
        ] : [],
      ),
      child: Text(widget.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
              color: widget.enabled ? Colors.black : AppColors.textMuted,
              fontSize: 18, fontWeight: FontWeight.w900)),
    )),
  );
}

// ════════════════════════════════════════════════
// GOAL / LEVEL / ACTIVITY tiles (unchanged)
// ════════════════════════════════════════════════
class _GoalTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GoalTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedScale(
      scale: selected ? 1.03 : 1.0,
      duration: AppDurations.normal, curve: AppCurves.primary,
      child: AnimatedContainer(
        duration: AppDurations.normal, curve: AppCurves.primary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.gold.withValues(alpha: 0.14),
                           AppColors.gold.withValues(alpha: 0.05)])
              : null,
          color: selected ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.75) : AppColors.borderSoft,
            width: selected ? 1.2 : 0.5,
          ),
          boxShadow: selected ? [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.14),
              blurRadius: 18, spreadRadius: -3, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(label, textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 13, letterSpacing: 0.2, fontWeight: FontWeight.w800)),
        ),
      ),
    ),
  ));
}

class _LevelTile extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _LevelTile({required this.label, required this.sub,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedScale(
      scale: selected ? 1.03 : 1.0,
      duration: AppDurations.normal, curve: AppCurves.primary,
      child: AnimatedContainer(
        duration: AppDurations.normal, curve: AppCurves.primary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.gold.withValues(alpha: 0.14),
                           AppColors.gold.withValues(alpha: 0.05)])
              : null,
          color: selected ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.75) : AppColors.borderSoft,
            width: selected ? 1.2 : 0.5,
          ),
          boxShadow: selected ? [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.14),
              blurRadius: 18, spreadRadius: -3, offset: const Offset(0, 4))] : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.rajdhani(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 12, letterSpacing: 0.2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  ));
}

class _ActivityTile extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _ActivityTile({required this.label, required this.sub,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedScale(
      scale: selected ? 1.015 : 1.0,
      duration: AppDurations.normal, curve: AppCurves.primary,
      child: AnimatedContainer(
        duration: AppDurations.normal, curve: AppCurves.primary,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.gold.withValues(alpha: 0.12),
                           AppColors.gold.withValues(alpha: 0.04)])
              : null,
          color: selected ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.75) : AppColors.borderSoft,
            width: selected ? 1.2 : 0.5,
          ),
          boxShadow: selected ? [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.12),
              blurRadius: 18, spreadRadius: -4, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.gold : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.borderMedium,
                width: 1.4,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 11)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.rajdhani(
                color: selected ? AppColors.gold : AppColors.textPrimary,
                fontSize: 15, letterSpacing: 0.6, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 11, height: 1.35)),
          ])),
        ]),
      ),
    ),
  );
}
