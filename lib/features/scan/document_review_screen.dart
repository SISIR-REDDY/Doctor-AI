import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../../services/ai/ai_service.dart';
import '../../services/analytics_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../theme/ios18_components.dart';
import '../insurance/add_policy_screen.dart';

/// Shows what the AI extracted, lets the user correct the essentials, and
/// saves it to the right place (case / vault / policies).
class DocumentReviewScreen extends StatefulWidget {
  final AnalyzeResult result;
  final List<String> pagePaths;
  final String requestedType;
  final String? caseId;

  const DocumentReviewScreen({
    super.key,
    required this.result,
    required this.pagePaths,
    required this.requestedType,
    this.caseId,
  });

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen> {
  final _db = FirestoreService();
  final _storage = StorageService();
  bool _saving = false;

  late String _docType = widget.result.documentType;
  late final Map<String, dynamic> _d = widget.result.data;

  // Editable essentials.
  late final TextEditingController _title = TextEditingController(text: _defaultTitle());
  late final TextEditingController _amount = TextEditingController(text: _primaryAmount() > 0 ? _fmtNum(_primaryAmount()) : '');
  late final TextEditingController _party = TextEditingController(text: _primaryParty());

  String _str(String k) => (_d[k] ?? '').toString();
  double _num(String k) => (_d[k] is num) ? (_d[k] as num).toDouble() : double.tryParse('${_d[k] ?? ''}') ?? 0;
  List<String> _list(String k) => (_d[k] is List) ? (_d[k] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

  static String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double _primaryAmount() => switch (_docType) {
        DocType.bill => _num('totalBilled'),
        DocType.eob => _num('totalPatientResponsibility'),
        DocType.denial => _num('amountDenied'),
        DocType.policy => _num('coverageAmount'),
        _ => 0,
      };

  String _primaryParty() => switch (_docType) {
        DocType.bill => _str('providerName'),
        DocType.eob || DocType.denial || DocType.policy => _str('insurerName'),
        DocType.record => _str('providerName'),
        _ => '',
      };

  String _defaultTitle() {
    final date = _str('dateOfService').isNotEmpty
        ? _str('dateOfService')
        : _str('denialDate').isNotEmpty
            ? _str('denialDate')
            : _str('date');
    String pretty(String iso) {
      final dt = DateTime.tryParse(iso);
      return dt == null ? '' : DateFormat('d MMM yyyy').format(dt);
    }
    final party = _primaryParty();
    switch (_docType) {
      case DocType.bill:
        return [if (party.isNotEmpty) party, if (pretty(date).isNotEmpty) pretty(date)].join(' · ');
      case DocType.eob:
        return 'EOB${party.isNotEmpty ? ' — $party' : ''}${pretty(date).isNotEmpty ? ' · ${pretty(date)}' : ''}';
      case DocType.denial:
        final svc = _str('serviceDescription');
        return 'Denial${svc.isNotEmpty ? ' — $svc' : party.isNotEmpty ? ' — $party' : ''}';
      case DocType.policy:
        return [_str('insurerName'), _str('planName')].where((s) => s.isNotEmpty).join(' — ');
      case DocType.record:
        return _str('title').isNotEmpty ? _str('title') : 'Medical record';
      default:
        return 'Document';
    }
  }

  String get _currency {
    final c = _str('currency');
    if (c.isNotEmpty) return c;
    final profile = context.read<HealthDataProvider>().profile;
    return regionByCode(profile?.country).currencyCode;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _party.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    final provider = context.read<HealthDataProvider>();
    final uid = provider.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      switch (_docType) {
        case DocType.bill:
          await _saveBill(uid, provider.profile);
        case DocType.eob:
          await _saveEob(uid, provider.profile);
        case DocType.denial:
          await _saveDenial(uid, provider.profile);
        case DocType.policy:
          await _savePolicy(uid, provider.profile);
        case DocType.record:
          await _saveRecord(uid);
        default:
          await _saveRecord(uid);
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Persists pages locally + cloud and writes the ScannedDocument row.
  Future<ScannedDocument> _persistDocument(String uid, {String caseId = ''}) async {
    final id = const Uuid().v4();
    final saved = await _storage.saveDocumentImages(filePaths: widget.pagePaths, patientId: uid, recordId: id);
    final local = saved.localPaths.isNotEmpty ? saved.localPaths : widget.pagePaths;
    final doc = ScannedDocument(
      id: id,
      userId: uid,
      docType: _docType,
      title: _title.text.trim(),
      caseId: caseId,
      localPaths: local,
      remoteUrls: saved.remoteUrls,
      isSynced: saved.remoteUrls.length >= local.length,
      data: _d,
      summary: _str('summary'),
      confidence: _num('confidence'),
      warnings: _list('warnings'),
    );
    await _db.saveDocument(uid, doc);
    return doc;
  }

  Future<InsuranceClaim?> _pickCase(String uid, {required String purpose}) async {
    if (widget.caseId != null) {
      final claims = await _db.watchClaims(uid).first;
      final existing = claims.where((c) => c.id == widget.caseId).firstOrNull;
      if (existing != null) return existing;
    }
    final claims = (await _db.watchClaims(uid).first).where((c) => !c.isClosed).toList();
    if (!mounted) return null;
    if (claims.isEmpty) return _newCase(uid);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CasePickerSheet(claims: claims, purpose: purpose),
    );
    if (choice == null) return null;
    if (choice == '__new__') return _newCase(uid);
    return claims.firstWhere((c) => c.id == choice);
  }

  InsuranceClaim _newCase(String uid) {
    final profile = context.read<HealthDataProvider>().profile;
    final region = regionByCode(profile?.country);
    final caseType = _str('caseType');
    return InsuranceClaim(
      id: const Uuid().v4(),
      userId: uid,
      title: _title.text.trim(),
      country: profile?.country.isNotEmpty == true ? profile!.country : region.code,
      currencyCode: _currency,
      caseType: caseType == 'inpatient' ? 'inpatient' : 'outpatient',
      hospitalName: _docType == DocType.bill ? _party.text.trim() : _str('providerName'),
      insurer: _docType == DocType.bill ? '' : _party.text.trim(),
      policyNumber: _str('memberId'),
      admissionDate: _str('dateOfService'),
      dischargeDate: _str('dateOfServiceEnd'),
      diagnosis: _list('diagnoses').join(', '),
      claimStatus: _docType == DocType.denial ? 'rejected' : 'pending',
      patientName: _familyPatientName(profile),
    );
  }

  /// Family mode: keep the patient named on the document when it is not the
  /// account holder, so letters and packets name the right person.
  String _familyPatientName(PatientProfile? profile) {
    if (profile == null || !profile.familyMode) return '';
    final name = _str('patientName').trim();
    if (name.isEmpty) return '';
    final first = profile.firstName.trim().toLowerCase();
    if (first.isNotEmpty && name.toLowerCase().contains(first)) return '';
    return name;
  }

  Future<void> _saveBill(String uid, PatientProfile? profile) async {
    final target = await _pickCase(uid, purpose: 'Add this bill to');
    if (target == null) return;
    final doc = await _persistDocument(uid, caseId: target.id);
    final items = BillLineItem.listFrom(_d['lineItems']);
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? _num('totalBilled');
    final category = switch (_str('caseType')) {
      'pharmacy' => 'pharmacy',
      'emergency' || 'inpatient' => 'hospital',
      'dental' => 'other',
      _ => items.any((i) => i.category == 'lab') && items.every((i) => i.category == 'lab') ? 'lab' : 'hospital',
    };
    final expense = CaseExpense(
      id: const Uuid().v4(),
      category: category,
      vendor: _party.text.trim(),
      date: _prettyDate(_str('dateOfService')),
      amount: amount,
      documentUrl: doc.remoteUrls.isNotEmpty ? doc.remoteUrls.first : '',
      imagePath: doc.localPaths.isNotEmpty ? doc.localPaths.first : '',
      note: _str('accountNumber').isNotEmpty ? 'Account ${_str('accountNumber')}' : '',
      lineItems: items.map((i) => i.asText).join('\n'),
      aiExtracted: true,
      items: items,
      documentId: doc.id,
    );
    final updated = target.copyWith(
      expenses: [...target.expenses, expense],
      documentIds: [...target.documentIds, doc.id],
      hospitalName: target.hospitalName.isEmpty ? _party.text.trim() : null,
      currencyCode: target.currencyCode.isEmpty ? _currency : null,
      claimAmount: target.claimAmount == 0 ? amount : null,
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    Analytics.log('bill_added', {'items': items.length, 'new_case': target.expenses.isEmpty ? 1 : 0});
    if (!mounted) return;
    _finish(updated, hint: 'Bill added. Run the audit to find errors and overcharges.');
  }

  Future<void> _saveEob(String uid, PatientProfile? profile) async {
    final target = await _pickCase(uid, purpose: 'Attach this statement to');
    if (target == null) return;
    final doc = await _persistDocument(uid, caseId: target.id);
    final updated = target.copyWith(
      eob: _d,
      insurer: target.insurer.isEmpty ? _party.text.trim() : null,
      policyNumber: target.policyNumber.isEmpty ? _str('memberId') : null,
      documentIds: [...target.documentIds, doc.id],
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    if (!mounted) return;
    _finish(updated, hint: 'Statement attached. The audit will now check for balance billing and coverage errors.');
  }

  Future<void> _saveDenial(String uid, PatientProfile? profile) async {
    final target = await _pickCase(uid, purpose: 'Attach this denial to');
    if (target == null) return;
    final doc = await _persistDocument(uid, caseId: target.id);
    final denial = DenialInfo.fromMap({..._d, 'documentId': doc.id, 'insurerName': _party.text.trim()});
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    final updated = target.copyWith(
      denial: amount != null && amount > 0 ? DenialInfo.fromMap({...denial.toMap(), 'amountDenied': amount}) : denial,
      insurer: target.insurer.isEmpty ? _party.text.trim() : null,
      policyNumber: target.policyNumber.isEmpty ? denial.memberId : null,
      rejectionReason: denial.reasonText,
      claimStatus: 'rejected',
      diagnosis: target.diagnosis.isEmpty ? denial.serviceDescription : null,
      documentIds: [...target.documentIds, doc.id],
      claimAmount: target.claimAmount == 0 ? denial.amountDenied : null,
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    Analytics.log('denial_added', {'reason': denial.reasonCategory});
    if (!mounted) return;
    _finish(updated, hint: 'Denial saved. Next: let Clinix explain it and plan the appeal.');
  }

  Future<void> _savePolicy(String uid, PatientProfile? profile) async {
    final doc = await _persistDocument(uid);
    final region = regionByCode(profile?.country);
    final extras = <String>[
      if (_str('summary').isNotEmpty) _str('summary'),
    ];
    final type = _str('policyType');
    final policy = InsurancePolicy(
      id: const Uuid().v4(),
      userId: uid,
      insurer: _party.text.trim(),
      policyNumber: _str('policyNumber').isNotEmpty ? _str('policyNumber') : _str('memberId'),
      policyType: const ['health', 'term', 'critical_illness', 'accidental', 'other'].contains(type) ? type : (type == 'life' ? 'term' : 'health'),
      country: _str('country').length == 2 ? _str('country').toUpperCase() : region.code,
      currencyCode: _currency,
      coverageAmount: double.tryParse(_amount.text.replaceAll(',', '')) ?? _num('coverageAmount'),
      premiumAmount: _num('premiumAmount'),
      premiumFrequency: switch (_str('premiumFrequency')) { 'monthly' => 'monthly', 'quarterly' => 'quarterly', _ => 'annual' },
      startDate: _str('startDate'),
      renewalDate: _str('renewalDate'),
      nomineeName: _str('beneficiaryName'),
      documentUrl: doc.remoteUrls.isNotEmpty ? doc.remoteUrls.first : '',
      notes: extras.join('\n'),
      planName: _str('planName'),
      memberId: _str('memberId'),
      groupNumber: _str('groupNumber'),
      deductibleIndividual: _num('deductibleIndividual'),
      deductibleFamily: _num('deductibleFamily'),
      outOfPocketMaxIndividual: _num('outOfPocketMaxIndividual'),
      outOfPocketMaxFamily: _num('outOfPocketMaxFamily'),
      copayPrimaryCare: _num('copayPrimaryCare'),
      copaySpecialist: _num('copaySpecialist'),
      copayEmergency: _num('copayEmergency'),
      coinsurancePercent: _num('coinsurancePercent'),
      networkType: _str('networkType'),
      exclusions: _list('exclusions'),
      waitingPeriods: _list('waitingPeriods'),
      documentId: doc.id,
    );
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop(true);
    nav.push(CupertinoPageRoute(builder: (_) => AddPolicyScreen(existingPolicy: policy)));
  }

  Future<void> _saveRecord(String uid) async {
    final id = const Uuid().v4();
    final saved = await _storage.saveDocumentImages(filePaths: widget.pagePaths, patientId: uid, recordId: id);
    final local = saved.localPaths.isNotEmpty ? saved.localPaths : widget.pagePaths;
    final type = _str('recordType');
    final keyValues = _str('keyValues');
    final abnormal = _list('abnormalFindings');
    final record = MedicalRecord(
      id: id,
      userId: uid,
      title: _title.text.trim().isEmpty ? 'Medical record' : _title.text.trim(),
      recordType: const ['lab', 'imaging', 'prescription', 'discharge', 'vaccination', 'other'].contains(type) ? type : 'other',
      imagePath: local.first,
      imageUrl: saved.remoteUrls.isNotEmpty ? saved.remoteUrls.first : '',
      imageUrls: saved.remoteUrls.isNotEmpty ? saved.remoteUrls : local,
      localImagePaths: local,
      isSynced: saved.remoteUrls.length >= local.length,
      aiSummary: _str('summary'),
      extractedText: [
        if (keyValues.isNotEmpty) keyValues,
        if (abnormal.isNotEmpty) 'Flagged: ${abnormal.join('; ')}',
        if (_list('followUps').isNotEmpty) 'Follow-up: ${_list('followUps').join('; ')}',
      ].join('\n'),
      isProcessed: true,
      doctorName: '',
      hospitalName: _party.text.trim(),
      recordDate: DateTime.tryParse(_str('date')),
    );
    await _db.saveMedicalRecord(uid, record);
    Analytics.log('record_added', {'type': record.recordType});
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop(true);
    nav.pushNamed(AppRouter.recordDetail, arguments: record);
  }

  void _finish(InsuranceClaim claim, {required String hint}) {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    nav.pop(true);
    nav.pushNamed(AppRouter.claimDetail, arguments: claim);
    messenger?.showSnackBar(SnackBar(content: Text(hint), duration: const Duration(seconds: 4)));
  }

  static String _prettyDate(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat('dd MMM yyyy').format(dt);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final warnings = _list('warnings');
    final confidence = _num('confidence');
    final lowConfidence = confidence > 0 && confidence < 0.6;
    final detected = widget.requestedType == 'auto';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: AppTheme.textPrimary),
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        title: Text('Review', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  _TypeHeader(
                    docType: _docType,
                    detected: detected,
                    confidence: confidence,
                    onChange: (t) => setState(() => _docType = t),
                  ),
                  const SizedBox(height: 16),
                  if (lowConfidence || warnings.isNotEmpty)
                    _Notice(
                      color: AppTheme.warningColor,
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      title: lowConfidence ? 'Some parts were hard to read' : 'Please double-check',
                      lines: warnings.isEmpty ? const ['Check the amounts and names below before saving.'] : warnings.take(4).toList(),
                    ),
                  if (_str('summary').isNotEmpty) ...[
                    const DSSectionLabel('WHAT THIS SAYS'),
                    InsetCard(
                      child: Text(_str('summary'),
                          style: AppTheme.bodyMedium.copyWith(height: 1.45)),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const DSSectionLabel('KEY DETAILS'),
                  InsetCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _party,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                              labelText: _docType == DocType.bill || _docType == DocType.record ? 'Provider' : 'Insurer'),
                        ),
                        if (_docType != DocType.record) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: switch (_docType) {
                                DocType.bill => 'Total billed',
                                DocType.eob => 'You owe (patient responsibility)',
                                DocType.denial => 'Amount denied',
                                DocType.policy => 'Coverage amount',
                                _ => 'Amount',
                              },
                              prefixText: '$_currency ',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._typeSpecific(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: AppTheme.dividerColor)),
              ),
              child: HeroButton(
                label: switch (_docType) {
                  DocType.bill => 'Save bill to a case',
                  DocType.eob => 'Attach to a case',
                  DocType.denial => 'Save & plan the appeal',
                  DocType.policy => 'Continue to policy details',
                  _ => 'Save to records',
                },
                icon: CupertinoIcons.checkmark_alt,
                loading: _saving,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeSpecific() {
    switch (_docType) {
      case DocType.bill:
        final items = BillLineItem.listFrom(_d['lineItems']);
        return [
          DSSectionLabel('LINE ITEMS (${items.length})'),
          if (items.isEmpty)
            _Notice(
              color: AppTheme.infoColor,
              icon: CupertinoIcons.info_circle_fill,
              title: 'No itemized charges found',
              lines: const ['Audits work best with an itemized bill. You can request one from the provider — Clinix can draft that letter.'],
            )
          else
            InsetCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.description,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                Text(
                                  [
                                    if (it.code.isNotEmpty) it.code,
                                    if (it.dateOfService.isNotEmpty) _prettyDate(it.dateOfService),
                                    if (it.quantity != 1) '×${_fmtNum(it.quantity)}',
                                  ].join(' · '),
                                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(formatMoney(it.amount, _currency),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _kv([
            ('Date of service', _prettyDate(_str('dateOfService'))),
            ('Account', _str('accountNumber')),
            ('Insurance paid', _num('insurancePaid') > 0 ? formatMoney(_num('insurancePaid'), _currency) : ''),
            ('Patient responsibility', _num('patientResponsibility') > 0 ? formatMoney(_num('patientResponsibility'), _currency) : ''),
            ('Diagnoses', _list('diagnoses').join(', ')),
          ]),
        ];
      case DocType.eob:
        return [
          _kv([
            ('Claim number', _str('claimNumber')),
            ('Member ID', _str('memberId')),
            ('Provider', _str('providerName')),
            ('Date of service', _prettyDate(_str('dateOfService'))),
            ('Network', _str('networkStatus').replaceAll('_', ' ')),
            ('Billed', formatMoney(_num('totalBilled'), _currency)),
            ('Allowed', _num('totalAllowed') > 0 ? formatMoney(_num('totalAllowed'), _currency) : ''),
            ('Plan paid', _num('totalPlanPaid') > 0 ? formatMoney(_num('totalPlanPaid'), _currency) : ''),
            ('Deductible remaining', _num('deductibleRemaining') > 0 ? formatMoney(_num('deductibleRemaining'), _currency) : ''),
            ('Appeal deadline', _prettyDate(_str('appealDeadline'))),
          ]),
          if (_list('denialReasons').isNotEmpty) ...[
            const SizedBox(height: 18),
            const DSSectionLabel('REASONS GIVEN'),
            InsetCard(child: Text(_list('denialReasons').join('\n\n'), style: AppTheme.bodyMedium.copyWith(height: 1.4))),
          ],
        ];
      case DocType.denial:
        return [
          _kv([
            ('Reason', DenialInfo.reasonLabel(_str('reasonCategory'))),
            ('Service', _str('serviceDescription')),
            ('Provider', _str('providerName')),
            ('Claim number', _str('claimNumber')),
            ('Member ID', _str('memberId')),
            ('Date of service', _prettyDate(_str('dateOfService'))),
            ('Denial date', _prettyDate(_str('denialDate'))),
            ('Appeal deadline', _str('appealDeadline').isNotEmpty ? _prettyDate(_str('appealDeadline')) : _str('appealDeadlineText')),
            ('Urgent', _d['isUrgent'] == true ? 'Yes — expedited appeal available' : ''),
          ]),
          if (_str('reasonText').isNotEmpty) ...[
            const SizedBox(height: 18),
            const DSSectionLabel('INSURER’S WORDING'),
            InsetCard(child: Text(_str('reasonText'), style: AppTheme.bodyMedium.copyWith(height: 1.4))),
          ],
        ];
      case DocType.policy:
        return [
          _kv([
            ('Plan', _str('planName')),
            ('Policy number', _str('policyNumber')),
            ('Member ID', _str('memberId')),
            ('Type', _str('policyType')),
            ('Deductible', _num('deductibleIndividual') > 0 ? formatMoney(_num('deductibleIndividual'), _currency) : ''),
            ('Out-of-pocket max', _num('outOfPocketMaxIndividual') > 0 ? formatMoney(_num('outOfPocketMaxIndividual'), _currency) : ''),
            ('Coinsurance', _num('coinsurancePercent') > 0 ? '${_fmtNum(_num('coinsurancePercent'))}%' : ''),
            ('Renewal', _prettyDate(_str('renewalDate'))),
          ]),
        ];
      default:
        return [
          _kv([
            ('Type', _str('recordType')),
            ('Date', _prettyDate(_str('date'))),
          ]),
          if (_list('abnormalFindings').isNotEmpty) ...[
            const SizedBox(height: 18),
            const DSSectionLabel('FLAGGED VALUES'),
            InsetCard(child: Text(_list('abnormalFindings').join('\n'), style: AppTheme.bodyMedium.copyWith(height: 1.4))),
          ],
          if (_str('keyValues').isNotEmpty) ...[
            const SizedBox(height: 18),
            const DSSectionLabel('VALUES'),
            InsetCard(child: Text(_str('keyValues'), style: AppTheme.bodySmall.copyWith(height: 1.5, fontFamily: 'monospace'))),
          ],
        ];
    }
  }

  Widget _kv(List<(String, String)> rows) {
    final visible = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return InsetCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(visible[i].$1, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                  ),
                  Expanded(
                    child: Text(visible[i].$2,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _TypeHeader extends StatelessWidget {
  final String docType;
  final bool detected;
  final double confidence;
  final ValueChanged<String> onChange;
  const _TypeHeader({required this.docType, required this.detected, required this.confidence, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (docType) {
      DocType.bill => (CupertinoIcons.doc_text_fill, AppTheme.dangerColor),
      DocType.eob => (CupertinoIcons.creditcard_fill, AppTheme.infoColor),
      DocType.denial => (CupertinoIcons.xmark_shield_fill, AppTheme.warningColor),
      DocType.policy => (CupertinoIcons.shield_lefthalf_fill, AppTheme.secondaryColor),
      _ => (CupertinoIcons.lab_flask_solid, AppTheme.successColor),
    };
    return Row(
      children: [
        IconBadge(icon, color: color, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DocType.label(docType), style: AppTheme.headingMedium),
              Text(
                detected
                    ? 'Detected automatically${confidence > 0 ? ' · ${(confidence * 100).round()}% sure' : ''}'
                    : 'Extracted from ${DocType.label(docType).toLowerCase()}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            final t = await showCupertinoModalPopup<String>(
              context: context,
              builder: (ctx) => CupertinoActionSheet(
                title: const Text('This is a…'),
                actions: [
                  for (final t in DocType.all)
                    CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, t), child: Text(DocType.label(t))),
                ],
                cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ),
            );
            if (t != null) onChange(t);
          },
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;
  const _Notice({required this.color, required this.icon, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark ? 0.18 : 0.10),
        borderRadius: DS.squircle(DS.rMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13.5)),
                const SizedBox(height: 3),
                for (final l in lines)
                  Text('• $l', style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CasePickerSheet extends StatelessWidget {
  final List<InsuranceClaim> claims;
  final String purpose;
  const _CasePickerSheet({required this.claims, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: DS.squircle(DS.rXl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Text(purpose, style: AppTheme.headingMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  ChoiceCard(
                    leading: IconBadge(CupertinoIcons.plus, color: AppTheme.primaryColor),
                    title: 'New case',
                    subtitle: 'Start a fresh case for this document',
                    selected: false,
                    onTap: () => Navigator.pop(context, '__new__'),
                  ),
                  const SizedBox(height: 8),
                  for (final c in claims)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChoiceCard(
                        leading: IconBadge(CupertinoIcons.briefcase_fill, color: AppTheme.secondaryColor),
                        title: c.title.isNotEmpty ? c.title : (c.hospitalName.isNotEmpty ? c.hospitalName : c.insurer),
                        subtitle: '${c.expenses.length} ${c.expenses.length == 1 ? 'bill' : 'bills'} · ${c.nextAction}',
                        selected: false,
                        onTap: () => Navigator.pop(context, c.id),
                      ),
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
