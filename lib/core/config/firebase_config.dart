import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  static String _env(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static bool get isEnabled =>
      _env('FIREBASE_ENABLED', fallback: 'true').toLowerCase() == 'true';

  static bool get useEmulator =>
      _env('FIREBASE_USE_EMULATOR', fallback: 'false').toLowerCase() == 'true';

  static String get firestoreHost =>
      _env('FIRESTORE_EMULATOR_HOST', fallback: 'localhost');

  static int get firestorePort =>
      int.tryParse(_env('FIRESTORE_EMULATOR_PORT')) ?? 8080;

  static String get authHost => _env('AUTH_EMULATOR_HOST', fallback: 'localhost');

  static int get authPort => int.tryParse(_env('AUTH_EMULATOR_PORT')) ?? 9099;

  static bool get fcmEnabled =>
      _env('FCM_ENABLED', fallback: 'false').toLowerCase() == 'true';

  static String get apiKeysCollection =>
      _env('FIREBASE_KEYS_COLLECTION', fallback: 'app_runtime');

  static String get apiKeysDocument =>
      _env('FIREBASE_KEYS_DOCUMENT', fallback: 'api_keys');

  static bool get isInitialized => true;

  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('[FirebaseConfig] initialize() is handled by FirebaseBootstrapService.');
    }
  }

  static Future<bool> validateConnection() async {
    return isEnabled;
  }

  static Map<String, String> getProjectInfo() {
    return <String, String>{
      'status': isEnabled ? 'Configured' : 'Disabled',
      'apiKeysCollection': apiKeysCollection,
      'apiKeysDocument': apiKeysDocument,
      'emulator': useEmulator ? 'enabled' : 'disabled',
    };
  }
}
