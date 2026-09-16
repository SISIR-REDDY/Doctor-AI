import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/advocate/advocate_service.dart';
import '../../services/ai/ai_error_ui.dart';
import '../../services/analytics_service.dart';
import '../../services/claim_pdf_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios_pickers.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../deadlines/deadlines_screen.dart' show DeadlineScheduler;
import '../letters/letter_screen.dart';
import '../scan/document_scan_screen.dart';
import 'add_expense_screen.dart';

/// One case: its bills, the audit, the denial and its appeal plan, letters,
/// deadlines and documents — plus the money recovered.
class ClaimDetailScreen extends StatefulWidget {
  final InsuranceClaim claim;
  const ClaimDetailScreen({super.key, required this.claim});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  final _svc = AdvocateService();
  final _db = FirestoreService();
  late InsuranceClaim _claim = widget.claim;

  bool _auditing = false;
  bool _explaining = false;
  bool _drafting = false;
  bool _exporting = false;
  final Set<String> _selectedFindings = {};

  String? _uid;
  Stream<List<ScannedDocument>>? _docs;
  Stream<List<CaseDeadline>>? _deadlines;
  Stream<List<InsurancePolicy>>? _policies;
  List<InsurancePolicy> _policyCache = const [];

  InsuranceRegion get _region => regionByCode(_claim.country.isNotEmpty ? _claim.country : _profile?.country);
  String get _currency => _claim.currencyCode.isNotEmpty ? _claim.currencyCode : _region.currencyCode;
  PatientProfile? get _profile => context.read<HealthDataProvider>().profile;

  void _ensureStreams(String? uid) {
    if (uid == null || uid == _uid) return;
    _uid = uid;
    _docs = _db.watchDocuments(uid, caseId: _claim.id);
    _deadlines = _db.watchDeadlines(uid);
    _policies = _db.watchPolicies(uid);
    _policies!.listen((p) => _policyCache = p, onError: (_) {});
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _runAudit({String notes = ''}) async {
    final uid = _uid;
    if (uid == null || _auditing) return;
    if (_claim.expenses.isEmpty) {
      _snack('Add at least one bill first.');
      return;
    }
    setState(() => _auditing = true);
    try {
      final updated = await _svc.runAudit(uid: uid, claim: _claim, profile: _profile, policies: _policyCache, userNotes: notes);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _claim = updated;
        _selectedFindings
          ..clear()
          ..addAll(updated.audit?.openFindings.map((f) => f.id) ?? const []);
      });
    } catch (e) {
      if (mounted) showAiError(context, e, trigger: 'audit');
    } finally {
      if (mounted) setState(() => _auditing = false);
    }
  }

  Future<void> _explain({String notes = ''}) async {
    final uid = _uid;
    if (uid == null || _explaining) return;
    setState(() => _explaining = true);
    try {
      var updated = await _svc.explainDenial(uid: uid, claim: _claim, profile: _profile, policies: _policyCache, userNotes: notes);
      if (!mounted) return;
      setState(() => _claim = updated);
      // Deadlines are the most valuable side effect — create them right away.
      final created = await _svc.createDeadlines(uid: uid, claim: updated, profile: _profile);
      if (mounted && created.isNotEmpty) {
        _snack('${created.length} ${created.length == 1 ? 'deadline' : 'deadlines'} added with reminders.');
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) showAiError(context, e, trigger: 'explain');
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  Future<void> _draft(String kind) async {
    final uid = _uid;
    if (uid == null || _drafting) return;
    List<AuditFinding> findings = const [];
    List<String> arguments = const [];
    int household = 0;
    double income = 0;
    String extra = '';

    if (kind == LetterKind.dispute) {
      final open = _claim.audit?.openFindings ?? const <AuditFinding>[];
      if (open.isEmpty) {
        _snack('Run the audit first — the dispute letter is built from its findings.');
        return;
      }
      final chosen = await _pickFindings(open);
      if (chosen == null || chosen.isEmpty) return;
      findings = chosen;
    }
    if (kind == LetterKind.appeal && _claim.denialExplanation != null) {
      arguments = _claim.denialExplanation!.arguments.map((a) => '${a.title}: ${a.detail}').toList();
    }
    if (kind == LetterKind.charityCare) {
      final r = await _askCharityDetails();
      if (r == null) return;
      household = r.$1;
      income = r.$2;
    }
    if (kind == LetterKind.medicalNecessity || kind == LetterKind.regulatorComplaint || kind == LetterKind.ombudsmanComplaint) {
      extra = await _askText('Anything the letter should mention?', 'e.g. dates you called, what you were told…') ?? '';
    }

    setState(() => _drafting = true);
    try {
      final updated = await _svc.draftLetter(
        uid: uid,
        claim: _claim,
        kind: kind,
        profile: _profile,
        findings: findings,
        argumentsToUse: arguments,
        evidenceAvailable: _claim.denialExplanation?.evidenceToGather ?? const [],
        householdSize: household,
        annualIncome: income,
        extraInstructions: extra,
      );
      if (!mounted) return;
      setState(() => _claim = updated);
      HapticFeedback.mediumImpact();
      _openLetter(updated.letters.last);
    } catch (e) {
      if (mounted) showAiError(context, e, trigger: 'letter_$kind');
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _openLetter(GeneratedLetter letter) async {
    final result = await Navigator.push<InsuranceClaim>(
      context,
      CupertinoPageRoute(builder: (_) => LetterScreen(claim: _claim, letter: letter)),
    );
    if (result != null && mounted) setState(() => _claim = result);
  }

  Future<void> _setFinding(AuditFinding f, String status) async {
    final uid = _uid;
    if (uid == null) return;
    double? recovered;
    if (status == FindingStatus.resolved) {
      final v = await _askAmount('How much was corrected or refunded?', f.estimatedSavingHigh);
      if (v == null) return;
      recovered = v;
    }
    try {
      final updated = await _svc.updateFinding(uid: uid, claim: _claim, findingId: f.id, status: status, recoveredAmount: recovered);
      if (mounted) setState(() => _claim = updated);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _setOutcome() async {
    final status = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('How did this case end?'),
        actions: [
          for (final s in [OutcomeStatus.won, OutcomeStatus.partial, OutcomeStatus.lost, OutcomeStatus.withdrawn])
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, s), child: Text(OutcomeStatus.label(s))),
          if (_claim.isClosed)
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, OutcomeStatus.open), child: const Text('Reopen case')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
    if (status == null || _uid == null) return;
    double amount = 0;
    if (status == OutcomeStatus.won || status == OutcomeStatus.partial) {
      final v = await _askAmount('How much did you get back or have written off?', _claim.potentialSaving);
      if (v == null) return;
      amount = v;
    }
    try {
      final updated = await _svc.setOutcome(uid: _uid!, claim: _claim, status: status, recoveredAmount: amount);
      if (!mounted) return;
      setState(() => _claim = updated);
      if (status == OutcomeStatus.won || status == OutcomeStatus.partial) {
        HapticFeedback.heavyImpact();
        _offerShare(amount);
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _offerShare(double amount) async {
    final share = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('${formatMoney(amount, _currency)} recovered'),
        content: const Text('\nNice work. Most people never dispute a bill — want to tell someone it works?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Share')),
        ],
      ),
    );
    if (share == true) {
      Analytics.log('share_win');
      await SharePlus.instance.share(ShareParams(
        text: 'I just got ${formatMoney(amount, _currency)} back on a medical bill using Clinix — it reads the bill, finds the errors and writes the dispute for you. clinixai.app',
      ));
    }
  }

  Future<void> _addBillManually() async {
    final uid = _uid;
    if (uid == null) return;
    final result = await Navigator.push<CaseExpense>(
      context,
      CupertinoPageRoute(builder: (_) => AddExpenseScreen(uid: uid, currencyCode: _currency)),
    );
    if (result == null || !mounted) return;
    final updated = _claim.copyWith(expenses: [..._claim.expenses, result], updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    if (mounted) setState(() => _claim = updated);
  }

  Future<void> _editBill(CaseExpense e) async {
    final uid = _uid;
    if (uid == null) return;
    final result = await Navigator.push<CaseExpense>(
      context,
      CupertinoPageRoute(builder: (_) => AddExpenseScreen(uid: uid, currencyCode: _currency, existing: e)),
    );
    if (result == null || !mounted) return;
    final updated = _claim.copyWith(
      expenses: _claim.expenses.map((x) => x.id == result.id ? result : x).toList(),
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    if (mounted) setState(() => _claim = updated);
  }

  Future<void> _removeBill(CaseExpense e) async {
    final uid = _uid;
    if (uid == null) return;
    final updated = _claim.copyWith(expenses: _claim.expenses.where((x) => x.id != e.id).toList(), updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    if (mounted) setState(() => _claim = updated);
  }

  Future<void> _addDeadline() async {
    final uid = _uid;
    if (uid == null) return;
    final title = await _askText('Deadline', 'e.g. Call insurer about claim status');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final date = await showIosDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    final d = CaseDeadline(
      id: const Uuid().v4(),
      caseId: _claim.id,
      caseTitle: _title,
      title: title.trim(),
      dueDate: DateTime(date.year, date.month, date.day, 9),
      source: 'manual',
    );
    await _db.saveDeadline(uid, d);
    await DeadlineScheduler.schedule(d);
  }

  Future<void> _exportPacket() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final p = _profile;
      await ClaimPdfService().shareClaimPacket(
        claim: _claim,
        patientName: _claim.patientName.isNotEmpty ? _claim.patientName : p?.fullName,
        patientAge: p?.age,
        patientGender: p?.gender,
        bloodGroup: p?.bloodGroup,
      );
      Analytics.pdfExported('packet');
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteCase() async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete this case?'),
        content: const Text('\nBills, audit, letters and deadlines will be removed.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteDeadlinesForCase(uid, _claim.id);
    await _db.deleteClaim(uid, _claim.id);
    if (mounted) Navigator.pop(context);
  }

  // ── Dialog helpers ─────────────────────────────────────────────────────────

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<String?> _askText(String title, String hint) async {
    final ctrl = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: ctrl, placeholder: hint, maxLines: 3, autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Continue')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<double?> _askAmount(String title, double suggested) async {
    final ctrl = TextEditingController(text: suggested > 0 ? suggested.toStringAsFixed(0) : '');
    final result = await showCupertinoDialog<double>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            prefix: Padding(padding: const EdgeInsets.only(left: 8), child: Text(_currency)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<(int, double)?> _askCharityDetails() async {
    final h = TextEditingController();
    final i = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Financial assistance'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text('Optional — hospitals screen on household size and income.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              CupertinoTextField(controller: h, placeholder: 'Household size', keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              CupertinoTextField(controller: i, placeholder: 'Annual household income ($_currency)', keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Draft')),
        ],
      ),
    );
    final r = ok == true ? (int.tryParse(h.text) ?? 0, double.tryParse(i.text.replaceAll(',', '')) ?? 0) : null;
    h.dispose();
    i.dispose();
    return r;
  }

  Future<List<AuditFinding>?> _pickFindings(List<AuditFinding> open) async {
    final selected = {..._selectedFindings.where((id) => open.any((f) => f.id == id))};
    if (selected.isEmpty) selected.addAll(open.map((f) => f.id));
    return showModalBottomSheet<List<AuditFinding>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
            decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DS.squircle(DS.rXl)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Text('Include in the dispute letter', style: AppTheme.headingMedium),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    children: [
                      for (final f in open)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ChoiceCard(
                            multi: true,
                            title: f.title,
                            subtitle: 'Up to ${formatMoney(f.estimatedSavingHigh, _currency)}',
                            selected: selected.contains(f.id),
                            onTap: () => setSheet(() {
                              if (!selected.remove(f.id)) selected.add(f.id);
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: HeroButton(
                    label: 'Draft letter (${selected.length})',
                    icon: CupertinoIcons.doc_text_fill,
                    onTap: selected.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, open.where((f) => selected.contains(f.id)).toList()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => _claim.title.isNotEmpty
      ? _claim.title
      : _claim.hospitalName.isNotEmpty
          ? _claim.hospitalName
          : _claim.insurer.isNotEmpty
              ? _claim.insurer
              : 'Case';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<HealthDataProvider>().uid;
    _ensureStreams(uid);
    final busy = _auditing || _explaining || _drafting;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: AppTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                tooltip: 'Export claim packet (PDF)',
                icon: _exporting
                    ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                    : Icon(CupertinoIcons.square_arrow_up, color: AppTheme.primaryColor),
                onPressed: _exporting ? null : _exportPacket,
              ),
              PopupMenuButton<String>(
                icon: Icon(CupertinoIcons.ellipsis_circle, color: AppTheme.textPrimary),
                onSelected: (v) {
                  switch (v) {
                    case 'outcome':
                      _setOutcome();
                    case 'deadline':
                      _addDeadline();
                    case 'delete':
                      _deleteCase();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'outcome', child: Text(_claim.isClosed ? 'Change outcome' : 'Record outcome')),
                  const PopupMenuItem(value: 'deadline', child: Text('Add a deadline')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete case', style: TextStyle(color: AppTheme.dangerColor))),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.6,
              titlePadding: const EdgeInsets.only(left: DS.gutter, bottom: 14, right: 100),
              title: Text(_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppTheme.textPrimary)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(DS.gutter, 4, DS.gutter, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeaderCard(claim: _claim, currency: _currency, onOutcome: _setOutcome),
                const SizedBox(height: 14),
                _NextStep(
                  claim: _claim,
                  busy: busy,
                  auditing: _auditing,
                  explaining: _explaining,
                  drafting: _drafting,
                  onAudit: () => _runAudit(),
                  onExplain: () => _explain(),
                  onDraftAppeal: () => _draft(LetterKind.appeal),
                  onDraftDispute: () => _draft(LetterKind.dispute),
                  onOpenDraft: () => _openLetter(_claim.letters.lastWhere((l) => l.status == 'draft')),
                  onScan: () => DocumentScanScreen.open(context, trigger: 'case', caseId: _claim.id),
                  onOutcome: _setOutcome,
                ),
                const SizedBox(height: 22),
                _BillsSection(
                  claim: _claim,
                  currency: _currency,
                  onScan: () => DocumentScanScreen.open(context, trigger: 'case_bill', docType: DocType.bill, caseId: _claim.id),
                  onManual: _addBillManually,
                  onEdit: _editBill,
                  onRemove: _removeBill,
                ),
                if (_claim.audit != null) ...[
                  const SizedBox(height: 22),
                  _AuditSection(
                    audit: _claim.audit!,
                    currency: _currency,
                    selected: _selectedFindings,
                    auditing: _auditing,
                    onToggle: (id) => setState(() {
                      if (!_selectedFindings.remove(id)) _selectedFindings.add(id);
                    }),
                    onSetStatus: _setFinding,
                    onRerun: () async {
                      final notes = await _askText('Add details for a sharper audit', 'Answer the questions, or add context…');
                      if (notes != null) _runAudit(notes: notes);
                    },
                    onDispute: () => _draft(LetterKind.dispute),
                    onItemized: () => _draft(LetterKind.itemizedRequest),
                    onCharity: () => _draft(LetterKind.charityCare),
                  ),
                ],
                if (_claim.denial != null) ...[
                  const SizedBox(height: 22),
                  _DenialSection(
                    claim: _claim,
                    currency: _currency,
                    region: _region,
                    explaining: _explaining,
                    onExplain: () => _explain(),
                    onRerun: () async {
                      final notes = await _askText('Add details', 'e.g. my doctor says…, the policy section says…');
                      if (notes != null) _explain(notes: notes);
                    },
                    onAppeal: () => _draft(LetterKind.appeal),
                    onNecessity: () => _draft(LetterKind.medicalNecessity),
                    onRecords: () => _draft(LetterKind.recordsRequest),
                  ),
                ],
                const SizedBox(height: 22),
                _LettersSection(
                  claim: _claim,
                  drafting: _drafting,
                  onOpen: _openLetter,
                  onDraft: _draft,
                  onDelete: (l) async {
                    if (_uid == null) return;
                    final updated = await _svc.deleteLetter(uid: _uid!, claim: _claim, letterId: l.id);
                    if (mounted) setState(() => _claim = updated);
                  },
                ),
                const SizedBox(height: 22),
                _DeadlinesSection(stream: _deadlines, caseId: _claim.id, uid: _uid, db: _db, onAdd: _addDeadline),
                const SizedBox(height: 22),
                _DocumentsSection(stream: _docs, onScan: () => DocumentScanScreen.open(context, trigger: 'case_docs', caseId: _claim.id)),
                const SizedBox(height: 22),
                _DetailsSection(claim: _claim, region: _region, currency: _currency),
                if (_hasLegacyNotes) ...[
                  const SizedBox(height: 22),
                  _LegacyNotes(claim: _claim),
                ],
                const SizedBox(height: 24),
                Text(
                  'Clinix provides general information and document drafts based on what you upload — not legal, financial or medical advice. Verify amounts and rules before acting; outcomes are never guaranteed.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary, height: 1.4),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasLegacyNotes =>
      _claim.claimReport.isNotEmpty ||
      _claim.fightAnalysis.isNotEmpty ||
      _claim.appealLetter.isNotEmpty ||
      _claim.auditReport.isNotEmpty ||
      _claim.disputeLetter.isNotEmpty;
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final InsuranceClaim claim;
  final String currency;
  final VoidCallback onOutcome;
  const _HeaderCard({required this.claim, required this.currency, required this.onOutcome});

  @override
  Widget build(BuildContext context) {
    final closed = claim.isClosed;
    final won = claim.outcomeStatus == OutcomeStatus.won || claim.outcomeStatus == OutcomeStatus.partial;
    final gradient = closed
        ? (won
            ? const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF1E9E4A)])
            : const LinearGradient(colors: [Color(0xFF6E6E73), Color(0xFF48484A)]))
        : claim.hasDenial
            ? const LinearGradient(colors: [Color(0xFFFF9500), Color(0xFFE0561F)])
            : const LinearGradient(colors: [Color(0xFF0A84FF), Color(0xFF0057D9)]);
    final parties = [
      if (claim.insurer.isNotEmpty) claim.insurer,
      if (claim.hospitalName.isNotEmpty) claim.hospitalName,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: DS.squircle(DS.rXl),
        boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.32), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                closed ? OutcomeStatus.label(claim.outcomeStatus) : (claim.hasDenial ? 'Denied claim' : 'Open case'),
                color: Colors.white,
                icon: closed ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.circle_fill,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onOutcome,
                child: Text(closed ? 'Change' : 'Record outcome',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: claim.hasDenial ? 'Denied' : 'Billed',
                  value: claim.hasDenial && claim.denial!.amountDenied > 0
                      ? formatMoney(claim.denial!.amountDenied, currency)
                      : claim.effectiveAmount > 0
                          ? formatMoney(claim.effectiveAmount, currency)
                          : '—',
                  foreground: Colors.white,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: closed ? 'Recovered' : 'Potential saving',
                  value: closed
                      ? formatMoney(claim.totalRecovered, currency)
                      : claim.potentialSaving > 0
                          ? formatMoney(claim.potentialSaving, currency)
                          : '—',
                  foreground: Colors.white,
                ),
              ),
            ],
          ),
          if (parties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(parties, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ── Next step ─────────────────────────────────────────────────────────────────

class _NextStep extends StatelessWidget {
  final InsuranceClaim claim;
  final bool busy, auditing, explaining, drafting;
  final VoidCallback onAudit, onExplain, onDraftAppeal, onDraftDispute, onOpenDraft, onScan, onOutcome;
  const _NextStep({
    required this.claim,
    required this.busy,
    required this.auditing,
    required this.explaining,
    required this.drafting,
    required this.onAudit,
    required this.onExplain,
    required this.onDraftAppeal,
    required this.onDraftDispute,
    required this.onOpenDraft,
    required this.onScan,
    required this.onOutcome,
  });

  @override
  Widget build(BuildContext context) {
    if (claim.isClosed) {
      return HeroButton(label: 'Reopen or change outcome', icon: CupertinoIcons.arrow_counterclockwise, onTap: onOutcome, color: AppTheme.textSecondary);
    }
    final (label, icon, action, loading, hint) = _resolve();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroButton(label: label, icon: icon, onTap: busy ? null : action, loading: loading),
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(hint, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          ),
      ],
    );
  }

  (String, IconData, VoidCallback, bool, String) _resolve() {
    if (claim.denial != null && claim.denialExplanation == null) {
      return ('Explain this denial & plan the appeal', CupertinoIcons.sparkles, onExplain, explaining, 'Your rights, the insurer’s obligations, deadlines and how strong the case is.');
    }
    if (claim.denial != null && !claim.letters.any((l) => l.kind == LetterKind.appeal)) {
      return ('Draft the appeal letter', CupertinoIcons.doc_text_fill, onDraftAppeal, drafting, 'Built from the denial, your policy and the arguments above.');
    }
    if (claim.letters.any((l) => l.status == 'draft')) {
      return ('Review & send your draft letter', CupertinoIcons.paperplane_fill, onOpenDraft, false, 'Edit, export as PDF, then mark it sent to start the follow-up timer.');
    }
    if (claim.expenses.isNotEmpty && claim.audit == null) {
      return ('Run the bill audit', CupertinoIcons.doc_text_search, onAudit, auditing, 'Duplicates, unbundling, quantity errors and prices vs fair-price references.');
    }
    if (claim.audit != null && claim.audit!.openFindings.isNotEmpty) {
      return ('Draft the dispute letter', CupertinoIcons.doc_text_fill, onDraftDispute, drafting, 'Pick the findings to contest; the letter goes to the provider’s billing department.');
    }
    if (claim.expenses.isEmpty && claim.denial == null) {
      return ('Scan a bill or letter', CupertinoIcons.camera_viewfinder, onScan, false, 'Add the itemized bill, insurer statement or denial letter for this case.');
    }
    return ('Record the outcome', CupertinoIcons.checkmark_seal_fill, onOutcome, false, 'Log what you got back so your savings are tracked.');
  }
}

// ── Bills ─────────────────────────────────────────────────────────────────────

class _BillsSection extends StatelessWidget {
  final InsuranceClaim claim;
  final String currency;
  final VoidCallback onScan;
  final VoidCallback onManual;
  final ValueChanged<CaseExpense> onEdit;
  final ValueChanged<CaseExpense> onRemove;
  const _BillsSection({required this.claim, required this.currency, required this.onScan, required this.onManual, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSectionLabel(
          'BILLS (${claim.expenses.length})',
          trailing: claim.expenses.isEmpty
              ? null
              : Text(formatMoney(claim.totalExpenses, currency),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),
        InsetCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final e in claim.expenses)
                InsetRow(
                  icon: kExpenseCategoryIcons[e.category] ?? CupertinoIcons.doc_text,
                  iconColor: AppTheme.primaryColor,
                  title: e.vendor.isNotEmpty ? e.vendor : (kExpenseCategories[e.category] ?? 'Bill'),
                  subtitle: [
                    if (e.date.isNotEmpty) e.date,
                    if (e.items.isNotEmpty) '${e.items.length} line items' else if (e.lineItems.trim().isNotEmpty) 'itemized' else 'not itemized',
                  ].join(' · '),
                  value: formatMoney(e.amount, currency),
                  trailing: SizedBox(
                    width: 30,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(CupertinoIcons.ellipsis, size: 16, color: AppTheme.textTertiary),
                      onSelected: (v) => v == 'edit' ? onEdit(e) : onRemove(e),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: AppTheme.dangerColor))),
                      ],
                    ),
                  ),
                  onTap: () => _showItems(context, e),
                ),
              InsetRow(
                icon: CupertinoIcons.camera_fill,
                iconColor: AppTheme.successColor,
                title: 'Scan a bill',
                subtitle: 'Camera, photos or PDF — line items extracted automatically',
                onTap: onScan,
              ),
              InsetRow(
                icon: CupertinoIcons.pencil,
                iconColor: AppTheme.textSecondary,
                title: 'Enter manually',
                onTap: onManual,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showItems(BuildContext context, CaseExpense e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DS.squircle(DS.rXl)),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            children: [
              Text(e.vendor.isNotEmpty ? e.vendor : 'Bill', style: AppTheme.headingMedium),
              Text('${e.date}${e.note.isNotEmpty ? ' · ${e.note}' : ''}', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              if (e.items.isEmpty && e.lineItems.trim().isEmpty)
                Text('No line items. Scan the itemized bill to enable the audit.', style: AppTheme.bodyMedium),
              if (e.items.isEmpty && e.lineItems.trim().isNotEmpty)
                Text(e.lineItems, style: AppTheme.bodyMedium.copyWith(height: 1.5)),
              for (final it in e.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.description, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            Text([if (it.code.isNotEmpty) it.code, if (it.dateOfService.isNotEmpty) it.dateOfService, if (it.quantity != 1) '×${it.quantity.toStringAsFixed(0)}'].join(' · '),
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(formatMoney(it.amount, currency), style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text('Total', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text(formatMoney(e.amount, currency), style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Audit ─────────────────────────────────────────────────────────────────────

class _AuditSection extends StatelessWidget {
  final AuditReport audit;
  final String currency;
  final Set<String> selected;
  final bool auditing;
  final ValueChanged<String> onToggle;
  final void Function(AuditFinding, String) onSetStatus;
  final VoidCallback onRerun, onDispute, onItemized, onCharity;
  const _AuditSection({
    required this.audit,
    required this.currency,
    required this.selected,
    required this.auditing,
    required this.onToggle,
    required this.onSetStatus,
    required this.onRerun,
    required this.onDispute,
    required this.onItemized,
    required this.onCharity,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (audit.overallRisk) { 'high' => AppTheme.dangerColor, 'low' => AppTheme.successColor, _ => AppTheme.warningColor };
    final open = audit.openFindings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSectionLabel(
          'BILL AUDIT',
          trailing: GestureDetector(
            onTap: auditing ? null : onRerun,
            child: Text('Re-run', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        InsetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pill('${audit.overallRisk[0].toUpperCase()}${audit.overallRisk.substring(1)} likelihood of errors', color: riskColor, icon: CupertinoIcons.exclamationmark_circle_fill),
                  const Spacer(),
                  Text(DateFormat('d MMM').format(audit.createdAt), style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: 'Potential saving',
                      value: audit.totalSavingHigh > 0
                          ? '${formatMoney(audit.totalSavingLow, currency)} – ${formatMoney(audit.totalSavingHigh, currency)}'
                          : 'None found',
                      foreground: audit.totalSavingHigh > 0 ? AppTheme.successColor : null,
                    ),
                  ),
                  if (audit.recovered > 0)
                    Expanded(child: StatTile(compact: true, label: 'Recovered', value: formatMoney(audit.recovered, currency), foreground: AppTheme.successColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(audit.summary, style: AppTheme.bodyMedium.copyWith(height: 1.45)),
              if (audit.itemizedBillMissing) ...[
                const SizedBox(height: 12),
                TonalButton(label: 'Request an itemized bill', icon: CupertinoIcons.doc_text, onTap: onItemized),
              ],
              if (audit.charityCareLikely) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.12), borderRadius: DS.squircle(DS.rMd)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(CupertinoIcons.gift_fill, size: 16, color: AppTheme.successColor),
                        const SizedBox(width: 8),
                        Text('Financial assistance may apply', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.successColor)),
                      ]),
                      if (audit.charityCareNote.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(audit.charityCareNote, style: AppTheme.bodySmall.copyWith(height: 1.35)),
                      ],
                      const SizedBox(height: 10),
                      TonalButton(label: 'Draft assistance request', icon: CupertinoIcons.doc_text, color: AppTheme.successColor, onTap: onCharity, height: 44),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (audit.findings.isNotEmpty) ...[
          const SizedBox(height: 14),
          DSSectionLabel('FINDINGS (${audit.findings.length})', trailing: open.isEmpty ? null : Text('${selected.length} selected', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          for (final f in audit.findings)
            _FindingCard(
              finding: f,
              currency: currency,
              selected: selected.contains(f.id),
              onToggle: f.isOpen ? () => onToggle(f.id) : null,
              onStatus: (s) => onSetStatus(f, s),
            ),
          if (open.isNotEmpty) ...[
            const SizedBox(height: 6),
            HeroButton(label: 'Draft dispute letter', icon: CupertinoIcons.doc_text_fill, onTap: onDispute),
          ],
        ],
        if (audit.nextSteps.isNotEmpty) ...[
          const SizedBox(height: 14),
          const DSSectionLabel('NEXT STEPS'),
          InsetCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < audit.nextSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(audit.nextSteps[i], style: AppTheme.bodyMedium.copyWith(height: 1.35))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (audit.questionsForUser.isNotEmpty) ...[
          const SizedBox(height: 14),
          InsetCard(
            onTap: onRerun,
            child: Row(
              children: [
                IconBadge(CupertinoIcons.question_circle_fill, color: AppTheme.infoColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sharpen this audit', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 3),
                      for (final q in audit.questionsForUser.take(3))
                        Text('• $q', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.3)),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 15, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FindingCard extends StatefulWidget {
  final AuditFinding finding;
  final String currency;
  final bool selected;
  final VoidCallback? onToggle;
  final ValueChanged<String> onStatus;
  const _FindingCard({required this.finding, required this.currency, required this.selected, required this.onToggle, required this.onStatus});

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final sev = switch (f.severity) { 'high' => AppTheme.dangerColor, 'low' => AppTheme.infoColor, _ => AppTheme.warningColor };
    final statusColor = switch (f.status) {
      FindingStatus.resolved => AppTheme.successColor,
      FindingStatus.disputed => AppTheme.primaryColor,
      FindingStatus.dismissed => AppTheme.textTertiary,
      _ => sev,
    };
    final dim = f.status == FindingStatus.dismissed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: DS.squircle(DS.rLg),
            border: Border.all(color: widget.selected ? AppTheme.primaryColor : AppTheme.glassBorder, width: widget.selected ? 1.4 : 0.7),
            boxShadow: DS.softShadow(),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: DS.squircle(DS.rLg),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.onToggle != null)
                        GestureDetector(
                          onTap: widget.onToggle,
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 12, top: 1),
                            decoration: BoxDecoration(
                              color: widget.selected ? AppTheme.primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: widget.selected ? AppTheme.primaryColor : AppTheme.textTertiary, width: 1.6),
                            ),
                            child: widget.selected ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white) : null,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Pill(AuditFinding.typeLabel(f.type), color: statusColor),
                                const SizedBox(width: 6),
                                if (f.status != FindingStatus.open)
                                  Pill(f.status[0].toUpperCase() + f.status.substring(1), color: statusColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(f.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 3),
                            Text(
                              f.status == FindingStatus.resolved && f.recoveredAmount > 0
                                  ? 'Recovered ${formatMoney(f.recoveredAmount, widget.currency)}'
                                  : 'Save ${formatMoney(f.estimatedSavingLow, widget.currency)} – ${formatMoney(f.estimatedSavingHigh, widget.currency)} of ${formatMoney(f.amountAtIssue, widget.currency)}',
                              style: AppTheme.bodySmall.copyWith(color: AppTheme.successColor, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Icon(_open ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, size: 15, color: AppTheme.textTertiary),
                    ],
                  ),
                ),
              ),
              if (_open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.explanation, style: AppTheme.bodyMedium.copyWith(height: 1.45)),
                      if (f.lineDescriptions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Lines: ${f.lineDescriptions.join('; ')}', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                      ],
                      if (f.benchmarkCode.isNotEmpty && f.benchmarkReferencePrice > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: DS.squircle(10)),
                          child: Text(
                            'Reference for ${f.benchmarkCode}: ${formatMoney(f.benchmarkReferencePrice, widget.currency)} · billed ${f.benchmarkRatio > 0 ? '${f.benchmarkRatio.toStringAsFixed(1)}× that' : 'above that'}',
                            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text('What to do', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                      const SizedBox(height: 3),
                      Text(f.recommendedAction, style: AppTheme.bodySmall.copyWith(height: 1.4)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (f.status != FindingStatus.resolved)
                            _MiniAction(label: 'Resolved…', icon: CupertinoIcons.checkmark_alt, color: AppTheme.successColor, onTap: () => widget.onStatus(FindingStatus.resolved)),
                          if (f.status != FindingStatus.dismissed)
                            _MiniAction(label: 'Dismiss', icon: CupertinoIcons.xmark, color: AppTheme.textSecondary, onTap: () => widget.onStatus(FindingStatus.dismissed)),
                          if (f.status != FindingStatus.open)
                            _MiniAction(label: 'Reopen', icon: CupertinoIcons.arrow_counterclockwise, color: AppTheme.primaryColor, onTap: () => widget.onStatus(FindingStatus.open)),
                        ],
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

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

// ── Denial ────────────────────────────────────────────────────────────────────

class _DenialSection extends StatelessWidget {
  final InsuranceClaim claim;
  final String currency;
  final InsuranceRegion region;
  final bool explaining;
  final VoidCallback onExplain, onRerun, onAppeal, onNecessity, onRecords;
  const _DenialSection({
    required this.claim,
    required this.currency,
    required this.region,
    required this.explaining,
    required this.onExplain,
    required this.onRerun,
    required this.onAppeal,
    required this.onNecessity,
    required this.onRecords,
  });

  @override
  Widget build(BuildContext context) {
    final d = claim.denial!;
    final x = claim.denialExplanation;
    final strengthColor = switch (x?.strength) { 'strong' => AppTheme.successColor, 'weak' => AppTheme.dangerColor, _ => AppTheme.warningColor };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSectionLabel('DENIAL', trailing: x == null ? null : GestureDetector(onTap: explaining ? null : onRerun, child: Text('Add details', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)))),
        InsetCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              _kv('Reason', DenialInfo.reasonLabel(d.reasonCategory)),
              if (d.serviceDescription.isNotEmpty) _kv('Service', d.serviceDescription),
              if (d.claimNumber.isNotEmpty) _kv('Claim #', d.claimNumber),
              if (d.denialDate.isNotEmpty) _kv('Denial date', d.denialDate),
              if (d.appealDeadline.isNotEmpty || d.appealDeadlineText.isNotEmpty) _kv('Appeal by', d.appealDeadline.isNotEmpty ? d.appealDeadline : d.appealDeadlineText),
              if (d.isUrgent) _kv('Urgent', 'Yes — ask for an expedited appeal'),
              if (d.reasonText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('“${d.reasonText}”', style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic, height: 1.4, color: AppTheme.textSecondary)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (x == null)
          HeroButton(label: 'Explain this denial & plan the appeal', icon: CupertinoIcons.sparkles, onTap: onExplain, loading: explaining)
        else ...[
          InsetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Pill(x.isDisputable ? '${x.strength[0].toUpperCase()}${x.strength.substring(1)} case' : 'Hard to dispute', color: strengthColor, icon: CupertinoIcons.scope),
                ]),
                const SizedBox(height: 10),
                Text(x.plainSummary, style: AppTheme.bodyMedium.copyWith(height: 1.45)),
                const SizedBox(height: 10),
                Text('Why it was denied', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(x.whyDenied, style: AppTheme.bodySmall.copyWith(height: 1.4)),
                if (x.successEstimate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Odds', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Text(x.successEstimate, style: AppTheme.bodySmall.copyWith(height: 1.4)),
                ],
              ],
            ),
          ),
          if (x.arguments.isNotEmpty) ...[
            const SizedBox(height: 14),
            const DSSectionLabel('ARGUMENTS TO MAKE'),
            InsetCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final a in x.arguments)
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 10),
                        title: Text(a.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        children: [Align(alignment: Alignment.centerLeft, child: Text(a.detail, style: AppTheme.bodySmall.copyWith(height: 1.4)))],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (x.evidenceToGather.isNotEmpty) ...[
            const SizedBox(height: 14),
            const DSSectionLabel('EVIDENCE TO GATHER'),
            InsetCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (final e in x.evidenceToGather)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(CupertinoIcons.doc_on_doc_fill, size: 15, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e, style: AppTheme.bodyMedium)),
                    ]),
                  ),
              ]),
            ),
          ],
          if (x.steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            const DSSectionLabel('APPEAL PATH'),
            InsetCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (var i = 0; i < x.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppTheme.warningColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.warningColor)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.steps[i].stage, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          Text(x.steps[i].action, style: AppTheme.bodySmall.copyWith(height: 1.35)),
                          if (x.steps[i].deadline.isNotEmpty)
                            Text(x.steps[i].deadline, style: AppTheme.bodySmall.copyWith(color: AppTheme.warningColor, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          HeroButton(label: 'Draft appeal letter', icon: CupertinoIcons.doc_text_fill, onTap: onAppeal),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TonalButton(label: 'Medical necessity', icon: CupertinoIcons.person_crop_square_fill, onTap: onNecessity)),
            const SizedBox(width: 10),
            Expanded(child: TonalButton(label: 'Request claim file', icon: CupertinoIcons.folder_fill, color: AppTheme.secondaryColor, onTap: onRecords)),
          ]),
        ],
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary))),
          Expanded(child: Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
        ]),
      );
}

// ── Letters ───────────────────────────────────────────────────────────────────

class _LettersSection extends StatelessWidget {
  final InsuranceClaim claim;
  final bool drafting;
  final ValueChanged<GeneratedLetter> onOpen;
  final ValueChanged<String> onDraft;
  final ValueChanged<GeneratedLetter> onDelete;
  const _LettersSection({required this.claim, required this.drafting, required this.onOpen, required this.onDraft, required this.onDelete});

  static const _kinds = [
    LetterKind.appeal,
    LetterKind.dispute,
    LetterKind.itemizedRequest,
    LetterKind.charityCare,
    LetterKind.medicalNecessity,
    LetterKind.recordsRequest,
    LetterKind.regulatorComplaint,
    LetterKind.ombudsmanComplaint,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSectionLabel('LETTERS (${claim.letters.length})'),
        InsetCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final l in claim.letters.reversed)
                InsetRow(
                  icon: l.status == 'sent' ? CupertinoIcons.paperplane_fill : CupertinoIcons.doc_text,
                  iconColor: l.status == 'sent' ? AppTheme.successColor : AppTheme.warningColor,
                  title: LetterKind.label(l.kind),
                  subtitle: '${l.status == 'sent' ? 'Sent' : 'Draft'} · ${DateFormat('d MMM yyyy').format(l.sentAt ?? l.createdAt)}',
                  trailing: SizedBox(
                    width: 30,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(CupertinoIcons.ellipsis, size: 16, color: AppTheme.textTertiary),
                      onSelected: (_) => onDelete(l),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.dangerColor)))],
                    ),
                  ),
                  onTap: () => onOpen(l),
                ),
              InsetRow(
                icon: drafting ? CupertinoIcons.hourglass : CupertinoIcons.plus_circle_fill,
                iconColor: AppTheme.primaryColor,
                title: drafting ? 'Drafting…' : 'Draft a letter',
                subtitle: 'Appeal, dispute, itemized request, assistance, complaints…',
                onTap: drafting
                    ? null
                    : () async {
                        final k = await showCupertinoModalPopup<String>(
                          context: context,
                          builder: (ctx) => CupertinoActionSheet(
                            title: const Text('Draft a letter'),
                            actions: [
                              for (final k in _kinds)
                                CupertinoActionSheetAction(
                                  onPressed: () => Navigator.pop(ctx, k),
                                  child: Text('${LetterKind.label(k)} — ${LetterKind.recipient(k)}'),
                                ),
                            ],
                            cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ),
                        );
                        if (k != null) onDraft(k);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Deadlines ─────────────────────────────────────────────────────────────────

class _DeadlinesSection extends StatelessWidget {
  final Stream<List<CaseDeadline>>? stream;
  final String caseId;
  final String? uid;
  final FirestoreService db;
  final VoidCallback onAdd;
  const _DeadlinesSection({required this.stream, required this.caseId, required this.uid, required this.db, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CaseDeadline>>(
      stream: stream,
      builder: (context, snap) {
        final all = (snap.data ?? const <CaseDeadline>[]).where((d) => d.caseId == caseId).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DSSectionLabel('DEADLINES', trailing: GestureDetector(onTap: onAdd, child: Text('Add', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)))),
            InsetCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (all.isEmpty)
                    InsetRow(
                      icon: CupertinoIcons.calendar_badge_plus,
                      iconColor: AppTheme.textTertiary,
                      title: 'No deadlines yet',
                      subtitle: 'Added automatically when a denial is analysed, or add your own',
                      onTap: onAdd,
                    ),
                  for (final d in all)
                    InsetRow(
                      icon: d.completed ? CupertinoIcons.checkmark_circle_fill : (d.isOverdue ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.clock_fill),
                      iconColor: d.completed ? AppTheme.successColor : (d.isOverdue ? AppTheme.dangerColor : (d.daysLeft <= 7 ? AppTheme.warningColor : AppTheme.primaryColor)),
                      title: d.title,
                      subtitle: DateFormat('EEE d MMM yyyy').format(d.dueDate),
                      value: d.completed ? 'Done' : (d.isOverdue ? 'Overdue' : '${d.daysLeft}d'),
                      onTap: uid == null
                          ? null
                          : () async {
                              final updated = d.copyWith(completed: !d.completed);
                              await db.saveDeadline(uid!, updated);
                              if (updated.completed) {
                                await DeadlineScheduler.cancel(updated);
                              } else {
                                await DeadlineScheduler.schedule(updated);
                              }
                            },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Documents ─────────────────────────────────────────────────────────────────

class _DocumentsSection extends StatelessWidget {
  final Stream<List<ScannedDocument>>? stream;
  final VoidCallback onScan;
  const _DocumentsSection({required this.stream, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScannedDocument>>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data ?? const <ScannedDocument>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DSSectionLabel('DOCUMENTS (${docs.length})', trailing: GestureDetector(onTap: onScan, child: Text('Scan', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13)))),
            if (docs.isEmpty)
              InsetCard(
                onTap: onScan,
                child: Row(children: [
                  IconBadge(CupertinoIcons.doc_on_doc_fill, color: AppTheme.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Scanned bills, statements and letters for this case appear here.', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.35))),
                ]),
              )
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _DocThumb(doc: docs[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DocThumb extends StatelessWidget {
  final ScannedDocument doc;
  const _DocThumb({required this.doc});

  @override
  Widget build(BuildContext context) {
    final local = doc.localPaths.isNotEmpty ? doc.localPaths.first : '';
    final remote = doc.remoteUrls.isNotEmpty ? doc.remoteUrls.first : '';
    final isPdf = local.toLowerCase().endsWith('.pdf') || remote.toLowerCase().contains('.pdf');
    Widget image;
    if (!isPdf && local.isNotEmpty && File(local).existsSync()) {
      image = Image.file(File(local), fit: BoxFit.cover);
    } else if (!isPdf && remote.isNotEmpty) {
      image = Image.network(remote, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else {
      image = _placeholder();
    }
    return DSPressable(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => DocumentViewerScreen(doc: doc))),
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: DS.squircle(DS.rMd),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          boxShadow: DS.softShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          image,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])),
              child: Text(DocType.label(doc.docType), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Center(child: IconBadge(CupertinoIcons.doc_richtext, color: AppTheme.primaryColor, size: 44));
}

/// Full-screen pager over a scanned document's pages.
class DocumentViewerScreen extends StatelessWidget {
  final ScannedDocument doc;
  const DocumentViewerScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final pages = doc.localPaths.isNotEmpty ? doc.localPaths : doc.remoteUrls;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(doc.title.isNotEmpty ? doc.title : DocType.label(doc.docType), style: const TextStyle(fontSize: 15)),
      ),
      body: PageView.builder(
        itemCount: pages.length,
        itemBuilder: (_, i) {
          final p = pages[i];
          if (p.toLowerCase().endsWith('.pdf')) {
            return Center(child: Text('PDF page — open from Files to view.', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))));
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: p.startsWith('http')
                  ? Image.network(p, fit: BoxFit.contain)
                  : Image.file(File(p), fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

// ── Details ───────────────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final InsuranceClaim claim;
  final InsuranceRegion region;
  final String currency;
  const _DetailsSection({required this.claim, required this.region, required this.currency});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Region', '${region.flag} ${region.name} · $currency'),
      ('Patient', claim.patientName),
      ('Insurer', claim.insurer),
      ('Policy / member', claim.policyNumber),
      ('Provider', claim.hospitalName),
      ('Type', claim.caseType),
      ('Dates', [claim.admissionDate, claim.dischargeDate].where((s) => s.isNotEmpty).join(' → ')),
      ('Diagnosis', claim.diagnosis),
      ('Created', DateFormat('d MMM yyyy').format(claim.createdAt)),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSSectionLabel('DETAILS'),
        InsetCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(r.$1, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary))),
                  Expanded(child: Text(r.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        InsetCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your rights in ${region.name}', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(region.keyRights, style: AppTheme.bodySmall.copyWith(height: 1.4)),
            const SizedBox(height: 8),
            Text('Independent dispute body: ${region.ombudsman}', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, height: 1.4)),
          ]),
        ),
      ],
    );
  }
}

// ── Legacy notes (pre-engine AI text) ─────────────────────────────────────────

class _LegacyNotes extends StatelessWidget {
  final InsuranceClaim claim;
  const _LegacyNotes({required this.claim});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (claim.claimReport.isNotEmpty) ('Claim report', claim.claimReport),
      if (claim.auditReport.isNotEmpty) ('Earlier bill audit', claim.auditReport),
      if (claim.disputeLetter.isNotEmpty) ('Earlier dispute letter', claim.disputeLetter),
      if (claim.fightAnalysis.isNotEmpty) ('Earlier rejection analysis', claim.fightAnalysis),
      if (claim.appealLetter.isNotEmpty) ('Earlier appeal letter', claim.appealLetter),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSSectionLabel('EARLIER NOTES'),
        InsetCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (final it in items)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(it.$1, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                  children: [
                    Align(alignment: Alignment.centerLeft, child: SelectableText(it.$2, style: AppTheme.bodySmall.copyWith(height: 1.45))),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
          ]),
        ),
      ],
    );
  }
}
