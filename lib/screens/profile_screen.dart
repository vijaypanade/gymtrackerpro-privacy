// lib/screens/profile_screen.dart — v11.0 ATHLETE IDENTITY
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/health_platform_service.dart';
import '../services/rest_timer_service.dart';
import 'login_screen.dart';

import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../models/models.dart';
import '../models/split_template.dart';
import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/profile_rank_badge.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import '../utils/weight_converter.dart';
import 'premium_paywall_screen.dart';
import '../utils/app_routes.dart';
import '../widgets/profile/athlete_timeline_card.dart';

class H {
  static void heavy()     => HapticFeedback.heavyImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void light()     => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success()   => HapticFeedback.heavyImpact();
  static void tap()       => HapticFeedback.lightImpact();
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _name, _age, _weight, _height;
  bool _editing         = false;
  bool _detailsExpanded = true;
  String _goal = 'muscle_gain', _level = 'beginner',
      _trainer = 'friendly', _gender = 'male', _activity = 'Moderate',
      _workoutTime = 'evening',
      _bodyType = 'mesomorph';

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
    _workoutTime = p.workoutTime;
    _bodyType = p.bodyType;
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
      name:           _name.text.trim().isEmpty ? 'Athlete' : _name.text.trim(),
      age:            int.tryParse(_age.text)       ?? 25,
      weightKg:       double.tryParse(_weight.text)  ?? 70.0,
      heightCm:       double.tryParse(_height.text)  ?? 170.0,
      goal:           _goal,     level:         _level,
      trainerType:    _trainer,  gender:        _gender,
      activityLevel:  _activity,
      workoutTime:    _workoutTime,
      bodyType:       _bodyType,
    ));
    setState(() { _editing = false; _detailsExpanded = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      appSnack('Profile updated!'));
  }

  // RFC-002.4 — permanently delete account + purge all cloud and local data.
  Future<void> _deleteAccount() async {
    // Step 1: first confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
          SizedBox(width: 10),
          Text('Delete Account?', style: TextStyle(
            fontFamily: 'Rajdhani', color: Colors.red,
            fontWeight: FontWeight.w900, fontSize: 20)),
        ]),
        content: const Text(
          'This will permanently delete your account and all your data — workouts, history, streaks, and progress.\n\nThis cannot be undone.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red.withValues(alpha: 0.15),
              foregroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: second confirmation — re-states permanence clearly
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Are you absolutely sure?', style: TextStyle(
            fontFamily: 'Rajdhani', color: Colors.red,
            fontWeight: FontWeight.w900, fontSize: 20)),
        content: const Text(
          'You will be asked to sign in with Google to confirm your identity, then your account will be deleted permanently.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete My Account', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (doubleConfirmed != true || !mounted) return;

    // Step 3: re-authenticate + delete (Google sign-in sheet appears here)
    final deleted = await AuthService.instance.deleteAccount();
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Could not delete account. Sign out and sign back in, then try again.',
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    // Step 4: clear all local data, then navigate to LoginScreen
    await context.read<AppProvider>().resetAllData();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Text('Reset All Data?', style: TextStyle(
            fontFamily: 'Rajdhani', color: Colors.white,
            fontWeight: FontWeight.w900, fontSize: 20)),
        ]),
        content: const Text(
          'This will permanently delete all your workout history, logs, streak, and profile. You will go through onboarding again.\n\nThis cannot be undone.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset Everything',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Are you sure?', style: TextStyle(
            fontFamily: 'Rajdhani', color: Colors.orange,
            fontWeight: FontWeight.w900, fontSize: 20)),
        content: const Text(
          'All data will be gone. Tap "Delete" to confirm.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red.withValues(alpha: 0.15), foregroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (doubleConfirmed != true || !mounted) return;

    await context.read<AppProvider>().resetAllData();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const OnboardingScreen()),
      (_) => false,
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Colors.red, size: 22),
          SizedBox(width: 10),
          Text('Sign Out?', style: TextStyle(
            fontFamily: 'Rajdhani', color: Colors.white,
            fontWeight: FontWeight.w900, fontSize: 20)),
        ]),
        content: const Text(
          'Your data is saved to your account. You can log back in anytime.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red.withValues(alpha: 0.15), foregroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    RestTimerService().stop();
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        fadeRoute(const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector2<AppProvider, GamificationProvider, ({
      UserProfile profile,
      int totalWorkouts, int currentStreak, int longestStreak,
      int activeWeeks,
      XPSystem xp,
      double tdee,
      bool isPremium,
      bool healthConnected,
      int recoveryScore,
      double sleepHours,
      int todaySteps,
      double lifetimeKg,
      double? restingHeartRate,
      double activeEnergyKcal,
      SplitStyle splitStyle,
    })>(
      selector: (_, ap, gp) {
        final rs  = ap.recoveryState;
        return (
          profile:           ap.profile,
          totalWorkouts:     ap.streak.totalWorkouts,
          currentStreak:     ap.streak.currentStreak,
          longestStreak:     ap.streak.longestStreak,
          activeWeeks:       ap.activeWeeks,
          xp:                gp.xp,
          tdee:              ap.tdee,
          isPremium:         ap.isPremium,
          healthConnected:   ap.healthConnectLinked,
          recoveryScore:     rs.overallScore.round(),
          sleepHours:        ap.coachSleepHours,
          todaySteps:        ap.healthTodaySteps,
          lifetimeKg:        ap.lifetimeVolumeKg,
          restingHeartRate:  ap.healthRHR,
          activeEnergyKcal:  ap.healthActiveEnergyKcal,
          splitStyle:        ap.splitStyle,
        );
      },
      builder: (context, d, _) {
        final p      = d.profile;
        final xp     = d.xp;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Stack(children: [
            Positioned(top: -80, left: -60, right: -60,
              child: IgnorePointer(child: Container(
                height: 280,
                decoration: BoxDecoration(gradient: RadialGradient(
                  center: Alignment.topCenter, radius: 0.7,
                  colors: [AppColors.gold.withValues(alpha: 0.05), Colors.transparent],
                )),
              )),
            ),
            CustomScrollView(
              physics: Platform.isIOS
                  ? const BouncingScrollPhysics()
                  : const ClampingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  floating: false, snap: false, pinned: true, elevation: 0,
                  titleSpacing: AppSpacing.lg,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Profile', style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textPrimary, fontSize: 22,
                          fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                      Text('Your LiftOn Identity', style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textMuted.withValues(alpha: 0.55), fontSize: 13)),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: _EditButton(
                        editing: _editing,
                        onTap: () {
                          if (_editing) {
                            _save();
                          } else {
                            H.light();
                            setState(() { _editing = true; _detailsExpanded = true; });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      20, AppSpacing.xs, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── P1: ATHLETE IDENTITY HERO ──────────────────────────
                      _FI(child: _HeroCard(
                          p: p, xp: xp,
                          totalWorkouts: d.totalWorkouts,
                          currentStreak: d.currentStreak,
                          longestStreak: d.longestStreak,
                          activeWeeks:  d.activeWeeks,
                          recoveryScore: d.recoveryScore,
                          lifetimeKg:   d.lifetimeKg,
                          splitStyle:   d.splitStyle)),
                      const SizedBox(height: 10),

                      // ── P3: ATHLETE TIMELINE ───────────────────────────────
                      const _FI(delay: 60, child: AthleteTimelineCard()),
                      const SizedBox(height: 10),

                      // ── P4: PREMIUM BENEFITS ────────────────────────────────
                      _FI(delay: 70, child: _SubscriptionCard(isPremium: d.isPremium)),
                      const SizedBox(height: 10),

                      // ── P5: HEALTH CONNECT ──────────────────────────────────
                      _FI(delay: 78, child: _HealthConnectCard(
                        connected:        d.healthConnected,
                        sleepHours:       d.sleepHours,
                        todaySteps:       d.todaySteps,
                        restingHeartRate: d.restingHeartRate,
                        activeEnergyKcal: d.activeEnergyKcal,
                      )),
                      const SizedBox(height: 10),

                      // ── P6: PERSONAL DETAILS (COLLAPSIBLE) ─────────────────
                      _ExpandableLabel(
                        text: 'Personal details',
                        expanded: _detailsExpanded || _editing,
                        onTap: _editing ? null : () {
                          H.light();
                          setState(() => _detailsExpanded = !_detailsExpanded);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: SizedBox(
                          width: double.infinity,
                          child: (_detailsExpanded || _editing)
                              ? _editing
                                  ? _EditForm(
                                      name: _name, age: _age,
                                      weight: _weight, height: _height,
                                      goal: _goal, level: _level,
                                      trainer: _trainer, gender: _gender,
                                      activity: _activity,
                                      bodyType: _bodyType,
                                      onGoal:     (v) => setState(() => _goal = v!),
                                      onLevel:    (v) => setState(() => _level = v!),
                                      onTrainer:  (v) => setState(() => _trainer = v!),
                                      onGender:   (v) => setState(() => _gender = v!),
                                      onActivity: (v) => setState(() => _activity = v!),
                                      onBodyType: (v) => setState(() => _bodyType = v!),
                                      onSave: _save,
                                    )
                                  : _InfoCard(p: p)
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (_detailsExpanded || _editing)
                        const SizedBox(height: AppSpacing.xxl),

                      // ── SIGN OUT (ghost) ────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _signOut,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.logout_rounded,
                                  color: AppColors.textMuted.withValues(alpha: 0.45),
                                  size: 14),
                              const SizedBox(width: 6),
                              Text('Sign Out',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted.withValues(alpha: 0.45),
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // ── DELETE ACCOUNT (RFC-002.4) ──────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _deleteAccount,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_forever_rounded,
                                  color: AppColors.red.withValues(alpha: 0.35),
                                  size: 13),
                              const SizedBox(width: 5),
                              Text('Delete Account',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.red.withValues(alpha: 0.35),
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // ── RESET (near-invisible) ──────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _resetAllData,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('Reset All Data',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textMuted.withValues(alpha: 0.25),
                                fontSize: 13, fontWeight: FontWeight.w400)),
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
// P1 — ATHLETE IDENTITY HERO
// ════════════════════════════════════════════════
// EDIT BUTTON — premium circular icon, animated state transition
// ════════════════════════════════════════════════
class _EditButton extends StatefulWidget {
  final bool editing;
  final VoidCallback onTap;
  const _EditButton({required this.editing, required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isSave = widget.editing;

    return GestureDetector(
      onTapDown:   (_) => _press.forward(),
      onTapUp:     (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: ()  => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSave
                ? AppColors.gold.withValues(alpha: 0.12)
                : const Color(0xFF1C1C1C),
            border: Border.all(
              color: isSave
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1.0,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isSave ? Icons.check_rounded : Icons.edit_outlined,
              key: ValueKey(isSave),
              color: isSave
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.40),
              size: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final UserProfile p;
  final XPSystem xp;
  final int totalWorkouts, currentStreak, longestStreak, recoveryScore, activeWeeks;
  final double lifetimeKg;
  final SplitStyle splitStyle;

  const _HeroCard({
    required this.p, required this.xp,
    required this.totalWorkouts, required this.currentStreak,
    required this.longestStreak, required this.activeWeeks,
    required this.recoveryScore,
    required this.lifetimeKg,
    required this.splitStyle,
  });

  // Dynamic statement driven by real signals — no hardcoded generic copy.
  static String _statement(int streak, int workouts, int recovScore) {
    if (streak >= 30) return '$streak days of straight discipline.';
    if (streak >= 14) return 'Two weeks strong. The body adapts.';
    if (streak >= 7)  return '$streak days strong. Consistency compounds.';
    if (recovScore >= 85) return 'Fully primed. Make today count.';
    if (recovScore < 40)  return 'Recovery is part of the work.';
    if (workouts >= 100)  return '$workouts sessions logged. The record speaks.';
    if (workouts >= 50)   return '$workouts sessions in. Keep the standard high.';
    if (workouts >= 10)   return 'The foundation is forming. Show up.';
    return 'Session one starts the record.';
  }

  // Earned badge based on verified rank/effort — no fake percentiles.
  static String _earnedBadge(UserRank rank, int workouts) {
    if (rank == UserRank.beast)    return 'ELITE ATHLETE';
    if (rank == UserRank.legend)   return 'HIGHLY CONSISTENT';
    if (rank == UserRank.champion) return 'DEDICATED LIFTER';
    if (workouts >= 50)            return 'PEAK PERFORMER';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final badge = _earnedBadge(xp.rank, totalWorkouts);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.07), blurRadius: 28),
        ],
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProfileHeaderBadge(rank: xp.rank),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name — primary identity
            Text(p.name, style: const TextStyle(fontFamily: 'Inter',
                color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.w700)),
            // Rank — secondary, gold
            Text(xp.rank.displayName, style: const TextStyle(fontFamily: 'Rajdhani',
                color: AppColors.gold,
                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.xs),
            if (badge.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25), width: 0.5)),
                child: Text(badge, style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.gold.withValues(alpha: 0.85),
                    fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              _statement(currentStreak, totalWorkouts, recoveryScore),
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted.withValues(alpha: 0.55),
                fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.1),
            ),
          ])),
        ]),

        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: AppSpacing.md),

        // Stat row: Tonnes | Sessions | Streak | Active Weeks
        IntrinsicHeight(child: Row(children: [
          _heroStat(_formatTonnes(lifetimeKg), 'All-Time Volume'),
          _heroDiv(),
          _heroStat('$totalWorkouts', 'Sessions'),
          _heroDiv(),
          _heroStat('${longestStreak}d', 'Best Streak'),
          _heroDiv(),
          _heroStat('${activeWeeks}w', 'Active Weeks'),
        ])),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: AppSpacing.md),

        // Rank Journey Strip
        _RankJourneyStrip(currentRank: xp.rank, progress: xp.rankProgress),

        const SizedBox(height: AppSpacing.sm),
        // Change 6: Numeric XP line
        Row(children: [
          Text(_fmtXP(xp.totalXP), style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.gold.withValues(alpha: 0.85),
              fontSize: 12, fontWeight: FontWeight.w700)),
          Text(' · ', style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.35),
              fontSize: 12)),
          Text('${_fmtXP(xp.xpToNextRank)} to ${xp.nextRankName}',
              style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.55),
                  fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        // Change 4: Weekly XP progress
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('This week', style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.45),
              fontSize: 11, fontWeight: FontWeight.w400)),
          Text('${xp.weeklyXP} / ${xp.weeklyXpGoal} XP',
              style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.65),
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),

        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: AppSpacing.xs),

        // Change 10: ONE data-driven insight
        _buildInsight(currentStreak, totalWorkouts, recoveryScore, xp),

        const SizedBox(height: AppSpacing.xs),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: AppSpacing.xs),

        // Training Style — merged from standalone card (tap → Tools tab)
        Builder(builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final shell = ctx.findAncestorStateOfType<MainShellState>();
            shell?.changeTab(3);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(width: 2, height: 12, decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Training style', style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted.withValues(alpha: 0.50),
                fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(width: 8),
              Text(
                splitStyle == SplitStyle.aiAdaptive
                    ? 'Adaptive Split' : splitStyle.label,
                style: const TextStyle(
                  fontFamily: 'Inter', color: AppColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.30), size: 14),
            ]),
          ),
        )),
      ]),
    );
  }

  /// Formats kg as tonnes with lowercase SI unit, dropping trailing `.0`.
  static String _formatTonnes(double kg) {
    final t = kg / 1000;
    return t == t.truncateToDouble() ? '${t.toInt()}t' : '${t.toStringAsFixed(1)}t';
  }

  /// Formats XP as compact integer with K suffix for ≥1000.
  static String _fmtXP(int xp) {
    if (xp >= 1000) {
      final k = xp / 1000;
      return k == k.truncateToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$xp';
  }

  static Widget _heroStat(String value, String label) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani',
          color: AppColors.textPrimary,
          fontSize: 22, fontWeight: FontWeight.w900, height: 1.0),
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted.withValues(alpha: 0.50), fontSize: 11,
          fontWeight: FontWeight.w400, letterSpacing: 0.2),
          textAlign: TextAlign.center),
    ]),
  );

  static Widget _heroDiv() => Container(
      width: 0.5, margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.divider.withValues(alpha: 0.45));

  static Widget _buildInsight(int streak, int workouts, int recovery, XPSystem xp) {
    final String text;
    if (streak >= 14) {
      text = '🔥 $streak-day streak — elite consistency.';
    } else if (streak >= 7) {
      text = '🔥 $streak days in a row — keep the chain alive.';
    } else if (recovery >= 85) {
      text = '💚 Recovery is high — ideal day for max effort.';
    } else if (xp.xpToNextRank <= 200 && xp.rank != UserRank.beast) {
      text = '⚡ ${xp.xpToNextRank} XP from ${xp.nextRankName} — push now.';
    } else if (workouts % 50 == 0 && workouts > 0) {
      text = '🏆 $workouts sessions — a milestone worth owning.';
    } else if (workouts % 10 == 0 && workouts > 0) {
      text = '📊 $workouts sessions logged. The record is building.';
    } else {
      text = '📈 Every session moves the line. Show up again.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textMuted.withValues(alpha: 0.55),
          fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.1)),
    );
  }
}


// ════════════════════════════════════════════════
// RANK JOURNEY STRIP
// ════════════════════════════════════════════════
class _RankJourneyStrip extends StatefulWidget {
  final UserRank currentRank;
  final double   progress; // 0.0–1.0 within current tier

  const _RankJourneyStrip({required this.currentRank, required this.progress});

  @override
  State<_RankJourneyStrip> createState() => _RankJourneyStripState();
}

class _RankJourneyStripState extends State<_RankJourneyStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fill;

  static const _ranks = UserRank.values; // recruit→warrior→gladiator→champion→legend→beast

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fill = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _ranks.indexOf(widget.currentRank);

    return AnimatedBuilder(
      animation: _fill,
      builder: (_, __) {
        return Column(
          children: [
            // ── Dot + line strip ─────────────────────────────────────
            SizedBox(
              height: 28,
              child: Row(
                children: List.generate(_ranks.length, (i) {
                  final isDone    = i < currentIdx;
                  final isCurrent = i == currentIdx;
                  final isLast    = i == _ranks.length - 1;

                  // Segment fill for the connecting line after this dot
                  double segFill = 0.0;
                  if (isDone) segFill = 1.0;
                  if (isCurrent) segFill = _fill.value * widget.progress;

                  return Expanded(
                    child: Row(children: [
                      // Dot
                      _RankDot(
                        done: isDone,
                        current: isCurrent,
                        pulseValue: _fill.value,
                      ),
                      // Connecting line (skip after last dot)
                      if (!isLast)
                        Expanded(
                          child: Stack(children: [
                            // Base line
                            Container(
                              height: 1.5,
                              color: const Color(0xFF2A2A2A),
                            ),
                            // Filled portion
                            FractionallySizedBox(
                              widthFactor: segFill,
                              child: Container(
                                height: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.gold.withValues(alpha: 0.9),
                                      AppColors.gold.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  );
                }),
              ),
            ),

            const SizedBox(height: 6),

            // ── Rank labels ──────────────────────────────────────────
            Row(
              children: List.generate(_ranks.length, (i) {
                final isCurrent = i == _ranks.indexOf(widget.currentRank);
                final isDone    = i < _ranks.indexOf(widget.currentRank);
                return Expanded(
                  child: Text(
                    _ranks[i].displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent
                          ? AppColors.gold
                          : isDone
                              ? AppColors.textMuted.withValues(alpha: 0.55)
                              : AppColors.textMuted.withValues(alpha: 0.25),
                      letterSpacing: 0.3,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _RankDot extends StatelessWidget {
  final bool   done;
  final bool   current;
  final double pulseValue; // 0.0–1.0 from animation

  const _RankDot({required this.done, required this.current, required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.gold,
        ),
      );
    }
    if (current) {
      // Pulsing outline dot
      return Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.6 + 0.4 * pulseValue),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15 * pulseValue),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 4, height: 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold,
            ),
          ),
        ),
      );
    }
    // Future rank — empty grey circle
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1.5),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// P4 — PREMIUM
// ════════════════════════════════════════════════
class _SubscriptionCard extends StatelessWidget {
  final bool isPremium;
  const _SubscriptionCard({required this.isPremium});

  static const _features = [
    'Coaching',
    'Recovery Insights',
    'Exercise Mastery',
    'Advanced Analytics',
    'PR Tracking',
  ];

  @override
  Widget build(BuildContext context) {
    if (isPremium) return _buildPremiumActive(context);
    return _buildUpgradeCTA(context);
  }

  Widget _buildPremiumActive(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
      ),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Text('Premium', style: TextStyle(
          fontFamily: 'Inter', color: AppColors.gold,
          fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0)),
        const SizedBox(width: 6),
        Icon(Icons.check_circle_rounded,
            color: AppColors.gold.withValues(alpha: 0.65), size: 12),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse(Platform.isIOS
                ? 'https://apps.apple.com/account/subscriptions'
                : 'https://play.google.com/store/account/subscriptions');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.45), size: 18),
        ),
      ]),
    );
  }

  static String _personalizedHook(int workouts, String goal) {
    if (workouts >= 100) return '$workouts sessions logged. Your coach should know every one.';
    if (workouts >= 50 && goal == 'strength')   return '$workouts strength sessions — unlock full progressive overload.';
    if (workouts >= 50 && goal == 'fat_loss')   return '$workouts sessions logged. Let coaching do the heavy lifting.';
    if (workouts >= 50)                          return '$workouts sessions strong. Get the coaching system to match.';
    if (workouts >= 10)                          return 'Your training is taking shape. A coach will accelerate it.';
    return 'Unlock the full LiftOn coaching system.';
  }

  Widget _buildUpgradeCTA(BuildContext context) {
    final ap      = context.read<AppProvider>();
    final hookLine = _personalizedHook(
        ap.streak.totalWorkouts, ap.profile.goal);

    return GestureDetector(
      onTap: () => PremiumPaywallScreen.show(context, source: 'profile_cta'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: const Color(0xFF242424), width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(
              gradient: AppGradients.gold,
              borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Premium', style: TextStyle(
              fontFamily: 'Inter', color: AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.30), width: 0.5)),
              child: const Text('Upgrade', style: TextStyle(
                fontFamily: 'Inter', color: AppColors.gold,
                fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(hookLine, style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.65),
              fontSize: 13, fontWeight: FontWeight.w400, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          ..._features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_rounded,
                  color: AppColors.gold.withValues(alpha: 0.55), size: 13),
              const SizedBox(width: 8),
              Text(f, style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted.withValues(alpha: 0.80),
                fontSize: 14, fontWeight: FontWeight.w400)),
            ]),
          )),
          const SizedBox(height: AppSpacing.sm),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Icon(Icons.arrow_forward_rounded,
                color: AppColors.gold.withValues(alpha: 0.55), size: 12),
          ]),
        ]),
      ),
    );
  }
}


// ════════════════════════════════════════════════
// P4b — TRAINING STYLE CARD
// ════════════════════════════════════════════════
class _TrainingStyleCard extends StatelessWidget {
  final SplitStyle splitStyle;
  const _TrainingStyleCard({required this.splitStyle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Switch to Tools tab (index 3) via MainShell
        final shell = context.findAncestorStateOfType<MainShellState>();
        shell?.changeTab(3);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: const Color(0xFF242424), width: 0.5),
        ),
        child: Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(
              color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Training style', style: TextStyle(
                fontFamily: 'Inter', color: AppColors.textMuted,
                fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(height: 2),
              Text(
                splitStyle == SplitStyle.aiAdaptive
                    ? 'Adaptive Split'
                    : splitStyle.label,
                style: const TextStyle(
                  fontFamily: 'Inter', color: AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.45), size: 18),
        ]),
      ),
    );
  }
}

// P5 — HEALTH CONNECT (upgraded)
// ════════════════════════════════════════════════
class _HealthConnectCard extends StatefulWidget {
  final bool    connected;
  final double  sleepHours;
  final int     todaySteps;
  final double? restingHeartRate; // bpm — null if no reading available
  final double  activeEnergyKcal; // kcal burned today — 0 if unavailable

  const _HealthConnectCard({
    required this.connected,
    required this.sleepHours,
    required this.todaySteps,
    this.restingHeartRate,
    this.activeEnergyKcal = 0.0,
  });

  @override
  State<_HealthConnectCard> createState() => _HealthConnectCardState();
}

class _HealthConnectCardState extends State<_HealthConnectCard> {
  bool _loading = false;

  String _formatSteps(int s) =>
      s >= 1000 ? '${(s / 1000).toStringAsFixed(1)}k' : '$s';

  Widget _vDivider() => Container(
    width: 0.5, margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.divider.withValues(alpha: 0.35));

  @override
  Widget build(BuildContext context) {
    if (!widget.connected) return _buildConnect(context);
    return _buildConnected(context);
  }

  Widget _buildConnected(BuildContext context) {
    final hasSleep  = widget.sleepHours > 0;
    final hasSteps  = widget.todaySteps > 0;
    final hasRHR    = widget.restingHeartRate != null;
    final hasEnergy = widget.activeEnergyKcal > 0;
    final hasAnyData = hasSleep || hasSteps || hasRHR || hasEnergy;
    final hasRow2    = hasRHR || hasEnergy;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: const Color(0xFF242424), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 2, height: 12, decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 7),
          const Text('Health connect', style: TextStyle(
            fontFamily: 'Inter', color: AppColors.textPrimary,
            fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.20), width: 0.5)),
            child: Text('Connected', style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.gold.withValues(alpha: 0.85),
              fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (!hasAnyData)
          Text('Syncing health data…',
              style: TextStyle(fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.55), fontSize: 13))
        else if (hasSleep)
          // Sleep present → 2-row layout: [Sleep | Steps] then [RHR | Energy]
          Column(children: [
            IntrinsicHeight(child: Row(children: [
              Expanded(child: _HealthCell(
                label: 'Sleep',
                value: '${widget.sleepHours.toStringAsFixed(1)}h',
                icon: Icons.bedtime_outlined)),
              if (hasSteps) ...[
                _vDivider(),
                Expanded(child: _HealthCell(
                  label: 'Steps',
                  value: _formatSteps(widget.todaySteps),
                  icon: Icons.directions_walk_rounded)),
              ],
            ])),
            if (hasRow2) ...[
              const SizedBox(height: 10),
              Container(height: 0.5, color: AppColors.divider.withValues(alpha: 0.25)),
              const SizedBox(height: 10),
              IntrinsicHeight(child: Row(children: [
                if (hasRHR) Expanded(child: _HealthCell(
                  label: 'Resting HR',
                  value: '${widget.restingHeartRate!.round()} bpm',
                  icon: Icons.favorite_border_rounded)),
                if (hasRHR && hasEnergy) _vDivider(),
                if (hasEnergy) Expanded(child: _HealthCell(
                  label: 'Active kcal',
                  value: '${widget.activeEnergyKcal.round()}',
                  icon: Icons.whatshot_rounded)),
              ])),
            ],
          ])
        else
          // No sleep → single row: Steps | RHR | Energy (up to 3 columns)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IntrinsicHeight(child: Row(children: [
              if (hasSteps) Expanded(child: _HealthCell(
                label: 'Steps',
                value: _formatSteps(widget.todaySteps),
                icon: Icons.directions_walk_rounded)),
              if (hasSteps && hasRHR) _vDivider(),
              if (hasRHR) Expanded(child: _HealthCell(
                label: 'Resting HR',
                value: '${widget.restingHeartRate!.round()} bpm',
                icon: Icons.favorite_border_rounded)),
              if ((hasSteps || hasRHR) && hasEnergy) _vDivider(),
              if (hasEnergy) Expanded(child: _HealthCell(
                label: 'Active kcal',
                value: '${widget.activeEnergyKcal.round()}',
                icon: Icons.whatshot_rounded)),
            ])),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.bedtime_outlined,
                size: 11,
                color: AppColors.textMuted.withValues(alpha: 0.40)),
              const SizedBox(width: 5),
              Text(Platform.isIOS
                ? 'No sleep data — wear Apple Watch to bed to enable'
                : 'No sleep data — connect a sleep app in Health Connect',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted.withValues(alpha: 0.40),
                  fontSize: 11, fontWeight: FontWeight.w400)),
            ]),
          ]),
      ]),
    );
  }

  Widget _buildConnect(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : () async {
        H.tap();
        setState(() => _loading = true);
        final ok = await context.read<AppProvider>().requestHealthPermissions();
        if (!mounted) return;
        setState(() => _loading = false);
        if (!ok) {
          // Permission not granted — open HC app or Play Store
          await HealthPlatformService.instance.openOrInstall();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: const Color(0xFF242424), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.18), width: 0.5)),
            child: Icon(Icons.favorite_border_rounded,
                color: AppColors.gold.withValues(alpha: 0.65), size: 16)),
          const SizedBox(width: 12),
          const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Health Connect', style: TextStyle(
              fontFamily: 'Inter', color: AppColors.textSecondary,
              fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('Connect to track sleep and recovery',
              style: TextStyle(
                fontFamily: 'Inter', color: AppColors.textMuted,
                fontSize: 13, fontWeight: FontWeight.w400)),
          ])),
          const SizedBox(width: 8),
          if (_loading)
            SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textMuted.withValues(alpha: 0.50)))
          else
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.textMuted.withValues(alpha: 0.40)),
        ]),
      ),
    );
  }
}

class _HealthCell extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _HealthCell({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.textMuted.withValues(alpha: 0.45), size: 15),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani',
          color: AppColors.textPrimary, fontSize: 22,
          fontWeight: FontWeight.w900, height: 1.0)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted.withValues(alpha: 0.50), fontSize: 11,
          fontWeight: FontWeight.w400, letterSpacing: 0.1)),
    ],
  );
}


// ════════════════════════════════════════════════
// INFO CARD — compact 3×2 grid (read view)
// ════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final UserProfile p;
  const _InfoCard({required this.p});

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle_gain': return 'Muscle Gain';
      case 'fat_loss':    return 'Fat Loss';
      case 'strength':    return 'Strength';
      default:            return g;
    }
  }

  String _trainerLabel(String t) {
    switch (t) {
      case 'friendly':     return 'Friendly';
      case 'strict':       return 'Strict';
      case 'military':     return 'Military';
      case 'motivational': return 'Hype';
      default:             return t;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F0F0F),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      border: Border.all(color: const Color(0xFF242424), width: 0.5),
    ),
    child: Column(children: [
      Row(children: [
        Expanded(child: _InfoField(label: 'Goal',   value: _goalLabel(p.goal))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _InfoField(label: 'Level',  value: '${p.level[0].toUpperCase()}${p.level.substring(1)}')),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _InfoField(label: 'Age',    value: '${p.age} yrs')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _InfoField(label: 'Weight', value: WeightConverter.display(p.weightKg, p.weightUnit))),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _InfoField(label: 'Coach',    value: _trainerLabel(p.trainerType))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _InfoField(label: 'Activity', value: p.activityLevel)),
      ]),
    ]),
  );
}

class _InfoField extends StatelessWidget {
  final String label, value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
    decoration: BoxDecoration(
      color: const Color(0xFF161616),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.07), width: 0.6),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted.withValues(alpha: 0.45), fontSize: 11,
          fontWeight: FontWeight.w400, letterSpacing: 0)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontFamily: 'Inter',
              color: AppColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}


// ════════════════════════════════════════════════
// EDIT FORM — 3 grouped sections
// ════════════════════════════════════════════════
class _EditForm extends StatelessWidget {
  final TextEditingController name, age, weight, height;
  final String goal, level, trainer, gender, activity, bodyType;
  final ValueChanged<String?> onGoal, onLevel, onTrainer, onGender, onActivity,
      onBodyType;
  final VoidCallback onSave;

  const _EditForm({
    required this.name, required this.age,
    required this.weight, required this.height,
    required this.goal, required this.level,
    required this.trainer, required this.gender, required this.activity,
    required this.bodyType,
    required this.onGoal, required this.onLevel,
    required this.onTrainer, required this.onGender, required this.onActivity,
    required this.onBodyType,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

    _fSec('Body & physical'),
    const SizedBox(height: AppSpacing.sm),
    _TF(ctrl: name, label: 'Name', cap: TextCapitalization.words),
    const SizedBox(height: AppSpacing.sm),
    Row(children: [
      Expanded(child: _TF(ctrl: age,    label: 'Age',         isNumber: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TF(ctrl: weight, label: 'Weight (kg)', isDecimal: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TF(ctrl: height, label: 'Height (cm)', isDecimal: true)),
    ]),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Gender', value: gender,
        items: const ['male', 'female'],
        labels: const {'male': 'Male', 'female': 'Female'},
        onChanged: onGender),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Body Type', value: bodyType,
        items: const ['ectomorph', 'mesomorph', 'endomorph'],
        labels: const {'ectomorph': 'Ectomorph (slim)',
          'mesomorph': 'Mesomorph (athletic)',
          'endomorph': 'Endomorph (heavy)'},
        onChanged: onBodyType),

    const SizedBox(height: AppSpacing.md),
    _fSec('Training & goals'),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Goal', value: goal,
        items: const ['muscle_gain', 'fat_loss', 'strength'],
        labels: const {'muscle_gain': 'Muscle Gain',
          'fat_loss': 'Fat Loss', 'strength': 'Strength'},
        onChanged: onGoal),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Training Level', value: level,
        items: const ['beginner', 'intermediate', 'advanced'],
        onChanged: onLevel),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Coach Style', value: trainer,
        items: const ['friendly', 'strict', 'military', 'motivational'],
        labels: const {'friendly': 'Friendly', 'strict': 'Strict',
          'military': 'Military', 'motivational': 'Hype'},
        onChanged: onTrainer),
    const SizedBox(height: AppSpacing.sm),
    _DD(label: 'Activity Level', value: activity,
        items: const ['Sedentary', 'Light', 'Moderate', 'High', 'Very High'],
        onChanged: onActivity),

    const SizedBox(height: 10),
    GoldButton(text: 'Save Profile', width: double.infinity, onTap: onSave),
  ]);
}


// ════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════

Widget _fSec(String title) => Row(children: [
  Container(width: 2, height: 10,
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(2)),
  ),
  const SizedBox(width: 6),
  Text(title, style: TextStyle(fontFamily: 'Inter',
      color: AppColors.textMuted.withValues(alpha: 0.55), fontSize: 12,
      fontWeight: FontWeight.w400, letterSpacing: 0)),
]);

// Expandable section label — shows chevron, toggles expand state.
class _ExpandableLabel extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback? onTap;
  const _ExpandableLabel({required this.text, required this.expanded, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(
          gradient: AppGradients.gold,
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: AppSpacing.sm),
      Text(text, style: TextStyle(fontFamily: 'Inter',
          color: AppColors.textMuted.withValues(alpha: 0.65), fontSize: 13,
          fontWeight: FontWeight.w500, letterSpacing: 0)),
      const Spacer(),
      Icon(
        expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        color: AppColors.textMuted.withValues(alpha: 0.60),
        size: 18),
    ]),
  );
}

// ── Input field ───────────────────────────────────────────────────────────────
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
    style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.34), fontSize: 13),
      filled: true, fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.6)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.22), width: 0.8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}

// ── Dropdown ──────────────────────────────────────────────────────────────────
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
    initialValue: value, onChanged: onChanged,
    dropdownColor: AppColors.bgModal,
    style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16),
    iconEnabledColor: Colors.white.withValues(alpha: 0.72),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.34), fontSize: 13),
      filled: true, fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.6)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.22), width: 0.8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    items: items.map((i) => DropdownMenuItem(
        value: i, child: Text(labels?[i] ?? _cap(i)))).toList(),
  );
}

// ── Fade + slide entrance ─────────────────────────────────────────────────────
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
