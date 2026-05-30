import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class RecordsVaultScreen extends StatefulWidget {
  const RecordsVaultScreen({super.key});

  @override
  State<RecordsVaultScreen> createState() => _RecordsVaultScreenState();
}

class _RecordsVaultScreenState extends State<RecordsVaultScreen> {
  final _db = FirestoreService();
  String _filterType = 'All';

  static const _types = [
    'All',
    'lab',
    'imaging',
    'prescription',
    'discharge',
    'vaccination',
    'other',
  ];

  static const _typeLabels = {
    'All': 'All',
    'lab': 'Lab Reports',
    'imaging': 'Imaging',
    'prescription': 'Prescriptions',
    'discharge': 'Discharge',
    'vaccination': 'Vaccination',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final uid = context.read<HealthDataProvider>().uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Medical Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _pickAndScan(context, uid ?? ''),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : Column(
              children: [
                _TypeFilter(
                  types: _types,
                  labels: _typeLabels,
                  selected: _filterType,
                  onChanged: (t) => setState(() => _filterType = t),
                ),
                Expanded(
                  child: StreamBuilder<List<MedicalRecord>>(
                    stream: _db.watchMedicalRecords(uid),
                    builder: (ctx, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final all = snap.data ?? [];
                      final filtered = _filterType == 'All'
                          ? all
                          : all
                              .where((r) => r.recordType == _filterType)
                              .toList();

                      if (filtered.isEmpty) {
                        return _EmptyState(
                            message: _filterType == 'All'
                                ? 'No records yet.\nTap + to scan or upload a document.'
                                : 'No ${_typeLabels[_filterType]} records.');
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.lg),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _RecordCard(
                          record: filtered[i],
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRouter.recordDetail,
                            arguments: filtered[i],
                          ),
                          onDelete: () => _db.deleteMedicalRecord(
                              uid, filtered[i].id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndScan(context, uid ?? ''),
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Scan / Upload'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _pickAndScan(BuildContext context, String uid) async {
    final source = await _showSourceDialog(context);
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? file = source == ImageSource.camera
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);

    if (file == null || !context.mounted) return;

    _showScanningSheet(context, uid, file.path);
  }

  Future<ImageSource?> _showSourceDialog(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Record'),
        content: const Text('Choose how to add your medical document:'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Camera'),
            onPressed: () =>
                Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
            onPressed: () =>
                Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  void _showScanningSheet(
      BuildContext context, String uid, String imagePath) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _ScanSheet(uid: uid, imagePath: imagePath, db: _db),
    );
  }
}

// ── Type Filter ───────────────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final List<String> types;
  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeFilter({
    required this.types,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.surfaceColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.lg, vertical: 8),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final selected = this.selected == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                  ),
                ),
                child: Text(
                  labels[t] ?? t,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Record Card ───────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecordCard(
      {required this.record,
      required this.onTap,
      required this.onDelete});

  static const _typeColors = <String, Color>{
    'lab': AppTheme.infoColor,
    'imaging': AppTheme.neurologyColor,
    'prescription': AppTheme.surgeryColor,
    'discharge': AppTheme.warningColor,
    'vaccination': AppTheme.secondaryColor,
    'other': AppTheme.textSecondary,
  };

  static const _typeIcons = <String, IconData>{
    'lab': Icons.science_outlined,
    'imaging': Icons.medical_information_outlined,
    'prescription': Icons.medication_outlined,
    'discharge': Icons.local_hospital_outlined,
    'vaccination': Icons.vaccines_outlined,
    'other': Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[record.recordType] ?? AppTheme.textSecondary;
    final icon = _typeIcons[record.recordType] ?? Icons.description_outlined;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.md),
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title.isEmpty ? 'Medical Record' : record.title,
                      style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          record.recordType[0].toUpperCase() +
                              record.recordType.substring(1),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy')
                            .format(record.uploadedAt),
                        style: AppTheme.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  if (record.isProcessed && record.aiSummary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        record.aiSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textTertiary, size: 20),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppTheme.dangerColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_rounded,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.lg),
          Text(message,
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Scan Sheet ────────────────────────────────────────────────────────────────

class _ScanSheet extends StatefulWidget {
  final String uid;
  final String imagePath;
  final FirestoreService db;
  const _ScanSheet(
      {required this.uid, required this.imagePath, required this.db});

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _titleCtrl = TextEditingController();
  String _recordType = 'lab';
  bool _analyzing = false;
  bool _saving = false;
  String _aiSummary = '';
  String _extractedText = '';

  final _types = [
    'lab',
    'imaging',
    'prescription',
    'discharge',
    'vaccination',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      const prompt =
          '''Analyze this medical document image. Please provide:
1. Document type (lab report, prescription, imaging report, discharge summary, etc.)
2. Key findings or values in plain language
3. A brief 2-3 sentence summary that a patient can easily understand
4. Any important values or results that are abnormal or need attention
5. Suggested follow-up actions if any

Format your response clearly with headings. Use simple language.''';

      final response = await ChatbotService().getGeminiVisionResponse(
        prompt: prompt,
        imagePath: widget.imagePath,
      );
      if (mounted) {
        setState(() {
          _aiSummary = response;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSummary = 'AI analysis unavailable. You can still save this record manually.';
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final record = MedicalRecord(
        id: const Uuid().v4(),
        userId: widget.uid,
        title: _titleCtrl.text.trim().isEmpty
            ? 'Medical Record ${DateFormat('dd MMM yyyy').format(DateTime.now())}'
            : _titleCtrl.text.trim(),
        recordType: _recordType,
        imagePath: widget.imagePath,
        aiSummary: _aiSummary,
        extractedText: _extractedText,
        isProcessed: true,
      );
      await widget.db.saveMedicalRecord(widget.uid, record);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.xl),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  const Text('Scan Result', style: AppTheme.headingSmall),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview image
                    ClipRRect(
                      borderRadius: AppTheme.mediumRadius,
                      child: Image.file(
                        File(widget.imagePath),
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: AppTheme.lg),
                    // AI Analysis
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
                              const Spacer(),
                              if (_analyzing)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.sm),
                          Text(
                            _analyzing
                                ? 'Analyzing your document...'
                                : _aiSummary,
                            style: AppTheme.bodySmall.copyWith(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.lg),
                    TextField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Record Title',
                        hintText: 'e.g. Blood Test Report - June 2026',
                      ),
                    ),
                    const SizedBox(height: AppTheme.md),
                    DropdownButtonFormField<String>(
                      value: _recordType,
                      decoration:
                          const InputDecoration(labelText: 'Record Type'),
                      items: _types
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t[0].toUpperCase() +
                                  t.substring(1))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _recordType = v!),
                    ),
                    const SizedBox(height: AppTheme.xl),
                    ElevatedButton(
                      onPressed: (_analyzing || _saving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.mediumRadius),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Save Record',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                    ),
                    const SizedBox(height: AppTheme.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
