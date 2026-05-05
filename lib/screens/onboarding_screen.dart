// lib/screens/onboarding_screen.dart — Phase 3
// 3-step premium onboarding:
//   Step 1 — Welcome + Name
//   Step 2 — Body stats (age, weight, height, gender)
//   Step 3 — Goal + Level + Activity
// Saves to AppProvider.updateProfile() and marks onboarding complete
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
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

  // Step 1
  final _nameCtrl = TextEditingController();

  // Step 2
  final _ageCtrl    = TextEditingController(text: '25');
  final _weightCtrl = TextEditingController(text: '70');
  final _heightCtrl = TextEditingController(text: '170');
  String _gender = 'male';

  // Step 3
  String _goal     = 'muscle_gain';
  String _level    = 'beginner';
  String _activity = 'Moderate';

  // Step 4
  String _weakMuscle = '';

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
    if (_page < 3) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  void _finish() {
    final ap = context.read<AppProvider>();
    ap.updateProfile(ap.profile.copyWith(
      name:          _nameCtrl.text.trim().isEmpty
                         ? 'Champion' : _nameCtrl.text.trim(),
      age:           int.tryParse(_ageCtrl.text)    ?? 25,
      weightKg:      double.tryParse(_weightCtrl.text) ?? 70.0,
      heightCm:      double.tryParse(_heightCtrl.text) ?? 170.0,
      gender:        _gender,
      goal:          _goal,
      level:         _level,
      activityLevel: _activity,
    ));
    // Save weak muscle preference
    if (_weakMuscle.isNotEmpty) {
      ap.settings.update('weakMusclePreference', _weakMuscle);
    }
    ap.completeOnboarding();
    ap.generateAIWorkout().catchError((_) {});
    HapticFeedback.heavyImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  bool get _canNext {
    if (_page == 0) return _nameCtrl.text.trim().isNotEmpty;
    return true;
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
              colors: [
                AppColors.gold.withValues(alpha: 0.07),
                Colors.transparent,
              ],
            )),
          )),
        ),

        SafeArea(
          child: Column(children: [
            // Progress indicator
            _ProgressBar(current: _page, total: 4),
            const SizedBox(height: AppSpacing.lg),

            // Page content
            Expanded(child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(nameCtrl: _nameCtrl,
                    onChanged: (_) => setState(() {})),
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
                    onGoal:     (v) => setState(() => _goal = v),
                    onLevel:    (v) => setState(() => _level = v),
                    onActivity: (v) => setState(() => _activity = v)),
                _Step4(
                    selected: _weakMuscle,
                    onSelect: (v) => setState(() => _weakMuscle = v)),
              ],
            )),

            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              child: _CTAButton(
                label: _page < 2 ? 'Continue →' : 'Start My Journey 🚀',
                enabled: _canNext,
                onTap: _next,
              ),
            ),
          ]),
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
      children: List.generate(total, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            decoration: BoxDecoration(
              gradient: i <= current ? AppGradients.gold : null,
              color: i <= current ? null : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(2),
              boxShadow: i <= current ? [BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 6)] : [],
            ),
          ),
        ),
      )),
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

      // App icon + greeting
      Container(
        width: 90, height: 90,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: AppGradients.gold),
        child: Center(child: Icon(
            Icons.fitness_center_rounded,
            color: Colors.black, size: 42)),
      ),
      const SizedBox(height: AppSpacing.xl),

      Text('Welcome to', style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 16)),
      const SizedBox(height: 4),
      Text('GymTracker Pro', style: GoogleFonts.rajdhani(
          color: AppColors.gold, fontSize: 36,
          fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: AppSpacing.xs),
      Text('PREMIUM', style: GoogleFonts.inter(
          color: AppColors.gold, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 4)),

      const SizedBox(height: AppSpacing.xxl),

      // Feature bullets
      ...[
        ('🏋️', 'AI-powered workout plans'),
        ('📊', 'Track every rep, set & PR'),
        ('🔥', 'Streak & XP gamification'),
        ('🤖', 'Personal AI coach'),
      ].map((f) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(f.$1,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(f.$2, style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w500)),
        ]),
      )),

      const SizedBox(height: AppSpacing.xxl),

      // Name input
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("What's your name?", style: GoogleFonts.rajdhani(
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
            hintText: 'Enter your name',
            hintStyle: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 15),
            filled: true, fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppColors.gold, width: 1.5)),
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

      Text('About You', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 30,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: AppSpacing.xs),
      Text('We\'ll personalize your plan around your body.',
          style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 14)),

      const SizedBox(height: AppSpacing.xxl),

      // Gender selector
      Text('Gender', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _GenderTile(label: 'Male',   emoji: '👨',
            selected: gender == 'male',
            onTap: () => onGender('male')),
        const SizedBox(width: AppSpacing.md),
        _GenderTile(label: 'Female', emoji: '👩',
            selected: gender == 'female',
            onTap: () => onGender('female')),
      ]),

      const SizedBox(height: AppSpacing.xl),

      // Stats fields
      Text('Body Stats', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _StatField(
            ctrl: ageCtrl, label: 'Age', unit: 'yrs',
            icon: '🎂')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatField(
            ctrl: weightCtrl, label: 'Weight', unit: 'kg',
            icon: '⚖️', isDecimal: true)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatField(
            ctrl: heightCtrl, label: 'Height', unit: 'cm',
            icon: '📏', isDecimal: true)),
      ]),

      const SizedBox(height: AppSpacing.xxl),

      // Info cards
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(
            'Your stats help us calculate your TDEE (daily calorie needs) and personalize workouts.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12,
                height: 1.4),
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
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 0.5,
        ),
        boxShadow: selected ? [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.20),
            blurRadius: 12)] : [],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: GoogleFonts.rajdhani(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    ),
  ));
}

class _StatField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, unit, icon;
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
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: AppSpacing.xs),
      TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
        style: GoogleFonts.rajdhani(
            color: AppColors.gold, fontSize: 22,
            fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          isDense: true, border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      Text(unit, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 10,
          fontWeight: FontWeight.w600)),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 10)),
    ]),
  );
}

// ════════════════════════════════════════════════
// STEP 3 — Goal + Level + Activity
// ════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  final String goal, level, activity;
  final ValueChanged<String> onGoal, onLevel, onActivity;

  const _Step3({
    required this.goal, required this.level, required this.activity,
    required this.onGoal, required this.onLevel, required this.onActivity,
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
      Text('AI will build your plan around these.',
          style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 14)),

      const SizedBox(height: AppSpacing.xl),

      // Fitness Goal
      Text('Primary Goal', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _GoalTile(emoji: '🔥', label: 'Fat Loss',
            selected: goal == 'fat_loss',
            onTap: () => onGoal('fat_loss')),
        const SizedBox(width: AppSpacing.sm),
        _GoalTile(emoji: '💪', label: 'Muscle Gain',
            selected: goal == 'muscle_gain',
            onTap: () => onGoal('muscle_gain')),
        const SizedBox(width: AppSpacing.sm),
        _GoalTile(emoji: '⚡', label: 'Strength',
            selected: goal == 'strength',
            onTap: () => onGoal('strength')),
      ]),

      const SizedBox(height: AppSpacing.xl),

      // Training Level
      Text('Training Level', style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 13,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _LevelTile(emoji: '🌱', label: 'Beginner', sub: '< 1 year',
            selected: level == 'beginner',
            onTap: () => onLevel('beginner')),
        const SizedBox(width: AppSpacing.sm),
        _LevelTile(emoji: '📈', label: 'Intermediate', sub: '1-3 years',
            selected: level == 'intermediate',
            onTap: () => onLevel('intermediate')),
        const SizedBox(width: AppSpacing.sm),
        _LevelTile(emoji: '🏆', label: 'Advanced', sub: '3+ years',
            selected: level == 'advanced',
            onTap: () => onLevel('advanced')),
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
            label: a,
            sub: _activitySub(a),
            selected: activity == a,
            onTap: () => onActivity(a),
          )).toList()),
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

class _GoalTile extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _GoalTile({required this.emoji, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 10, fontWeight: FontWeight.w700,
            )),
      ]),
    ),
  ));
}

class _LevelTile extends StatelessWidget {
  final String emoji, label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _LevelTile({required this.emoji, required this.label,
      required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 9.5, fontWeight: FontWeight.w800)),
        Text(sub, style: GoogleFonts.inter(
            color: AppColors.textMuted, fontSize: 8.5)),
      ]),
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
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.10)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderSoft,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.gold : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.borderMedium,
              width: 1.5,
            ),
          ),
          child: selected ? const Icon(Icons.check_rounded,
              color: Colors.black, size: 12) : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(label, style: GoogleFonts.inter(
              color: selected ? AppColors.gold : AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700)),
          Text(sub, style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 11)),
        ])),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// CTA BUTTON
// ════════════════════════════════════════════════
class _CTAButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _CTAButton({required this.label, required this.enabled,
      required this.onTap});
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
    _s = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) { if (widget.enabled) _c.forward(); },
    onTapUp:   (_) { _c.reverse(); if (widget.enabled) widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: widget.enabled
            ? const LinearGradient(
                colors: [Color(0xFFFFCC00), Color(0xFFFF9900)])
            : null,
        color: widget.enabled ? null : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.enabled ? [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 20, offset: const Offset(0, 4))] : [],
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
// STEP 4 — WEAK MUSCLE
// ════════════════════════════════════════════════
class _Step4 extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  static const _muscles = [
    {'key': 'chest',     'label': 'Chest',     'emoji': '💪'},
    {'key': 'back',      'label': 'Back',      'emoji': '🏋️'},
    {'key': 'legs',      'label': 'Legs',      'emoji': '🦵'},
    {'key': 'shoulders', 'label': 'Shoulders', 'emoji': '🔝'},
    {'key': 'arms',      'label': 'Arms',      'emoji': '💪'},
    {'key': 'core',      'label': 'Core',      'emoji': '🔥'},
  ];

  const _Step4({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Any weak point? 🎯',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI will give this muscle extra love. Optional — skip if unsure.',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: _muscles.map((m) {
              final isSelected = selected == m['key'];
              return GestureDetector(
                onTap: () => onSelect(m['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.18),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m['emoji']!,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        m['label']!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Skip option
          GestureDetector(
            onTap: () => onSelect(''),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected.isEmpty
                    ? AppColors.bgCard
                    : Colors.transparent,
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
                      ? '✓ Skip — no specific weakness'
                      : 'Skip — no specific weakness',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: selected.isEmpty
                        ? AppColors.gold
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

