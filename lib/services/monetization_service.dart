// lib/services/monetization_service.dart — v1.0 COMPLETE MONETIZATION ENGINE
// ════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
//   MonetizationService  ← single source of truth for all revenue logic
//       ↓
//   AppProvider          ← reads isPremium, canUseAI(), aiUsageCount
//       ↓
//   UI Screens           ← show paywall via PaywallTrigger enum
//
// REVENUE STREAMS:
//   1. AdMob Banner      — Home screen (free users, always)
//   2. AdMob Interstitial — After workout complete (max 2/day, free users)
//   3. AdMob Rewarded    — Unlock extra AI use (watch ad → +1 plan)
//   4. Subscription      — ₹199/month (no ads + unlimited AI + premium features)
//
// PAYWALL TRIGGERS (behavior-based, non-annoying):
//   - AI limit hit       → "Watch ad OR upgrade"
//   - 5th workout done   → "You're consistent! Unlock full coaching"
//   - PR broken          → "You're progressing! Premium has adaptive plans"
//   - 7-day streak       → "Streak is building! Protect it with premium"
//   - Advanced stats tap → "Upgrade to see full analytics"
//
// PSYCHOLOGY:
//   - Show VALUE before paywall (let user taste premium features)
//   - Never interrupt a workout session
//   - Max 1 paywall prompt per day
//   - Always offer free path (watch ad) before paid upgrade
// ════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'billing_service.dart';
import '../utils/app_constants.dart';

// ─────────────────────────────────────────────────────────────
// PAYWALL TRIGGER ENUM — why the paywall appeared
// UI uses this to show context-aware messaging
// ─────────────────────────────────────────────────────────────
enum PaywallTrigger {
  aiLimitHit,        // Used all 2 free AI plans today
  workoutMilestone,  // Completed 5th or 10th workout
  prBroken,          // Hit a new personal record
  streakMilestone,   // 7-day streak reached
  advancedStatsTap,  // Tapped locked analytics feature
  manual,            // User tapped "Upgrade" themselves
}

extension PaywallTriggerX on PaywallTrigger {
  String get headline {
    switch (this) {
      case PaywallTrigger.aiLimitHit:
        return 'AI Limit Reached 🤖';
      case PaywallTrigger.workoutMilestone:
        return 'You\'re Building Something Real 🔥';
      case PaywallTrigger.prBroken:
        return 'New PR! You\'re Getting Stronger 💪';
      case PaywallTrigger.streakMilestone:
        return '7-Day Streak! Protect It 🔥';
      case PaywallTrigger.advancedStatsTap:
        return 'Unlock Full Analytics 📊';
      case PaywallTrigger.manual:
        return 'Unlock Your Full Potential 👑';
    }
  }

  String get subtext {
    switch (this) {
      case PaywallTrigger.aiLimitHit:
        return 'You\'ve used your 2 free AI plans today.\nWatch an ad for 1 more — or go Premium for unlimited.';
      case PaywallTrigger.workoutMilestone:
        return 'You\'ve completed 5+ workouts. Serious athletes use smart coaching.\nUpgrade to get adaptive plans built on your actual data.';
      case PaywallTrigger.prBroken:
        return 'You\'re getting stronger every week 💪\n\nDon\'t lose this momentum.\nUnlock AI coaching that adapts every week\nand predicts your next PR before you lift.';
      case PaywallTrigger.streakMilestone:
        return '7 days straight. That\'s rare. Premium gives you\nsmarter recovery, deload detection, and streak protection tools.';
      case PaywallTrigger.advancedStatsTap:
        return 'This feature is available for Premium members.\nSee fatigue index, plateau detection, and weekly trends.';
      case PaywallTrigger.manual:
        return 'Everything you need to train smarter,\nrecover better, and progress faster.';
    }
  }

  bool get showAdOption {
    // Only show "watch ad" option for AI limit — not for other triggers
    return this == PaywallTrigger.aiLimitHit;
  }
}

// ─────────────────────────────────────────────────────────────
// MONETIZATION SERVICE — singleton
// ─────────────────────────────────────────────────────────────
class MonetizationService {
  MonetizationService._();
  static final MonetizationService instance = MonetizationService._();

  static const String _keyPremium          = 'is_premium_v1';
  static const String _keyAiUsageDate      = 'ai_usage_date_v1';
  static const String _keyAiUsageCount     = 'ai_usage_count_v1';
  static const String _keyRewardedExtras   = 'rewarded_extras_v1';
  static const String _keyLastPaywallDate  = 'last_paywall_date_v1';
  static const String _keyInterstitialCount= 'interstitial_count_v1';
  static const String _keyInterstitialDate = 'interstitial_date_v1';

  static const int _freeAiLimit            = 2;  // free plans per day
  static const int _maxInterstitialsPerDay = 2;  // max fullscreen ads/day

  bool _isPremium      = false;
  int  _aiUsageToday   = 0;
  int  _rewardedExtras = 0;  // extra uses earned by watching ads
  int  _interstitialsToday = 0;

  bool get isPremium    => _isPremium;
  int  get aiUsageToday => _aiUsageToday;
  int  get freeAiLimit  => _freeAiLimit;

  int get aiUsesRemaining {
    if (_isPremium) return 999;
    return (_freeAiLimit + _rewardedExtras - _aiUsageToday).clamp(0, 99);
  }

  bool get canUseAI {
    if (_isPremium) return true;
    return _aiUsageToday < (_freeAiLimit + _rewardedExtras);
  }

  // ─────────────────────────────────────────────────────────
  // INIT — call in AppProvider._init()
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      _isPremium    = prefs.getBool(_keyPremium) ?? false;
      _resetDailyCountsIfNeeded(prefs);
      _aiUsageToday    = prefs.getInt(_keyAiUsageCount)    ?? 0;
      _rewardedExtras  = prefs.getInt(_keyRewardedExtras)  ?? 0;
      _interstitialsToday = prefs.getInt(_keyInterstitialCount) ?? 0;

      // Sync ad service premium state
      // AdService.instance.setPremium(_isPremium); // enable after pub get
    } catch (e) {
      debugPrint('MonetizationService.init error: $e');
    }
  }

  void _resetDailyCountsIfNeeded(SharedPreferences prefs) {
    final today    = _todayStr;
    final lastDate = prefs.getString(_keyAiUsageDate) ?? '';
    if (lastDate != today) {
      prefs.setString(_keyAiUsageDate,       today);
      prefs.setInt(_keyAiUsageCount,         0);
      prefs.setInt(_keyRewardedExtras,       0);
      prefs.setInt(_keyInterstitialCount,    0);
      prefs.setString(_keyInterstitialDate,  today);
      _aiUsageToday       = 0;
      _rewardedExtras     = 0;
      _interstitialsToday = 0;
    }
  }

  // ─────────────────────────────────────────────────────────
  // AI USAGE TRACKING
  // ─────────────────────────────────────────────────────────
  Future<void> recordAIUse() async {
    _aiUsageToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAiUsageCount, _aiUsageToday);
  }

  /// Called after user watches rewarded ad — grants +1 AI use
  Future<void> grantRewardedAIUse() async {
    _rewardedExtras++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRewardedExtras, _rewardedExtras);
  }

  // ─────────────────────────────────────────────────────────
  // INTERSTITIAL FREQUENCY CAP
  // ─────────────────────────────────────────────────────────
  bool get canShowInterstitial {
    if (_isPremium) return false;
    return _interstitialsToday < _maxInterstitialsPerDay;
  }

  Future<void> showInterstitialIfAllowed({VoidCallback? onDone}) async {
    if (!canShowInterstitial) {
      onDone?.call();
      return;
    }
    _interstitialsToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInterstitialCount, _interstitialsToday);
    onDone?.call(); // AdService.instance.showInterstitial — enable after pub get
  }

  // ─────────────────────────────────────────────────────────
  // PREMIUM UPGRADE
  // NOTE: Real billing via in_app_purchase → call this after
  //       purchase verified. For now: direct unlock.
  // ─────────────────────────────────────────────────────────
  Future<void> upgradeToPremium({String plan = 'yearly'}) async {
    // Try real billing first
    try {
      final productId = plan == 'monthly'
          ? BillingProducts.monthly
          : BillingProducts.yearly;
      await BillingService.instance.purchase(productId);
      // BillingService will call _setPremium via listener
    } catch (e) {
      debugPrint('Billing error: $e — falling back to direct upgrade');
    }
    // Also set locally (for immediate UI update)
    await _setPremium(true);
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremium, value);
    debugPrint('✅ Premium: $value');
  }

  // Called by BillingService after successful purchase
  void markPremiumFromBilling() {
    _isPremium = true;
    debugPrint('✅ Premium granted via BillingService');
  }

  Future<void> revokePremium() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremium, false);
    // AdService.instance.setPremium(false);
  }

  // ─────────────────────────────────────────────────────────
  // PAYWALL TRIGGER LOGIC
  // Returns true if paywall should be shown — max 1/day
  // ─────────────────────────────────────────────────────────
  // NOTE: Interstitial frequency is handled by AdService internally
  // MonetizationService only handles: isPremium, canUseAI, AI usage count

  Future<bool> shouldShowPaywall(PaywallTrigger trigger) async {
    if (_isPremium) return false;
    // AI limit — always show (user is blocked anyway)
    if (trigger == PaywallTrigger.aiLimitHit) return true;
    // Other triggers — max 1 per day to avoid annoyance
    try {
      final prefs    = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_keyLastPaywallDate) ?? '';
      if (lastDate == _todayStr) return false; // already shown today
      await prefs.setString(_keyLastPaywallDate, _todayStr);
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
}

// ═════════════════════════════════════════════════════════════
// PAYWALL SHEET — beautiful bottom sheet, behavior-aware
// Usage: PaywallSheet.show(context, trigger: PaywallTrigger.prBroken)
// ═════════════════════════════════════════════════════════════
class PaywallSheet extends StatefulWidget {
  final PaywallTrigger trigger;
  final VoidCallback?  onUpgrade;
  final VoidCallback?  onAdComplete; // rewarded ad finished → grant AI use

  const PaywallSheet({
    super.key,
    required this.trigger,
    this.onUpgrade,
    this.onAdComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required PaywallTrigger trigger,
    VoidCallback? onUpgrade,
    VoidCallback? onAdComplete,
  }) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder:           (_) => PaywallSheet(
        trigger:      trigger,
        onUpgrade:    onUpgrade,
        onAdComplete: onAdComplete,
      ),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _loadingAd      = false;
  bool _loadingUpgrade = false;
  String _selectedPlan = 'yearly'; // default to yearly (best value)

  static const _features = [
    ('🤖', 'Unlimited AI workout plans',       true),
    ('📊', 'Advanced analytics & fatigue index', true),
    ('🧠', 'Smart coaching insights',           true),
    ('🎯', 'Plateau detection & deload alerts', true),
    ('🚫', 'Zero ads — ever',                  true),
    ('🔥', 'PR tracking & weekly memory',       false), // free too
    ('📅', 'Weekly planner',                    false), // free too
  ];

  @override
  Widget build(BuildContext context) {
    final trigger = widget.trigger;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            // ── Crown icon ───────────────────────────────────
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppGradients.gold),
              child: const Center(
                  child: Text('👑', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 16),

            // ── STEP 1: Dopamine headline ─────────────────────
            Text(trigger.headline,
                style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(trigger.subtext,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),

            // ── STEP 2: Future Preview — make user imagine ────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0900),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text('WITH PREMIUM — NEXT WEEK',
                      style: GoogleFonts.inter(
                          color: AppColors.gold, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 10),
                _FuturePreviewRow('📈', 'Next week plan auto-adjusts to your progress'),
                const SizedBox(height: 6),
                _FuturePreviewRow('🧠', 'AI tracks your weak muscles every session'),
                const SizedBox(height: 6),
                _FuturePreviewRow('🏆', 'Advanced PR predictions — know before you lift'),
                const SizedBox(height: 6),
                _FuturePreviewRow('🎯', 'Deload auto-detected — never overtrain again'),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Feature list ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.20)),
              ),
              child: Column(
                children: _features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Text(f.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f.$2,
                        style: GoogleFonts.inter(
                            color: f.$3
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: f.$3
                                ? FontWeight.w600
                                : FontWeight.w400))),
                    if (f.$3)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('PRO',
                            style: GoogleFonts.inter(
                                color: AppColors.gold, fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('FREE',
                            style: GoogleFonts.inter(
                                color: AppColors.green, fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── STEP 4: Price — monthly + yearly ─────────────
            Row(children: [
              // Monthly
              Expanded(child: _PricePill(
                price: '₹199', period: '/mo',
                badge: '3 days free',
                isSelected: _selectedPlan == 'monthly',
                onTap: () => setState(() => _selectedPlan = 'monthly'),
              )),
              const SizedBox(width: 10),
              // Yearly — highlighted as best value
              Expanded(child: _PricePill(
                price: '₹999', period: '/yr',
                badge: 'Save 58% 🔥',
                isSelected: _selectedPlan == 'yearly',
                isHighlighted: true,
                onTap: () => setState(() => _selectedPlan = 'yearly'),
              )),
            ]),
            const SizedBox(height: 16),

            // ── Upgrade CTA ──────────────────────────────────
            _loadingUpgrade
                ? const CircularProgressIndicator(color: AppColors.gold)
                : GestureDetector(
                    onTap: _onUpgradeTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            blurRadius: 18, offset: const Offset(0, 4))],
                      ),
                      child: Text(
                          _selectedPlan == 'yearly'
                              ? 'Start Free Trial — ₹999/yr 🚀'
                              : 'Start Free Trial — ₹199/mo 🚀',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                              color: Colors.black, fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
            const SizedBox(height: 10),

            // ── Watch Ad option (only for AI limit trigger) ──
            if (trigger.showAdOption) ...[
              _loadingAd
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                          color: AppColors.gold, strokeWidth: 2))
                  : TextButton.icon(
                      onPressed: _onWatchAdTap,
                      icon: const Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.textMuted, size: 18),
                      label: Text('Watch an ad instead (free)',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 13,
                              decoration: TextDecoration.underline)),
                    ),
            ],

            // ── Skip ─────────────────────────────────────────
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
            ),

            // ── Trust signals ────────────────────────────────
            Text('Cancel anytime • No hidden fees • Secure payment',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _onUpgradeTap() async {
    HapticFeedback.heavyImpact();
    setState(() => _loadingUpgrade = true);
    try {
      // TODO: Replace with real in_app_purchase flow
      // For now: direct unlock (AdMob-only phase)
      await MonetizationService.instance.upgradeToPremium();
      if (mounted) {
        Navigator.pop(context);
        widget.onUpgrade?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('👑 Welcome to Premium! No more limits.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint('Upgrade error: $e');
    } finally {
      if (mounted) setState(() => _loadingUpgrade = false);
    }
  }

  Future<void> _onWatchAdTap() async {
    HapticFeedback.lightImpact();
    setState(() => _loadingAd = true);
    // AdService rewarded — enable after: flutter pub get (google_mobile_ads)
    // Stub: grant reward directly for now
    await MonetizationService.instance.grantRewardedAIUse();
    if (mounted) {
      Navigator.pop(context);
      widget.onAdComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🎁 Reward unlocked! +1 AI plan available.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    if (mounted) setState(() => _loadingAd = false);
  }
}

// ═════════════════════════════════════════════════════════════
// AI USAGE PILL — shows "2/2 used • Watch ad" inline widget
// Use anywhere you show the AI button
// ═════════════════════════════════════════════════════════════
class AIUsagePill extends StatelessWidget {
  final bool isPremium;
  final int  used;
  final int  limit;
  final VoidCallback? onTap;

  const AIUsagePill({
    super.key,
    required this.isPremium,
    required this.used,
    required this.limit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('👑', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text('Unlimited', style: GoogleFonts.inter(
              color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    final remaining = (limit - used).clamp(0, limit);
    final isEmpty   = remaining == 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isEmpty
              ? AppColors.red.withValues(alpha: 0.12)
              : AppColors.textMuted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isEmpty
                  ? AppColors.red.withValues(alpha: 0.40)
                  : AppColors.borderSoft),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isEmpty ? Icons.lock_rounded : Icons.auto_awesome_rounded,
            size: 10,
            color: isEmpty ? AppColors.red : AppColors.textMuted,
          ),
          const SizedBox(width: 3),
          Text(
            isEmpty ? 'Limit reached' : '$remaining AI left',
            style: GoogleFonts.inter(
                color: isEmpty ? AppColors.red : AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// FUTURE PREVIEW ROW — Step 2: make user imagine the value
// ═════════════════════════════════════════════════════════════
class _FuturePreviewRow extends StatelessWidget {
  final String emoji, text;
  const _FuturePreviewRow(this.emoji, this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w500, height: 1.4))),
      const Icon(Icons.check_circle_rounded,
          color: AppColors.green, size: 14),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// PRICE PILL — Step 4: monthly vs yearly toggle
// ═════════════════════════════════════════════════════════════
class _PricePill extends StatelessWidget {
  final String price, period, badge;
  final bool isSelected, isHighlighted;
  final VoidCallback onTap;

  const _PricePill({
    required this.price, required this.period, required this.badge,
    required this.isSelected, required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.gold
        : AppColors.borderSoft;
    final bgColor = isSelected
        ? AppColors.gold.withValues(alpha: 0.10)
        : AppColors.bgSurface;

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color:  bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 0.8),
          boxShadow: isSelected ? [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.2),
              blurRadius: 10)] : null,
        ),
        child: Column(children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.green.withValues(alpha: 0.15)
                  : AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badge, style: GoogleFonts.inter(
                color: isHighlighted ? AppColors.green : AppColors.gold,
                fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          // Price
          Row(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Text(price, style: GoogleFonts.rajdhani(
                color: isSelected ? AppColors.gold : AppColors.textPrimary,
                fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(period, style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 11)),
            ),
          ]),
          // Selection indicator
          const SizedBox(height: 4),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.gold
                  : Colors.transparent,
              border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.borderMedium,
                  width: 1.5),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                    color: Colors.black, size: 11)
                : null,
          ),
        ]),
      ),
    );
  }
}
