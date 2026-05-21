import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/config/firebase_config.dart';
import '../firebase/firebase_bootstrap_service.dart';

class FhirConfig {
  final String baseUrl;
  final String accessToken;
  final String clientId;
  final String redirectUri;
  final String scopes;
  final String source;

  const FhirConfig({
    required this.baseUrl,
    required this.accessToken,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    required this.source,
  });

  bool get isConfigured => baseUrl.isNotEmpty && accessToken.isNotEmpty;
}

class FhirConfigService {
  static const String defaultEpicBaseUrl =
      'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4';

  FhirConfig? _cached;

  Future<FhirConfig?> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached;

    final fromFirestore = await _loadFromFirestore();
    if (fromFirestore != null) {
      _cached = fromFirestore;
      return fromFirestore;
    }

    final fromEnv = _loadFromEnv();
    if (fromEnv != null) {
      _cached = fromEnv;
      return fromEnv;
    }

    return null;
  }

  Future<FhirConfig?> _loadFromFirestore() async {
    if (!FirebaseConfig.isEnabled || !FirebaseBootstrapService.isInitialized) {
      return null;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final collection = _env('FHIR_CONFIG_COLLECTION', fallback: 'app_runtime');
      final document = _env('FHIR_CONFIG_DOCUMENT', fallback: 'fhir_config');
      final snapshot = await firestore.collection(collection).doc(document).get();
      final data = snapshot.data();
      if (data == null) return null;

      final baseUrl = _stringValue(data['baseUrl']) ?? defaultEpicBaseUrl;
      final accessToken = _stringValue(data['accessToken']) ?? '';
      final clientId = _stringValue(data['clientId']) ?? '';
      final redirectUri = _stringValue(data['redirectUri']) ?? '';
      final scopes = _stringValue(data['scopes']) ?? '';

      return FhirConfig(
        baseUrl: baseUrl.trim(),
        accessToken: accessToken.trim(),
        clientId: clientId.trim(),
        redirectUri: redirectUri.trim(),
        scopes: scopes.trim(),
        source: 'firestore:$collection/$document',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FhirConfigService] Failed to load config: $e');
      }
      return null;
    }
  }

  FhirConfig? _loadFromEnv() {
    try {
      final baseUrl = _env('FHIR_BASE_URL', fallback: defaultEpicBaseUrl).trim();
      final accessToken = _env('FHIR_ACCESS_TOKEN').trim();
      final clientId = _env('FHIR_CLIENT_ID').trim();
      final redirectUri = _env('FHIR_REDIRECT_URI').trim();
      final scopes = _env('FHIR_SCOPES').trim();

      if (baseUrl.isEmpty && accessToken.isEmpty) return null;

      return FhirConfig(
        baseUrl: baseUrl,
        accessToken: accessToken,
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: scopes,
        source: 'env',
      );
    } catch (_) {
      return null;
    }
  }

  String _env(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? _stringValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}
