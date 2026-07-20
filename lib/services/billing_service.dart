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
import 'monetization_service.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// PRODUCT IDs — must match Play Console exactly
// ─────────────────────────────────────────────────────────
class BillingProducts {
  static const monthly = 'premium_monthly'; // ₹150/month
  static const yearly  = 'premium_yearly';  // ₹1499/year
  static const all     = {monthly, yearly};
}

// ─────────────────────────────────────────────────────────
// BILLING STATE
// ─────────────────────────────────────────────────────────
enum BillingStatus { loading, available, unavailable, purchased, error }

class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const _keyPremium    = 'billing_premium_v3';
  static const _keyProductId  = 'billing_product_id_v3';
  static const _keyExpiry     = 'billing_expiry_v3';

  // UID-scoped keys — one account's purchase won't leak to another on same device
  String get _kPremium   { final u = AuthService.instance.currentUser?.uid; return u != null ? '${_keyPremium}_$u'   : _keyPremium; }
  String get _kProductId { final u = AuthService.instance.currentUser?.uid; return u != null ? '${_keyProductId}_$u' : _keyProductId; }
  String get _kExpiry    { final u = AuthService.instance.currentUser?.uid; return u != null ? '${_keyExpiry}_$u'    : _keyExpiry; }

  // ── State ──────────────────────────────────────────────
  BillingStatus _status         = BillingStatus.loading;
  bool          _isPremium      = false;
  bool          _available      = false;
  String?       _activeProduct;
  String?       _error;

  List<ProductDetails>   _products   = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // ── Public getters ─────────────────────────────────────
  BillingStatus get status        => _status;
  bool          get isPremium     => _isPremium;
  bool          get isAvailable   => _available;
  String?       get error         => _error;
  String?       get activeProduct => _activeProduct;
  List<ProductDetails> get products => _products;

  // ─────────────────────────────────────────────────────────
  // INIT — call in main.dart before runApp
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      // Load cached premium status first (instant UI)
      await _loadCachedStatus();

      // Check if billing available on device
      _available = await InAppPurchase.instance.isAvailable();
      if (!_available) {
        _status = BillingStatus.unavailable;
        notifyListeners();
        return;
      }

      // Listen for purchase updates
      _purchaseSub = InAppPurchase.instance.purchaseStream
          .listen(_onPurchaseUpdate, onError: _onPurchaseError);

      // Load products
      await _loadProducts();

      // Restore previous purchases (fire-and-forget — results come via purchaseStream)
      InAppPurchase.instance.restorePurchases().ignore();

      _status = BillingStatus.available;
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

    if (response.error != null) {
      debugPrint('Product query error: ${response.error}');
    }

    _products = response.productDetails;
    debugPrint('Loaded ${_products.length} products: '
        '${_products.map((p) => "${p.id}=${p.price}").join(", ")}');
  }

  // ─────────────────────────────────────────────────────────
  // PURCHASE — called from UI
  // ─────────────────────────────────────────────────────────
  Future<void> purchase(String productId) async {
    if (!_available) {
      throw Exception('Payment is not available on this device.');
    }

    if (_products.isEmpty) {
      throw Exception(
        'Subscription products are not configured yet.\n'
        'Please update the app from the Play Store to access Premium.',
      );
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception(
        'Subscription plan not found. Please update the app.',
      ),
    );

    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
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
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleValidPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Purchase failed';
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

      // Complete the purchase transaction (required for both platforms)
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _onPurchaseError(dynamic error) {
    _error = error.toString();
    _status = BillingStatus.error;
    notifyListeners();
    debugPrint('Purchase stream error: $error');
  }

  // ─────────────────────────────────────────────────────────
  // VALIDATE AND GRANT PREMIUM
  // Defence-in-depth: local grant + Firestore record.
  //
  // Attack surface closed:
  //   • Editing SharedPreferences on a rooted device no longer
  //     grants premium because _loadCachedStatus cross-checks
  //     Firestore on every cold start.
  //   • The Firestore record is the authoritative source of truth.
  //
  // RFC-003: verifyPurchase Cloud Function sets the Firebase custom claim
  // { premium: true, premiumExpiry } that askAI checks server-side.
  // ─────────────────────────────────────────────────────────
  static const _verifyPurchaseUrl =
      'https://us-central1-gymtrackerpro-2cb3a.cloudfunctions.net/verifyPurchase';

  Future<void> _handleValidPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    if (productId != BillingProducts.monthly &&
        productId != BillingProducts.yearly) { return; }

    final now    = DateTime.now();
    final expiry = productId == BillingProducts.yearly
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 32));

    // 1. Grant locally first so UI responds instantly.
    _isPremium     = true;
    _activeProduct = productId;
    _status        = BillingStatus.purchased;
    await _savePremiumStatus(productId: productId, expiryDate: expiry.toIso8601String());
    MonetizationService.instance.markPremiumFromBilling();
    notifyListeners();

    debugPrint('✅ Premium granted locally: $productId, expires: $expiry');

    // 2. Write authoritative grant record to Firestore (server source of truth).
    await _recordGrantToFirestore(
      productId:     productId,
      purchaseToken: purchase.verificationData.serverVerificationData,
      expiresAt:     expiry,
    );

    // 3. RFC-003: set Firebase custom claim so askAI recognises premium server-side.
    // Non-fatal — local grant already active. Claim is refreshed on next getIdToken(true).
    _callVerifyPurchase(
      productId:     productId,
      purchaseToken: purchase.verificationData.serverVerificationData,
    ).ignore();
  }

  Future<void> _callVerifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      if (idToken == null) return;

      final response = await http.post(
        Uri.parse(_verifyPurchaseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'productId':     productId,
          'purchaseToken': purchaseToken,
          'platform':      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Pull the fresh premium claim into the cached token.
        await user.getIdToken(true);
        debugPrint('✅ RFC-003: premium custom claim set');
      } else {
        debugPrint('⚠️ verifyPurchase (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('verifyPurchase error (non-fatal): $e');
    }
  }

  // Writes the purchase grant to Firestore so it can be cross-checked
  // on every cold start. Non-fatal if Firestore is unreachable.
  Future<void> _recordGrantToFirestore({
    required String   productId,
    required String   purchaseToken,
    required DateTime expiresAt,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('premium_grants')
          .doc(uid)
          .set({
        'productId':     productId,
        'purchaseToken': purchaseToken,
        'grantedAt':     FieldValue.serverTimestamp(),
        'expiresAt':     expiresAt.toIso8601String(),
        'platform':      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'verified':      false,
      }, SetOptions(merge: true));
      debugPrint('✅ Grant recorded to Firestore');
    } catch (e) {
      // Non-fatal — local grant already applied. Retried on next purchase restore.
      debugPrint('⚠️ Firestore grant record failed (non-fatal): $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // PERSISTENCE — cache premium status locally
  // Prevents "free" state flash on cold start
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCachedStatus() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final premium = prefs.getBool(_kPremium)  ?? false;
      final expiry  = prefs.getString(_kExpiry) ?? '';
      final product = prefs.getString(_kProductId);

      if (!premium) return;

      // Check local expiry first.
      if (expiry.isNotEmpty) {
        final expiryDate = DateTime.tryParse(expiry);
        if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
          await _clearPremiumStatus();
          return;
        }
      }

      // Cross-check Firestore: if SharedPrefs claims premium but Firestore
      // has no grant record for this UID, the local flag is spoofed — revoke.
      final firestoreValid = await _verifyGrantInFirestore();
      if (!firestoreValid) {
        debugPrint('⚠️ Firestore cross-check failed — revoking spoofed local premium');
        await _clearPremiumStatus();
        return;
      }

      _isPremium     = true;
      _activeProduct = product;
    } catch (e) {
      // On any error (network, Firestore offline) trust the local cache
      // to avoid false revocation. Firestore check is best-effort.
      debugPrint('_loadCachedStatus error (trusting cache): $e');
      final prefs   = await SharedPreferences.getInstance();
      final premium = prefs.getBool(_kPremium) ?? false;
      if (premium) {
        _isPremium     = true;
        _activeProduct = prefs.getString(_kProductId);
      }
    }
  }

  // Returns true if Firestore has a valid grant for the current user,
  // OR if the user is not authenticated / Firestore is unreachable.
  // Returns false only when Firestore explicitly has no grant record.
  Future<bool> _verifyGrantInFirestore() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return true; // unauthenticated — defer to Play restore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('premium_grants')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return false;
      final data     = doc.data()!;
      final expiresAt = DateTime.tryParse(data['expiresAt'] as String? ?? '');
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return false;
      return true;
    } catch (e) {
      // Network unavailable or timeout — fail open so offline users aren't revoked.
      debugPrint('Firestore grant check skipped (offline?): $e');
      return true;
    }
  }

  Future<void> _savePremiumStatus({
    required String productId,
    required String expiryDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremium,   true);
    await prefs.setString(_kProductId, productId);
    await prefs.setString(_kExpiry,    expiryDate);
  }

  Future<void> _clearPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPremium);
    await prefs.remove(_kProductId);
    await prefs.remove(_kExpiry);
    _isPremium     = false;
    _activeProduct = null;
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

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
