// lib/models/daily_mission.dart
// CoachMission — one adaptive mission per day. Generated from context — never generic.
// Tactical, specific, identity-aligned. No gamification fluff.
// Named CoachMission to distinguish from the gamification DailyMission in models.dart.

enum CoachMissionType {
  consistency, // Show up and complete the session
  recovery,    // Protect recovery — shorter, lower intensity
  strength,    // Target a specific compound or muscle
  volume,      // Maintain or increase volume with control
  habit,       // Minimum viable session — streak protection
}

class CoachMission {
  final String           title;
  final String           description;
  final CoachMissionType type;
  final int              targetSets;    // 0 = unspecified
  final String           muscleTarget;  // '' = unspecified

  const CoachMission({
    required this.title,
    required this.description,
    required this.type,
    this.targetSets   = 0,
    this.muscleTarget = '',
  });

  static const CoachMission fallback = CoachMission(
    title:       'Complete today\'s session.',
    description: 'Consistency compounds over time.',
    type:        CoachMissionType.consistency,
  );

  String get typeTag {
    switch (type) {
      case CoachMissionType.consistency: return 'CONSISTENCY';
      case CoachMissionType.recovery:    return 'RECOVERY';
      case CoachMissionType.strength:    return 'STRENGTH';
      case CoachMissionType.volume:      return 'VOLUME';
      case CoachMissionType.habit:       return 'HABIT';
    }
  }

  Map<String, dynamic> toJson() => {
    'title':        title,
    'description':  description,
    'type':         type.name,
    'targetSets':   targetSets,
    'muscleTarget': muscleTarget,
  };

  factory CoachMission.fromJson(Map<String, dynamic> j) => CoachMission(
    title:        j['title']        as String? ?? fallback.title,
    description:  j['description']  as String? ?? fallback.description,
    type: CoachMissionType.values.firstWhere(
      (t) => t.name == (j['type'] as String? ?? ''),
      orElse: () => CoachMissionType.consistency,
    ),
    targetSets:   j['targetSets']   as int? ?? 0,
    muscleTarget: j['muscleTarget'] as String? ?? '',
  );
}
