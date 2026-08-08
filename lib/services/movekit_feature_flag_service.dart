import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Emergency kill switch for MoveKit demo loops.
///
/// RFC-005 §19.3 item 1. LiftOn is already live on the Play Store, so once a
/// build ships, reverting source code no longer reaches an installed app. This
/// flag is the only rollback that does: flipping it off in the Firebase console
/// stops MoveKit loops for every user within one Remote Config fetch, with no
/// app update and no user action.
///
/// ## Default OFF is intentional
///
/// [isEnabled] is `false` from construction and stays `false` until a Remote
/// Config fetch explicitly says otherwise. This is a deliberate departure from
/// `AiQuotaService`, which defaults its `ai_enabled` flag to **on** so that a
/// Remote Config outage cannot take away a feature users already rely on.
///
/// MoveKit is the opposite case: it is new, it costs Firebase Storage egress,
/// and it is under licence. **Fail closed.** Every failure path below —
/// unavailable Remote Config, network failure, timeout, or any unexpected
/// exception — leaves MoveKit disabled, and users fall back to the existing
/// YouTube demo flow, which this feature never removes (RFC-005 §9.3).
///
/// Nothing here touches the catalog, the planner, or any UI: this service only
/// answers "is the feature switched on?".
class MoveKitFeatureFlagService {
  MoveKitFeatureFlagService._();

  static final MoveKitFeatureFlagService instance =
      MoveKitFeatureFlagService._();

  /// Remote Config parameter name. Must match the key created in the Firebase
  /// console; until that parameter exists, the local default keeps loops off.
  static const String _key = 'movekit_loops_enabled';

  /// Matches the fetch timeout used by `AiQuotaService`, so a slow network
  /// degrades consistently across the app.
  static const Duration _timeout = Duration(seconds: 4);

  bool _enabled = false;
  bool _initialized = false;
  Future<void>? _inFlight;

  /// Whether MoveKit demo loops are switched on.
  ///
  /// `false` before [init] completes, and `false` after any failure. Callers
  /// need no null handling and no "unknown" state.
  bool get isEnabled => _enabled;

  /// Syncs the flag once. Idempotent, and safe to call concurrently —
  /// overlapping calls await the same fetch.
  ///
  /// Never throws: a failure is reported through [debugPrint] and leaves the
  /// flag off. Use [refresh] to re-sync later, including after a failed [init].
  Future<void> init() {
    if (_initialized) return Future<void>.value();
    return _inFlight ??= _sync().whenComplete(() {
      _initialized = true;
      _inFlight = null;
    });
  }

  /// Re-reads the flag from Remote Config.
  ///
  /// Intended for an app-resume hook, so a console change can take effect
  /// without a restart. Wiring that hook up is a later step; this method is the
  /// seam it will call.
  Future<void> refresh() => _sync();

  Future<void> _sync() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(const <String, dynamic>{_key: false});
      await rc.fetchAndActivate().timeout(_timeout);
      _enabled = rc.getBool(_key);
    } catch (error) {
      // Fail closed. The flag is not left at a previously fetched value:
      // if we cannot confirm the feature should be on, it is off.
      _enabled = false;
      debugPrint('[MoveKitFlag] Remote Config sync failed: $error '
          '— MoveKit loops remain DISABLED');
    }
  }
}
