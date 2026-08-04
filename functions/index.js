// functions/index.js — production-safe Gemini proxy
//
// Server-side protections:
//   1. Firebase Auth ID token verification (required)
//   2. Emergency kill switch (Firestore ai_config/global.enabled)
//   3. Per-UID per-feature daily rate limit (request_types[type] in ai_usage/{uid})
//   4. Per-UID cooldown enforcement (min 10s between requests)
//   5. Flash vs Pro model routing based on request type
//   6. Usage tracking per user per day (daily_count kept for analytics only)
//   7. API key is never logged
//
// Feature daily limits (free / premium):
//   chat:    15 / unlimited
//   diet:     2 / unlimited
//   plan:     3 / unlimited
//   workout:  3 / unlimited
//   brief:   10 / unlimited
//
// Firebase schema (Firestore):
//
//   /ai_config/global
//     enabled:            bool   — emergency kill switch
//     free_daily_limit:   number — default 15
//     premium_daily_limit:number — default 60
//     cooldown_seconds:   number — default 10
//     flash_model:        string — "gemini-2.5-flash"
//     pro_model:          string — "gemini-2.5-pro"
//
//   /ai_usage/{uid}
//     date:              string    — "YYYY-MM-DD" of last reset
//     daily_count:       number    — resets each new date
//     total_count:       number    — lifetime
//     last_request_at:   timestamp
//     is_premium:        bool
//     request_types:     map       — { chat: N, brief: N, plan: N, ... }

"use strict";

const { onRequest }    = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const functionsV1      = require("firebase-functions/v1");
const admin            = require("firebase-admin");
const crypto           = require("crypto");
const fetch            = require("node-fetch");
const { GoogleAuth }   = require("google-auth-library");

admin.initializeApp();
const db = admin.firestore();

const GEMINI_API_KEY  = defineSecret("GEMINI_API_KEY");
const PLAY_SA_JSON    = defineSecret("PLAY_SERVICE_ACCOUNT_JSON");
const APPSTORE_SECRET = defineSecret("APPSTORE_SHARED_SECRET");

// Android package name — must match Play Console exactly
const ANDROID_PACKAGE = "com.nidhish.aitrainer";

// ── Defaults (overridden by Firestore ai_config/global) ─────────────────────
const DEFAULTS = {
  enabled:             true,
  free_daily_limit:    15,
  premium_daily_limit: 60,
  cooldown_seconds:    10,
  flash_model:         "gemini-2.5-flash",
  pro_model:           "gemini-2.5-pro",
};

// ── Feature-specific free daily limits ──────────────────────────────────────
const FREE_FEATURE_LIMITS = {
  chat:    15,
  diet:     2,
  plan:     3,
  workout:  3,
  brief:   10,
};
const DEFAULT_FREE_LIMIT = 5; // fallback for unknown/future types

// Premium users are unlimited for all features.
function getFeatureLimit(type, isPremium) {
  if (isPremium) return Infinity;
  return FREE_FEATURE_LIMITS[type] ?? DEFAULT_FREE_LIMIT;
}

// ── Allowed model names (whitelist — prevents model injection) ───────────────
const ALLOWED_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.5-pro",
]);

// ── Today string ─────────────────────────────────────────────────────────────
function todayUTC() {
  return new Date().toISOString().split("T")[0]; // "YYYY-MM-DD"
}

// ── Fetch global config (cached per cold-start) ──────────────────────────────
let _configCache = null;
let _configFetchedAt = 0;
const CONFIG_TTL_MS = 60_000; // re-fetch config every 60s

async function getConfig() {
  const now = Date.now();
  if (_configCache && now - _configFetchedAt < CONFIG_TTL_MS) {
    return _configCache;
  }
  try {
    const snap = await db.collection("ai_config").doc("global").get();
    _configCache = snap.exists ? { ...DEFAULTS, ...snap.data() } : { ...DEFAULTS };
  } catch (_) {
    _configCache = { ...DEFAULTS }; // network error → use defaults (fail open)
  }
  _configFetchedAt = now;
  return _configCache;
}

// ── Store receipt verification helpers ──────────────────────────────────────
//
// Both helpers return { valid: bool, expiryMs: number|null, reason: string }.
//
// Failure modes:
//   • Explicit invalid (wrong token, cancelled, expired) → valid=false (reject)
//   • Transient store API error (network, quota)         → throws (caller fails open)
//
// The caller catches throws and falls back to a local expiry estimate so that
// a store-API outage never blocks a legitimate purchase.

async function verifyAndroidPurchase(productId, purchaseToken) {
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(PLAY_SA_JSON.value());
  } catch (_) {
    throw new Error("PLAY_SERVICE_ACCOUNT_JSON secret is missing or invalid JSON");
  }

  const auth   = new GoogleAuth({ credentials: serviceAccount, scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();

  const url  = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}/purchases/subscriptions/${productId}/tokens/${encodeURIComponent(purchaseToken)}`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });

  // 404 / 410 = token not found or already voided — definitively invalid
  if (resp.status === 404 || resp.status === 410) {
    return { valid: false, expiryMs: null, reason: `Play API ${resp.status}: token not found or voided` };
  }
  if (!resp.ok) throw new Error(`Play API HTTP ${resp.status}`); // transient → throw

  const sub          = await resp.json();
  const paymentState = sub.paymentState;
  const expiryMs     = sub.expiryTimeMillis ? parseInt(sub.expiryTimeMillis, 10) : null;

  if (paymentState === 1 || paymentState === 2) {
    // ACTIVE or FREE_TRIAL — definitively entitled.
    return { valid: true, inGracePeriod: false, expiryMs, reason: `paymentState=${paymentState} autoRenewing=${sub.autoRenewing} acknowledgementState=${sub.acknowledgementState}` };
  }

  if (paymentState === 0 && expiryMs && expiryMs > Date.now()) {
    // Payment pending but Google's entitlement window still open = IN_GRACE_PERIOD.
    // cancelReason=2 is the payment-declined path. User remains entitled.
    return { valid: true, inGracePeriod: true, expiryMs, reason: `GRACE_PERIOD autoRenewing=${sub.autoRenewing} cancelReason=${sub.cancelReason ?? "none"} acknowledgementState=${sub.acknowledgementState}` };
  }

  // paymentState=0 with past/missing expiryTimeMillis = ON_HOLD, PAUSED, or expired.
  return { valid: false, inGracePeriod: false, expiryMs: null, reason: `ON_HOLD/PAUSED paymentState=${paymentState} expiryMs=${expiryMs} autoRenewing=${sub.autoRenewing} cancelReason=${sub.cancelReason ?? "none"}` };
}

// ── RFC-006: StoreKit 2 JWS verification ────────────────────────────────────
// in_app_purchase_storekit delivers SK2PurchaseDetails on iOS 15+, whose
// serverVerificationData is the transaction JWS — not a legacy App Receipt.
// /verifyReceipt cannot parse it and answers 21002. Verified here with Apple's
// official library; no hand-written crypto.
const fs   = require("fs");
const path = require("path");
const { defineString } = require("firebase-functions/params");
const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");

const APPLE_BUNDLE_ID  = "com.nidhish.aitrainer";
// Numeric App Store id. Not secret, so a deploy-time param rather than a secret;
// set via functions/.env (APPLE_APP_APPLE_ID=...) or the deploy prompt.
const APPLE_APP_APPLE_ID = defineString("APPLE_APP_APPLE_ID");

let _appleRootCAs = null;
function appleRootCAs() {
  if (!_appleRootCAs) {
    const dir = path.join(__dirname, "certs");
    _appleRootCAs = fs.readdirSync(dir)
      .filter((f) => f.endsWith(".cer"))
      .map((f) => fs.readFileSync(path.join(dir, f)));
    if (_appleRootCAs.length === 0) throw new Error("no Apple root CA .cer in functions/certs");
  }
  return _appleRootCAs;
}

const _verifiers = {};
function verifierFor(env) {
  if (!_verifiers[env]) {
    const appAppleId = Number(APPLE_APP_APPLE_ID.value());
    if (env === Environment.PRODUCTION && !appAppleId) {
      throw new Error("APPLE_APP_APPLE_ID is not configured");
    }
    _verifiers[env] = new SignedDataVerifier(
      appleRootCAs(), true, env, APPLE_BUNDLE_ID, appAppleId || undefined,
    );
  }
  return _verifiers[env];
}

// A JWS is exactly three base64url segments; a legacy receipt is plain base64.
const isJws = (t) =>
  typeof t === "string" &&
  t.split(".").length === 3 &&
  t.split(".").every((s) => /^[A-Za-z0-9_-]+$/.test(s));

// The library raises VerificationException (carrying .status) for a decided
// verification failure. Anything without .status is infrastructure — network,
// missing cert, revocation lookup — and must stay transient so the caller
// answers 202 and the retry loop keeps the purchase alive.
const isDecidedFailure = (e) => e && e.status !== undefined;

async function verifyIosJws(jws) {
  // Environment is untrustworthy until the signature is checked, so try both.
  let decoded = null, lastErr = null;
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try { decoded = await verifierFor(env).verifyAndDecodeTransaction(jws); break; }
    catch (e) { lastErr = e; }
  }
  if (!decoded) throw lastErr || new Error("JWS verification failed");

  if (decoded.revocationDate) {
    return { valid: false, expiryMs: null, originalTransactionId: decoded.originalTransactionId ?? null,
             reason: `revoked reason=${decoded.revocationReason}` };
  }
  const expiryMs = decoded.expiresDate ?? null;
  if (expiryMs && expiryMs < Date.now()) {
    return { valid: false, expiryMs: null, originalTransactionId: decoded.originalTransactionId ?? null,
             reason: `expired at ${new Date(expiryMs).toISOString()}` };
  }
  return {
    valid: true,
    expiryMs,
    originalTransactionId: decoded.originalTransactionId ?? null,
    reason: `JWS product=${decoded.productId} type=${decoded.type}`,
  };
}

// purchaseToken for iOS = base64-encoded App Receipt from
// PurchaseDetails.verificationData.serverVerificationData (StoreKit 1 / in_app_purchase plugin).
async function verifyIosLegacyReceipt(receiptData) {
  const secret = APPSTORE_SECRET.value();
  if (!secret) throw new Error("APPSTORE_SHARED_SECRET secret is missing");

  const body = JSON.stringify({ "receipt-data": receiptData, "password": secret, "exclude-old-transactions": true });

  async function callEndpoint(url) {
    const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body });
    if (!r.ok) throw new Error(`App Store HTTP ${r.status}`);
    return r.json();
  }

  let data = await callEndpoint("https://buy.itunes.apple.com/verifyReceipt");
  if (data.status === 21007) {
    // Sandbox receipt sent to production — retry with sandbox endpoint (normal in TestFlight)
    data = await callEndpoint("https://sandbox.itunes.apple.com/verifyReceipt");
  }

  if (data.status !== 0) {
    // Definitively invalid statuses (not transient)
    const INVALID_STATUSES = new Set([21003, 21004, 21010]);
    if (INVALID_STATUSES.has(data.status)) {
      return { valid: false, expiryMs: null, reason: `App Store status=${data.status}` };
    }
    throw new Error(`App Store status=${data.status}`); // transient → throw
  }

  const info = data.latest_receipt_info;
  if (!info || info.length === 0) {
    return { valid: false, expiryMs: null, reason: "App Store: no active subscription in receipt" };
  }

  // latest_receipt_info[0] is the most recent transaction when exclude-old-transactions=true
  const latest   = info[0];
  const expiryMs = latest.expires_date_ms ? parseInt(latest.expires_date_ms, 10) : null;
  if (expiryMs && expiryMs < Date.now()) {
    return { valid: false, expiryMs: null, reason: `App Store: subscription already expired at ${latest.expires_date}` };
  }

  // original_transaction_id is stable for the lifetime of a subscription across
  // renewals and restores. The App Receipt itself is regenerated on both, so it
  // cannot be used as an ownership key on iOS — see RFC-004 F2.
  return {
    valid: true,
    expiryMs,
    originalTransactionId: latest.original_transaction_id ?? null,
    reason: `product=${latest.product_id} cancellation=${latest.cancellation_date ?? "none"}`,
  };
}

// Routes StoreKit 2 tokens to JWS verification and everything else to the
// legacy receipt flow. Return shape is identical for both, so BillingService's
// contract (valid / expiryMs / originalTransactionId / reason) is unchanged.
//
// A decided verification failure is returned as valid:false → 402 → rejected.
// A transient failure is re-thrown → 202 → pending, so the retry loop and grace
// handling behave exactly as before. Collapsing the two would turn an Apple
// outage into a permanent revocation.
async function verifyIosPurchase(token) {
  try {
    return isJws(token) ? await verifyIosJws(token) : await verifyIosLegacyReceipt(token);
  } catch (e) {
    if (isDecidedFailure(e)) {
      return { valid: false, expiryMs: null, originalTransactionId: null,
               reason: `JWS rejected status=${e.status}` };
    }
    throw e; // transient — caller answers 202 PENDING_VERIFICATION
  }
}

// ── Main Cloud Function ──────────────────────────────────────────────────────
exports.askAI = onRequest(
  {
    secrets:        [GEMINI_API_KEY],
    timeoutSeconds: 120,
    memory:         "512MiB",
    cors:           true,
  },
  async (req, res) => {

    // ── 1. Method guard ──────────────────────────────────────────────────────
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    // ── 2. Firebase Auth token verification ──────────────────────────────────
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

    let uid = null;
    let isPremium = false;

    if (token) {
      try {
        const decoded = await admin.auth().verifyIdToken(token);
        uid = decoded.uid;
        // Premium flag can be stored in custom claims (set via Admin SDK when purchase verified)
        isPremium = decoded.premium === true;
      } catch (e) {
        return res.status(401).json({ error: "Invalid auth token." });
      }
    } else {
      // No token — reject. Internal testers can use a service-account-signed token.
      return res.status(401).json({ error: "Authorization required." });
    }

    // ── 3. Load config ────────────────────────────────────────────────────────
    const config = await getConfig();

    // ── 4. Emergency kill switch ──────────────────────────────────────────────
    if (!config.enabled) {
      return res.status(503).json({
        error: "AI assistant is temporarily offline. Please try again later.",
      });
    }

    // ── 5. Validate request body ──────────────────────────────────────────────
    const { prompt, model: requestedModel, type = "chat" } = req.body;

    if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
      return res.status(400).json({ error: "Prompt required." });
    }
    if (prompt.length > 20_000) {
      return res.status(400).json({ error: "Prompt too long." });
    }

    // ── 6. Model routing ──────────────────────────────────────────────────────
    // Client suggests a model; server validates against whitelist and overrides
    // non-premium users attempting to use Pro.
    let model = config.flash_model;
    if (requestedModel && ALLOWED_MODELS.has(requestedModel)) {
      model = requestedModel;
    }
    // Downgrade: non-premium users never get Pro
    if (model === config.pro_model && !isPremium) {
      model = config.flash_model;
    }

    // ── 7. Per-UID rate limiting ──────────────────────────────────────────────
    const usageRef = db.collection("ai_usage").doc(uid);
    const today    = todayUTC();
    const featureLimit = getFeatureLimit(type, isPremium);

    let featureCount  = 0;
    let lastRequestAt = null;

    try {
      const usageSnap = await usageRef.get();
      if (usageSnap.exists) {
        const data        = usageSnap.data();
        // request_types counts reset implicitly when date differs (new day = 0).
        const typeCounts  = data.date === today ? (data.request_types ?? {}) : {};
        featureCount      = typeCounts[type] ?? 0;
        lastRequestAt     = data.last_request_at?.toDate?.() ?? null;
      }
    } catch (e) {
      // Firestore read error — fail open (don't block user due to DB issue)
      console.warn(`[askAI] usage read error for uid=${uid}: ${e.message}`);
    }

    // 7a. Cooldown check
    if (lastRequestAt) {
      const elapsedSeconds = (Date.now() - lastRequestAt.getTime()) / 1000;
      if (elapsedSeconds < config.cooldown_seconds) {
        const remaining = Math.ceil(config.cooldown_seconds - elapsedSeconds);
        return res.status(429).json({
          error: `Please wait ${remaining}s before the next request.`,
          cooldown: true,
        });
      }
    }

    // 7b. Per-feature quota check (daily_count is analytics-only; gating uses request_types[type])
    const limitLabel = featureLimit === Infinity ? "∞" : featureLimit;
    console.log(`[askAI] quota: type=${type} count=${featureCount}/${limitLabel} premium=${isPremium} uid=${uid}`);
    if (featureLimit !== Infinity && featureCount >= featureLimit) {
      return res.status(429).json({
        error: isPremium
          ? `Daily ${type} limit reached. Resets at midnight UTC.`
          : `Daily ${type} limit reached (${featureLimit}/day). Upgrade to Premium for more.`,
        quota_exceeded: true,
      });
    }

    // ── 8. Call Gemini API ────────────────────────────────────────────────────
    const apiKey = GEMINI_API_KEY.value();
    // NOTE: API key is intentionally never logged.

    console.log(`[askAI] calling Gemini: model=${model} type=${type} uid=${uid} premium=${isPremium}`);

    let geminiResponse;
    try {
      geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method:  "POST",
          headers: { "Content-Type": "application/json" },
          body:    JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature:      0.7,
              maxOutputTokens:  (type === "plan" || type === "diet") ? 16384 : 1024,
              responseMimeType: (type === "plan" || type === "diet") ? "application/json" : undefined,
              // Disable thinking for structured JSON types: thinking tokens share
              // the maxOutputTokens budget, leaving <200 tokens for actual output.
              thinkingConfig:   (type === "plan" || type === "diet") ? { thinkingBudget: 0 } : undefined,
            },
          }),
        }
      );
    } catch (networkErr) {
      console.error(`[askAI] Gemini network error: ${networkErr.message}`);
      return res.status(502).json({ error: "Failed to reach AI service. Please try again." });
    }

    console.log(`[askAI] Gemini HTTP status: ${geminiResponse.status}`);

    let data;
    try {
      data = await geminiResponse.json();
    } catch (parseErr) {
      console.error(`[askAI] Failed to parse Gemini response body: ${parseErr.message}`);
      return res.status(502).json({ error: "Malformed response from AI service." });
    }

    if (data.error) {
      const code    = data.error.code || geminiResponse.status || 500;
      const message = data.error.message || "AI error.";
      // Log the full error object so Cloud Function logs show the exact Gemini error
      console.error(`[askAI] Gemini error body:`, JSON.stringify(data.error));
      // Any Gemini 4xx = non-retriable on the Flutter side; map to 400.
      // 5xx from Gemini = transient; map to 502 so Flutter retries.
      const clientCode = (code >= 400 && code < 500) ? 400 : 502;
      return res.status(clientCode).json({ error: message });
    }

    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!reply) {
      return res.status(500).json({ error: "Empty response from AI." });
    }

    // ── 9. Track usage (non-blocking) ─────────────────────────────────────────
    const updateData = {
      date:            today,
      daily_count:     admin.firestore.FieldValue.increment(1),
      total_count:     admin.firestore.FieldValue.increment(1),
      last_request_at: admin.firestore.FieldValue.serverTimestamp(),
      is_premium:      isPremium,
    };
    updateData[`request_types.${type}`] = admin.firestore.FieldValue.increment(1);

    usageRef.set(updateData, { merge: true }).catch((e) => {
      console.warn(`[askAI] usage write error: ${e.message}`);
    });

    // ── 10. Respond ──────────────────────────────────────────────────────────
    return res.status(200).json({ success: true, reply });
  }
);

// ── RFC-003: Server-side premium verification ─────────────────────────────────
//
// Called by Flutter immediately after a Play Store / App Store purchase is
// confirmed by in_app_purchase. Flow:
//   1. Verify Firebase ID token.
//   2. Call store receipt API (Play Developer API or App Store receipt validation).
//      - Explicit invalid token → 402 (purchase rejected, no binding written).
//      - Store API unreachable  → 202 PENDING_VERIFICATION (no binding written;
//        Flutter retries every 30s and on next cold start).
//   3. Token ownership check via purchase_tokens/{sha256(token)} Firestore transaction.
//      - Token already bound to a different UID → 409 TOKEN_ALREADY_BOUND.
//      - Firestore unavailable                  → 202 PENDING_VERIFICATION (retry).
//      - Token unbound or same UID              → create/update binding, continue.
//   4. Set custom claim { premium: true, premiumExpiry } via Admin SDK.
//   5. Write verified grant record to premium_grants/{uid} (non-fatal cache; the
//      purchase_tokens binding is the authoritative ownership database).
//
// Required secrets (GCP Secret Manager):
//   PLAY_SERVICE_ACCOUNT_JSON  — GCP service account JSON with androidpublisher scope
//   APPSTORE_SHARED_SECRET     — App Store Connect app-specific shared secret (hex)
//
// Firestore schema:
//   purchase_tokens/{sha256(purchaseToken)}
//     uid              string    — Firebase UID that owns this token
//     platform         string    — "android" | "ios"
//     productId        string    — "premium_monthly" | "premium_yearly"
//     firstVerifiedAt  timestamp — when the token was first bound
//     lastVerifiedAt   timestamp — most recent successful re-verification
//
// Response 200: { success: true, premiumExpiry: ISO-8601 timestamp, gracePeriod: bool }
// Response 202: { status: "PENDING_VERIFICATION", message: "..." }
// Response 402: { error: "..." }  — store rejected the purchase token
// Response 409: { error: "TOKEN_ALREADY_BOUND", message: "..." }
// Error 4xx/5xx: { error: "..." }
exports.verifyPurchase = onRequest(
  {
    // APPLE_APP_APPLE_ID is intentionally absent: it is a defineString param,
    // not a secret. Listing a non-secret param here makes the deploy fail with
    // "Secret environment variable overlaps non secret environment variable".
    // Its value comes from .env.<projectId>; the numeric App Store id is public.
    secrets:        [PLAY_SA_JSON, APPSTORE_SECRET],
    timeoutSeconds: 30,
    memory:         "256MiB",
    cors:           true,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    // 1. Firebase Auth token verification
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Authorization required." });

    let uid;
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      uid = decoded.uid;
    } catch (_) {
      return res.status(401).json({ error: "Invalid auth token." });
    }

    // 2. Validate request body
    const { productId, purchaseToken, platform } = req.body;
    // premium_yearly_v2 is the iOS yearly product id (BillingProducts.yearly
    // resolves to it on iOS). Omitting it made every iOS yearly purchase fail
    // with 400 and never grant premium — see RFC-004 F1.
    const VALID_PRODUCTS = new Set(["premium_monthly", "premium_yearly", "premium_yearly_v2"]);
    if (!productId || !VALID_PRODUCTS.has(productId)) {
      return res.status(400).json({ error: "Invalid product ID." });
    }
    if (!purchaseToken || typeof purchaseToken !== "string" || purchaseToken.trim().length === 0) {
      return res.status(400).json({ error: "Purchase token required." });
    }
    const isIos = platform === "ios";

    // 3. Verify with store API and obtain real expiry.
    //    Local estimate is the fallback when the store API is temporarily unreachable.
    // Must cover every id in VALID_PRODUCTS — a missing key yields NaN expiry.
    const FALLBACK_DAYS = { premium_yearly: 365, premium_yearly_v2: 365, premium_monthly: 32 };
    let expiryMs      = Date.now() + FALLBACK_DAYS[productId] * 24 * 60 * 60 * 1000;
    let storeVerified = false;
    let storeResult   = null; // declared outside try so it's in scope at the final return

    try {
      storeResult = isIos
        ? await verifyIosPurchase(purchaseToken)
        : await verifyAndroidPurchase(productId, purchaseToken);

      if (!storeResult.valid) {
        console.warn(`[verifyPurchase] REJECTED uid=${uid} product=${productId} platform=${isIos ? "ios" : "android"} reason=${storeResult.reason}`);
        return res.status(402).json({ error: "Purchase could not be verified with the store." });
      }

      storeVerified = true;
      if (storeResult.expiryMs && storeResult.expiryMs > Date.now()) {
        expiryMs = storeResult.expiryMs; // use real expiry from store
      }
      console.log(`[verifyPurchase] VERIFIED uid=${uid} product=${productId} realExpiry=${new Date(expiryMs).toISOString()} reason=${storeResult.reason}`);
    } catch (storeErr) {
      // Store API temporarily unreachable — return PENDING_VERIFICATION so Flutter
      // retries. Never grant premium without store confirmation.
      console.warn(`[verifyPurchase] PENDING uid=${uid} product=${productId} platform=${isIos ? "ios" : "android"}: ${storeErr.message}`);
      return res.status(202).json({ status: "PENDING_VERIFICATION", message: "Store API temporarily unavailable. Retry later." });
    }

    // Full ISO-8601 — never date-only. Truncating to YYYY-MM-DD moves the expiry
    // back to midnight, so a subscription valid until 17:21 today is read as
    // having expired 17 hours ago: the client revokes, re-verifies, is granted
    // the same truncated date, and loops without premium ever sticking. Harmless
    // for month-long production terms, fatal for short sandbox ones.
    // DateTime.tryParse on the client accepts both, so older date-only values
    // stored by previous deploys still parse correctly.
    const expiryStr = new Date(expiryMs).toISOString();

    // 4. Ownership check — one purchase token may only be bound to one Firebase UID.
    //    Prevents a shared Google/Apple account from granting premium to multiple
    //    Firebase users (two accounts on the same device sharing a Play account).
    //
    //    Firestore transaction guarantees atomicity: two concurrent first-time
    //    verifications cannot both observe "doc doesn't exist" and each bind the
    //    token to a different UID. The loser is retried by Firestore and then sees
    //    the winner's binding, triggering TOKEN_ALREADY_BOUND.
    //    Ownership key: Android uses the purchase token (stable per purchase).
    //    iOS must use original_transaction_id — the App Receipt changes on every
    //    renewal and restore, so hashing it produced a new "owner" each time and
    //    silently defeated this check (RFC-004 F2). Falls back to the receipt
    //    hash only if Apple omitted the field, preserving the previous behaviour.
    const ownershipKey = isIos
      ? (storeResult.originalTransactionId || purchaseToken)
      : purchaseToken;
    const tokenHash = crypto.createHash("sha256").update(ownershipKey).digest("hex");
    const tokenRef  = db.collection("purchase_tokens").doc(tokenHash);
    let crossAccountRejected = false;

    try {
      await db.runTransaction(async (txn) => {
        const tokenDoc = await txn.get(tokenRef);
        if (!tokenDoc.exists) {
          // First time this token is verified — bind it to the current Firebase UID.
          txn.set(tokenRef, {
            uid,
            platform:        isIos ? "ios" : "android",
            productId,
            firstVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastVerifiedAt:  admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
        const boundUid = tokenDoc.data().uid;
        if (boundUid !== uid) {
          // Token is already bound to a different Firebase UID — cross-account.
          // Setting the flag before throwing so the outer catch can distinguish
          // this intentional abort from a transient Firestore error.
          crossAccountRejected = true;
          throw new Error("TOKEN_ALREADY_BOUND");
        }
        // Same UID — legitimate re-verify or restore. Refresh the timestamp.
        txn.update(tokenRef, { lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
    } catch (txnErr) {
      if (crossAccountRejected) {
        console.warn(`[verifyPurchase] CROSS_ACCOUNT uid=${uid} product=${productId} tokenHash=${tokenHash.slice(0, 12)}…`);
        return res.status(409).json({
          error:   "TOKEN_ALREADY_BOUND",
          code:    "TOKEN_ALREADY_BOUND",
          message: "This subscription is registered to a different account.",
        });
      }
      // Transient Firestore error — tell Flutter to retry rather than silently
      // skipping the ownership check.
      console.warn(`[verifyPurchase] purchase_tokens txn failed uid=${uid}: ${txnErr.message}`);
      return res.status(202).json({ status: "PENDING_VERIFICATION", message: "Ownership check temporarily unavailable. Retry later." });
    }

    // 5. Set custom claim — this is what askAI gates on (decoded.premium === true)
    try {
      await admin.auth().setCustomUserClaims(uid, { premium: true, premiumExpiry: expiryStr });
      console.log(`[verifyPurchase] claim set: uid=${uid} product=${productId} expiry=${expiryStr} storeVerified=${storeVerified}`);
    } catch (err) {
      console.error(`[verifyPurchase] setCustomUserClaims failed uid=${uid}:`, err);
      return res.status(500).json({ error: "Failed to grant premium." });
    }

    // 6. Write grant to Firestore via Admin SDK (non-fatal cache — claim and
    //    purchase_tokens binding are already authoritative at this point).
    db.collection("premium_grants").doc(uid).set({
      productId,
      purchaseToken,
      grantedAt:    admin.firestore.FieldValue.serverTimestamp(),
      expiresAt:    expiryStr,
      platform:     isIos ? "ios" : "android",
      verified:     storeVerified,
      verifiedAt:   storeVerified ? admin.firestore.FieldValue.serverTimestamp() : null,
    }, { merge: true }).catch((err) => {
      console.warn(`[verifyPurchase] premium_grants write failed (non-fatal) uid=${uid}:`, err);
    });

    return res.status(200).json({ success: true, premiumExpiry: expiryStr, gracePeriod: storeResult.inGracePeriod ?? false });
  }
);

// ── RFC-002.4: GDPR data purge on account deletion ───────────────────────────
//
// Gen1 auth trigger (firebase-functions/v1). Runs on Node 22 — GCF Gen1
// does not support Node 24. askAI uses Gen2 (onRequest); both coexist fine.
//
// Purge order:
//   1. users/{uid} + all subcollections (logs, plans, instances,
//      measurements, _meta, favorites, history_entries) — recursiveDelete.
//   2. Top-level flat documents (legacy + server-owned).
//
// Admin SDK bypasses Firestore Security Rules — the only authorised server-side
// writer for premium_grants and entitlements (RFC-002.3).
exports.onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db  = admin.firestore();

  try {
    // 1. Recursively delete users/{uid} and every subcollection.
    await db.recursiveDelete(db.collection("users").doc(uid));
    console.log(`[onUserDeleted] users/${uid} + subcollections deleted`);
  } catch (err) {
    console.error(`[onUserDeleted] recursiveDelete users/${uid} failed:`, err);
  }

  // 2. Top-level flat documents — settle all regardless of individual errors.
  //    purchase_tokens/{tokenHash} is intentionally excluded: the binding record
  //    is keyed by the SHA-256 of the purchase token (not by UID) and must persist
  //    so the same token cannot be re-bound to a new account after deletion.
  const topLevel = [
    db.collection("workout_history").doc(uid),
    db.collection("premium_grants").doc(uid),
    db.collection("ai_usage").doc(uid),
    db.collection("entitlements").doc(uid),
  ];

  const results = await Promise.allSettled(topLevel.map((ref) => ref.delete()));
  results.forEach((r, i) => {
    if (r.status === "rejected") {
      console.warn(`[onUserDeleted] top-level delete[${i}] failed:`, r.reason);
    }
  });

  console.log(`[onUserDeleted] purge complete for uid=${uid}`);
});
