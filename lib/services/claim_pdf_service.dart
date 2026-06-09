import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/config/insurance_regions.dart';
import '../features/claims/add_expense_screen.dart' show kExpenseCategories;
import '../models/patient_models.dart';

/// Builds a polished, **submittable** PDF claim packet from an [InsuranceClaim].
///
/// Unlike the old "copy the AI text" flow, this produces a real document a user
/// can email or print and hand to an insurer: a cover page, a patient/policy/case
/// block, an itemized expense table that totals to the claim amount, the AI
/// medical-necessity narrative, a region-correct rights/escalation footer, and —
/// where receipts exist — the actual receipt images appended as evidence pages.
///
/// The same primitives power the medical-record summary export (see
/// [buildRecordSummary]); claim packets are the flagship, records reuse the engine.
class ClaimPdfService {
  static const PdfColor _ink = PdfColor.fromInt(0xFF0F172A); // slate-900
  static const PdfColor _muted = PdfColor.fromInt(0xFF64748B); // slate-500
  static const PdfColor _line = PdfColor.fromInt(0xFFE2E8F0); // slate-200
  static const PdfColor _brand = PdfColor.fromInt(0xFF007AFF); // iOS blue
  static const PdfColor _brandSoft = PdfColor.fromInt(0xFFEAF2FF);
  static const PdfColor _zebra = PdfColor.fromInt(0xFFF8FAFC);

  /// Generates the claim packet and returns the raw PDF bytes.
  ///
  /// [patientName]/[patientAge] come from the signed-in profile; both are
  /// optional so the packet still renders for a guest or incomplete profile.
  Future<Uint8List> buildClaimPacket({
    required InsuranceClaim claim,
    String? patientName,
    int? patientAge,
    String? patientGender,
    String? bloodGroup,
  }) async {
    final region = regionByCode(claim.country);
    final doc = pw.Document(
      title: 'Insurance Claim — ${claim.insurer}',
      author: patientName ?? 'Clinix AI',
      creator: 'Clinix AI',
      subject: 'Health insurance claim submission',
    );

    final fmt = DateFormat('dd MMM yyyy');
    final ref = _claimReference(claim);

    // Receipt evidence images, resolved up-front (network + local).
    final receipts = await _resolveReceiptImages(claim);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 48),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : _runningHeader(claim, ref),
        footer: (ctx) => _footer(ctx, region),
        build: (ctx) => [
          _coverBlock(claim, region, ref, fmt),
          pw.SizedBox(height: 22),
          _sectionTitle('Policyholder & Patient'),
          _patientTable(
            name: patientName,
            age: patientAge,
            gender: patientGender,
            bloodGroup: bloodGroup,
            region: region,
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Claim & Treatment Details'),
          _caseTable(claim, region, fmt),
          pw.SizedBox(height: 18),
          if (claim.expenses.isNotEmpty) ...[
            _sectionTitle('Itemized Expenses'),
            _expenseTable(claim),
            pw.SizedBox(height: 18),
          ],
          if (claim.claimReport.trim().isNotEmpty) ...[
            _sectionTitle('Medical Necessity & Claim Justification'),
            _narrative(claim.claimReport),
            pw.SizedBox(height: 18),
          ],
          _declaration(patientName, fmt),
        ],
      ),
    );

    // Append receipt evidence as full pages so the insurer sees the bills.
    if (receipts.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 48),
          header: (ctx) => _runningHeader(claim, ref),
          footer: (ctx) => _footer(ctx, region),
          build: (ctx) => [
            _sectionTitle('Supporting Documents (${receipts.length})'),
            pw.SizedBox(height: 8),
            ...receipts.map(_receiptPage),
          ],
        ),
      );
    }

    return doc.save();
  }

  /// Opens the OS share/print sheet for the generated packet.
  Future<void> shareClaimPacket({
    required InsuranceClaim claim,
    String? patientName,
    int? patientAge,
    String? patientGender,
    String? bloodGroup,
  }) async {
    final bytes = await buildClaimPacket(
      claim: claim,
      patientName: patientName,
      patientAge: patientAge,
      patientGender: patientGender,
      bloodGroup: bloodGroup,
    );
    final safeInsurer = claim.insurer.isEmpty
        ? 'Insurer'
        : claim.insurer.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Claim_${safeInsurer}_${_claimReference(claim)}.pdf',
    );
  }

  /// Builds a clean formal **letter/document** PDF from free text — used for
  /// AI appeal letters, billing-dispute letters, and record summaries. Reuses
  /// the same typography and region footer as the claim packet.
  Future<Uint8List> buildLetter({
    required String title,
    required String body,
    String? regionCode,
    String? fromName,
    String? subtitle,
  }) async {
    final region = regionByCode(regionCode);
    final doc = pw.Document(title: title, author: fromName ?? 'Clinix AI');
    final fmt = DateFormat('dd MMM yyyy');
    final blocks = _cleanNarrative(body);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 52),
        footer: (ctx) => _footer(ctx, region),
        build: (ctx) => [
          pw.Text('CLINIX AI',
              style: pw.TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _brand,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 19, color: _ink, fontWeight: pw.FontWeight.bold)),
          if (subtitle != null && subtitle.trim().isNotEmpty)
            pw.Text(subtitle,
                style: const pw.TextStyle(fontSize: 11, color: _muted)),
          pw.SizedBox(height: 4),
          pw.Text(fmt.format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: _muted)),
          pw.Divider(color: _line, height: 28),
          for (final b in blocks) ...[
            if (b.isHeading)
              pw.Text(b.text,
                  style: pw.TextStyle(
                      fontSize: 12,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold))
            else
              pw.Text(b.text,
                  style: const pw.TextStyle(
                      fontSize: 11, color: _ink, lineSpacing: 2.5)),
            pw.SizedBox(height: 9),
          ],
          if (fromName != null && fromName.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Sincerely,',
                style: const pw.TextStyle(fontSize: 11, color: _ink)),
            pw.SizedBox(height: 22),
            pw.Text(fromName,
                style: pw.TextStyle(
                    fontSize: 11, color: _ink, fontWeight: pw.FontWeight.bold)),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// Generates the letter and opens the share/print sheet.
  Future<void> shareLetter({
    required String title,
    required String body,
    String? regionCode,
    String? fromName,
    String? subtitle,
    String? filename,
  }) async {
    final bytes = await buildLetter(
      title: title,
      body: body,
      regionCode: regionCode,
      fromName: fromName,
      subtitle: subtitle,
    );
    final safe = (filename ?? title).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: '$safe.pdf');
  }

  // ── Building blocks ─────────────────────────────────────────────────────────

  String _claimReference(InsuranceClaim claim) {
    final tail = claim.id.replaceAll('-', '');
    final short = tail.length >= 6 ? tail.substring(0, 6).toUpperCase() : 'CLAIM';
    final y = claim.createdAt.year;
    return 'CLX-$y-$short';
  }

  pw.Widget _coverBlock(
    InsuranceClaim claim,
    InsuranceRegion region,
    String ref,
    DateFormat fmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: _brandSoft,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CLINIX AI',
                      style: pw.TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: _brand,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Health Insurance Claim',
                      style: pw.TextStyle(
                          fontSize: 22,
                          color: _ink,
                          fontWeight: pw.FontWeight.bold)),
                  if (claim.title.trim().isNotEmpty)
                    pw.Text(claim.title,
                        style: const pw.TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: _line),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REF', style: _labelStyle()),
                    pw.Text(ref,
                        style: pw.TextStyle(
                            fontSize: 12,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              _coverStat('Insurer', claim.insurer.isEmpty ? '—' : claim.insurer),
              _coverStat('Total Claimed',
                  formatMoney(claim.effectiveAmount, claim.currencyCode)),
              _coverStat('Region', '${region.flag}  ${region.name}'),
              _coverStat('Prepared', fmt.format(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _coverStat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: _labelStyle()),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 12, color: _ink, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _patientTable({
    String? name,
    int? age,
    String? gender,
    String? bloodGroup,
    required InsuranceRegion region,
  }) {
    return _kvTable([
      ('Name', (name?.trim().isNotEmpty ?? false) ? name!.trim() : '—'),
      ('Age', age != null && age > 0 ? '$age years' : '—'),
      if (gender != null && gender.trim().isNotEmpty && gender != 'Prefer not to say')
        ('Gender', gender),
      if (bloodGroup != null && bloodGroup.trim().isNotEmpty)
        ('Blood Group', bloodGroup),
    ]);
  }

  pw.Widget _caseTable(
      InsuranceClaim claim, InsuranceRegion region, DateFormat fmt) {
    final isInpatient = claim.caseType != 'outpatient';
    return _kvTable([
      ('Insurer', claim.insurer.isEmpty ? '—' : claim.insurer),
      ('Policy Number', claim.policyNumber.isEmpty ? '—' : claim.policyNumber),
      ('Case Type', isInpatient ? 'Inpatient / Hospitalization' : 'Outpatient'),
      if (claim.hospitalName.isNotEmpty)
        (isInpatient ? 'Hospital' : 'Provider', claim.hospitalName),
      if (claim.diagnosis.isNotEmpty) ('Diagnosis / Reason', claim.diagnosis),
      if (claim.admissionDate.isNotEmpty)
        (isInpatient ? 'Admission' : 'Visit Date', claim.admissionDate),
      if (claim.dischargeDate.isNotEmpty) ('Discharge', claim.dischargeDate),
      ('Filed On', fmt.format(claim.createdAt)),
      ('Total Claimed',
          formatMoney(claim.effectiveAmount, claim.currencyCode)),
    ]);
  }

  pw.Widget _kvTable(List<(String, String)> rows) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            pw.Container(
              decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.white : _zebra,
                border: i == rows.length - 1
                    ? null
                    : const pw.Border(bottom: pw.BorderSide(color: _line)),
              ),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 150,
                    child: pw.Text(rows[i].$1,
                        style: const pw.TextStyle(fontSize: 10, color: _muted)),
                  ),
                  pw.Expanded(
                    child: pw.Text(rows[i].$2,
                        style: pw.TextStyle(
                            fontSize: 11,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _expenseTable(InsuranceClaim claim) {
    final headerStyle = pw.TextStyle(
        fontSize: 9,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5);
    final cellStyle = const pw.TextStyle(fontSize: 10, color: _ink);

    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _brand),
              children: [
                _cell('Category / Vendor', headerStyle),
                _cell('Details', headerStyle),
                _cell('Date', headerStyle),
                _cell('Amount', headerStyle, align: pw.TextAlign.right),
              ],
            ),
            for (int i = 0; i < claim.expenses.length; i++)
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: i.isEven ? PdfColors.white : _zebra),
                children: [
                  _cell(
                    '${kExpenseCategories[claim.expenses[i].category] ?? claim.expenses[i].category}'
                    '${claim.expenses[i].vendor.isEmpty ? '' : '\n${claim.expenses[i].vendor}'}',
                    cellStyle,
                  ),
                  _cell(
                    claim.expenses[i].lineItems.isNotEmpty
                        ? claim.expenses[i].lineItems
                        : (claim.expenses[i].note.isEmpty
                            ? '—'
                            : claim.expenses[i].note),
                    const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                  _cell(claim.expenses[i].date.isEmpty ? '—' : claim.expenses[i].date,
                      cellStyle),
                  _cell(formatMoney(claim.expenses[i].amount, claim.currencyCode),
                      pw.TextStyle(
                          fontSize: 10,
                          color: _ink,
                          fontWeight: pw.FontWeight.bold),
                      align: pw.TextAlign.right),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _brandSoft),
              children: [
                _cell('TOTAL',
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                _cell('', cellStyle),
                _cell('', cellStyle),
                _cell(
                  formatMoney(claim.totalExpenses, claim.currencyCode),
                  pw.TextStyle(
                      fontSize: 11,
                      color: _brand,
                      fontWeight: pw.FontWeight.bold),
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  /// Renders the AI narrative. The model emits markdown-ish text with `#`/`*`
  /// markers; we strip them to clean paragraphs so the PDF reads like a letter.
  pw.Widget _narrative(String raw) {
    final blocks = _cleanNarrative(raw);
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _zebra,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final b in blocks) ...[
            if (b.isHeading)
              pw.Text(b.text,
                  style: pw.TextStyle(
                      fontSize: 12,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold))
            else
              pw.Text(b.text,
                  style: const pw.TextStyle(
                      fontSize: 10.5, color: _ink, lineSpacing: 2)),
            pw.SizedBox(height: 7),
          ],
        ],
      ),
    );
  }

  pw.Widget _declaration(String? name, DateFormat fmt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Declaration',
              style: pw.TextStyle(
                  fontSize: 12, color: _ink, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            'I declare that the information provided in this claim is true and '
            'complete to the best of my knowledge, and that the expenses listed '
            'were necessarily incurred for the medical treatment described.',
            style: const pw.TextStyle(fontSize: 10, color: _muted, lineSpacing: 2),
          ),
          pw.SizedBox(height: 26),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signLine('Signature'),
              _signLine('Date'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _signLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 180, decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _ink, width: 0.8)))),
        pw.SizedBox(height: 3),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ],
    );
  }

  pw.Widget _receiptPage(_Receipt r) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(r.caption,
              style: pw.TextStyle(
                  fontSize: 10, color: _muted, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.ConstrainedBox(
              constraints: const pw.BoxConstraints(maxHeight: 560),
              child: pw.Image(pw.MemoryImage(r.bytes), fit: pw.BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _runningHeader(InsuranceClaim claim, String ref) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration:
          const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(claim.insurer.isEmpty ? 'Insurance Claim' : claim.insurer,
              style: pw.TextStyle(
                  fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold)),
          pw.Text(ref, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, InsuranceRegion region) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration:
          const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Your rights in ${region.name}: ${region.keyRights}',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            maxLines: 2,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'AI-assisted document — general information only, not legal or financial advice. '
            'Review and verify all details before submitting.',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
            maxLines: 2,
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Clinix AI',
                  style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 4, height: 14, color: _brand),
        pw.SizedBox(width: 8),
        pw.Text(text,
            style: pw.TextStyle(
                fontSize: 13, color: _ink, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.TextStyle _labelStyle() => const pw.TextStyle(
      fontSize: 8, color: _muted, letterSpacing: 1);

  // ── Receipt image resolution ────────────────────────────────────────────────

  Future<List<_Receipt>> _resolveReceiptImages(InsuranceClaim claim) async {
    final out = <_Receipt>[];
    for (int i = 0; i < claim.expenses.length; i++) {
      final e = claim.expenses[i];
      final caption =
          '${kExpenseCategories[e.category] ?? e.category}'
          '${e.vendor.isEmpty ? '' : ' — ${e.vendor}'}'
          '${e.date.isEmpty ? '' : ' (${e.date})'}';
      final bytes = await _loadImage(e.documentUrl, e.imagePath);
      if (bytes != null) out.add(_Receipt(caption: caption, bytes: bytes));
    }
    return out;
  }

  /// Loads receipt bytes from a remote URL first, then a local path. Returns
  /// null (skips the page) on any failure so one bad receipt never aborts the PDF.
  Future<Uint8List?> _loadImage(String url, String localPath) async {
    if (url.trim().startsWith('http')) {
      try {
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[ClaimPdf] remote receipt failed: $e');
      }
    }
    if (localPath.trim().isNotEmpty) {
      try {
        final f = File(localPath);
        if (await f.exists()) return await f.readAsBytes();
      } catch (e) {
        if (kDebugMode) debugPrint('[ClaimPdf] local receipt failed: $e');
      }
    }
    return null;
  }

  // ── Narrative cleaning ──────────────────────────────────────────────────────

  List<_Block> _cleanNarrative(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];
    final buffer = StringBuffer();

    void flush() {
      final t = buffer.toString().trim();
      if (t.isNotEmpty) blocks.add(_Block(t, isHeading: false));
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      // Markdown heading (#, ##) or a bold-only line acts as a section heading.
      final isHeading = RegExp(r'^#{1,4}\s').hasMatch(trimmed) ||
          RegExp(r'^\*\*[^*]+\*\*:?$').hasMatch(trimmed);
      if (isHeading) {
        flush();
        blocks.add(_Block(_stripMd(trimmed), isHeading: true));
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(_stripMd(trimmed));
      }
    }
    flush();
    return blocks;
  }

  String _stripMd(String s) => s
      .replaceAll(RegExp(r'^#{1,4}\s*'), '')
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
      .replaceAll(RegExp(r'^[-*]\s+'), '• ')
      .trim();
}

class _Block {
  final String text;
  final bool isHeading;
  const _Block(this.text, {required this.isHeading});
}

class _Receipt {
  final String caption;
  final Uint8List bytes;
  const _Receipt({required this.caption, required this.bytes});
}
