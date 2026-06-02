import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/media_permissions.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';

/// Categories a bill can fall under. value → display label.
const Map<String, String> kExpenseCategories = {
  'hospital': 'Hospital',
  'pharmacy': 'Pharmacy',
  'lab': 'Lab / Diagnostics',
  'consultation': 'Consultation',
  'imaging': 'Imaging / Scan',
  'procedure': 'Procedure / Surgery',
  'other': 'Other',
};

const Map<String, IconData> kExpenseCategoryIcons = {
  'hospital': Icons.local_hospital_outlined,
  'pharmacy': Icons.medication_outlined,
  'lab': Icons.science_outlined,
  'consultation': Icons.medical_services_outlined,
  'imaging': Icons.monitor_heart_outlined,
  'procedure': Icons.healing_outlined,
  'other': Icons.receipt_long_outlined,
};

/// Adds (or edits) a single itemized bill for a case. Supports manual entry and
/// an AI "scan bill" flow that reads a receipt photo and pre-fills the fields.
///
/// Pops with the resulting [CaseExpense], or `null` if cancelled.
class AddExpenseScreen extends StatefulWidget {
  final String uid;
  final String currencyCode;
  final CaseExpense? existing;

  const AddExpenseScreen({
    super.key,
    required this.uid,
    required this.currencyCode,
    this.existing,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _vendorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _category = 'hospital';
  DateTime? _date;
  String _imagePath = '';
  String _documentUrl = '';
  String _lineItems = '';
  bool _aiExtracted = false;

  bool _scanning = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _vendorCtrl.text = e.vendor;
      _amountCtrl.text = e.amount > 0 ? _trimAmount(e.amount) : '';
      _noteCtrl.text = e.note;
      _category = kExpenseCategories.containsKey(e.category) ? e.category : 'other';
      _date = e.date.isNotEmpty ? _tryParseDate(e.date) : null;
      _imagePath = e.imagePath;
      _documentUrl = e.documentUrl;
      _lineItems = e.lineItems;
      _aiExtracted = e.aiExtracted;
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  static String _trimAmount(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  DateTime? _tryParseDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').parse(s);
    } catch (_) {
      return DateTime.tryParse(s);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  // ── AI bill scan ──────────────────────────────────────────────────────────

  Future<void> _scanBill() async {
    final source = await _showSourceDialog();
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      final ok = await MediaPermissions.ensureCamera(context);
      if (!ok || !mounted) return;
    }

    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() {
      _imagePath = file.path;
      _scanning = true;
    });

    try {
      const prompt = '''You are extracting structured data from a medical bill or receipt image.
Return ONLY a JSON object (no markdown fences, no commentary) with these keys:
- "vendor": string — the hospital / pharmacy / clinic / lab name on the bill, else ""
- "amount": number — the TOTAL payable amount as a plain number (no currency symbol, no commas); 0 if unreadable
- "date": string — the bill date formatted as "DD MMM YYYY" (e.g. "12 Apr 2026"), else ""
- "category": one of "hospital","pharmacy","lab","consultation","imaging","procedure","other"
- "lineItems": string — every individual charge line copied verbatim, one per line as "description — amount" (keep quantities/codes if shown). Empty string if the bill has no itemized lines.
If a field is unreadable, use "" or 0. Output the JSON object only.''';

      final response = await ChatbotService().getGeminiVisionResponse(
        prompt: prompt,
        imagePath: file.path,
      );
      final data = _parseJson(response);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          final vendor = (data['vendor'] ?? '').toString();
          if (vendor.isNotEmpty) _vendorCtrl.text = vendor;
          final amount = data['amount'];
          final amt = amount is num
              ? amount.toDouble()
              : double.tryParse(amount?.toString() ?? '');
          if (amt != null && amt > 0) _amountCtrl.text = _trimAmount(amt);
          final dateStr = (data['date'] ?? '').toString();
          final parsed = dateStr.isNotEmpty ? _tryParseDate(dateStr) : null;
          if (parsed != null) _date = parsed;
          final cat = (data['category'] ?? '').toString();
          if (kExpenseCategories.containsKey(cat)) _category = cat;
          final items = (data['lineItems'] ?? '').toString().trim();
          if (items.isNotEmpty) _lineItems = items;
          _aiExtracted = true;
        });
        _snack('Bill scanned — review the details below.');
      } else {
        _snack('Could not read the bill. Please enter the details manually.');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Tolerantly parses a JSON object out of an LLM response that may wrap it in
  /// markdown fences or surrounding prose.
  Map<String, dynamic>? _parseJson(String raw) {
    var text = raw.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    text = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<ImageSource?> _showSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scan Bill'),
        content: const Text('Capture or choose a photo of the bill/receipt.'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Camera'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _snack('Enter a valid bill amount.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.existing?.id.isNotEmpty == true
          ? widget.existing!.id
          : const Uuid().v4();

      // Upload the receipt image if we have a new local one.
      var documentUrl = _documentUrl;
      if (_imagePath.isNotEmpty && documentUrl.isEmpty && widget.uid.isNotEmpty) {
        final uploaded = await StorageService().uploadDocumentImage(
          filePath: _imagePath,
          patientId: widget.uid,
          scanId: id,
        );
        if (uploaded != null && uploaded.isNotEmpty) documentUrl = uploaded;
      }

      final expense = CaseExpense(
        id: id,
        category: _category,
        vendor: _vendorCtrl.text.trim(),
        date: _date != null ? DateFormat('dd MMM yyyy').format(_date!) : '',
        amount: amount,
        documentUrl: documentUrl,
        imagePath: _imagePath,
        note: _noteCtrl.text.trim(),
        lineItems: _lineItems,
        aiExtracted: _aiExtracted,
      );
      if (mounted) Navigator.pop(context, expense);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final symbol = regionByCurrency(widget.currencyCode).currencySymbol;
    final hasImage = _imagePath.isNotEmpty || _documentUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Bill' : 'Edit Bill'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          // Scan banner
          _ScanCard(
            scanning: _scanning,
            hasImage: hasImage,
            aiExtracted: _aiExtracted,
            onScan: _scanning ? null : _scanBill,
          ),
          const SizedBox(height: AppTheme.lg),

          _Card(children: [
            Text('Bill Details', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: kExpenseCategories.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(kExpenseCategoryIcons[e.key],
                                size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: AppTheme.md),
            TextField(
              controller: _vendorCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Provider / Vendor',
                hintText: 'e.g. City Hospital, Apollo Pharmacy',
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '$symbol ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Bill Date',
                          hintText: 'Select',
                          suffixIcon: const Icon(
                              Icons.calendar_today_rounded, size: 16),
                        ),
                        controller: TextEditingController(
                          text: _date != null
                              ? DateFormat('dd MMM yyyy').format(_date!)
                              : '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything relevant about this bill',
              ),
            ),
          ]),
          const SizedBox(height: AppTheme.xl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
              shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Bill',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ScanCard extends StatelessWidget {
  final bool scanning;
  final bool hasImage;
  final bool aiExtracted;
  final VoidCallback? onScan;

  const _ScanCard({
    required this.scanning,
    required this.hasImage,
    required this.aiExtracted,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onScan,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.largeRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: scanning
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.document_scanner_rounded,
                      color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanning
                        ? 'Reading your bill…'
                        : aiExtracted
                            ? 'Scanned — tap to rescan'
                            : 'Scan bill with AI',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scanning
                        ? 'Extracting amount, vendor & date'
                        : 'Snap the receipt — fields fill in automatically',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!scanning)
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );
}
