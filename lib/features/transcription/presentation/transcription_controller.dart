import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../data/deepgram_service.dart';
import '../data/gemini_service.dart';
import '../domain/transcription_model.dart';

enum TranscriptionState { idle, recording, transcribing, classifying, processing, done, error }

class TranscriptionController extends ChangeNotifier {
  final _audioRecorder = AudioRecorder();
  final _deepgramService = DeepgramService();
  final _geminiService = GeminiService();

  TranscriptionState state = TranscriptionState.idle;
  TranscriptionModel data = const TranscriptionModel();
  String? errorMessage;
  String _recordingPath = '';
  DateTime? _recordingStartedAt;
  static const Duration _minRecordingDuration = Duration(milliseconds: 1500);

  // Waveform
  final List<double> waveformValues = List.filled(40, 0.0);
  final Random _waveformRandom = Random();
  Timer? _waveformTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double _currentAudioLevel = 0.0;
  double _noiseFloorDb = -60.0;

  bool get isRecording => state == TranscriptionState.recording;
  bool get isProcessing =>
      state == TranscriptionState.transcribing ||
      state == TranscriptionState.classifying ||
      state == TranscriptionState.processing;

  double get audioLevel => _currentAudioLevel;

  // ── Expose both raw and diarized transcripts ──────────────────────────
  String get transcription => data.transcriptForAI; // diarized if available
  String get rawTranscript => data.rawTranscript;
  String get diarizedTranscript => data.diarizedTranscript;
  String get summary => data.summary;
  String get prescription => data.prescription;
  Map<int, String> get speakerRoles => data.speakerRoles;
  bool get hasSpeakerClassification => data.hasSpeakerClassification;

  /// Human-readable status for progress indicator.
  String get statusLabel {
    switch (state) {
      case TranscriptionState.idle:
        return 'Ready';
      case TranscriptionState.recording:
        return 'Recording';
      case TranscriptionState.transcribing:
        return 'Transcribing audio…';
      case TranscriptionState.classifying:
        return 'Identifying speakers…';
      case TranscriptionState.processing:
        return 'Generating AI outputs…';
      case TranscriptionState.done:
        return 'Complete';
      case TranscriptionState.error:
        return 'Error';
    }
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _setError('Microphone permission permanently denied. Please enable it in Settings.');
      return false;
    }
    _setError('Microphone permission denied');
    return false;
  }

  Future<void> toggleRecording() async {
    if (isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        final granted = await requestPermissions();
        if (!granted) return;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final primaryConfig = _buildPrimaryRecordConfig();
      _recordingPath = _buildRecordingPath(directory.path, timestamp, primaryConfig.encoder);

      try {
        await _audioRecorder.start(primaryConfig, path: _recordingPath);
      } catch (_) {
        final fallback = _buildFallbackRecordConfig();
        if (fallback == null) rethrow;
        _recordingPath = _buildRecordingPath(directory.path, timestamp, fallback.encoder);
        await _audioRecorder.start(fallback, path: _recordingPath);
      }

      data = const TranscriptionModel();
      state = TranscriptionState.recording;
      _recordingStartedAt = DateTime.now();
      _startWaveformAnimation();
      notifyListeners();
      await _startAmplitudeMonitoring();
      developer.log('Recording started: $_recordingPath');
    } catch (e) {
      _setError('Could not start recording. Please check microphone permissions and try again.');
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Guarantee at least a minimum recording duration so the m4a container
      // gets a valid moov atom written. Stopping at <1s on iOS frequently
      // produces a file Deepgram cannot decode.
      final startedAt = _recordingStartedAt;
      if (startedAt != null) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed < _minRecordingDuration) {
          await Future<void>.delayed(_minRecordingDuration - elapsed);
        }
      }
      _waveformTimer?.cancel();
      _resetWaveform();
      await _stopAmplitudeMonitoring();

      // IMPORTANT: `stop()` returns the canonical final path the platform
      // actually wrote to — on iOS this can differ from the path passed to
      // `start()` (sandboxing, file:// prefix, etc). Always prefer it.
      final stoppedPath = await _audioRecorder.stop();
      if (stoppedPath != null && stoppedPath.isNotEmpty) {
        _recordingPath = _normaliseFilePath(stoppedPath);
      }
      _recordingStartedAt = null;

      // Allow up to ~1s for the encoder to flush the moov atom to disk.
      // We poll instead of sleeping blindly so short recordings still work.
      final resolvedFile = await _waitForRecordingToFlush(_recordingPath);
      if (resolvedFile == null) {
        developer.log(
          'Recording file missing or empty at: $_recordingPath',
        );
        _setError(
          'Recording could not be saved. Please check microphone access in Settings and try again.',
        );
        return;
      }

      final size = await resolvedFile.length();
      developer.log('Recording finalised: ${resolvedFile.path} (${size}B)');
      if (size < 1024) {
        _setError(
          'No audio was captured. Make sure your microphone is enabled and try again.',
        );
        return;
      }

      _recordingPath = resolvedFile.path;
      state = TranscriptionState.transcribing;
      notifyListeners();
      await _transcribeAndClassify();
    } catch (e) {
      developer.log('Stop recording failure: $e');
      _setError('Could not stop the recording. Please try again.');
    }
  }

  /// Strips any `file://` prefix that some platforms prepend.
  String _normaliseFilePath(String raw) {
    if (raw.startsWith('file://')) {
      return Uri.parse(raw).toFilePath();
    }
    return raw;
  }

  /// Polls the filesystem for up to ~1s waiting for the encoder to finish
  /// writing the audio container. Returns the [File] once it has non-zero
  /// length, or null if it never materialises.
  Future<File?> _waitForRecordingToFlush(String path) async {
    final file = File(path);
    for (var i = 0; i < 10; i++) {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) return file;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return await file.exists() ? file : null;
  }

  // ── Core pipeline ──────────────────────────────────────────────────────

  Future<void> _transcribeAndClassify() async {
    try {
      // Step 1: Deepgram transcription WITH diarization
      developer.log('Step 1: Deepgram diarization…');
      final deepgramResult =
          await _deepgramService.transcribeWithDiarization(_recordingPath);

      if (deepgramResult.rawTranscript.isEmpty ||
          deepgramResult.rawTranscript == 'No speech detected') {
        data = data.copyWith(rawTranscript: 'No speech detected');
        _setError('No speech detected. Please speak clearly and try again.');
        return;
      }

      data = data.copyWith(
        rawTranscript: deepgramResult.rawTranscript,
        utterances: deepgramResult.utterances,
      );
      notifyListeners();

      // Step 2: Speaker classification.
      // Skip entirely for single-speaker recordings (dictation / monologue)
      // — Gemini round-trip would just confirm "it's one Doctor", saving 3-5s.
      final distinctSpeakers =
          deepgramResult.utterances.map((u) => u.speakerId).toSet();

      if (distinctSpeakers.length <= 1 && deepgramResult.utterances.isNotEmpty) {
        // One voice → treat as Doctor dictating.
        final id = distinctSpeakers.first;
        final labelMap = {id: 'Doctor'};
        final diarized = deepgramResult.formatWithLabels(labelMap);
        data = data.copyWith(speakerRoles: labelMap, diarizedTranscript: diarized);
        notifyListeners();
        developer.log('Single speaker — skipped classification, labelled as Doctor.');
      } else if (deepgramResult.utterances.isNotEmpty) {
        developer.log(
            'Step 2: Speaker classification (${distinctSpeakers.length} speakers)…');
        state = TranscriptionState.classifying;
        notifyListeners();

        try {
          final rawRoles =
              await _geminiService.classifySpeakers(deepgramResult.utterances);

          final labelMap = <int, String>{
            for (final id in distinctSpeakers) id: rawRoles[id] ?? 'Speaker ${id + 1}',
          };

          final diarized = deepgramResult.formatWithLabels(labelMap);
          data = data.copyWith(speakerRoles: labelMap, diarizedTranscript: diarized);
          notifyListeners();
          developer.log('Speaker roles: $labelMap');
        } catch (e) {
          developer.log('Speaker classification failed (non-fatal): $e');
        }
      }

      // Step 3: Summary + prescription in PARALLEL — both only need the
      // transcript and are fully independent of each other. Running them
      // concurrently cuts the AI wait time roughly in half.
      final isUsable = data.transcriptForAI.split(' ').length >= 3;
      if (isUsable) {
        developer.log('Step 3: Gemini summary + prescription (parallel)…');
        state = TranscriptionState.processing;
        notifyListeners();
        await _processWithGemini(data.transcriptForAI);
      } else {
        state = TranscriptionState.done;
        notifyListeners();
      }
    } on AppException catch (e) {
      _setError(e.message);
    } catch (e) {
      developer.log('Transcription pipeline failure: $e');
      _setError('Transcription failed. Please try again.');
    }
  }

  Future<void> _processWithGemini(String transcript) async {
    try {
      // Run summary and prescription simultaneously — they're independent.
      final results = await Future.wait([
        _geminiService.generateSummary(transcript),
        _geminiService.generatePrescription(transcript),
      ]);
      data = data.copyWith(summary: results[0], prescription: results[1]);
      state = TranscriptionState.done;
      notifyListeners();
      developer.log('Gemini processing complete (parallel).');
    } catch (e) {
      developer.log('Gemini processing failed (non-fatal): $e');
      state = TranscriptionState.done;
      notifyListeners();
    }
  }

  // ── Waveform helpers ───────────────────────────────────────────────────

  void _startWaveformAnimation() {
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final base = _currentAudioLevel.clamp(0.0, 1.0);
      final energy = pow(base, 0.65).toDouble();
      final spread = 0.08 + energy * 0.45;
      for (int i = 0; i < waveformValues.length; i++) {
        final jitter = (_waveformRandom.nextDouble() - 0.5) * spread;
        waveformValues[i] = (energy + jitter).clamp(0.0, 1.0);
      }
      notifyListeners();
    });
  }

  void _resetWaveform() {
    for (int i = 0; i < waveformValues.length; i++) {
      waveformValues[i] = 0.0;
    }
    _currentAudioLevel = 0.0;
    _noiseFloorDb = -60.0;
  }

  Future<void> _startAmplitudeMonitoring() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _amplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 60))
        .listen(
      (amplitude) {
        final db = max(amplitude.current, amplitude.max);
        if (db < _noiseFloorDb + 6) {
          _noiseFloorDb = (_noiseFloorDb * 0.95 + db * 0.05).clamp(-90.0, -30.0);
        }
        final effectiveDb = db - (_noiseFloorDb + 6.0);
        final normalized = (effectiveDb / 40.0).clamp(0.0, 1.0);
        _currentAudioLevel = normalized <= 0.02 ? 0.0 : normalized;
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _stopAmplitudeMonitoring() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  // ── Config helpers ─────────────────────────────────────────────────────

  RecordConfig _buildPrimaryRecordConfig() => const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      );

  RecordConfig? _buildFallbackRecordConfig() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return null;
    return const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1);
  }

  String _buildRecordingPath(String dir, int ts, AudioEncoder enc) =>
      '$dir/recording_$ts${_extensionForEncoder(enc)}';

  String _extensionForEncoder(AudioEncoder enc) {
    switch (enc) {
      case AudioEncoder.wav:
        return '.wav';
      default:
        return '.m4a';
    }
  }

  void _setError(String message) {
    errorMessage = message;
    state = TranscriptionState.error;
    notifyListeners();
    developer.log('TranscriptionController error: $message');
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}
