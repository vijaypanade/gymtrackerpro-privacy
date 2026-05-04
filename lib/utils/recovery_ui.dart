import 'package:flutter/material.dart';

class RecoveryUI {
  static Color getColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}