// lib/screens/premium_screen.dart — v2.0 FULL REBUILD
// Premium screen with proper UX, feature comparison, pricing
// Tapping "Upgrade" routes through MonetizationService

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/monetization_service.dart';
import '../utils/app_constants.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  bool _loading = false;
  String _selectedPlan = 'yearly'; // yearly default — best value anchor

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() { _shimmer.dispose(); super.dispose(); }

  // ── Feature rows: (emoji, label, free, premium) ──────────
  static const _features = [
    ('🤖', 'AI Workout Plans',         '2/day',      'Unlimited'),
    ('📅', 'Weekly Planner',           '✓',          '✓'),
    ('💪', 'PR Tracking',              '✓',          '✓'),
    ('🔥', 'Streaks & XP',             '✓',          '✓'),
    ('📊', 'Basic Stats',              '✓',          '✓'),
    ('📈', 'Fatigue & Plateau Index',  '—',          '✓'),
    ('🧠', 'Scientific AI Coach',      '—',          '✓'),
    ('🎯', 'Weak Muscle Detection',    '—',          '✓'),
    ('🔄', 'Weekly Memory Coaching',   '—',          '✓'),
  ];

  @override
  Widget build(BuildContext context) {
    final top  = MediaQuery.of(context).padding.top;
    final p    = context.watch<AppProvider>();

    if (p.isPremium) return _AlreadyPremiumScreen();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverToBoxAdapter(child: Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text('Go Premium', style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w900)),
            ]),
          )),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Crown + headline ───────────────────────────
              Center(child: AnimatedBuilder(
                animation: _shimmer,
                builder: (_, __) => Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment(-1 + _shimmer.value * 2, -1),
                      end:   Alignment( 1 + _shimmer.value * 2,  1),
                      colors: const [
                        Color(0xFFFFCC00), Color(0xFFFF9900),
                        Color(0xFFFFCC00),
                      ],
                    ),
                    boxShadow: [BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 24, spreadRadius: 2)],
                  ),
                  child: const Center(
                      child: Icon(Icons.workspace_premium_rounded,
                          color: Colors.black, size: 38)),
                ),
              )),
              const SizedBox(height: 20),

              Text('Unlock Full Potential',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary, fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Everything you need to train smarter,\nrecover better, and progress faster.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 28),

              // ── STEP 2: Future Preview ─────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0900),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.22)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.gold, size: 13),
                    const SizedBox(width: 6),
                    Text('WHAT HAPPENS NEXT WEEK',
                        style: GoogleFonts.inter(
                            color: AppColors.gold, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 10),
                  _PreviewRow(Icons.trending_up_rounded, 'Next week plan auto-adjusts to your progress'),
                  const SizedBox(height: 6),
                  _PreviewRow(Icons.psychology_rounded, 'AI tracks your weak muscles every session'),
                  const SizedBox(height: 6),
                  _PreviewRow(Icons.emoji_events_rounded, 'Advanced PR predictions — know before you lift'),
                  const SizedBox(height: 6),
                  _PreviewRow(Icons.track_changes_rounded, 'Deload auto-detected — never overtrain again'),
                ]),
              ),
              const SizedBox(height: 20),

              // ── STEP 4: Dual pricing — monthly + yearly ────
              Row(children: [
                Expanded(child: _PlanTile(
                  price: '₹150', period: '/month',
                  badge: '3 days free', badgeColor: AppColors.green,
                  isSelected: _selectedPlan == 'monthly',
                  onTap: () => setState(() => _selectedPlan = 'monthly'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _PlanTile(
                  price: '₹1000', period: '/year',
                  badge: 'Save 58%', badgeColor: AppColors.orange,
                  isSelected: _selectedPlan == 'yearly',
                  isPopular: true,
                  onTap: () => setState(() => _selectedPlan = 'yearly'),
                )),
              ]),
              const SizedBox(height: 20),

              // ── Feature comparison table ───────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(children: [
                      const Expanded(child: SizedBox()),
                      SizedBox(width: 64, child: Text('FREE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1))),
                      SizedBox(width: 72, child: Text('PRO',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.gold, fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1))),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  // Feature rows
                  ..._features.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    final isLast = i == _features.length - 1;
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(children: [
                          Text(f.$1, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f.$2,
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))),
                          SizedBox(width: 64, child: Text(f.$3,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: f.$3 == '—'
                                      ? AppColors.textMuted
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                          SizedBox(width: 72, child: Text(f.$4,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: f.$4 == '✓' || f.$4 == 'Unlimited'
                                      ? AppColors.gold
                                      : AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800))),
                        ]),
                      ),
                      if (!isLast) const Divider(
                          height: 1, color: AppColors.divider,
                          indent: 16, endIndent: 16),
                    ]);
                  }),
                ]),
              ),
              const SizedBox(height: 28),

              // ── CTA Button ─────────────────────────────────
              _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.gold))
                  : GestureDetector(
                      onTap: _onUpgrade,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFCC00), Color(0xFFFF9900)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 20, offset: const Offset(0, 5))],
                        ),
                        child: Text(
                            _selectedPlan == 'yearly'
                              ? 'Start Free — ₹1000/yr 🚀'
                              : 'Start Free — ₹150/mo 🚀',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                                color: Colors.black, fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
              const SizedBox(height: 12),

              // ── Trust badges ───────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _TrustBadge('🔒', 'Secure'),
                const SizedBox(width: 16),
                _TrustBadge('↩️', 'Cancel anytime'),
                const SizedBox(width: 16),
                _TrustBadge('🚫', 'No hidden fees'),
              ]),
              const SizedBox(height: 20),

              Center(child: Text(
                'Billed monthly. Cancel anytime in Google Play.',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 10),
              )),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://play.google.com/store/account/subscriptions',
                  );
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                child: Text(
                  'Manage Subscription',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ])),
          ),
        ],
      ),
    );
  }

  Future<void> _onUpgrade() async {
    HapticFeedback.heavyImpact();
    setState(() => _loading = true);
    try {
      await MonetizationService.instance.upgradeToPremium(plan: _selectedPlan);
      if (!mounted) return;
      context.read<AppProvider>().notifyListeners();
      {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Welcome to Premium — unlimited AI coaching unlocked.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _TrustBadge extends StatelessWidget {
  final String emoji, label;
  const _TrustBadge(this.emoji, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 10,
          fontWeight: FontWeight.w600)),
    ],
  );
}

// ── Already Premium screen ─────────────────────────────────────
class _AlreadyPremiumScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, top + 40, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppGradients.gold),
              child: const Center(
                  child: Icon(Icons.workspace_premium_rounded,
                      color: Colors.black, size: 44)),
            ),
            const SizedBox(height: 24),
            Text('You\'re Premium!', style: GoogleFonts.rajdhani(
                color: AppColors.gold, fontSize: 28,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('All features unlocked. Unlimited AI. Full analytics.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 14,
                    height: 1.5)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
                  borderRadius: BorderRadius.circular(14)),
                child: Text('Back to Training 💪',
                    style: GoogleFonts.rajdhani(
                        color: Colors.black, fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Future preview row ─────────────────────────────────────────
class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PreviewRow(this.icon, this.text);

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
          color: AppColors.green, size: 14),
    ],
  );
}

// ── Plan tile — monthly / yearly toggle ───────────────────────
class _PlanTile extends StatelessWidget {
  final String price, period, badge;
  final Color badgeColor;
  final bool isSelected, isPopular;
  final VoidCallback onTap;

  const _PlanTile({
    required this.price, required this.period,
    required this.badge, required this.badgeColor,
    required this.isSelected, required this.onTap,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(
          14,
          isPopular ? 18 : 14,
          14,
          isPopular ? 18 : 14,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.14),
                    AppColors.gold.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? AppColors.gold : AppColors.borderSoft,
              width: isSelected ? 1.8 : 0.8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Column(children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(4)),
              child: Text('BEST VALUE', style: GoogleFonts.inter(
                  color: Colors.black, fontSize: 8,
                  fontWeight: FontWeight.w900)),
            ),
          if (isPopular) const SizedBox(height: 6),
          Text(price, style: GoogleFonts.rajdhani(
              color: isSelected ? AppColors.gold : AppColors.textPrimary,
              fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
          Text(period, style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4)),
            child: Text(badge, style: GoogleFonts.inter(
                color: badgeColor, fontSize: 9,
                fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.gold : Colors.transparent,
              border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.borderMedium,
                  width: 1.5)),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                    color: Colors.black, size: 12)
                : null,
          ),
        ]),
      ),
    );
  }
}
