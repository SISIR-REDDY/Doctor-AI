import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/errors/app_exception.dart';

/// Records short voice clips for Deepgram transcription.
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;

  String? _path;
  bool _isRecording = false;
  double _level = 0;

  bool get isRecording => _isRecording;
  double get level => _level;

  final _levelController = StreamController<double>.broadcast();
  Stream<double> get levelStream => _levelController.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_isRecording) return;

    final permitted = await _recorder.hasPermission();
    if (!permitted) {
      throw AppException(
        code: 'mic-permission-denied',
        message: 'Microphone permission is required for voice input.',
      );
    }

    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/clinix_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _path!,
    );

    _isRecording = true;
    _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      final normalized =
          ((amp.current + 50) / 50).clamp(0.05, 1.0); // dBFS → 0–1
      _level = normalized;
      if (!_levelController.isClosed) {
        _levelController.add(normalized);
      }
    });
  }

  /// Stops recording and returns the file path, or null if nothing was captured.
  Future<String?> stop() async {
    if (!_isRecording) return _path;

    final path = await _recorder.stop();
    _isRecording = false;
    await _ampSub?.cancel();
    _ampSub = null;
    _level = 0;
    if (!_levelController.isClosed) _levelController.add(0);

    final resolved = path ?? _path;
    _path = null;

    if (resolved != null && await File(resolved).exists()) {
      return resolved;
    }
    return null;
  }

  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    _isRecording = false;
    await _ampSub?.cancel();
    _ampSub = null;
    if (_path != null) {
      try {
        final f = File(_path!);
        if (await f.exists()) await f.delete();
      } catch (e) {
        if (kDebugMode) debugPrint('[VoiceRecorder] delete failed: $e');
      }
    }
    _path = null;
    _level = 0;
    if (!_levelController.isClosed) _levelController.add(0);
  }

  void dispose() {
    _ampSub?.cancel();
    _levelController.close();
    _recorder.dispose();
  }
}
