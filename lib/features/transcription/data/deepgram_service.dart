import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/errors/app_exception.dart';
import '../../../services/firebase/api_credentials_service.dart';

/// A single speaker-labeled utterance from Deepgram diarization.
class SpeakerUtterance {
  final int speakerId;
  final String text;
  final double start;
  final double end;

  const SpeakerUtterance({
    required this.speakerId,
    required this.text,
    required this.start,
    required this.end,
  });
}

/// Full result from Deepgram — raw transcript + per-speaker utterances.
class DeepgramResult {
  /// Plain concatenated transcript (no speaker labels).
  final String rawTranscript;

  /// Chronological list of utterances with speaker IDs.
  final List<SpeakerUtterance> utterances;

  /// How many distinct speakers Deepgram detected.
  final int speakerCount;

  const DeepgramResult({
    required this.rawTranscript,
    required this.utterances,
    required this.speakerCount,
  });

  /// Formats utterances into a readable string using [labelMap].
  /// [labelMap] maps speaker ID → display name (e.g. {0: 'Doctor', 1: 'Patient'}).
  String formatWithLabels(Map<int, String> labelMap) {
    final buf = StringBuffer();
    for (final u in utterances) {
      final label = labelMap[u.speakerId] ?? 'Speaker ${u.speakerId}';
      buf.writeln('[$label]: ${u.text.trim()}');
    }
    return buf.toString().trim();
  }

  /// Formats utterances with generic "Speaker N" labels.
  String get formattedRaw {
    final buf = StringBuffer();
    for (final u in utterances) {
      buf.writeln('[Speaker ${u.speakerId}]: ${u.text.trim()}');
    }
    return buf.toString().trim();
  }
}

class DeepgramService {
  final String? _apiKey;

  DeepgramService({String? apiKey}) : _apiKey = apiKey?.trim();

  Future<String> _resolveApiKey() async {
    final configuredKey = _apiKey;
    if (configuredKey != null && configuredKey.isNotEmpty) {
      return configuredKey;
    }
    return ApiCredentialsService.instance.getDeepgramApiKey();
  }

  /// Transcribes audio with full speaker diarization.
  /// Returns a [DeepgramResult] containing utterances per speaker.
  Future<DeepgramResult> transcribeWithDiarization(String recordingPath) async {
    final apiKey = await _resolveApiKey();
    if (apiKey.isEmpty) {
      throw AppException(
        code: 'missing-deepgram-api-key',
        message:
            'Deepgram API key not configured. Please add deepgramApiKey to Firebase collection: app_runtime/api_keys.',
      );
    }

    // nova-3-general — faster and more accurate than nova-2.
    // diarize=true + utterances=true → grouped speaker turns in one pass.
    // smart_format=true → handles numbers, dates, punctuation automatically.
    final uri = Uri.parse(
      'https://api.deepgram.com/v1/listen'
      '?model=nova-3-general'
      '&diarize=true'
      '&utterances=true'
      '&smart_format=true'
      '&punctuate=true',
    );

    final file = File(recordingPath);
    if (!await file.exists()) {
      throw AppException(
        code: 'audio-file-not-found',
        message: 'Recorded audio file was not found. Please try recording again.',
      );
    }

    final bytes = await file.readAsBytes();
    // Sanity check: anything under ~4KB is almost certainly an unfinished
    // recording — m4a containers need a few hundred bytes of headers even
    // for silent audio, and Deepgram will reject anything malformed.
    if (bytes.length < 4096) {
      throw AppException(
        code: 'recording-too-short',
        message: 'The recording was too short to transcribe. '
            'Please record for at least 2–3 seconds and try again.',
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Token $apiKey',
              'Content-Type': _contentTypeForPath(recordingPath),
              'Accept': 'application/json',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw AppException(
        code: 'deepgram-timeout',
        message: 'Transcription timed out. Please check your connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      throw AppException(
        code: 'deepgram-http-${response.statusCode}',
        message: _friendlyDeepgramError(response.statusCode, response.body),
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return _parseDeepgramResponse(body);
  }

  String _friendlyDeepgramError(int status, String rawBody) {
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

  /// Legacy plain-text transcription (no diarization). Kept for fallback.
  Future<String> transcribe(String recordingPath) async {
    final result = await transcribeWithDiarization(recordingPath);
    return result.rawTranscript;
  }

  // ── Parser ────────────────────────────────────────────────────────────────

  DeepgramResult _parseDeepgramResponse(Map<String, dynamic> body) {
    // ── Raw transcript ────────────────────────────────────────────────────
    final results = body['results'] as Map<String, dynamic>?;
    final channels = results?['channels'] as List?;
    final alternatives =
        (channels?.firstOrNull as Map<String, dynamic>?)?['alternatives'] as List?;
    final rawTranscript =
        ((alternatives?.firstOrNull as Map<String, dynamic>?)?['transcript']
                as String?)
            ?.trim() ??
            '';

    // ── Utterances (Deepgram groups consecutive words by speaker) ─────────
    final utterancesRaw = results?['utterances'] as List?;
    if (utterancesRaw != null && utterancesRaw.isNotEmpty) {
      final utterances = <SpeakerUtterance>[];
      final speakerIds = <int>{};

      for (final u in utterancesRaw.cast<Map<String, dynamic>>()) {
        final speakerId = (u['speaker'] as num?)?.toInt() ?? 0;
        final text = (u['transcript'] as String?) ?? '';
        final start = (u['start'] as num?)?.toDouble() ?? 0.0;
        final end = (u['end'] as num?)?.toDouble() ?? 0.0;
        if (text.trim().isEmpty) continue;
        speakerIds.add(speakerId);
        utterances.add(SpeakerUtterance(
          speakerId: speakerId,
          text: text,
          start: start,
          end: end,
        ));
      }

      return DeepgramResult(
        rawTranscript: rawTranscript.isNotEmpty ? rawTranscript : 'No speech detected',
        utterances: utterances,
        speakerCount: speakerIds.length,
      );
    }

    // ── Fallback: build utterances from word-level diarization ────────────
    final words = (alternatives?.firstOrNull as Map<String, dynamic>?)?['words'] as List?;
    if (words != null && words.isNotEmpty) {
      return _buildUtterancesFromWords(words.cast<Map<String, dynamic>>(), rawTranscript);
    }

    // ── No diarization data — return single-speaker result ────────────────
    return DeepgramResult(
      rawTranscript: rawTranscript.isNotEmpty ? rawTranscript : 'No speech detected',
      utterances: rawTranscript.isNotEmpty
          ? [SpeakerUtterance(speakerId: 0, text: rawTranscript, start: 0, end: 0)]
          : [],
      speakerCount: rawTranscript.isNotEmpty ? 1 : 0,
    );
  }

  /// Groups consecutive words from the same speaker into utterances.
  DeepgramResult _buildUtterancesFromWords(
    List<Map<String, dynamic>> words,
    String rawTranscript,
  ) {
    final utterances = <SpeakerUtterance>[];
    final speakerIds = <int>{};

    int? currentSpeaker;
    final wordBuffer = StringBuffer();
    double utteranceStart = 0;
    double utteranceEnd = 0;

    for (final w in words) {
      final speaker = (w['speaker'] as num?)?.toInt() ?? 0;
      final word = (w['punctuated_word'] as String?) ?? (w['word'] as String?) ?? '';
      final start = (w['start'] as num?)?.toDouble() ?? 0.0;
      final end = (w['end'] as num?)?.toDouble() ?? 0.0;

      speakerIds.add(speaker);

      if (currentSpeaker == null) {
        currentSpeaker = speaker;
        utteranceStart = start;
      }

      if (speaker != currentSpeaker) {
        // Speaker changed — flush current utterance
        final text = wordBuffer.toString().trim();
        if (text.isNotEmpty) {
          utterances.add(SpeakerUtterance(
            speakerId: currentSpeaker,
            text: text,
            start: utteranceStart,
            end: utteranceEnd,
          ));
        }
        wordBuffer.clear();
        currentSpeaker = speaker;
        utteranceStart = start;
      }

      if (wordBuffer.isNotEmpty) wordBuffer.write(' ');
      wordBuffer.write(word);
      utteranceEnd = end;
    }

    // Flush last utterance
    final lastText = wordBuffer.toString().trim();
    if (lastText.isNotEmpty && currentSpeaker != null) {
      utterances.add(SpeakerUtterance(
        speakerId: currentSpeaker,
        text: lastText,
        start: utteranceStart,
        end: utteranceEnd,
      ));
    }

    return DeepgramResult(
      rawTranscript: rawTranscript.isNotEmpty ? rawTranscript : 'No speech detected',
      utterances: utterances,
      speakerCount: speakerIds.length,
    );
  }

  /// Returns the standards-compliant MIME type that Deepgram expects for the
  /// given file path. Critical: an iOS `.m4a` file is an MP4 container, so it
  /// MUST be sent as `audio/mp4` — sending `audio/m4a` causes Deepgram to
  /// reject the body with "corrupt or unsupported data".
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
}
