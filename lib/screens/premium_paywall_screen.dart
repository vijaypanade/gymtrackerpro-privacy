// lib/screens/premium_paywall_screen.dart
// Premium conversion paywall — shown when free user hits AI limit or feature gate.
//
// Architecture:
//   - Full-screen modal (not bottom sheet) — higher conversion rate
//   - Yearly plan pre-selected — anchors to best value
//   - 14-day free trial as primary CTA
//   - Integrates with existing BillingService (in_app_purchase)
//   - RevenueCat-swap-ready: replace BillingService calls in _purchase()
//
// Trigger:
//   final purchased = await PremiumPaywallScreen.show(context, source: 'ai_limit');
//
// Play Store compliance:
//   ✓ Dismissible (Skip button always visible)
//   ✓ Trial terms disclosed below CTA
//   ✓ Auto-renewal disclosed
//   ✓ Restore Purchases available
//   ✓ Terms & Privacy links present

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:url_launcher/url_launcher.dart';

import '../services/billing_service.dart';
import '../utils/app_constants.dart';

// ── Plan data model ──────────────────────────────────────────────────────────

enum _PlanId { monthly, yearly }

class _Plan {
  final _PlanId  id;
  final String   productId;
  final String   title;
  final String   price;
  final String   period;
  final String?  perMonth;   // shown under price for multi-month plans
  final String?  badge;      // null | 'MOST POPULAR' | 'BEST VALUE'
  final String?  savings;    // null | 'Save 22%' | 'Save 44%'
  final bool     isHero;     // full-width hero card layout

  const _Plan({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
    required this.period,
    this.perMonth,
    this.badge,
    this.savings,
    this.isHero = false,
  });
}

// Note: in production these prices come from ProductDetails.price (Play Store).
// These are display fallbacks while products are loading.
final _kPlans = [
  _Plan(
    id:        _PlanId.yearly,
    productId: BillingProducts.yearly,
    title:     'Yearly',
    price:     '₹1499',
    period:    '/year',
    perMonth:  'Only ₹125/month',
    badge:     'BEST VALUE',
    savings:   'Save 17%',
    isHero:    true,
  ),
  _Plan(
    id:        _PlanId.monthly,
    productId: BillingProducts.monthly,
    title:     'Monthly',
    price:     '₹150',
    period:    '/month',
    badge:     'MOST POPULAR',
  ),
];

// The store returns the price already formatted for the user's storefront and
// currency, and that is the only figure they are actually charged. The hardcoded
// ₹ strings above are a placeholder for the brief moment before products finish
// loading — showing them to a non-INR storefront advertises a price that will
// not be charged (App Store Guideline 3.1.2 / Play equivalent).
ProductDetails? _storeProduct(String productId) {
  for (final p in BillingService.instance.products) {
    if (p.id == productId) return p;
  }
  return null;
}

String _livePrice(_Plan plan) => _storeProduct(plan.productId)?.price ?? plan.price;

// Derived per-month figure for the yearly plan. Recomputed from the live price
// so the currency matches; falls back to the placeholder only while loading.
String? _livePerMonth(_Plan plan) {
  if (plan.perMonth == null) return null;
  final p = _storeProduct(plan.productId);
  if (p == null) return plan.perMonth;
  return 'Only ${p.currencySymbol}${(p.rawPrice / 12).toStringAsFixed(0)}/month';
}

const _kFeatures = [
  (Icons.all_inclusive_rounded,     'Unlimited Coaching',          'Daily limit removed'),
  (Icons.fitness_center_rounded,    'Advanced Workout Plans',      'Periodized & adaptive'),
  (Icons.monitor_heart_rounded,     'Recovery Intelligence',       'Deep fatigue analysis'),
  (Icons.trending_up_rounded,       'Performance Analytics',       'Advanced stats & insights'),
  (Icons.star_rounded,              'All Future Features',         'Included at no extra cost'),
];

// ── Screen ───────────────────────────────────────────────────────────────────

class PremiumPaywallScreen extends StatefulWidget {
  final String source; // 'ai_limit' | 'feature' | 'manual'

  const PremiumPaywallScreen({super.key, this.source = 'ai_limit'});

  /// Show as full-screen modal. Returns true if purchase succeeded.
  static Future<bool> show(
    BuildContext context, {
    String source = 'ai_limit',
  }) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: PremiumPaywallScreen(source: source),
        ),
      ),
    );
    return result == true;
  }

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen>
    with TickerProviderStateMixin {
  _PlanId _selected  = _PlanId.yearly;
  bool    _purchasing = false;
  bool    _restoring  = false;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryAnim;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<void> _purchase() async {
    final plan = _kPlans.firstWhere((p) => p.id == _selected);
    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);

    try {
      await BillingService.instance.purchase(plan.productId);
      // BillingService notifies listeners — AppProvider / MonetizationService
      // handle premium state. We close paywall on success.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: AppColors.bgElevated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.lightImpact();
    setState(() => _restoring = true);
    try {
      await BillingService.instance.restorePurchases();
      if (mounted && BillingService.instance.isPremium) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active subscription found.')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end:   Offset.zero,
        ).animate(_entryAnim),
        child: FadeTransition(
          opacity: _entryAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildTriggerBadge()),
              SliverToBoxAdapter(child: _buildFeatureList()),
              SliverToBoxAdapter(child: _buildPricingSection()),
              SliverToBoxAdapter(child: _buildCtaSection()),
              SliverToBoxAdapter(child: _buildFooter()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Atmospheric gold gradient background
        SizedBox(
          height: 240 + topPad,
          child: CustomPaint(painter: _HeaderGlowPainter()),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.borderMedium, width: 0.5),
                    ),
                    child: Text('Skip',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Crown icon with shimmer
              Center(
                child: AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) {
                    final t = _shimmerCtrl.value;
                    return Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          startAngle: 0,
                          endAngle: math.pi * 2,
                          transform: GradientRotation(t * math.pi * 2),
                          colors: const [
                            Color(0xFFD4AF37),
                            Color(0xFFFFD700),
                            Color(0xFFFFF176),
                            Color(0xFFFFD700),
                            Color(0xFFD4AF37),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                          child: Icon(Icons.workspace_premium_rounded,
                              color: Colors.black, size: 36)),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Headline
              Center(
                child: Text(
                  'Train Without Limits',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Subheadline
              Center(
                child: Text(
                  'Start your 14-day free trial.\nNo payment today.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ── Trigger badge ─────────────────────────────────────────────────────────
  // Context-aware message explaining WHY paywall appeared.

  Widget _buildTriggerBadge() {
    if (widget.source != 'ai_limit') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0F00),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
              color: AppColors.goldAmber.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.goldAmber, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'ve used today\'s plan limit. '
                'Go Premium for unlimited coaching, every day.',
                style: GoogleFonts.inter(
                  color: AppColors.goldSoft,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feature list ──────────────────────────────────────────────────────────

  Widget _buildFeatureList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.borderSoft, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREMIUM INCLUDES',
              style: GoogleFonts.inter(
                color: AppColors.goldAmber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_kFeatures.length, (i) {
              final (icon, label, sub) = _kFeatures[i];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i < _kFeatures.length - 1 ? 14 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon,
                          color: AppColors.gold, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              )),
                          Text(sub,
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              )),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.gold, size: 18),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Pricing section ───────────────────────────────────────────────────────

  Widget _buildPricingSection() {
    final heroplan = _kPlans.firstWhere((p) => p.isHero); // yearly
    final sidePlans = _kPlans.where((p) => !p.isHero).toList(); // monthly

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE YOUR PLAN',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),

          // ── Hero card (Yearly) ────────────────────────────────────────────
          _HeroPlanCard(
            plan:       heroplan,
            isSelected: _selected == heroplan.id,
            shimmer:    _shimmerCtrl,
            pulse:      _pulseCtrl,
            onTap:      () {
              HapticFeedback.selectionClick();
              setState(() => _selected = heroplan.id);
            },
          ),
          const SizedBox(height: 10),

          // ── Monthly card ──────────────────────────────────────────────────
          Row(
            children: sidePlans.map((plan) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: plan == sidePlans.first ? 5 : 0,
                    left:  plan == sidePlans.last  ? 5 : 0,
                  ),
                  child: _SidePlanCard(
                    plan:       plan,
                    isSelected: _selected == plan.id,
                    onTap:      () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = plan.id);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── CTA section ───────────────────────────────────────────────────────────

  Widget _buildCtaSection() {
    final plan = _kPlans.firstWhere((p) => p.id == _selected);
    final isYearly = _selected == _PlanId.yearly;

    final trialLine = isYearly
        ? '${_livePrice(plan)}/year billed after trial ends'
        : '${_livePrice(plan)}/month billed after 14-day trial';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Primary CTA
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final glow = 0.3 + _pulseCtrl.value * 0.15;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: glow),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _purchasing ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  elevation: 0,
                ),
                child: _purchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black54,
                        ),
                      )
                    : Text(
                        'Start 14-Day Free Trial',
                        style: GoogleFonts.rajdhani(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Trial disclosure (Play Store required)
          Text(
            '$trialLine · Cancel anytime',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-renews. Cancel before trial ends to avoid charges.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textDisabled.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          // Divider
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),

          // Restore + links row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(
                label: 'Restore Purchase',
                loading: _restoring,
                onTap: _restorePurchases,
              ),
              _FooterDot(),
              _FooterLink(
                label: 'Terms of Use',
                onTap: () => _openUrl(
                    'https://liftonapp.com/terms'),
              ),
              _FooterDot(),
              _FooterLink(
                label: 'Privacy Policy',
                onTap: () => _openUrl(
                    'https://liftonapp.com/privacy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Hero plan card (Yearly — full width) ─────────────────────────────────────

class _HeroPlanCard extends StatelessWidget {
  final _Plan              plan;
  final bool               isSelected;
  final AnimationController shimmer;
  final AnimationController pulse;
  final VoidCallback       onTap;

  const _HeroPlanCard({
    required this.plan,
    required this.isSelected,
    required this.shimmer,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([shimmer, pulse]),
        builder: (_, child) {
          final borderAlpha = isSelected
              ? 0.85 + pulse.value * 0.15
              : 0.30;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0D0B02)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: borderAlpha),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge + radio row
            Row(
              children: [
                // BEST VALUE badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFFFD700),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.badge ?? '',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (plan.savings != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    plan.savings!,
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                _RadioDot(selected: isSelected),
              ],
            ),

            const SizedBox(height: 14),

            // Price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _livePrice(plan),
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    plan.period,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            if (_livePerMonth(plan) != null) ...[
              const SizedBox(height: 4),
              Text(
                _livePerMonth(plan)!,
                style: GoogleFonts.inter(
                  color: AppColors.goldSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Trial highlight
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded,
                    color: AppColors.gold, size: 15),
                const SizedBox(width: 6),
                Text(
                  '14-day free trial included',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Side plan card (Monthly) ──────────────────────────────────────────────────

class _SidePlanCard extends StatelessWidget {
  final _Plan     plan;
  final bool      isSelected;
  final VoidCallback onTap;

  const _SidePlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D0B02) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.75)
                : AppColors.borderSoft,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            if (plan.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.borderMedium, width: 0.5),
                ),
                child: Text(
                  plan.badge!,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else if (plan.savings != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  plan.savings!,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(height: 20),

            Text(
              _livePrice(plan),
              style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              plan.period,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),

            if (_livePerMonth(plan) != null) ...[
              const SizedBox(height: 4),
              Text(
                _livePerMonth(plan)!,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.title,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _RadioDot(selected: isSelected, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Radio dot ─────────────────────────────────────────────────────────────────

class _RadioDot extends StatelessWidget {
  final bool   selected;
  final double size;
  const _RadioDot({required this.selected, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.gold : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderStrong,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? const Center(
              child: Icon(Icons.check_rounded,
                  color: Colors.black, size: 12))
          : null,
    );
  }
}

// ── Footer link ───────────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  final String     label;
  final VoidCallback onTap;
  final bool       loading;

  const _FooterLink({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.textMuted))
          : Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textDisabled,
              ),
            ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('·',
          style: GoogleFonts.inter(
            color: AppColors.textDisabled,
            fontSize: 14,
          )),
    );
  }
}

// ── Header atmospheric glow painter ──────────────────────────────────────────

class _HeaderGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Warm gold radial glow from top-center
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [
            Color(0x22D4AF37),
            Color(0x10D4AF37),
            Color(0x00D4AF37),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_HeaderGlowPainter _) => false;
}
