import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../core/utils/media_permissions.dart';
import '../../models/advocate_models.dart';
import '../../services/ai/ai_service.dart';
import '../../services/analytics_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import 'document_review_screen.dart';

/// Universal document scanner: pick what it is → capture pages (camera,
/// photos or PDF) → AI extraction → review & save.
///
/// Entry point for the whole product: [open] shows the type/source sheet.
class DocumentScanScreen extends StatefulWidget {
  final String docType; // bill | eob | denial | policy | record | auto
  final String source; // camera | gallery | pdf
  final String? caseId;
  const DocumentScanScreen({super.key, required this.docType, required this.source, this.caseId});

  /// Opens the "what are you scanning?" sheet, then the scanner.
  static Future<void> open(BuildContext context, {required String trigger, String? docType, String? caseId}) async {
    Analytics.log('scan_open', {'trigger': trigger});
    final choice = await showModalBottomSheet<({String type, String source})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanChooserSheet(initialType: docType),
    );
    if (choice == null || !context.mounted) return;
    Analytics.scanStarted(choice.type);
    await Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => DocumentScanScreen(docType: choice.type, source: choice.source, caseId: caseId),
      ),
    );
  }

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  final _picker = ImagePicker();
  final List<String> _pages = [];
  bool _busy = false;
  bool _analyzing = false;
  String _status = '';
  bool _pickedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickInitial());
  }

  Future<void> _pickInitial() async {
    _pickedOnce = true;
    switch (widget.source) {
      case 'camera':
        await _addFromCamera();
      case 'gallery':
        await _addFromGallery();
      case 'pdf':
        await _addPdf();
    }
    if (_pages.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _addFromCamera() async {
    if (!await MediaPermissions.ensureCamera(context)) return;
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 2200);
      if (x != null) setState(() => _pages.add(x.path));
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _addFromGallery() async {
    if (!await MediaPermissions.ensurePhotos(context)) return;
    try {
      final xs = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 2200, limit: 12);
      if (xs.isNotEmpty) setState(() => _pages.addAll(xs.map((x) => x.path)));
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _addPdf() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: false);
      final path = res?.files.single.path;
      if (path != null) {
        final size = await File(path).length();
        if (size > 18 * 1024 * 1024) {
          if (mounted) AppErrorHandler.showSnackBar(context, const AppException(code: 'too-large', message: 'PDF is larger than 18 MB. Please split it.'));
          return;
        }
        setState(() => _pages
          ..clear()
          ..add(path));
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  bool get _isPdf => _pages.length == 1 && StorageService.isPdf(_pages.first);

  Future<void> _analyze() async {
    if (_pages.isEmpty || _busy) return;
    final provider = context.read<HealthDataProvider>();
    final uid = provider.uid;
    if (uid == null) return;
    final region = provider.profile?.country.isNotEmpty == true ? provider.profile!.country : 'US';

    setState(() {
      _busy = true;
      _analyzing = true;
      _status = 'Preparing pages…';
    });
    try {
      final files = <AiFile>[];
      for (final p in _pages) {
        final f = await AiFile.fromPath(p);
        if (f != null) files.add(f);
      }
      if (files.isEmpty) throw const AppException(code: 'no-files', message: 'Could not read the pages.');
      setState(() => _status = widget.docType == 'auto' ? 'Working out what this is…' : 'Reading your ${DocType.label(widget.docType).toLowerCase()}…');

      final result = await AiService.instance.analyzeDocument(
        files: files,
        docType: widget.docType,
        region: region,
      );
      Analytics.scanCompleted(result.documentType, success: true, pages: _pages.length);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final saved = await Navigator.pushReplacement<bool, void>(
        context,
        CupertinoPageRoute(
          builder: (_) => DocumentReviewScreen(
            result: result,
            pagePaths: List.of(_pages),
            requestedType: widget.docType,
            caseId: widget.caseId,
          ),
        ),
      );
      if (saved == true && mounted) Navigator.maybePop(context);
    } on AiQuotaException catch (e) {
      Analytics.quotaHit(e.op);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _analyzing = false;
      });
      final go = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Free limit reached'),
          content: Text('\n${e.message}'),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('See Pro')),
          ],
        ),
      );
      if (go == true && mounted) {
        Analytics.paywallShown('quota_${e.op}');
        Navigator.pushNamed(context, AppRouter.paywall);
      }
    } catch (e) {
      Analytics.scanCompleted(widget.docType, success: false, pages: _pages.length);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _analyzing = false;
      });
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.docType == 'auto' ? 'Document' : DocType.label(widget.docType);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark, color: AppTheme.textPrimary),
          onPressed: _analyzing ? null : () => Navigator.maybePop(context),
        ),
        title: Text(label, style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _analyzing
            ? _AnalyzingView(status: _status, pages: _pages)
            : Column(
                children: [
                  Expanded(
                    child: _pages.isEmpty
                        ? Center(
                            child: _pickedOnce
                                ? Text('No pages yet', style: AppTheme.bodyMedium)
                                : const CupertinoActivityIndicator())
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: _pages.length,
                            itemBuilder: (_, i) => _PageThumb(
                              path: _pages[i],
                              index: i,
                              onRemove: () => setState(() => _pages.removeAt(i)),
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(top: BorderSide(color: AppTheme.dividerColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isPdf)
                          Row(
                            children: [
                              Expanded(
                                child: TonalButton(
                                  label: 'Add page',
                                  icon: CupertinoIcons.camera_fill,
                                  onTap: _addFromCamera,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TonalButton(
                                  label: 'From photos',
                                  icon: CupertinoIcons.photo_fill,
                                  color: AppTheme.secondaryColor,
                                  onTap: _addFromGallery,
                                ),
                              ),
                            ],
                          ),
                        if (!_isPdf) const SizedBox(height: 10),
                        HeroButton(
                          label: _pages.isEmpty
                              ? 'Add a page to continue'
                              : _isPdf
                                  ? 'Read this PDF'
                                  : 'Read ${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
                          icon: CupertinoIcons.sparkles,
                          onTap: _pages.isEmpty ? null : _analyze,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pages are stored on this device first, then processed on our no-training AI tier.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  final String path;
  final int index;
  final VoidCallback onRemove;
  const _PageThumb({required this.path, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final pdf = StorageService.isPdf(path);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: DS.squircle(DS.rMd),
        border: Border.all(color: AppTheme.glassBorder, width: 0.8),
        boxShadow: DS.softShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          pdf
              ? Center(child: IconBadge(CupertinoIcons.doc_richtext, color: AppTheme.dangerColor, size: 56))
              : Image.file(File(path), fit: BoxFit.cover),
          Positioned(
            left: 8,
            top: 8,
            child: Pill(pdf ? 'PDF' : 'Page ${index + 1}', color: AppTheme.primaryColor),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  final String status;
  final List<String> pages;
  const _AnalyzingView({required this.status, required this.pages});

  @override
  Widget build(BuildContext context) {
    final first = pages.isNotEmpty ? pages.first : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: DS.squircle(DS.rLg),
                      boxShadow: DS.softShadow(y: 10, blur: 30),
                      color: AppTheme.surfaceColor,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: first != null && !StorageService.isPdf(first)
                        ? Image.file(File(first), fit: BoxFit.cover, width: 150, height: 190)
                        : Center(child: IconBadge(CupertinoIcons.doc_richtext, color: AppTheme.primaryColor, size: 60)),
                  ),
                  const _ScanLine(),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const CupertinoActivityIndicator(radius: 12),
            const SizedBox(height: 14),
            Text(status, textAlign: TextAlign.center, style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('This usually takes 10–30 seconds.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Align(
        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
        child: Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [
              AppTheme.primaryColor.withValues(alpha: 0),
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0),
            ]),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.6), blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}

// ── Chooser sheet ─────────────────────────────────────────────────────────────

class _ScanChooserSheet extends StatefulWidget {
  final String? initialType;
  const _ScanChooserSheet({this.initialType});

  @override
  State<_ScanChooserSheet> createState() => _ScanChooserSheetState();
}

class _ScanChooserSheetState extends State<_ScanChooserSheet> {
  late String _type = widget.initialType ?? 'auto';

  static const _types = [
    ('auto', CupertinoIcons.wand_stars, 'Detect automatically', 'Bill, statement, letter, policy or record'),
    (DocType.bill, CupertinoIcons.doc_text_fill, 'Medical bill', 'Itemized statement, invoice, pharmacy receipt'),
    (DocType.eob, CupertinoIcons.creditcard_fill, 'Insurance statement (EOB)', 'What your insurer paid and what you owe'),
    (DocType.denial, CupertinoIcons.xmark_shield_fill, 'Denial letter', 'A claim or pre-approval was refused'),
    (DocType.policy, CupertinoIcons.shield_lefthalf_fill, 'Insurance policy', 'Policy schedule, benefits summary'),
    (DocType.record, CupertinoIcons.lab_flask_solid, 'Medical record', 'Lab report, prescription, discharge summary'),
  ];

  void _choose(String source) {
    HapticFeedback.lightImpact();
    Navigator.pop(context, (type: _type, source: source));
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.dangerColor,
      AppTheme.infoColor,
      AppTheme.warningColor,
      AppTheme.secondaryColor,
      AppTheme.successColor,
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rXl),
          boxShadow: DS.softShadow(y: 10, blur: 30),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 14),
              Text('What are you scanning?', style: AppTheme.headingMedium),
              const SizedBox(height: 12),
              for (var i = 0; i < _types.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChoiceCard(
                    leading: IconBadge(_types[i].$2, color: colors[i], size: 38),
                    title: _types[i].$3,
                    subtitle: _types[i].$4,
                    selected: _type == _types[i].$1,
                    onTap: () => setState(() => _type = _types[i].$1),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _SourceButton(icon: CupertinoIcons.camera_fill, label: 'Camera', onTap: () => _choose('camera'))),
                  const SizedBox(width: 8),
                  Expanded(child: _SourceButton(icon: CupertinoIcons.photo_fill, label: 'Photos', onTap: () => _choose('gallery'))),
                  const SizedBox(width: 8),
                  Expanded(child: _SourceButton(icon: CupertinoIcons.doc_fill, label: 'PDF', onTap: () => _choose('pdf'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: DS.squircle(DS.rLg),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
