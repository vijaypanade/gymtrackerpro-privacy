// lib/services/billing_service.dart
// ══════════════════════════════════════════════════════════
// REAL BILLING — replaces fake SharedPreferences premium flag
// Uses: in_app_purchase (Google Play / App Store)
//
// SETUP STEPS:
// 1. Add to pubspec.yaml:  in_app_purchase: ^3.1.13
// 2. Add to AndroidManifest.xml:
//    <uses-permission android:name="com.android.vending.BILLING"/>
// 3. Create products in Play Console:
//    - premium_monthly    ₹150/month  (base plan)
//    - premium_yearly     ₹1499/year  (Save 17% — RECOMMENDED)
//    Both with 14-day free trial introductory pricing.
// ══════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'monetization_service.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// PRODUCT IDs — must match Play Console exactly
// ─────────────────────────────────────────────────────────
class BillingProducts {
  static const monthly = 'premium_monthly'; // ₹150/month

  static String get yearly =>
      Platform.isIOS ? 'premium_yearly_v2' : 'premium_yearly';

  static Set<String> get all => {monthly, yearly};
}

// ─────────────────────────────────────────────────────────
// BILLING STATE
// ─────────────────────────────────────────────────────────
enum BillingStatus { loading, available, unavailable, purchased, error, pendingVerification }

// Private — outcome of a single verifyPurchase Cloud Function call.
// gracePeriod: Google confirmed entitled but payment is pending renewal (grace window open).
enum _VerifyOutcome { granted, gracePeriod, pending, rejected }

// Carries the outcome plus the server-supplied expiry date string (YYYY-MM-DD).
class _VerifyResult {
  final _VerifyOutcome outcome;
  final String?        premiumExpiry;
  // User-facing explanation for a rejection. Null falls back to the generic
  // store-rejection text; set when the cause is actionable (e.g. the purchase
  // belongs to a different account and the user must switch back to it).
  final String?        rejectionMessage;
  const _VerifyResult(this.outcome, {this.premiumExpiry, this.rejectionMessage});
}

class BillingService extends ChangeNotifier with WidgetsBindingObserver {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const _keyPremium         = 'billing_premium_v3';
  static const _keyProductId       = 'billing_product_id_v3';
  static const _keyExpiry          = 'billing_expiry_v3';
  // Retained after grant so expired-expiry re-verification can call the CF without
  // requiring the user to re-open the paywall or make a new purchase.
  static const _keyPurchaseToken   = 'billing_purchase_token_v1';
  // Pending purchase JSON: {productId, purchaseToken, platform, pendingAt}.
  // Written before the CF call and cleared only after the store confirms.
  static const _keyPendingPurchase = 'billing_pending_purchase_v1';
  // Set only when a Cloud Function verification confirms the subscription with the
  // Play/App Store. Absent when billing keys come from the Firestore fast-path.
  // _loadCachedStatus() re-verifies with CF when this flag is absent/false, ensuring
  // a stale Firestore doc cannot permanently grant premium without Play Store backing.
  static const _keyCfConfirmed    = 'billing_cf_confirmed_v1';

  // UID-scoped keys — one account's purchase won't leak to another on same device
  String get _kPremium          { final u = _uid; return u != null ? '${_keyPremium}_$u'         : _keyPremium; }
  String get _kProductId        { final u = _uid; return u != null ? '${_keyProductId}_$u'       : _keyProductId; }
  String get _kExpiry           { final u = _uid; return u != null ? '${_keyExpiry}_$u'          : _keyExpiry; }
  String get _kPurchaseToken    { final u = _uid; return u != null ? '${_keyPurchaseToken}_$u'   : _keyPurchaseToken; }
  String get _kPendingPurchase  { final u = _uid; return u != null ? '${_keyPendingPurchase}_$u' : _keyPendingPurchase; }
  String get _kCfConfirmed      { final u = _uid; return u != null ? '${_keyCfConfirmed}_$u'     : _keyCfConfirmed; }
  String? get _uid => AuthService.instance.currentUser?.uid;

  // ── State ──────────────────────────────────────────────
  BillingStatus _status              = BillingStatus.loading;
  bool          _isPremium           = false;
  bool          _pendingVerification = false;
  bool          _verifying           = false; // prevents concurrent CF calls
  bool          _available           = false;
  String?       _activeProduct;
  String?       _error;
  Timer?        _retryTimer;
  // Completer used only during init() to await the first restore event batch.
  // Nulled immediately after use so subsequent stream events don't touch it.
  Completer<void>? _initRestoreCompleter;

  List<ProductDetails>   _products    = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<User?>? _authSub;

  // ── Public getters ─────────────────────────────────────
  BillingStatus get status                => _status;
  bool          get isPremium             => _isPremium;
  bool          get isPendingVerification => _pendingVerification;
  bool          get isAvailable           => _available;
  String?       get error                 => _error;
  String?       get activeProduct         => _activeProduct;
  List<ProductDetails> get products       => _products;

  // ─────────────────────────────────────────────────────────
  // INIT — call in main.dart before runApp
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      // Load cached state (instant UI — no network calls except Firestore cross-check)
      await _loadCachedStatus();

      // If a purchase is still awaiting store verification from a previous session,
      // retry now in the background so the user doesn't have to re-open the paywall.
      if (_pendingVerification) unawaited(_retryPendingVerification());

      // Subscribe to Firebase auth state changes AFTER the initial load so we
      // don't double-process the current user. skip(1) skips the immediate emission.
      // On sign-out  → reset all in-memory premium state.
      // On sign-in   → reload from the new user's UID-scoped SharedPrefs keys.
      _authSub = FirebaseAuth.instance.authStateChanges()
          .skip(1)
          .listen(_onAuthStateChanged);

      _available = await InAppPurchase.instance.isAvailable();
      if (!_available) {
        _status = BillingStatus.unavailable;
        notifyListeners();
        return;
      }

      _purchaseSub = InAppPurchase.instance.purchaseStream
          .listen(_onPurchaseUpdate, onError: _onPurchaseError);

      await _loadProducts();

      // Restore active subscriptions. Wait for the platform to deliver the first
      // event batch before init() returns so that _pendingVerification and
      // BillingStatus are settled before the UI renders. This eliminates the
      // race where Home renders as Free and Profile (opened moments later) shows
      // Premium because an async restore + CF grant completed in between.
      _initRestoreCompleter = Completer<void>();
      await InAppPurchase.instance.restorePurchases();
      await _initRestoreCompleter!.future
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      _initRestoreCompleter = null;

      if (_status == BillingStatus.loading) {
        _status = _pendingVerification
            ? BillingStatus.pendingVerification
            : BillingStatus.available;
      }
    } catch (e) {
      _status = BillingStatus.error;
      _error  = e.toString();
      debugPrint('BillingService.init error: $e');
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // LOAD PRODUCTS from Play Store
  // ─────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      BillingProducts.all,
    ).timeout(const Duration(seconds: 8), onTimeout: () {
      debugPrint('Product query timed out after 8s');
      return ProductDetailsResponse(productDetails: [], notFoundIDs: [], error: null);
    });
    if (response.error != null) debugPrint('Product query error: ${response.error}');
    _products = response.productDetails;
    debugPrint('Loaded ${_products.length} products: '
        '${_products.map((p) => "${p.id}=${p.price}").join(", ")}');
  }

  // ─────────────────────────────────────────────────────────
  // PURCHASE — called from UI
  // ─────────────────────────────────────────────────────────
  Future<void> purchase(String productId) async {
    if (!_available) throw Exception('Payment is not available on this device.');
    if (_products.isEmpty) {
      throw Exception(
        'Subscription products are not configured yet.\n'
        'Please update the app from the Play Store to access Premium.',
      );
    }
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Subscription plan not found. Please update the app.'),
    );
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  // ─────────────────────────────────────────────────────────
  // RESTORE PURCHASES — important for iOS + re-installs
  // ─────────────────────────────────────────────────────────
  Future<void> restorePurchases() async {
    if (!_available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  // ─────────────────────────────────────────────────────────
  // PURCHASE STREAM HANDLER
  // ─────────────────────────────────────────────────────────
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    // Signal init() that the platform has delivered its restore batch (may be
    // empty). Capture + null first to be safe against concurrent completions.
    final restoreCompleter = _initRestoreCompleter;
    _initRestoreCompleter = null;
    restoreCompleter?.complete();

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleValidPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _error  = purchase.error?.message ?? 'Purchase failed';
          _status = BillingStatus.error;
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          debugPrint('Purchase cancelled: ${purchase.productID}');
          _status = BillingStatus.available;
          notifyListeners();
          break;
        case PurchaseStatus.pending:
          debugPrint('Purchase pending: ${purchase.productID}');
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _onPurchaseError(dynamic error) {
    _error  = error.toString();
    _status = BillingStatus.error;
    notifyListeners();
    debugPrint('Purchase stream error: $error');
  }

  // ─────────────────────────────────────────────────────────
  // GRANT FLOW — store verification required before unlocking
  //
  // Premium is NEVER granted until the verifyPurchase Cloud Function
  // confirms with Google Play or the App Store:
  //
  //   Store confirms  (CF 200) → grant premium, clear pending state.
  //   Store unavail.  (CF 202) → stay in pendingVerification, retry every 30s.
  //   Store rejects   (CF 402) → reject purchase, clear pending state.
  //   Other error / timeout    → treat as pending, retry.
  //
  // Pending purchases survive force-quits (persisted to SharedPrefs) and are
  // retried on every cold start and every 30s while the app is in the foreground.
  //
  // Attack surface closed:
  //   • SharedPrefs edits on rooted devices cannot unlock premium — the store
  //     must confirm the purchase before any grant is written.
  //   • Firestore cross-check on cold start detects any spoofed local state.
  // ─────────────────────────────────────────────────────────
  static const _verifyPurchaseUrl =
      'https://us-central1-gymtrackerpro-2cb3a.cloudfunctions.net/verifyPurchase';

  static const _retryInterval = Duration(seconds: 30);

  Future<void> _handleValidPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    if (productId != BillingProducts.monthly &&
        productId != BillingProducts.yearly) { return; }

    // If already verified premium (e.g. a restored subscription that is already
    // confirmed in Firestore), skip re-verification — avoid overwriting a good state.
    if (_isPremium && !_pendingVerification) {
      debugPrint('ℹ️ Restored already-verified subscription: $productId');
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData;

    debugPrint(
      '🔬 type=${purchase.runtimeType} '
      'len=${purchaseToken.length} '
      'dots=${'.'.allMatches(purchaseToken).length}',
    );

    final platform      = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    // Fast path for restored purchases: if Firestore already has a valid, unexpired
    // grant for this UID the subscription is confirmed — skip the CF round-trip.
    // Cross-account protection is enforced server-side: the CF gates every verify
    // call on purchase_tokens/{sha256(token)}, which binds a token to one Firebase
    // UID at first verification and rejects any subsequent UID that presents the
    // same token (HTTP 409 TOKEN_ALREADY_BOUND → _VerifyOutcome.rejected).
    if (purchase.status == PurchaseStatus.restored) {
      // Fast-path requires BOTH local billing keys AND a valid Firestore grant.
      // Without the billing check, a stale Firestore doc (from a cancelled subscription)
      // can re-grant premium immediately after _reVerifyOrRevoke() cleared billing keys
      // on this same cold start. Checking _kPremium here ensures that if billing was
      // just revoked (key removed), the fast-path is skipped and we fall through to CF.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPremium) ?? false) {
        final firestoreValid = await _verifyGrantInFirestore(failOpen: false);
        if (firestoreValid) {
          // Both local billing AND Firestore confirm — restore instantly without CF.
          final product      = prefs.getString(_kProductId) ?? productId;
          final cachedExpiry = prefs.getString(_kExpiry) ?? '';
          final expiryDate   = DateTime.tryParse(cachedExpiry) ?? _localExpiry(productId);
          _isPremium     = true;
          _activeProduct = product;
          _status        = BillingStatus.purchased;
          await _savePremiumStatus(
            productId:     product,
            expiryDate:    expiryDate.toIso8601String(),
            purchaseToken: purchaseToken,
          );
          if (!MonetizationService.instance.isPremium) {
            MonetizationService.instance.markPremiumFromBilling();
          }
          notifyListeners();
          debugPrint('✅ Restore fast-path: Firestore grant valid — granted instantly: $product (expires: ${expiryDate.toIso8601String()})');
          return;
        }
      }
      // No local billing OR no current Firestore grant → fall through to CF.
    }

    // 1. Persist the purchase before everything else — survives force-quits.
    await _savePendingPurchase(
      productId:     productId,
      purchaseToken: purchaseToken,
      platform:      platform,
    );

    // 2. Enter pending state so the UI can show "verifying…" immediately.
    _pendingVerification = true;
    _activeProduct       = productId;
    _status              = BillingStatus.pendingVerification;
    notifyListeners();
    debugPrint('⏳ Purchase received — awaiting store verification: $productId');

    // 3. Verify with the store in the background; grant or start retry on outcome.
    unawaited(_verifyAndGrant(
      productId:     productId,
      purchaseToken: purchaseToken,
      platform:      platform,
    ));
  }

  Future<void> _verifyAndGrant({
    required String productId,
    required String purchaseToken,
    required String platform,
  }) async {
    if (_verifying) return; // prevent concurrent CF calls
    _verifying = true;
    try {
      final result = await _callVerifyPurchase(
        productId:     productId,
        purchaseToken: purchaseToken,
        platform:      platform,
      );

      switch (result.outcome) {
        case _VerifyOutcome.granted:
        case _VerifyOutcome.gracePeriod:
          _retryTimer?.cancel();
          await _clearPendingPurchase();
          // Use server-supplied expiry when available; generous local estimate otherwise.
          final expiry = result.premiumExpiry != null
              ? (DateTime.tryParse(result.premiumExpiry!) ?? _localExpiry(productId))
              : _localExpiry(productId);
          _isPremium           = true;
          _pendingVerification = false;
          _activeProduct       = productId;
          _status              = BillingStatus.purchased;
          // Persist purchase token so re-verification can run when cached expiry passes.
          await _savePremiumStatus(
            productId:     productId,
            expiryDate:    expiry.toIso8601String(),
            purchaseToken: purchaseToken,
            cfConfirmed:   true,
          );
          MonetizationService.instance.markPremiumFromBilling();
          notifyListeners();
          if (result.outcome == _VerifyOutcome.gracePeriod) {
            debugPrint('⚠️ Premium in grace period: $productId expires: $expiry');
          } else {
            debugPrint('✅ Premium verified and granted: $productId expires: $expiry');
          }
          break;

        case _VerifyOutcome.pending:
          // Store API temporarily unavailable — hold pending state and retry.
          _pendingVerification = true;
          _isPremium           = false;
          _status              = BillingStatus.pendingVerification;
          notifyListeners();
          _startRetryTimer();
          debugPrint('⏳ Store verification unavailable — retry in ${_retryInterval.inSeconds}s');
          break;

        case _VerifyOutcome.rejected:
          _retryTimer?.cancel();
          await _clearPendingPurchase();
          _pendingVerification = false;
          _isPremium           = false;
          _status              = BillingStatus.error;
          _error               = result.rejectionMessage
              ?? 'Purchase could not be verified with the store.';
          notifyListeners();
          debugPrint('❌ Purchase rejected by store: $productId');
          break;
      }
    } finally {
      _verifying = false;
    }
  }

  // Generous local estimate — used only if the CF omits premiumExpiry.
  static DateTime _localExpiry(String productId) {
    final now = DateTime.now();
    return productId == BillingProducts.yearly
        ? now.add(const Duration(days: 400))
        : now.add(const Duration(days: 40));
  }

  // ── Retry timer — fires every 30s while verification is pending ─────────────
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (!_pendingVerification) { _retryTimer?.cancel(); return; }
      unawaited(_retryPendingVerification());
    });
  }

  Future<void> _retryPendingVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPendingPurchase);
      if (raw == null) {
        _pendingVerification = false;
        _retryTimer?.cancel();
        return;
      }
      final data          = jsonDecode(raw) as Map<String, dynamic>;
      final productId     = data['productId']     as String;
      final purchaseToken = data['purchaseToken'] as String;
      final platform      = data['platform']      as String;
      await _verifyAndGrant(
        productId:     productId,
        purchaseToken: purchaseToken,
        platform:      platform,
      );
    } catch (e) {
      debugPrint('_retryPendingVerification error: $e');
    }
  }

  // ── Cloud Function call ──────────────────────────────────────────────────────
  Future<_VerifyResult> _callVerifyPurchase({
    required String productId,
    required String purchaseToken,
    required String platform,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const _VerifyResult(_VerifyOutcome.pending);
      final idToken = await user.getIdToken();
      if (idToken == null) return const _VerifyResult(_VerifyOutcome.pending);

      final response = await http.post(
        Uri.parse(_verifyPurchaseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'productId':     productId,
          'purchaseToken': purchaseToken,
          'platform':      platform,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Store confirmed — refresh cached token to pick up new custom claims.
        await user.getIdToken(true);
        final body          = jsonDecode(response.body) as Map<String, dynamic>;
        final premiumExpiry = body['premiumExpiry'] as String?;
        final isGrace       = body['gracePeriod']   as bool? ?? false;
        if (isGrace) {
          debugPrint('⚠️ RFC-003: GRACE_PERIOD — payment pending, entitlement active (expiry=$premiumExpiry)');
          return _VerifyResult(_VerifyOutcome.gracePeriod, premiumExpiry: premiumExpiry);
        }
        debugPrint('✅ RFC-003: store verified, claim set (expiry=$premiumExpiry)');
        return _VerifyResult(_VerifyOutcome.granted, premiumExpiry: premiumExpiry);
      }

      if (response.statusCode == 202) {
        // CF received the request but the store API is temporarily unavailable.
        debugPrint('⏳ CF: PENDING_VERIFICATION (store API unavailable)');
        return const _VerifyResult(_VerifyOutcome.pending);
      }

      if (response.statusCode == 400) {
        // Malformed request (unknown product id, missing token). Deterministic —
        // retrying sends the identical body and cannot succeed. Treated as
        // pending before RFC-004, which hid iOS yearly failures behind an
        // endless 30s retry loop instead of surfacing them.
        debugPrint('❌ CF: bad request (400) — not retryable: ${response.body}');
        return const _VerifyResult(_VerifyOutcome.rejected);
      }

      if (response.statusCode == 402) {
        // Store explicitly rejected the purchase token.
        debugPrint('❌ CF: purchase rejected (402): ${response.body}');
        return const _VerifyResult(_VerifyOutcome.rejected);
      }

      if (response.statusCode == 409) {
        // Token already bound to a different Firebase UID — cross-account restore
        // attempt. Reject permanently; retrying will not change the outcome.
        // Common cause: the user subscribed while signed in with one provider
        // (e.g. Google) and is now signed in with another (e.g. Apple). The
        // generic "could not be verified" text left them with no way forward,
        // so name the cause and the recovery step — see RFC-004 F2.
        debugPrint('❌ CF: TOKEN_ALREADY_BOUND (409) — purchase token belongs to a different Firebase account');
        return const _VerifyResult(
          _VerifyOutcome.rejected,
          rejectionMessage:
              'This subscription is already linked to another LiftOn account. '
              'Sign out and sign back in with the account you originally '
              'subscribed with, or contact support to move it.',
        );
      }

      // 4xx / 5xx not covered above — treat as transient, retry later.
      debugPrint('⚠️ verifyPurchase (${response.statusCode}): ${response.body}');
      return const _VerifyResult(_VerifyOutcome.pending);

    } on TimeoutException {
      debugPrint('⚠️ verifyPurchase timed out — will retry');
      return const _VerifyResult(_VerifyOutcome.pending);
    } catch (e) {
      debugPrint('⚠️ verifyPurchase error — will retry: $e');
      return const _VerifyResult(_VerifyOutcome.pending);
    }
  }

  // ─────────────────────────────────────────────────────────
  // PERSISTENCE — cache premium / pending state locally
  // Prevents "free" state flash on cold start for verified subscribers.
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Restore pending-verification state from a previous session.
      // Fall through: also load any existing verified premium so a user with an
      // active subscription doesn't appear downgraded while a renewal verifies.
      if (prefs.containsKey(_kPendingPurchase)) {
        _pendingVerification = true;
        debugPrint('⏳ Pending purchase found on cold start — will retry verification');
      }

      final premium     = prefs.getBool(_kPremium)     ?? false;
      final expiry      = prefs.getString(_kExpiry)    ?? '';
      final product     = prefs.getString(_kProductId);
      final cfConfirmed = prefs.getBool(_kCfConfirmed) ?? false;

      if (!premium) {
        // Billing has no stored premium. Clear any stale MonetizationService key
        // (is_premium_v2_$uid) that might have been left from a previous session
        // where billing was revoked but MonetizationService was not synced.
        await MonetizationService.instance.revokePremium();
        return;
      }

      // Check local expiry.
      if (expiry.isNotEmpty) {
        final expiryDate = DateTime.tryParse(expiry);
        if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
          // Expiry passed — re-verify with CF before revoking.
          // The subscription may be in Google's grace period (still entitled).
          debugPrint('⚠️ Local expiry passed on cold start — re-verifying with CF');
          await _reVerifyOrRevoke(
            productId:   product ?? '',
            debugReason: 'local expiry passed on cold start',
          );
          return;
        }
      }

      // If billing keys were written by the Firestore fast-path (not a CF-confirmed
      // grant), re-verify with CF before granting. A stale Firestore doc (e.g. from a
      // cancelled subscription whose expiresAt hasn't passed yet) would otherwise grant
      // premium indefinitely without any Play/App Store check. This triggers on the very
      // first cold start after a fast-path grant because _kCfConfirmed is never written
      // by the fast-path. After the CF confirms, it writes _kCfConfirmed=true and
      // subsequent cold starts trust the local cache (until the real expiry passes).
      if (!cfConfirmed) {
        debugPrint('⚠️ Billing not CF-confirmed — re-verifying with Play Store via CF');
        await _reVerifyOrRevoke(
          productId:   product ?? '',
          debugReason: 'not CF-confirmed on cold start',
        );
        return;
      }

      // Cross-check Firestore: if SharedPrefs claims premium but Firestore has no
      // valid grant record, re-verify with CF rather than revoking immediately.
      // Catches the edge case where the Firestore write failed but the local grant
      // was written (or the Firestore expiry lags behind a recent CF renewal).
      final firestoreValid = await _verifyGrantInFirestore();
      if (!firestoreValid) {
        debugPrint('⚠️ Firestore cross-check failed — re-verifying with CF');
        await _reVerifyOrRevoke(
          productId:   product ?? '',
          debugReason: 'Firestore cross-check failed on cold start',
        );
        return;
      }

      _isPremium     = true;
      _activeProduct = product;
      // H-2: heal de-sync if billing key is set but MonetizationService's key was
      // not updated (e.g. crash between the two writes).
      if (!MonetizationService.instance.isPremium) {
        MonetizationService.instance.markPremiumFromBilling();
      }
    } catch (e) {
      // On any error (network, Firestore offline) trust the local cache to avoid
      // false revocation. Firestore check is best-effort.
      debugPrint('_loadCachedStatus error (trusting cache): $e');
      final prefs   = await SharedPreferences.getInstance();
      final premium = prefs.getBool(_kPremium) ?? false;
      if (premium) {
        _isPremium     = true;
        _activeProduct = prefs.getString(_kProductId);
      }
    }
  }

  // Returns true     — Firestore has a valid, unexpired grant for this UID.
  // Returns failOpen — Firestore is unreachable (true protects offline users;
  //                    false forces CF verify in the restore fast-path).
  // Returns false    — Firestore explicitly reports no grant.
  Future<bool> _verifyGrantInFirestore({bool failOpen = true}) async {
    final uid = _uid;
    if (uid == null) return failOpen; // unauthenticated
    try {
      final doc = await FirebaseFirestore.instance
          .collection('premium_grants')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return false;
      final data      = doc.data()!;
      final expiresAt = DateTime.tryParse(data['expiresAt'] as String? ?? '');
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return false;
      return true;
    } catch (e) {
      debugPrint('Firestore grant check skipped (offline?): $e');
      return failOpen;
    }
  }

  // ── Account isolation ────────────────────────────────────────────────────────

  // Firebase auth state changed: sign-out clears all in-memory premium state;
  // sign-in reloads from the new user's UID-scoped SharedPrefs keys.
  // This is the single authoritative reset point — no other sign-out handler needed.
  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      // User signed out — wipe all premium state from memory immediately.
      _resetPremiumState();
      // Also clear MonetizationService so AppProvider.isPremium returns false.
      await MonetizationService.instance.revokePremium();
    } else {
      // New user signed in (or token refreshed) — reload from their scoped cache.
      // If they have no local cache, _loadCachedStatus exits early with _isPremium=false.
      await _loadCachedStatus();
    }
  }

  // Zero out all premium-related in-memory state without touching SharedPrefs.
  // SharedPrefs entries are keyed by UID so they are naturally isolated.
  void _resetPremiumState() {
    _retryTimer?.cancel();
    _retryTimer          = null;
    _isPremium           = false;
    _pendingVerification = false;
    _verifying           = false;
    _activeProduct       = null;
    _error               = null;
    _status              = _available ? BillingStatus.available : BillingStatus.unavailable;
    notifyListeners();
  }

  // Called when the locally-cached expiry has passed or Firestore cross-check fails.
  // Re-verifies with the CF rather than revoking immediately, so that subscriptions
  // in Google's grace period (paymentState=0, expiryTimeMillis still future) remain
  // active. Revokes only when the CF definitively rejects (ON_HOLD / EXPIRED / invalid).
  Future<void> _reVerifyOrRevoke({required String productId, String debugReason = ''}) async {
    final prefs         = await SharedPreferences.getInstance();
    final purchaseToken = prefs.getString(_kPurchaseToken) ?? '';
    if (purchaseToken.isEmpty) {
      // No token stored — cannot re-verify. Safe to revoke.
      debugPrint('⚠️ _reVerifyOrRevoke: no token stored ($debugReason) — revoking');
      await _clearPremiumStatus();
      return;
    }
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    debugPrint('🔄 Re-verifying with CF ($debugReason)…');
    final result = await _callVerifyPurchase(
      productId:     productId,
      purchaseToken: purchaseToken,
      platform:      platform,
    );
    switch (result.outcome) {
      case _VerifyOutcome.granted:
      case _VerifyOutcome.gracePeriod:
        final expiry = result.premiumExpiry != null
            ? (DateTime.tryParse(result.premiumExpiry!) ?? _localExpiry(productId))
            : _localExpiry(productId);
        _isPremium     = true;
        _activeProduct = productId;
        await _savePremiumStatus(
          productId:     productId,
          expiryDate:    expiry.toIso8601String(),
          purchaseToken: purchaseToken,
          cfConfirmed:   true,
        );
        if (!MonetizationService.instance.isPremium) {
          MonetizationService.instance.markPremiumFromBilling();
        }
        debugPrint('✅ Re-verify ${result.outcome == _VerifyOutcome.gracePeriod ? "(grace period)" : ""}: premium refreshed, expires $expiry');
        break;
      case _VerifyOutcome.pending:
        // CF or store API unreachable — fail open, trust local cache.
        _isPremium     = true;
        _activeProduct = productId;
        debugPrint('⏳ Re-verify pending ($debugReason) — store unavailable, keeping premium');
        break;
      case _VerifyOutcome.rejected:
        await _clearPremiumStatus();
        // Surface an actionable cause when there is one (e.g. TOKEN_ALREADY_BOUND
        // on a cross-provider restore). This is the path a user hits on cold start
        // or restore, so without it the revocation is silent — RFC-004 F2.
        if (result.rejectionMessage != null) {
          _error  = result.rejectionMessage;
          _status = BillingStatus.error;
          notifyListeners();
        }
        debugPrint('❌ Re-verify rejected ($debugReason) — premium revoked');
        break;
    }
  }

  Future<void> _savePendingPurchase({
    required String productId,
    required String purchaseToken,
    required String platform,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingPurchase, jsonEncode({
      'productId':     productId,
      'purchaseToken': purchaseToken,
      'platform':      platform,
      'pendingAt':     DateTime.now().toIso8601String(),
    }));
  }

  Future<void> _clearPendingPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingPurchase);
  }

  Future<void> _savePremiumStatus({
    required String productId,
    required String expiryDate,
    String purchaseToken = '',
    bool cfConfirmed = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremium,     true);
    await prefs.setString(_kProductId, productId);
    await prefs.setString(_kExpiry,    expiryDate);
    if (purchaseToken.isNotEmpty) {
      await prefs.setString(_kPurchaseToken, purchaseToken);
    }
    // Write or clear the CF-confirmed flag so _loadCachedStatus() knows whether
    // this grant was verified with the Play/App Store (vs. Firestore fast-path only).
    if (cfConfirmed) {
      await prefs.setBool(_kCfConfirmed, true);
    } else {
      await prefs.remove(_kCfConfirmed);
    }
  }

  Future<void> _clearPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPremium);
    await prefs.remove(_kProductId);
    await prefs.remove(_kExpiry);
    await prefs.remove(_kPurchaseToken);
    await prefs.remove(_kCfConfirmed);
    _isPremium     = false;
    _activeProduct = null;
    await MonetizationService.instance.revokePremium();
  }

  // ─────────────────────────────────────────────────────────
  // DEVELOPMENT OVERRIDE — use for testing without Play Store
  // Call: BillingService.instance.devGrantPremium()
  // ─────────────────────────────────────────────────────────
  Future<void> devGrantPremium() async {
    assert(kDebugMode, 'devGrantPremium only available in debug mode');
    _isPremium = true;
    _activeProduct = BillingProducts.monthly;
    await _savePremiumStatus(
      productId:  BillingProducts.monthly,
      expiryDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    );
    notifyListeners();
    debugPrint('🛠 Dev premium granted');
  }

  Future<void> devRevokePremium() async {
    assert(kDebugMode, 'devRevokePremium only available in debug mode');
    await _clearPremiumStatus();
    notifyListeners();
    debugPrint('🛠 Dev premium revoked');
  }

  // H-4: Check subscription expiry whenever the app comes back to the foreground.
  // Catches the case where a subscription expires while the app is running or
  // backgrounded — without this, the user stays premium until next cold start.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_isPremium || _pendingVerification) return;
    unawaited(_checkExpiryOnResume());
  }

  Future<void> _checkExpiryOnResume() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final expiry = prefs.getString(_kExpiry) ?? '';
      if (expiry.isEmpty) return;
      final expiryDate = DateTime.tryParse(expiry);
      if (expiryDate == null || DateTime.now().isBefore(expiryDate)) return;
      // Expiry passed while app was open or backgrounded.
      // Re-verify with CF — subscription may be in Google's grace period.
      debugPrint('⚠️ H-4: Cached expiry passed on resume — re-verifying with CF');
      final product = prefs.getString(_kProductId) ?? '';
      await _reVerifyOrRevoke(productId: product, debugReason: 'expiry passed on resume');
      if (!_isPremium) {
        // revokePremium() already called inside _clearPremiumStatus() via _reVerifyOrRevoke.
        _status = BillingStatus.available;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('_checkExpiryOnResume error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _authSub?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }
}
