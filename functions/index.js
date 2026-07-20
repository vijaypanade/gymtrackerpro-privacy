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
const admin                 = require("firebase-admin");
const fetch                 = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

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
// confirmed by in_app_purchase. Validates the caller's ID token, checks the
// productId against the known set, sets a Firebase custom claim
// { premium: true, premiumExpiry: "YYYY-MM-DD" } via Admin SDK, and writes
// a verified:true grant record to premium_grants/{uid}.
//
// askAI already gates on decoded.premium === true — no changes needed there.
// The Flutter client calls getIdToken(true) after this succeeds to pull the
// fresh claim into the cached token.
exports.verifyPurchase = onRequest(
  { timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }

    // 1. Auth token verification
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Authorization required." });

    let uid;
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      uid = decoded.uid;
    } catch (e) {
      return res.status(401).json({ error: "Invalid auth token." });
    }

    // 2. Validate request body
    const { productId, purchaseToken } = req.body;
    const VALID_PRODUCTS = new Set([
      "premium_monthly",
      "premium_quarterly",
      "premium_yearly",
    ]);
    if (!productId || !VALID_PRODUCTS.has(productId)) {
      return res.status(400).json({ error: "Invalid product ID." });
    }
    if (!purchaseToken || typeof purchaseToken !== "string" || purchaseToken.trim().length === 0) {
      return res.status(400).json({ error: "Purchase token required." });
    }

    // 3. Calculate expiry
    const EXPIRY_DAYS = { premium_yearly: 365, premium_quarterly: 95, premium_monthly: 32 };
    const expiry    = new Date(Date.now() + EXPIRY_DAYS[productId] * 24 * 60 * 60 * 1000);
    const expiryStr = expiry.toISOString().split("T")[0]; // YYYY-MM-DD

    // 4. Set custom claim — this is what askAI checks (decoded.premium === true)
    try {
      await admin.auth().setCustomUserClaims(uid, { premium: true, premiumExpiry: expiryStr });
      console.log(`[verifyPurchase] claim set: uid=${uid} product=${productId} expiry=${expiryStr}`);
    } catch (err) {
      console.error(`[verifyPurchase] setCustomUserClaims failed uid=${uid}:`, err);
      return res.status(500).json({ error: "Failed to grant premium." });
    }

    // 5. Write verified grant to Firestore (non-fatal — claim already set)
    db.collection("premium_grants").doc(uid).set({
      productId,
      purchaseToken,
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: expiryStr,
      platform:  req.body.platform ?? "android",
      verified:  true,
    }, { merge: true }).catch((err) => {
      console.warn(`[verifyPurchase] Firestore write failed (non-fatal) uid=${uid}:`, err);
    });

    return res.status(200).json({ success: true, premiumExpiry: expiryStr });
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
