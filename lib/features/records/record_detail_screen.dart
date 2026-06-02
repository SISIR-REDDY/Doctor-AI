import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/ai_summary_view.dart';
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
              AiSummaryView(
                content: record.aiSummary,
                title: 'AI Summary',
              ),
            if (record.extractedText.isNotEmpty &&
                record.extractedText != record.aiSummary) ...[
              const SizedBox(height: AppTheme.lg),
              AiSummaryView(
                content: record.extractedText,
                title: 'Full Analysis',
                icon: Icons.description_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordImage extends StatefulWidget {
  final MedicalRecord record;
  const _RecordImage({required this.record});

  @override
  State<_RecordImage> createState() => _RecordImageState();
}

class _RecordImageState extends State<_RecordImage> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.record.allImageUrls;

    // Multi-page cloud images
    if (urls.length > 1) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: AppTheme.largeRadius,
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Image.network(
                  urls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppTheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_page + 1} / ${urls.length}',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      );
    }

    // Single cloud URL
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: AppTheme.largeRadius,
        child: Image.network(
          urls.first,
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

    // Fallback to local file (cached path, no cloud upload succeeded)
    if (widget.record.imagePath.isNotEmpty &&
        File(widget.record.imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: AppTheme.largeRadius,
        child: Image.file(
          File(widget.record.imagePath),
          fit: BoxFit.cover,
          height: 220,
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() => Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: AppTheme.largeRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Center(
          child: Icon(Icons.description_outlined,
              size: 56, color: AppTheme.textTertiary),
        ),
      );
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
