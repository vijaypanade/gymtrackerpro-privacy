// lib/services/monetization_service.dart
// ════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
//   MonetizationService  ← single source of truth for all revenue logic
//       ↓
//   AppProvider          ← reads isPremium, canUseAI(), aiUsageCount
//       ↓
//   UI Screens           ← show paywall via PaywallTrigger enum
//
// REVENUE STREAM: Subscription only — ₹150/month or ₹1499/year
//
// PAYWALL TRIGGERS (behavior-based, non-annoying):
//   - AI limit hit       → "Upgrade for unlimited coaching"
//   - 5th workout done   → "You're consistent! Unlock full coaching"
//   - PR broken          → "You're progressing! Premium has adaptive plans"
//   - 7-day streak       → "Streak is building! Protect it with premium"
//   - Advanced stats tap → "Upgrade to see full analytics"
//
// PSYCHOLOGY:
//   - Show VALUE before paywall (let user taste premium features)
//   - Never interrupt a workout session
//   - Max 1 paywall prompt per day
// ════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'billing_service.dart';
import '../utils/app_constants.dart';

// ─────────────────────────────────────────────────────────────
// PAYWALL TRIGGER ENUM — why the paywall appeared
// ─────────────────────────────────────────────────────────────
enum PaywallTrigger {
  aiLimitHit,
  workoutMilestone,
  prBroken,
  streakMilestone,
  advancedStatsTap,
  manual,
}

extension PaywallTriggerX on PaywallTrigger {
  String get headline {
    switch (this) {
      case PaywallTrigger.aiLimitHit:
        return 'Train Without Limits';
      case PaywallTrigger.workoutMilestone:
        return 'You\'re Building Something Real';
      case PaywallTrigger.prBroken:
        return 'New PR. You\'re Getting Stronger';
      case PaywallTrigger.streakMilestone:
        return '7-Day Streak. Protect It';
      case PaywallTrigger.advancedStatsTap:
        return 'Unlock Full Analytics';
      case PaywallTrigger.manual:
        return 'Unlock Your Full Potential';
    }
  }

  String get subtext {
    switch (this) {
      case PaywallTrigger.aiLimitHit:
        return 'You\'ve hit your daily AI limit. Upgrade to Premium for unlimited AI coaching — no limits, ever.';
      case PaywallTrigger.workoutMilestone:
        return 'You\'ve completed 5+ workouts. Serious athletes use smart coaching.\nUpgrade to get adaptive plans built on your actual data.';
      case PaywallTrigger.prBroken:
        return 'You\'re getting stronger every week.\n\nDon\'t lose this momentum.\nUnlock AI coaching that adapts every week\nand predicts your next PR before you lift.';
      case PaywallTrigger.streakMilestone:
        return '7 days straight. That\'s rare. Premium gives you\nsmarter recovery, deload detection, and streak protection tools.';
      case PaywallTrigger.advancedStatsTap:
        return 'This feature is available for Premium members.\nSee fatigue index, plateau detection, and weekly trends.';
      case PaywallTrigger.manual:
        return 'Everything you need to train smarter,\nrecover better, and progress faster.';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MONETIZATION SERVICE — singleton
// ─────────────────────────────────────────────────────────────
class MonetizationService {
  MonetizationService._();
  static final MonetizationService instance = MonetizationService._();

  static const String _keyPremium         = 'is_premium_v2';

  String get _premiumKey {
    final uid = AuthService.instance.currentUser?.uid;
    return uid != null ? '${_keyPremium}_$uid' : _keyPremium;
  }

  static const String _keyAiUsageDate     = 'ai_usage_date_v1';
  static const String _keyAiUsageCount    = 'ai_usage_count_v1';
  static const String _keyLastPaywallDate = 'last_paywall_date_v1';
  static const String _keyChatUsageDate   = 'chat_usage_date_v1';
  static const String _keyChatUsageCount  = 'chat_usage_count_v1';

  static const int _freeAiLimit   = 3;
  static const int _freeChatLimit = 5;

  bool _isPremium      = false;
  int  _aiUsageToday   = 0;
  int  _chatUsageToday = 0;

  bool get isPremium    => _isPremium;
  int  get aiUsageToday => _aiUsageToday;
  int  get freeAiLimit  => _freeAiLimit;

  int get aiUsesRemaining {
    if (_isPremium) return 999;
    return (_freeAiLimit - _aiUsageToday).clamp(0, 99);
  }

  bool get canUseAI {
    if (_isPremium) return true;
    return _aiUsageToday < _freeAiLimit;
  }

  bool get canUseChat {
    if (_isPremium) return true;
    return _chatUsageToday < _freeChatLimit;
  }

  int get chatUsesRemaining {
    if (_isPremium) return 999;
    return (_freeChatLimit - _chatUsageToday).clamp(0, 99);
  }

  int get chatUsageToday => _chatUsageToday;
  int get freeChatLimit  => _freeChatLimit;

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium      = prefs.getBool(_premiumKey) ?? false;
      _resetDailyCountsIfNeeded(prefs);
      _aiUsageToday   = prefs.getInt(_keyAiUsageCount)   ?? 0;
      _chatUsageToday = prefs.getInt(_keyChatUsageCount) ?? 0;
    } catch (e) {
      debugPrint('MonetizationService.init error: $e');
    }
  }

  void _resetDailyCountsIfNeeded(SharedPreferences prefs) {
    final today    = _todayStr;
    final lastDate = prefs.getString(_keyAiUsageDate) ?? '';
    if (lastDate != today) {
      prefs.setString(_keyAiUsageDate, today);
      prefs.setInt(_keyAiUsageCount,   0);
      _aiUsageToday = 0;
    }
    final lastChatDate = prefs.getString(_keyChatUsageDate) ?? '';
    if (lastChatDate != today) {
      prefs.setString(_keyChatUsageDate, today);
      prefs.setInt(_keyChatUsageCount, 0);
      _chatUsageToday = 0;
    } else {
      _chatUsageToday = prefs.getInt(_keyChatUsageCount) ?? 0;
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

  Future<void> recordChatMessageUse() async {
    _chatUsageToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyChatUsageCount, _chatUsageToday);
  }

  // ─────────────────────────────────────────────────────────
  // PREMIUM UPGRADE
  // ─────────────────────────────────────────────────────────
  Future<void> upgradeToPremium({String plan = 'yearly'}) async {
    try {
      final productId = plan == 'monthly'
          ? BillingProducts.monthly
          : BillingProducts.yearly;
      await BillingService.instance.purchase(productId);
    } catch (e) {
      debugPrint('Billing error: $e');
      rethrow;
    }
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
    debugPrint('✅ Premium: $value');
  }

  void markPremiumFromBilling() {
    _isPremium = true;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_premiumKey, true);
    });
    debugPrint('✅ Premium granted via BillingService');
  }

  Future<void> revokePremium() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    // Use the UID-scoped key if available. If called during sign-out, currentUser
    // may already be null — capture the key from _premiumKey BEFORE Firebase clears
    // the session. BillingService._onAuthStateChanged calls this; at that point the
    // auth state has already changed, so we write to the global fallback key.
    // That is acceptable: the critical effect is _isPremium = false in memory.
    await prefs.setBool(_premiumKey, false);
  }

  // ─────────────────────────────────────────────────────────
  // PAYWALL TRIGGER LOGIC — max 1/day
  // ─────────────────────────────────────────────────────────
  Future<bool> shouldShowPaywall(PaywallTrigger trigger) async {
    if (_isPremium) return false;
    if (trigger == PaywallTrigger.aiLimitHit) return true;
    try {
      final prefs    = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_keyLastPaywallDate) ?? '';
      if (lastDate == _todayStr) return false;
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
// PAYWALL SHEET
// Usage: PaywallSheet.show(context, trigger: PaywallTrigger.prBroken)
// ═════════════════════════════════════════════════════════════
class PaywallSheet extends StatefulWidget {
  final PaywallTrigger trigger;
  final VoidCallback?  onUpgrade;

  const PaywallSheet({
    super.key,
    required this.trigger,
    this.onUpgrade,
  });

  static Future<void> show(
    BuildContext context, {
    required PaywallTrigger trigger,
    VoidCallback? onUpgrade,
  }) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => PaywallSheet(
        trigger:   trigger,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _loadingUpgrade = false;
  String _selectedPlan = 'yearly';

  @override
  void initState() {
    super.initState();
    BillingService.instance.addListener(_onBillingUpdate);
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onBillingUpdate);
    super.dispose();
  }

  void _onBillingUpdate() {
    if (!mounted || !_loadingUpgrade) return;
    final b = BillingService.instance;
    if (b.isPremium) {
      setState(() => _loadingUpgrade = false);
      Navigator.pop(context);
      widget.onUpgrade?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Welcome to Premium — no more limits.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (b.isPendingVerification) {
      // Purchase received — waiting for store to confirm. Keep paywall open but
      // clear the spinner so the user knows the app is waiting, not frozen.
      setState(() => _loadingUpgrade = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment received — verifying with store…',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (b.status == BillingStatus.error) {
      setState(() => _loadingUpgrade = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment failed. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (b.status == BillingStatus.available) {
      setState(() => _loadingUpgrade = false);
    }
  }

  static const _features = [
    (Icons.auto_awesome_rounded,      'Unlimited AI workout plans',         true),
    (Icons.bar_chart_rounded,         'Advanced analytics & fatigue index', true),
    (Icons.psychology_rounded,        'Smart coaching insights',            true),
    (Icons.track_changes_rounded,     'Plateau detection & deload alerts',  true),
    (Icons.fitness_center_rounded,    'Weak muscle detection',              true),
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
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            // Crown icon
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppGradients.gold),
              child: const Center(
                  child: Icon(Icons.workspace_premium_rounded,
                      color: Colors.black, size: 34)),
            ),
            const SizedBox(height: 16),

            // Headline
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

            // Future preview
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
                const _FuturePreviewRow(Icons.trending_up_rounded, 'Next week plan auto-adjusts to your progress'),
                const SizedBox(height: 6),
                const _FuturePreviewRow(Icons.psychology_rounded, 'AI tracks your weak muscles every session'),
                const SizedBox(height: 6),
                const _FuturePreviewRow(Icons.emoji_events_rounded, 'Advanced PR predictions — know before you lift'),
                const SizedBox(height: 6),
                const _FuturePreviewRow(Icons.track_changes_rounded, 'Deload auto-detected — never overtrain again'),
              ]),
            ),
            const SizedBox(height: 20),

            // Feature list
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
                    Icon(f.$1, color: AppColors.gold, size: 16),
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
                    ),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Price pills — monthly + yearly
            Row(children: [
              Expanded(child: _PricePill(
                price: '₹150', period: '/mo',
                badge: '14 days free',
                isSelected: _selectedPlan == 'monthly',
                onTap: () => setState(() => _selectedPlan = 'monthly'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _PricePill(
                price: '₹1499', period: '/yr',
                badge: 'Save 17%',
                isSelected: _selectedPlan == 'yearly',
                isHighlighted: true,
                onTap: () => setState(() => _selectedPlan = 'yearly'),
              )),
            ]),
            const SizedBox(height: 16),

            // Social proof
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded,
                      color: AppColors.gold, size: 13),
                  const SizedBox(width: 4),
                  Text('Cancel anytime · Billed annually',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            // Upgrade CTA
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
                      child: Column(
                        children: [
                          Text(
                              _selectedPlan == 'yearly'
                                  ? 'Start Free Trial — ₹1,499/yr'
                                  : 'Start Free Trial — ₹150/mo',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.rajdhani(
                                  color: Colors.black, fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          Text('No payment today • Cancel anytime',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: Colors.black54, fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 10),

            // Skip
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
            ),

            // Trust signal
            Text('Auto-renews · Cancel before trial ends to avoid charges',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    fontSize: 9),
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
      final productId = _selectedPlan == 'monthly'
          ? BillingProducts.monthly
          : BillingProducts.yearly;
      await BillingService.instance.purchase(productId);
    } catch (e) {
      debugPrint('Upgrade error: $e');
      if (mounted) {
        setState(() => _loadingUpgrade = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════
// AI USAGE PILL
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
// FUTURE PREVIEW ROW
// ═════════════════════════════════════════════════════════════
class _FuturePreviewRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FuturePreviewRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.gold, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w500, height: 1.4))),
      const Icon(Icons.check_circle_rounded,
          color: AppColors.gold, size: 14),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// PRICE PILL
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
    final borderColor = isSelected ? AppColors.gold : AppColors.borderSoft;
    final bgColor     = isSelected
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: isHighlighted ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badge, style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
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
          if (isHighlighted) ...[
            const SizedBox(height: 2),
            Text('Just ₹125/month',
                style: GoogleFonts.inter(
                    color: AppColors.goldSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 4),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.gold : Colors.transparent,
              border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.borderMedium,
                  width: 1.5),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 11)
                : null,
          ),
        ]),
      ),
    );
  }
}
