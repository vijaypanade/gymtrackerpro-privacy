import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_shell.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  /// Completes when all providers are initialized. Navigation is gated on
  /// BOTH this future AND the minimum animation duration.
  final Future<void>? readyFuture;
  const SplashScreen({super.key, this.readyFuture});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Phase 1 — Logo entrance (0–700 ms)
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _logoFade;

  // Ambient glow breathing (starts at 700 ms, loops)
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowOpacity;

  // Phase 2 — Brand name + tagline stagger (starts at 1200 ms)
  late final AnimationController _textCtrl;
  late final Animation<double>   _brandFade;
  late final Animation<double>   _taglineFade;

  // Status line — only shown if startup exceeds 2 s
  late final AnimationController _statusCtrl;
  late final Animation<double>   _statusFade;
  bool _showStatus = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:         Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Phase 1: Logo entrance ────────────────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));
    _logoFade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    // ── Glow breathing ───────────────────────────────────────────────────────
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _glowOpacity = Tween<double>(begin: 0.15, end: 0.35).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // ── Phase 2: Brand + tagline ─────────────────────────────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.40, 1.0, curve: Curves.easeOut)));

    // ── Status text ──────────────────────────────────────────────────────────
    _statusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _statusFade = CurvedAnimation(parent: _statusCtrl, curve: Curves.easeOut);

    _runAnimation();
    _setupNavigation();
  }

  // Drives the visual sequence regardless of provider readiness.
  Future<void> _runAnimation() async {
    _logoCtrl.forward();

    // 700 ms — logo settled → haptic + start glow
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _glowCtrl.repeat(reverse: true);

    // 1200 ms — fade in brand text
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textCtrl.forward();
  }

  void _setupNavigation() {
    bool providerReady = false;

    // Show status text if providers haven't resolved by 2 s
    Future<void>.delayed(const Duration(milliseconds: 2000)).then((_) {
      if (!mounted || providerReady) return;
      setState(() => _showStatus = true);
      _statusCtrl.forward();
    });

    // Navigate when BOTH min visual hold (2.5 s) AND providers are ready
    Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 2500)),
      widget.readyFuture ?? Future<void>.value(),
    ]).then((_) {
      providerReady = true;
      if (!mounted) return;
      final isLoggedIn = AuthService.instance.currentUser != null;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              isLoggedIn ? const MainShell() : const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Warm black background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF120E08), Colors.black],
                stops: [0.0, 0.75],
              ),
            ),
          ),

          // ── Center column: glow + logo + text ─────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with ambient glow — phase 1
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: _GlowLogo(glowAnim: _glowOpacity),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // LIFTON — phase 2
                AnimatedBuilder(
                  animation: _brandFade,
                  builder: (_, __) => Opacity(
                    opacity: _brandFade.value,
                    child: Text(
                      'LIFTON',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline — phase 2 (250 ms after brand)
                AnimatedBuilder(
                  animation: _taglineFade,
                  builder: (_, __) => Opacity(
                    opacity: _taglineFade.value,
                    child: Text(
                      'The gym plan that adjusts itself.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status line — only if startup > 2 s ───────────────────────────
          if (_showStatus)
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Center(
                child: FadeTransition(
                  opacity: _statusFade,
                  child: Text(
                    'Preparing your training system...',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.40),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
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

// ── Logo tile with animated ambient glow ──────────────────────────────────────

class _GlowLogo extends StatelessWidget {
  final Animation<double> glowAnim;
  const _GlowLogo({required this.glowAnim});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: glowAnim,
    builder: (_, __) => Stack(
      alignment: Alignment.center,
      children: [
        // Radial ambient glow — breathes with glowAnim
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: glowAnim.value),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Logo tile
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
                blurRadius: 48,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.60),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: Image.asset(
              'assets/header_logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    ),
  );
}
