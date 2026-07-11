// lib/brain/models/environment_context.dart
//
// Immutable container for environment-specific values needed by AthleteBrain.
// This object is intentionally small and compositional and does not contain
// any business logic or policy decisions.

class EnvironmentContext {
  final DateTime now;

  const EnvironmentContext({
    required this.now,
  });
}
