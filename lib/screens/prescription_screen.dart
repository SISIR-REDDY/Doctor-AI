import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

const Color _bgStart = Color(0xFFF3F5FF);
const Color _bgEnd = Color(0xFFEFF9F7);
const Color _surface = Colors.white;
const Color _ink = Color(0xFF1F2430);
const Color _muted = Color(0xFF6B7280);
const Color _accent = Color(0xFF4C6FFF);
const Color _accentSoft = Color(0xFFE8EEFF);
const Color _warning = Color(0xFFFFB020);

class PrescriptionScreen extends StatefulWidget {
  final String prescription;

  const PrescriptionScreen({super.key, required this.prescription});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  bool _isSaving = false;

  Future<void> _savePrescription() async {
    if (widget.prescription.isEmpty) {
      _showMessage('No prescription content to save');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showMessage('Storage permission is required to save the prescription');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'prescription_${DateTime.now().millisecondsSinceEpoch}.txt';
      final filePath = '${directory.path}/$fileName';

      // Write the prescription to a file
      final file = File(filePath);
      await file.writeAsString(widget.prescription);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Your medical prescription',
      );

      _showMessage('Prescription saved and shared');
    } catch (e) {
      _showMessage('Error saving prescription: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('Error') ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _parsePrescription(widget.prescription);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
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
                _buildHero(data),
                const SizedBox(height: 16),
                _buildMedicationCard(data),
                const SizedBox(height: 16),
                _buildTestsCard(data),
                const SizedBox(height: 16),
                _buildInstructionCard(data),
                const SizedBox(height: 16),
                _buildWarningsCard(data),
                const SizedBox(height: 16),
                _buildMissingCard(data),
                const SizedBox(height: 16),
                _buildRawOutput(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _savePrescription,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 8,
        tooltip: 'Save Prescription',
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.download),
      ),
    );
  }

  Widget _buildHero(_PrescriptionData data) {
    final chipColor = data.missing.isEmpty ? Colors.green : _warning;

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
                child: const Icon(Icons.medication, color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Prescription Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              _Pill(label: data.missing.isEmpty ? 'Ready' : 'Needs input', color: chipColor),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: 'Meds: ${data.medications.length}', color: _accent),
              _Pill(label: 'Tests: ${data.tests.length}', color: _accent),
              _Pill(label: 'Warnings: ${data.warnings.length}', color: _warning),
              _Pill(label: 'Missing: ${data.missing.length}', color: chipColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(_PrescriptionData data) {
    return _SectionCard(
      title: 'Medications',
      icon: Icons.medical_services,
      color: _accent,
      items: data.medications,
      fallback: 'No medication details provided yet.',
    );
  }

  Widget _buildTestsCard(_PrescriptionData data) {
    return _SectionCard(
      title: 'Tests and diagnostics',
      icon: Icons.biotech,
      color: _accent,
      items: data.tests,
      fallback: 'No tests listed.',
    );
  }

  Widget _buildInstructionCard(_PrescriptionData data) {
    return _SectionCard(
      title: 'Instructions and follow-up',
      icon: Icons.task_alt,
      color: _accent,
      items: data.instructions,
      fallback: 'No follow-up instructions captured.',
    );
  }

  Widget _buildWarningsCard(_PrescriptionData data) {
    return _SectionCard(
      title: 'Warnings and cautions',
      icon: Icons.warning_amber,
      color: _warning,
      items: data.warnings,
      fallback: 'No warnings noted.',
      tone: _warning,
    );
  }

  Widget _buildMissingCard(_PrescriptionData data) {
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
      icon: Icons.error_outline,
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
          child: widget.prescription.trim().isEmpty
              ? const Text('No prescription available', style: TextStyle(color: _muted))
              : MarkdownBody(
                  data: widget.prescription,
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

  _PrescriptionData _parsePrescription(String input) {
    final medications = <String>[];
    final tests = <String>[];
    final instructions = <String>[];
    final warnings = <String>[];
    final missing = <String>[];

    if (input.trim().isEmpty) {
      return _PrescriptionData(
        medications: medications,
        tests: tests,
        instructions: instructions,
        warnings: warnings,
        missing: missing,
      );
    }

    bool captureMissing = false;
    final lines = input.split('\n');
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final line = trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '');
      final lower = line.toLowerCase();

      if (lower.startsWith('missing details')) {
        captureMissing = true;
        continue;
      }

      if (captureMissing) {
        if (_isSectionHeader(lower)) {
          captureMissing = false;
        } else {
          missing.add(line);
          continue;
        }
      }

      if (_looksLikeMedication(lower)) {
        medications.add(line);
        continue;
      }
      if (_looksLikeTest(lower)) {
        tests.add(line);
        continue;
      }
      if (_looksLikeWarning(lower)) {
        warnings.add(line);
        continue;
      }
      if (_looksLikeInstruction(lower)) {
        instructions.add(line);
        continue;
      }

      instructions.add(line);
    }

    return _PrescriptionData(
      medications: medications,
      tests: tests,
      instructions: instructions,
      warnings: warnings,
      missing: missing,
    );
  }

  bool _looksLikeMedication(String value) {
    return value.contains('mg') ||
        value.contains('tablet') ||
        value.contains('capsule') ||
        value.contains('dose') ||
        value.contains('take ') ||
        value.contains('rx') ||
        value.contains('medication');
  }

  bool _looksLikeTest(String value) {
    return value.contains('test') ||
        value.contains('lab') ||
        value.contains('scan') ||
        value.contains('x-ray') ||
        value.contains('mri') ||
        value.contains('ct');
  }

  bool _looksLikeWarning(String value) {
    return value.contains('avoid') ||
        value.contains('allergy') ||
        value.contains('warning') ||
        value.contains('contraindicated');
  }

  bool _looksLikeInstruction(String value) {
    return value.contains('follow') ||
        value.contains('review') ||
        value.contains('return') ||
        value.contains('monitor') ||
        value.contains('instruction');
  }

  bool _isSectionHeader(String value) {
    return value.contains('prescription') || value.contains('summary');
  }
}

class _PrescriptionData {
  final List<String> medications;
  final List<String> tests;
  final List<String> instructions;
  final List<String> warnings;
  final List<String> missing;

  const _PrescriptionData({
    required this.medications,
    required this.tests,
    required this.instructions,
    required this.warnings,
    required this.missing,
  });
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