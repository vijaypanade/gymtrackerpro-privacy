// lib/widgets/home/daily_protein_card.dart
//
// DailyProteinCard — compact summary on Home; tap opens the Protein Hub.
// V4 architecture: the Home card only summarizes (value, bar, remaining).
// All interaction — coaching, history, quick add, categories — lives in
// a DraggableScrollableSheet bottom sheet (_ProteinHubSheet).
// Dashboards summarize; interaction opens detail.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/meal_log_model.dart';
import '../../providers/app_provider.dart';
import '../../screens/main_shell.dart' show MainShellState;
import '../../services/ai_engine.dart';
import '../../services/meal_log_service.dart';
import '../../services/observation_engine.dart';
import '../../services/protein_intelligence_service.dart';
import '../../utils/app_constants.dart';

// ═══════════════════════════════════════════════════
// PERSISTENCE KEYS
// ═══════════════════════════════════════════════════

const _kFavoritesKey = 'protein_favorites_v1';
const _kRecentsKey   = 'protein_recents_v1';
const _kMostUsedKey  = 'protein_most_used_v1';

// ═══════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

// Merge same-portion entries into display rows.
List<_MergedEntry> _mergeEntries(List<MealLogEntry> entries) {
  final map = <String, List<MealLogEntry>>{};
  for (final e in entries) {
    map.putIfAbsent(e.foods.first, () => []).add(e);
  }
  final result = <_MergedEntry>[];
  for (final kv in map.entries) {
    final group = kv.value
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final count        = group.length;
    final totalProtein = group.fold<int>(0, (s, e) => s + e.protein);
    final totalKcal    = group.fold<int>(0, (s, e) => s + e.kcal);
    result.add(_MergedEntry(
      label:        _buildMergedLabel(kv.key, count),
      rawLabel:     kv.key,
      count:        count,
      totalProtein: totalProtein,
      totalKcal:    totalKcal,
      originals:    group,
      loggedAt:     group.first.loggedAt,
    ));
  }
  result.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return result;
}

String _buildMergedLabel(String rawLabel, int count) {
  if (count == 1) return rawLabel;
  final parenIdx = rawLabel.indexOf('(');
  if (parenIdx < 0) return '${rawLabel.trim()} ×$count';
  final baseName   = rawLabel.substring(0, parenIdx).trim();
  final portionRaw = rawLabel.substring(parenIdx + 1, rawLabel.lastIndexOf(')')).trim();
  final parts      = portionRaw.split(' ');
  if (parts.length >= 2) {
    final unit   = parts.sublist(1).join(' ');
    final plural = (!unit.endsWith('s')) ? '${unit}s' : unit;
    return '$baseName ×$count $plural';
  }
  return '$baseName ×$count';
}

// ═══════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════

class _MergedEntry {
  final String label;
  final String rawLabel;
  final int count;
  final int totalProtein;
  final int totalKcal;
  final List<MealLogEntry> originals;
  final DateTime loggedAt;

  const _MergedEntry({
    required this.label,
    required this.rawLabel,
    required this.count,
    required this.totalProtein,
    required this.totalKcal,
    required this.originals,
    required this.loggedAt,
  });
}

// ═══════════════════════════════════════════════════
// PUBLIC WIDGET
// ═══════════════════════════════════════════════════

class DailyProteinCard extends StatefulWidget {
  const DailyProteinCard({super.key});

  @override
  State<DailyProteinCard> createState() => _DailyProteinCardState();
}

class _DailyProteinCardState extends State<DailyProteinCard> {
  DayMealLog? _log;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await MealLogService.getTodayLog('');
    if (!mounted) return;
    setState(() { _log = log; _loading = false; });
    // Protein feeds Recovery Intelligence as one lightweight signal.
    context.read<AppProvider>().refreshProteinSignal();
  }

  int get _consumed =>
      _log?.entries.values.fold<int>(0, (s, e) => s + e.protein) ?? 0;

  int get _consumedKcal =>
      _log?.entries.values.fold<int>(0, (s, e) => s + e.kcal) ?? 0;

  Future<void> _openHub(int proteinGoal, int kcalGoal, bool isFatLoss) async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ProteinHubSheet(
        proteinGoal: proteinGoal,
        kcalGoal:    kcalGoal,
        isFatLoss:   isFatLoss,
      ),
    );
    if (!mounted) return;
    // The hub lives on the root navigator — tab navigation must happen
    // from the card's context, after the sheet has closed.
    if (result == 'nutrition') {
      context.findAncestorStateOfType<MainShellState>()?.changeTab(3);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ap      = context.watch<AppProvider>();
    final profile = ap.profile;
    final goal    = profile.goal;

    final tdee = AIEngine.estimateTDEE(
      weightKg:      profile.weightKg,
      heightCm:      profile.heightCm,
      age:           profile.age,
      gender:        profile.gender,
      goal:          goal,
      activityLevel: profile.activityLevel,
    );
    final macros      = AIEngine.getMacros(tdee: tdee, weightKg: profile.weightKg, goal: goal);
    final proteinGoal = macros['protein']!.round();
    final kcalGoal    = tdee.round();
    final isFatLoss   = goal == 'fat_loss';

    if (_loading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    final remaining = (proteinGoal - _consumed).clamp(0, proteinGoal);
    final progress  = (_consumed / proteinGoal).clamp(0.0, 1.0);
    final completed = _consumed >= proteinGoal;

    return GestureDetector(
      onTap: () => _openHub(proteinGoal, kcalGoal, isFatLoss),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.03),
            width: 0.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary row ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
              child: Row(
                children: [
                  Text(
                    'Daily Protein',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$_consumed',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    ' / ${proteinGoal}g',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white.withValues(alpha: 0.20),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    completed ? 'Target hit' : '${remaining}g left',
                    style: GoogleFonts.inter(
                      color: completed
                          ? AppColors.gold.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.30),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),

            // ── Progress bar — visual max 100% ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1.5),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    valueColor: AlwaysStoppedAnimation(
                      completed
                          ? AppColors.gold.withValues(alpha: 0.60)
                          : AppColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),

            if (isFatLoss)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                child: Text(
                  '$_consumedKcal / $kcalGoal kcal',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.16),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

            SizedBox(height: isFatLoss ? 8 : 10),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PROTEIN HUB — DraggableScrollableSheet bottom sheet
// Owns all data and actions; the Home card only summarizes.
// ═══════════════════════════════════════════════════

class _ProteinHubSheet extends StatefulWidget {
  final int proteinGoal;
  final int kcalGoal;
  final bool isFatLoss;

  const _ProteinHubSheet({
    required this.proteinGoal,
    required this.kcalGoal,
    required this.isFatLoss,
  });

  @override
  State<_ProteinHubSheet> createState() => _ProteinHubSheetState();
}

class _ProteinHubSheetState extends State<_ProteinHubSheet> {
  DayMealLog? _log;
  bool _loading = true;
  int  _yesterdayConsumed = 0;

  Set<String>      _favorites = {};
  List<String>     _recents   = [];
  Map<String, int> _mostUsed  = {};

  // Undo banner (replaces SnackBar for reliable 2-second auto-dismiss)
  _MergedEntry? _pendingUndo;
  bool          _undoVisible = false;
  Timer?        _undoTimer;

  // Coach personal memory — computed once/day by ProteinIntelligenceService.
  String _finisherFood = '';
  String _observation  = '';
  // Evening habit mention has its own cooldown so it doesn't fire daily.
  bool _eveningHabitAllowed = false;
  Observation? _eveningHabitObs;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrefs();
    _loadMemory();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final results = await Future.wait([
      MealLogService.getTodayLog(''),
      MealLogService.getLogForDate('', yesterday),
    ]);
    if (!mounted) return;
    final todayLog     = results[0] as DayMealLog?;
    final yesterdayLog = results[1] as DayMealLog?;
    setState(() {
      _log = todayLog;
      _yesterdayConsumed =
          yesterdayLog?.entries.values.fold<int>(0, (s, e) => s + e.protein) ?? 0;
      _loading = false;
    });
    // Protein feeds Recovery Intelligence as one lightweight signal.
    context.read<AppProvider>().refreshProteinSignal();
  }

  Future<void> _loadMemory() async {
    final memory  = await ProteinIntelligenceService.getMemory();
    final mayShow = await ProteinIntelligenceService.shouldShowObservation();
    // Evening habit mention shares the ObservationEngine cooldown so the
    // same habit is never spoken twice in one week across any surface.
    bool mayEvening = false;
    if (memory.hasSignal && memory.finisherSource.isNotEmpty) {
      _eveningHabitObs = Observation(
        id:     'protein_finisher:'
            '${memory.finisherSource.toLowerCase().replaceAll(' ', '_')}',
        text:   memory.finisherSource,
        source: 'protein',
      );
      mayEvening = await ObservationEngine.pick([_eveningHabitObs!]) != null;
    }
    if (!mounted) return;
    setState(() {
      _finisherFood = memory.hasSignal ? memory.finisherSource : '';
      _observation  =
          mayShow ? ProteinIntelligenceService.buildObservation(memory) : '';
      _eveningHabitAllowed = mayEvening;
    });
    // The hub is open — an observation shown here counts as seen.
    if (_observation.isNotEmpty) {
      ProteinIntelligenceService.markObservationShown();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final favJson = prefs.getString(_kFavoritesKey);
    final recJson = prefs.getString(_kRecentsKey);
    final muJson  = prefs.getString(_kMostUsedKey);
    if (!mounted) return;
    setState(() {
      if (favJson != null) {
        _favorites = Set<String>.from(json.decode(favJson) as List);
      }
      if (recJson != null) {
        _recents = List<String>.from(json.decode(recJson) as List);
      }
      if (muJson != null) {
        final decoded = json.decode(muJson) as Map<String, dynamic>;
        _mostUsed = decoded.map((k, v) => MapEntry(k, v as int));
      }
    });
  }

  Future<void> _toggleFavorite(String label) async {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_favorites.contains(label)) {
        _favorites.remove(label);
      } else {
        _favorites.add(label);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavoritesKey, json.encode(_favorites.toList()));
  }

  Future<void> _addRecent(String label) async {
    _recents.remove(label);
    _recents.insert(0, label);
    if (_recents.length > 4) _recents = _recents.sublist(0, 4);
    _mostUsed[label] = (_mostUsed[label] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kRecentsKey, json.encode(_recents)),
      prefs.setString(_kMostUsedKey, json.encode(_mostUsed)),
    ]);
  }

  int get _consumed =>
      _log?.entries.values.fold<int>(0, (s, e) => s + e.protein) ?? 0;

  int get _consumedKcal =>
      _log?.entries.values.fold<int>(0, (s, e) => s + e.kcal) ?? 0;

  List<MealLogEntry> get _todayEntries =>
      _log?.entries.values.toList() ?? [];

  // ── Snackbars ──────────────────────────────────
  // Adds are silent — the history row appearing is confirmation enough.
  // Deletes auto-dismiss after 4 s; UNDO is available during that window.

  void _showDeleteUndo(BuildContext ctx, _MergedEntry merged) {
    _undoTimer?.cancel();
    setState(() {
      _pendingUndo  = merged;
      _undoVisible  = true;
    });
    _undoTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _undoVisible = false);
    });
  }

  Future<void> _triggerUndo() async {
    _undoTimer?.cancel();
    setState(() => _undoVisible = false);
    if (_pendingUndo == null) return;
    for (final e in _pendingUndo!.originals) {
      await MealLogService.logMeal('', e);
    }
    _load();
  }

  // ── Actions ────────────────────────────────────

  Future<void> _onQuickAdd(BuildContext ctx, _ProteinFood food) async {
    HapticFeedback.lightImpact();
    final entry = await showModalBottomSheet<MealLogEntry>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortionPicker(food: food),
    );
    if (entry != null) {
      await _addRecent(food.label);
      _load();
    }
  }

  Future<void> _onEntryAction(BuildContext ctx, _MergedEntry merged) async {
    final action = await showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntryActionSheet(merged: merged),
    );
    if (action == 'remove') {
      for (final e in merged.originals) {
        await MealLogService.unlogMeal('', e);
      }
      _load();
      if (ctx.mounted) _showDeleteUndo(ctx, merged);
    } else if (action == 'edit') {
      final target = merged.originals.last;
      final food   = _findFoodForEntry(target);
      if (food != null && ctx.mounted) {
        await MealLogService.unlogMeal('', target);
        if (!ctx.mounted) return;
        final newEntry = await showModalBottomSheet<MealLogEntry>(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PortionPicker(food: food),
        );
        if (newEntry == null) {
          await MealLogService.logMeal('', target);
        }
        _load();
      }
    }
  }

  Future<void> _onEntryDismiss(BuildContext ctx, _MergedEntry merged) async {
    for (final e in merged.originals) {
      await MealLogService.unlogMeal('', e);
    }
    _load();
    if (ctx.mounted) _showDeleteUndo(ctx, merged);
  }

  _ProteinFood? _findFoodForEntry(MealLogEntry entry) {
    final name = entry.foods.first.toLowerCase();
    final parenIdx = name.indexOf('(');
    final base = (parenIdx > 0 ? name.substring(0, parenIdx) : name).trim();
    for (final food in _allFoods) {
      final label = food.label.toLowerCase();
      // Bidirectional match so renamed foods (e.g. "Whey" → "Whey Protein")
      // still resolve entries logged under the old label.
      if (name.contains(label) || label.contains(base)) return food;
    }
    return null;
  }

  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final proteinGoal = widget.proteinGoal;
    final remaining   = (proteinGoal - _consumed).clamp(0, proteinGoal);
    final completed   = _consumed >= proteinGoal;
    final exceeded    = _consumed > proteinGoal;
    final yesterdayAchieved = _yesterdayConsumed >= proteinGoal;

    // Evening habit line fires only with a real gap, a reliable habit,
    // and an open cooldown window. Consumes the cooldown when shown.
    final evening = DateTime.now().hour >= 19;
    final eveningHabit = (evening &&
            _eveningHabitAllowed &&
            _finisherFood.isNotEmpty &&
            _consumed > 0 &&
            !completed &&
            remaining <= 45)
        ? _finisherFood
        : '';
    if (eveningHabit.isNotEmpty) {
      _eveningHabitAllowed = false;
      final obs = _eveningHabitObs;
      if (obs != null) ObservationEngine.markSeen(obs);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (sheetCtx, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Stack(
            children: [
              Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.gold,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            controller: scrollController,
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom:
                                  MediaQuery.of(sheetCtx).padding.bottom + 24,
                            ),
                            child: Builder(
                              builder: (innerCtx) => _ExpandedContent(
                                consumed:          _consumed,
                                proteinGoal:       proteinGoal,
                                remaining:         remaining,
                                completed:         completed,
                                exceeded:          exceeded,
                                consumedKcal:      _consumedKcal,
                                kcalGoal:          widget.kcalGoal,
                                isFatLoss:         widget.isFatLoss,
                                entries:           _todayEntries,
                                favorites:         _favorites,
                                recents:           _recents,
                                mostUsed:          _mostUsed,
                                yesterdayAchieved: yesterdayAchieved,
                                finisherFood:      _finisherFood,
                                observation:       _observation,
                                eveningHabit:      eveningHabit,
                                onQuickAdd:        (f) => _onQuickAdd(innerCtx, f),
                                onEntryAction:     (m) => _onEntryAction(innerCtx, m),
                                onEntryDismiss:    (m) => _onEntryDismiss(innerCtx, m),
                                onToggleFavorite:  _toggleFavorite,
                                onViewFullNutrition: () =>
                                    Navigator.of(context).pop('nutrition'),
                              ),
                            ),
                          ),
                  ),
                ],
              ),

              // ── Undo banner — auto-hides after 2 s ──
              if (_undoVisible && _pendingUndo != null)
                Positioned(
                  left: 16, right: 16,
                  bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
                  child: _UndoBanner(
                    merged:  _pendingUndo!,
                    onUndo:  _triggerUndo,
                    onDismiss: () {
                      _undoTimer?.cancel();
                      setState(() => _undoVisible = false);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// EXPANDED CONTENT — StatefulWidget for category state
// ═══════════════════════════════════════════════════

class _ExpandedContent extends StatefulWidget {
  final int consumed;
  final int proteinGoal;
  final int remaining;
  final bool completed;
  final bool exceeded;
  final int consumedKcal;
  final int kcalGoal;
  final bool isFatLoss;
  final List<MealLogEntry> entries;
  final Set<String> favorites;
  final List<String> recents;
  final Map<String, int> mostUsed;
  final bool yesterdayAchieved;
  final String finisherFood;
  final String observation;
  final String eveningHabit; // '' = silent (cooldown or no reliable habit)
  final void Function(_ProteinFood) onQuickAdd;
  final void Function(_MergedEntry) onEntryAction;
  final void Function(_MergedEntry) onEntryDismiss;
  final void Function(String) onToggleFavorite;
  final VoidCallback onViewFullNutrition;

  const _ExpandedContent({
    required this.consumed,
    required this.proteinGoal,
    required this.remaining,
    required this.completed,
    required this.exceeded,
    required this.consumedKcal,
    required this.kcalGoal,
    required this.isFatLoss,
    required this.entries,
    required this.favorites,
    required this.recents,
    required this.mostUsed,
    required this.yesterdayAchieved,
    required this.finisherFood,
    required this.observation,
    this.eveningHabit = '',
    required this.onQuickAdd,
    required this.onEntryAction,
    required this.onEntryDismiss,
    required this.onToggleFavorite,
    required this.onViewFullNutrition,
  });

  @override
  State<_ExpandedContent> createState() => _ExpandedContentState();
}

class _ExpandedContentState extends State<_ExpandedContent> {
  // Multiple categories can be open simultaneously.
  // DAIRY and SUPPLEMENTS start open so Paneer/Whey are immediately visible.
  Set<String> _openCategories = {'DAIRY', 'SUPPLEMENTS'};
  // When target is completed, quick add collapses.
  // User can re-open it explicitly.
  late bool _showQuickAdd;

  @override
  void initState() {
    super.initState();
    _showQuickAdd = !widget.completed;
  }

  @override
  void didUpdateWidget(_ExpandedContent old) {
    super.didUpdateWidget(old);
    if (!old.completed && widget.completed) {
      _showQuickAdd = false;
    }
  }

  void _toggleCategory(String label) {
    setState(() {
      if (_openCategories.contains(label)) {
        _openCategories.remove(label);
      } else {
        _openCategories.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final merged = _mergeEntries(widget.entries);

    // Build smart quick-add ordering
    final favFoods = _allFoods
        .where((f) => widget.favorites.contains(f.label))
        .toList()
      ..sort((a, b) =>
          (widget.mostUsed[b.label] ?? 0).compareTo(widget.mostUsed[a.label] ?? 0));
    final favLabels    = widget.favorites;
    final recentFoods  = <_ProteinFood>[];
    for (final label in widget.recents) {
      final f = _allFoods.where((f) => f.label == label).firstOrNull;
      if (f != null && !favLabels.contains(f.label)) recentFoods.add(f);
    }
    final recentLabels = recentFoods.map((f) => f.label).toSet();

    // Most used — not in favorites or recents, top 3
    final muSorted = _allFoods
        .where((f) => !favLabels.contains(f.label) && !recentLabels.contains(f.label))
        .toList()
      ..sort((a, b) =>
          (widget.mostUsed[b.label] ?? 0).compareTo(widget.mostUsed[a.label] ?? 0));
    final mostUsedFoods = muSorted
        .where((f) => (widget.mostUsed[f.label] ?? 0) > 0)
        .take(3)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Coaching ───────────────────────────
          _buildCoachingArea(merged),

          // ── Yesterday acknowledgement ─────────────
          if (widget.consumed == 0 && widget.yesterdayAchieved) ...[
            const SizedBox(height: 8),
            Text(
              'Target hit yesterday. Recovery supported.',
              style: GoogleFonts.inter(
                color: AppColors.gold.withValues(alpha: 0.35),
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── 2. Today's Progress ───────────────────
          _buildProgress(),

          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 12),

          // ── History ───────────────────────────────
          if (merged.isEmpty)
            _buildEmptyState()
          else ...[
            _sectionLabel('TODAY'),
            const SizedBox(height: 6),
            ...merged.map((m) => _HistoryRow(
              merged:    m,
              onTap:     () => widget.onEntryAction(m),
              onDismiss: () => widget.onEntryDismiss(m),
            )),
            const SizedBox(height: 8),
          ],

          // ── Today's Summary (completed) ───────────
          if (widget.completed && merged.isNotEmpty) ...[
            _divider(),
            const SizedBox(height: 10),
            _buildSummary(merged),
            const SizedBox(height: 10),
          ],

          // ── Quick Add ─────────────────────────────
          if (_showQuickAdd) ...[
            _divider(),
            const SizedBox(height: 10),
            _sectionLabel('QUICK ADD'),
            const SizedBox(height: 8),

            // Favorites — horizontal scrollable chips
            if (favFoods.isNotEmpty) ...[
              _sectionLabel('FAVORITES'),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: favFoods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final f = favFoods[i];
                    return _QuickAddChip(
                      food: f,
                      isFavorite: true,
                      onTap:      () => widget.onQuickAdd(f),
                      onLongPress: () => widget.onToggleFavorite(f.label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Recent — horizontal scrollable chips
            if (recentFoods.isNotEmpty) ...[
              _sectionLabel('RECENT'),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: recentFoods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final f = recentFoods[i];
                    return _QuickAddChip(
                      food: f,
                      isFavorite: false,
                      onTap:      () => widget.onQuickAdd(f),
                      onLongPress: () => widget.onToggleFavorite(f.label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Most Used
            if (mostUsedFoods.isNotEmpty) ...[
              _sectionLabel('MOST USED'),
              const SizedBox(height: 4),
              ...mostUsedFoods.map((f) => _QuickAddRow(
                food: f, isFavorite: false,
                onTap:      () => widget.onQuickAdd(f),
                onLongPress: () => widget.onToggleFavorite(f.label),
              )),
              const SizedBox(height: 8),
            ],

            // Categorized accordion — collapsed by default
            ..._categories.map((cat) {
              final catFoods = cat.foods.toList();
              if (catFoods.isEmpty) return const SizedBox.shrink();
              final isOpen = _openCategories.contains(cat.label);
              return _CategoryAccordion(
                label:    cat.label,
                count:    catFoods.length,
                isOpen:   isOpen,
                onToggle: () => _toggleCategory(cat.label),
                foods:    catFoods,
                favorites: widget.favorites,
                onQuickAdd:      widget.onQuickAdd,
                onToggleFavorite: widget.onToggleFavorite,
              );
            }),

            const SizedBox(height: 4),
          ] else if (widget.completed) ...[
            // Offer to re-open quick add after completion
            _divider(),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showQuickAdd = true),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Add more protein',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 7. View Full Nutrition ────────────────
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onViewFullNutrition,
              borderRadius: BorderRadius.circular(14),
              splashColor: AppColors.gold.withValues(alpha: 0.06),
              highlightColor: AppColors.gold.withValues(alpha: 0.04),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF252525),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'View Full Nutrition',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Today's Progress ──────────────────────────

  Widget _buildProgress() {
    final progress =
        (widget.consumed / widget.proteinGoal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${widget.consumed}',
              style: GoogleFonts.rajdhani(
                color: AppColors.gold,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              ' / ${widget.proteinGoal}g',
              style: GoogleFonts.rajdhani(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              widget.completed
                  ? 'Target hit'
                  : '${widget.remaining}g left',
              style: GoogleFonts.inter(
                color: widget.completed
                    ? AppColors.gold.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.32),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(1.5),
          child: SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(
                widget.completed
                    ? AppColors.gold.withValues(alpha: 0.65)
                    : AppColors.gold.withValues(alpha: 0.50),
              ),
            ),
          ),
        ),
        if (widget.isFatLoss) ...[
          const SizedBox(height: 8),
          Text(
            '${widget.consumedKcal} / ${widget.kcalGoal} kcal',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.18),
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  // ── Coaching area ─────────────────────────────

  Widget _buildCoachingArea(List<_MergedEntry> merged) {
    final now       = DateTime.now();
    final evening   = now.hour >= 19;
    final remaining = widget.remaining;

    String text;

    if (widget.exceeded || widget.completed) {
      text = 'Target complete.\nRecovery supported.';
    } else if (widget.consumed == 0) {
      // Zero consumed — personalized from habit memory, otherwise time-of-day nudge.
      if (widget.finisherFood.isNotEmpty) {
        text = 'You usually finish with ${widget.finisherFood.toLowerCase()}.\n'
            'Let\'s do that again.';
      } else if (now.hour < 12) {
        text = '${remaining}g left.\nStart with breakfast.';
      } else if (now.hour < 16) {
        text = '${remaining}g left.\nStart with lunch.';
      } else {
        text = '${remaining}g left.\nDinner is your main chance.';
      }
    } else if (evening) {
      // Evening — remembered habit first (cooldown-gated), then the
      // gap-sized food suggestion as the everyday fallback.
      if (widget.eveningHabit.isNotEmpty && remaining <= 45) {
        text = '${remaining}g left.\n${widget.eveningHabit} usually finishes it.';
      } else if (remaining <= 8) {
        text = '${remaining}g left.\nMilk will finish it.';
      } else if (remaining <= 18) {
        text = '${remaining}g left.\nPaneer will finish it.';
      } else if (remaining <= 30) {
        text = '${remaining}g left.\nOne scoop of whey will finish it.';
      } else if (remaining <= 45) {
        text = '${remaining}g left.\nWhey and an egg will finish it.';
      } else {
        text = '${remaining}g left.\nA solid dinner gets you close.';
      }
    } else {
      // Daytime with some progress — specific food for small gaps, meal nudge for large.
      if (remaining <= 8) {
        text = '${remaining}g left.\nMilk will finish it.';
      } else if (remaining <= 18) {
        text = '${remaining}g left.\nPaneer is enough.';
      } else if (remaining <= 30) {
        text = '${remaining}g left.\nOne scoop of whey will finish it.';
      } else if (remaining <= 45) {
        text = '${remaining}g left.\nWhey and two eggs will do it.';
      } else if (now.hour < 12) {
        text = '${remaining}g left.\nStart with breakfast.';
      } else if (now.hour < 16) {
        text = '${remaining}g left.\nStart with lunch.';
      } else {
        text = '${remaining}g left.\nDinner is the main event.';
      }
    }

    // Occasional memory observation — at most one every few days,
    // shown alongside coaching while the day is still in progress.
    final showObservation =
        widget.observation.isNotEmpty && widget.consumed > 0 && !evening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.30),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        if (showObservation) ...[
          const SizedBox(height: 6),
          Text(
            widget.observation,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  // ── Today's Summary ───────────────────────────

  Widget _buildSummary(List<_MergedEntry> merged) {
    // Top source by total protein
    final top = merged.reduce((a, b) => a.totalProtein > b.totalProtein ? a : b);
    final parenIdx = top.originals.first.foods.first.indexOf('(');
    final topName  = parenIdx > 0
        ? top.originals.first.foods.first.substring(0, parenIdx).trim()
        : top.originals.first.foods.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY\'S SUMMARY',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.15),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.consumed}g consumed  ·  ${merged.fold<int>(0, (s, m) => s + m.count)} entries',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Top source: $topName (${top.totalProtein}g)',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nothing logged yet.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Start with your first protein source.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.20),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: Colors.white.withValues(alpha: 0.15),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
  );

  static Widget _divider() => Container(
    height: 0.5,
    color: Colors.white.withValues(alpha: 0.04),
  );
}

// ═══════════════════════════════════════════════════
// HISTORY ROW — merged entry with time, menu, swipe
// ═══════════════════════════════════════════════════

class _HistoryRow extends StatelessWidget {
  final _MergedEntry merged;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HistoryRow({
    required this.merged,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          _formatTime(merged.loggedAt),
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.16),
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Dismissible(
          key: ValueKey('merged_${merged.rawLabel}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 15,
              color: Colors.red.withValues(alpha: 0.45),
            ),
          ),
          onDismissed: (_) => onDismiss(),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _HistoryLabel(merged: merged),
                  ),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── History label — "Paneer" / "150g · +27g" ──────

class _HistoryLabel extends StatelessWidget {
  final _MergedEntry merged;
  const _HistoryLabel({required this.merged});

  @override
  Widget build(BuildContext context) {
    final raw = merged.rawLabel;
    final parenIdx = raw.indexOf('(');
    final foodName = parenIdx > 0 ? raw.substring(0, parenIdx).trim() : raw;
    final portionStr = (parenIdx > 0 && raw.endsWith(')'))
        ? raw.substring(parenIdx + 1, raw.length - 1)
        : '';
    final displayName = merged.count > 1 ? '$foodName ×${merged.count}' : foodName;
    final subtitle = [
      if (portionStr.isNotEmpty) portionStr,
      '+${merged.totalProtein}g',
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// CATEGORY ACCORDION
// ═══════════════════════════════════════════════════

class _CategoryAccordion extends StatelessWidget {
  final String label;
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<_ProteinFood> foods;
  final Set<String> favorites;
  final void Function(_ProteinFood) onQuickAdd;
  final void Function(String) onToggleFavorite;

  const _CategoryAccordion({
    required this.label,
    required this.count,
    required this.isOpen,
    required this.onToggle,
    required this.foods,
    required this.favorites,
    required this.onQuickAdd,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$label ($count)',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isOpen
              ? Column(
                  children: foods.map((f) => _QuickAddRow(
                    food:        f,
                    isFavorite:  favorites.contains(f.label),
                    onTap:       () => onQuickAdd(f),
                    onLongPress: () => onToggleFavorite(f.label),
                  )).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// QUICK ADD ROW
// ═══════════════════════════════════════════════════

class _QuickAddRow extends StatelessWidget {
  final _ProteinFood food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickAddRow({
    required this.food,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              if (isFavorite) ...[
                Icon(Icons.star_rounded, size: 11,
                    color: AppColors.gold.withValues(alpha: 0.35)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  food.label,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                '+${food.portions.first.protein}g',
                style: GoogleFonts.inter(
                  color: AppColors.gold.withValues(alpha: 0.40),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_rounded, size: 14,
                  color: Colors.white.withValues(alpha: 0.15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// QUICK ADD CHIP — horizontal pill for Favorites / Recent
// ═══════════════════════════════════════════════════

class _QuickAddChip extends StatelessWidget {
  final _ProteinFood food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickAddChip({
    required this.food,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2C2C2C), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFavorite) ...[
              Icon(Icons.star_rounded, size: 9,
                  color: AppColors.gold.withValues(alpha: 0.50)),
              const SizedBox(width: 4),
            ],
            Text(
              food.label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '+${food.portions.first.protein}g',
              style: GoogleFonts.inter(
                color: AppColors.gold.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ENTRY ACTION SHEET
// ═══════════════════════════════════════════════════

class _EntryActionSheet extends StatelessWidget {
  final _MergedEntry merged;
  const _EntryActionSheet({required this.merged});

  @override
  Widget build(BuildContext context) {
    final isMultiple = merged.count > 1;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            merged.label,
            style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${merged.totalProtein}g protein  ·  ${merged.totalKcal} kcal',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 11, fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          if (!isMultiple)
            _actionTile(
              context,
              icon: Icons.edit_outlined,
              label: 'Edit portion',
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          if (!isMultiple) const SizedBox(height: 6),
          _actionTile(
            context,
            icon: Icons.delete_outline_rounded,
            label: isMultiple ? 'Remove all ${merged.count} entries' : 'Remove entry',
            isDestructive: true,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Colors.red.withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252525), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(
              color: color, fontSize: 13, fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PORTION PICKER SHEET
// ═══════════════════════════════════════════════════

class _PortionPicker extends StatefulWidget {
  final _ProteinFood food;
  const _PortionPicker({required this.food});

  @override
  State<_PortionPicker> createState() => _PortionPickerState();
}

class _PortionPickerState extends State<_PortionPicker> {
  bool _saving = false;
  int? _selected;

  Future<void> _log(int idx) async {
    if (_saving) return;
    setState(() { _selected = idx; _saving = true; });
    HapticFeedback.mediumImpact();

    final p   = widget.food.portions[idx];
    final now = DateTime.now();
    final mealType = now.hour < 11
        ? 'Breakfast'
        : now.hour < 16
            ? 'Lunch'
            : now.hour < 20
                ? 'Dinner'
                : 'Snack';

    final entry = MealLogEntry(
      mealType: mealType,
      planDay:  1,
      foods:    ['${widget.food.label} (${p.label})'],
      kcal:     p.kcal,
      protein:  p.protein,
      carbs:    p.carbs,
      fats:     p.fats,
      loggedAt: now,
    );
    await MealLogService.logMeal('', entry);
    if (!mounted) return;
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.food.label,
            style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.food.portions.asMap().entries.map((e) {
            final idx        = e.key;
            final p          = e.value;
            final isSelected = _selected == idx;
            return GestureDetector(
              onTap: () => _log(idx),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.10)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.35)
                        : const Color(0xFF252525),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label, style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 13, fontWeight: FontWeight.w500,
                          )),
                          const SizedBox(height: 4),
                          Text('+${p.protein}g protein', style: GoogleFonts.inter(
                            color: AppColors.gold, fontSize: 17, fontWeight: FontWeight.w700,
                          )),
                          const SizedBox(height: 2),
                          Text('${p.kcal} kcal', style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.22),
                            fontSize: 10, fontWeight: FontWeight.w400,
                          )),
                        ],
                      ),
                    ),
                    if (isSelected && _saving)
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.gold,
                        ),
                      )
                    else
                      Icon(Icons.add_circle_outline_rounded, size: 20,
                          color: AppColors.gold.withValues(alpha: 0.35)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// UNDO BANNER — inline, auto-dismissed via Timer in parent
// ═══════════════════════════════════════════════════

class _UndoBanner extends StatelessWidget {
  final _MergedEntry merged;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _UndoBanner({
    required this.merged,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final raw      = merged.originals.first.foods.first;
    final parenIdx = raw.indexOf('(');
    final label    = parenIdx > 0 ? raw.substring(0, parenIdx).trim() : raw;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Removed $label',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          GestureDetector(
            onTap: onUndo,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                'UNDO',
                style: GoogleFonts.inter(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PROTEIN DATABASE
// ═══════════════════════════════════════════════════

class _ProteinFood {
  final String label;
  final String category;
  final List<_Portion> portions;
  const _ProteinFood({required this.label, required this.category, required this.portions});
}

class _Portion {
  final String label;
  final int protein;
  final int kcal;
  final int carbs;
  final int fats;
  const _Portion({required this.label, required this.protein, required this.kcal,
      this.carbs = 0, this.fats = 0});
}

class _FoodCategory {
  final String label;
  final List<_ProteinFood> foods;
  const _FoodCategory({required this.label, required this.foods});
}

// ── Animal ────────────────────────────────────────

const _animalFoods = <_ProteinFood>[
  _ProteinFood(label: 'Egg', category: 'ANIMAL', portions: [
    _Portion(label: '1 egg',  protein: 6,  kcal: 70,  fats: 5),
    _Portion(label: '2 eggs', protein: 12, kcal: 140, fats: 10),
    _Portion(label: '3 eggs', protein: 18, kcal: 210, carbs: 1, fats: 15),
  ]),
  _ProteinFood(label: 'White Eggs', category: 'ANIMAL', portions: [
    _Portion(label: '2 whites', protein: 7,  kcal: 34),
    _Portion(label: '4 whites', protein: 14, kcal: 68),
    _Portion(label: '6 whites', protein: 21, kcal: 102),
  ]),
  _ProteinFood(label: 'Chicken Breast', category: 'ANIMAL', portions: [
    _Portion(label: '100g', protein: 31, kcal: 165, fats: 4),
    _Portion(label: '150g', protein: 46, kcal: 248, fats: 6),
    _Portion(label: '200g', protein: 62, kcal: 330, fats: 8),
  ]),
  _ProteinFood(label: 'Chicken', category: 'ANIMAL', portions: [
    _Portion(label: '100g', protein: 27, kcal: 165, fats: 3),
    _Portion(label: '150g', protein: 40, kcal: 248, fats: 5),
    _Portion(label: '200g', protein: 54, kcal: 330, fats: 7),
  ]),
  _ProteinFood(label: 'Chicken Curry', category: 'ANIMAL', portions: [
    _Portion(label: '1 serving',  protein: 22, kcal: 240, carbs: 6,  fats: 14),
    _Portion(label: '2 servings', protein: 44, kcal: 480, carbs: 12, fats: 28),
  ]),
  _ProteinFood(label: 'Fish', category: 'ANIMAL', portions: [
    _Portion(label: '1 piece',  protein: 20, kcal: 120, fats: 3),
    _Portion(label: '2 pieces', protein: 40, kcal: 240, fats: 6),
  ]),
  _ProteinFood(label: 'Salmon', category: 'ANIMAL', portions: [
    _Portion(label: '100g', protein: 25, kcal: 208, fats: 13),
    _Portion(label: '150g', protein: 38, kcal: 312, fats: 19),
  ]),
  _ProteinFood(label: 'Sardines', category: 'ANIMAL', portions: [
    _Portion(label: '2 pieces',   protein: 12, kcal: 90,  fats: 5),
    _Portion(label: '1 can (90g)', protein: 19, kcal: 140, fats: 8),
  ]),
  _ProteinFood(label: 'Mackerel (Bangda)', category: 'ANIMAL', portions: [
    _Portion(label: '1 piece',  protein: 18, kcal: 140, fats: 6),
    _Portion(label: '2 pieces', protein: 36, kcal: 280, fats: 12),
  ]),
  _ProteinFood(label: 'Rohu', category: 'ANIMAL', portions: [
    _Portion(label: '1 piece',  protein: 20, kcal: 115, fats: 3),
    _Portion(label: '2 pieces', protein: 40, kcal: 230, fats: 6),
  ]),
  _ProteinFood(label: 'Katla', category: 'ANIMAL', portions: [
    _Portion(label: '1 piece',  protein: 19, kcal: 111, fats: 3),
    _Portion(label: '2 pieces', protein: 38, kcal: 222, fats: 6),
  ]),
  _ProteinFood(label: 'Surmai', category: 'ANIMAL', portions: [
    _Portion(label: '1 piece',  protein: 22, kcal: 110, fats: 2),
    _Portion(label: '2 pieces', protein: 44, kcal: 220, fats: 4),
  ]),
  _ProteinFood(label: 'Tuna', category: 'ANIMAL', portions: [
    _Portion(label: '1 can (85g)', protein: 20, kcal: 90,  fats: 1),
    _Portion(label: '100g',        protein: 24, kcal: 108, fats: 1),
  ]),
  _ProteinFood(label: 'Prawns', category: 'ANIMAL', portions: [
    _Portion(label: '100g', protein: 20, kcal: 85,  fats: 1),
    _Portion(label: '150g', protein: 30, kcal: 128, fats: 2),
  ]),
  _ProteinFood(label: 'Mutton', category: 'ANIMAL', portions: [
    _Portion(label: '100g',      protein: 25, kcal: 250, fats: 15),
    _Portion(label: '1 serving', protein: 20, kcal: 220, carbs: 4, fats: 14),
  ]),
];

// ── Dairy ─────────────────────────────────────────

const _dairyFoods = <_ProteinFood>[
  _ProteinFood(label: 'Milk', category: 'DAIRY', portions: [
    _Portion(label: '1 glass (250ml)', protein: 8,  kcal: 150, carbs: 12, fats: 8),
    _Portion(label: '2 glasses',       protein: 16, kcal: 300, carbs: 24, fats: 16),
  ]),
  _ProteinFood(label: 'Toned Milk', category: 'DAIRY', portions: [
    _Portion(label: '1 glass (250ml)', protein: 8,  kcal: 130, carbs: 12, fats: 3),
    _Portion(label: '2 glasses',       protein: 16, kcal: 260, carbs: 24, fats: 6),
  ]),
  _ProteinFood(label: 'Double Toned Milk', category: 'DAIRY', portions: [
    _Portion(label: '1 glass (250ml)', protein: 8,  kcal: 110, carbs: 12, fats: 2),
    _Portion(label: '2 glasses',       protein: 16, kcal: 220, carbs: 24, fats: 4),
  ]),
  _ProteinFood(label: 'Curd', category: 'DAIRY', portions: [
    _Portion(label: '1 bowl',  protein: 10, kcal: 100, carbs: 8,  fats: 4),
    _Portion(label: '2 bowls', protein: 20, kcal: 200, carbs: 16, fats: 8),
  ]),
  _ProteinFood(label: 'Greek Yogurt', category: 'DAIRY', portions: [
    _Portion(label: '100g', protein: 10, kcal: 60,  carbs: 4, fats: 1),
    _Portion(label: '200g', protein: 20, kcal: 120, carbs: 8, fats: 2),
  ]),
  _ProteinFood(label: 'Paneer', category: 'DAIRY', portions: [
    _Portion(label: '50g',  protein: 9,  kcal: 130, carbs: 2, fats: 10),
    _Portion(label: '100g', protein: 18, kcal: 260, carbs: 4, fats: 20),
    _Portion(label: '150g', protein: 27, kcal: 390, carbs: 6, fats: 30),
  ]),
  _ProteinFood(label: 'Low-fat Paneer', category: 'DAIRY', portions: [
    _Portion(label: '50g',  protein: 10, kcal: 80,  carbs: 2, fats: 2),
    _Portion(label: '100g', protein: 20, kcal: 160, carbs: 4, fats: 4),
    _Portion(label: '150g', protein: 30, kcal: 240, carbs: 6, fats: 6),
  ]),
];

// ── Vegetarian ────────────────────────────────────

const _vegFoods = <_ProteinFood>[
  _ProteinFood(label: 'Soya Chunks', category: 'VEG', portions: [
    _Portion(label: '50g (dry)',  protein: 26, kcal: 170, carbs: 15, fats: 5),
    _Portion(label: '100g (dry)', protein: 52, kcal: 340, carbs: 30, fats: 10),
  ]),
  _ProteinFood(label: 'Tofu', category: 'VEG', portions: [
    _Portion(label: '100g', protein: 8,  kcal: 76,  carbs: 2, fats: 4),
    _Portion(label: '200g', protein: 16, kcal: 152, carbs: 4, fats: 8),
  ]),
  _ProteinFood(label: 'Tempeh', category: 'VEG', portions: [
    _Portion(label: '100g', protein: 19, kcal: 193, carbs: 9,  fats: 11),
    _Portion(label: '150g', protein: 28, kcal: 290, carbs: 14, fats: 16),
  ]),
  _ProteinFood(label: 'Dal', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 9,  kcal: 120, carbs: 18, fats: 2),
    _Portion(label: '2 bowls', protein: 18, kcal: 240, carbs: 36, fats: 4),
  ]),
  _ProteinFood(label: 'Masoor Dal', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 10, kcal: 130, carbs: 18, fats: 1),
    _Portion(label: '2 bowls', protein: 20, kcal: 260, carbs: 36, fats: 2),
  ]),
  _ProteinFood(label: 'Moong Dal', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 12, kcal: 130, carbs: 20, fats: 1),
    _Portion(label: '2 bowls', protein: 24, kcal: 260, carbs: 40, fats: 2),
  ]),
  _ProteinFood(label: 'Urad Dal', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 11, kcal: 140, carbs: 18, fats: 1),
    _Portion(label: '2 bowls', protein: 22, kcal: 280, carbs: 36, fats: 2),
  ]),
  _ProteinFood(label: 'Rajma', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 8,  kcal: 140, carbs: 22, fats: 2),
    _Portion(label: '2 bowls', protein: 16, kcal: 280, carbs: 44, fats: 4),
  ]),
  _ProteinFood(label: 'Chickpeas (Chole)', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 10, kcal: 160, carbs: 24, fats: 3),
    _Portion(label: '2 bowls', protein: 20, kcal: 320, carbs: 48, fats: 6),
  ]),
  _ProteinFood(label: 'Black Chana', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 10, kcal: 155, carbs: 25, fats: 2),
    _Portion(label: '2 bowls', protein: 20, kcal: 310, carbs: 50, fats: 4),
  ]),
  _ProteinFood(label: 'Moong Sprouts', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 8,  kcal: 70,  carbs: 10, fats: 1),
    _Portion(label: '2 bowls', protein: 16, kcal: 140, carbs: 20, fats: 2),
  ]),
  _ProteinFood(label: 'Mixed Sprouts', category: 'VEG', portions: [
    _Portion(label: '1 bowl',  protein: 7,  kcal: 80,  carbs: 12, fats: 1),
    _Portion(label: '2 bowls', protein: 14, kcal: 160, carbs: 24, fats: 2),
  ]),
  _ProteinFood(label: 'Peanut Butter', category: 'VEG', portions: [
    _Portion(label: '1 tbsp', protein: 4, kcal: 95,  carbs: 3, fats: 8),
    _Portion(label: '2 tbsp', protein: 8, kcal: 190, carbs: 6, fats: 16),
  ]),
  _ProteinFood(label: 'Roasted Peanuts', category: 'VEG', portions: [
    _Portion(label: '1 handful (30g)', protein: 7,  kcal: 165, carbs: 5,  fats: 14),
    _Portion(label: '2 handfuls',      protein: 14, kcal: 330, carbs: 10, fats: 28),
  ]),
];

// ── Supplements ───────────────────────────────────

const _supplementFoods = <_ProteinFood>[
  _ProteinFood(label: 'Whey Protein', category: 'SUPP', portions: [
    _Portion(label: '1 scoop',  protein: 25, kcal: 120, carbs: 3, fats: 2),
    _Portion(label: '2 scoops', protein: 50, kcal: 240, carbs: 6, fats: 4),
  ]),
];

// ── Ready Protein ─────────────────────────────────

const _readyFoods = <_ProteinFood>[
  _ProteinFood(label: 'Protein Bar', category: 'READY', portions: [
    _Portion(label: '1 bar', protein: 20, kcal: 200, carbs: 22, fats: 7),
  ]),
  _ProteinFood(label: 'Protein Shake', category: 'READY', portions: [
    _Portion(label: '1 serving', protein: 25, kcal: 150, carbs: 5, fats: 3),
  ]),
  _ProteinFood(label: 'Protein Lassi', category: 'READY', portions: [
    _Portion(label: '1 glass', protein: 15, kcal: 200, carbs: 20, fats: 5),
  ]),
];

// ── Index ─────────────────────────────────────────

final _allFoods = <_ProteinFood>[
  ..._animalFoods,
  ..._dairyFoods,
  ..._vegFoods,
  ..._supplementFoods,
  ..._readyFoods,
];

final _categories = <_FoodCategory>[
  const _FoodCategory(label: 'ANIMAL',        foods: _animalFoods),
  const _FoodCategory(label: 'DAIRY',         foods: _dairyFoods),
  const _FoodCategory(label: 'VEGETARIAN',    foods: _vegFoods),
  const _FoodCategory(label: 'SUPPLEMENTS',   foods: _supplementFoods),
  const _FoodCategory(label: 'READY PROTEIN', foods: _readyFoods),
];
