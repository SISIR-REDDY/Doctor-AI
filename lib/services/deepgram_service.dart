import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import 'chatbot_service.dart';
import 'firebase/api_credentials_service.dart';

/// Internal struct: contiguous words from one speaker in a Deepgram response.
class _SpeakerSegment {
  final int speakerId;
  final String text;
  _SpeakerSegment(this.speakerId, this.text);
}

class DeepgramService {
  final ChatbotService _chatbot = ChatbotService();

  Future<String> transcribeAudioFile(String audioFilePath) async {
    final apiKey = await ApiCredentialsService.instance.getDeepgramApiKey(forceRefresh: true);

    if (apiKey.isEmpty) {
      throw AppException(
        code: 'missing-deepgram-api-key',
        message:
            'Deepgram API key not configured. Please add deepgramApiKey to Firebase collection: app_runtime/api_keys.',
      );
    }

    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) {
      throw AppException(
        code: 'audio-file-not-found',
        message: 'Recorded audio file was not found for transcription.',
      );
    }

    final bytes = await audioFile.readAsBytes();
    // Guard against unfinished/empty recordings before sending to Deepgram.
    if (bytes.length < 4096) {
      throw AppException(
        code: 'recording-too-short',
        message: 'The recording was too short to transcribe. '
            'Please record for at least 2–3 seconds and try again.',
      );
    }

    final uri = Uri.parse(
      'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true&diarize=true',
    );

    try {
      final request = http.Request('POST', uri)
        ..headers['Authorization'] = 'Token $apiKey'
        // iOS `.m4a` is an MP4 container — must be sent as `audio/mp4`.
        // Using a non-standard `audio/m4a` causes Deepgram to return
        // 400 "corrupt or unsupported data".
        ..headers['Content-Type'] = _contentTypeForPath(audioFilePath)
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = bytes;

      final streamedResponse = await http.Client().send(request);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw AppException(
          code: 'deepgram-http-${streamedResponse.statusCode}',
          message: _friendlyDeepgramError(streamedResponse.statusCode),
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final results = json['results'] as Map<String, dynamic>?;
      final channels = results?['channels'] as List<dynamic>?;
      final firstChannel =
        (channels != null && channels.isNotEmpty) ? channels.first : null;
      final alternatives =
        (firstChannel as Map<String, dynamic>?)?['alternatives'] as List<dynamic>?;
      final firstAlternative = (alternatives != null && alternatives.isNotEmpty)
        ? alternatives.first as Map<String, dynamic>?
        : null;

      // Try to parse diarized response with speaker labels
      final words = firstAlternative?['words'] as List<dynamic>?;
      String text;

      if (words != null && words.isNotEmpty) {
        final segments = _buildSpeakerSegments(words);
        // Ask Gemini to decide which speaker number is the doctor — we
        // never assume Speaker 0 == Doctor, because Deepgram assigns
        // speaker IDs in arbitrary order based on who it heard first.
        final labels = await _classifySpeakers(segments);
        text = _renderWithLabels(segments, labels);
      } else {
        // Fallback to plain transcript if no word-level data
        text = (firstAlternative?['transcript'] as String?) ?? '';
      }

      if (text.trim().isEmpty) {
        throw AppException(
          code: 'empty-transcription',
          message:
              'No speech was detected. Please speak clearly and try recording again.',
        );
      }

      return text.trim();
    } catch (error) {
      if (error is AppException) rethrow;
      throw AppException(
        code: 'deepgram-request-failed',
        message: 'Unable to transcribe audio right now. Please try again.',
        cause: error,
      );
    }
  }

  /// Groups Deepgram's word-level diarization into contiguous segments
  /// per speaker, preserving turn order.
  List<_SpeakerSegment> _buildSpeakerSegments(List<dynamic> words) {
    final out = <_SpeakerSegment>[];
    int? currentSpeaker;
    final buf = <String>[];

    void flush() {
      final s = currentSpeaker;
      if (s == null || buf.isEmpty) return;
      out.add(_SpeakerSegment(s, buf.join(' ').trim()));
      buf.clear();
    }

    for (final wordData in words) {
      final w = wordData['punctuated_word'] as String? ??
          wordData['word'] as String? ??
          '';
      final speaker = (wordData['speaker'] as num?)?.toInt();
      if (speaker == null) continue;

      if (currentSpeaker == null) {
        currentSpeaker = speaker;
      } else if (speaker != currentSpeaker) {
        flush();
        currentSpeaker = speaker;
      }
      if (w.isNotEmpty) buf.add(w);
    }
    flush();
    return out;
  }

  /// Asks Gemini which speaker ID corresponds to the doctor vs. patient.
  /// Falls back to generic "Speaker N" labels if classification fails —
  /// never assumes Speaker 0 is the doctor.
  Future<Map<int, String>> _classifySpeakers(
    List<_SpeakerSegment> segments,
  ) async {
    final ids = segments.map((s) => s.speakerId).toSet().toList()..sort();
    if (ids.isEmpty) return {};
    if (ids.length == 1) {
      // Single voice — most likely a doctor dictating notes.
      return {ids.first: 'Doctor'};
    }

    // Keep the sample short for cost/latency; first 30 segments cover the
    // opening of nearly every consultation.
    final sample = segments
        .take(30)
        .map((s) => '[Speaker ${s.speakerId}]: ${s.text}')
        .join('\n');

    final prompt = '''
You are a medical conversation analyst.

Below is a diarized transcript excerpt. Speakers are labelled with numeric IDs.

Transcript:
$sample

Task: Decide which speaker number is the Doctor and which is the Patient.
- Doctor: asks diagnostic questions, mentions medications/tests, uses clinical terms, gives instructions.
- Patient: describes their own symptoms, answers questions about their body, expresses concerns.
- If a third party is present (nurse, relative), label them appropriately.

CRITICAL:
- Do NOT assume Speaker 0 is the Doctor. Decide ONLY from the content.
- If you cannot tell with confidence, output "Unknown" for that speaker.

Respond with ONLY a JSON object, no markdown, no prose.
Example: {"0": "Patient", "1": "Doctor"}

Your answer (JSON only):''';

    try {
      final raw = await _chatbot.getGeminiResponse(prompt);
      return _parseSpeakerMap(raw, ids);
    } catch (e) {
      developer.log('Speaker classification failed: $e');
      return {for (final id in ids) id: 'Speaker ${id + 1}'};
    }
  }

  Map<int, String> _parseSpeakerMap(String raw, List<int> ids) {
    final match = RegExp(r'\{[^}]+\}').firstMatch(raw);
    if (match == null) {
      return {for (final id in ids) id: 'Speaker ${id + 1}'};
    }
    final result = <int, String>{};
    for (final m in RegExp(r'"(\d+)"\s*:\s*"([^"]+)"').allMatches(match.group(0)!)) {
      final id = int.tryParse(m.group(1) ?? '');
      final role = (m.group(2) ?? '').trim();
      if (id != null && role.isNotEmpty) result[id] = role;
    }
    // Backfill any speaker the model omitted.
    for (final id in ids) {
      result.putIfAbsent(id, () => 'Speaker ${id + 1}');
    }
    return result;
  }

  String _renderWithLabels(
    List<_SpeakerSegment> segments,
    Map<int, String> labels,
  ) {
    final buf = StringBuffer();
    for (final s in segments) {
      final label = labels[s.speakerId] ?? 'Speaker ${s.speakerId + 1}';
      buf
        ..writeln('$label: ${s.text}')
        ..writeln();
    }
    return buf.toString().trim();
  }

  /// Returns the Deepgram-compatible MIME type for an audio file path.
  /// See: https://developers.deepgram.com/docs/audio-formats
  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'audio/mp4';
  }

  String _friendlyDeepgramError(int status) {
    if (status == 400) {
      return 'Could not process this audio. The recording may be too short, '
          'silent, or in an unsupported format. Please try again.';
    }
    if (status == 401 || status == 403) {
      return 'Transcription service authentication failed. '
          'Please verify the Deepgram key in Firebase.';
    }
    if (status == 429) {
      return 'Transcription rate limit reached. Please wait a moment and try again.';
    }
    if (status >= 500) {
      return 'Transcription service is temporarily unavailable. Please try again shortly.';
    }
    return 'Transcription failed (HTTP $status). Please try again.';
  }
}