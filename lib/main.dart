import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/ai_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/app_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/user_provider.dart';
import 'providers/workout_provider.dart';

import 'screens/splash_screen.dart';

import 'services/ad_service.dart';
import 'services/billing_service.dart';
import 'services/monetization_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

import 'utils/app_constants.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    BindingBase.debugZoneErrorsAreFatal = true;

    // ✅ CRITICAL FIX: keep binding + runApp in SAME ZONE
    await _initHive();
    await _initFirebase();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    runApp(const GymTrackerProApp());
  }, (error, stack) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('❌ Unhandled error: $error');
      debugPrint('$stack');
    }
  });
}

// ════════════════════════════════════════════════
// INIT FUNCTIONS
// ════════════════════════════════════════════════

Future<void> _initHive() async {
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(StorageKeys.hiveWorkoutBox),
    Hive.openBox(StorageKeys.hiveLogsBox),
    Hive.openBox(StorageKeys.hiveSettingsBox),
  ]);
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();

    FlutterError.onError = (details) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };
  } catch (e, s) {
    debugPrint('❌ Firebase init failed: $e');
    debugPrint('$s');
  }
}

// 🚀 Moved to SplashScreen (NON-BLOCKING STARTUP)
Future<void> initCoreServices() async {
  await StorageService.instance.init();
  await MonetizationService.instance.init();

  await MobileAds.instance.initialize();

 if (kDebugMode) {
  final config = RequestConfiguration(
    testDeviceIds: ['E3803C1921456FA984C44D432ACE4118'],
  );
  MobileAds.instance.updateRequestConfiguration(config);
}

  await AdService.instance.init(
    isPremium: MonetizationService.instance.isPremium,
  );

  await Future.wait([
    BillingService.instance.init(),
    NotificationService.instance.init(),
  ]);
}

// ════════════════════════════════════════════════
// APP ROOT
// ════════════════════════════════════════════════

class GymTrackerProApp extends StatelessWidget {
  const GymTrackerProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 🔹 BASIC PROVIDERS
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),

        // 🔹 MAIN ORCHESTRATOR (SAFE INIT)
        ChangeNotifierProxyProvider5<
            UserProvider,
            WorkoutProvider,
            AnalyticsProvider,
            AIProvider,
            SettingsProvider,
            AppProvider>(
          create: (ctx) => AppProvider(
            user: ctx.read<UserProvider>(),
            workout: ctx.read<WorkoutProvider>(),
            analytics: ctx.read<AnalyticsProvider>(),
            ai: ctx.read<AIProvider>(),
            settings: ctx.read<SettingsProvider>(),
          ),

          // ✅ CRITICAL FIX: NEVER recreate, NEVER call init here
          update: (ctx, user, workout, analytics, ai, settings, previous) {
            return previous!;
          },
        ),
      ],
      child: const _AppBootstrap(),
    );
  }
}

// ════════════════════════════════════════════════
// BOOTSTRAP (DEFERRED INIT — ZERO LAG)
// ════════════════════════════════════════════════

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final ai  = context.read<AIProvider>();
      final app = context.read<AppProvider>();

      // 🔥 PARALLEL BACKGROUND INIT
      await Future.wait([
        ai.load(),
        initCoreServices(),
      ]);

      await app.init();

      if (mounted) {
        setState(() => _initialized = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _initialized
          ? const SplashScreen() // will instantly move forward
          : const SplashScreen(), // same UI → no flicker
    );
  }
}