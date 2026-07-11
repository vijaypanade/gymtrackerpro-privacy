// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _loading = false;

  // Entry — plays once on mount
  late final AnimationController _entryCtrl;
  // Pulse — loops indefinitely for the logo halo
  late final AnimationController _pulseCtrl;

  // ── Staggered entry animations ────────────────────────────
  late final Animation<double> _bgFade;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double> _buttonOpacity;
  late final Animation<Offset>  _buttonSlide;

  // ── Pulsing rings ─────────────────────────────────────────
  late final Animation<double> _pulseInner;
  late final Animation<double> _pulseOuter;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Entry: 1300ms, staggered sections ─────────────────
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _bgFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.28, 0.62, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.28, 0.62, curve: Curves.easeOutCubic),
    ));

    _buttonOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOutCubic),
    ));

    // ── Pulse: 3.2s slow breathing loop ────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _pulseInner = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOuter = Tween<double>(begin: 1.0, end: 1.32).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;

    if (user != null) {
      final ap = context.read<AppProvider>();
      final restored = await ap.user.tryRestoreFromCloud();
      await ap.workout.tryRestoreLogsFromCloud();

      final prefs = await SharedPreferences.getInstance();
      final isOnboarded =
          restored || (prefs.getBool('onboarding_complete') ?? false);

      if (restored) await prefs.setBool('onboarding_complete', true);
      if (!mounted) return;
      setState(() => _loading = false);

      Navigator.of(context).pushReplacement(
        fadeRoute(isOnboarded ? const MainShell() : const OnboardingScreen()),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign-in cancelled or failed. Please try again.'),
          backgroundColor: AppColors.bgElevated,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient background ──────────────────────────
          FadeTransition(
            opacity: _bgFade,
            child: _PremiumBackground(size: size),
          ),

          // ── Main content ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Hero emblem with pulsing halo
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _HeroEmblem(
                        pulseInner: _pulseInner,
                        pulseOuter: _pulseOuter,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Brand + divider tagline
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const _TitleSection(),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Feature pills — per-chip stagger
                  _FeaturePills(ctrl: _entryCtrl),

                  const Spacer(flex: 3),

                  // Google sign-in CTA
                  FadeTransition(
                    opacity: _buttonOpacity,
                    child: SlideTransition(
                      position: _buttonSlide,
                      child: _GoogleCTA(
                        loading: _loading,
                        onTap: _loading ? null : _signIn,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _buttonOpacity,
                    child: Text(
                      'By continuing, you agree to our Privacy Policy',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF707070),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Background — radial gold ambience
// ════════════════════════════════════════════════════════════
class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF030303)),

        // Top-center warm gold spotlight
        Positioned(
          top: -size.height * 0.18,
          left: size.width * 0.05,
          right: size.width * 0.05,
          child: Container(
            height: size.height * 0.55,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0x12D4AF37), // ~7% gold
                  Colors.transparent,
                ],
                radius: 0.68,
              ),
            ),
          ),
        ),

        // Bottom subtle warmth
        Positioned(
          bottom: -size.height * 0.10,
          left: 0,
          right: 0,
          child: Container(
            height: size.height * 0.36,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0x06D4AF37), // ~2% gold
                  Colors.transparent,
                ],
                radius: 0.85,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// Hero Emblem — layered rings + glowing core
// ════════════════════════════════════════════════════════════
class _HeroEmblem extends StatelessWidget {
  const _HeroEmblem({required this.pulseInner, required this.pulseOuter});
  final Animation<double> pulseInner;
  final Animation<double> pulseOuter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseInner, pulseOuter]),
      builder: (_, __) {
        // Alpha fades to 0 as ring reaches max scale (emanating wave feel)
        final innerAlpha =
            ((1.14 - pulseInner.value) / 0.14 * 0.20).clamp(0.0, 0.20);
        final outerAlpha =
            ((1.32 - pulseOuter.value) / 0.32 * 0.09).clamp(0.0, 0.09);

        return SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer breathing ring
              Transform.scale(
                scale: pulseOuter.value,
                child: Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color.fromRGBO(212, 175, 55, outerAlpha),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // Inner breathing ring
              Transform.scale(
                scale: pulseInner.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color.fromRGBO(212, 175, 55, innerAlpha),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // Glow halo — breathes with pulse
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // brighter as ring expands
                      color: Color.fromRGBO(212, 175, 55,
                          0.10 + 0.12 * (pulseInner.value - 1.0) / 0.14),
                      blurRadius:
                          30.0 + 18.0 * (pulseInner.value - 1.0) / 0.14,
                      spreadRadius:
                          4.0 + 6.0 * (pulseInner.value - 1.0) / 0.14,
                    ),
                  ],
                ),
              ),

              // Fine gold border ring
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
              ),

              // Core emblem — header_logo for brand consistency with splash
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: () {
                    final t = (pulseInner.value - 1.0) / 0.14;
                    return [
                      BoxShadow(
                        color: Color.fromRGBO(212, 175, 55, 0.12 + 0.18 * t),
                        blurRadius: 18.0 + 24.0 * t,
                        spreadRadius: 2.0 + 6.0 * t,
                      ),
                      const BoxShadow(
                        color: Color(0xCC000000),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ];
                  }(),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/header_logo.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// Title Section — gold gradient brand name + divider tagline
// ════════════════════════════════════════════════════════════
class _TitleSection extends StatelessWidget {
  const _TitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "LIFTON AI" — gold shimmer gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFA8892C),
              Color(0xFFFFD700),
              Color(0xFFE8CB6A),
              Color(0xFFD4AF37),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'LIFTON',
            style: GoogleFonts.rajdhani(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
        ),

        const SizedBox(height: 7),

        // Subtitle
        Text(
          'Train Smarter. Recover Better.',
          style: GoogleFonts.inter(
            color: const Color(0xFF8A8A8A),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 22),

        // "TRAIN · TRACK · DOMINATE" between gradient lines
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFD4AF37).withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Train · Track · Progress',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.50),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// Feature Pills — staggered entrance, dark capsules + gold icon
// ════════════════════════════════════════════════════════════
class _FeaturePills extends StatelessWidget {
  // ignore: use_key_in_widget_constructors
  const _FeaturePills({required this.ctrl});
  final AnimationController ctrl;

  static const _features = [
    (Icons.psychology_rounded,     'Personalised Coaching'),
    (Icons.calendar_month_rounded, 'Adaptive Weekly Plans'),
    (Icons.favorite_rounded,       'Recovery Insights'),
    (Icons.trending_up_rounded,    'Personal Records'),
    (Icons.analytics_rounded,      'Progress Tracking'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _features.asMap().entries.map((e) {
        // Each chip starts 4% (≈52ms) later than the previous one
        const base = 0.50;
        const span = 0.30;
        final start = base + e.key * 0.04;
        final end   = (start + span).clamp(0.0, 1.0);

        final opacity = CurvedAnimation(
          parent: ctrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ));

        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: _Pill(icon: e.value.$1, label: e.value.$2),
          ),
        );
      }).toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 13),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF9A9A9A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Google CTA — premium white button with scale tap feedback
// ════════════════════════════════════════════════════════════
class _GoogleCTA extends StatefulWidget {
  const _GoogleCTA({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_GoogleCTA> createState() => _GoogleCTAState();
}

class _GoogleCTAState extends State<_GoogleCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.loading ? 0.65 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0xB3000000),
                blurRadius: 22,
                spreadRadius: -4,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: widget.loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://developers.google.com/identity/images/g-logo.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 22,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      ),
    );
  }
}
