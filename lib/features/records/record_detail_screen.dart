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
            // Image preview
            if (record.imagePath.isNotEmpty &&
                File(record.imagePath).existsSync())
              ClipRRect(
                borderRadius: AppTheme.largeRadius,
                child: Image.file(
                  File(record.imagePath),
                  fit: BoxFit.cover,
                  height: 200,
                ),
              )
            else
              Container(
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
              ),
            const SizedBox(height: AppTheme.lg),

            // Meta info
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

            // AI Summary
            if (record.aiSummary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
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
                        const Icon(Icons.auto_awesome_rounded,
                            color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        const Text('AI Analysis',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sm),
                    Text(record.aiSummary,
                        style: AppTheme.bodySmall.copyWith(height: 1.6)),
                  ],
                ),
              ),

            if (record.extractedText.isNotEmpty) ...[
              const SizedBox(height: AppTheme.lg),
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Extracted Text',
                        style:
                            AppTheme.headingSmall.copyWith(fontSize: 15)),
                    const SizedBox(height: AppTheme.md),
                    Text(record.extractedText,
                        style: AppTheme.bodySmall
                            .copyWith(fontFamily: 'monospace', height: 1.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
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
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(children: children),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySmall),
              Text(value,
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
