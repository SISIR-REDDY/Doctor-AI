import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import '../../firebase_options.dart';

class FirebaseBootstrapService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!FirebaseConfig.isEnabled || _initialized) return;

    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[Firebase] Already initialized, skipping...');
      }
      return;
    }

    try {
      // Always pass the correct Firebase options for the current platform
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kDebugMode) {
        debugPrint('[Firebase] Initialized with project: ${Firebase.app().options.projectId}');
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // App Check: proves requests come from a genuine build of this app.
      // Debug builds use the debug provider (register the printed token in
      // Firebase console → App Check → Manage debug tokens). Release builds
      // use Play Integrity / App Attest. The backend only *enforces* App
      // Check once `app_runtime/config.enforceAppCheck` is true.
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Firebase] App Check activation failed: $e');
      }

      if (FirebaseConfig.useEmulator) {
        await FirebaseAuth.instance
            .useAuthEmulator(FirebaseConfig.authHost, FirebaseConfig.authPort);
        FirebaseFirestore.instance.useFirestoreEmulator(
          FirebaseConfig.firestoreHost,
          FirebaseConfig.firestorePort,
        );
      }

      _initialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase initialization skipped: $error');
      }
      _initialized = false;
    }
  }
}
