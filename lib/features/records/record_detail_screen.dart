import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../core/widgets/ai_summary_view.dart';
import '../../models/care_models.dart';
import '../../models/patient_models.dart';
import '../../services/claim_pdf_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'lab_results_view.dart';

class RecordDetailScreen extends StatelessWidget {
  final MedicalRecord record;
  const RecordDetailScreen({super.key, required this.record});

  Future<void> _exportPdf(BuildContext context) async {
    final body = record.aiSummary.isNotEmpty
        ? record.aiSummary
        : (record.extractedText.isNotEmpty
            ? record.extractedText
            : 'No AI summary is available for this record yet.');
    try {
      await ClaimPdfService().shareLetter(
        title: record.title.isEmpty ? 'Medical Record Summary' : record.title,
        subtitle:
            '${record.recordType[0].toUpperCase()}${record.recordType.substring(1)} record · '
            '${DateFormat('dd MMM yyyy').format(record.uploadedAt)}',
        body: body,
        filename: record.title.isEmpty ? 'Record_Summary' : record.title,
      );
    } catch (e) {
      if (context.mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(record.title.isEmpty ? 'Record Detail' : record.title),
        actions: [
          if (record.aiSummary.isNotEmpty || record.extractedText.isNotEmpty)
            IconButton(
              tooltip: 'Export summary PDF',
              icon: const Icon(CupertinoIcons.share),
              onPressed: () => _exportPdf(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordImage(record: record),
            const SizedBox(height: AppTheme.lg),
            _InfoCard(children: [
              _Row(CupertinoIcons.square_grid_2x2, 'Type',
                  record.recordType[0].toUpperCase() +
                      record.recordType.substring(1)),
              _Row(CupertinoIcons.calendar, 'Uploaded',
                  DateFormat('dd MMM yyyy, hh:mm a').format(record.uploadedAt)),
              if (record.doctorName.isNotEmpty)
                _Row(CupertinoIcons.person, 'Doctor',
                    record.doctorName),
              if (record.hospitalName.isNotEmpty)
                _Row(CupertinoIcons.building_2_fill, 'Hospital',
                    record.hospitalName),
            ]),
            const SizedBox(height: AppTheme.lg),
            // Structured results sit above the prose: the numbers are what
            // the user opened the report for; the summary explains them.
            if (record.labMarkers.isNotEmpty) ...[
              _LabResultsWithHistory(record: record),
              const SizedBox(height: AppTheme.lg),
            ],
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
                icon: CupertinoIcons.doc_text,
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
                      child: const CupertinoActivityIndicator(),
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
              child: const CupertinoActivityIndicator(),
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
          child: Icon(CupertinoIcons.doc_text,
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

/// Loads the user's other lab records so each marker can show its trend.
class _LabResultsWithHistory extends StatelessWidget {
  final MedicalRecord record;
  const _LabResultsWithHistory({required this.record});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return LabResultsView(markers: record.labMarkers);
    return StreamBuilder<List<MedicalRecord>>(
      stream: FirestoreService().watchMedicalRecords(uid),
      builder: (context, snap) {
        final priors = priorReadings(record, snap.data ?? const []);
        return LabResultsView(markers: record.labMarkers, priors: priors);
      },
    );
  }
}
