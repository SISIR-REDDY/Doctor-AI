import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import 'api_credentials_service.dart';
import 'firebase_bootstrap_service.dart';
import 'firestore_service.dart';

class AuthService {
  // google_sign_in v6 — create a single instance with both client IDs.
  // clientId  → used on iOS/macOS (native OAuth client)
  // serverClientId → used on Android (web/server client for ID token)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '873559957687-emljucvb770bsvosgcbq81bajcbmfn7l.apps.googleusercontent.com',
    serverClientId:
        '873559957687-41ubt16p8uggr8qoqal06umdfnhnpbt4.apps.googleusercontent.com',
  );

  // ── Firebase helpers ──────────────────────────────────────────────────────

  Stream<User?> authStateChanges() =>
      _auth?.authStateChanges() ?? const Stream<User?>.empty();

  User? get currentUser => _auth?.currentUser;

  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  FirebaseAuth? get _auth {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw AppException(
        code: 'firebase-not-configured',
        message: 'Firebase is not configured. Please check your setup.',
      );
    }
    return auth;
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<UserCredential> signInWithGoogle() async {
    final auth = _requireAuth();

    if (kDebugMode) debugPrint('[Auth] Starting Google Sign-In...');

    // signIn() shows the account picker on all platforms (iOS, Android, web).
    // Returns null if the user cancels.
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      // User dismissed the account picker.
      throw AppException(
        code: 'google-sign-in-canceled',
        message: 'Sign-in was cancelled.',
      );
    }

    if (kDebugMode) debugPrint('[Auth] Google account: ${googleUser.email}');

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final String? idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AppException(
        code: 'google-auth-no-token',
        message:
            'Could not get a sign-in token from Google. Please try again.',
      );
    }

    final OAuthCredential credential =
        GoogleAuthProvider.credential(idToken: idToken);

    final UserCredential userCredential =
        await auth.signInWithCredential(credential).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw AppException(
        code: 'firebase-sign-in-timeout',
        message: 'Sign-in timed out. Check your internet connection.',
      ),
    );

    if (kDebugMode) {
      debugPrint('[Auth] Firebase sign-in OK: ${userCredential.user?.email}');
    }

    return userCredential;
  }

  // ── Apple Sign-In ─────────────────────────────────────────────────────────

  Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw AppException(
        code: 'apple-not-supported',
        message: 'Apple Sign-In is only available on iOS.',
      );
    }

    final auth = _requireAuth();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return auth.signInWithCredential(oauthCredential);
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await FirestoreService.clearAllCaches();
    ApiCredentialsService.instance.clearCache();

    await Future.wait<void>([
      _auth?.signOut().catchError((_) {}) ?? Future.value(),
      _googleSignIn.signOut().catchError((_) => null),
    ]).timeout(const Duration(seconds: 10), onTimeout: () => []);

    if (kDebugMode) debugPrint('[Auth] Signed out.');
  }
}
