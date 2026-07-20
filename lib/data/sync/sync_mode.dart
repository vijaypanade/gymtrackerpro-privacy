/// Controls whether the sync engine is active and at what audience level.
///
/// The mode is stored in Hive settings and read at startup. It can only be
/// advanced by an authorised deployment (server-side feature flag or
/// direct developer override in debug builds) — the app never promotes its
/// own sync_mode at runtime.
///
/// Lifecycle:
///   disabled  → internal  (developer / CI testing)
///   internal  → beta      (controlled rollout)
///   beta      → production (full release)
///
/// RFC-002.1 ships with sync_mode = SyncMode.disabled.
/// The outbox and sync engine are wired but entirely dormant at this level.
enum SyncMode {
  /// Sync engine is fully off. No Firestore writes are attempted.
  /// Outbox accepts enqueues but the flush loop never runs.
  /// This is the shipped state for RFC-002.1.
  disabled,

  /// Active for internal developer builds only.
  /// Flush runs against the Firebase project used for testing.
  internal,

  /// Active for a controlled external beta audience.
  beta,

  /// Active for all users.
  production;

  /// Whether the sync engine should attempt Firestore flushes.
  bool get isActive => this != SyncMode.disabled;

  /// Deserialise from a stored string, defaulting to [disabled] on
  /// unknown values. Safe across enum additions.
  static SyncMode fromString(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => disabled);
}
