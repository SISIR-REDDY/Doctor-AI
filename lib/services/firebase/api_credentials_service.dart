import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // All possible field names for Gemini API key (Firestore document fields)
  static const List<String> _geminiKeyFields = [
    'geminiApiKey',
    'gemini_api_key',
    'GEMINI_API_KEY',
    'geminiKey',
    'gemini_key',
    'aiApiKey',
    'ai_api_key',
  ];

  // All possible field names for Deepgram API key (Firestore document fields)
  static const List<String> _deepgramKeyFields = [
    'deepgramApiKey',
    'deepgram_api_key',
    'DEEPGRAM_API_KEY',
    'deepgramKey',
    'deepgram_key',
    'speechApiKey',
    'speech_api_key',
  ];

  // .env variable names (checked as fallback when Firestore is unavailable)
  static const List<String> _geminiEnvKeys = [
    'GEMINI_API_KEY',
    'GEMINI_KEY',
    'AI_API_KEY',
  ];
  static const List<String> _deepgramEnvKeys = [
    'DEEPGRAM_API_KEY',
    'DEEPGRAM_KEY',
    'SPEECH_API_KEY',
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
      return creds.geminiApiKey.isNotEmpty && creds.deepgramApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<ApiCredentials> _load({bool forceRefresh = false}) async {
    final userId = AuthService().currentUser?.uid;

    // Return in-memory cache if valid (same user, no forced refresh)
    if (!forceRefresh && _cached != null) {
      if (userId == null || _cachedUserId == userId) {
        return _cached!;
      }
      // Different user logged in — clear stale cache
      clearCache();
    }

    // ── Priority 1: Firestore (when signed in and Firebase available) ─────
    if (userId != null && userId.isNotEmpty) {
      final firestoreCreds = await _loadFromFirestore();
      if (firestoreCreds != null) {
        _cached = firestoreCreds;
        _cachedUserId = userId;
        if (kDebugMode) {
          debugPrint('[ApiCredentialsService] ✅ Keys from Firestore: ${firestoreCreds.source}');
        }
        return firestoreCreds;
      }
    }

    // ── Priority 2: .env file (local dev / fallback) ───────────────────────
    final envCreds = _loadFromEnv();
    if (envCreds != null) {
      // Cache env-based creds too so we don't re-read dotenv every call
      _cached = envCreds;
      _cachedUserId = userId;
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] ✅ Keys from .env');
      }
      return envCreds;
    }

    // ── No keys found anywhere ────────────────────────────────────────────
    throw Exception(
      'API keys not found.\n\n'
      'Add them to Firebase Firestore:\n'
      '  Collection: app_runtime\n'
      '  Document:   api_keys\n'
      '  Fields:     geminiApiKey, deepgramApiKey\n\n'
      'OR add them to your .env file:\n'
      '  GEMINI_API_KEY=your_key_here\n'
      '  DEEPGRAM_API_KEY=your_key_here',
    );
  }

  // ── Firestore loader ──────────────────────────────────────────────────────

  Future<ApiCredentials?> _loadFromFirestore() async {
    if (!FirebaseConfig.isEnabled || !FirebaseBootstrapService.isInitialized) {
      return null;
    }

    final firestore = _firestoreInstance;
    if (firestore == null) return null;

    try {
      // Use serverAndCache so it works offline (cache fallback) and online.
      final snapshot = await firestore
          .collection(FirebaseConfig.apiKeysCollection)
          .doc(FirebaseConfig.apiKeysDocument)
          .get(const GetOptions(source: Source.serverAndCache));

      final data = snapshot.data();
      if (data == null) return null;

      String? gemini;
      for (final field in _geminiKeyFields) {
        final v = _sanitize(data[field] as String?);
        if (v.isNotEmpty) { gemini = v; break; }
      }

      String? deepgram;
      for (final field in _deepgramKeyFields) {
        final v = _sanitize(data[field] as String?);
        if (v.isNotEmpty) { deepgram = v; break; }
      }

      if (gemini == null || deepgram == null) return null;

      return ApiCredentials(
        geminiApiKey: gemini,
        deepgramApiKey: deepgram,
        source: 'firestore:${FirebaseConfig.apiKeysCollection}/${FirebaseConfig.apiKeysDocument}',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiCredentialsService] Firestore error: $e');
      return null;
    }
  }

  // ── .env loader ───────────────────────────────────────────────────────────

  ApiCredentials? _loadFromEnv() {
    String? gemini;
    for (final key in _geminiEnvKeys) {
      final v = _sanitize(dotenv.env[key]);
      if (v.isNotEmpty) { gemini = v; break; }
    }

    String? deepgram;
    for (final key in _deepgramEnvKeys) {
      final v = _sanitize(dotenv.env[key]);
      if (v.isNotEmpty) { deepgram = v; break; }
    }

    if (gemini == null || deepgram == null) return null;

    return ApiCredentials(
      geminiApiKey: gemini,
      deepgramApiKey: deepgram,
      source: 'dotenv',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  FirebaseFirestore? get _firestoreInstance {
    try { return FirebaseFirestore.instance; } catch (_) { return null; }
  }

  /// Strips whitespace and rejects obvious placeholder values.
  String _sanitize(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower.startsWith('your_')) return '';
    if (lower.startsWith('your-')) return '';
    if (lower.contains('placeholder')) return '';
    if (lower == 'null' || lower == 'undefined' || lower == 'none') return '';
    if (v.contains('_api_key_here')) return '';   // catches 'your_api_key_here'
    if (v.contains('_KEY_HERE')) return '';
    return v;
  }
}
