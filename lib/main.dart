import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'utils/premium_scroll_behavior.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/ai_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/app_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/user_provider.dart';
import 'providers/workout_provider.dart';

import 'screens/splash_screen.dart';

import 'services/billing_service.dart';
import 'services/connectivity_service.dart';
import 'services/monetization_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'data/sync/outbox_service.dart';

import 'utils/app_constants.dart';
import 'utils/app_typography.dart';
import 'services/ai_quota_service.dart';
import 'services/exercise_video_service.dart';
import 'services/exercise_gif_service.dart';
import 'services/voice_coach_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

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

    // Warm GIF cache in background — ready before user opens exercise cards
    ExerciseGifService.instance.prefetch();

    runApp(const LiftOnApp());
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
    Hive.openBox(OutboxService.boxName), // RFC-002.1: sync outbox
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
  await OutboxService.instance.open(); // RFC-002.1: wire to the already-open box
  await MonetizationService.instance.init();
  await AiQuotaService.instance.init(); // quota + kill switch — needed before app.init()

  await Future.wait([
    BillingService.instance.init()
        .timeout(const Duration(seconds: 12), onTimeout: () {
      debugPrint('[Boot] BillingService timed out — skipping');
    }),
    NotificationService.instance.init()
        .timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint('[Boot] NotificationService timed out — skipping');
    }),
    ConnectivityService.instance.init()
        .timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint('[Boot] ConnectivityService timed out — skipping');
    }),
  ]);
}

// ════════════════════════════════════════════════
// APP ROOT
// ════════════════════════════════════════════════

class LiftOnApp extends StatelessWidget {
  const LiftOnApp({super.key});

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
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),

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
  // Resolves when all providers are ready. SplashScreen awaits this before
  // navigating so the user never lands on an uninitialized shell.
  late final Future<void> _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = _initialize();
  }

  Future<void> _initialize() async {
    final ai   = context.read<AIProvider>();
    final app  = context.read<AppProvider>();
    final favs = context.read<FavoritesProvider>();

    // Defer non-critical services so they never block the first rendered frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExerciseVideoService.init().ignore();
      VoiceCoachService().init().ignore();
    });

    debugPrint('[Boot] parallel init start');
    await Future.wait([
      ai.load().catchError((e) => debugPrint('[Boot] ai.load error: $e')),
      initCoreServices().catchError((e) => debugPrint('[Boot] initCoreServices error: $e')),
      favs.loadFavorites().catchError((e) => debugPrint('[Boot] loadFavorites error: $e')),
    ]);

    await app.init().catchError((e) => debugPrint('[Boot] app.init error: $e'));
    debugPrint('[Boot] app ready');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiftOn',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const PremiumScrollBehavior(),
      theme: AppTheme.dark,
      // RFC-TYPOGRAPHY-001 — platform typography scale applied once here.
      // Android renders all text at the compact pre-iOS-pass scale; iOS is
      // unchanged. See AppTypography for the rationale.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: AppTypography.scalerFor(context),
        ),
        child: child!,
      ),
      home: SplashScreen(readyFuture: _readyFuture),
    );
  }
}