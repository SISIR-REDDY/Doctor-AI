import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import 'firebase/api_credentials_service.dart';

/// Speech-to-text via [Deepgram](https://developers.deepgram.com/) listen API.
class DeepgramService {
  static const _listenUrl = 'https://api.deepgram.com/v1/listen';

  /// Compile-time fallback, supplied via `--dart-define=DEEPGRAM_API_KEY=...`,
  /// used when no key is configured in Firestore.
  static const String _envKey = String.fromEnvironment('DEEPGRAM_API_KEY');

  Future<String> transcribeFile(String filePath) async {
    var apiKey = await ApiCredentialsService.instance.getDeepgramApiKey();
    if (apiKey.isEmpty) apiKey = _envKey;
    if (apiKey.isEmpty) {
      throw AppException(
        code: 'deepgram-not-configured',
        message:
            'Voice input is not set up. Add deepgramApiKey in Firebase '
            '(app_runtime/api_keys) or pass --dart-define=DEEPGRAM_API_KEY.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw AppException(
        code: 'audio-missing',
        message: 'Recording file was not found.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AppException(
        code: 'audio-empty',
        message: 'Recording was empty. Please try again.',
      );
    }

    final uri = Uri.parse(
      '$_listenUrl?model=nova-2&smart_format=true&punctuate=true&language=en',
    );

    if (kDebugMode) {
      debugPrint('[Deepgram] Transcribing ${bytes.length} bytes...');
    }

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Token $apiKey',
            'Content-Type': _contentTypeForPath(filePath),
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[Deepgram] HTTP ${response.statusCode}: ${response.body}');
      }
      throw AppException(
        code: 'deepgram-http-error',
        message: 'Voice transcription failed (${response.statusCode}).',
      );
    }

    final transcript = _parseTranscript(response.body);
    if (transcript.isEmpty) {
      throw AppException(
        code: 'deepgram-empty',
        message: 'No speech detected. Speak clearly and try again.',
      );
    }

    if (kDebugMode) {
      debugPrint('[Deepgram] Transcript: $transcript');
    }
    return transcript;
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'audio/mp4';
  }

  String _parseTranscript(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['results'] as Map<String, dynamic>?;
      final channels = results?['channels'] as List<dynamic>?;
      if (channels == null || channels.isEmpty) return '';

      final alternatives = channels.first['alternatives'] as List<dynamic>?;
      if (alternatives == null || alternatives.isEmpty) return '';

      return (alternatives.first['transcript'] as String? ?? '').trim();
    } catch (e) {
      if (kDebugMode) debugPrint('[Deepgram] Parse error: $e');
      return '';
    }
  }
}
