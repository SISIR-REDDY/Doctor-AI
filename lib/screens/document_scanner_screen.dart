import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/errors/app_error_handler.dart';
import '../theme/app_theme.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../widgets/clinical_md.dart';
import '../widgets/workflow/workflow_header_card.dart';

class DocumentScannerScreen extends StatefulWidget {
  final String patientId;

  const DocumentScannerScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();
  
  final List<DocumentScan> _scans = [];
  bool _isAnalyzing = false;
  String _selectedDocType = 'lab_report';
  bool _isReanalyzing = false;
  File? _selectedImage;
  StreamSubscription<List<DocumentScan>>? _cloudSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCloudScans();
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    super.dispose();
  }

  void _listenToCloudScans() {
    if (!_firestoreService.isFirebaseAvailable) return;

    _cloudSubscription =
        _firestoreService.watchDocumentScans(widget.patientId).listen(
      (cloudScans) {
        if (!mounted) return;
        setState(() {
          _scans
            ..clear()
            ..addAll(cloudScans);
        });
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Medical Documents'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.lg, AppTheme.lg, 0),
              child: WorkflowHeaderCard(
                title: 'Document Scanner',
                subtitle: 'Capture, classify, and analyze medical documents.',
                icon: Icons.document_scanner_outlined,
                accentColor: const Color(0xFF9333EA),
                stats: [
                  WorkflowHeaderStat(
                    icon: Icons.folder_copy_outlined,
                    label: '${_scans.length} scans',
                  ),
                  WorkflowHeaderStat(
                    icon: Icons.auto_awesome_outlined,
                    label: _isAnalyzing ? 'Analyzing' : 'AI ready',
                  ),
                ],
                helperText: 'Use camera or gallery to capture a document and extract key details.',
              ),
            ),
            // Upload Section
            _buildUploadSection(),
            const SizedBox(height: AppTheme.lg),
            
            // Recent Scans
            if (_scans.isNotEmpty) ...[
              SectionHeader(
                title: 'Recent Scans',
                subtitle: '${_scans.length} document${_scans.length > 1 ? 's' : ''}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
                  itemBuilder: (context, index) {
                    return _buildScanCard(_scans[index]);
                  },
                ),
              ),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: GlossyCard(
        child: Column(
          children: [
            if (_selectedImage != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: AppTheme.mediumRadius,
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                ],
              ),
            
            // Document Type Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document Type', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.sm),
                Wrap(
                  spacing: AppTheme.sm,
                  runSpacing: AppTheme.sm,
                  children: [
                    _buildDocTypeChip('lab_report', 'Lab Report', Icons.biotech),
                    _buildDocTypeChip('xray', 'X-Ray', Icons.image),
                    _buildDocTypeChip('scan', 'Scan/MRI', Icons.document_scanner),
                    _buildDocTypeChip('prescription', 'Prescription', Icons.medication),
                    _buildDocTypeChip('discharge', 'Discharge', Icons.local_hospital_outlined),
                    _buildDocTypeChip('ecg', 'ECG/EKG', Icons.monitor_heart_outlined),
                    _buildDocTypeChip('referral', 'Referral', Icons.assignment_outlined),
                    _buildDocTypeChip('other', 'Other', Icons.description_outlined),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.lg),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(height: AppTheme.xs),
                          const Text(
                            'Camera',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.image,
                            color: AppTheme.secondaryColor,
                            size: 28,
                          ),
                          const SizedBox(height: AppTheme.xs),
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (_selectedImage != null) ...[
              const SizedBox(height: AppTheme.lg),
              IosButton(
                label: _isAnalyzing ? 'Analyzing...' : 'Analyze Document',
                isLoading: _isAnalyzing,
                onPressed: _analyzeDocument,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(DocumentScan scan) {
    return GlossyCard(
      onTap: () => _showScanDetails(scan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getDocTypeColor(scan.documentType).withValues(alpha: 0.1),
                  borderRadius: AppTheme.mediumRadius,
                ),
                child: Center(
                  child: Icon(
                    _getDocTypeIcon(scan.documentType),
                    color: _getDocTypeColor(scan.documentType),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      _formatDocType(scan.documentType),
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      _formatDate(scan.dateScanned),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (scan.isProcessed)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 20,
                ),
            ],
          ),
          if (scan.analysis.isNotEmpty) ...[
            const SizedBox(height: AppTheme.md),
            const Divider(color: AppTheme.dividerColor, height: 1),
            const SizedBox(height: AppTheme.md),
            Text('Analysis', style: AppTheme.labelMedium),
            const SizedBox(height: AppTheme.xs),
            Text(
              _stripMdPreview(scan.analysis),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  bool _isRemotePath(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xl),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            'No Documents Yet',
            style: AppTheme.headingMedium.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Scan your medical documents to analyze them',
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _analyzeDocument() async {
    if (_selectedImage == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final prompt = _buildPromptForDocType(_selectedDocType);

      final analysis = await _chatbotService.getGeminiVisionResponse(
        prompt: prompt,
        imagePath: _selectedImage!.path,
      );

      if (!mounted) return;

      // Reject error-shaped responses so they are never saved as clinical content.
      final lower = analysis.trim().toLowerCase();
      if (lower.startsWith('error:') ||
          lower.contains('could not connect') ||
          lower.contains('api key') ||
          lower.isEmpty) {
        throw Exception('AI analysis failed — please check your Gemini API key in Firebase.');
      }

      final scanId = 'scan_${_uuid.v4()}';
      final remoteUrl = await _storageService.uploadDocumentImage(
        filePath: _selectedImage!.path,
        patientId: widget.patientId,
        scanId: scanId,
      );

      final scan = DocumentScan(
        id: scanId,
        patientId: widget.patientId,
        imagePath: remoteUrl ?? _selectedImage!.path,
        documentType: _selectedDocType,
        analysis: analysis.trim(),
        isProcessed: true,
      );

      setState(() {
        _scans.insert(0, scan);
        _selectedImage = null;
        _isAnalyzing = false;
      });

      try {
        await _firestoreService.saveDocumentScan(scan);
      } catch (error) {
        if (!mounted) return;
        AppErrorHandler.showSnackBar(context, error);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document analyzed and saved'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  String _buildPromptForDocType(String docType) {
    final typeLabel = _formatDocType(docType);
    switch (docType) {
      case 'lab_report':
        return '''You are a clinical pathology assistant. Analyze this lab report image.

Extract and structure the following:

Test Results:
- List each test name, value, unit, and reference range
- Flag any values outside the reference range with ⚠️

Key Findings:
- Summarize the clinically significant abnormal values

Clinical Interpretation:
- What these results suggest (e.g. anaemia, infection, renal impairment)

Recommended Actions:
- Any urgent follow-up or repeat tests indicated

Rules: Use only what is visible in the image. Do not guess values. If text is unclear, say "unreadable".''';

      case 'xray':
        return '''You are a radiologist assistant. Analyze this X-ray image.

Provide:

Anatomical Region:
- What part of the body and projection (PA/AP/lateral etc.)

Visible Structures:
- Describe the key structures visible

Findings:
- Note any abnormalities, opacities, fractures, effusions, or masses
- Describe size, location, and character

Impression:
- Likely diagnosis or differential

Limitations:
- Any quality issues or what cannot be assessed from this image

Rules: Be precise. If this is not a medical image, say so clearly.''';

      case 'scan':
        return '''You are a radiologist assistant. Analyze this medical scan/imaging report.

Provide:

Scan Type & Region:
- Modality (CT/MRI/Ultrasound etc.) and body region

Key Findings:
- Describe each significant finding with location and measurements if visible

Impression:
- Primary diagnosis or differential diagnoses

Urgency:
- Is urgent follow-up needed?

Rules: Base analysis only on visible content. Flag anything that requires immediate attention.''';

      case 'prescription':
        return '''You are a clinical pharmacist assistant. Analyze this prescription image.

Extract and provide:

Medications Prescribed:
- Drug name, dose, frequency, duration for each item

Patient Instructions:
- Any special instructions visible

Safety Check:
- Flag any unusual doses, potential interactions (if multiple drugs), or missing information

Missing Information:
- List any fields that are blank or unreadable (date, prescriber, patient name etc.)

Rules: Extract only what is clearly visible. Do not infer or guess medication names if unclear.''';

      default:
        return '''You are a clinical documentation assistant. Analyze this $typeLabel medical document.

Provide:

Document Summary:
- Type and purpose of this document

Key Clinical Information:
- All clinically relevant data, values, diagnoses, or instructions present

Important Findings:
- Any abnormalities, warnings, or action items

Recommended Actions:
- What should be done based on this document

Rules: Use only what is visible in the image. Be concise and clinically precise.''';
    }
  }

  Future<void> _showScanDetails(DocumentScan scan) async {
    final isRemote = _isRemotePath(scan.imagePath);
    final imageFile = isRemote ? null : File(scan.imagePath);
    final imageExists = imageFile != null && await imageFile.exists();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDocType(scan.documentType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headingSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                ClipRRect(
                  borderRadius: AppTheme.mediumRadius,
                  child: imageExists
                      ? Image.file(
                          imageFile,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : isRemote
                          ? Image.network(
                              scan.imagePath,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                width: double.infinity,
                                color: AppTheme.backgroundColor,
                                alignment: Alignment.center,
                                child: Text(
                                  'Image preview unavailable on this device.',
                                  style: AppTheme.bodySmall,
                                ),
                              ),
                            )
                          : Container(
                              height: 180,
                              width: double.infinity,
                              color: AppTheme.backgroundColor,
                              alignment: Alignment.center,
                              child: Text(
                                'Image preview unavailable on this device.',
                                style: AppTheme.bodySmall,
                              ),
                            ),
                ),
                if (!imageExists && !isRemote) ...[
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'The scan record was synced from cloud, but local image file path is not present here.',
                    style: AppTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: AppTheme.lg),
                if (scan.extractedText.isNotEmpty) ...[
                  Text('Extracted Text', style: AppTheme.labelLarge),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: Text(scan.extractedText, style: AppTheme.bodySmall),
                  ),
                  const SizedBox(height: AppTheme.lg),
                ],
                if (scan.analysis.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(child: Text('AI Analysis', style: AppTheme.labelLarge)),
                      TextButton.icon(
                        onPressed: _isReanalyzing
                            ? null
                            : () => _reanalyze(context, scan),
                        icon: _isReanalyzing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(_isReanalyzing ? 'Analyzing…' : 'Re-analyze'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ClinicalMd(
                      scan.analysis,
                      fontSize: 13,
                      selectable: true,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppTheme.md),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isReanalyzing ? null : () => _reanalyze(context, scan),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Analyze this document'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDocTypeColor(String type) {
    switch (type) {
      case 'lab_report':   return AppTheme.primaryColor;
      case 'xray':         return AppTheme.secondaryColor;
      case 'scan':         return AppTheme.warningColor;
      case 'prescription': return AppTheme.successColor;
      case 'discharge':    return AppTheme.infoColor;
      case 'ecg':          return AppTheme.cardiologyColor;
      case 'referral':     return AppTheme.neurologyColor;
      default:             return AppTheme.textSecondary;
    }
  }

  IconData _getDocTypeIcon(String type) {
    switch (type) {
      case 'lab_report':   return Icons.biotech;
      case 'xray':         return Icons.image;
      case 'scan':         return Icons.document_scanner;
      case 'prescription': return Icons.medication;
      case 'discharge':    return Icons.local_hospital_outlined;
      case 'ecg':          return Icons.monitor_heart_outlined;
      case 'referral':     return Icons.assignment_outlined;
      default:             return Icons.description_outlined;
    }
  }

  Widget _buildDocTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedDocType == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryColor),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedDocType = value;
        });
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
    );
  }

  /// Strips markdown for the compact card preview (no markdown renderer in
  /// a truncating Text widget). Removes `**bold**`, `*italic*`, `# headers`,
  /// leading `- ` bullets, and collapses whitespace.
  String _stripMdPreview(String raw) => raw
      .replaceAll(RegExp(r'\*{1,2}([^*]+)\*{1,2}'), r'$1')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^-\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();

  String _formatDocType(String type) {
    switch (type) {
      case 'lab_report':   return 'Lab Report';
      case 'xray':         return 'X-Ray';
      case 'scan':         return 'Medical Scan / MRI';
      case 'prescription': return 'Prescription';
      case 'discharge':    return 'Discharge Summary';
      case 'ecg':          return 'ECG / EKG';
      case 'referral':     return 'Referral Letter';
      default:             return 'Medical Document';
    }
  }

  Future<void> _reanalyze(BuildContext sheetContext, DocumentScan scan) async {
    final isRemote = _isRemotePath(scan.imagePath);
    if (isRemote) {
      // Can't re-send a remote URL to vision — need the original bytes.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Re-analysis requires the original image. Pick the document again from the upload section.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final file = File(scan.imagePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original image not found. Please re-scan the document.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isReanalyzing = true);

    try {
      final prompt = _buildPromptForDocType(scan.documentType);
      final analysis = await _chatbotService.getGeminiVisionResponse(
        prompt: prompt,
        imagePath: scan.imagePath,
      );

      final lower = analysis.trim().toLowerCase();
      if (lower.startsWith('error:') || lower.contains('could not connect') || lower.isEmpty) {
        throw Exception('AI analysis failed — please check your Gemini API key.');
      }

      final updated = DocumentScan(
        id: scan.id,
        patientId: scan.patientId,
        imagePath: scan.imagePath,
        documentType: scan.documentType,
        extractedText: scan.extractedText,
        analysis: analysis.trim(),
        isProcessed: true,
        dateScanned: scan.dateScanned,
      );

      if (!mounted) return;
      setState(() {
        final idx = _scans.indexWhere((s) => s.id == scan.id);
        if (idx != -1) _scans[idx] = updated;
        _isReanalyzing = false;
      });

      try {
        await _firestoreService.saveDocumentScan(updated);
      } catch (_) {}

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Re-analysis complete'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReanalyzing = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
