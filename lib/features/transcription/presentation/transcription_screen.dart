import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docpilot/core/healthcare/healthcare_services_manager.dart';
import 'package:docpilot/models/health_models.dart';
import 'package:docpilot/screens/prescription_screen.dart';
import 'package:docpilot/screens/summary_screen.dart';
import 'package:docpilot/screens/transcription_detail_screen.dart';
import 'package:docpilot/services/firebase/auth_service.dart';
import 'package:docpilot/services/firebase/firestore_service.dart';
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

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final HealthcareServicesManager _services = HealthcareServicesManager();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  bool _promptedForSave = false;
  String? _lastSavedSignature;
  String? _lastErrorShown;

  // Live elapsed-time tracking. We compute on every tick so the timer in the
  // hero card updates without changing the controller.
  Timer? _ticker;
  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  TranscriptionState? _lastState;

  // Recent sessions (loaded once, refreshed after save).
  List<ConsultationSession> _recentSessions = const [];
  bool _isLoadingSessions = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSessions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _isLoadingSessions = false);
      return;
    }
    try {
      final sessions =
          await _firestore.getConsultationHistory(doctorId: uid, limit: 3);
      if (!mounted) return;
      setState(() {
        _recentSessions = sessions;
        _isLoadingSessions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _RecorderHero(
              controller: controller,
              elapsed: _elapsed,
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Results'),
            _ResultsList(controller: controller),
            const SizedBox(height: 24),
            const _SectionHeader('Recent sessions'),
            _RecentSessionsList(
              sessions: _recentSessions,
              isLoading: _isLoadingSessions,
              onTapSession: (s) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TranscriptionDetailScreen(
                    transcription: s.transcript,
                  ),
                ),
              ),
            ),
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
      final suggestedName = _services
              .suggestPatientNameFromTranscript(controller.transcription) ??
          '';
      final enteredName =
          await _promptForPatientName(suggestedName: suggestedName);
      final resolvedName = _resolvePatientName(enteredName, suggestedName);

      final savedPatient = await _services.createPatientWithSession(
        patientName: resolvedName,
        transcript: controller.transcription,
        summary: controller.summary,
        prescription: controller.prescription,
        source: 'transcription',
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
          content: Text(
              'Saved to ${savedPatient.firstName} ${savedPatient.lastName}'
                  .trim()),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Refresh the recent sessions list so the just-saved one appears.
      _loadRecentSessions();
    });
  }

  String _buildSignature(TranscriptionController c) =>
      '${c.transcription.length}|${c.summary.length}|${c.prescription.length}';

  String _resolvePatientName(String? direct, String suggestion) {
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    if (suggestion.isNotEmpty) return suggestion;
    return 'Patient ${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> _promptForPatientName({required String suggestedName}) async {
    final ctrl = TextEditingController(text: suggestedName);
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Save to patient'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            placeholder: 'Patient name',
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Use suggested'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(TranscriptionController c) async {
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
      // Trigger a fresh record cycle. The controller resets data on start.
      await c.toggleRecording();
      if (c.isRecording) await c.toggleRecording();
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
//   PREMIUM HERO RECORDER
// ────────────────────────────────────────────────────────────────────────────

class _RecorderHero extends StatelessWidget {
  final TranscriptionController controller;
  final Duration elapsed;
  const _RecorderHero({required this.controller, required this.elapsed});

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

          // Big mic button
          _MicButton(
            isRecording: isRecording,
            isDisabled: isProcessing,
            onTap: controller.toggleRecording,
          ),
          const SizedBox(height: 14),

          // Helper text
          Text(
            _helperText(controller, isDone),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // AI feature pills (always visible — informs the doctor)
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
//   RECENT SESSIONS LIST (fills bottom space with real, useful data)
// ────────────────────────────────────────────────────────────────────────────

class _RecentSessionsList extends StatelessWidget {
  final List<ConsultationSession> sessions;
  final bool isLoading;
  final ValueChanged<ConsultationSession> onTapSession;

  const _RecentSessionsList({
    required this.sessions,
    required this.isLoading,
    required this.onTapSession,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }
    if (sessions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _faint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.history_rounded,
                  size: 18, color: _faint),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No past consultations yet. Recorded sessions will appear here.',
                style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < sessions.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _border),
            _SessionRow(
              session: sessions[i],
              onTap: () => onTapSession(sessions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ConsultationSession session;
  final VoidCallback onTap;
  const _SessionRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final patient = session.patientName.trim().isEmpty
        ? 'Untitled patient'
        : session.patientName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    _initialsOf(patient),
                    style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(session.createdAt),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _faint, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
