import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docpilot/core/healthcare/healthcare_services_manager.dart';
import 'package:docpilot/models/health_models.dart';
import 'package:docpilot/screens/consultation_history_screen.dart';
import 'package:docpilot/screens/prescription_screen.dart';
import 'package:docpilot/screens/summary_screen.dart';
import 'package:docpilot/screens/transcription_detail_screen.dart';
import 'package:docpilot/widgets/audio_visualizer.dart';
import 'transcription_controller.dart';

// ─── iOS-native palette ─────────────────────────────────────────────────────
const Color _bg = Color(0xFFF6F7FB);
const Color _surface = Colors.white;
const Color _border = Color(0xFFE5E7EB);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _faint = Color(0xFF9CA3AF);
const Color _brand = Color(0xFF2563EB);
const Color _danger = Color(0xFFDC2626);
const Color _success = Color(0xFF10B981);

// ─── Patient intake data collected before recording starts ──────────────────
class _PatientIntake {
  final String name;
  final String gender;
  final String age;
  final List<String> foodAllergies;
  final List<String> medAllergies;
  final List<String> surgeries;
  final String bp;
  final String height;
  final String weight;
  final ProviderPatientRecord? existing; // non-null = selected existing patient

  const _PatientIntake({
    this.name = '',
    this.gender = '',
    this.age = '',
    this.foodAllergies = const [],
    this.medAllergies = const [],
    this.surgeries = const [],
    this.bp = '',
    this.height = '',
    this.weight = '',
    this.existing,
  });

  String get displayName =>
      existing?.fullName.isNotEmpty == true ? existing!.fullName : name;

  List<String> get extraHistory {
    final items = <String>[];
    if (bp.isNotEmpty) items.add('BP: $bp');
    if (height.isNotEmpty) items.add('Height: $height');
    if (weight.isNotEmpty) items.add('Weight: $weight');
    for (final s in surgeries) {
      if (s.isNotEmpty) items.add('Surgery: $s');
    }
    return items;
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final HealthcareServicesManager _services = HealthcareServicesManager();

  bool _promptedForSave = false;
  String? _lastSavedSignature;
  String? _lastErrorShown;

  // Patient collected in the pre-recording intake form.
  _PatientIntake? _intake;

  // Live elapsed-time tracking.
  Timer? _ticker;
  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  TranscriptionState? _lastState;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncElapsedTracker(TranscriptionController c) {
    // Start/stop the elapsed timer in lockstep with recording state.
    if (c.isRecording && _lastState != TranscriptionState.recording) {
      _recordingStartedAt = DateTime.now();
      _elapsed = Duration.zero;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _recordingStartedAt == null) return;
        setState(() {
          _elapsed = DateTime.now().difference(_recordingStartedAt!);
        });
      });
    } else if (!c.isRecording && _lastState == TranscriptionState.recording) {
      _ticker?.cancel();
      _ticker = null;
      _recordingStartedAt = null;
    }
    _lastState = c.state;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TranscriptionController>();
    _syncElapsedTracker(controller);
    _maybePromptForSave(controller);
    _maybeShowError(controller);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Consultation',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _ink, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (controller.state == TranscriptionState.done &&
              controller.transcription.isNotEmpty)
            TextButton(
              onPressed: () => _confirmReset(controller),
              child: const Text('New',
                  style: TextStyle(
                      color: _brand,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: _ink, size: 24),
            tooltip: 'Session history',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConsultationHistoryScreen(),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _RecorderHero(
              controller: controller,
              elapsed: _elapsed,
              intake: _intake,
              onMicTap: () => _handleMicTap(controller),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Results'),
            _ResultsList(controller: controller),
          ],
        ),
      ),
    );
  }

  // ─── Side-effect helpers ─────────────────────────────────────────────────

  void _maybeShowError(TranscriptionController controller) {
    if (controller.state != TranscriptionState.error) {
      _lastErrorShown = null;
      return;
    }
    final msg = controller.errorMessage ?? 'Something went wrong';
    if (_lastErrorShown == msg) return;
    _lastErrorShown = msg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Recording failed'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(msg),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _maybePromptForSave(TranscriptionController controller) {
    if (controller.state == TranscriptionState.recording ||
        controller.state == TranscriptionState.transcribing ||
        controller.state == TranscriptionState.processing) {
      _promptedForSave = false;
      return;
    }
    if (controller.state != TranscriptionState.done) return;
    if (controller.transcription.trim().isEmpty) return;

    final signature = _buildSignature(controller);
    if (_lastSavedSignature == signature || _promptedForSave) return;

    _promptedForSave = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final intake = _intake;
      final patientName = intake?.displayName.isNotEmpty == true
          ? intake!.displayName
          : (_services.suggestPatientNameFromTranscript(
                  controller.transcription) ??
              'Patient');

      final savedPatient = await _services.createPatientWithSession(
        patientName: patientName,
        transcript: controller.transcription,
        summary: controller.summary,
        prescription: controller.prescription,
        source: 'transcription',
        gender: intake?.gender ?? '',
        foodAllergies: intake?.foodAllergies ?? [],
        medicinalAllergies: intake?.medAllergies ?? [],
        extraHistory: intake?.extraHistory ?? [],
        existingPatient: intake?.existing,
      );

      if (!mounted) return;
      if (savedPatient == null) {
        _promptedForSave = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to save this session.'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _lastSavedSignature = signature;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Saved · ${savedPatient.fullName.isEmpty ? patientName : savedPatient.fullName}'),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // History is shown via ConsultationHistoryScreen; nothing to refresh here.
    });
  }

  String _buildSignature(TranscriptionController c) =>
      '${c.transcription.length}|${c.summary.length}|${c.prescription.length}';

  // ── Mic tap → show intake form first, then start recording ─────────────────

  Future<void> _handleMicTap(TranscriptionController controller) async {
    // Recording or processing → just stop.
    if (controller.state == TranscriptionState.recording) {
      await controller.toggleRecording();
      return;
    }
    if (controller.isProcessing) return;

    // Done state → confirm reset first.
    if (controller.state == TranscriptionState.done ||
        controller.state == TranscriptionState.error) {
      final ok = await _confirmReset(controller);
      if (!ok) return;
      setState(() => _intake = null);
    }

    if (!mounted) return;

    // Show patient intake; only start recording if user submits.
    final intake = await showModalBottomSheet<_PatientIntake>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatientIntakeSheet(services: _services),
    );
    if (intake == null || !mounted) return;
    setState(() => _intake = intake);
    await controller.toggleRecording();
  }

  Future<bool> _confirmReset(TranscriptionController c) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Start a new session?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('The current transcript and AI outputs will be cleared.'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start new'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _promptedForSave = false;
      _lastSavedSignature = null;
    }
    return confirmed == true;
  }
}

// ────────────────────────────────────────────────────────────────────────────
//   PREMIUM HERO RECORDER
// ────────────────────────────────────────────────────────────────────────────

class _RecorderHero extends StatelessWidget {
  final TranscriptionController controller;
  final Duration elapsed;
  final _PatientIntake? intake;
  final VoidCallback? onMicTap;
  const _RecorderHero({
    required this.controller,
    required this.elapsed,
    this.intake,
    this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = controller.isRecording;
    final isProcessing = controller.isProcessing;
    final isDone = controller.state == TranscriptionState.done &&
        controller.transcription.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        children: [
          // Status pill + live timer
          Row(
            children: [
              _StatusPill(controller: controller),
              const Spacer(),
              _Timer(
                elapsed: elapsed,
                isActive: isRecording,
                isDone: isDone,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Always-visible waveform — pulses when idle, alive when recording
          SizedBox(
            height: 80,
            child: AudioSignalBox(
              isActive: isRecording || isProcessing,
              color: isRecording
                  ? _danger
                  : (isProcessing ? _brand : _faint.withValues(alpha: 0.6)),
              audioLevel: controller.audioLevel,
            ),
          ),
          const SizedBox(height: 18),

          // Patient badge — shown when intake was captured
          if (intake != null && !isRecording && !isProcessing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _brand.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: _brand),
                  const SizedBox(width: 6),
                  Text(
                    intake!.displayName.isEmpty ? 'Patient ready' : intake!.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _brand,
                    ),
                  ),
                  if (intake!.gender.isNotEmpty) ...[
                    const Text('  ·  ', style: TextStyle(color: _faint, fontSize: 12)),
                    Text(
                      '${intake!.gender}${intake!.age.isNotEmpty ? ", ${intake!.age}y" : ""}',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Big mic button
          _MicButton(
            isRecording: isRecording,
            isDisabled: isProcessing,
            onTap: onMicTap ?? controller.toggleRecording,
          ),
          const SizedBox(height: 14),

          // Helper text
          Text(
            _helperText(controller, isDone),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _FeaturePill(icon: Icons.auto_awesome, label: 'Auto-summary'),
              _FeaturePill(icon: Icons.medication_outlined, label: 'Auto-Rx'),
              _FeaturePill(icon: Icons.bolt_rounded, label: 'AI insights'),
            ],
          ),
        ],
      ),
    );
  }

  String _helperText(TranscriptionController c, bool isDone) {
    switch (c.state) {
      case TranscriptionState.idle:
        return 'Tap to start recording the consultation';
      case TranscriptionState.recording:
        return 'Tap again to stop and generate AI outputs';
      case TranscriptionState.transcribing:
        return 'Converting audio to text…';
      case TranscriptionState.classifying:
        return 'Identifying who is Doctor and Patient from the conversation…';
      case TranscriptionState.processing:
        return 'Generating summary and prescription…';
      case TranscriptionState.done:
        return isDone
            ? 'Review results below or tap mic to record again'
            : 'Tap mic to start a new recording';
      case TranscriptionState.error:
        return 'Tap mic to try again';
    }
  }
}

class _StatusPill extends StatelessWidget {
  final TranscriptionController controller;
  const _StatusPill({required this.controller});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _styleFor(controller.state);
    final isProcessing = controller.isProcessing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProcessing) ...[
            const CupertinoActivityIndicator(radius: 6),
            const SizedBox(width: 6),
          ] else
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _styleFor(TranscriptionState s) {
    switch (s) {
      case TranscriptionState.idle:
        return ('Ready', _muted, const Color(0xFFF3F4F6));
      case TranscriptionState.recording:
        return ('Recording', _danger, _danger.withValues(alpha: 0.10));
      case TranscriptionState.transcribing:
        return ('Transcribing', _brand, _brand.withValues(alpha: 0.10));
      case TranscriptionState.classifying:
        return ('Identifying speakers', _brand, _brand.withValues(alpha: 0.10));
      case TranscriptionState.processing:
        return ('Generating', _brand, _brand.withValues(alpha: 0.10));
      case TranscriptionState.done:
        return ('Complete', _success, _success.withValues(alpha: 0.10));
      case TranscriptionState.error:
        return ('Error', _danger, _danger.withValues(alpha: 0.10));
    }
  }
}

class _Timer extends StatelessWidget {
  final Duration elapsed;
  final bool isActive;
  final bool isDone;
  const _Timer(
      {required this.elapsed, required this.isActive, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final color = isActive ? _danger : (isDone ? _ink : _faint);
    return Text(
      '$mm:$ss',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -0.5,
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isDisabled;
  final VoidCallback onTap;

  const _MicButton({
    required this.isRecording,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? _danger : _brand;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? _faint.withValues(alpha: 0.25) : color,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 20,
                    spreadRadius: isRecording ? 6 : 0,
                  ),
                ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _brand),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//   RESULTS LIST
// ────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final TranscriptionController controller;
  const _ResultsList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ResultRow(
            icon: Icons.record_voice_over_rounded,
            iconColor: const Color(0xFF14B8A6),
            title: 'Transcript',
            preview: _preview(controller.transcription),
            isReady: controller.transcription.isNotEmpty,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TranscriptionDetailScreen(
                  transcription: controller.transcription,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          _ResultRow(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Summary',
            preview: _preview(controller.summary),
            isReady: controller.summary.isNotEmpty,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SummaryScreen(summary: controller.summary),
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          _ResultRow(
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFFEA580C),
            title: 'Prescription',
            preview: _preview(controller.prescription),
            isReady: controller.prescription.isNotEmpty,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrescriptionScreen(
                  prescription: controller.prescription,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _preview(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final single = t.replaceAll(RegExp(r'\s+'), ' ');
    return single.length > 80 ? '${single.substring(0, 80)}…' : single;
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String preview;
  final bool isReady;
  final VoidCallback onTap;

  const _ResultRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.preview,
    required this.isReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isReady ? onTap : null,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isReady
                      ? iconColor.withValues(alpha: 0.12)
                      : _faint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: isReady ? iconColor : _faint,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isReady ? _ink : _faint,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview.isEmpty
                          ? 'Record a session to generate'
                          : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: preview.isEmpty ? _faint : _muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isReady ? _faint : _border,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//   HISTORY CARD  (kept for potential re-use)
// ────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _HistorySheet extends StatelessWidget {
  final List<ConsultationSession> sessions;
  final bool isLoading;
  final ValueChanged<ConsultationSession> onTapSession;
  final VoidCallback onRefresh;

  const _HistorySheet({
    required this.sessions,
    required this.isLoading,
    required this.onTapSession,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.88,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Session History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (sessions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${sessions.length} sessions',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brand,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: _muted, size: 20),
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'All recorded consultations from this device',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildBody(),
          ),
          SizedBox(height: mq.padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && sessions.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _faint.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 36, color: _faint),
            ),
            const SizedBox(height: 16),
            const Text(
              'No sessions yet',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Record a consultation and it will\nappear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: sessions.length + (isLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == sessions.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 8),
                SizedBox(width: 8),
                Text('Refreshing…',
                    style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          );
        }
        final s = sessions[i];
        return _HistoryCard(session: s, onTap: () => onTapSession(s));
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ConsultationSession session;
  final VoidCallback onTap;
  const _HistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final patient = session.patientName.trim().isEmpty
        ? 'Untitled patient'
        : session.patientName;
    final hasSummary = session.summary.trim().isNotEmpty;
    final hasRx = session.prescription.trim().isNotEmpty;
    final preview = _preview(session.transcript);

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _initials(patient),
                    style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(session.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: _faint),
                        ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: _muted, height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (session.durationSeconds > 0)
                          _Badge(
                            icon: Icons.timer_outlined,
                            label: session.formattedDuration,
                            color: _muted,
                          ),
                        if (hasSummary)
                          _Badge(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Summary',
                            color: _brand,
                          ),
                        if (hasRx)
                          _Badge(
                            icon: Icons.medication_outlined,
                            label: 'Rx',
                            color: const Color(0xFFEA580C),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: _faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final single = t.replaceAll(RegExp(r'\s+'), ' ');
    return single.length > 100 ? '${single.substring(0, 100)}…' : single;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

// ────────────────────────────────────────────────────────────────────────────
//   PATIENT INTAKE SHEET  (shown before recording starts)
// ────────────────────────────────────────────────────────────────────────────

class _PatientIntakeSheet extends StatefulWidget {
  final HealthcareServicesManager services;
  const _PatientIntakeSheet({required this.services});

  @override
  State<_PatientIntakeSheet> createState() => _PatientIntakeSheetState();
}

class _PatientIntakeSheetState extends State<_PatientIntakeSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── New patient form fields ───────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  String _gender = '';
  final _ageCtrl = TextEditingController();
  final _foodAllergyCtrl = TextEditingController();
  final _medAllergyCtrl = TextEditingController();
  final _surgeryCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _showOptional = false;
  bool _formError = false;

  // ── Existing patient search ───────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  List<ProviderPatientRecord> _patients = [];
  List<ProviderPatientRecord> _filtered = [];
  bool _loadingPatients = true;
  ProviderPatientRecord? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadPatients();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _nameCtrl, _ageCtrl, _foodAllergyCtrl, _medAllergyCtrl,
      _surgeryCtrl, _bpCtrl, _heightCtrl, _weightCtrl, _searchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final list = await widget.services.firestore.getDoctorPatients(
        widget.services.currentDoctorId,
      );
      if (mounted) {
        setState(() {
          _patients = list;
          _filtered = list;
          _loadingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  void _filterPatients(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _patients
          : _patients
              .where((p) => p.fullName.toLowerCase().contains(lower))
              .toList();
    });
  }

  List<String> _splitTags(String raw) =>
      raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  void _submitNew() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _formError = true);
      return;
    }
    Navigator.of(context).pop(_PatientIntake(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      age: _ageCtrl.text.trim(),
      foodAllergies: _splitTags(_foodAllergyCtrl.text),
      medAllergies: _splitTags(_medAllergyCtrl.text),
      surgeries: _splitTags(_surgeryCtrl.text),
      bp: _bpCtrl.text.trim(),
      height: _heightCtrl.text.trim(),
      weight: _weightCtrl.text.trim(),
    ));
  }

  void _submitExisting() {
    if (_selectedPatient == null) return;
    Navigator.of(context).pop(_PatientIntake(existing: _selectedPatient));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: _brand, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Who is this consultation for?',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: _ink, letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: _muted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: _brand,
              unselectedLabelColor: _muted,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'New Patient'),
                Tab(text: 'Existing Patient'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildNewForm(),
                _buildExistingSearch(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, mq.padding.bottom + 12),
            child: ListenableBuilder(
              listenable: _tab,
              builder: (_, __) => ElevatedButton(
                onPressed: _tab.index == 0 ? _submitNew : _submitExisting,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _tab.index == 0 ? 'Start Recording' : 'Start Recording with Selected Patient',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Patient name *'),
          _field(_nameCtrl, 'Full name', Icons.person_outline,
              error: _formError && _nameCtrl.text.isEmpty,
              onChanged: (_) => setState(() => _formError = false)),
          const SizedBox(height: 12),
          _label('Gender'),
          Row(
            children: ['Male', 'Female', 'Other'].map((g) {
              final sel = _gender == g;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _gender = sel ? '' : g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? _brand : _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _brand : _border),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: sel ? Colors.white : _ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _label('Age'),
          _field(_ageCtrl, 'e.g. 42', Icons.calendar_today_outlined,
              inputType: TextInputType.number),
          const SizedBox(height: 16),
          // Optional section
          GestureDetector(
            onTap: () => setState(() => _showOptional = !_showOptional),
            child: Row(
              children: [
                Text(
                  _showOptional ? 'Hide optional details' : 'Add optional details',
                  style: const TextStyle(
                    fontSize: 13, color: _brand, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showOptional
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _brand, size: 18,
                ),
              ],
            ),
          ),
          if (_showOptional) ...[
            const SizedBox(height: 12),
            _label('Food allergies (comma-separated)'),
            _field(_foodAllergyCtrl, 'e.g. Peanuts, Shellfish',
                Icons.no_food_outlined),
            const SizedBox(height: 12),
            _label('Medicinal allergies (comma-separated)'),
            _field(_medAllergyCtrl, 'e.g. Penicillin, Aspirin',
                Icons.medication_outlined),
            const SizedBox(height: 12),
            _label('Previous surgeries (comma-separated)'),
            _field(_surgeryCtrl, 'e.g. Appendectomy 2018',
                Icons.local_hospital_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Blood pressure'),
                      _field(_bpCtrl, '120/80',
                          Icons.favorite_border_rounded),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Height'),
                      _field(_heightCtrl, 'e.g. 175 cm',
                          Icons.height_rounded),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Weight'),
                      _field(_weightCtrl, 'e.g. 70 kg',
                          Icons.monitor_weight_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExistingSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filterPatients,
            decoration: InputDecoration(
              hintText: 'Search by name…',
              prefixIcon: const Icon(Icons.search, color: _muted),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 2)),
            ),
          ),
        ),
        Expanded(
          child: _loadingPatients
              ? const Center(child: CupertinoActivityIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'No patients yet.\nCreate one with "New Patient".'
                            : 'No patients match "${_searchCtrl.text}".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final sel = _selectedPatient?.id == p.id;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selectedPatient = sel ? null : p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _brand.withValues(alpha: 0.06)
                                  : _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel ? _brand : _border,
                                  width: sel ? 1.5 : 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: _brand.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      p.firstName.isNotEmpty
                                          ? p.firstName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: _brand,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.fullName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: _ink)),
                                      if (p.gender.isNotEmpty ||
                                          p.age > 0)
                                        Text(
                                          [
                                            if (p.gender.isNotEmpty) p.gender,
                                            if (p.age > 0) '${p.age}y',
                                          ].join(' · '),
                                          style: const TextStyle(
                                              fontSize: 12, color: _muted),
                                        ),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _brand, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool error = false,
    TextInputType inputType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: error ? _danger : _muted),
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: error ? _danger : _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: error ? _danger : _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: error ? _danger : _brand, width: 2)),
        errorText: error ? 'Required' : null,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
