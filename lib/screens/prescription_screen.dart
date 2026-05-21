import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../core/healthcare/clinical_text_parser.dart';
import '../core/healthcare/consultation_ui_theme.dart';
import '../theme/app_theme.dart';

class PrescriptionScreen extends StatefulWidget {
  final String prescription;

  const PrescriptionScreen({super.key, required this.prescription});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  bool _isSaving = false;

  Future<void> _exportPrescription() async {
    if (widget.prescription.trim().isEmpty) {
      _showMessage('No prescription content to export');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        _showMessage('Storage permission needed to export');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/prescription_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(filePath).writeAsString(widget.prescription);
      await Share.shareXFiles([XFile(filePath)], text: 'Clinical prescription draft');
      _showMessage('Prescription exported');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: (message.toLowerCase().contains('fail') || message.toLowerCase().contains('error')) ? AppTheme.dangerColor : AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ClinicalTextParser.parsePrescription(widget.prescription);
    final ready = data.missing.isEmpty && data.medications.isNotEmpty;

    return Scaffold(
      backgroundColor: ConsultationPalette.cream,
      appBar: AppBar(
        title: const Text('Prescription Draft'),
        backgroundColor: ConsultationPalette.surface,
        foregroundColor: ConsultationPalette.charcoal,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined),
            onPressed: widget.prescription.trim().isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: widget.prescription));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
                    );
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _exportPrescription,
        backgroundColor: ConsultationPalette.prescription,
        foregroundColor: Colors.white,
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.ios_share),
        label: const Text('Export'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(data, ready),
            const SizedBox(height: AppTheme.lg),
            _DisclaimerBanner(),
            const SizedBox(height: AppTheme.lg),
            _MedCard(items: data.medications),
            const SizedBox(height: AppTheme.md),
            _SectionCard(
              title: 'Tests & diagnostics',
              icon: Icons.biotech_outlined,
              accent: ConsultationPalette.transcript,
              items: data.tests,
              emptyHint: 'No investigations suggested for this visit.',
            ),
            const SizedBox(height: AppTheme.md),
            _SectionCard(
              title: 'Patient instructions',
              icon: Icons.menu_book_outlined,
              accent: ConsultationPalette.doctor,
              items: data.instructions,
              emptyHint: 'Add follow-up and self-care guidance.',
            ),
            if (data.warnings.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              _SectionCard(
                title: 'Warnings & cautions',
                icon: Icons.warning_amber_rounded,
                accent: ConsultationPalette.warning,
                items: data.warnings,
              ),
            ],
            if (data.missing.isNotEmpty) ...[
              const SizedBox(height: AppTheme.md),
              _SectionCard(
                title: 'Missing for safe prescribing',
                icon: Icons.error_outline,
                accent: ConsultationPalette.warning,
                items: data.missing,
              ),
            ],
            const SizedBox(height: AppTheme.lg),
            _RawExpansion(raw: widget.prescription),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(PrescriptionData data, bool ready) {
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
                child: const Icon(Icons.medication, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              const Expanded(
                child: Text(
                  'Treatment plan',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (ready ? AppTheme.successColor : ConsultationPalette.warning).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ready ? 'Draft ready' : 'Review needed',
                  style: TextStyle(
                    color: ready ? Colors.white : ConsultationPalette.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.xs,
            children: [
              _HeroStat('${data.medications.length} meds', Icons.medication_liquid),
              _HeroStat('${data.tests.length} tests', Icons.science_outlined),
              _HeroStat('${data.warnings.length} alerts', Icons.shield_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _HeroStat(String label, IconData icon) {
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

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: ConsultationPalette.warning.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: ConsultationPalette.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: ConsultationPalette.warning, size: 20),
          SizedBox(width: AppTheme.sm),
          Expanded(
            child: Text(
              'AI-generated draft for clinician review only. Verify allergies, dosing, and interactions before prescribing.',
              style: TextStyle(fontSize: 12, height: 1.4, color: ConsultationPalette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  final List<String> items;

  const _MedCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: ConsultationPalette.prescription.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medication_outlined, color: ConsultationPalette.prescription),
              SizedBox(width: AppTheme.sm),
              Text('Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: ConsultationPalette.ink)),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (items.isEmpty)
            const Text(
              'No medications identified — review transcript or add manually.',
              style: TextStyle(color: ConsultationPalette.muted, fontStyle: FontStyle.italic),
            )
          else
            ...items.map((item) => _MedTile(text: item)),
        ],
      ),
    );
  }
}

class _MedTile extends StatelessWidget {
  final String text;

  const _MedTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final isOtc = text.toLowerCase().contains('(otc)') || text.toLowerCase().contains('over-the-counter');
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: ConsultationPalette.prescription.withValues(alpha: 0.05),
        borderRadius: AppTheme.smallRadius,
        border: Border(left: BorderSide(color: ConsultationPalette.prescription, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: const TextStyle(height: 1.45, fontSize: 14))),
          if (isOtc)
            Container(
              margin: const EdgeInsets.only(left: AppTheme.sm),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ConsultationPalette.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('OTC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ConsultationPalette.goldMuted)),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;
  final String? emptyHint;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: ConsultationPalette.surface,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
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
          if (items.isEmpty)
            Text(emptyHint ?? 'None listed.', style: const TextStyle(color: ConsultationPalette.muted, fontStyle: FontStyle.italic))
          else
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
                    Expanded(child: Text(item, style: const TextStyle(height: 1.45, fontSize: 14))),
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
              child: SelectableText(raw, style: const TextStyle(fontSize: 13, height: 1.5, color: ConsultationPalette.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
