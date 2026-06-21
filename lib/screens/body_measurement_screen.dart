// lib/screens/body_measurement_screen.dart — Premium Body Stats
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/app_constants.dart';

// ── Metric descriptor ─────────────────────────────────────────────────────────
class _Metric {
  final String  label;
  final String  unit;
  final Color   color;
  final double? Function(BodyMeasurement) value;

  const _Metric({
    required this.label,
    required this.unit,
    required this.color,
    required this.value,
  });
}

final _metrics = [
  _Metric(label: 'Weight', unit: 'kg', color: AppColors.gold,
      value: (m) => m.weightKg),
  _Metric(label: 'Chest',  unit: 'cm', color: const Color(0xFFEF5350),
      value: (m) => m.chestCm),
  _Metric(label: 'Waist',  unit: 'cm', color: const Color(0xFF42A5F5),
      value: (m) => m.waistCm),
  _Metric(label: 'Hips',   unit: 'cm', color: const Color(0xFFAB47BC),
      value: (m) => m.hipsCm),
  _Metric(label: 'Arms',   unit: 'cm', color: const Color(0xFF66BB6A),
      value: (m) => m.leftArmCm ?? m.rightArmCm),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class BodyMeasurementScreen extends StatefulWidget {
  const BodyMeasurementScreen({super.key});

  @override
  State<BodyMeasurementScreen> createState() => _BodyMeasurementScreenState();
}

class _BodyMeasurementScreenState extends State<BodyMeasurementScreen> {
  final _chestCtrl    = TextEditingController();
  final _waistCtrl    = TextEditingController();
  final _hipsCtrl     = TextEditingController();
  final _leftArmCtrl  = TextEditingController();
  final _rightArmCtrl = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _notesCtrl    = TextEditingController();

  int _metricIdx = 0;    // which chart metric is selected

  @override
  void dispose() {
    for (final c in [_chestCtrl, _waistCtrl, _hipsCtrl,
                     _leftArmCtrl, _rightArmCtrl, _weightCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save(AppProvider p) {
    final w  = double.tryParse(_weightCtrl.text);
    final ch = double.tryParse(_chestCtrl.text);
    final wa = double.tryParse(_waistCtrl.text);
    final hi = double.tryParse(_hipsCtrl.text);
    final la = double.tryParse(_leftArmCtrl.text);
    final ra = double.tryParse(_rightArmCtrl.text);

    if ([w, ch, wa, hi, la, ra].every((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter at least one measurement.',
            style: GoogleFonts.inter()),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    p.addMeasurement(BodyMeasurement(
      id:         const Uuid().v4(),
      date:       DateTime.now().toIso8601String().substring(0, 10),
      weightKg:   w,
      chestCm:    ch,
      waistCm:    wa,
      hipsCm:     hi,
      leftArmCm:  la,
      rightArmCm: ra,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));

    for (final c in [_chestCtrl, _waistCtrl, _hipsCtrl,
                     _leftArmCtrl, _rightArmCtrl, _weightCtrl, _notesCtrl]) {
      c.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Saved!', style: GoogleFonts.inter()),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p            = context.watch<AppProvider>();
    // Newest first for display; oldest first for chart
    final sorted       = [...p.measurements]
        ..sort((a, b) => b.date.compareTo(a.date));
    final chronological = sorted.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ──────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.bg,
            pinned: true, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text('BODY STATS',
                  style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 19, fontWeight: FontWeight.w900,
                      letterSpacing: 1.6)),
              Text('Track your transformation',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
              child: Column(children: [

                // ── Chart section (only when 2+ entries) ─────
                if (chronological.length >= 2) ...[
                  _MetricTabBar(
                    selected:  _metricIdx,
                    onSelect:  (i) => setState(() => _metricIdx = i),
                    measurements: chronological,
                  ),
                  const SizedBox(height: 12),
                  _TrendChart(
                    measurements: chronological,
                    metric:       _metrics[_metricIdx],
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Log form ──────────────────────────────────
                _LogForm(
                  chestCtrl:    _chestCtrl,
                  waistCtrl:    _waistCtrl,
                  hipsCtrl:     _hipsCtrl,
                  leftArmCtrl:  _leftArmCtrl,
                  rightArmCtrl: _rightArmCtrl,
                  weightCtrl:   _weightCtrl,
                  notesCtrl:    _notesCtrl,
                  onSave:       () => _save(p),
                ),

                const SizedBox(height: 24),

                // ── History ───────────────────────────────────
                if (sorted.isEmpty)
                  _EmptyState()
                else ...[
                  Row(children: [
                    Text('HISTORY',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 10),
                  ...sorted.asMap().entries.map((e) {
                    final prev = e.key < sorted.length - 1
                        ? sorted[e.key + 1]
                        : null;
                    return _HistoryCard(
                      current: e.value,
                      previous: prev,
                      onDelete: () => p.deleteMeasurement(e.value.id),
                    );
                  }),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric tab bar ────────────────────────────────────────────────────────────
class _MetricTabBar extends StatelessWidget {
  final int      selected;
  final ValueChanged<int> onSelect;
  final List<BodyMeasurement> measurements;

  const _MetricTabBar({
    required this.selected,
    required this.onSelect,
    required this.measurements,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _metrics.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final m      = _metrics[i];
        final active = i == selected;
        // Only show tab if at least one measurement has this value
        final hasData = measurements.any((e) => m.value(e) != null);
        if (!hasData) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? m.color.withValues(alpha: 0.18)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? m.color.withValues(alpha: 0.55)
                    : AppColors.divider.withValues(alpha: 0.20),
              ),
            ),
            child: Text(m.label,
                style: GoogleFonts.inter(
                    color: active ? m.color : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ),
        );
      },
    ),
  );
}

// ── Trend chart ───────────────────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  final _Metric               metric;

  const _TrendChart({required this.measurements, required this.metric});

  @override
  Widget build(BuildContext context) {
    final pts = <_DateValue>[];
    for (final m in measurements) {
      final v = metric.value(m);
      if (v != null) pts.add(_DateValue(m.date, v));
    }
    if (pts.length < 2) return const SizedBox.shrink();

    final spots = pts.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final vals  = pts.map((p) => p.value);
    final minY  = (vals.reduce((a, b) => a < b ? a : b) * 0.97).floorToDouble();
    final maxY  = (vals.reduce((a, b) => a > b ? a : b) * 1.03).ceilToDouble();

    final first = pts.first.value;
    final last  = pts.last.value;
    final delta = last - first;
    final isGain = delta >= 0;

    // Weight: loss = good (green), gain = red. Other measurements: gain = good.
    final isWeight = metric.label == 'Weight';
    final deltaGood = isWeight ? !isGain : isGain;
    final deltaColor = delta.abs() < 0.1
        ? AppColors.textMuted
        : (deltaGood ? AppColors.green : AppColors.red);

    final sign = delta >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: metric.color.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metric.label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text('${last % 1 == 0 ? last.toInt() : last.toStringAsFixed(1)} ${metric.unit}',
                style: GoogleFonts.rajdhani(
                    color: metric.color,
                    fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              delta.abs() < 0.1
                  ? 'No change'
                  : '$sign${delta.toStringAsFixed(1)} ${metric.unit}',
              style: GoogleFonts.inter(
                  color: deltaColor,
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Chart
        SizedBox(
          height: 150,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider.withValues(alpha: 0.35),
                      strokeWidth: 0.5)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles:  const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 38,
                getTitlesWidget: (v, _) => Text(
                  v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 9)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  // Show only first and last
                  if (i != 0 && i != pts.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final parts = pts[i].date.split('-');
                  final label = parts.length == 3
                      ? '${parts[2]}/${parts[1]}'
                      : pts[i].date;
                  return Text(label,
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 9));
                },
              )),
            ),
            lineBarsData: [
              LineChartBarData(
                spots:          spots,
                isCurved:       true,
                curveSmoothness: 0.35,
                color:          metric.color,
                barWidth:       2.2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, i) {
                    final isLast = i == spots.length - 1;
                    return FlDotCirclePainter(
                      radius: isLast ? 4.5 : 2.5,
                      color: isLast ? metric.color : metric.color.withValues(alpha: 0.6),
                      strokeColor: AppColors.bg,
                      strokeWidth: isLast ? 1.5 : 1,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      metric.color.withValues(alpha: 0.18),
                      metric.color.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}

class _DateValue {
  final String date;
  final double value;
  const _DateValue(this.date, this.value);
}

// ── Log form ──────────────────────────────────────────────────────────────────
class _LogForm extends StatelessWidget {
  final TextEditingController chestCtrl, waistCtrl, hipsCtrl,
      leftArmCtrl, rightArmCtrl, weightCtrl, notesCtrl;
  final VoidCallback onSave;

  const _LogForm({
    required this.chestCtrl,   required this.waistCtrl,
    required this.hipsCtrl,    required this.leftArmCtrl,
    required this.rightArmCtrl,required this.weightCtrl,
    required this.notesCtrl,   required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.20), width: 0.8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LOG TODAY',
          style: GoogleFonts.inter(
              color: AppColors.gold,
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
      const SizedBox(height: 14),
      _row([
        _Field('Weight (kg)', weightCtrl),
        _Field('Chest (cm)',  chestCtrl),
      ]),
      const SizedBox(height: 10),
      _row([
        _Field('Waist (cm)', waistCtrl),
        _Field('Hips (cm)',  hipsCtrl),
      ]),
      const SizedBox(height: 10),
      _row([
        _Field('Left Arm (cm)',  leftArmCtrl),
        _Field('Right Arm (cm)', rightArmCtrl),
      ]),
      const SizedBox(height: 10),
      _Field('Notes (optional)', notesCtrl, done: true),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text('Save Measurements',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    ]),
  );

  Widget _row(List<Widget> children) => Row(
    children: children
        .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
        .toList()
      ..removeLast(),
  );
}

class _Field extends StatelessWidget {
  final String hint;
  final TextEditingController ctrl;
  final bool done;
  const _Field(this.hint, this.ctrl, {this.done = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: done ? TextInputAction.done : TextInputAction.next,
    style: GoogleFonts.inter(
        color: AppColors.textPrimary, fontSize: 13.5),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: AppColors.textMuted, fontSize: 12.5),
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.30),
              width: 0.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: AppColors.gold, width: 1)),
    ),
  );
}

// ── History card ──────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final BodyMeasurement  current;
  final BodyMeasurement? previous;
  final VoidCallback     onDelete;

  const _HistoryCard({
    required this.current,
    required this.previous,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = current;
    final p = previous;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.18), width: 0.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date + delete
        Row(children: [
          Text(m.date,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.40), size: 18),
          ),
        ]),
        const SizedBox(height: 10),

        // Measurement chips
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (m.weightKg    != null) _Chip('Weight',    m.weightKg!,    'kg', p?.weightKg,    isWeight: true),
          if (m.chestCm     != null) _Chip('Chest',     m.chestCm!,     'cm', p?.chestCm),
          if (m.waistCm     != null) _Chip('Waist',     m.waistCm!,     'cm', p?.waistCm,     isWaist: true),
          if (m.hipsCm      != null) _Chip('Hips',      m.hipsCm!,      'cm', p?.hipsCm),
          if (m.leftArmCm   != null) _Chip('L Arm',     m.leftArmCm!,   'cm', p?.leftArmCm),
          if (m.rightArmCm  != null) _Chip('R Arm',     m.rightArmCm!,  'cm', p?.rightArmCm),
        ]),

        if (m.notes != null) ...[
          const SizedBox(height: 8),
          Text(m.notes!,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String  label;
  final double  value;
  final String  unit;
  final double? prev;
  final bool    isWeight;
  final bool    isWaist;

  const _Chip(this.label, this.value, this.unit, this.prev,
      {this.isWeight = false, this.isWaist = false});

  @override
  Widget build(BuildContext context) {
    final delta = (prev != null) ? value - prev! : null;

    // For weight/waist: decrease = good. For everything else: increase = good.
    Color? deltaColor;
    String deltaStr = '';
    if (delta != null && delta.abs() >= 0.1) {
      final good = (isWeight || isWaist) ? delta < 0 : delta > 0;
      deltaColor = good ? AppColors.green : AppColors.red;
      deltaStr   = '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
    }

    final valStr = value % 1 == 0
        ? '${value.toInt()} $unit'
        : '${value.toStringAsFixed(1)} $unit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(valStr,
              style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w800)),
          if (deltaStr.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(deltaStr,
                style: GoogleFonts.inter(
                    color: deltaColor,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.straighten_rounded,
            color: AppColors.textMuted.withValues(alpha: 0.25), size: 52),
        const SizedBox(height: 14),
        Text('No measurements yet',
            style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Log your first entry above\nto start tracking your transformation.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}
