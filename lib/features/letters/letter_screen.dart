import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/advocate/advocate_service.dart';
import '../../services/analytics_service.dart';
import '../../services/claim_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';

/// A drafted letter: edit the text, export it as a formal PDF, copy it,
/// share it, and mark it as sent (which schedules a 30-day follow-up).
class LetterScreen extends StatefulWidget {
  final InsuranceClaim claim;
  final GeneratedLetter letter;
  const LetterScreen({super.key, required this.claim, required this.letter});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  final _svc = AdvocateService();
  late InsuranceClaim _claim = widget.claim;
  late GeneratedLetter _letter = widget.letter;
  late final TextEditingController _body = TextEditingController(text: widget.letter.body);
  late final TextEditingController _subject = TextEditingController(text: widget.letter.subject);
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _persist({String? status, bool addFollowUp = false}) async {
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      _letter = _letter.copyWith(
        body: _body.text,
        subject: _subject.text,
        status: status,
        sentAt: status == 'sent' ? DateTime.now() : null,
      );
      _claim = await _svc.updateLetter(uid: uid, claim: _claim, letter: _letter, addFollowUp: addFollowUp);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final profile = context.read<HealthDataProvider>().profile;
      await ClaimPdfService().shareLetter(
        title: LetterKind.label(_letter.kind),
        body: _fullText(),
        regionCode: _claim.country,
        fromName: profile?.fullName,
        subtitle: _subject.text,
        filename: LetterKind.label(_letter.kind),
      );
      Analytics.pdfExported(_letter.kind);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fullText() => [
        if (_letter.recipientBlock.isNotEmpty) _letter.recipientBlock,
        if (_subject.text.isNotEmpty) 'Re: ${_subject.text}',
        _body.text,
      ].join('\n\n');

  Future<void> _markSent() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Mark as sent?'),
        content: const Text('\nClinix will add a 30-day follow-up reminder so nothing slips.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark sent')),
        ],
      ),
    );
    if (ok == true) {
      await _persist(status: 'sent', addFollowUp: true);
      Analytics.log('letter_sent', {'kind': _letter.kind});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _letter.status == 'sent';
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) => Navigator.of(context).canPop() ? null : null,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(CupertinoIcons.chevron_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context, _claim),
          ),
          title: Text(LetterKind.label(_letter.kind), style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700)),
          centerTitle: true,
          actions: [
            if (_editing)
              TextButton(onPressed: _busy ? null : () => _persist(), child: const Text('Save'))
            else
              TextButton(onPressed: sent ? null : () => setState(() => _editing = true), child: const Text('Edit')),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Row(
                      children: [
                        Pill(sent ? 'Sent ${DateFormat('d MMM').format(_letter.sentAt ?? DateTime.now())}' : 'Draft',
                            color: sent ? AppTheme.successColor : AppTheme.warningColor,
                            icon: sent ? CupertinoIcons.paperplane_fill : CupertinoIcons.pencil),
                        const SizedBox(width: 8),
                        Pill(LetterKind.recipient(_letter.kind), color: AppTheme.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Notice(
                      text:
                          'Review every fact before sending. This is a draft prepared from your documents — not legal advice. Replace any [PLACEHOLDER] text.',
                    ),
                    const SizedBox(height: 14),
                    InsetCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_letter.recipientBlock.isNotEmpty) ...[
                            Text(_letter.recipientBlock,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.4)),
                            const SizedBox(height: 12),
                          ],
                          if (_editing)
                            TextField(
                              controller: _subject,
                              decoration: const InputDecoration(labelText: 'Subject'),
                            )
                          else
                            Text('Re: ${_subject.text}',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                          const SizedBox(height: 14),
                          if (_editing)
                            TextField(
                              controller: _body,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              style: AppTheme.bodyMedium.copyWith(height: 1.5),
                              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                            )
                          else
                            SelectableText(_body.text, style: AppTheme.bodyMedium.copyWith(height: 1.55)),
                        ],
                      ),
                    ),
                    if (_letter.checklist.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const DSSectionLabel('ENCLOSE'),
                      InsetCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            for (final c in _letter.checklist)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(CupertinoIcons.doc_on_doc_fill, size: 16, color: AppTheme.primaryColor),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(c, style: AppTheme.bodyMedium)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_letter.sendingTips.isNotEmpty || _letter.deadlineNote.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const DSSectionLabel('SENDING'),
                      InsetCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            if (_letter.deadlineNote.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(CupertinoIcons.clock_fill, size: 16, color: AppTheme.warningColor),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(_letter.deadlineNote, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ),
                            for (final t in _letter.sendingTips)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(CupertinoIcons.lightbulb_fill, size: 16, color: AppTheme.successColor),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(t, style: AppTheme.bodyMedium)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.dividerColor)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TonalButton(
                            label: 'Copy',
                            icon: CupertinoIcons.doc_on_clipboard,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _fullText()));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TonalButton(
                            label: 'Share',
                            icon: CupertinoIcons.share,
                            color: AppTheme.secondaryColor,
                            onTap: () => SharePlus.instance.share(ShareParams(text: _fullText(), subject: _subject.text)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TonalButton(
                            label: 'PDF',
                            icon: CupertinoIcons.doc_richtext,
                            color: AppTheme.dangerColor,
                            onTap: _busy ? null : _exportPdf,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HeroButton(
                      label: sent ? 'Sent — follow-up scheduled' : 'Mark as sent',
                      icon: sent ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.paperplane_fill,
                      loading: _busy,
                      onTap: sent || _busy ? null : _markSent,
                      gradient: sent ? const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF1E9E4A)]) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: AppTheme.isDark ? 0.18 : 0.10),
          borderRadius: DS.squircle(DS.rMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: AppTheme.warningColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary, height: 1.35))),
          ],
        ),
      );
}
