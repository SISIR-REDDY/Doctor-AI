import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import 'ai/ai_service.dart';
import 'firebase/api_credentials_service.dart';

/// Text/vision generation for screens that still build their own prompt.
///
/// All calls go through the Clinix backend ([AiService.generate]) so the
/// Gemini key stays server-side. A direct-to-Gemini path is kept ONLY as a
/// transitional fallback for builds running against a project where the
/// Cloud Functions have not been deployed yet; it is disabled automatically
/// once the backend has answered successfully in this session and should be
/// removed (together with `app_runtime/api_keys`) after deployment.
class ChatbotService {
  final ApiCredentialsService _credentialsService = ApiCredentialsService.instance;

  static const List<String> _legacyModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
  ];

  /// Compile-time key, supplied via `--dart-define=GEMINI_API_KEY=...` (dev only).
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Set to false to hard-disable the legacy direct path (do this once the
  /// backend is live everywhere).
  static const bool allowLegacyFallback = true;

  static bool _backendMissing = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates text for [prompt]. Throws [AppException] on failure so callers
  /// can render a clean UI state instead of pasting an error into a document.
  Future<String> getGeminiResponse(String prompt) async {
    return _run(prompt, const []);
  }

  Future<String> getGeminiVisionResponse({
    required String prompt,
    String? imagePath,
  }) {
    return getGeminiVisionResponseMulti(
      prompt: prompt,
      imagePaths: imagePath != null && imagePath.isNotEmpty ? [imagePath] : [],
    );
  }

  /// Analyzes one or more images / PDFs together with [prompt].
  Future<String> getGeminiVisionResponseMulti({
    required String prompt,
    required List<String> imagePaths,
  }) async {
    final files = <AiFile>[];
    for (final p in imagePaths) {
      final f = await AiFile.fromPath(p);
      if (f != null) files.add(f);
    }
    return _run(prompt, files);
  }

  // ── Routing ────────────────────────────────────────────────────────────────

  Future<String> _run(String prompt, List<AiFile> files) async {
    if (!_backendMissing || !allowLegacyFallback) {
      try {
        final text = await AiService.instance.generate(prompt: prompt, files: files);
        if (text.trim().isNotEmpty) return text;
        throw const AppException(code: 'ai-empty', message: 'The AI returned an empty response. Please try again.');
      } on AppException catch (e) {
        if (e.code != 'ai-backend-missing' || !allowLegacyFallback) rethrow;
        _backendMissing = true;
        debugPrint('[ChatbotService] ⚠️ Backend not deployed — using legacy direct path.');
      }
    }
    return _legacyDirect(prompt, files);
  }

  // ── Legacy direct-to-Gemini path (transitional) ───────────────────────────

  Future<String> _legacyKey() async {
    try {
      final k = await _credentialsService.getGeminiApiKey();
      if (k.isNotEmpty) return k;
    } catch (_) {}
    return _envGeminiKey;
  }

  Future<String> _legacyDirect(String prompt, List<AiFile> files) async {
    final apiKey = await _legacyKey();
    if (apiKey.isEmpty) {
      throw const AppException(
        code: 'ai-not-configured',
        message: 'AI is not available yet. Deploy the Clinix backend (see functions/README.md).',
      );
    }
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      for (final f in files)
        {
          'inline_data': {'mime_type': f.mimeType, 'data': f.base64Data}
        },
    ];
    Object? lastError;
    for (final model in _legacyModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 4096},
              }),
            )
            .timeout(const Duration(seconds: 60));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractText(data);
          if (text.trim().isNotEmpty) return text;
          lastError = 'empty response';
          continue;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const AppException(code: 'ai-key', message: 'AI key is invalid or unauthorised.');
        }
        if (response.statusCode == 429) {
          throw const AppException(code: 'ai-rate', message: 'AI rate limit reached. Please wait a moment.');
        }
        lastError = 'HTTP ${response.statusCode}';
      } on AppException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw AppException(code: 'ai-failed', message: 'AI request failed ($lastError). Please try again.');
  }

  String _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List) return '';
    for (final c in candidates) {
      final parts = (c is Map ? c['content'] : null) is Map ? (c['content']['parts']) : null;
      if (parts is! List) continue;
      for (final p in parts) {
        if (p is Map && p['text'] is String && (p['text'] as String).trim().isNotEmpty) {
          return p['text'] as String;
        }
      }
    }
    return '';
  }

  /// True if a file at [path] can be attached (exists and is a supported type).
  static Future<bool> canAttach(String path) async {
    if (!await File(path).exists()) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.pdf');
  }
}
