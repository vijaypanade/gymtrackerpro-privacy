// lib/brain/models/biometric_context.dart
//
// Carries raw biometric readings through the AthleteBrain pipeline.
// Used post-compute to prepend a biometric-specific prefix to the
// athlete-facing coaching message. Advisory only — never alters safety signals.

enum BiometricSignal { hrv, rhr, sleep, none }

class BiometricContext {
  final double? hrv;
  final double? hrvBaseline;
  final double? rhr;
  final double  sleepHours;
  final bool    hasHrv;
  final bool    hasRhr;
  final bool    hasSleep;

  const BiometricContext({
    required this.sleepHours,
    required this.hasHrv,
    required this.hasRhr,
    required this.hasSleep,
    this.hrv,
    this.hrvBaseline,
    this.rhr,
  });

  // Returns the signal most responsible for recovery suppression, or none.
  // Penalty thresholds mirror RecoveryEngine modifier magnitudes without
  // importing or duplicating the engine.
  BiometricSignal get primarySignal {
    double hrvPenalty   = 0;
    double rhrPenalty   = 0;
    double sleepPenalty = 0;

    if (hasHrv && hrv != null && hrv! > 0) {
      if (hrvBaseline != null && hrvBaseline! > 0) {
        final pct = (hrv! - hrvBaseline!) / hrvBaseline!;
        if (pct < -0.25)      hrvPenalty = 12;
        else if (pct < -0.15) hrvPenalty = 8;
        else if (pct < -0.05) hrvPenalty = 5;
      }
    }

    if (hasRhr && rhr != null) {
      if (rhr! > 80)      rhrPenalty = 8;
      else if (rhr! > 70) rhrPenalty = 4;
    }

    if (hasSleep && sleepHours > 0) {
      if (sleepHours < 5)      sleepPenalty = 8;
      else if (sleepHours < 6) sleepPenalty = 5;
      else if (sleepHours < 7) sleepPenalty = 3;
    }

    if (hrvPenalty == 0 && rhrPenalty == 0 && sleepPenalty == 0) {
      return BiometricSignal.none;
    }
    if (hrvPenalty >= rhrPenalty && hrvPenalty >= sleepPenalty) {
      return BiometricSignal.hrv;
    }
    if (rhrPenalty >= sleepPenalty) return BiometricSignal.rhr;
    return BiometricSignal.sleep;
  }
}
