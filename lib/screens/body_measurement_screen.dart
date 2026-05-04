// lib/screens/body_measurement_screen.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';

class BodyMeasurementScreen extends StatefulWidget {
  const BodyMeasurementScreen({super.key});

  @override
  State<BodyMeasurementScreen> createState() => _BodyMeasurementScreenState();
}

class _BodyMeasurementScreenState extends State<BodyMeasurementScreen> {
  final _chestCtrl   = TextEditingController();
  final _waistCtrl   = TextEditingController();
  final _hipsCtrl    = TextEditingController();
  final _leftArmCtrl = TextEditingController();
  final _rightArmCtrl= TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _notesCtrl   = TextEditingController();

  @override
  void dispose() {
    for (final c in [_chestCtrl,_waistCtrl,_hipsCtrl,_leftArmCtrl,_rightArmCtrl,_weightCtrl,_notesCtrl]) c.dispose();
    super.dispose();
  }

  void _save(AppProvider p) {
    final m = BodyMeasurement(
      id: const Uuid().v4(),
      date: DateTime.now().toIso8601String().substring(0, 10),
      chestCm:    double.tryParse(_chestCtrl.text),
      waistCm:    double.tryParse(_waistCtrl.text),
      hipsCm:     double.tryParse(_hipsCtrl.text),
      leftArmCm:  double.tryParse(_leftArmCtrl.text),
      rightArmCm: double.tryParse(_rightArmCtrl.text),
      weightKg:   double.tryParse(_weightCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    p.addMeasurement(m);
    for (final c in [_chestCtrl,_waistCtrl,_hipsCtrl,_leftArmCtrl,_rightArmCtrl,_weightCtrl,_notesCtrl]) c.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Measurements saved! 📏', style: TextStyle(fontFamily: 'Inter',)),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Body Measurements 📏', style: TextStyle(fontFamily: 'Rajdhani',fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LOG FORM
          GoldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Today\'s Measurements', style: TextStyle(fontFamily: 'Rajdhani',
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold,
                )),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _field('Chest (cm)', _chestCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Waist (cm)', _waistCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Hips (cm)', _hipsCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Weight (kg)', _weightCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Left Arm (cm)', _leftArmCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Right Arm (cm)', _rightArmCtrl)),
                ]),
                const SizedBox(height: 12),
                _field('Notes (optional)', _notesCtrl),
                const SizedBox(height: 16),
                GoldButton(
                  text: 'Save Measurements',
                  icon: Icons.save_rounded,
                  width: double.infinity,
                  onTap: () => _save(p),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // HISTORY
          if (p.measurements.isNotEmpty) ...[
            const SectionHeader(title: 'MEASUREMENT HISTORY'),
            const SizedBox(height: 8),
            ...p.measurements.map((m) => _MeasurementCard(
              measurement: m,
              onDelete: () => p.deleteMeasurement(m.id),
            )),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('📏', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('No measurements yet', style: TextStyle(fontFamily: 'Rajdhani',
                      color: AppColors.textMuted, fontSize: 16,
                    )),
                    Text('Track your body changes over time', style: TextStyle(fontFamily: 'Inter',
                      color: AppColors.textMuted, fontSize: 12,
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.bgCardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1),
        ),
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final BodyMeasurement measurement;
  final VoidCallback onDelete;

  const _MeasurementCard({required this.measurement, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.date, style: TextStyle(fontFamily: 'Inter',
                color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700,
              )),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (m.weightKg != null)   _chip('⚖️ ${m.weightKg}kg'),
              if (m.chestCm != null)    _chip('Chest: ${m.chestCm}cm'),
              if (m.waistCm != null)    _chip('Waist: ${m.waistCm}cm'),
              if (m.hipsCm != null)     _chip('Hips: ${m.hipsCm}cm'),
              if (m.leftArmCm != null)  _chip('L.Arm: ${m.leftArmCm}cm'),
              if (m.rightArmCm != null) _chip('R.Arm: ${m.rightArmCm}cm'),
            ],
          ),
          if (m.notes != null && m.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.notes!, style: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) => Text(text, style: TextStyle(fontFamily: 'Inter',
    color: AppColors.textSecondary, fontSize: 12,
  ));
}
