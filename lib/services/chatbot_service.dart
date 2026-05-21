import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'firebase/api_credentials_service.dart';

class ChatbotService {
  final ApiCredentialsService _credentialsService = ApiCredentialsService.instance;

  // Ordered model fallback chain — fastest first.
  // gemini-2.5-flash-lite is the quickest model in the 2.5 family.
  // Docs: https://ai.google.dev/gemini-api/docs/models
  static const List<String> _models = [
    'gemini-2.5-flash-lite', // fastest — try first
    'gemini-2.5-flash',      // more capable fallback
    'gemini-2.0-flash',      // legacy safety net
  ];

  // v1beta exposes 2.5 models first.
  static const List<String> _apiVersions = ['v1beta', 'v1'];

  // Once a working model+version combo is found it's cached here so
  // subsequent calls skip straight to it instead of re-scanning the list.
  String? _cachedModel;
  String? _cachedVersion;

  /// Get API key from Firebase only (no local fallback)
  Future<String> _getGeminiApiKey() async {
    try {
      final firebaseKey = await _credentialsService.getGeminiApiKey(forceRefresh: false);
      if (firebaseKey.isNotEmpty) {
        debugPrint('[ChatbotService] ✅ Using Gemini API key from Firebase');
        return firebaseKey;
      }
    } catch (e) {
      debugPrint('[ChatbotService] ⚠️ Firebase API key failed: $e');
    }

    debugPrint('[ChatbotService] ❌ No valid Gemini API key found in Firebase');
    return '';
  }

  String _extractTextFromResponse(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) {
        continue;
      }

      final content = candidate['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }

      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }

      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '';
  }

  Future<String> _callGemini(
    String apiKey,
    List<Map<String, dynamic>> parts,
  ) async {
    // Build the ordered list to try — cached combo goes first to skip
    // the fallback scan on every subsequent call.
    final orderedCombos = <(String model, String version)>[];
    if (_cachedModel != null && _cachedVersion != null) {
      orderedCombos.add((_cachedModel!, _cachedVersion!));
    }
    for (final model in _models) {
      for (final version in _apiVersions) {
        if (model == _cachedModel && version == _cachedVersion) continue;
        orderedCombos.add((model, version));
      }
    }

    Exception? lastError;

    for (final (model, apiVersion) in orderedCombos) {
      try {
        debugPrint('[ChatbotService] Trying $model @ $apiVersion');

        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {
                  'temperature': 0.4,    // lower temp = more focused clinical output
                  'maxOutputTokens': 1024, // enough for our concise prompts
                },
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractTextFromResponse(data);
          if (text.trim().isNotEmpty) {
            debugPrint('[ChatbotService] ✅ $model @ $apiVersion succeeded');
            // Cache for next call.
            _cachedModel = model;
            _cachedVersion = apiVersion;
            return text;
          }
          lastError = Exception('$model returned empty response');
          continue;
        }

        if (response.statusCode == 404) {
          debugPrint('[ChatbotService] ⚠️ $model not on $apiVersion');
          // Invalidate cache if the cached combo is now 404.
          if (model == _cachedModel && apiVersion == _cachedVersion) {
            _cachedModel = null;
            _cachedVersion = null;
          }
          lastError = Exception('Model $model not found on $apiVersion');
          continue;
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception(
            'Gemini API key is invalid or has insufficient permissions.',
          );
        }

        if (response.statusCode == 429) {
          throw Exception('Gemini rate limit reached. Please wait a moment.');
        }

        debugPrint('[ChatbotService] HTTP ${response.statusCode} from $model');
        lastError = Exception('HTTP ${response.statusCode}');
      } on Exception catch (e) {
        debugPrint('[ChatbotService] $model @ $apiVersion threw: $e');
        lastError = e;
      }
    }

    throw lastError ??
        Exception(
          'All Gemini models failed. Check your API key and ensure the '
          'Generative Language API is enabled.',
        );
  }

  /// Get a response from Gemini based on a prompt.
  ///
  /// Throws on any failure (auth, rate limit, network, all-models-404) so
  /// callers can render a clean UI state instead of pasting an error
  /// sentence into a clinical document. Use try/catch at the call site.
  Future<String> getGeminiResponse(String prompt) async {
    debugPrint('\n=== GEMINI PROMPT ===');
    debugPrint(prompt);

    final apiKey = await _getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API key not configured. Add geminiApiKey to Firebase '
        '(app_runtime/api_keys).',
      );
    }

    debugPrint('[ChatbotService] Calling Gemini API...');
    return await _callGemini(apiKey, [{'text': prompt}]);
  }

  /// Get a response from Gemini based on image (vision). Throws on failure.
  Future<String> getGeminiVisionResponse({
    required String prompt,
    String? imagePath,
  }) async {
    debugPrint('\n=== GEMINI VISION PROMPT ===');
    debugPrint(prompt);

    final apiKey = await _getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API key not configured. Add geminiApiKey to Firebase '
        '(app_runtime/api_keys).',
      );
    }

    final List<Map<String, dynamic>> parts = [
      {"text": prompt}
    ];

    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          final imageBase64 = base64Encode(imageBytes);

          String mimeType = 'image/jpeg';
          if (imagePath.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imagePath.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
          } else if (imagePath.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
          }

          parts.add({
            'inline_data': {
              'mime_type': mimeType,
              'data': imageBase64,
            },
          });
        }
      } catch (e) {
        debugPrint('[ChatbotService] Error reading image file: $e');
      }
    }

    debugPrint('[ChatbotService] Calling Gemini Vision API...');
    return await _callGemini(apiKey, parts);
  }
}