import 'package:flutter/material.dart';

const Color _bgStart = Color(0xFFF3F5FF);
const Color _bgEnd = Color(0xFFEFF9F7);
const Color _surface = Colors.white;
const Color _ink = Color(0xFF1F2430);
const Color _muted = Color(0xFF6B7280);
const Color _accent = Color(0xFF4C6FFF);
const Color _accentSoft = Color(0xFFE8EEFF);
const Color _doctor = Color(0xFF4C6FFF);
const Color _patient = Color(0xFF12B5A6);

class TranscriptionDetailScreen extends StatelessWidget {
  final String transcription;

  const TranscriptionDetailScreen({super.key, required this.transcription});

  @override
  Widget build(BuildContext context) {
    final data = _parseTranscription(transcription);
    final stats = _buildStats(data);
    final highlights = _extractHighlights(data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgStart, _bgEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(stats),
                const SizedBox(height: 16),
                _buildHighlights(highlights),
                const SizedBox(height: 16),
                _buildTimeline(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(_TranscriptStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
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
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.record_voice_over, color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Doctor-Patient Conversation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              _Pill(label: '${stats.segments} segments', color: _accent),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: 'Doctor: ${stats.doctorCount}', color: _doctor),
              _Pill(label: 'Patient: ${stats.patientCount}', color: _patient),
              _Pill(label: 'Other: ${stats.otherCount}', color: _muted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(List<String> highlights) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key phrases',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          if (highlights.isEmpty)
            const Text('No highlights available yet.', style: TextStyle(color: _muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: highlights
                  .map((text) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 11, color: _ink),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<_Utterance> data) {
    if (data.isEmpty) {
      return _InfoCard(
        title: 'No transcription available',
        icon: Icons.info_outline,
        color: _muted,
        message: 'Record a session to generate the conversation timeline.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conversation timeline',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          ...data.map((utterance) => _TimelineTile(utterance: utterance)),
        ],
      ),
    );
  }

  _TranscriptStats _buildStats(List<_Utterance> data) {
    int doctor = 0;
    int patient = 0;
    int other = 0;
    for (final item in data) {
      if (item.speaker == 'Doctor') {
        doctor++;
      } else if (item.speaker == 'Patient') {
        patient++;
      } else {
        other++;
      }
    }

    return _TranscriptStats(
      segments: data.length,
      doctorCount: doctor,
      patientCount: patient,
      otherCount: other,
    );
  }

  List<_Utterance> _parseTranscription(String input) {
    if (input.trim().isEmpty) return [];

    final utterances = <_Utterance>[];
    final lines = input.split('\n').where((line) => line.trim().isNotEmpty);

    for (final raw in lines) {
      final line = raw.trim();
      final isDoctor = line.startsWith('Doctor:');
      final isPatient = line.startsWith('Patient:');

      if (isDoctor || isPatient) {
        final speaker = isDoctor ? 'Doctor' : 'Patient';
        final text = line.substring(line.indexOf(':') + 1).trim();
        utterances.add(_Utterance(speaker: speaker, text: text));
      } else {
        utterances.add(_Utterance(speaker: 'Other', text: line));
      }
    }

    return utterances;
  }

  List<String> _extractHighlights(List<_Utterance> data) {
    final phrases = <String>[];
    for (final item in data) {
      final text = item.text.trim();
      if (text.split(' ').length < 3) continue;
      phrases.add(text);
      if (phrases.length == 3) break;
    }
    return phrases;
  }
}

class _TranscriptStats {
  final int segments;
  final int doctorCount;
  final int patientCount;
  final int otherCount;

  const _TranscriptStats({
    required this.segments,
    required this.doctorCount,
    required this.patientCount,
    required this.otherCount,
  });
}

class _Utterance {
  final String speaker;
  final String text;

  const _Utterance({required this.speaker, required this.text});
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _Utterance utterance;

  const _TimelineTile({required this.utterance});

  @override
  Widget build(BuildContext context) {
    final isDoctor = utterance.speaker == 'Doctor';
    final isPatient = utterance.speaker == 'Patient';
    final color = isDoctor
        ? _doctor
        : isPatient
            ? _patient
            : _muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            utterance.speaker,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            utterance.text,
            style: const TextStyle(fontSize: 14, color: _ink, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String message;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}