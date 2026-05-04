// lib/screens/ai_setup_screen.dart
// REPLACE entire file. Do not merge/append.
import 'package:flutter/material.dart';
import '../engines/workout_engine.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_engine.dart';
import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';

class AISetupScreen extends StatefulWidget {
  const AISetupScreen({super.key});

  @override
  State<AISetupScreen> createState() => _AISetupScreenState();
}

class _AISetupScreenState extends State<AISetupScreen> {
  int    _step          = 0;
  String _goal          = 'muscle_gain';
  String _level         = 'intermediate';
  String _trainerType   = 'friendly';
  String _weakMuscle    = '';
  bool   _isGenerating  = false;

  WorkoutPlanResult? _planResult; // ✅ typed — NOT Map

  Future<void> _generatePlan() async {
    print("🔥 AI ENGINE CALLED");  
    setState(() => _isGenerating = true);
    final provider = context.read<AppProvider>();
    await Future.delayed(const Duration(milliseconds: 1200));

    // ✅ generateWeeklyPlan — no generateWorkoutPlanAdvanced
    final result = AIEngine.generateWeeklyPlan(
  goal: _goal,
  level: _level,
  logs: provider.logs,
  weakMuscle: _weakMuscle,
  recoveryScore: provider.recoveryScore.round(),
  fatigued: provider.isFatigued,
);
    if (mounted) setState(() { _planResult = result; _isGenerating = false; _step = 4; });
  }

  Future<void> _applyPlan() async {
    if (_planResult == null) return;
    final provider = context.read<AppProvider>();

    final updatedProfile = provider.profile.copyWith(
      goal: _goal, level: _level, trainerType: _trainerType,
    );
    provider.updateProfile(updatedProfile);

    // ✅ applyGeneratedPlan accepts WorkoutPlanResult
    await provider.applyGeneratedPlan(_planResult!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Plan applied! Check your Weekly Planner.'),
            backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('AI SETUP'),
        leading: _step > 0 && _step < 4
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => setState(() => _step--))
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(_step),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0: return _StepGoal(key: const ValueKey(0), selected: _goal,
          onSelect: (v) => setState(() { _goal = v; _step = 1; }));
      case 1: return _StepLevel(key: const ValueKey(1), selected: _level,
          onSelect: (v) => setState(() { _level = v; _step = 2; }));
      case 2: return _StepTrainer(key: const ValueKey(2), selected: _trainerType,
          onSelect: (v) => setState(() { _trainerType = v; _step = 3; }));
      case 3: return _StepWeakMuscle(key: const ValueKey(3),
          selected: _weakMuscle, isGenerating: _isGenerating,
          onSelect: (v) => setState(() => _weakMuscle = v),
          // ✅ sync VoidCallback — wraps async
          onGenerate: _generatePlan,);
      default: return _StepResults(key: const ValueKey(4),
          result: _planResult, onApply: _applyPlan,
          onRegenerate: () => setState(() { _step = 3; _planResult = null; }));
    }
  }
}

// ── STEP 0: GOAL ─────────────────────────────────────────────
class _StepGoal extends StatelessWidget {
  final String selected; final ValueChanged<String> onSelect;
  static const _goals = [
    {'key':'muscle_gain','label':'Muscle Gain','emoji':'💪','desc':'Build size and definition'},
    {'key':'fat_loss',   'label':'Fat Loss',   'emoji':'🔥','desc':'Burn fat, keep muscle'},
    {'key':'strength',   'label':'Strength',   'emoji':'🏋️','desc':'Lift heavier over time'},
  ];
  const _StepGoal({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(title: 'What\'s your goal?', subtitle: 'We\'ll build your entire plan around this.',
      child: Column(children: _goals.map((g) => _OptionCard(
        emoji: g['emoji']!, label: g['label']!, desc: g['desc']!,
        selected: g['key'] == selected, onTap: () => onSelect(g['key']!),
      )).toList()));
  }
}

// ── STEP 1: LEVEL ─────────────────────────────────────────────
class _StepLevel extends StatelessWidget {
  final String selected; final ValueChanged<String> onSelect;
  static const _levels = [
    {'key':'beginner',    'label':'Beginner',    'emoji':'🌱','desc':'Less than 6 months'},
    {'key':'intermediate','label':'Intermediate','emoji':'⚡','desc':'6 months to 2 years'},
    {'key':'advanced',    'label':'Advanced',    'emoji':'🔱','desc':'2+ years consistent'},
  ];
  const _StepLevel({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(title: 'What\'s your level?', subtitle: 'Be honest — the right plan matters.',
      child: Column(children: _levels.map((l) => _OptionCard(
        emoji: l['emoji']!, label: l['label']!, desc: l['desc']!,
        selected: l['key'] == selected, onTap: () => onSelect(l['key']!),
      )).toList()));
  }
}

// ── STEP 2: TRAINER ───────────────────────────────────────────
class _StepTrainer extends StatelessWidget {
  final String selected; final ValueChanged<String> onSelect;
  static const _trainers = [
    {'key':'friendly',    'label':'Friendly',  'emoji':'😊','desc':'Supportive & encouraging'},
    {'key':'strict',      'label':'Strict',    'emoji':'😤','desc':'No excuses. Just results.'},
    {'key':'military',    'label':'Military',  'emoji':'🪖','desc':'Drill sergeant energy'},
    {'key':'motivational','label':'Hype Coach','emoji':'🔥','desc':'Maximum hype, maximum gains'},
  ];
  const _StepTrainer({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(title: 'Choose your trainer', subtitle: 'How should your AI coach talk to you?',
      child: Column(children: _trainers.map((t) => _OptionCard(
        emoji: t['emoji']!, label: t['label']!, desc: t['desc']!,
        selected: t['key'] == selected, onTap: () => onSelect(t['key']!),
      )).toList()));
  }
}

// ── STEP 3: WEAK MUSCLE + GENERATE ───────────────────────────
class _StepWeakMuscle extends StatelessWidget {
  final String selected;
  final bool isGenerating;
  final ValueChanged<String> onSelect;
  final VoidCallback onGenerate;

  static const _muscles = [
    {'key':'chest',    'label':'Chest',    'emoji':'🏋️'},
    {'key':'back',     'label':'Back',     'emoji':'💪'},
    {'key':'legs',     'label':'Legs',     'emoji':'🦵'},
    {'key':'shoulders','label':'Shoulders','emoji':'🔝'},
    {'key':'arms',     'label':'Arms',     'emoji':'💪'},
    {'key':'core',     'label':'Core',     'emoji':'🔥'},
  ];

  const _StepWeakMuscle({super.key,
    required this.selected, required this.isGenerating,
    required this.onSelect, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return _StepWrapper(
      title: 'Weak point to prioritize?',
      subtitle: 'Optional — extra volume for this muscle.',
      child: Column(children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          GestureDetector(onTap: () => onSelect(''),
            child: _RecoveryMuscleChip(emoji: '⏭️', label: 'Skip', selected: selected.isEmpty)),
          ..._muscles.map((m) => GestureDetector(onTap: () => onSelect(m['key']!),
            child: _RecoveryMuscleChip(emoji: m['emoji']!, label: m['label']!, selected: selected == m['key']))),
        ]),
        const SizedBox(height: 32),
        // ✅ VoidCallback — no async issues
        GoldButton(
          text: isGenerating ? 'Generating Plan... ⏳' : '🤖 Generate My Plan',
          width: double.infinity,
         onTap: isGenerating
    ? () {}
    : () {
        debugPrint("🔥 BUTTON PRESSED");
        onGenerate();
      },
        ),
      ]),
    );
  }
}

class _RecoveryMuscleChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;

  const _RecoveryMuscleChip({
    required this.emoji,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? Colors.yellow.withOpacity(0.15) : Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.yellow : Colors.white24,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// ── STEP 4: RESULTS ───────────────────────────────────────────
class _StepResults extends StatelessWidget {
  final WorkoutPlanResult? result;
  final Future<void> Function() onApply;
  final VoidCallback onRegenerate;

  const _StepResults({super.key,
    required this.result, required this.onApply, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    if (result == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
  child: ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
    children: [

      /// 🔥 HEADER
      Text(
        'Your Plan is Ready! 🎉',
        style: TextStyle(
          fontFamily: 'Rajdhani',
          color: AppColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 6),

      Text(
        result!.summary,
        style: TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),

      const SizedBox(height: 20),

      /// 🔥 PLAN LIST
      ...result!.plan.entries.map((entry) {
        final isRest =
            entry.value.isEmpty || entry.value.first == 'Rest';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRest
                  ? AppColors.divider
                  : AppColors.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔹 DAY HEADER
              Row(
                children: [
                  Text(
                    isRest ? '😴' : '🏋️',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        color: isRest
                            ? AppColors.textMuted
                            : AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  if (!isRest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              /// 🔹 EXERCISES
              /// 🔹 EXERCISES
if (!isRest) ...[
  const SizedBox(height: 8),

  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: entry.value.map((exercise) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ",
                style: TextStyle(color: Colors.white, fontSize: 14)),
            Expanded(
              child: Text(
                exercise,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  ),
],
            ],
          ),
        );
      }),

      const SizedBox(height: 30),

      /// 🔥 APPLY BUTTON
      GoldButton(
        text: 'Apply This Plan ✅',
        width: double.infinity,
        onTap: () async {
          await onApply();
        },
      ),

      const SizedBox(height: 12),

      /// 🔁 REGENERATE
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onRegenerate,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Regenerate 🔄',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: AppColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      const SizedBox(height: 20),
    ],
  ),
);
  }
}

// ── SHARED WRAPPERS ───────────────────────────────────────────
class _StepWrapper extends StatelessWidget {
  final String title, subtitle; final Widget child;
  const _StepWrapper({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontFamily: 'Rajdhani',
            color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontFamily: 'Nunito',color: AppColors.textMuted, fontSize: 14)),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji, label, desc; final bool selected; final VoidCallback onTap;
  const _OptionCard({required this.emoji, required this.label, required this.desc,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.08) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.gold : AppColors.divider,
              width: selected ? 1.5 : 1)),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: (selected ? AppColors.gold : AppColors.textMuted).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: 'Rajdhani',
                color: selected ? AppColors.gold : AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
            Text(desc, style: TextStyle(fontFamily: 'Nunito',color: AppColors.textMuted, fontSize: 13)),
          ])),
          if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 22),
        ]),
      ),
    );
  }
}
