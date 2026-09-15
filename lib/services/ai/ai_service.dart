import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../firebase/storage_service.dart';

/// Which backend operation a call maps to (mirrors functions/src/config.ts).
enum AiOp { analyze, audit, letter, explain, chat, generate }

/// A file attached to an AI request (image or PDF), sent inline as base64.
class AiFile {
  final String mimeType;
  final String base64Data;
  const AiFile({required this.mimeType, required this.base64Data});

  static Future<AiFile?> fromPath(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return AiFile(
        mimeType: StorageService.mimeFor(path).mime,
        base64Data: base64Encode(bytes),
      );
    } catch (e) {
      debugPrint('[AiService] read file failed: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'mimeType': mimeType, 'data': base64Data};
}

/// Thrown when the user has exhausted their plan allowance — the UI opens the
/// paywall instead of showing a generic error.
class AiQuotaException extends AppException {
  final String op;
  final String plan;
  final int limit;
  final String scope;
  AiQuotaException({
    required super.message,
    required this.op,
    required this.plan,
    required this.limit,
    required this.scope,
  }) : super(code: 'ai-quota');

  bool get isFreePlan => plan == 'free';
}

/// Client for the Clinix Cloud Functions AI backend.
///
/// Every method calls a server-side callable that holds the Gemini key,
/// versions the prompts and meters usage per plan. The app never talks to
/// the AI provider directly.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const String region = 'us-central1';
  static const Duration _timeout = Duration(seconds: 200);

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: region);

  /// Set once the backend has been observed as reachable; lets the legacy
  /// fallback in [ChatbotService] short-circuit.
  bool backendReachable = false;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final result = await callable.call<dynamic>(payload);
      backendReachable = true;
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'value': data};
    } on FirebaseFunctionsException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(FirebaseFunctionsException e) {
    final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const <String, dynamic>{};
    switch (e.code) {
      case 'resource-exhausted':
        return AiQuotaException(
          message: e.message ?? 'Usage limit reached.',
          op: '${details['op'] ?? ''}',
          plan: '${details['plan'] ?? 'free'}',
          limit: (details['limit'] as num?)?.toInt() ?? 0,
          scope: '${details['scope'] ?? 'month'}',
        );
      case 'unauthenticated':
        return AppException(code: 'ai-unauthenticated', message: 'Please sign in again to continue.');
      case 'not-found':
      case 'unimplemented':
        return AppException(
          code: 'ai-backend-missing',
          message: 'The Clinix backend is not deployed yet.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return AppException(
          code: 'ai-unavailable',
          message: e.message ?? 'The AI service is busy. Please try again in a moment.',
        );
      case 'invalid-argument':
        return AppException(code: 'ai-invalid', message: e.message ?? 'Invalid request.');
      case 'failed-precondition':
        return AppException(code: 'ai-precondition', message: e.message ?? 'Request could not be verified.');
      default:
        return AppException(code: 'ai-${e.code}', message: e.message ?? 'Something went wrong. Please try again.');
    }
  }

  // ── Typed tasks ────────────────────────────────────────────────────────────

  /// Classifies (when [docType] is `auto`) and extracts a document.
  /// Returns `{documentType, classificationConfidence, language, data}`.
  Future<AnalyzeResult> analyzeDocument({
    required List<AiFile> files,
    String docType = 'auto',
    required String region,
    String hints = '',
  }) async {
    final res = await _call('analyzeDocument', {
      'docType': docType,
      'region': region,
      'files': files.map((f) => f.toJson()).toList(),
      'hints': hints,
    });
    return AnalyzeResult(
      documentType: '${res['documentType'] ?? 'other'}',
      confidence: (res['classificationConfidence'] as num?)?.toDouble() ?? 0,
      language: '${res['language'] ?? 'en'}',
      data: Map<String, dynamic>.from(res['data'] as Map? ?? const {}),
      model: '${res['model'] ?? ''}',
    );
  }

  Future<Map<String, dynamic>> auditBills(Map<String, dynamic> payload) =>
      _call('auditBills', payload);

  Future<Map<String, dynamic>> draftLetter(Map<String, dynamic> payload) =>
      _call('draftLetter', payload);

  Future<Map<String, dynamic>> explainDenial(Map<String, dynamic> payload) =>
      _call('explainDenial', payload);

  Future<String> chat({
    required String mode,
    required String region,
    required List<Map<String, String>> messages,
    String context = '',
    String profileSummary = '',
  }) async {
    final res = await _call('chat', {
      'mode': mode,
      'region': region,
      'messages': messages,
      'context': context,
      'profileSummary': profileSummary,
    });
    return '${res['reply'] ?? ''}';
  }

  /// Transitional passthrough for screens that still build their own prompt.
  Future<String> generate({
    required String prompt,
    List<AiFile> files = const [],
  }) async {
    final res = await _call('generate', {
      'prompt': prompt,
      'files': files.map((f) => f.toJson()).toList(),
    });
    return '${res['text'] ?? ''}';
  }
}

class AnalyzeResult {
  final String documentType;
  final double confidence;
  final String language;
  final Map<String, dynamic> data;
  final String model;
  const AnalyzeResult({
    required this.documentType,
    required this.confidence,
    required this.language,
    required this.data,
    required this.model,
  });
}
