import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ IMPORTANT: Single instance (NO clientId for Android)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

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

  // 🚪 SIGN OUT
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("SignOut Error: $e");
    }
  }
}