import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/deepgram_service.dart';
import '../data/gemini_service.dart';
import '../domain/transcription_model.dart';

enum TranscriptionState { idle, recording, transcribing, processing, done, error }

class TranscriptionController extends ChangeNotifier {
  final _audioRecorder = AudioRecorder();
  final _deepgramService = DeepgramService();
  final _geminiService = GeminiService();

  TranscriptionState state = TranscriptionState.idle;
  TranscriptionModel data = const TranscriptionModel();
  String? errorMessage;
  String _recordingPath = '';

  // Waveform — kept here since it's driven by recording state
  final List<double> waveformValues = List.filled(40, 0.0);
  final Random _waveformRandom = Random();
  Timer? _waveformTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double _currentAudioLevel = 0.0;
  double _noiseFloorDb = -60.0;

  bool get isRecording => state == TranscriptionState.recording;
  bool get isProcessing =>
      state == TranscriptionState.transcribing ||
      state == TranscriptionState.processing;

  double get audioLevel => _currentAudioLevel;

  String get transcription => data.rawTranscript;
  String get summary => data.summary;
  String get prescription => data.prescription;

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _setError('Microphone permission permanently denied. Please enable it in settings.');
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

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        final granted = await requestPermissions();
        if (!granted) {
          return;
        }
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final primaryConfig = _buildPrimaryRecordConfig();
      _recordingPath = _buildRecordingPath(directory.path, timestamp, primaryConfig.encoder);

      try {
        await _audioRecorder.start(primaryConfig, path: _recordingPath);
      } catch (e) {
        final fallbackConfig = _buildFallbackRecordConfig();
        if (fallbackConfig == null) {
          rethrow;
        }

        _recordingPath = _buildRecordingPath(directory.path, timestamp, fallbackConfig.encoder);
        await _audioRecorder.start(fallbackConfig, path: _recordingPath);
      }

      // Reset previous data
      data = const TranscriptionModel();
      state = TranscriptionState.recording;
      _startWaveformAnimation();
      notifyListeners();

      await _startAmplitudeMonitoring();

      developer.log('Started recording to: $_recordingPath');
    } catch (e) {
      _setError('Error starting recording: $e');
    }
  }

  RecordConfig _buildPrimaryRecordConfig() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      return const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      );
    }

    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  RecordConfig? _buildFallbackRecordConfig() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      return null;
    }

    return const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  String _buildRecordingPath(String dir, int timestamp, AudioEncoder encoder) {
    return '$dir/recording_$timestamp${_extensionForEncoder(encoder)}';
  }

  String _extensionForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.wav:
        return '.wav';
      case AudioEncoder.aacLc:
        return '.m4a';
      default:
        return '.m4a';
    }
  }

  Future<void> _stopRecording() async {
    try {
      _waveformTimer?.cancel();
      _resetWaveform();
      await _stopAmplitudeMonitoring();

      await _audioRecorder.stop();
      state = TranscriptionState.transcribing;
      notifyListeners();

      developer.log('Recording stopped, transcribing...');
      await _transcribe();
    } catch (e) {
      _setError('Error stopping recording: $e');
    }
  }

  Future<void> _transcribe() async {
    try {
      final transcript = await _deepgramService.transcribe(_recordingPath);

      data = data.copyWith(rawTranscript: transcript);
      state = TranscriptionState.processing;
      notifyListeners();

      final isUsable = transcript.isNotEmpty &&
          transcript != 'No speech detected' &&
          transcript.split(' ').length >= 3; // at least 3 words
      if (isUsable) {
        await _processWithGemini(transcript);
      } else {
        state = TranscriptionState.done;
        notifyListeners();
        if (transcript == 'No speech detected' || transcript.isEmpty) {
          _setError('No speech detected. Please speak clearly and try again.');
        }
      }
    } catch (e) {
      _setError('Transcription error: $e');
    }
  }

  Future<void> _processWithGemini(String transcript) async {
    try {
      final summary = await _geminiService.generateSummary(transcript);
      final prescription = await _geminiService.generatePrescription(transcript);

      data = data.copyWith(summary: summary, prescription: prescription);
      state = TranscriptionState.done;
      notifyListeners();

      developer.log('Gemini processing complete');
    } catch (e) {
      _setError('Gemini error: $e');
    }
  }

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

  void _setError(String message) {
    errorMessage = message;
    state = TranscriptionState.error;
    notifyListeners();
    developer.log(message);
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}