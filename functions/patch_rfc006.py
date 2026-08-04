import sys, shutil, pathlib

p = pathlib.Path("index.js")
src = p.read_text()
shutil.copy(p, "index.js.bak")

def sub(old, new, label):
    global src
    if old not in src:
        sys.exit(f"❌ ANCHOR NOT FOUND [{label}] — काहीही बदललं नाही")
    if new in src:
        print(f"⏭  already applied [{label}]"); return
    src = src.replace(old, new, 1)
    print(f"✅ {label}")

# 1 — JWS verification helper
sub(
'// purchaseToken for iOS = base64-encoded App Receipt from',
'''// ── RFC-006: StoreKit 2 JWS verification ────────────────────────────────────
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

// purchaseToken for iOS = base64-encoded App Receipt from''',
"JWS helper inserted")

# 2 — legacy फंक्शनचं नाव बदला
sub("async function verifyIosPurchase(receiptData) {",
    "async function verifyIosLegacyReceipt(receiptData) {",
    "legacy renamed")

# 3 — dispatcher
sub("// ── Main Cloud Function ──",
'''// Routes StoreKit 2 tokens to JWS verification and everything else to the
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

// ── Main Cloud Function ──''',
"dispatcher added")

p.write_text(src)
print("\\n🎉 index.js.bak मध्ये backup ठेवला")

























x



