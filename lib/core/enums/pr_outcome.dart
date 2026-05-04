// lib/core/enums/pr_outcome.dart
// ══════════════════════════════════════════════════════════
// SINGLE SOURCE OF TRUTH — replaces duplicate enums in:
//   - app_provider.dart  (had 4 values, missing repPR/volumePR)
//   - pr_service.dart    (had 6 values, different order)
// ALL files must import from here only.
// ══════════════════════════════════════════════════════════

enum PROutcome {
  first,    // First ever log — always a win
  pr,       // Weight PR — heavier than ever
  repPR,    // Same weight, more reps
  volumePR, // Total volume (weight × reps) exceeded previous best
  match,    // Exactly matched previous best
  drop,     // Below previous best
}

extension PROutcomeX on PROutcome {
  bool get isPR    => this == PROutcome.pr    ||
                      this == PROutcome.first ||
                      this == PROutcome.repPR ||
                      this == PROutcome.volumePR;
  bool get isFirst  => this == PROutcome.first;
  bool get isMatch  => this == PROutcome.match;
  bool get isDrop   => this == PROutcome.drop;
  bool get isRepPR  => this == PROutcome.repPR;

  String get uxMessage {
    switch (this) {
      case PROutcome.first:    return '🎉 First rep logged! Every journey starts here.';
      case PROutcome.pr:       return '🔥 New weight PR! You\'re getting stronger.';
      case PROutcome.repPR:    return '💥 Rep PR! Same weight, more reps — progression!';
      case PROutcome.volumePR: return '📈 Volume PR! Best total work output ever.';
      case PROutcome.match:    return '💪 Matched your best. Push for +1 next time.';
      case PROutcome.drop:     return '📊 Below best — recovery matters. Come back stronger.';
    }
  }

  String get label {
    switch (this) {
      case PROutcome.first:    return 'FIRST 🎉';
      case PROutcome.pr:       return 'PR 🔥';
      case PROutcome.repPR:    return 'REP PR 💥';
      case PROutcome.volumePR: return 'VOLUME PR 📈';
      case PROutcome.match:    return 'MATCHED 💪';
      case PROutcome.drop:     return 'DROP 📉';
    }
  }
}
