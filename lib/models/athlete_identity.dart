// lib/models/athlete_identity.dart
// Athlete identity stage — derived from observed training history.
// Communicated subtly through AI copy, never shouted at the user.

enum AthleteIdentityStage {
  beginner,    // 0–7 workouts
  developing,  // 8–25
  consistent,  // 26–60
  disciplined, // 61–150
  elite,       // 150+ + high consistency
}

extension AthleteIdentityStageX on AthleteIdentityStage {
  static AthleteIdentityStage from({
    required int totalWorkouts,
    required int consistencyScore,
  }) {
    if (totalWorkouts < 8)   return AthleteIdentityStage.beginner;
    if (totalWorkouts < 26)  return AthleteIdentityStage.developing;
    if (totalWorkouts < 61)  return AthleteIdentityStage.consistent;
    if (totalWorkouts < 151) return AthleteIdentityStage.disciplined;
    if (consistencyScore >= 75) return AthleteIdentityStage.elite;
    return AthleteIdentityStage.disciplined;
  }

  // Short internal label — used in coach framing, not shown raw to user.
  String get label {
    switch (this) {
      case AthleteIdentityStage.beginner:    return 'building foundation';
      case AthleteIdentityStage.developing:  return 'developing consistency';
      case AthleteIdentityStage.consistent:  return 'consistency phase';
      case AthleteIdentityStage.disciplined: return 'disciplined training';
      case AthleteIdentityStage.elite:       return 'elite consistency';
    }
  }

  // Framing prefix the AI uses to reinforce identity without being cringe.
  // Returns empty string if no identity reinforcement is warranted.
  String identityFrame(int totalWorkouts) {
    switch (this) {
      case AthleteIdentityStage.beginner:
        return totalWorkouts >= 4
            ? 'Foundation phase: '
            : '';
      case AthleteIdentityStage.developing:
        return totalWorkouts % 5 == 0
            ? 'Consistency phase is stabilizing. '
            : '';
      case AthleteIdentityStage.consistent:
        return 'Your training discipline is building reliability. ';
      case AthleteIdentityStage.disciplined:
        return 'Disciplined athletes protect momentum first. ';
      case AthleteIdentityStage.elite:
        return 'Elite training patterns require precision, not volume. ';
    }
  }

  // Coach context tag for message routing.
  String get coachTag {
    switch (this) {
      case AthleteIdentityStage.beginner:    return 'beginner';
      case AthleteIdentityStage.developing:  return 'developing';
      case AthleteIdentityStage.consistent:  return 'consistent';
      case AthleteIdentityStage.disciplined: return 'disciplined';
      case AthleteIdentityStage.elite:       return 'elite';
    }
  }

  bool get isEarlyPhase =>
      this == AthleteIdentityStage.beginner ||
      this == AthleteIdentityStage.developing;

  bool get isAdvanced =>
      this == AthleteIdentityStage.disciplined ||
      this == AthleteIdentityStage.elite;
}
