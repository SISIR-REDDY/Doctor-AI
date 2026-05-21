import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/healthcare/clinical_text_parser.dart';
import '../core/healthcare/consultation_ui_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_md.dart';

class SummaryScreen extends StatelessWidget {
  final String summary;

  const SummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final data = ClinicalTextParser.parseSummary(summary);
    final missing = data.missingOrIncomplete;
    final completeness = missing.isEmpty ? 'Complete' : missing.length <= 2 ? 'Partial' : 'Needs review';

    return Scaffold(
      backgroundColor: ConsultationPalette.cream,
      appBar: AppBar(
        title: const Text('Clinical Summary'),
        backgroundColor: ConsultationPalette.surface,
        foregroundColor: ConsultationPalette.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Copy summary',
            icon: const Icon(Icons.copy_outlined),
            onPressed: summary.trim().isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: summary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied'), duration: Duration(seconds: 1)),
                    );
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, AppTheme.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              title: 'Visit overview',
              subtitle: data.hasStructuredContent
                  ? 'Structured SOAP notes from this consultation'
                  : 'Review narrative summary below',
              accent: ConsultationPalette.summary,
              badge: completeness,
              stats: [
                if (data.chiefComplaint.isNotEmpty) 'Complaint captured',
                if (data.assessment.isNotEmpty) 'Assessment documented',
                if (data.plan.isNotEmpty) 'Plan outlined',
              ],
            ),
            const SizedBox(height: AppTheme.lg),
            if (!data.hasStructuredContent && data.overview.isNotEmpty) ...[
              _NarrativeCard(text: data.overview),
              const SizedBox(height: AppTheme.lg),
            ],
            _SoapSection(
              title: 'Chief complaint',
              icon: Icons.report_gmailerrorred_outlined,
              accent: ConsultationPalette.warning,
              body: data.chiefComplaint,
            ),
            _SoapSection(
              title: 'History of present illness',
              icon: Icons.history_edu_outlined,
              accent: ConsultationPalette.summary,
              body: data.hpi,
            ),
            _SoapSection(
              title: 'Findings & observations',
              icon: Icons.search_outlined,
              accent: ConsultationPalette.transcript,
              body: data.findings,
            ),
            _SoapSection(
              title: 'Clinical assessment',
              icon: Icons.fact_check_outlined,
              accent: ConsultationPalette.doctor,
              body: data.assessment,
            ),
            _SoapSection(
              title: 'Plan & next steps',
              icon: Icons.playlist_add_check_outlined,
              accent: ConsultationPalette.prescription,
              body: data.plan,
            ),
            if (data.safetyFlags.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              _BulletSection(
                title: 'Safety flags',
                icon: Icons.warning_amber_rounded,
                accent: ConsultationPalette.warning,
                items: data.safetyFlags,
              ),
            ],
            if (data.followUp.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              _BulletSection(
                title: 'Follow-up',
                icon: Icons.event_available_outlined,
                accent: ConsultationPalette.transcript,
                items: data.followUp,
              ),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              _BulletSection(
                title: 'Needs clarification',
                icon: Icons.help_outline,
                accent: ConsultationPalette.muted,
                items: missing,
              ),
            ],
            const SizedBox(height: AppTheme.lg),
            _RawExpansion(raw: summary),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final String badge;
  final List<String> stats;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.badge,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: ConsultationPalette.headerGradient,
        borderRadius: AppTheme.largeRadius,
        boxShadow: [
          BoxShadow(
            color: ConsultationPalette.charcoal.withValues(alpha: 0.15),
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
                child: Icon(Icons.summarize, color: accent.withValues(alpha: 0.9), size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ConsultationPalette.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ConsultationPalette.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: ConsultationPalette.gold, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppTheme.md),
            Wrap(
              spacing: AppTheme.sm,
              runSpacing: AppTheme.xs,
              children: stats
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(s, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final String text;

  const _NarrativeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: ConsultationPalette.summary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Narrative summary', style: TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
          const SizedBox(height: AppTheme.sm),
          ClinicalMd(text, color: ConsultationPalette.ink, selectable: true),
        ],
      ),
    );
  }
}

class _SoapSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String body;

  const _SoapSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = body.trim().isNotEmpty && !_isEmpty(body);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: ConsultationPalette.surface,
          borderRadius: AppTheme.largeRadius,
          border: Border.all(color: accent.withValues(alpha: hasContent ? 0.2 : 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            if (hasContent)
              ClinicalMd(body.trim(), color: ConsultationPalette.ink, selectable: true)
            else
              const Text(
                'Not documented in this visit — tap to add in patient record.',
                style: TextStyle(
                  height: 1.5, fontSize: 14,
                  color: ConsultationPalette.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isEmpty(String v) {
    final lower = v.toLowerCase();
    return lower.contains('not available') || lower.contains('not specified');
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;

  const _BulletSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppTheme.sm),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ConsultationPalette.ink)),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(child: ClinicalMd(item, fontSize: 14, color: ConsultationPalette.ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawExpansion extends StatelessWidget {
  final String raw;

  const _RawExpansion({required this.raw});

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
          title: const Text('Full AI output', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.lg),
              child: SelectableText(
                raw.trim().isEmpty ? 'No summary generated.' : raw,
                style: const TextStyle(fontSize: 13, height: 1.5, color: ConsultationPalette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
