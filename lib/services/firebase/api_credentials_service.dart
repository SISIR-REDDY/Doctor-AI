import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
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

  // All possible field names for Gemini API key
  static const List<String> _geminiKeyFields = [
    'geminiApiKey',
    'gemini_api_key',
    'GEMINI_API_KEY',
    'geminiKey',
    'gemini_key',
    'aiApiKey',
    'ai_api_key',
  ];

  // All possible field names for Deepgram API key
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

  Future<String> getGeminiApiKey({bool forceRefresh = true}) async {
    final creds = await _load(forceRefresh: forceRefresh);
    return creds.geminiApiKey;
  }

  Future<String> getDeepgramApiKey({bool forceRefresh = true}) async {
    final creds = await _load(forceRefresh: forceRefresh);
    return creds.deepgramApiKey;
  }

  Future<bool> hasKeys({bool forceRefresh = true}) async {
    try {
      final creds = await _load(forceRefresh: forceRefresh);
      return creds.geminiApiKey.isNotEmpty && creds.deepgramApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<ApiCredentials> _load({bool forceRefresh = false}) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      clearCache();
      throw AppException(
        code: 'not-authenticated',
        message: 'Sign in is required before loading runtime API keys.',
      );
    }

    if (!forceRefresh) {
      if (_cached != null && _cachedUserId == userId) {
        return _cached!; // Still allow explicit cache use when requested.
      }

      if (_cachedUserId != null && _cachedUserId != userId) {
        clearCache();
      }
    }

    // Always load from Firestore (no local key sources).
    final primaryCreds = await _loadFromAllPossibleLocations();
    if (primaryCreds != null) {
      _cached = primaryCreds;
      _cachedUserId = userId;
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] ✅ Keys loaded from: ${primaryCreds.source}');
      }
      return primaryCreds;
    }

    throw AppException(
      code: 'api-keys-unavailable',
      message:
          'API keys not configured in Firebase. Please add geminiApiKey and deepgramApiKey to collection: app_runtime, document: api_keys.',
    );
  }

  Future<ApiCredentials?> _loadFromAllPossibleLocations() async {
    if (!FirebaseConfig.isEnabled || !FirebaseBootstrapService.isInitialized) {
      return null;
    }

    final firestore = _primaryFirestore;
    if (firestore == null) return null;

    // Only use the configured Firestore location.
    final envCreds = await _tryLoadFromPath(
      firestore,
      FirebaseConfig.apiKeysCollection,
      FirebaseConfig.apiKeysDocument,
    );
    if (envCreds != null) return envCreds;

    return null;
  }

  Future<ApiCredentials?> _tryLoadFromPath(
    FirebaseFirestore firestore,
    String collection,
    String document,
  ) async {
    try {
        final snapshot = await firestore
          .collection(collection)
          .doc(document)
          .get(const GetOptions(source: Source.server));

      final data = snapshot.data();
      if (data == null) return null;

      // Try all possible field names for Gemini key
      String? gemini;
      for (final field in _geminiKeyFields) {
        final value = _sanitizeKey(data[field] as String?);
        if (value.isNotEmpty) {
          gemini = value;
          break;
        }
      }

      // Try all possible field names for Deepgram key
      String? deepgram;
      for (final field in _deepgramKeyFields) {
        final value = _sanitizeKey(data[field] as String?);
        if (value.isNotEmpty) {
          deepgram = value;
          break;
        }
      }

      if (gemini == null || gemini.isEmpty || deepgram == null || deepgram.isEmpty) {
        return null;
      }

      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] Found keys at $collection/$document');
      }

      return ApiCredentials(
        geminiApiKey: gemini,
        deepgramApiKey: deepgram,
        source: 'firestore:$collection/$document',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] Error reading $collection/$document: $e');
      }
      return null;
    }
  }

  FirebaseFirestore? get _primaryFirestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _sanitizeKey(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('your_')) return '';
    if (value.contains('placeholder')) return '';
    if (value.contains('YOUR_')) return '';
    if (value.contains('PLACEHOLDER')) return '';
    if (value == 'null') return '';
    if (value == 'undefined') return '';
    return value;
  }
}
