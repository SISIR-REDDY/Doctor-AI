import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/healthcare/clinical_text_parser.dart';
import '../core/healthcare/consultation_ui_theme.dart';
import '../theme/app_theme.dart';

class TranscriptionDetailScreen extends StatelessWidget {
  final String transcription;

  const TranscriptionDetailScreen({super.key, required this.transcription});

  @override
  Widget build(BuildContext context) {
    final insights = ClinicalTextParser.parseTranscript(transcription);

    return Scaffold(
      backgroundColor: ConsultationPalette.cream,
      appBar: AppBar(
        title: const Text('Consultation Transcript'),
        backgroundColor: ConsultationPalette.surface,
        foregroundColor: ConsultationPalette.charcoal,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy transcript',
            onPressed: transcription.trim().isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: transcription));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transcript copied'), duration: Duration(seconds: 1)),
                    );
                  },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: transcription.trim().isEmpty
          ? const Center(
              child: Text('No transcript available', style: TextStyle(color: ConsultationPalette.muted)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, AppTheme.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(insights),
                  const SizedBox(height: AppTheme.lg),
                  if (insights.patientSummary.isNotEmpty) ...[
                    _PatientSaysCard(summary: insights.patientSummary),
                    const SizedBox(height: AppTheme.lg),
                  ],
                  if (insights.symptoms.isNotEmpty) ...[
                    _SymptomsCard(symptoms: insights.symptoms),
                    const SizedBox(height: AppTheme.lg),
                  ],
                  if (insights.keyPhrases.isNotEmpty) ...[
                    _KeyMomentsCard(phrases: insights.keyPhrases),
                    const SizedBox(height: AppTheme.lg),
                  ],
                  _TimelineCard(utterances: insights.utterances),
                  const SizedBox(height: AppTheme.lg),
                  _FullTranscriptCard(text: transcription),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(TranscriptInsights insights) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: ConsultationPalette.headerGradient,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: ConsultationPalette.charcoal.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: const Icon(Icons.record_voice_over, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              const Expanded(
                child: Text(
                  'Conversation captured',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              _StatChip(label: '${insights.wordCount} words', icon: Icons.text_fields),
              const SizedBox(width: AppTheme.sm),
              _StatChip(label: '~${insights.estimatedMinutes} min', icon: Icons.timer_outlined),
              const SizedBox(width: AppTheme.sm),
              _StatChip(label: '${insights.utterances.length} turns', icon: Icons.forum_outlined),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.xs,
            children: [
              _SpeakerPill('Doctor', insights.doctorCount, ConsultationPalette.doctor),
              _SpeakerPill('Patient', insights.patientCount, ConsultationPalette.patient),
              if (insights.otherCount > 0)
                _SpeakerPill('Other', insights.otherCount, ConsultationPalette.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SpeakerPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SpeakerPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PatientSaysCard extends StatelessWidget {
  final String summary;

  const _PatientSaysCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.patient.withValues(alpha: 0.08),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: ConsultationPalette.patient.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: ConsultationPalette.patient, size: 20),
              SizedBox(width: AppTheme.sm),
              Text('What the patient reported', style: TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(summary, style: const TextStyle(fontSize: 15, height: 1.5, color: ConsultationPalette.ink, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  final List<String> symptoms;

  const _SymptomsCard({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: ConsultationPalette.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Symptoms mentioned', style: TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.sm,
            children: symptoms
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ConsultationPalette.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s, style: const TextStyle(color: ConsultationPalette.warning, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _KeyMomentsCard extends StatelessWidget {
  final List<String> phrases;

  const _KeyMomentsCard({required this.phrases});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Key moments', style: TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
          const SizedBox(height: AppTheme.sm),
          ...phrases.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, size: 18, color: ConsultationPalette.gold),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(child: Text(p, style: const TextStyle(height: 1.4, fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final List<TranscriptUtterance> utterances;

  const _TimelineCard({required this.utterances});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conversation timeline', style: TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
          const SizedBox(height: AppTheme.md),
          ...utterances.map((u) => _ChatBubble(utterance: u)),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final TranscriptUtterance utterance;

  const _ChatBubble({required this.utterance});

  Color get _color {
    switch (utterance.speaker) {
      case 'Doctor':
        return ConsultationPalette.doctor;
      case 'Patient':
        return ConsultationPalette.patient;
      default:
        return ConsultationPalette.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = utterance.speaker == 'Doctor';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isDoctor ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isDoctor) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _color.withValues(alpha: 0.15),
              child: Icon(
                utterance.speaker == 'Patient' ? Icons.person : Icons.chat_bubble_outline,
                size: 16,
                color: _color,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.md),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isDoctor ? 16 : 4),
                  bottomRight: Radius.circular(isDoctor ? 4 : 16),
                ),
                border: Border.all(color: _color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    utterance.speaker,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color),
                  ),
                  const SizedBox(height: 4),
                  Text(utterance.text, style: const TextStyle(fontSize: 14, height: 1.45, color: ConsultationPalette.ink)),
                ],
              ),
            ),
          ),
          if (isDoctor) ...[
            const SizedBox(width: AppTheme.sm),
            CircleAvatar(
              radius: 16,
              backgroundColor: _color.withValues(alpha: 0.15),
              child: Icon(Icons.medical_services_outlined, size: 16, color: _color),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullTranscriptCard extends StatelessWidget {
  final String text;

  const _FullTranscriptCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text('Full transcript', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.lg),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 14, height: 1.55, color: ConsultationPalette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
