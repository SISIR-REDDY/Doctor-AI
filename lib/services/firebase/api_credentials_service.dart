import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import 'auth_service.dart';
import 'firebase_bootstrap_service.dart';

class ApiCredentials {
  final String geminiApiKey;
  final String deepgramApiKey;
  final String source;

  const ApiCredentials({
    required this.geminiApiKey,
    required this.deepgramApiKey,
    required this.source,
  });
}

class ApiCredentialsService {
  ApiCredentialsService._();

  static final ApiCredentialsService instance = ApiCredentialsService._();

  ApiCredentials? _cached;
  String? _cachedUserId;

  // Field names accepted on the Firestore api_keys document.
  static const List<String> _geminiKeyFields = [
    'geminiApiKey',
    'gemini_api_key',
    'GEMINI_API_KEY',
    'geminiKey',
    'gemini_key',
    'aiApiKey',
    'ai_api_key',
  ];

  static const List<String> _deepgramKeyFields = [
    'deepgramApiKey',
    'deepgram_api_key',
    'DEEPGRAM_API_KEY',
    'deepgramKey',
    'deepgram_key',
    'speechApiKey',
    'speech_api_key',
  ];

  void clearCache() {
    _cached = null;
    _cachedUserId = null;
  }

  Future<void> preload() async {
    try {
      await _load(forceRefresh: true);
    } catch (_) {}
  }

  Future<String> getGeminiApiKey({bool forceRefresh = false}) async {
    final creds = await _load(forceRefresh: forceRefresh);
    return creds.geminiApiKey;
  }

  Future<String> getDeepgramApiKey({bool forceRefresh = false}) async {
    final creds = await _load(forceRefresh: forceRefresh);
    return creds.deepgramApiKey;
  }

  Future<bool> hasKeys({bool forceRefresh = false}) async {
    try {
      final creds = await _load(forceRefresh: forceRefresh);
      return creds.geminiApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasDeepgramKey({bool forceRefresh = false}) async {
    try {
      final creds = await _load(forceRefresh: forceRefresh);
      return creds.deepgramApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<ApiCredentials> _load({bool forceRefresh = false}) async {
    final userId = AuthService().currentUser?.uid;

    if (!forceRefresh && _cached != null) {
      if (userId == null || _cachedUserId == userId) {
        return _cached!;
      }
      clearCache();
    }

    if (userId == null || userId.isEmpty) {
      throw Exception(
        'Sign in to load API keys from Firebase.\n\n'
        'Keys are stored in Firestore at:\n'
        '  ${FirebaseConfig.apiKeysCollection}/${FirebaseConfig.apiKeysDocument}',
      );
    }

    if (!FirebaseConfig.isEnabled || !FirebaseBootstrapService.isInitialized) {
      throw Exception('Firebase is not initialized. Restart the app and try again.');
    }

    final firestoreCreds = await _loadFromFirestore();
    if (firestoreCreds != null) {
      _cached = firestoreCreds;
      _cachedUserId = userId;
      if (kDebugMode) {
        debugPrint(
          '[ApiCredentialsService] ✅ Keys from Firestore: ${firestoreCreds.source}',
        );
      }
      return firestoreCreds;
    }

    throw Exception(
      'API keys not found in Firebase Firestore.\n\n'
      'Add them in the Firebase console:\n'
      '  Collection: ${FirebaseConfig.apiKeysCollection}\n'
      '  Document:   ${FirebaseConfig.apiKeysDocument}\n'
      '  Fields:     geminiApiKey, deepgramApiKey',
    );
  }

  Future<ApiCredentials?> _loadFromFirestore() async {
    final firestore = _firestoreInstance;
    if (firestore == null) return null;

    try {
      final snapshot = await firestore
          .collection(FirebaseConfig.apiKeysCollection)
          .doc(FirebaseConfig.apiKeysDocument)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));

      final data = snapshot.data();
      if (data == null) return null;

      String? gemini;
      for (final field in _geminiKeyFields) {
        final v = _sanitize(data[field] as String?);
        if (v.isNotEmpty) {
          gemini = v;
          break;
        }
      }

      String? deepgram;
      for (final field in _deepgramKeyFields) {
        final v = _sanitize(data[field] as String?);
        if (v.isNotEmpty) {
          deepgram = v;
          break;
        }
      }

      if (gemini == null) return null;

      return ApiCredentials(
        geminiApiKey: gemini,
        deepgramApiKey: deepgram ?? '',
        source:
            'firestore:${FirebaseConfig.apiKeysCollection}/${FirebaseConfig.apiKeysDocument}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] Firestore error: $e');
      }
      return null;
    }
  }

  FirebaseFirestore? get _firestoreInstance {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _sanitize(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower.startsWith('your_')) return '';
    if (lower.startsWith('your-')) return '';
    if (lower.contains('placeholder')) return '';
    if (lower == 'null' || lower == 'undefined' || lower == 'none') return '';
    if (v.contains('_api_key_here')) return '';
    if (v.contains('_KEY_HERE')) return '';
    return v;
  }
}
