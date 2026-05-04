class AITrainer {

  /// 🔥 MAIN FUNCTION
  static String getTodaySuggestion({
    required List<String> lastWorkouts,
    required String todayPlan,
  }) {

    // 🧠 1. If no history
    if (lastWorkouts.isEmpty) {
      return "Start your fitness journey today 💪";
    }

    final last = lastWorkouts.last.toLowerCase();

    // 🧠 2. If same muscle repeated
    if (last.contains(todayPlan.toLowerCase())) {
      return "You trained $todayPlan recently, go lighter today ⚡";
    }

    // 🧠 3. Missed workout detection
    if (_isSkipped(lastWorkouts, todayPlan)) {
      return "You missed $todayPlan, let's hit it today 🔥";
    }

    // 🧠 4. Fatigue logic
    if (_isFatigued(lastWorkouts)) {
      return "Take it easy today, focus on form 🧘";
    }

    // 🧠 5. Default
    return "Train $todayPlan today 🔥";
  }

  /// 🔥 MISSED WORKOUT LOGIC
  static bool _isSkipped(List<String> history, String today) {
    final recent = history.take(3).toList();
    return !recent.any((w) => w.toLowerCase().contains(today.toLowerCase()));
  }

  /// 🔥 FATIGUE DETECTION
  static bool _isFatigued(List<String> history) {
    if (history.length < 3) return false;

    final last3 = history.reversed.take(3).toList();

    return last3.every((w) =>
        w.toLowerCase().contains("push") ||
        w.toLowerCase().contains("pull") ||
        w.toLowerCase().contains("legs"));
  }
}