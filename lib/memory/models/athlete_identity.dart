// lib/memory/models/athlete_identity.dart

/// Immutable athlete identity characteristics.
///
/// This model is part of the AthleteMemory layer and stores
/// long-term, identity-focused data only.
class AthleteIdentity {
  final String athleteId;
  final String preferredName;
  final String primaryGoal;
  final String trainingExperience;
  final String preferredSessionStyle;

  const AthleteIdentity({
    required this.athleteId,
    required this.preferredName,
    required this.primaryGoal,
    required this.trainingExperience,
    required this.preferredSessionStyle,
  });
}
