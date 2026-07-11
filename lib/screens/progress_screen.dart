// lib/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/app_provider.dart';
import '../utils/app_constants.dart';
import '../data/exercise_data.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // ✅ FIX: no longer hardcoded to "Deadlift"
  String _selectedExercise = 'Deadlift';

  static final List<String> _exercises = ExerciseData.list
      .where((e) => e['bodyweight'] == false)
      .map((e) => e['name'] as String)
      .toList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final key = provider.getKey(_selectedExercise.toLowerCase().replaceAll(' ', '_'));
    final logs = provider.getLogsForExercise(key);

    final streak = provider.streak.currentStreak;
    final total = provider.workoutLogs.length;

    final pr = logs.isNotEmpty
        ? logs.map((e) => e.weight).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Progress', style: TextStyle(fontFamily: 'Rajdhani',fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.bg,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 STATS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statCard('🔥 Streak', '$streak days'),
                _statCard('🏋️ Workouts', '$total'),
                _statCard('🏆 PR', '${pr.toInt()} kg'),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ FIX: Exercise selector dropdown
            const Text('Select Exercise', style: TextStyle(fontFamily: 'Rajdhani',
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 1,
            )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButton<String>(
                value: _selectedExercise,
                isExpanded: true,
                dropdownColor: AppColors.bgCard,
                underline: const SizedBox(),
                style: const TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 14),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedExercise = val);
                },
                items: _exercises.map((name) => DropdownMenuItem(
                  value: name,
                  child: Text(name),
                )).toList(),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '$_selectedExercise Progress',
              style: const TextStyle(fontFamily: 'Rajdhani',
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // 📊 GRAPH
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.show_chart, color: AppColors.gold, size: 48),
                          const SizedBox(height: 12),
                          Text('No data for $_selectedExercise yet',
                              style: const TextStyle(fontFamily: 'Inter',color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          const Text('Log this exercise in Planner to see progress',
                              style: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(
                                '${value.toInt()}',
                                style: const TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(
                                '#${value.toInt() + 1}',
                                style: const TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            barWidth: 3,
                            color: AppColors.gold,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.gold,
                                strokeWidth: 2,
                                strokeColor: Colors.black,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.gold.withValues(alpha: 0.08),
                            ),
                            spots: logs.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value.weight);
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Inter',fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontFamily: 'Rajdhani',
            fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
          )),
        ],
      ),
    );
  }
}
