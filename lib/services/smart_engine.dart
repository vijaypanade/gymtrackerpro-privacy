class SmartEngine {

  static String decideWorkout({
    required String lastWorkout,
    required int missedDays,
    required Map<String, int> muscleData,
  }) {

    // ❌ missed workout → easy start
    if (missedDays >= 2) return "fullbody";

    // 🔁 rotation
    if (lastWorkout == "push") return "pull";
    if (lastWorkout == "pull") return "legs";
    if (lastWorkout == "legs") return "push";

    // ⚖️ imbalance
    if (muscleData.isNotEmpty) {
      final sorted = muscleData.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      return sorted.first.key.toLowerCase();
    }

    return "push";
  }
}