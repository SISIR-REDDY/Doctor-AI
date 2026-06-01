import 'package:flutter/foundation.dart';

/// Firebase project settings — API keys are loaded from Firestore, not local files.
class FirebaseConfig {
  static const bool isEnabled = true;
  static const bool useEmulator = false;
  static const String firestoreHost = 'localhost';
  static const int firestorePort = 8080;
  static const String authHost = 'localhost';
  static const int authPort = 9099;
  static const bool fcmEnabled = false;
  static const String apiKeysCollection = 'app_runtime';
  static const String apiKeysDocument = 'api_keys';

  static const bool isInitialized = true;

  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint(
        '[FirebaseConfig] initialize() is handled by FirebaseBootstrapService.',
      );
    }
  }

  static Future<bool> validateConnection() async => isEnabled;

  static Map<String, String> getProjectInfo() {
    return <String, String>{
      'status': isEnabled ? 'Configured' : 'Disabled',
      'apiKeysCollection': apiKeysCollection,
      'apiKeysDocument': apiKeysDocument,
      'emulator': useEmulator ? 'enabled' : 'disabled',
    };
  }
}
