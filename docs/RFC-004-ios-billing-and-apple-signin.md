# RFC-004 — iOS Billing Correctness & Apple Sign-In Identity

**Status:** Approved (owner-directed, 2026-07-25)
**Scope:** `functions/index.js`, `lib/services/billing_service.dart`,
`ios/Runner/RunnerDebug.entitlements`, `lib/services/auth_service.dart`

Derived from the audit of two reported defects:
1. iOS TestFlight — purchase completes, Profile still shows the Upgrade card.
2. Apple Sign-In does not attach an email address; Google Sign-In does.

---

## F1 — iOS yearly purchases can never be granted (Blocker)

**Evidence**
- `lib/services/billing_service.dart:35` — iOS yearly product id is `premium_yearly_v2`.
- `functions/index.js:460` — `VALID_PRODUCTS` = `{premium_monthly, premium_yearly}`.
- `functions/index.js:471` — `FALLBACK_DAYS` has no `premium_yearly_v2` key.
- `lib/services/billing_service.dart:487-522` — handlers exist for 200/202/402/409
  only; 400 falls through to the generic branch and returns `pending`.

**Failure chain**
iOS yearly purchase → CF returns `400 Invalid product ID` → Flutter maps 400 to
`_VerifyOutcome.pending` → 30 s retry timer runs forever → premium never granted.
Both paywalls default to the yearly plan (`premium_screen.dart:27`,
`premium_paywall_screen.dart:126`), so this is the default iOS purchase path.

**Change**
- Add `premium_yearly_v2` to `VALID_PRODUCTS`.
- Add `premium_yearly_v2: 365` to `FALLBACK_DAYS` (prevents `undefined → NaN`
  expiry once the whitelist accepts the id — the two must land together).
- Flutter: handle `400` explicitly as `rejected`, not `pending`. A malformed
  request is deterministic; retrying cannot change the outcome and the silent
  infinite retry is what hides the failure from the user.

---

## F2 — Cross-provider premium loss + ineffective iOS ownership binding

**Evidence**
- `functions/index.js:508` — ownership key is `sha256(purchaseToken)`.
  On iOS `purchaseToken` is the full App Receipt, which is regenerated on
  renewal and restore, so the hash is not stable for a subscription.
- `functions/index.js:199-206` — `verifyIosPurchase` never extracts
  `original_transaction_id`.
- `functions/index.js:527-540` — a UID mismatch returns `409`.
- `lib/services/billing_service.dart:513-517` — `409` maps to `rejected`, which
  runs `_clearPremiumStatus()` and shows the generic store-rejection message.
- No `linkWithCredential` / `fetchSignInMethodsForEmail` anywhere in `lib/`, so
  the same person signing in with Google and with Apple holds two distinct UIDs.

**Consequences**
- iOS cross-account protection does not actually work (a fresh receipt yields a
  fresh hash), while `purchase_tokens` accumulates orphaned documents.
- A user who subscribed under one provider and later signs in with the other is
  permanently rejected with a message that does not explain the cause or the fix.
  On iOS the App Store subscription belongs to the Apple ID regardless of which
  in-app login is used, so this is a realistic path.

**Change**
- `verifyIosPurchase` returns `originalTransactionId` from
  `latest_receipt_info[0].original_transaction_id`.
- Ownership key becomes `sha256(originalTransactionId)` on iOS and stays
  `sha256(purchaseToken)` on Android. Existing iOS binding documents are
  orphaned by design — they never matched across receipt refreshes, so no
  entitlement regression is possible.
- The `409` response body carries a machine-readable `code`, and Flutter
  surfaces a distinct, actionable message naming the recovery step
  (sign in with the original account / contact support) instead of the generic
  "could not be verified" text.

---

## F3 — Apple Sign-In capability missing from Debug and Profile builds

**Evidence**
- `ios/Runner/Runner.entitlements` (Release) declares
  `com.apple.developer.applesignin`.
- `ios/Runner/RunnerDebug.entitlements` does not.
- `ios/Runner.xcodeproj/project.pbxproj` — Debug and Profile configurations of
  the Runner target both point at `RunnerDebug.entitlements`.

Apple Sign-In therefore fails on local `flutter run` builds and only works in
Release/TestFlight. Google Sign-In needs no entitlement, which is why the two
providers behave differently during development.

**Change** Add the `applesignin` entitlement to `RunnerDebug.entitlements` so
Debug and Profile match Release.

---

## F4 — Apple email is never captured

**Evidence**
- `lib/services/auth_service.dart:66` requests the email scope.
- That is the only occurrence of the string `email` in all of `lib/`.
- `auth_service.dart:80-90` persists the Apple-supplied name via
  `updateDisplayName()` precisely because Apple returns it only on the first
  authorization, but performs no equivalent for the email.

Apple returns the email only on first authorization; Google returns it on every
sign-in. When Firebase does not auto-populate it (re-authorization after the
Firebase record was removed, or Hide My Email), the account is left with no
email and no fallback — and no way to relate it to the user's other provider
account, which is what makes F2 unrecoverable in practice.

**Change** On Apple sign-in, if the Firebase user has no email and the Apple
credential supplied one, persist it with `verifyBeforeUpdateEmail` semantics not
being applicable here — use `updatePhotoURL`-style direct profile write via
`user.updateEmail` is unsafe/deprecated, so instead record the credential email
on the Firestore user document for support-side account recovery. Firebase Auth
remains the identity source; this is a recovery breadcrumb only.

**Note:** Hide My Email relay addresses require Apple Developer + Firebase relay
configuration and are out of scope for a code change.

---

## Out of scope

- Wiring `premium_paywall_screen.dart` into navigation, and the premature
  "Welcome to Premium" toast in `premium_screen.dart:392` (tracked separately).
- Automatic Google↔Apple account linking.

## Verification

- `flutter analyze` clean.
- iOS monthly and yearly purchase both reach `✅ RFC-003: store verified`.
- CF logs show `VERIFIED` for `premium_yearly_v2`.
- Apple Sign-In succeeds on a Debug build.
