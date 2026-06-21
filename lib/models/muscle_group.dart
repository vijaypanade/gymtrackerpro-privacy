// lib/models/muscle_group.dart
// Canonical enum for every individually-rendered muscle layer.
// Each value maps to one SVG asset, one score key, and one view side.

enum MuscleGroup {
  // ── Front view ─────────────────────────────────────────────────────────────
  pecs,        // chest
  frontDelts,  // anterior deltoid caps
  biceps,      // biceps brachii
  abs,         // rectus abdominis / core
  quads,       // quadriceps
  tibialis,    // tibialis anterior (shin)

  // ── Back view ──────────────────────────────────────────────────────────────
  traps,       // trapezius
  rearDelts,   // posterior deltoid caps
  lats,        // latissimus dorsi
  triceps,     // triceps brachii
  glutes,      // gluteus maximus
  hamstrings,  // biceps femoris / semitendinosus
  calves,      // gastrocnemius
}

extension MuscleGroupX on MuscleGroup {
  // Which side of the body this muscle belongs to.
  bool get isFrontView => switch (this) {
    MuscleGroup.pecs       ||
    MuscleGroup.frontDelts ||
    MuscleGroup.biceps     ||
    MuscleGroup.abs        ||
    MuscleGroup.quads      ||
    MuscleGroup.tibialis   => true,
    _                      => false,
  };

  // Maps to the score key in the existing Map<String, double> scores data.
  String get scoreKey => switch (this) {
    MuscleGroup.pecs       => 'chest',
    MuscleGroup.frontDelts => 'shoulders',
    MuscleGroup.biceps     => 'arms',
    MuscleGroup.abs        => 'core',
    MuscleGroup.quads      => 'legs',
    MuscleGroup.tibialis   => 'legs',
    MuscleGroup.traps      => 'back',
    MuscleGroup.rearDelts  => 'shoulders',
    MuscleGroup.lats       => 'back',
    MuscleGroup.triceps    => 'arms',
    MuscleGroup.glutes     => 'legs',
    MuscleGroup.hamstrings => 'legs',
    MuscleGroup.calves     => 'legs',
  };

  String get displayName => switch (this) {
    MuscleGroup.pecs       => 'Chest',
    MuscleGroup.frontDelts => 'Shoulders',
    MuscleGroup.biceps     => 'Biceps',
    MuscleGroup.abs        => 'Core',
    MuscleGroup.quads      => 'Quads',
    MuscleGroup.tibialis   => 'Shins',
    MuscleGroup.traps      => 'Traps',
    MuscleGroup.rearDelts  => 'Rear Delts',
    MuscleGroup.lats       => 'Lats',
    MuscleGroup.triceps    => 'Triceps',
    MuscleGroup.glutes     => 'Glutes',
    MuscleGroup.hamstrings => 'Hamstrings',
    MuscleGroup.calves     => 'Calves',
  };

  String get assetPath => switch (this) {
    MuscleGroup.pecs       => 'assets/body/muscles/front/pecs.svg',
    MuscleGroup.frontDelts => 'assets/body/muscles/front/front_delts.svg',
    MuscleGroup.biceps     => 'assets/body/muscles/front/biceps.svg',
    MuscleGroup.abs        => 'assets/body/muscles/front/abs.svg',
    MuscleGroup.quads      => 'assets/body/muscles/front/quads.svg',
    MuscleGroup.tibialis   => 'assets/body/muscles/front/tibialis.svg',
    MuscleGroup.traps      => 'assets/body/muscles/back/traps.svg',
    MuscleGroup.rearDelts  => 'assets/body/muscles/back/rear_delts.svg',
    MuscleGroup.lats       => 'assets/body/muscles/back/lats.svg',
    MuscleGroup.triceps    => 'assets/body/muscles/back/triceps.svg',
    MuscleGroup.glutes     => 'assets/body/muscles/back/glutes.svg',
    MuscleGroup.hamstrings => 'assets/body/muscles/back/hamstrings.svg',
    MuscleGroup.calves     => 'assets/body/muscles/back/calves.svg',
  };
}

// Ordered lists used to iterate over muscles per view.
const List<MuscleGroup> frontMuscleGroups = [
  MuscleGroup.quads,       // draw large muscles first (painter's algorithm)
  MuscleGroup.abs,
  MuscleGroup.pecs,
  MuscleGroup.biceps,
  MuscleGroup.frontDelts,
  MuscleGroup.tibialis,
];

const List<MuscleGroup> backMuscleGroups = [
  MuscleGroup.hamstrings,
  MuscleGroup.glutes,
  MuscleGroup.lats,
  MuscleGroup.triceps,
  MuscleGroup.traps,
  MuscleGroup.rearDelts,
  MuscleGroup.calves,
];
