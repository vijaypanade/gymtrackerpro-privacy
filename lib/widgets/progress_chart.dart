import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/app_constants.dart';

class ProgressChart extends StatelessWidget {
  final String exerciseKey;
  final String unit;

  const ProgressChart({
    super.key,
    required this.exerciseKey,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final spots = provider.getProgressSpots(exerciseKey, unit);

    if (spots.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text("No data yet 📉"),
      );
    }

    // 🔥 logs (sorted + last 5)
    final allLogs = provider.logs
        .where((l) => l.exercise == exerciseKey)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final logs = allLogs.length > 5
        ? allLogs.sublist(allLogs.length - 5)
        : allLogs;

  final double maxY =
        spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.15),
            Colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          clipData: FlClipData.none(),

          minX: 0,
          maxX: spots.length > 1 ? spots.length - 1 : 1,
          minY: 0,

          // ✅ DYNAMIC SCALE FIX
        maxY: maxY.toDouble() < 50
    ? (maxY + 10).toDouble()
    : maxY.toDouble() < 150
        ? (maxY + 20).toDouble()
        : (maxY + (maxY * 0.2)).toDouble(),
          // 🔥 GRID
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(spots),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 0.8,
            ),
          ),

          // 🔥 TITLES
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: _getInterval(spots),
                getTitlesWidget: (value, meta) {
                  if (value % _getInterval(spots) != 0) {
                    return const SizedBox();
                  }

                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),

            // 🔥 DATE
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= logs.length) {
                    return const SizedBox();
                  }

                  final date = logs[value.toInt()].date;

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "${date.day.toString().padLeft(2, '0')}/"
                      "${date.month.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),

            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),

          borderData: FlBorderData(show: false),

          // 🔥 LINE
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: AppColors.gold,
              barWidth: 3,
              isStrokeCapRound: true,

              // 🔥 DOT LOGIC (FIXED)
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final spots = bar.spots;

                  final double maxY = spots
                      .map((e) => e.y)
                      .reduce((a, b) => a > b ? a : b);

                  final isLast = index == spots.length - 1;
                  final isPR = (spot.y - maxY).abs() < 0.1;

                  // ❌ HIDE duplicate
                  if (!isLast &&
                      index > 0 &&
                      (spot.y - spots[index - 1].y).abs() < 0.1) {
                    return FlDotCirclePainter(
                      radius: 0,
                      color: Colors.transparent,
                    );
                  }

                  // 🟣 BOTH
                  if (isPR && isLast) {
                    return FlDotCirclePainter(
                      radius: 7,
                      color: Colors.purple,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  }

                  // 🟢 PR
                  if (isPR) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.green,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  }

                  // 🟠 TODAY
                  if (isLast) {
                    return FlDotCirclePainter(
                      radius: 7,
                      color: Colors.orange,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  }

                  // 🔴 DROP
                  if (index > 0 &&
                      spot.y < spots[index - 1].y) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.black,
                    );
                  }

                  // 🟡 NORMAL
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.gold,
                    strokeWidth: 2,
                    strokeColor: Colors.black,
                  );
                },
              ),

              // 🔥 AREA
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],

          // 🔥 TOOLTIP (FIXED)
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 12,
              getTooltipColor: (_) =>
                  Colors.black.withValues(alpha: 0.85),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((e) {
                  final index = e.x.toInt();

                  if (index >= logs.length) return null;

                  final log = logs[index];

                  return LineTooltipItem(
                    '${log.weight.toStringAsFixed(0)} kg\n'
                    '${log.reps} reps\n'
                    '${log.date.day}/${log.date.month}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),

        // 🔥 SMOOTH ANIMATION

      ),
    );
  }

  double _getInterval(List<FlSpot> spots) {
    final double maxY =
        spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 25;
    return 50;
  }
}