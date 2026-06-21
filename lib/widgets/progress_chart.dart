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

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Single sorted list — spots and labels share the SAME indices
    final allLogs = provider.logs
        .where((l) => l.exercise == exerciseKey)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = provider.getProgressSpots(exerciseKey, unit);

    if (spots.isEmpty || allLogs.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text(
          'No data yet',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    final double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double chartMaxY = maxY < 50
        ? (maxY + 10).toDouble()
        : maxY < 150
            ? (maxY + 20).toDouble()
            : maxY + maxY * 0.18;

    final int n = allLogs.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          clipData: FlClipData.none(),
          minX: 0,
          maxX: spots.length > 1 ? spots.length - 1 : 1,
          minY: 0,
          maxY: chartMaxY,

          // Grid
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(spots),
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 0.5,
            ),
          ),

          // Titles
          titlesData: FlTitlesData(
            // Y-axis left
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: _getInterval(spots),
                getTitlesWidget: (value, meta) {
                  if (value % _getInterval(spots) != 0) return const SizedBox();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                    ),
                  );
                },
              ),
            ),

            // X-axis bottom — FIXED: same index as spots, show first/mid/last only
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= n) return const SizedBox.shrink();

                  // Show only first, middle, last to prevent overlap
                  final isFirst = idx == 0;
                  final isLast  = idx == n - 1;
                  final isMid   = n > 2 && idx == n ~/ 2;
                  if (!isFirst && !isLast && !isMid) return const SizedBox.shrink();

                  final date  = allLogs[idx].date;
                  final label = '${_monthAbbr[date.month]} ${date.day}';

                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),

            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),

          borderData: FlBorderData(show: false),

          // Line
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.goldAmber.withValues(alpha: 0.85),
              barWidth: 1.8,
              isStrokeCapRound: true,

              // Dot logic
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final allSpots = bar.spots;
                  final double peak = allSpots
                      .map((e) => e.y)
                      .reduce((a, b) => a > b ? a : b);
                  final isLast = index == allSpots.length - 1;
                  final isPR   = (spot.y - peak).abs() < 0.1;

                  // Hide if same value as prev
                  if (!isLast &&
                      index > 0 &&
                      (spot.y - allSpots[index - 1].y).abs() < 0.1) {
                    return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                  }

                  if (isPR && isLast) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.goldAmber,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF0A0A0A),
                    );
                  }
                  if (isPR) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.goldAmber.withValues(alpha: 0.80),
                      strokeWidth: 1.5,
                      strokeColor: const Color(0xFF0A0A0A),
                    );
                  }
                  if (isLast) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.goldAmber.withValues(alpha: 0.75),
                      strokeWidth: 1.5,
                      strokeColor: const Color(0xFF0A0A0A),
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 2,
                    color: AppColors.goldAmber.withValues(alpha: 0.40),
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),

              // Premium gradient fill below line
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.goldAmber.withValues(alpha: 0.18),
                    AppColors.goldAmber.withValues(alpha: 0.00),
                  ],
                ),
              ),
            ),
          ],

          // Tooltip
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 10,
              getTooltipColor: (_) => const Color(0xFF1A1A1A),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((e) {
                  final idx = e.x.toInt();
                  if (idx < 0 || idx >= allLogs.length) return null;
                  final log  = allLogs[idx];
                  final date = log.date;
                  return LineTooltipItem(
                    '${log.weight.toStringAsFixed(0)} kg · ${log.reps} reps\n'
                    '${_monthAbbr[date.month]} ${date.day}',
                    const TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _getInterval(List<FlSpot> spots) {
    final double maxY =
        spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 50)  return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 25;
    return 50;
  }
}
