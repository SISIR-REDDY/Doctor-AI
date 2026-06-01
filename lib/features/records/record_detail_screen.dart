import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/patient_models.dart';
import '../../theme/app_theme.dart';

class RecordDetailScreen extends StatelessWidget {
  final MedicalRecord record;
  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(record.title.isEmpty ? 'Record Detail' : record.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordImage(record: record),
            const SizedBox(height: AppTheme.lg),
            _InfoCard(children: [
              _Row(Icons.category_outlined, 'Type',
                  record.recordType[0].toUpperCase() +
                      record.recordType.substring(1)),
              _Row(Icons.calendar_today_outlined, 'Uploaded',
                  DateFormat('dd MMM yyyy, hh:mm a').format(record.uploadedAt)),
              if (record.doctorName.isNotEmpty)
                _Row(Icons.person_outline_rounded, 'Doctor',
                    record.doctorName),
              if (record.hospitalName.isNotEmpty)
                _Row(Icons.local_hospital_outlined, 'Hospital',
                    record.hospitalName),
            ]),
            const SizedBox(height: AppTheme.lg),
            if (record.aiSummary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text('AI Summary',
                            style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.primaryColor)),
                      ],
                    ),
                    const SizedBox(height: AppTheme.md),
                    Text(record.aiSummary, style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            if (record.extractedText.isNotEmpty &&
                record.extractedText != record.aiSummary) ...[
              const SizedBox(height: AppTheme.lg),
              _InfoCard(children: [
                Text('Full analysis', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.sm),
                Text(record.extractedText, style: AppTheme.bodyMedium),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordImage extends StatelessWidget {
  final MedicalRecord record;
  const _RecordImage({required this.record});

  @override
  Widget build(BuildContext context) {
    final url = record.imageUrl.trim();
    if (url.startsWith('http')) {
      return ClipRRect(
        borderRadius: AppTheme.largeRadius,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          height: 220,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 220,
              alignment: Alignment.center,
              color: AppTheme.surfaceVariant,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }

    if (record.imagePath.isNotEmpty && File(record.imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: AppTheme.largeRadius,
        child: Image.file(
          File(record.imagePath),
          fit: BoxFit.cover,
          height: 220,
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: const Center(
        child: Icon(Icons.description_outlined,
            size: 56, color: AppTheme.textTertiary),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textTertiary),
          const SizedBox(width: 10),
          Text('$label: ', style: AppTheme.bodySmall),
          Expanded(child: Text(value, style: AppTheme.labelLarge)),
        ],
      ),
    );
  }
}
