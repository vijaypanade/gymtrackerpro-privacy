// lib/screens/splash_screen.dart — v5 Cinematic Splash
// ✅ FIX: Removed hardcoded test_user_123 / "Vijay" Firestore call
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import 'main_shell.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {

  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _barCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset>  _textSlide;
  late final Animation<double> _glowPulse;
  late final Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();

    // ✅ FIX: खालील 4 lines पूर्णपणे DELETE केल्या:
    //   userId: "test_user_123",   ← सगळे users एकाच document मध्ये जात होते!
    //   name: "Vijay",             ← तुमचं नाव सर्व users ला दिसत होतं!
    // );
    // Firestore write आता LoginScreen नंतर AuthService मधून होतो (real UID ने)

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _barCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _logoScale   = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide   = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _glowPulse   = Tween<double>(begin: 0.3, end: 0.9).animate(_glowCtrl);
    _barProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _barCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final isSignedIn = AuthService.instance.isSignedIn;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a1, __) => isSignedIn
            ? const MainShell()
            : const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a1, __, child) =>
            FadeTransition(opacity: a1, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose(); _textCtrl.dispose();
    _glowCtrl.dispose(); _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [

        // ── Ambient glow
        AnimatedBuilder(
          animation: _glowPulse,
          builder: (_, __) => Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.75,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.07 * _glowPulse.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.gold,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.40),
                            blurRadius: 28, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: Colors.black, size: 42,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Text
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, child) => Opacity(
                  opacity: _textOpacity.value,
                  child: SlideTransition(position: _textSlide, child: child),
                ),
                child: Column(children: [
                  Text('AI TRAINER', style: TextStyle(fontFamily: 'Rajdhani',
                    color: AppColors.gold, fontSize: 26,
                    fontWeight: FontWeight.w900, letterSpacing: 4,
                  )),
                  const SizedBox(height: 6),
                  Text('TRAIN · TRACK · DOMINATE', style: TextStyle(fontFamily: 'Inter',
                    color: AppColors.textMuted, fontSize: 10,
                    letterSpacing: 3.5, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ],
          ),
        ),

        // ── Progress bar at bottom
        Positioned(
          bottom: 52, left: 60, right: 60,
          child: AnimatedBuilder(
            animation: _barCtrl,
            builder: (_, __) => Opacity(
              opacity: _barProgress.value,
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _barProgress.value,
                    backgroundColor: AppColors.bgElevated,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Loading your stats...', style: TextStyle(fontFamily: 'Inter',
                  color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
