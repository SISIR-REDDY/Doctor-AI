import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/healthcare/consultation_ui_theme.dart';
import '../../features/transcription/data/deepgram_service.dart';
import '../../theme/app_theme.dart';
import '../audio_visualizer.dart';

/// Records audio and transcribes with Deepgram for clinical note dictation.
class ClinicalVoiceInput extends StatefulWidget {
  final ValueChanged<String> onTranscriptReady;
  final VoidCallback? onCancel;

  const ClinicalVoiceInput({
    super.key,
    required this.onTranscriptReady,
    this.onCancel,
  });

  @override
  State<ClinicalVoiceInput> createState() => _ClinicalVoiceInputState();
}

class _ClinicalVoiceInputState extends State<ClinicalVoiceInput> {
  final AudioRecorder _recorder = AudioRecorder();
  final DeepgramService _deepgram = DeepgramService();

  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;
  double _audioLevel = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission is required for voice notes')),
    );
    return false;
  }

  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;
    if (_isRecording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _ensureMicPermission()) return;
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _recordingPath = '${dir.path}/clinical_note_$ts.m4a';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 16000,
      numChannels: 1,
    );

    await _recorder.start(config, path: _recordingPath!);
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      if (!mounted) return;
      final db = amp.current;
      final normalized = ((db + 60) / 60).clamp(0.0, 1.0);
      setState(() => _audioLevel = normalized);
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopAndTranscribe() async {
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    try {
      final path = await _recorder.stop() ?? _recordingPath;
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        throw StateError('Recording file was not created');
      }

      final transcript = await _deepgram.transcribe(path);
      if (!mounted) return;
      widget.onTranscriptReady(transcript.trim());
    } catch (error) {
      if (mounted) AppErrorHandler.showSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _audioLevel = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: const BoxDecoration(
        gradient: ConsultationPalette.headerGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppTheme.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Voice Clinical Note',
            style: AppTheme.headingSmall.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            _isTranscribing
                ? 'Transcribing with Deepgram…'
                : _isRecording
                    ? 'Listening — tap stop when finished'
                    : 'Tap the microphone to dictate your note',
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppTheme.lg),
          AudioVisualizer(
            isRecording: _isRecording,
            audioLevel: _audioLevel,
            size: 140,
            primaryColor: ConsultationPalette.gold,
            secondaryColor: Colors.white,
          ),
          const SizedBox(height: AppTheme.lg),
          if (_isTranscribing)
            const Padding(
              padding: EdgeInsets.all(AppTheme.md),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                const SizedBox(width: AppTheme.md),
                FilledButton.icon(
                  onPressed: _toggleRecording,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRecording ? AppTheme.dangerColor : ConsultationPalette.gold,
                    foregroundColor: ConsultationPalette.charcoal,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl, vertical: AppTheme.md),
                  ),
                  icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_isRecording ? 'Stop & Transcribe' : 'Start Recording'),
                ),
              ],
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
