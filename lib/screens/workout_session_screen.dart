// lib/screens/workout_session_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_constants.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Map<String, dynamic> day;

  const WorkoutSessionScreen({super.key, required this.day});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  List<Map<String, dynamic>> _sets = [];

  @override
  void initState() {
    super.initState();
    final exercises = widget.day['exercises'] as List? ?? [];
    for (final ex in exercises) {
      final count = (ex['sets'] as int?) ?? 3;
      for (int i = 0; i < count; i++) {
        _sets.add({
          'name': ex['name'] ?? '',
          'reps': 0,
          'done': false,
        });
      }
    }
  }

  int get _completedCount => _sets.where((s) => s['done'] == true).length;
  double get _progress => _sets.isEmpty ? 0 : _completedCount / _sets.length;

  void _increment(int i) {
    HapticFeedback.selectionClick();
    setState(() => _sets[i]['reps'] = (_sets[i]['reps'] as int) + 1);
  }

  void _decrement(int i) {
    if ((_sets[i]['reps'] as int) <= 0) return;
    HapticFeedback.selectionClick();
    setState(() => _sets[i]['reps'] = (_sets[i]['reps'] as int) - 1);
  }

  void _toggleDone(int i) {
    HapticFeedback.lightImpact();
    setState(() => _sets[i]['done'] = !(_sets[i]['done'] as bool));
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.day['focus'] as String? ?? 'Workout';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(focus,
            style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_completedCount / ${_sets.length}',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Set list
          Expanded(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _sets.length,
              itemBuilder: (_, i) => _SetRow(
                set: _sets[i],
                index: i,
                onIncrement: () => _increment(i),
                onDecrement: () => _decrement(i),
                onToggle: () => _toggleDone(i),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gold, AppColors.goldSoft],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _completedCount == _sets.length
                      ? 'Complete Workout'
                      : 'Finish Session',
                  style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final Map<String, dynamic> set;
  final int index;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggle;

  const _SetRow({
    required this.set,
    required this.index,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final done = set['done'] as bool;
    final reps = set['reps'] as int;
    final name = set['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF131313) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.bgElevated,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Done indicator
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.gold
                    : AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : null,
                size: 16,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + set number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: done
                            ? AppColors.textMuted
                            : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Set ${index + 1}',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textMuted)),
              ],
            ),
          ),

          // Reps counter
          if (!done) ...[
            _CounterButton(
              icon: Icons.remove_rounded,
              onTap: onDecrement,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$reps',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            _CounterButton(
              icon: Icons.add_rounded,
              onTap: onIncrement,
            ),
            const SizedBox(width: 4),
            Text('reps',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textMuted)),
          ] else ...[
            Text('$reps reps',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}
