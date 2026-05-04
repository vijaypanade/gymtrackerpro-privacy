// lib/screens/planner_screen.dart — v9.0 PHASE 1
// PHASE 1 UPGRADES:
//   ① HAPTICS — consistent system throughout (heavy/medium/light/selection)
//   ② PLANNER UI — complete premium redesign:
//      • AppBar: gradient title, workout summary pill
//      • AI Banner: glassmorphism card with animated typing indicator
//      • Day Strip: larger tiles, progress arc, today pulse dot
//      • Day Header: workout stats row (exercises · sets · volume)
//      • Exercise Cards: full-width emoji icon, category chip, live volume display
//      • Set Rows: numbered circles, weight/reps inline display, green fill done
//      • Complete Button: full gold gradient CTA
//      • Streak dialog: large emoji + coach copy + auto-dismiss
//   ③ GOOGLE FONTS FALLBACK — TextStyle fallback when fonts can't load
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/ai_engine.dart';
import '../services/monetization_service.dart'; // ✅ Paywall
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/gamification_provider.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/progress_chart.dart';
import '../data/exercise_data.dart';
import 'ai_chat_screen.dart';
import '../widgets/confetti_celebration.dart';
import '../widgets/pr_celebration.dart';
import '../services/ad_service.dart';
// ════════════════════════════════════════════════
// HAPTICS HELPER — consistent system
// ════════════════════════════════════════════════
class H{
  static void heavy()     => HapticFeedback.heavyImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void light()     => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success()   => HapticFeedback.heavyImpact();
  static void tap()       => HapticFeedback.lightImpact();
}

// ════════════════════════════════════════════════
// BADGE DIALOG
// ════════════════════════════════════════════════
void showBadgesDialog(BuildContext context, List<AppBadge> badges) {
  if (badges.isEmpty) return;
  H.success();
  showDialog(context: context, builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.bgModal,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.22),
              blurRadius: 40, spreadRadius: 4)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.sm),
          Text('BADGE UNLOCKED', style: GoogleFonts.inter(
              color: AppColors.gold, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: AppSpacing.lg),
          ...badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(b.emoji,
                    style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: GoogleFonts.rajdhani(
                    color: AppColors.gold, fontSize: 17,
                    fontWeight: FontWeight.w800)),
                Text(b.description, style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
              ])),
            ]),
          )),
          const SizedBox(height: AppSpacing.sm),
          GoldButton(text: 'Let\'s Go! 💪',
              width: double.infinity,
              onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  ));
}

// ════════════════════════════════════════════════
// PLANNER SCREEN
// ════════════════════════════════════════════════
class PlannerScreen extends StatefulWidget {
  final int? initialDayIndex;
  const PlannerScreen({super.key, this.initialDayIndex});
  @override State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _day = 0;
  static const _names = [
    'Monday','Tuesday','Wednesday',
    'Thursday','Friday','Saturday','Sunday'];
  static const _shorts = ['MON','TUE','WED','THU','FRI','SAT','SUN'];

  @override
  void initState() {
    super.initState();
    final i = widget.initialDayIndex;
    _day = (i != null && i >= 0 && i < 7)
        ? i : (DateTime.now().weekday - 1).clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    if (p.loading) return Scaffold(
      backgroundColor: AppColors.bg,
      body: const Center(child: CircularProgressIndicator(
          color: AppColors.gold)));

    if (p.weekPlan.length < 7) return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.gold),
        const SizedBox(height: AppSpacing.lg),
        Text('Setting up your plan…', style: GoogleFonts.inter(
            color: AppColors.textMuted)),
      ])));

    final safe = _day.clamp(0, p.weekPlan.length - 1);
    final day  = p.weekPlan[safe];
    final col  = AppColors.dayColors[safe % AppColors.dayColors.length];

    // Workout summary for AppBar subtitle
    final exCount  = day.exercises.length;
    final setCount = day.exercises.fold(0, (s, e) => s + e.sets.length);
    final doneCount= day.completedExercises;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [

        // ── PREMIUM APP BAR ───────────────────────
        _PlannerAppBar(
          dayName: _names[safe],
          color: col,
          exCount: exCount,
          setCount: setCount,
          doneCount: doneCount,
          isRest: day.isRestDay,
          isDone: day.isCompleted,
          onAI: () => Navigator.push(context,
              slideRoute(const AIChatScreen())),
          onBack: () => Navigator.pop(context),
        ),

        // ── AI BANNER ─────────────────────────────
        _AIBanner(message: p.aiSuggestion, tdee: p.tdee),

        // ── DAY STRIP ─────────────────────────────
        _DayStrip(
          selected: safe,
          plan: p.weekPlan,
          todayIdx: p.todayIndex,
          shorts: _shorts,
          onSelect: (i) {
            H.selection();
            setState(() => _day = i);
          },
        ),

        // ── DAY BODY ──────────────────────────────
        Expanded(child: _DayBody(
          idx: safe, name: _names[safe], provider: p)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// PREMIUM APP BAR
// ════════════════════════════════════════════════
class _PlannerAppBar extends StatelessWidget {
  final String dayName;
  final Color color;
  final int exCount, setCount, doneCount;
  final bool isRest, isDone;
  final VoidCallback onAI, onBack;

  const _PlannerAppBar({
    required this.dayName, required this.color,
    required this.exCount, required this.setCount,
    required this.doneCount,
    required this.isRest, required this.isDone,
    required this.onAI, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.sm, top + AppSpacing.sm,
          AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
            bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        // Back button
        _Tap(
          onTap: () { H.tap(); onBack(); },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Title + subtitle
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('WEEKLY PLANNER', style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 1),
          // Workout stats pill
          if (!isRest && exCount > 0)
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.green : color)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDone
                      ? '✓ $dayName complete'
                      : '$dayName · $doneCount/$exCount done',
                  style: GoogleFonts.inter(
                    color: isDone ? AppColors.green : color,
                    fontSize: 10, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ])
          else
            Text(isRest ? '$dayName · Rest Day 😴'
                : '$dayName · No workout',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 10)),
        ])),

        // AI button
        _Tap(
          onTap: () { H.tap(); onAI(); },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0.15),
                AppColors.gold.withValues(alpha: 0.07),
              ]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.smart_toy_rounded,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 4),
              Text('AI', style: GoogleFonts.inter(
                  color: AppColors.gold, fontSize: 11,
                  fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// AI BANNER — glassmorphism
// ════════════════════════════════════════════════
class _AIBanner extends StatelessWidget {
  final String message;
  final double tdee;
  const _AIBanner({required this.message, required this.tdee});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 4),
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
    decoration: BoxDecoration(
      color: const Color(0xFF0B0900),
      borderRadius: BorderRadius.circular(AppSpacing.md),
      border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.18), width: 0.8),
    ),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: AppGradients.gold),
        child: const Center(child: Text('🤖',
            style: TextStyle(fontSize: 15))),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(message.isEmpty ? '💪 Ready to crush it today!' : message,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 12,
                fontWeight: FontWeight.w500, height: 1.3)),
        Text('TDEE ${tdee.toStringAsFixed(0)} kcal',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 9.5,
                fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}

// ════════════════════════════════════════════════
// DAY STRIP — larger tiles, progress, today pulse
// ════════════════════════════════════════════════
class _DayStrip extends StatelessWidget {
  final int selected, todayIdx;
  final List<DayPlan> plan;
  final List<String> shorts;
  final ValueChanged<int> onSelect;

  const _DayStrip({
    required this.selected, required this.todayIdx,
    required this.plan, required this.shorts, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final n = plan.length.clamp(0, 7);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
            bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.4))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: List.generate(n, (i) {
          final day = plan[i];
          final sel = i == selected;
          final tod = i == todayIdx;
          final col = AppColors.dayColors[i % AppColors.dayColors.length];

          return Expanded(child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? col.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? col
                      : tod
                          ? col.withValues(alpha: 0.35)
                          : Colors.transparent,
                  width: sel ? 1.5 : 1,
                ),
                boxShadow: sel ? [BoxShadow(
                    color: col.withValues(alpha: 0.20),
                    blurRadius: 8)] : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Day label
                Text(shorts[i], style: GoogleFonts.inter(
                  color: sel
                      ? col
                      : tod
                          ? col.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                  fontSize: 9.5, fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
                const SizedBox(height: 5),

                // Day indicator dot / icon
                _DayIndicator(day: day, color: col, sel: sel, tod: tod),

                // Today pulse dot
                if (tod) ...[
                  const SizedBox(height: 4),
                  _PulseDot(color: col),
                ] else
                  const SizedBox(height: 8),
              ]),
            ),
          ));
        }),
      ),
    );
  }
}

class _DayIndicator extends StatelessWidget {
  final DayPlan day; final Color color; final bool sel, tod;
  const _DayIndicator({required this.day, required this.color,
      required this.sel, required this.tod});

  @override
  Widget build(BuildContext context) {
    if (day.isRestDay) {
      return Text('😴', style: TextStyle(
          fontSize: sel ? 20 : 17));
    }
    if (day.isCompleted) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.green.withValues(alpha: 0.6), width: 1.5),
        ),
        child: const Icon(Icons.check_rounded,
            color: AppColors.green, size: 14),
      );
    }
    if (day.exercises.isEmpty) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.14)
              : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded,
            color: sel ? color : AppColors.textMuted, size: 14),
      );
    }
    // Has exercises — show count with completion arc
    final done  = day.completedExercises;
    final total = day.exercises.length;
    final pct   = done / total;
    return SizedBox(
      width: 30, height: 30,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: pct,
          strokeWidth: 2.5,
          backgroundColor: AppColors.bgElevated,
          valueColor: AlwaysStoppedAnimation(
              done == total ? AppColors.green : color),
        ),
        Text('$total', style: GoogleFonts.rajdhani(
            color: sel ? color : AppColors.textSecondary,
            fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _p;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _p = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _p,
    builder: (_, __) => Container(
      width: 5, height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: _p.value),
      ),
    ),
  );
}

// ════════════════════════════════════════════════
// DAY BODY
// ════════════════════════════════════════════════
class _DayBody extends StatelessWidget {
  final int idx; final String name; final AppProvider provider;
  const _DayBody({required this.idx, required this.name,
      required this.provider});

  @override
  Widget build(BuildContext context) {
    final wp   = provider.weekPlan;
    if (wp.isEmpty) return const SizedBox.shrink();
    final safe = idx.clamp(0, wp.length - 1);
    final day  = wp[safe];
    final col  = AppColors.dayColors[safe % AppColors.dayColors.length];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 90),
      children: [
        _DayHeader(day: day, name: name, color: col, idx: safe),
        const SizedBox(height: AppSpacing.lg),
        if (day.isRestDay)
          _RestCard(idx: safe, color: col)
        else ...[
          if (day.exercises.isEmpty)
            _EmptyDay(idx: safe, color: col, p: provider)
          else
            ...day.exercises.asMap().entries.map((e) =>
                _ExCard(ex: e.value, idx: safe, color: col,
                    entryDelay: e.key * 50)),
          const SizedBox(height: AppSpacing.sm),
          _AddBtn(idx: safe, color: col),
          if (day.exercises.isNotEmpty && !day.isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            _CompleteBtn(idx: safe),
          ],
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════
// DAY HEADER — with workout stats row
// ════════════════════════════════════════════════
class _DayHeader extends StatelessWidget {
  final DayPlan day; final String name;
  final Color color; final int idx;
  const _DayHeader({required this.day, required this.name,
      required this.color, required this.idx});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final fat = AIEngine.detectFatigue(p.lastWorkouts);
    final exCount  = day.exercises.length;
    final setCount = day.exercises.fold(0, (s, e) => s + e.sets.length);
    final vol      = day.exercises.fold(0.0, (s, e) =>
        s + e.sets.fold(0.0, (ss, set) => ss + set.weight * set.reps));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Fatigue warning
      if (fat.isNotEmpty) Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.red.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.red, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(fat, style: GoogleFonts.inter(
              color: AppColors.red, fontSize: 12,
              fontWeight: FontWeight.w600))),
        ]),
      ),

      // Header card
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
              color: color.withValues(alpha: 0.20), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            // Color indicator
            Container(
              width: 4, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.3)]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.toUpperCase(), style: GoogleFonts.inter(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
              Text(
                day.title.isEmpty ? 'Workout' : day.title,
                style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary, fontSize: 20,
                    fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ])),
            // Done badge
            if (day.isCompleted) Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded,
                    color: AppColors.green, size: 12),
                const SizedBox(width: 3),
                Text('Done', style: GoogleFonts.inter(
                    color: AppColors.green, fontSize: 10,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
            // Menu
            _HeaderMenu(day: day, idx: idx, p: p),
          ]),

          // Stats row (only if has exercises)
          if (exCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              _StatChip('🏋️', '$exCount exercises'),
              const SizedBox(width: AppSpacing.sm),
              _StatChip('🔁', '$setCount sets'),
              if (vol > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                _StatChip('📦', '${(vol / 1000).toStringAsFixed(1)}t vol'),
              ],
            ]),
          ],
        ]),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String emoji, label;
  const _StatChip(this.emoji, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.bgCardLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 11,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _HeaderMenu extends StatelessWidget {
  final DayPlan day; final int idx; final AppProvider p;
  const _HeaderMenu({required this.day, required this.idx, required this.p});

  String _type(int i) {
    final s = p.level == 'beginner'
        ? ['Full','Rest','Full','Rest','Full','Rest','Rest']
        : (p.level == 'advanced' && p.goal == 'muscle_gain')
            ? ['Push','Pull','Legs','Push','Pull','Legs','Rest']
            : ['Push','Pull','Legs','Rest','Push','Pull','Rest'];
    final r = i < s.length ? s[i] : 'Full';
    return r == 'Rest' ? 'Full' : r;
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.bgCardLight,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    icon: const Icon(Icons.more_horiz_rounded,
        color: AppColors.textMuted, size: 20),
    onSelected: (v) {
      H.tap();
      switch (v) {
        case 'rename': _renameDialog(context);  break;
        case 'generate': p.generateWorkoutForDay(_type(idx), idx); break;
        case 'rest': p.toggleRestDay(idx); break;
        case 'clear': p.clearDay(idx); break;
      }
    },
    itemBuilder: (_) => [
      _mi('rename',   Icons.edit_outlined,         'Rename'),
      _mi('generate', Icons.auto_awesome_rounded,  'AI Generate'),
      _mi('rest',     Icons.bedtime_outlined,
          day.isRestDay ? 'Unset Rest Day' : 'Set as Rest Day'),
      _mi('clear',    Icons.delete_sweep_outlined,
          'Clear Day', AppColors.red),
    ],
  );

  PopupMenuItem<String> _mi(String v, IconData ic, String t, [Color? c]) =>
      PopupMenuItem(value: v, child: Row(children: [
        Icon(ic, color: c ?? AppColors.textSecondary, size: 17),
        const SizedBox(width: AppSpacing.sm),
        Text(t, style: GoogleFonts.inter(
            color: c ?? AppColors.textPrimary, fontSize: 13)),
      ]));

  void _renameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: p.weekPlan[idx].title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Rename Workout', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: GoogleFonts.inter(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'e.g. Push Day A'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(
                color: AppColors.textMuted))),
        GoldButton(text: 'Save', onTap: () {
          if (ctrl.text.trim().isNotEmpty) {
            p.updateDayTitle(idx, ctrl.text.trim());
          }
          Navigator.pop(ctx);
        }),
      ],
    ));
  }
}

// ════════════════════════════════════════════════
// REST CARD
// ════════════════════════════════════════════════
class _RestCard extends StatelessWidget {
  final int idx; final Color color;
  const _RestCard({required this.idx, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      border: Border.all(color: AppColors.borderSoft, width: 0.5),
    ),
    child: Column(children: [
      const Text('😴', style: TextStyle(fontSize: 52)),
      const SizedBox(height: AppSpacing.md),
      Text('Rest Day', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 24,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: AppSpacing.xs),
      Text('Recovery is where the gains happen.\nYou\'ve earned this.',
          style: GoogleFonts.inter(color: AppColors.textMuted,
              fontSize: 13, height: 1.5),
          textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: 10),
        ),
        onPressed: () {
          H.tap();
          context.read<AppProvider>().toggleRestDay(idx);
        },
        child: Text('Change to Workout Day',
            style: GoogleFonts.rajdhani(
                color: color, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// EMPTY DAY CARD
// ════════════════════════════════════════════════
class _EmptyDay extends StatelessWidget {
  final int idx; final Color color; final AppProvider p;
  const _EmptyDay({required this.idx, required this.color,
      required this.p});

  void _gen(BuildContext ctx) {
    H.medium();
    final split = _type();
    p.generateWorkoutForDay(split, idx);
    final updated = p.weekPlan[idx];
    if (updated.exercises.isEmpty) {
      final workout = AIEngine.generateDayWorkout(
        goal: p.goal, level: p.level, type: split,
        history: p.lastWorkouts, weakMuscle: p.weakMuscle,
        isBeginner: p.level == 'beginner',
      );
      for (final ex in workout) {
        p.addExercise(idx,
          name:         ex['name']       as String? ?? '',
          category:     ex['muscle']     as String? ?? '',
          emoji:        ex['emoji']      as String? ?? '💪',
          type:         ex['type']       as String? ?? '',
          unit:         ex['unit']       as String? ?? 'kg',
          baseId:       '${ex["name"]}_${ex["type"] ?? ""}',
          isBodyweight: ex['bodyweight'] as bool?   ?? false,
        );
      }
    }
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('🤖 AI Workout Ready! Let\'s get it 💪',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _type() {
    final s = p.level == 'beginner'
        ? ['Full','Rest','Full','Rest','Full','Rest','Rest']
        : (p.level == 'advanced' && p.goal == 'muscle_gain')
            ? ['Push','Pull','Legs','Push','Pull','Legs','Rest']
            : ['Push','Pull','Legs','Rest','Push','Pull','Rest'];
    final r = idx < s.length ? s[idx] : 'Full';
    return r == 'Rest' ? 'Full' : r;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
    ),
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.06),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.fitness_center_rounded, color: color, size: 32),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('No Exercises Yet', style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary, fontSize: 22,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: AppSpacing.xs),
      Text('Your AI coach will build the perfect\nworkout in seconds.',
          style: GoogleFonts.inter(color: AppColors.textMuted,
              fontSize: 13, height: 1.5),
          textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xl),

      // AI Generate button
      _Tap(
        onTap: () => _gen(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.black, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Generate with AI', style: GoogleFonts.rajdhani(
                color: Colors.black, fontSize: 17,
                fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: () { H.tap(); _showPicker(context, idx); },
        child: Text('or add manually', style: GoogleFonts.inter(
            color: AppColors.textMuted, fontSize: 12,
            decoration: TextDecoration.underline)),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════
// ADD BUTTON
// ════════════════════════════════════════════════
class _AddBtn extends StatelessWidget {
  final int idx; final Color color;
  const _AddBtn({required this.idx, required this.color});
  @override
  Widget build(BuildContext context) => _Tap(
    onTap: () { H.light(); _showPicker(context, idx); },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_rounded, color: color, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Text('Add Exercise', style: GoogleFonts.rajdhani(
            color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// COMPLETE BUTTON
// ════════════════════════════════════════════════
class _CompleteBtn extends StatelessWidget {
  final int idx;
  const _CompleteBtn({required this.idx});

  void _dialog(BuildContext ctx) {
    H.medium();
    int dur = 45;
    showDialog(context: ctx, builder: (d) => StatefulBuilder(
      builder: (d2, ss) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        title: Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.sm),
          Text('Workout Complete!', style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('How long did you train?', style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpacing.lg),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_rounded),
              color: AppColors.gold, iconSize: 32,
              onPressed: () {
                H.selection();
                ss(() => dur = (dur - 5).clamp(5, 300));
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.gold.withValues(alpha: 0.14),
                  AppColors.gold.withValues(alpha: 0.06),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Text('$dur min', style: GoogleFonts.rajdhani(
                  color: AppColors.gold, fontSize: 34,
                  fontWeight: FontWeight.w900)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              color: AppColors.gold, iconSize: 32,
              onPressed: () {
                H.selection();
                ss(() => dur = (dur + 5).clamp(5, 300));
              },
            ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d2),
            child: Text('Cancel', style: GoogleFonts.inter(
                color: AppColors.textMuted))),
          GoldButton(text: 'Save Session 🔥', onTap: () async {
            final p  = ctx.read<AppProvider>();
            final gp = ctx.read<GamificationProvider>();
            Navigator.pop(d2);
            final badges = await p.markDayComplete(idx, dur);

/// 🔥 INTERSTITIAL AD TRIGGER (AFTER WORKOUT COMPLETE)
Future.delayed(const Duration(milliseconds: 300), () async {
  await AdService.instance.showInterstitialIfAllowed();
});

final xp = XPSystem.xpWorkoutComplete +
    XPSystem.xpStreakBonus *
    (p.streak.currentStreak ~/ 7 + 1);
            gp.addXP(xp); gp.onWorkoutComplete();
            for (final b in badges) gp.triggerBadgePopup(b);
            if (!ctx.mounted) return;

            // ── Celebration ──────────────────────────────────
            await showWorkoutCelebration(ctx,
              xp:       xp,
              streak:   p.streak.currentStreak,
              duration: dur,
              badges:   badges.map((b) => b.emoji).toList(),
            );
            if (!ctx.mounted) return;

            // ── Interstitial (frequency capped, free only) ───
            await MonetizationService.instance
                .showInterstitialIfAllowed();
            if (!ctx.mounted) return;

            // ── Behavior paywall (milestone-based) ───────────
            final trigger = p.pendingPaywallTrigger;
            if (trigger != null) {
              p.clearPaywallTrigger();
              await PaywallSheet.show(ctx,
                trigger:   trigger,
                onUpgrade: () => p.notifyListeners(),
                onAdComplete: () => p.notifyListeners(),
              );
            }
          }),
        ],
      ),
    ));
  }

  void _streakDialog(BuildContext ctx, int streak) {
    H.success();
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (_, v, child) =>
            Transform.scale(scale: v, child: child),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.bgModal,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.5),
                width: 1.5),
            boxShadow: AppShadows.colored(AppColors.orange),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.sm),
            Text('+1 Day Streak!', style: GoogleFonts.rajdhani(
                color: AppColors.orange, fontSize: 28,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.xs),
            Text('$streak ${streak == 1 ? "day" : "days"} strong 💪',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('You\'re building an unbreakable habit.',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    ));
    Future.delayed(const Duration(seconds: 2), () {
      if (ctx.mounted && Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Tap(
    onTap: () => _dialog(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFCC00), Color(0xFFFF9900)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.black, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text('Mark as Complete 🎉', style: GoogleFonts.rajdhani(
            color: Colors.black, fontSize: 18,
            fontWeight: FontWeight.w900)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════
// EXERCISE CARD — premium redesign
// ════════════════════════════════════════════════
class _ExCard extends StatefulWidget {
  final PlannedExercise ex;
  final int idx, entryDelay;
  final Color color;
  const _ExCard({required this.ex, required this.idx,
      required this.color, this.entryDelay = 0});
  @override State<_ExCard> createState() => _ExCardState();
}

class _ExCardState extends State<_ExCard>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _entryC;
  late Animation<double> _entryF;
  late Animation<Offset> _entryS;

  @override
  void initState() {
    super.initState();
    _entryC = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 360));
    _entryF = CurvedAnimation(parent: _entryC, curve: Curves.easeOut);
    _entryS = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryC, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.entryDelay),
            () { if (mounted) _entryC.forward(); });
  }
  @override void dispose() { _entryC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ex   = widget.ex;
    final p    = context.read<AppProvider>();
    final key  = p.getKey(ex.baseId);
    final pr   = p.getPR(key, ex.unit);
    final prR  = p.getPRReps(key);
    final msg  = p.getTrainerMessage(ex);
    final adv  = AIEngine.getProgressionSuggestion(
      lastReps: prR, lastWeight: pr, goal: p.goal,
      sessionCount: p.logs.length);

    // Completed sets count
    final doneSets = ex.sets.where((s) => s.done).length;
    final totalSets = ex.sets.length;

    return FadeTransition(
      opacity: _entryF,
      child: SlideTransition(
        position: _entryS,
        child: Dismissible(
          key: Key(ex.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirm(context, ex.name),
          onDismissed: (_) {
            H.medium();
            p.removeExercise(widget.idx, ex.id);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_rounded,
                  color: AppColors.red, size: 24),
              Text('Remove', style: GoogleFonts.inter(
                  color: AppColors.red, fontSize: 10,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _open
                    ? widget.color.withValues(alpha: 0.4)
                    : AppColors.divider.withValues(alpha: 0.6),
                width: _open ? 1.2 : 0.5),
              boxShadow: _open ? [BoxShadow(
                  color: widget.color.withValues(alpha: 0.12),
                  blurRadius: 16)] : [],
            ),
            child: Column(children: [
              // ── CARD HEADER ───────────────────
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: ex.category.toLowerCase() == 'rest' ? null : () {
                  H.selection();
                  setState(() => _open = !_open);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    // Emoji container
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withValues(alpha: 0.22),
                            widget.color.withValues(alpha: 0.07),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: widget.color.withValues(alpha: 0.2)),
                      ),
                      child: Center(child: Text(ex.emoji,
                          style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Name + info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        // FIX: Show only name in header (no type suffix truncating it)
                        // Type shown in category chip below
                        ex.name,
                        style: GoogleFonts.rajdhani(
                            fontSize: 15, fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (ex.category.isNotEmpty) Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          // FIX: Show "Category · Type" for full context
                          child: Text(
                            ex.type.isNotEmpty
                                ? '${ex.category} · ${ex.type}'
                                : ex.category,
                            style: GoogleFonts.inter(
                                color: widget.color, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                        ),
                        if (msg.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Expanded(child: Text(msg, style: GoogleFonts.inter(
                              color: AppColors.orange, fontSize: 10,
                              fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                        ] else if (pr > 0) ...[
                          const SizedBox(width: 5),
                          Expanded(child: Text(adv.message, style: GoogleFonts.inter(
                              color: AppColors.green, fontSize: 10,
                              fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ]),
                    ])),

                    const SizedBox(width: AppSpacing.xs),

                    // Right side: PR + sets progress + chevron
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      if (pr > 0) Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.orange.withValues(
                                  alpha: 0.35)),
                        ),
                        child: Text(
                          ex.unit == 'min'
                              ? '🏆 ${pr.toInt()}m'
                              : ex.bodyweight
                                  ? '🏆 ${prR}r'
                                  : prR > 0
                                      ? '🏆 ${pr.toStringAsFixed(1)}×$prR'
                                      : '🏆 ${pr.toStringAsFixed(1)}',
                          style: GoogleFonts.inter(
                              color: AppColors.orange, fontSize: 9,
                              fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 4),
                      // Sets done indicator
                      Text('$doneSets/$totalSets sets',
                          style: GoogleFonts.inter(
                            color: doneSets == totalSets
                                ? AppColors.green : AppColors.textMuted,
                            fontSize: 10, fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 2),
                      Icon(
                        _open ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textMuted, size: 16),
                    ]),
                  ]),
                ),
              ),

              // ── EXPANDED SECTION ──────────────
              if (_open) ...[
                Divider(color: widget.color.withValues(alpha: 0.15),
                    height: 1, indent: AppSpacing.md,
                    endIndent: AppSpacing.md),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 150, child: ProgressChart(
                    exerciseKey: key, unit: ex.unit)),
                _SetsPanel(ex: ex, idx: widget.idx,
                    color: widget.color),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext ctx, String name) async =>
      await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Remove Exercise?', style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w700)),
        content: Text('Remove "$name" from today\'s plan?',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep it', style: GoogleFonts.inter(
                  color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      )) ?? false;
}

// ════════════════════════════════════════════════
// SETS PANEL
// ════════════════════════════════════════════════
class _SetsPanel extends StatelessWidget {
  final PlannedExercise ex; final int idx; final Color color;
  const _SetsPanel({required this.ex, required this.idx,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final isC  = ex.unit == 'min';
    final isBW = ex.bodyweight;

    return Column(children: [
      // Column headers
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 2, AppSpacing.lg, 4),
        child: Row(children: [
          SizedBox(width: 28, child: Text('SET',
              style: GoogleFonts.inter(color: AppColors.textMuted,
                  fontSize: 9, fontWeight: FontWeight.w800,
                  letterSpacing: 1))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(isC ? 'MIN' : isBW ? 'REPS' : 'KG',
              style: GoogleFonts.inter(color: AppColors.textMuted,
                  fontSize: 9, fontWeight: FontWeight.w800,
                  letterSpacing: 1))),
          const SizedBox(width: AppSpacing.sm),
          if (!isC && !isBW)
            Expanded(child: Text('REPS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textMuted,
                    fontSize: 9, fontWeight: FontWeight.w800,
                    letterSpacing: 1)))
          else const Spacer(),
          const SizedBox(width: 52),
        ]),
      ),

      // Set rows
      ...ex.sets.asMap().entries.map((e) => _SetRow(
          ex: ex, set: e.value, num: e.key + 1,
          idx: idx, color: color)),

      // Add set button
      TextButton.icon(
        onPressed: () {
          H.light();
          p.addSet(idx, ex.id);
        },
        icon: Icon(Icons.add_rounded, size: 14, color: color),
        label: Text('Add Set', style: GoogleFonts.rajdhani(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
      const SizedBox(height: AppSpacing.xs),
    ]);
  }
}

// ════════════════════════════════════════════════
// SET ROW — premium redesign
// ════════════════════════════════════════════════
class _SetRow extends StatelessWidget {
  final PlannedExercise ex; final ExSet set;
  final int num, idx; final Color color;
  const _SetRow({required this.ex, required this.set,
      required this.num, required this.idx, required this.color});

  @override
  Widget build(BuildContext context) {
    final p    = context.read<AppProvider>();
    final isC  = ex.unit == 'min';
    final isBW = ex.bodyweight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: set.done ? LinearGradient(colors: [
          AppColors.green.withValues(alpha: 0.12),
          AppColors.green.withValues(alpha: 0.04),
        ]) : null,
        color: set.done ? null : AppColors.bgCardLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: set.done
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.3),
          width: set.done ? 0.8 : 0.5,
        ),
      ),
      child: Row(children: [
        // Set number circle
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: set.done
                ? AppColors.green.withValues(alpha: 0.15)
                : AppColors.bgElevated,
            border: Border.all(
              color: set.done
                  ? AppColors.green.withValues(alpha: 0.5)
                  : AppColors.borderMedium,
              width: 0.8,
            ),
          ),
          child: Center(child: Text('$num',
              style: GoogleFonts.rajdhani(
                color: set.done ? AppColors.green : AppColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Input fields
        Expanded(child: isC
            ? _Num(value: set.weight, done: set.done, color: color,
                hint: '10', isInt: true,
                onSave: (v) => p.updateSet(idx, ex.id, set.id, weight: v))
            : isBW
                ? _Num(value: set.reps.toDouble(), done: set.done,
                    color: color, isInt: true, hint: '10',
                    onSave: (v) => p.updateSet(
                        idx, ex.id, set.id, reps: v.toInt()))
                : _Num(value: set.weight, done: set.done, color: color,
                    hint: '20.0',
                    onSave: (v) => p.updateSet(
                        idx, ex.id, set.id, weight: v))),
        const SizedBox(width: AppSpacing.sm),
        if (!isC && !isBW)
          Expanded(child: _Num(
              value: set.reps.toDouble(), done: set.done, color: color,
              isInt: true, hint: '10',
              onSave: (v) => p.updateSet(
                  idx, ex.id, set.id, reps: v.toInt())))
        else const Spacer(),
        const SizedBox(width: AppSpacing.sm),

        // Done check button
        GestureDetector(
          onTap: () async {
            final wasDone = set.done;
            if (wasDone) {
              p.toggleSetDone(idx, ex.id, set.id);
              return;
            }

            final key = p.getKey(ex.baseId);

            // ✅ FIXED: get prev values from checkPRResult instead of two separate calls
            // checkPRResult reads the same data but in one atomic operation
            final prevBestWeight = p.getPR(key, ex.unit);
            final prevBestReps   = p.getPRReps(key);

            // ✅ FIXED: safety guard for invalid sets
            if (set.weight < 0 || set.reps <= 0) {
              p.toggleSetDone(idx, ex.id, set.id);
              return;
            }

            // ✅ FIXED: use checkPRResult() — proper weight/reps/first PR logic
            // Old code used volume (weight×reps) which is WRONG:
            //   50kg×5=250 wouldn't beat 40kg×7=280 even though heavier
            final prResult   = p.checkPRResult(key, set.weight, set.reps, ex.unit);
            final isPR       = prResult.isPR;
            final isFirst    = prResult.isFirst;
            final improvePct = prResult.improvePct.clamp(0.0, 999.0);

            // ── Toggle (log the set) ──────────────────────────────────
            p.toggleSetDone(idx, ex.id, set.id);

            // ── XP — tiered by improvement magnitude ──────────────────
            H.medium();
            final dynXP = isPR
                ? (improvePct >= 30 ? 500
                   : improvePct >= 15 ? 250
                   : isFirst ? 150 : 100)
                : 50;

            try {
              final gp = Provider.of<GamificationProvider>(
                  context, listen: false);
              gp.addXP(XPSystem.xpSetCompleted);
              if (isPR) { gp.addXP(dynXP); H.heavy(); }
            } catch (_) {}

            if (!context.mounted) return;

            // ✅ FIXED: use prResult.isMatch instead of manual comparison
            if (prResult.isMatch) { showMatchedPR(context, ex.name); return; }

            // ── PR Celebration ────────────────────────────────────────
            if (isPR) {
              try {
                await AudioPlayer().play(AssetSource('sounds/success.mp3'));
              } catch (_) {}
              if (context.mounted) {
                // Get first-ever weight for journey display
                final allLogs = p.getLogsForExercise(key);
                final firstW  = allLogs.isNotEmpty
                    ? allLogs.map((l) => l.weight)
                        .where((w) => w > 0)
                        .fold(9999.0, (a, b) => b < a ? b : a)
                    : 0.0;

                await showPRCelebration(context,
                  exerciseName:   ex.name,
                  weight:         set.weight,
                  reps:           set.reps,
                  xpEarned:       dynXP,
                  unit:           ex.unit,
                  prevWeight:     prResult.prevWeight,
                  prevReps:       prResult.prevReps,
                  sessionCount:   p.logs.length,
                  improvePct:     improvePct,
                  firstWeight:    firstW == 9999.0 ? 0 : firstW,
                  sessionPRCount: 1,
                );
                // ✅ PR paywall — "You're improving! Get adaptive plans"
                if (context.mounted && !p.isPremium) {
                  final prTrigger = await p.checkPRPaywall();
                  if (prTrigger != null && context.mounted) {
                    await PaywallSheet.show(context,
                      trigger:  prTrigger,
                      onUpgrade: () => p.notifyListeners(),
                    );
                  }
                }
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: set.done ? const LinearGradient(
                  colors: [AppColors.green,
                    Color(0xFF22C55E)]) : null,
              color: set.done ? null : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: set.done
                    ? AppColors.green.withValues(alpha: 0.6)
                    : AppColors.borderMedium,
                width: 0.8,
              ),
              boxShadow: set.done ? [BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.3),
                  blurRadius: 6)] : [],
            ),
            child: Icon(
              set.done ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: set.done ? Colors.white : AppColors.textMuted,
              size: 15,
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            H.light();
            p.removeSet(idx, ex.id, set.id);
          },
          child: const Icon(Icons.close_rounded,
              color: AppColors.textMuted, size: 15),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// NUMBER INPUT FIELD — comma→dot fix + focus glow
// ════════════════════════════════════════════════
class _Num extends StatefulWidget {
  final double value; final bool done, isInt;
  final Color color; final String hint;
  final ValueChanged<double> onSave;
  const _Num({required this.value, required this.done,
      required this.color, required this.hint,
      this.isInt = false, required this.onSave});
  @override State<_Num> createState() => _NumState();
}

class _NumState extends State<_Num> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _Num old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  String _fmt(double v) => widget.isInt
      ? v.toInt().toString() : v.toStringAsFixed(1);

  void _save(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || v < 0) return;
    if (v > AppLimits.maxWeight) return;
    widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    final bc = widget.done
        ? AppColors.green.withValues(alpha: 0.55)
        : _focused ? widget.color : AppColors.divider;

    return TextField(
      controller: _ctrl, focusNode: _focus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(
          decimal: !widget.isInt, signed: false),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            RegExp(widget.isInt ? r'[0-9]' : r'[0-9.,]')),
      ],
      style: GoogleFonts.rajdhani(
          color: widget.done ? AppColors.green : AppColors.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      decoration: InputDecoration(
        isDense: true, filled: true,
        fillColor: widget.done
            ? AppColors.green.withValues(alpha: 0.05)
            : AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        hintText: widget.hint,
        hintStyle: GoogleFonts.rajdhani(
            color: AppColors.textMuted.withValues(alpha: 0.4),
            fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: bc, width: 0.8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: bc, width: 0.8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: widget.color, width: 1.4)),
      ),
      onChanged: _save, onSubmitted: _save,
    );
  }
}

// ════════════════════════════════════════════════
// TAP FEEDBACK
// ════════════════════════════════════════════════
class _Tap extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const _Tap({required this.child, required this.onTap});
  @override State<_Tap> createState() => _TapState();
}
class _TapState extends State<_Tap> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 160));
    _s = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _c.forward(),
    onTapUp:     (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: widget.child),
  );
}

// ════════════════════════════════════════════════
// EXERCISE PICKER
// ════════════════════════════════════════════════
void _showPicker(BuildContext context, int dayIdx) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickerSheet(dayIdx: dayIdx),
  );
}

class _PickerSheet extends StatefulWidget {
  final int dayIdx;
  const _PickerSheet({required this.dayIdx});
  @override State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _search = '';
  String _cat = 'All';
  final Set<String> _sel = {};
  static const _filters = [
    'All','Chest','Back','Legs','Shoulders','Arms','Core','Cardio'];

  List<Map<String, dynamic>> get _all {
    final seen = <String>{}; final out = <Map<String, dynamic>>[];
    for (final ex in ExerciseData.list) {
      if (seen.add('${ex["name"]}_${ex["type"]}')) out.add(ex);
    }
    return out;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    return _all.where((ex) {
      final name   = (ex['name']   as String? ?? '').toLowerCase();
      final type   = (ex['type']   as String? ?? '').toLowerCase();
      final muscle = (ex['muscle'] as String? ?? '').toLowerCase();
      return (q.isEmpty || name.contains(q) || type.contains(q)
              || muscle.contains(q))
          && (_cat == 'All' || muscle == _cat.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final list = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: AppSpacing.sm),
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: AppSpacing.md),

        // Header
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl),
          child: Row(children: [
            Text('Add Exercises', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 22,
                fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),

        // Search + custom
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg),
          child: Column(children: [
            TextField(
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true, fillColor: AppColors.bgCardLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCustom(context, widget.dayIdx),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Custom'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold),
              )),
            // Filter chips
            SizedBox(height: 36, child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((t) {
                final sel = _cat == t;
                return GestureDetector(
                  onTap: () { H.selection(); setState(() => _cat = t); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.gold : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.gold : AppColors.divider)),
                    child: Text(t, style: GoogleFonts.inter(
                      color: sel ? Colors.black : AppColors.textMuted,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                );
              }).toList(),
            )),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),

        // List
        Expanded(child: list.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min,
                children: [
              const Text('😔', style: TextStyle(fontSize: 32)),
              const SizedBox(height: AppSpacing.sm),
              Text('No exercises found', style: GoogleFonts.inter(
                  color: AppColors.textMuted)),
            ]))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.lg),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final ex    = list[i];
                  final name  = ex['name']   as String? ?? '';
                  final type  = ex['type']   as String? ?? '';
                  final cat   = ex['muscle'] as String? ?? 'General';
                  final emoji = ex['emoji']  as String? ?? '💪';
                  final col   = AppColors.categoryColors[cat] ?? AppColors.gold;
                  final k     = '${name}_$type';
                  final fav   = p.favorites.contains(k);
                  final sel   = _sel.contains(k);

                  return GestureDetector(
                    onTap: () {
                      H.selection();
                      setState(() => sel ? _sel.remove(k) : _sel.add(k));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: sel
                            ? col.withValues(alpha: 0.10)
                            : AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? col : Colors.transparent,
                          width: 1.2)),
                      child: Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(type.isNotEmpty ? '$name ($type)' : name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: sel ? col : AppColors.textPrimary,
                                fontSize: 13)),
                          Text(cat, style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 11)),
                        ])),
                        IconButton(
                          onPressed: () { H.light(); p.toggleFavorite(k); },
                          icon: Icon(
                              fav ? Icons.star : Icons.star_border,
                              color: fav ? AppColors.gold
                                  : AppColors.textMuted)),
                        if (sel) const Icon(Icons.check_circle_rounded,
                            color: AppColors.gold, size: 20),
                      ]),
                    ),
                  );
                },
              )),

        // Add selected button
        if (_sel.isNotEmpty) Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border(top: BorderSide(color: AppColors.divider))),
          child: GoldButton(
            text: 'Add ${_sel.length} Exercise'
                '${_sel.length > 1 ? "s" : ""} 💪',
            width: double.infinity,
            onTap: () { H.medium(); _add(context); },
          ),
        ),
      ]),
    );
  }

  void _add(BuildContext context) {
    final p = context.read<AppProvider>();
    for (final key in _sel) {
      final ex = _all.firstWhere(
        (e) => '${e["name"]}_${e["type"]}' == key,
        orElse: () => <String, dynamic>{},
      );
      if (ex.isEmpty) continue;
      p.addExercise(widget.dayIdx,
        name:         ex['name']       as String? ?? '',
        category:     ex['muscle']     as String? ?? '',
        emoji:        ex['emoji']      as String? ?? '💪',
        type:         ex['type']       as String? ?? '',
        unit:         ex['unit']       as String?
            ?? (ex['bodyweight'] == true ? 'reps' : 'kg'),
        baseId:       '${ex["name"]}_${ex["type"] ?? ""}',
        isBodyweight: ex['bodyweight'] as bool? ?? false,
      );
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${_sel.length} exercise'
          '${_sel.length > 1 ? "s" : ""} added!',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ════════════════════════════════════════════════
// CUSTOM EXERCISE SHEET
// ════════════════════════════════════════════════
void _showCustom(BuildContext context, int dayIdx) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomSheet(dayIdx: dayIdx),
  );
}

class _CustomSheet extends StatefulWidget {
  final int dayIdx;
  const _CustomSheet({required this.dayIdx});
  @override State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  final _name  = TextEditingController();
  final _emoji = TextEditingController(text: '💪');
  final _cat   = TextEditingController(text: 'Custom');
  bool _bw = false;
  String? _err;

  @override void dispose() {
    _name.dispose(); _emoji.dispose(); _cat.dispose(); super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Please enter a name'); return;
    }
    H.medium();
    context.read<AppProvider>().addCustomExercise(
      dayIndex:     widget.dayIdx,
      name:         _name.text.trim(),
      category:     _cat.text.trim().isEmpty ? 'Custom' : _cat.text.trim(),
      emoji:        _emoji.text.trim().isEmpty ? '💪' : _emoji.text.trim(),
      isBodyweight: _bw,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 24 + kb),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Text('Custom Exercise', style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name, autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(
                labelText: 'Exercise Name *', errorText: _err),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: TextField(controller: _emoji,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(labelText: 'Emoji'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: TextField(controller: _cat,
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Category'))),
          ]),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
            child: SwitchListTile(
              value: _bw,
              onChanged: (v) { H.selection(); setState(() => _bw = v); },
              title: Text('Bodyweight exercise',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(_bw ? 'Tracked in reps' : 'Tracked in kg',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
              activeColor: AppColors.gold,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GoldButton(text: 'Add Exercise', width: double.infinity,
              onTap: _submit),
        ],
      )),
    );
  }
}
