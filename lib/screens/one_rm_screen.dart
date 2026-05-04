// lib/screens/one_rm_screen.dart
import 'package:flutter/material.dart';

import '../utils/app_constants.dart';
import '../widgets/shared_widgets.dart';

class OneRmScreen extends StatefulWidget {
  const OneRmScreen({super.key});

  @override
  State<OneRmScreen> createState() => _OneRmScreenState();
}

class _OneRmScreenState extends State<OneRmScreen> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl   = TextEditingController();
  double? _oneRm;

  void _calculate() {
    final weight = double.tryParse(_weightCtrl.text);
    final reps   = int.tryParse(_repsCtrl.text);

    if (weight == null || reps == null || reps <= 0) return;

    // Epley formula: 1RM = weight × (1 + reps/30)
    final result = weight * (1 + reps / 30);
    setState(() => _oneRm = result);
  }

  // Percentage chart for training zones
  static const _zones = [
    {'pct': 100, 'label': '1RM — Max Strength', 'reps': '1',   'color': 0xFFEF4444},
    {'pct': 95,  'label': '95% — Near Max',      'reps': '2',   'color': 0xFFF97316},
    {'pct': 90,  'label': '90% — Strength',       'reps': '3',   'color': 0xFFEAB308},
    {'pct': 85,  'label': '85% — Strength/Hyp',   'reps': '5',   'color': 0xFFD4AF37},
    {'pct': 80,  'label': '80% — Hypertrophy',    'reps': '8',   'color': 0xFF22C55E},
    {'pct': 75,  'label': '75% — Hypertrophy',    'reps': '10',  'color': 0xFF3B82F6},
    {'pct': 70,  'label': '70% — Endurance',      'reps': '12',  'color': 0xFF8B5CF6},
    {'pct': 65,  'label': '65% — Endurance',      'reps': '15',  'color': 0xFF6B7280},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('1RM Calculator 🏆', style: TextStyle(fontFamily: 'Rajdhani',fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calculate Your 1 Rep Max', style: TextStyle(fontFamily: 'Rajdhani',
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold,
                )),
                const SizedBox(height: 4),
                Text('Using Epley Formula: weight × (1 + reps/30)', style: TextStyle(fontFamily: 'Inter',
                  fontSize: 11, color: AppColors.textMuted,
                )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _field('Weight (kg)', _weightCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Reps done', _repsCtrl, isInt: true)),
                  ],
                ),
                const SizedBox(height: 16),
                GoldButton(
                  text: 'Calculate 1RM',
                  icon: Icons.calculate_rounded,
                  width: double.infinity,
                  onTap: _calculate,
                ),
                if (_oneRm != null) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Text('Your Estimated 1RM', style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textMuted, fontSize: 12,
                        )),
                        const SizedBox(height: 4),
                        Text('${_oneRm!.toStringAsFixed(1)} kg', style: TextStyle(fontFamily: 'Rajdhani',
                          color: AppColors.gold, fontSize: 40, fontWeight: FontWeight.w800,
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_oneRm != null) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'TRAINING ZONES'),
            const SizedBox(height: 8),
            ..._zones.map((z) {
              final pct = z['pct'] as int;
              final weight = _oneRm! * pct / 100;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(z['color'] as int).withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(z['color'] as int).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text('$pct%', style: TextStyle(fontFamily: 'Rajdhani',
                        color: Color(z['color'] as int), fontSize: 14, fontWeight: FontWeight.w800,
                      ))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(z['label'] as String, style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                        )),
                        Text('~${z['reps']} reps', style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.textMuted, fontSize: 11,
                        )),
                      ],
                    )),
                    Text('${weight.toStringAsFixed(1)} kg', style: TextStyle(fontFamily: 'Rajdhani',
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl, {bool isInt = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontFamily: 'Inter',color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Inter',color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.bgCardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
    );
  }
}
