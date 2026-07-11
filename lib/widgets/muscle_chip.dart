// lib/widgets/muscle_chip.dart — v3.0 Premium
// Fixed: equal size, no overflow, premium dark gold aesthetic
import 'package:flutter/material.dart';

import '../utils/recovery_ui.dart';

// ═══════════════════════════════════════════════════════════════
// RECOVERY MUSCLE CHIP — fixed 1:1 square, no overflow ever
// ═══════════════════════════════════════════════════════════════
class RecoveryMuscleChip extends StatelessWidget {
  final String muscle;
  final int score;
  final String emoji;

  const RecoveryMuscleChip({
    super.key,
    required this.muscle,
    required this.score,
    required this.emoji,
  });

  static String _statusLabel(int score) {
    if (score >= 80) return 'READY';
    if (score >= 50) return 'RECOVER';
    return 'REST';
  }

  static String _tooltipMsg(int score) {
    if (score >= 80) return 'Fully recovered — train hard 💪';
    if (score >= 50) return 'Recovering — use moderate load';
    return 'Recently trained — take rest ⚠️';
  }

  // Normalise long names to fit one line
  static String _shortName(String muscle) {
    final m = muscle.toLowerCase();
    if (m == 'shoulders') return 'SHOULDER';
    return muscle.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color  = RecoveryUI.getColor(score);
    final label  = _statusLabel(score);
    final isRest = score < 50;

    return Tooltip(
      message: _tooltipMsg(score),
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      textStyle: const TextStyle(fontFamily: 'Inter',color: Colors.white70, fontSize: 11),
      child: Container(
        // ── CRITICAL: fixed aspect, no expansion from text ──
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isRest ? 0.14 : 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isRest ? 0.55 : 0.28),
            width: isRest ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isRest ? 0.18 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),

            // Muscle name — NEVER wraps
            Text(
              _shortName(muscle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),

            // Score
            Text(
              '$score%',
              maxLines: 1,
              style: TextStyle(fontFamily: 'Rajdhani',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),

            // Status label pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
