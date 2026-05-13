import 'package:docpilot/screens/prescription_screen.dart';
import 'package:docpilot/screens/summary_screen.dart';
import 'package:docpilot/screens/transcription_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'transcription_controller.dart';

class TranscriptionScreen extends StatelessWidget {
  const TranscriptionScreen({super.key});

  static const Color _bg = Color(0xFFF2F4F7);
  static const Color _card = Colors.white;
  static const Color _ink = Color(0xFF1E2733);
  static const Color _muted = Color(0xFF8B95A5);
  static const Color _sky = Color(0xFF6EA8FF);
  static const Color _mint = Color(0xFF58D6C7);
  static const Color _sun = Color(0xFFFFC857);
  static const Color _rose = Color(0xFFFF6B6B);
  static const Color _violet = Color(0xFF7B7BFF);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TranscriptionController>();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _buildTopBar(controller),
            const SizedBox(height: 16),
            _buildHeroCard(controller),
            const SizedBox(height: 16),
            _buildWaveformCard(controller),
            const SizedBox(height: 16),
            _buildInsightRow(controller),
            const SizedBox(height: 20),
            _buildSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            _buildActionRow(context, controller),
            const SizedBox(height: 20),
            _buildSectionTitle('Recent Snapshot'),
            const SizedBox(height: 12),
            _buildRecentCard(context, controller),
          ],
        ),
      ),
    );
  }

  String _statusText(TranscriptionState state) {
    switch (state) {
      case TranscriptionState.recording:    return 'Recording your voice...';
      case TranscriptionState.transcribing: return 'Transcribing your voice...';
      case TranscriptionState.processing:   return 'Processing with Gemini...';
      case TranscriptionState.error:        return 'Something went wrong';
      default:                              return 'Tap the mic to begin';
    }
  }

  String _statusDetailText(TranscriptionController controller) {
    switch (controller.state) {
      case TranscriptionState.recording:    return 'Recording in progress';
      case TranscriptionState.transcribing: return 'Processing audio...';
      case TranscriptionState.processing:   return 'Generating content with Gemini...';
      case TranscriptionState.done:         return 'Ready to view results';
      case TranscriptionState.error:        return controller.errorMessage ?? 'Error occurred';
      default:                              return 'Press the microphone button to start';
    }
  }

  String _statusLabel(TranscriptionController controller) {
    if (controller.state == TranscriptionState.error) {
      return 'Needs attention';
    }
    if (controller.isRecording) {
      return 'Recording';
    }
    if (controller.isProcessing) {
      return 'Processing';
    }
    return 'Ready';
  }

  Color _statusColor(TranscriptionController controller) {
    if (controller.state == TranscriptionState.error) {
      return _rose;
    }
    if (controller.isRecording) {
      return _rose;
    }
    if (controller.isProcessing) {
      return _sun;
    }
    return _mint;
  }

  Widget _buildTopBar(TranscriptionController controller) {
    final statusLabel = _statusLabel(controller);
    final statusColor = _statusColor(controller);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Welcome back',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 0.2),
            ),
            SizedBox(height: 4),
            Text(
              'DocPilot Studio',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 0.3),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(28),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(TranscriptionController controller) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2431), Color(0xFF364962)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _violet.withAlpha(30),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Voice clinic companion',
                            style: TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusText(controller.state),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusDetailText(controller),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildRecordOrb(controller),
                  ],
                ),
                const SizedBox(height: 16),
                if (controller.isProcessing)
                  LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white.withAlpha(26),
                    valueColor: const AlwaysStoppedAnimation<Color>(_sun),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tap the mic to capture a session',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniChip('Transcript', controller.transcription.isNotEmpty, _mint),
                    _buildMiniChip('Summary', controller.summary.isNotEmpty, _sky),
                    _buildMiniChip('Prescription', controller.prescription.isNotEmpty, _sun),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, bool isReady, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isReady ? color.withAlpha(38) : Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isReady ? color : Colors.white.withAlpha(40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isReady ? color : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildRecordOrb(TranscriptionController controller) {
    final isRecording = controller.isRecording;
    final baseColor = isRecording ? _rose : _sky;

    return GestureDetector(
      onTap: controller.isProcessing ? null : controller.toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: baseColor,
          boxShadow: [
            BoxShadow(
              color: baseColor.withAlpha(isRecording ? 120 : 80),
              blurRadius: isRecording ? 24 : 18,
              spreadRadius: isRecording ? 6 : 2,
            ),
          ],
        ),
        child: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildWaveformCard(TranscriptionController controller) {
    const barCount = 24;
    final isLive = controller.isRecording;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Signal Dock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
              ),
              const Spacer(),
              Text(
                isLive ? 'Live' : 'Idle',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isLive ? _mint : _muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLive)
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(barCount, (index) {
                  final value = controller.waveformValues[index % controller.waveformValues.length];
                  final height = 10 + value * 46;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: _mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            )
          else
            SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(barCount, (index) {
                  return Container(
                    width: 3,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _ink.withAlpha(40),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(TranscriptionController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildInsightCard(
            'Transcripts',
            controller.transcription.isNotEmpty ? '1' : '0',
            Icons.record_voice_over,
            _mint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInsightCard(
            'Summaries',
            controller.summary.isNotEmpty ? '1' : '0',
            Icons.summarize,
            _sky,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInsightCard(
            'Scripts',
            controller.prescription.isNotEmpty ? '1' : '0',
            Icons.medication,
            _sun,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withAlpha(38), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
    );
  }

  Widget _buildActionRow(BuildContext context, TranscriptionController controller) {
    return Column(
      children: [
        _buildActionTile(
          title: 'Transcription',
          subtitle: 'Raw conversation',
          icon: Icons.record_voice_over,
          color: _mint,
          isEnabled: controller.transcription.isNotEmpty,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => TranscriptionDetailScreen(transcription: controller.transcription),
          )),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          title: 'Summary',
          subtitle: 'Key takeaways',
          icon: Icons.summarize,
          color: _sky,
          isEnabled: controller.summary.isNotEmpty,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SummaryScreen(summary: controller.summary),
          )),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          title: 'Prescription',
          subtitle: 'Medication & notes',
          icon: Icons.medication,
          color: _sun,
          isEnabled: controller.prescription.isNotEmpty,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PrescriptionScreen(prescription: controller.prescription),
          )),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    final badgeText = isEnabled ? 'Open' : 'Locked';
    final badgeIcon = isEnabled ? Icons.arrow_forward : Icons.lock_outline;
    final badgeColor = isEnabled ? color : _muted;
    final actionHint = isEnabled ? 'Tap to review' : 'Record a session first';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(45), _card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withAlpha(70)),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -24,
                right: -10,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(28),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withAlpha(60),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isEnabled ? _ink : _muted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            actionHint,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Text(
                            badgeText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                          ),
                          const SizedBox(width: 6),
                          Icon(badgeIcon, size: 12, color: badgeColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, TranscriptionController controller) {
    final hasTranscript = controller.transcription.isNotEmpty;
    final preview = hasTranscript
        ? controller.transcription.trim()
        : 'No session recorded yet. Use the mic above to start.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Latest transcript',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
              ),
              const Spacer(),
              if (hasTranscript)
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TranscriptionDetailScreen(transcription: controller.transcription),
                  )),
                  child: const Text('Open'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview,
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: _violet.withAlpha(200)),
              const SizedBox(width: 6),
              Text(
                hasTranscript ? 'Ready for review' : 'Awaiting first session',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}