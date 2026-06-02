import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../core/utils/media_permissions.dart';
import '../../core/widgets/ai_summary_view.dart';
import '../../models/patient_models.dart';
import '../../core/errors/app_error_handler.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';

class RecordsVaultScreen extends StatefulWidget {
  const RecordsVaultScreen({super.key});

  @override
  State<RecordsVaultScreen> createState() => _RecordsVaultScreenState();
}

class _RecordsVaultScreenState extends State<RecordsVaultScreen> {
  final _db = FirestoreService();
  String _filterType = 'All';

  // Cache the stream so rebuilds (e.g. theme toggle) don't resubscribe/reload.
  Stream<List<MedicalRecord>>? _stream;
  String? _streamUid;
  Stream<List<MedicalRecord>> _records(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = _db.watchMedicalRecords(uid);
    }
    return _stream!;
  }

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
                    stream: _records(uid),
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
    final source = await _showSourceSheet(context);
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final List<String> imagePaths = [];

    if (source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty || !context.mounted) return;
      imagePaths.addAll(files.map((f) => f.path));
    } else {
      // Camera: allow multiple shots with a review sheet between each
      final ok = await MediaPermissions.ensureCamera(context);
      if (!ok || !context.mounted) return;

      while (true) {
        final file =
            await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (file == null || !context.mounted) break;
        imagePaths.add(file.path);

        final addMore = await _showCameraReviewSheet(context, imagePaths);
        if (addMore != true || !context.mounted) break;
      }
    }

    if (imagePaths.isEmpty || !context.mounted) return;
    _showScanningSheet(context, uid, imagePaths);
  }

  /// Attractive bottom sheet to pick camera vs gallery.
  Future<ImageSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourceSheet(),
    );
  }

  /// After each camera capture, shows thumbnails of all captured photos
  /// and asks whether to add more or finish. Returns true = take another.
  Future<bool?> _showCameraReviewSheet(
      BuildContext context, List<String> captured) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _CameraReviewSheet(capturedPaths: captured),
    );
  }

  void _showScanningSheet(
      BuildContext context, String uid, List<String> imagePaths) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) =>
          _ScanSheet(uid: uid, imagePaths: imagePaths, db: _db),
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

  static Map<String, Color> get _typeColors => <String, Color>{
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
              icon: Icon(Icons.more_vert_rounded,
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
          Icon(Icons.folder_open_rounded,
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

// ── Source picker sheet ───────────────────────────────────────────────────────

class _SourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Medical Record', style: AppTheme.headingSmall),
                      Text('Choose your source',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      sublabel: 'Take multiple\nphotos',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () =>
                          Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      sublabel: 'Select multiple\nimages at once',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5856D6), Color(0xFFAF52DE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () =>
                          Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
            const SizedBox(height: 4),
            Text(sublabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Camera review sheet ───────────────────────────────────────────────────────

class _CameraReviewSheet extends StatelessWidget {
  final List<String> capturedPaths;
  const _CameraReviewSheet({required this.capturedPaths});

  @override
  Widget build(BuildContext context) {
    final count = capturedPaths.length;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.97),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.successColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$count ${count == 1 ? 'photo' : 'photos'} captured',
                          style: const TextStyle(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('Swipe to review',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textTertiary)),
                ],
              ),
              const SizedBox(height: 14),
              // Thumbnail strip
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: count,
                  itemBuilder: (_, i) => Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(capturedPaths[i]),
                            width: 72,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Take Another'),
                      onPressed: () => Navigator.pop(context, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(
                            color: AppTheme.primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34C759), Color(0xFF30B35A)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        icon: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          'Done  ·  $count ${count == 1 ? 'page' : 'pages'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan Sheet ────────────────────────────────────────────────────────────────

class _ScanSheet extends StatefulWidget {
  final String uid;
  final List<String> imagePaths;
  final FirestoreService db;
  const _ScanSheet(
      {required this.uid, required this.imagePaths, required this.db});

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _titleCtrl = TextEditingController();
  final _pageCtrl = PageController();
  int _currentPage = 0;
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
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      final pageCount = widget.imagePaths.length;
      final prompt = pageCount == 1
          ? '''Analyze this medical document image. Please provide:
1. Document type (lab report, prescription, imaging report, discharge summary, etc.)
2. Key findings or values in plain language
3. A brief 2-3 sentence summary that a patient can easily understand
4. Any important values or results that are abnormal or need attention
5. Suggested follow-up actions if any

Format your response clearly with headings. Use simple language.'''
          : '''Analyze this multi-page medical document ($pageCount pages provided). Please provide:
1. Document type (lab report, prescription, imaging report, discharge summary, etc.)
2. Key findings or values from ALL pages in plain language
3. A brief 2-3 sentence summary that a patient can easily understand
4. Any important values or results that are abnormal or need attention across any page
5. Suggested follow-up actions if any

Format your response clearly with headings. Use simple language.''';

      final response = await ChatbotService().getGeminiVisionResponseMulti(
        prompt: prompt,
        imagePaths: widget.imagePaths,
      );
      if (mounted) {
        setState(() {
          _aiSummary = response;
          _extractedText = response;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSummary = '';
          _extractedText = '';
          _analyzing = false;
        });
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _save() async {
    if (widget.uid.isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        Exception('Sign in required to save records.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final recordId = const Uuid().v4();

      // Upload all pages in parallel; get back only the URLs that succeeded.
      final imageUrls = await StorageService().uploadDocumentImages(
        filePaths: widget.imagePaths,
        patientId: widget.uid,
        recordId: recordId,
      );

      if (mounted) {
        final total = widget.imagePaths.length;
        final uploaded = imageUrls.length;
        if (uploaded == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not upload images to cloud. Record saved with local copy only.',
              ),
            ),
          );
        } else if (uploaded < total) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$uploaded of $total pages uploaded. ${total - uploaded} page(s) failed — record saved with partial cloud backup.',
              ),
            ),
          );
        }
      }

      final record = MedicalRecord(
        id: recordId,
        userId: widget.uid,
        title: _titleCtrl.text.trim().isEmpty
            ? 'Medical Record ${DateFormat('dd MMM yyyy').format(DateTime.now())}'
            : _titleCtrl.text.trim(),
        recordType: _recordType,
        imagePath: widget.imagePaths.first,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
        imageUrls: imageUrls,
        aiSummary: _aiSummary,
        extractedText: _extractedText,
        isProcessed: _aiSummary.isNotEmpty,
      );
      await widget.db.saveMedicalRecord(widget.uid, record);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.imagePaths.length;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Scan Result', style: AppTheme.headingSmall),
                      if (pageCount > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pageCount pages',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Image preview (PageView for multi, plain for single) ──
                    if (pageCount == 1)
                      ClipRRect(
                        borderRadius: AppTheme.mediumRadius,
                        child: Image.file(
                          File(widget.imagePaths.first),
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: AppTheme.mediumRadius,
                        child: SizedBox(
                          height: 160,
                          child: PageView.builder(
                            controller: _pageCtrl,
                            itemCount: pageCount,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemBuilder: (_, i) => Image.file(
                              File(widget.imagePaths[i]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.sm),
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pageCount,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == i ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? AppTheme.primaryColor
                                  : AppTheme.dividerColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.sm),
                      // Thumbnail strip
                      SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: pageCount,
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _pageCtrl.animateToPage(i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut),
                            child: Container(
                              width: 48,
                              height: 56,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _currentPage == i
                                      ? AppTheme.primaryColor
                                      : AppTheme.dividerColor,
                                  width: _currentPage == i ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.file(
                                  File(widget.imagePaths[i]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.lg),
                    // ── AI Analysis ──────────────────────────────────────────
                    AiSummaryView(
                      content: _aiSummary,
                      isLoading: _analyzing,
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
                      initialValue: _recordType,
                      decoration: const InputDecoration(
                          labelText: 'Record Type'),
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
                                  strokeWidth: 2, color: Colors.white))
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
