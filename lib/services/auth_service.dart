import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ IMPORTANT: Single instance (NO clientId for Android)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  // Diagnostic only. Set when signInWithApple() fails for any reason other than
  // the user cancelling, so the caller can show the real cause instead of a
  // generic message. Needed because debugPrint is not readable on TestFlight.
  String? lastAppleError;

  // 🔐 GOOGLE SIGN-IN
  Future<User?> signInWithGoogle() async {
    try {
      // 👉 ensure fresh login every time (optional but safer)
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account =
          await _googleSignIn.signIn();

      if (account == null) {
        debugPrint("User cancelled login");
        return null;
      }

      final GoogleSignInAuthentication authentication =
          await account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: authentication.idToken,
        accessToken: authentication.accessToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;

    } catch (e) {
      debugPrint("🔥 Google Sign-In Error: $e");
      return null;
    }
  }

  // 🍎 SIGN IN WITH APPLE (RFC-IOS-APPLE-SIGNIN-001)
  //
  // A raw nonce is sent to Apple as its SHA-256 hash; Firebase verifies the
  // raw nonce against the hash embedded in the returned identityToken. This
  // binds the Apple credential to this sign-in attempt (replay protection).
  Future<User?> signInWithApple() async {
    lastAppleError = null;
    try {
      final rawNonce = _generateNonce();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:  appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await _auth.signInWithCredential(oauthCredential);

      // Apple only provides the name on the FIRST authorization — persist it
      // to the Firebase profile so later sessions have a displayName.
      final user = userCredential.user;
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        final name = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].whereType<String>().join(' ').trim();
        if (name.isNotEmpty) await user.updateDisplayName(name);
      }

      // Same one-shot rule applies to the email: Apple returns it only on the
      // first authorization, whereas Google returns it on every sign-in. If
      // Firebase did not populate user.email from the identity token (re-auth
      // after the Firebase record was removed, or Hide My Email), the account is
      // left with no email at all and no way to relate it to the same person's
      // other provider account — which is what makes a cross-provider
      // subscription rejection unrecoverable. Record it as a support-side
      // breadcrumb; Firebase Auth remains the identity source. RFC-004 F4.
      // Fire-and-forget. A Firestore write's future resolves on server ack, so
      // awaiting it hangs sign-in indefinitely on a slow or offline network —
      // the same hazard app_provider.dart already guards with .ignore() on
      // backfillHistoryIfNeeded(). Sign-in must not depend on a breadcrumb.
      if (user != null) {
        _recordAppleEmail(user, appleCredential.email).ignore();
      }

      return user;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled — same silent-null contract as signInWithGoogle().
      if (e.code == AuthorizationErrorCode.canceled) return null;
      // Raised by Apple itself, before Firebase is involved. Points at the
      // entitlement / provisioning profile / device Apple-ID side.
      lastAppleError = 'Apple ${e.code.name}: ${e.message}';
      debugPrint('🍎 Apple Sign-In Error: ${e.code} — ${e.message}');
      return null;
    } on FirebaseAuthException catch (e) {
      // Apple succeeded and Firebase refused the credential. Distinct cause and
      // distinct fix, so it must not be collapsed into the generic branch.
      lastAppleError = 'Firebase ${e.code}: ${e.message}';
      debugPrint('🍎 Firebase Auth Error: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      lastAppleError = '${e.runtimeType}: $e';
      debugPrint('🍎 Apple Sign-In Error: ${e.runtimeType} — $e');
      return null;
    }
  }

  // Writes the Apple-supplied email to users/{uid} under a dedicated key so it
  // never collides with the 'profile' map that tryRestoreFromCloud() reads.
  // Non-fatal by design: sign-in must succeed even if this write fails, and a
  // doc carrying only this field still counts as "no cloud profile" for restore.
  Future<void> _recordAppleEmail(User user, String? appleEmail) async {
    final email = appleEmail ?? user.email;
    if (email == null || email.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'authEmail':    email,
        'authProvider': 'apple',
        // A Hide My Email relay cannot be matched against a Google account, so
        // flag it — support needs to know the address is not the real one.
        'authEmailIsPrivateRelay': email.endsWith('@privaterelay.appleid.com'),
        'updatedAt':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('🍎 Apple email breadcrumb write failed (non-fatal): $e');
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // 🚪 SIGN OUT
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("SignOut Error: $e");
    }
  }

  // RFC-002.4 — permanently delete the Firebase Auth account.
  //
  // Firebase requires recent authentication before user.delete().
  // Re-authenticates via Google (always interactive — silent re-auth returns
  // stale/null idTokens on iOS and causes reauthenticate to throw).
  // After deletion the onUserDeleted Cloud Function purges all Firestore data.
  //
  // Returns true on success, false if the user cancelled or an error occurred.
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Attempt direct deletion first.
      // Works when the Firebase token is fresh (signed in recently).
      // Throws requires-recent-login when the session is too old.
      try {
        await user.delete();
        await _googleSignIn.signOut();
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') {
          debugPrint('deleteAccount direct-delete error: ${e.code} — $e');
          return false;
        }
        // Token too old — fall through to interactive re-auth.
      }

      // Always use interactive sign-in for re-auth.
      // signInSilently() returns cached credentials whose idToken is often null
      // on iOS, which makes reauthenticateWithCredential throw silently.
      await _googleSignIn.signOut(); // clear any stale cached state first
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // user cancelled

      final googleAuth = await account.authentication;
      final idToken    = googleAuth.idToken;
      if (idToken == null) {
        debugPrint('deleteAccount: idToken is null after re-auth');
        return false;
      }

      final credential = GoogleAuthProvider.credential(
        idToken:     idToken,
        accessToken: googleAuth.accessToken,
      );

      await user.reauthenticateWithCredential(credential);
      await user.delete();
      await _googleSignIn.signOut();
      return true;
    } catch (e) {
      debugPrint('deleteAccount error: ${e.runtimeType} — $e');
      return false;
    }
  }
}