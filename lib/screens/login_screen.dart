// lib/screens/login_screen.dart
// ✅ FIX: Login नंतर onboarding flag check करतो
//         नवीन user  → OnboardingScreen
//         परत आलेला user → MainShell (onboarding skip)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/app_constants.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  // ✅ FIX: onboarding check key — AppProvider च्या key शी match असणे गरजेचे
  static const _kOnboardingDone = 'onboarding_complete';

  Future<void> _signIn() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    final user = await AuthService.instance.signInWithGoogle();
    
    final prefs = await SharedPreferences.getInstance();
    final isOnboarded = prefs.getBool("onboarding_complete") ?? false;

    if (!mounted) return;
    setState(() => _loading = false);

    if (user != null) {
      // ✅ FIX: Real user UID ने Firestore मध्ये save करा (test_user_123 नाही!)

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isOnboarded
              ? const MainShell()        // ← परत आलेला user: सरळ app मध्ये
              : const OnboardingScreen(), // ← नवीन user: onboarding flow
        ),
      );
    } else {
      // Sign-in cancel किंवा fail
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign-in cancelled or failed. Please try again.'),
          backgroundColor: AppColors.bgElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.gold,
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    size: 40, color: Colors.black),
              ),
              const SizedBox(height: 24),

              // ✅ FIX: Title "AI Trainer" — सर्वत्र consistent नाव
              Text('AI Trainer', style: TextStyle(
                fontFamily: 'Rajdhani',
                color: AppColors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              )),
              const SizedBox(height: 8),
              Text('Your personal AI-powered gym coach',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Features list
              ...[
                ('🤖', 'AI Workout & Diet Coach'),
                ('📅', 'Smart Weekly Planner'),
                ('🔥', 'Streak & Progress Tracking'),
              ].map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Text(f.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(f.$2, style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  )),
                ]),
              )),

              const Spacer(flex: 2),

              // Google Sign-In Button
              GestureDetector(
                onTap: _loading ? null : _signIn,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 20,
                    )],
                  ),
                  child: _loading
                      ? const Center(child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                        ))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://developers.google.com/identity/images/g-logo.png',
                              width: 22, height: 22,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.g_mobiledata_rounded,
                                      size: 24, color: Colors.black),
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),
              Text('By continuing, you agree to our Privacy Policy',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
