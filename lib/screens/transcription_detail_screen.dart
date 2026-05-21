import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/healthcare/clinical_text_parser.dart';
import '../core/healthcare/consultation_ui_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_md.dart';

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
          ClinicalMd(summary, fontSize: 15, color: ConsultationPalette.ink, selectable: true),
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
    if (utterances.isEmpty) return const SizedBox.shrink();

    // Detect how many distinct speakers are in the transcript.
    final speakers = utterances.map((u) => u.speaker).toSet();

    return Container(
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Conversation',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: ConsultationPalette.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ConsultationPalette.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${utterances.length} turns · ${speakers.length} speaker${speakers.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: ConsultationPalette.muted,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEFF3)),
          // ── Turns ─────────────────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: utterances.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEEEFF3)),
            itemBuilder: (_, i) => _TurnRow(
              utterance: utterances[i],
              index: i,
              totalSpeakers: speakers.length,
            ),
          ),
        ],
      ),
    );
  }
}

// Speaker colour palette — stable per role name so the same speaker always
// gets the same colour regardless of turn order.
Color _speakerColor(String speaker) {
  switch (speaker) {
    case 'Doctor':
      return const Color(0xFF1D4ED8); // deep clinical blue
    case 'Patient':
      return const Color(0xFF0F766E); // clinical teal
    default:
      // Deterministic from label text so Speaker 1 ≠ Speaker 2.
      final h = speaker.codeUnits.fold(0, (a, b) => a + b) % 360;
      return HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.40).toColor();
  }
}


String _speakerInitial(String speaker) {
  if (speaker == 'Doctor') return 'Dr';
  if (speaker == 'Patient') return 'Pt';
  // "Speaker 1" → "S1"
  final num = RegExp(r'\d+').firstMatch(speaker)?.group(0) ?? '';
  return num.isNotEmpty ? 'S$num' : speaker[0].toUpperCase();
}

class _TurnRow extends StatelessWidget {
  final TranscriptUtterance utterance;
  final int index;
  final int totalSpeakers;

  const _TurnRow({
    required this.utterance,
    required this.index,
    required this.totalSpeakers,
  });

  @override
  Widget build(BuildContext context) {
    final color = _speakerColor(utterance.speaker);
    final isEven = index.isEven;

    return Container(
      color: isEven
          ? Colors.transparent
          : ConsultationPalette.ink.withValues(alpha: 0.015),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Speaker avatar ──────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                _speakerInitial(utterance.speaker),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role label with left accent bar
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      utterance.speaker,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Actual speech
                Text(
                  utterance.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: ConsultationPalette.ink,
                  ),
                ),
              ],
            ),
          ),
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
