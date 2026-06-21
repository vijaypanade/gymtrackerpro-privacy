// lib/utils/app_constants.dart — v5 Premium Design System
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════
// SPACING SYSTEM
// ══════════════════════════════════════════════
class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

class AppRadii {
  static const double xs   = 8;
  static const double sm   = 12;
  static const double md   = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double pill = 999;

  // semantic usage
  static const double card = lg;
  static const double modal = xl;
  static const double button = md;
  static const double chip = sm;
}

// ══════════════════════════════════════════════
// PREMIUM COLOR SYSTEM
// ══════════════════════════════════════════════
class AppColors {
  // ── Backgrounds (deep blacks with subtle warmth)
  static const Color bg          = Color(0xFF050505); // near-black with warmth
  static const Color background  = bg;
  static const Color bgSurface   = Color(0xFF080808);
  static const Color bgCard      = Color(0xFF0E0E0E);
  static const Color bgCardLight = Color(0xFF141414);
  static const Color bgElevated  = Color(0xFF1C1C1C);
  static const Color bgModal     = Color(0xFF111111);

  // ── Gold System (3-tier premium hierarchy)
  static const Color gold        = Color(0xFFD4AF37);   // base gold (legacy)
  static const Color goldHero    = Color(0xFFFFD54A);   // ONE hero element per section
  static const Color goldSoft    = Color(0xFFC9A227);   // secondary badges, chips
  static const Color goldAmber   = Color(0xFF8F6B1F);   // inactive bars, muted labels
  static const Color goldLight   = Color(0xFFFFD700);
  static const Color goldDark    = Color(0xFFA8892C);
  static const Color goldMuted   = Color(0xFF6B5820);
  static const Color goldGlow    = Color(0xFFD4AF3740); // with alpha

  // ── Text (clean hierarchy)
  static const Color textPrimary   = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB2B2B2);
  static const Color textMuted     = Color(0xFF8A8A8A);
  static const Color textDisabled  = Color(0xFF2E2E2E);

  // ── Borders
  static const Color borderSoft   = Color(0xFF1A1A1A);
  static const Color borderMedium = Color(0xFF242424);
  static const Color borderStrong = Color(0xFF303030);
  static const Color divider      = Color(0xFF1A1A1A);

  // ── Semantic (vivid, saturated)
  static const Color green     = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color greenGlow = Color(0xFF22C55E30);
  static const Color red       = Color(0xFFE57373);  // Material Red 300 — muted, luxury-safe
  static const Color redDark   = Color(0xFFEF5350);  // Material Red 400 — deeper but not aggressive
  static const Color blue      = Color(0xFF3B82F6);
  static const Color blueGlow  = Color(0xFF3B82F630);
  static const Color orange    = Color(0xFFF97316);
  static const Color purple    = Color(0xFF8B5CF6);
  static const Color purpleGlow= Color(0xFF8B5CF630);
  static const Color cyan      = Color(0xFF06B6D4);
  static const Color yellow    = Color(0xFFEAB308);
  static const Color pink      = Color(0xFFEC4899);

  // ── Muscle Group Colors
  static const Color muscleChest     = Color(0xFFEF4444);
  static const Color muscleBack      = Color(0xFF3B82F6);
  static const Color muscleLegs      = Color(0xFF22C55E);
  static const Color muscleShoulders = Color(0xFFF97316);
  static const Color muscleArms      = Color(0xFF8B5CF6);
  static const Color muscleCore      = Color(0xFFEAB308);
  static const Color muscleCardio    = Color(0xFF06B6D4);

  // ── Day Colors
  static const List<Color> dayColors = [
    Color(0xFFD4AF37), // muted gold
    Color(0xFFB8B8B8), // silver grey
    Color(0xFF8A8A8A), // soft grey
    Color(0xFFC6A55B), // warm muted gold
    Color(0xFF9A9A9A), // neutral grey
    Color(0xFFE0E0E0), // soft white
    Color(0xFF5A5A5A), // charcoal
  ];

  // ── Goal Colors
  static const Color goalFatLoss   = Color(0xFFEF4444);
  static const Color goalMuscle    = Color(0xFF3B82F6);
  static const Color goalStrength  = Color(0xFFD4AF37);

  static const Map<String, Color> categoryColors = {
    'Chest': muscleChest, 'Back': muscleBack, 'Legs': muscleLegs,
    'Shoulders': muscleShoulders, 'Arms': muscleArms,
    'Core': muscleCore, 'Cardio': muscleCardio,
  };
}

// ══════════════════════════════════════════════
// GRADIENTS
// ══════════════════════════════════════════════
class AppGradients {
  static const LinearGradient gold = LinearGradient(
    colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldVertical = LinearGradient(
    colors: [AppColors.goldLight, AppColors.goldDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkCard = LinearGradient(
    colors: [Color(0xFF131313), Color(0xFF0A0A0A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldSubtle = LinearGradient(
    colors: [Color(0xFF1A1400), Color(0xFF0F0F0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hero = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF050505)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient fatLoss = LinearGradient(
    colors: [AppColors.red.withValues(alpha: 0.8), AppColors.orange.withValues(alpha: 0.5)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static LinearGradient muscleGain = LinearGradient(
    colors: [AppColors.blue.withValues(alpha: 0.7), AppColors.purple.withValues(alpha: 0.5)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static LinearGradient strength = LinearGradient(
    colors: [AppColors.goldDark.withValues(alpha: 0.7), AppColors.gold.withValues(alpha: 0.4)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // Rank gradients
  static LinearGradient rankGradient(int rank) {
    const gradients = [
      [Color(0xFF64748B), Color(0xFF475569)], // recruit - slate
      [Color(0xFF2563EB), Color(0xFF1D4ED8)], // warrior - blue
      [Color(0xFFD4AF37), Color(0xFF8B6914)], // gladiator - metallic gold
      [Color(0xFFD97706), Color(0xFFB45309)], // champion - amber
      [Color(0xFFD4AF37), Color(0xFFA8892C)], // legend - gold
      [Color(0xFFEF4444), Color(0xFFDC2626)], // beast - red
    ];
    final g = gradients[rank.clamp(0, 5)];
    return LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

// ══════════════════════════════════════════════
// SHADOWS
// ══════════════════════════════════════════════
class AppShadows {
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.24),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get strong => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.34),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> cardGlow([Color glow = AppColors.gold]) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.7),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: glow.withValues(alpha: 0.07),
      blurRadius: 32,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> buttonGlow([Color glow = AppColors.gold]) => [
    BoxShadow(
      color: glow.withValues(alpha: 0.35),
      blurRadius: 20,
      spreadRadius: 1,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get card => medium;

  static List<BoxShadow> colored(Color c) => [
    BoxShadow(
      color: c.withValues(alpha: 0.28),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.8),
      blurRadius: 40,
      offset: const Offset(0, 20),
    ),
  ];
}

class AppBorders {
  static Border subtle = Border.all(
    color: AppColors.borderSoft,
    width: 0.6,
  );

  static Border medium = Border.all(
    color: AppColors.borderMedium,
    width: 0.8,
  );

  static Border strong = Border.all(
    color: AppColors.borderStrong,
    width: 1.0,
  );

  static Border glow([Color color = AppColors.gold]) => Border.all(
    color: color.withValues(alpha: 0.32),
    width: 0.9,
  );

  static Border active([Color color = AppColors.gold]) => Border.all(
    color: color.withValues(alpha: 0.50),
    width: 1.0,
  );
}

// ══════════════════════════════════════════════
// TYPOGRAPHY — Rajdhani (headers) + Inter (body)
// ══════════════════════════════════════════════
class AppTextStyles {
  // Display
  static TextStyle get display => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 42, fontWeight: FontWeight.w900,
    color: AppColors.textPrimary, letterSpacing: 1,
    height: 1.0,
  );

  // Headings
  static TextStyle get h1 => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 30, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: 0.5,
  );
  static TextStyle get h2 => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle get h3 => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle get h4 => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );

  // Body
  static TextStyle get body => TextStyle(fontFamily: 'Inter',
    fontSize: 14, color: AppColors.textPrimary, height: 1.5,
  );
  static TextStyle get bodySmall => TextStyle(fontFamily: 'Inter',
    fontSize: 12, color: AppColors.textSecondary, height: 1.4,
  );
  static TextStyle get caption => TextStyle(fontFamily: 'Inter',
    fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.4,
  );
  static TextStyle get label => TextStyle(fontFamily: 'Inter',
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
  );

  // Special
  static TextStyle get number => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: 1,
  );
  static TextStyle get bigNumber => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 40, fontWeight: FontWeight.w900,
    color: AppColors.textPrimary, letterSpacing: 1,
  );
  static TextStyle get sectionTitle => TextStyle(fontFamily: 'Inter',
    fontSize: 11, fontWeight: FontWeight.w700,
    color: AppColors.textMuted, letterSpacing: 1.8,
  );
  static TextStyle get gold => TextStyle(fontFamily: 'Rajdhani',
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold,
  );
  static TextStyle get goldSmall => TextStyle(fontFamily: 'Inter',
    fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold,
  );

  // Button
  static TextStyle get button => TextStyle(fontFamily: 'Inter',
    fontSize: 15, fontWeight: FontWeight.w800,
    color: Colors.black, letterSpacing: 0.3,
  );
  static TextStyle get buttonSmall => TextStyle(fontFamily: 'Inter',
    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black,
  );
}

// ══════════════════════════════════════════════
// ANIMATION DURATIONS
// ══════════════════════════════════════════════
class AppDurations {

  // Tactile feedback
  static const Duration instant = Duration(milliseconds: 80);

  // Chips / toggles / micro interactions
  static const Duration fast = Duration(milliseconds: 160);

  // Standard UI motion
  static const Duration normal = Duration(milliseconds: 240);

  // Premium reveals / cards / sheets
  static const Duration slow = Duration(milliseconds: 420);

  // Cinematic transitions
  static const Duration xslow = Duration(milliseconds: 620);

  // Navigation
  static const Duration pageTransition = Duration(milliseconds: 320);
}

class AppCurves {
  static const Curve primary = Curves.easeOutCubic;
  static const Curve smooth = Curves.easeOutQuart;
  static const Curve entrance = Curves.easeOutExpo;
  static const Curve exit = Curves.easeInOutCubic;
  static const Curve emphasis = Curves.easeOutBack;
}

// ══════════════════════════════════════════════
// THEME
// ══════════════════════════════════════════════
class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.goldLight,
      surface: AppColors.bgCard,
      error: AppColors.red,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Rajdhani',
        color: AppColors.textPrimary, fontSize: 20,
        fontWeight: FontWeight.w800, letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      scrolledUnderElevation: 0,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
  fontFamily: 'Inter',
  bodyColor: AppColors.textPrimary,
  displayColor: AppColors.textPrimary,
),
    cardTheme: CardThemeData(
      color: AppColors.bgCard, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.borderSoft, width: 0.5),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSurface,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.textMuted,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bgElevated,
      contentTextStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgModal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderMedium, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1),
      ),
      labelStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 13),
      hintStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgCard,
      selectedColor: AppColors.gold.withValues(alpha: 0.18),
      labelStyle: TextStyle(fontFamily: 'Inter',fontSize: 12, color: AppColors.textPrimary),
      side: const BorderSide(color: AppColors.borderSoft, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}

// ══════════════════════════════════════════════
// LIMITS
// ══════════════════════════════════════════════
class AppLimits {
  static const double maxWeight = 400.0;
  static const int maxSetsPerExercise = 10;
  static const int maxExercisesPerDay = 12;
}
