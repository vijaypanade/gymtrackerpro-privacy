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
//    - premium_monthly    ₹149/month  (base plan)
//    - premium_quarterly  ₹349/3mo    (Save 22%)
//    - premium_yearly     ₹999/year   (Save 44% — RECOMMENDED)
//    All three with 14-day free trial introductory pricing.
// ══════════════════════════════════════════════════════════

import 'dart:async';
import 'monetization_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// PRODUCT IDs — must match Play Console exactly
// ─────────────────────────────────────────────────────────
class BillingProducts {
  static const monthly   = 'premium_monthly';   // ₹149/month
  static const quarterly = 'premium_quarterly'; // ₹349/3 months
  static const yearly    = 'premium_yearly';    // ₹999/year
  static const all       = {monthly, quarterly, yearly};
}

// ─────────────────────────────────────────────────────────
// BILLING STATE
// ─────────────────────────────────────────────────────────
enum BillingStatus { loading, available, unavailable, purchased, error }

class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const _keyPremium    = 'billing_premium_v2';
  static const _keyProductId  = 'billing_product_id_v2';
  static const _keyExpiry     = 'billing_expiry_v2';

  // ── State ──────────────────────────────────────────────
  BillingStatus _status         = BillingStatus.loading;
  bool          _isPremium      = false;
  bool          _available      = false;
  String?       _activeProduct;
  String?       _error;

  List<ProductDetails>   _products   = [];
  List<PurchaseDetails>  _purchases  = [];

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

      // Restore previous purchases
      await InAppPurchase.instance.restorePurchases();

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
    );

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
  // In production: verify receipt with your backend server.
  // For Phase 1 (AdMob-only): local grant is acceptable.
  // ─────────────────────────────────────────────────────────
  Future<void> _handleValidPurchase(PurchaseDetails purchase) async {
    // TODO Phase 2: Send purchase.verificationData to your backend
    // and verify with Google Play Developer API before granting.
    // For now: trust the purchase stream (Google handles verification).

    final productId = purchase.productID;

    if (productId == BillingProducts.monthly  ||
        productId == BillingProducts.quarterly ||
        productId == BillingProducts.yearly) {
      // Calculate expiry
      final now = DateTime.now();
      final expiry = productId == BillingProducts.yearly
          ? now.add(const Duration(days: 365))
          : productId == BillingProducts.quarterly
              ? now.add(const Duration(days: 95))  // 3 months + buffer
              : now.add(const Duration(days: 32));  // monthly + buffer

      _isPremium     = true;
      _activeProduct = productId;
      _status        = BillingStatus.purchased;

      await _savePremiumStatus(
        productId:  productId,
        expiryDate: expiry.toIso8601String(),
      );

      debugPrint('✅ Premium granted: $productId, expires: $expiry');
      // ✅ Sync with MonetizationService (UI + AdService)
      MonetizationService.instance.markPremiumFromBilling();
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  // PERSISTENCE — cache premium status locally
  // Prevents "free" state flash on cold start
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCachedStatus() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final premium = prefs.getBool(_keyPremium)    ?? false;
      final expiry  = prefs.getString(_keyExpiry)   ?? '';
      final product = prefs.getString(_keyProductId);

      if (!premium) return;

      // Check if subscription expired
      if (expiry.isNotEmpty) {
        final expiryDate = DateTime.tryParse(expiry);
        if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
          // Expired — clear and restore from Play (handled in init)
          await _clearPremiumStatus();
          return;
        }
      }

      _isPremium     = true;
      _activeProduct = product;
    } catch (e) {
      debugPrint('_loadCachedStatus error: $e');
    }
  }

  Future<void> _savePremiumStatus({
    required String productId,
    required String expiryDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremium,   true);
    await prefs.setString(_keyProductId, productId);
    await prefs.setString(_keyExpiry,    expiryDate);
  }

  Future<void> _clearPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPremium);
    await prefs.remove(_keyProductId);
    await prefs.remove(_keyExpiry);
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
