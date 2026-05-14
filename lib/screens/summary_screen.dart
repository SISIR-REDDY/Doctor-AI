import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const Color _bgStart = Color(0xFFF3F5FF);
const Color _bgEnd = Color(0xFFEFF9F7);
const Color _surface = Colors.white;
const Color _ink = Color(0xFF1F2430);
const Color _muted = Color(0xFF6B7280);
const Color _accent = Color(0xFF4C6FFF);
const Color _accentSoft = Color(0xFFE8EEFF);
const Color _warning = Color(0xFFFFB020);

class SummaryScreen extends StatelessWidget {
  final String summary;

  const SummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final data = _parseSummary(summary);
    final missingCount = data.missing.length;
    final completeness = _completenessLabel(missingCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
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
                _buildHero(completeness, missingCount),
                const SizedBox(height: 16),
                _buildAtAGlance(data),
                const SizedBox(height: 16),
                _buildSectionGrid(data),
                const SizedBox(height: 16),
                _buildPlanCard(data),
                const SizedBox(height: 16),
                _buildMissingCard(data),
                const SizedBox(height: 16),
                _buildRawOutput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String completeness, int missingCount) {
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
                child: const Icon(Icons.summarize, color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Conversation Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              _Pill(label: completeness, color: _accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            missingCount == 0
                ? 'All core sections captured.'
                : '$missingCount missing or incomplete section(s) detected.',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildAtAGlance(_SummaryData data) {
    final chief = _firstLine(data.sections['Chief complaint']);
    final assessment = _firstLine(data.sections['Assessment']);
    final plan = _firstLine(data.sections['Plan']);

    return Row(
      children: [
        Expanded(
          child: _KpiTile(label: 'Chief complaint', value: chief),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(label: 'Assessment', value: assessment),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(label: 'Plan', value: plan),
        ),
      ],
    );
  }

  Widget _buildSectionGrid(_SummaryData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 420;
        final children = <Widget>[
          _SectionCard(
            title: 'Chief complaint',
            icon: Icons.report,
            color: _accent,
            items: data.sections['Chief complaint'] ?? [],
          ),
          _SectionCard(
            title: 'HPI',
            icon: Icons.sticky_note_2,
            color: _accent,
            items: data.sections['HPI'] ?? [],
          ),
          _SectionCard(
            title: 'Findings',
            icon: Icons.search,
            color: _accent,
            items: data.sections['Findings/Observations'] ?? [],
          ),
          _SectionCard(
            title: 'Assessment',
            icon: Icons.fact_check,
            color: _accent,
            items: data.sections['Assessment'] ?? [],
          ),
        ];

        if (!isWide) {
          return Column(
            children: children
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: card,
                    ))
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPlanCard(_SummaryData data) {
    return _SectionCard(
      title: 'Plan and next steps',
      icon: Icons.playlist_add_check,
      color: _accent,
      items: data.sections['Plan'] ?? [],
      fallback: 'No plan details captured yet.',
    );
  }

  Widget _buildMissingCard(_SummaryData data) {
    if (data.missing.isEmpty) {
      return _InfoCard(
        title: 'Missing details',
        icon: Icons.check_circle,
        color: Colors.green,
        message: 'No missing details detected.',
      );
    }

    return _SectionCard(
      title: 'Missing details',
      icon: Icons.warning_amber,
      color: _warning,
      items: data.missing,
      tone: _warning,
    );
  }

  Widget _buildRawOutput() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _surface,
      collapsedBackgroundColor: _surface,
      title: const Text(
        'Full output',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: summary.trim().isEmpty
              ? const Text('No summary available', style: TextStyle(color: _muted))
              : MarkdownBody(
                  data: summary,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.5, color: _ink),
                    h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _accent),
                    h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _accent),
                    h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _accent),
                    listBullet: const TextStyle(fontSize: 14, color: _accent),
                  ),
                ),
        ),
      ],
    );
  }

  String _completenessLabel(int missingCount) {
    if (missingCount == 0) return 'Complete';
    if (missingCount <= 2) return 'Partial';
    return 'Needs input';
  }

  String _firstLine(List<String>? lines) {
    if (lines == null || lines.isEmpty) return 'Not specified';
    return lines.first.trim();
  }

  _SummaryData _parseSummary(String input) {
    if (input.trim().isEmpty) {
      return _SummaryData.empty();
    }

    final sections = <String, List<String>>{
      'Chief complaint': [],
      'HPI': [],
      'Findings/Observations': [],
      'Assessment': [],
      'Plan': [],
    };
    final missing = <String>[];
    String? current;

    final lines = input.split('\n');
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final normalized = trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '');
      final headingMatch = RegExp(
        r'^(Chief complaint|HPI|Findings/Observations|Findings|Assessment|Plan|Next steps)\s*:?',
        caseSensitive: false,
      ).firstMatch(normalized);

      if (headingMatch != null) {
        final heading = _normalizeHeading(headingMatch.group(1) ?? '');
        current = heading;
        final after = normalized.substring(headingMatch.end).trim();
        if (after.isNotEmpty) {
          sections[current]!.add(after);
        }
        if (_isMissing(after)) {
          missing.add('$heading: $after');
        }
        continue;
      }

      if (current != null) {
        sections[current]!.add(normalized);
        if (_isMissing(normalized)) {
          missing.add('$current: $normalized');
        }
      } else if (_isMissing(normalized)) {
        missing.add(normalized);
      }
    }

    return _SummaryData(sections: sections, missing: missing);
  }

  String _normalizeHeading(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('chief')) return 'Chief complaint';
    if (lower == 'hpi') return 'HPI';
    if (lower.startsWith('findings')) return 'Findings/Observations';
    if (lower.startsWith('assessment')) return 'Assessment';
    return 'Plan';
  }

  bool _isMissing(String value) {
    final lower = value.toLowerCase();
    return lower.contains('not specified') ||
        lower.contains('insufficient') ||
        lower.contains('missing') ||
        lower.contains('not possible');
  }
}

class _SummaryData {
  final Map<String, List<String>> sections;
  final List<String> missing;

  const _SummaryData({required this.sections, required this.missing});

  factory _SummaryData.empty() {
    return const _SummaryData(sections: {}, missing: []);
  }
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

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;

  const _KpiTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String? fallback;
  final Color? tone;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.fallback,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? color;
    final content = items.isEmpty
        ? [fallback ?? 'No details provided.']
        : items;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveTone.withValues(alpha: 0.18)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveTone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveTone, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...content.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: _muted)),
                  Expanded(
                    child: Text(
                      item.trim(),
                      style: const TextStyle(fontSize: 12, color: _ink, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
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