// ─── Advocate models ──────────────────────────────────────────────────────────
// Structured results of the bill-audit / denial-appeal engine. Field names
// mirror the backend JSON schemas (functions/src/ai/schemas.ts) so a server
// response can be persisted as-is and re-hydrated here.

double _num(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _int(Object? v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

String _str(Object? v) => (v ?? '').toString();

List<String> _strList(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  return const <String>[];
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return const <Map<String, dynamic>>[];
}

DateTime? _date(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

/// Document kinds the scanner understands.
class DocType {
  static const bill = 'bill';
  static const eob = 'eob';
  static const denial = 'denial';
  static const policy = 'policy';
  static const record = 'record';
  static const other = 'other';

  static const all = [bill, eob, denial, policy, record];

  static String label(String t) => switch (t) {
        bill => 'Medical bill',
        eob => 'Insurance statement (EOB)',
        denial => 'Denial letter',
        policy => 'Insurance policy',
        record => 'Medical record',
        _ => 'Document',
      };
}

// ─── BillLineItem ─────────────────────────────────────────────────────────────

class BillLineItem {
  final String code;
  final String codeSystem;
  final String modifier;
  final String description;
  final String dateOfService; // YYYY-MM-DD
  final double quantity;
  final double unitPrice;
  final double amount;
  final String category;

  const BillLineItem({
    this.code = '',
    this.codeSystem = '',
    this.modifier = '',
    this.description = '',
    this.dateOfService = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.amount = 0,
    this.category = 'other',
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'codeSystem': codeSystem,
        'modifier': modifier,
        'description': description,
        'dateOfService': dateOfService,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'amount': amount,
        'category': category,
      };

  factory BillLineItem.fromMap(Map<String, dynamic> m) {
    final qty = _num(m['quantity']);
    final amount = _num(m['amount']);
    final unit = _num(m['unitPrice']);
    return BillLineItem(
      code: _str(m['code']),
      codeSystem: _str(m['codeSystem']),
      modifier: _str(m['modifier']),
      description: _str(m['description']),
      dateOfService: _str(m['dateOfService']),
      quantity: qty <= 0 ? 1 : qty,
      unitPrice: unit > 0 ? unit : (qty > 0 ? amount / qty : amount),
      amount: amount,
      category: _str(m['category']).isEmpty ? 'other' : _str(m['category']),
    );
  }

  static List<BillLineItem> listFrom(Object? raw) =>
      _mapList(raw).map(BillLineItem.fromMap).toList();

  /// One-line human summary used in prompts and legacy text fields.
  String get asText =>
      '${code.isNotEmpty ? '[$code] ' : ''}$description — ${amount.toStringAsFixed(2)}${quantity != 1 ? ' (×${quantity.toStringAsFixed(0)})' : ''}';
}

// ─── AuditFinding / AuditReport ───────────────────────────────────────────────

class FindingStatus {
  static const open = 'open';
  static const disputed = 'disputed';
  static const resolved = 'resolved';
  static const dismissed = 'dismissed';
}

class AuditFinding {
  final String id;
  final String type;
  final String severity; // low | medium | high
  final String title;
  final String explanation;
  final List<String> expenseIds;
  final List<String> lineDescriptions;
  final double amountAtIssue;
  final double estimatedSavingLow;
  final double estimatedSavingHigh;
  final String benchmarkCode;
  final double benchmarkReferencePrice;
  final double benchmarkRatio;
  final String recommendedAction;
  final String disputeParagraph;
  final double confidence;

  // User-tracked lifecycle.
  final String status; // FindingStatus
  final double recoveredAmount;

  const AuditFinding({
    required this.id,
    this.type = 'other',
    this.severity = 'medium',
    this.title = '',
    this.explanation = '',
    this.expenseIds = const [],
    this.lineDescriptions = const [],
    this.amountAtIssue = 0,
    this.estimatedSavingLow = 0,
    this.estimatedSavingHigh = 0,
    this.benchmarkCode = '',
    this.benchmarkReferencePrice = 0,
    this.benchmarkRatio = 0,
    this.recommendedAction = '',
    this.disputeParagraph = '',
    this.confidence = 0,
    this.status = FindingStatus.open,
    this.recoveredAmount = 0,
  });

  bool get isOpen => status == FindingStatus.open || status == FindingStatus.disputed;

  AuditFinding copyWith({String? status, double? recoveredAmount}) => AuditFinding(
        id: id,
        type: type,
        severity: severity,
        title: title,
        explanation: explanation,
        expenseIds: expenseIds,
        lineDescriptions: lineDescriptions,
        amountAtIssue: amountAtIssue,
        estimatedSavingLow: estimatedSavingLow,
        estimatedSavingHigh: estimatedSavingHigh,
        benchmarkCode: benchmarkCode,
        benchmarkReferencePrice: benchmarkReferencePrice,
        benchmarkRatio: benchmarkRatio,
        recommendedAction: recommendedAction,
        disputeParagraph: disputeParagraph,
        confidence: confidence,
        status: status ?? this.status,
        recoveredAmount: recoveredAmount ?? this.recoveredAmount,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'severity': severity,
        'title': title,
        'explanation': explanation,
        'expenseIds': expenseIds,
        'lineDescriptions': lineDescriptions,
        'amountAtIssue': amountAtIssue,
        'estimatedSavingLow': estimatedSavingLow,
        'estimatedSavingHigh': estimatedSavingHigh,
        'benchmarkCode': benchmarkCode,
        'benchmarkReferencePrice': benchmarkReferencePrice,
        'benchmarkRatio': benchmarkRatio,
        'recommendedAction': recommendedAction,
        'disputeParagraph': disputeParagraph,
        'confidence': confidence,
        'status': status,
        'recoveredAmount': recoveredAmount,
      };

  factory AuditFinding.fromMap(Map<String, dynamic> m) => AuditFinding(
        id: _str(m['id']),
        type: _str(m['type']).isEmpty ? 'other' : _str(m['type']),
        severity: _str(m['severity']).isEmpty ? 'medium' : _str(m['severity']),
        title: _str(m['title']),
        explanation: _str(m['explanation']),
        expenseIds: _strList(m['expenseIds']),
        lineDescriptions: _strList(m['lineDescriptions']),
        amountAtIssue: _num(m['amountAtIssue']),
        estimatedSavingLow: _num(m['estimatedSavingLow']),
        estimatedSavingHigh: _num(m['estimatedSavingHigh']),
        benchmarkCode: _str(m['benchmarkCode']),
        benchmarkReferencePrice: _num(m['benchmarkReferencePrice']),
        benchmarkRatio: _num(m['benchmarkRatio']),
        recommendedAction: _str(m['recommendedAction']),
        disputeParagraph: _str(m['disputeParagraph']),
        confidence: _num(m['confidence']),
        status: _str(m['status']).isEmpty ? FindingStatus.open : _str(m['status']),
        recoveredAmount: _num(m['recoveredAmount']),
      );

  static String typeLabel(String t) => switch (t) {
        'duplicate' => 'Duplicate charge',
        'unbundling' => 'Unbundled charges',
        'upcoding' => 'Possible upcoding',
        'quantity' => 'Quantity error',
        'not_received' => 'Service not received',
        'overpriced' => 'Above fair price',
        'facility_fee' => 'Facility fee',
        'balance_billing' => 'Balance billing',
        'not_covered_wrongly' => 'Should be covered',
        'coordination' => 'Coordination of benefits',
        'non_payable_item' => 'Non-payable item',
        'package_rate' => 'Included in package',
        'math_error' => 'Math error',
        _ => 'Billing issue',
      };
}

class AuditReport {
  final String summary;
  final String overallRisk; // low | medium | high
  final List<AuditFinding> findings;
  final double totalSavingLow;
  final double totalSavingHigh;
  final bool itemizedBillMissing;
  final bool charityCareLikely;
  final String charityCareNote;
  final List<String> nextSteps;
  final List<String> questionsForUser;
  final String currency;
  final String model;
  final String promptVersion;
  final DateTime createdAt;

  AuditReport({
    this.summary = '',
    this.overallRisk = 'medium',
    this.findings = const [],
    this.totalSavingLow = 0,
    this.totalSavingHigh = 0,
    this.itemizedBillMissing = false,
    this.charityCareLikely = false,
    this.charityCareNote = '',
    this.nextSteps = const [],
    this.questionsForUser = const [],
    this.currency = '',
    this.model = '',
    this.promptVersion = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  List<AuditFinding> get openFindings => findings.where((f) => f.isOpen).toList();

  double get openSavingHigh =>
      openFindings.fold(0, (s, f) => s + f.estimatedSavingHigh);
  double get openSavingLow =>
      openFindings.fold(0, (s, f) => s + f.estimatedSavingLow);
  double get recovered => findings.fold(0, (s, f) => s + f.recoveredAmount);

  AuditReport copyWith({List<AuditFinding>? findings}) => AuditReport(
        summary: summary,
        overallRisk: overallRisk,
        findings: findings ?? this.findings,
        totalSavingLow: totalSavingLow,
        totalSavingHigh: totalSavingHigh,
        itemizedBillMissing: itemizedBillMissing,
        charityCareLikely: charityCareLikely,
        charityCareNote: charityCareNote,
        nextSteps: nextSteps,
        questionsForUser: questionsForUser,
        currency: currency,
        model: model,
        promptVersion: promptVersion,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'summary': summary,
        'overallRisk': overallRisk,
        'findings': findings.map((f) => f.toMap()).toList(),
        'totalSavingLow': totalSavingLow,
        'totalSavingHigh': totalSavingHigh,
        'itemizedBillMissing': itemizedBillMissing,
        'charityCareLikely': charityCareLikely,
        'charityCareNote': charityCareNote,
        'nextSteps': nextSteps,
        'questionsForUser': questionsForUser,
        'currency': currency,
        'model': model,
        'promptVersion': promptVersion,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuditReport.fromMap(Map<String, dynamic> m, {String currency = '', String model = '', String promptVersion = ''}) =>
      AuditReport(
        summary: _str(m['summary']),
        overallRisk: _str(m['overallRisk']).isEmpty ? 'medium' : _str(m['overallRisk']),
        findings: _mapList(m['findings']).map(AuditFinding.fromMap).toList(),
        totalSavingLow: _num(m['totalSavingLow']),
        totalSavingHigh: _num(m['totalSavingHigh']),
        itemizedBillMissing: m['itemizedBillMissing'] == true,
        charityCareLikely: m['charityCareLikely'] == true,
        charityCareNote: _str(m['charityCareNote']),
        nextSteps: _strList(m['nextSteps']),
        questionsForUser: _strList(m['questionsForUser']),
        currency: _str(m['currency']).isEmpty ? currency : _str(m['currency']),
        model: _str(m['model']).isEmpty ? model : _str(m['model']),
        promptVersion: _str(m['promptVersion']).isEmpty ? promptVersion : _str(m['promptVersion']),
        createdAt: _date(m['createdAt']),
      );
}

// ─── Denial ───────────────────────────────────────────────────────────────────

class DenialInfo {
  final String insurerName;
  final String memberId;
  final String claimNumber;
  final String referenceNumber;
  final String patientName;
  final String providerName;
  final String serviceDescription;
  final String dateOfService;
  final String denialDate; // YYYY-MM-DD
  final double amountDenied;
  final String currency;
  final String reasonCategory;
  final String reasonText;
  final List<String> policyClausesCited;
  final String appealDeadline; // YYYY-MM-DD or ''
  final String appealDeadlineText;
  final List<String> appealLevels;
  final String appealAddress;
  final String appealFax;
  final String appealEmail;
  final String appealPhone;
  final bool externalReviewMentioned;
  final bool isUrgent;
  final String summary;
  final List<String> warnings;
  final String documentId;

  const DenialInfo({
    this.insurerName = '',
    this.memberId = '',
    this.claimNumber = '',
    this.referenceNumber = '',
    this.patientName = '',
    this.providerName = '',
    this.serviceDescription = '',
    this.dateOfService = '',
    this.denialDate = '',
    this.amountDenied = 0,
    this.currency = '',
    this.reasonCategory = 'other',
    this.reasonText = '',
    this.policyClausesCited = const [],
    this.appealDeadline = '',
    this.appealDeadlineText = '',
    this.appealLevels = const [],
    this.appealAddress = '',
    this.appealFax = '',
    this.appealEmail = '',
    this.appealPhone = '',
    this.externalReviewMentioned = false,
    this.isUrgent = false,
    this.summary = '',
    this.warnings = const [],
    this.documentId = '',
  });

  DateTime? get denialDateTime => _date(denialDate);
  DateTime? get appealDeadlineDate => _date(appealDeadline);

  Map<String, dynamic> toMap() => {
        'insurerName': insurerName,
        'memberId': memberId,
        'claimNumber': claimNumber,
        'referenceNumber': referenceNumber,
        'patientName': patientName,
        'providerName': providerName,
        'serviceDescription': serviceDescription,
        'dateOfService': dateOfService,
        'denialDate': denialDate,
        'amountDenied': amountDenied,
        'currency': currency,
        'reasonCategory': reasonCategory,
        'reasonText': reasonText,
        'policyClausesCited': policyClausesCited,
        'appealDeadline': appealDeadline,
        'appealDeadlineText': appealDeadlineText,
        'appealLevels': appealLevels,
        'appealAddress': appealAddress,
        'appealFax': appealFax,
        'appealEmail': appealEmail,
        'appealPhone': appealPhone,
        'externalReviewMentioned': externalReviewMentioned,
        'isUrgent': isUrgent,
        'summary': summary,
        'warnings': warnings,
        'documentId': documentId,
      };

  factory DenialInfo.fromMap(Map<String, dynamic> m) => DenialInfo(
        insurerName: _str(m['insurerName']),
        memberId: _str(m['memberId']),
        claimNumber: _str(m['claimNumber']),
        referenceNumber: _str(m['referenceNumber']),
        patientName: _str(m['patientName']),
        providerName: _str(m['providerName']),
        serviceDescription: _str(m['serviceDescription']),
        dateOfService: _str(m['dateOfService']),
        denialDate: _str(m['denialDate']),
        amountDenied: _num(m['amountDenied']),
        currency: _str(m['currency']),
        reasonCategory: _str(m['reasonCategory']).isEmpty ? 'other' : _str(m['reasonCategory']),
        reasonText: _str(m['reasonText']),
        policyClausesCited: _strList(m['policyClausesCited']),
        appealDeadline: _str(m['appealDeadline']),
        appealDeadlineText: _str(m['appealDeadlineText']),
        appealLevels: _strList(m['appealLevels']),
        appealAddress: _str(m['appealAddress']),
        appealFax: _str(m['appealFax']),
        appealEmail: _str(m['appealEmail']),
        appealPhone: _str(m['appealPhone']),
        externalReviewMentioned: m['externalReviewMentioned'] == true,
        isUrgent: m['isUrgent'] == true,
        summary: _str(m['summary']),
        warnings: _strList(m['warnings']),
        documentId: _str(m['documentId']),
      );

  static String reasonLabel(String c) => switch (c) {
        'medical_necessity' => 'Not medically necessary',
        'prior_authorization' => 'No prior authorization',
        'not_covered' => 'Service not covered',
        'out_of_network' => 'Out of network',
        'coding_error' => 'Coding / billing error',
        'timely_filing' => 'Filed too late',
        'pre_existing' => 'Pre-existing condition',
        'experimental' => 'Experimental / investigational',
        'coordination_of_benefits' => 'Coordination of benefits',
        'eligibility' => 'Eligibility / enrollment',
        'documentation' => 'Missing documentation',
        'waiting_period' => 'Waiting period',
        'sub_limit' => 'Sub-limit / cap reached',
        _ => 'Other reason',
      };
}

class DenialStep {
  final String stage;
  final String action;
  final String deadline;
  final int daysFromDenial;
  const DenialStep({this.stage = '', this.action = '', this.deadline = '', this.daysFromDenial = 0});
  Map<String, dynamic> toMap() => {'stage': stage, 'action': action, 'deadline': deadline, 'daysFromDenial': daysFromDenial};
  factory DenialStep.fromMap(Map<String, dynamic> m) => DenialStep(
        stage: _str(m['stage']),
        action: _str(m['action']),
        deadline: _str(m['deadline']),
        daysFromDenial: _int(m['daysFromDenial']),
      );
}

class DenialArgument {
  final String title;
  final String detail;
  const DenialArgument({this.title = '', this.detail = ''});
  Map<String, dynamic> toMap() => {'title': title, 'detail': detail};
  factory DenialArgument.fromMap(Map<String, dynamic> m) =>
      DenialArgument(title: _str(m['title']), detail: _str(m['detail']));
}

class DenialExplanation {
  final String plainSummary;
  final String whyDenied;
  final bool isDisputable;
  final String strength; // weak | moderate | strong
  final List<DenialArgument> arguments;
  final List<String> evidenceToGather;
  final List<DenialStep> steps;
  final String successEstimate;
  final List<String> questionsForUser;
  final DateTime createdAt;

  DenialExplanation({
    this.plainSummary = '',
    this.whyDenied = '',
    this.isDisputable = false,
    this.strength = 'moderate',
    this.arguments = const [],
    this.evidenceToGather = const [],
    this.steps = const [],
    this.successEstimate = '',
    this.questionsForUser = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'plainSummary': plainSummary,
        'whyDenied': whyDenied,
        'isDisputable': isDisputable,
        'strength': strength,
        'arguments': arguments.map((a) => a.toMap()).toList(),
        'evidenceToGather': evidenceToGather,
        'steps': steps.map((s) => s.toMap()).toList(),
        'successEstimate': successEstimate,
        'questionsForUser': questionsForUser,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DenialExplanation.fromMap(Map<String, dynamic> m) => DenialExplanation(
        plainSummary: _str(m['plainSummary']),
        whyDenied: _str(m['whyDenied']),
        isDisputable: m['isDisputable'] == true,
        strength: _str(m['strength']).isEmpty ? 'moderate' : _str(m['strength']),
        arguments: _mapList(m['arguments']).map(DenialArgument.fromMap).toList(),
        evidenceToGather: _strList(m['evidenceToGather']),
        steps: _mapList(m['steps']).map(DenialStep.fromMap).toList(),
        successEstimate: _str(m['successEstimate']),
        questionsForUser: _strList(m['questionsForUser']),
        createdAt: _date(m['createdAt']),
      );
}

// ─── GeneratedLetter ──────────────────────────────────────────────────────────

class LetterKind {
  static const appeal = 'appeal';
  static const dispute = 'dispute';
  static const itemizedRequest = 'itemized_request';
  static const charityCare = 'charity_care';
  static const medicalNecessity = 'medical_necessity';
  static const regulatorComplaint = 'regulator_complaint';
  static const ombudsmanComplaint = 'ombudsman_complaint';
  static const recordsRequest = 'records_request';

  static String label(String k) => switch (k) {
        appeal => 'Appeal letter',
        dispute => 'Bill dispute letter',
        itemizedRequest => 'Itemized bill request',
        charityCare => 'Financial assistance request',
        medicalNecessity => 'Letter of medical necessity',
        regulatorComplaint => 'Regulator complaint',
        ombudsmanComplaint => 'Ombudsman complaint',
        recordsRequest => 'Records request',
        _ => 'Letter',
      };

  static String recipient(String k) => switch (k) {
        appeal || recordsRequest => 'to your insurer',
        dispute || itemizedRequest || charityCare => 'to the provider / hospital',
        medicalNecessity => 'for your doctor to sign',
        regulatorComplaint => 'to the regulator',
        ombudsmanComplaint => 'to the ombudsman',
        _ => '',
      };
}

class GeneratedLetter {
  final String id;
  final String kind;
  final String subject;
  final String recipientBlock;
  final String body;
  final List<String> checklist;
  final List<String> sendingTips;
  final String deadlineNote;
  final String status; // draft | sent
  final DateTime createdAt;
  final DateTime? sentAt;

  GeneratedLetter({
    required this.id,
    required this.kind,
    this.subject = '',
    this.recipientBlock = '',
    this.body = '',
    this.checklist = const [],
    this.sendingTips = const [],
    this.deadlineNote = '',
    this.status = 'draft',
    DateTime? createdAt,
    this.sentAt,
  }) : createdAt = createdAt ?? DateTime.now();

  GeneratedLetter copyWith({String? body, String? status, DateTime? sentAt, String? subject}) => GeneratedLetter(
        id: id,
        kind: kind,
        subject: subject ?? this.subject,
        recipientBlock: recipientBlock,
        body: body ?? this.body,
        checklist: checklist,
        sendingTips: sendingTips,
        deadlineNote: deadlineNote,
        status: status ?? this.status,
        createdAt: createdAt,
        sentAt: sentAt ?? this.sentAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'subject': subject,
        'recipientBlock': recipientBlock,
        'body': body,
        'checklist': checklist,
        'sendingTips': sendingTips,
        'deadlineNote': deadlineNote,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
      };

  factory GeneratedLetter.fromMap(Map<String, dynamic> m) => GeneratedLetter(
        id: _str(m['id']),
        kind: _str(m['kind']).isEmpty ? LetterKind.appeal : _str(m['kind']),
        subject: _str(m['subject']),
        recipientBlock: _str(m['recipientBlock']),
        body: _str(m['body']),
        checklist: _strList(m['checklist']),
        sendingTips: _strList(m['sendingTips']),
        deadlineNote: _str(m['deadlineNote']),
        status: _str(m['status']).isEmpty ? 'draft' : _str(m['status']),
        createdAt: _date(m['createdAt']),
        sentAt: _date(m['sentAt']),
      );

  static List<GeneratedLetter> listFrom(Object? raw) =>
      _mapList(raw).map(GeneratedLetter.fromMap).toList();
}

// ─── CaseDeadline ─────────────────────────────────────────────────────────────

/// A dated obligation on a case (appeal due, follow-up, external review…).
/// Stored in `users/{uid}/deadlines` so Home can query across cases.
class CaseDeadline {
  final String id;
  final String caseId;
  final String caseTitle;
  final String title;
  final String stage;
  final DateTime dueDate;
  final bool completed;
  final String source; // denial | audit | manual
  final DateTime createdAt;

  CaseDeadline({
    required this.id,
    required this.caseId,
    this.caseTitle = '',
    required this.title,
    this.stage = '',
    required this.dueDate,
    this.completed = false,
    this.source = 'manual',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get daysLeft => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => !completed && dueDate.isBefore(DateTime.now());

  CaseDeadline copyWith({bool? completed, DateTime? dueDate, String? title}) => CaseDeadline(
        id: id,
        caseId: caseId,
        caseTitle: caseTitle,
        title: title ?? this.title,
        stage: stage,
        dueDate: dueDate ?? this.dueDate,
        completed: completed ?? this.completed,
        source: source,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'caseId': caseId,
        'caseTitle': caseTitle,
        'title': title,
        'stage': stage,
        'dueDate': dueDate.toIso8601String(),
        'completed': completed,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CaseDeadline.fromMap(Map<String, dynamic> m) => CaseDeadline(
        id: _str(m['id']),
        caseId: _str(m['caseId']),
        caseTitle: _str(m['caseTitle']),
        title: _str(m['title']),
        stage: _str(m['stage']),
        dueDate: _date(m['dueDate']) ?? DateTime.now(),
        completed: m['completed'] == true,
        source: _str(m['source']).isEmpty ? 'manual' : _str(m['source']),
        createdAt: _date(m['createdAt']),
      );
}

// ─── ScannedDocument ──────────────────────────────────────────────────────────

/// Any document the user scanned (bill, EOB, denial, policy, record) with
/// its extracted data. Bills/denials also get attached to a case; records go
/// to the vault. Stored in `users/{uid}/documents`.
class ScannedDocument {
  final String id;
  final String userId;
  final String docType;
  final String title;
  final String caseId;
  final List<String> localPaths;
  final List<String> remoteUrls;
  final bool isSynced;
  final Map<String, dynamic> data;
  final String summary;
  final double confidence;
  final List<String> warnings;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScannedDocument({
    required this.id,
    required this.userId,
    required this.docType,
    this.title = '',
    this.caseId = '',
    this.localPaths = const [],
    this.remoteUrls = const [],
    this.isSynced = false,
    this.data = const {},
    this.summary = '',
    this.confidence = 0,
    this.warnings = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ScannedDocument copyWith({
    String? title,
    String? caseId,
    List<String>? localPaths,
    List<String>? remoteUrls,
    bool? isSynced,
    Map<String, dynamic>? data,
    DateTime? updatedAt,
  }) =>
      ScannedDocument(
        id: id,
        userId: userId,
        docType: docType,
        title: title ?? this.title,
        caseId: caseId ?? this.caseId,
        localPaths: localPaths ?? this.localPaths,
        remoteUrls: remoteUrls ?? this.remoteUrls,
        isSynced: isSynced ?? this.isSynced,
        data: data ?? this.data,
        summary: summary,
        confidence: confidence,
        warnings: warnings,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'docType': docType,
        'title': title,
        'caseId': caseId,
        'localPaths': localPaths,
        'remoteUrls': remoteUrls,
        'isSynced': isSynced,
        'data': data,
        'summary': summary,
        'confidence': confidence,
        'warnings': warnings,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScannedDocument.fromMap(Map<String, dynamic> m) => ScannedDocument(
        id: _str(m['id']),
        userId: _str(m['userId']),
        docType: _str(m['docType']).isEmpty ? DocType.other : _str(m['docType']),
        title: _str(m['title']),
        caseId: _str(m['caseId']),
        localPaths: _strList(m['localPaths']),
        remoteUrls: _strList(m['remoteUrls']),
        isSynced: m['isSynced'] == true,
        data: m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : const {},
        summary: _str(m['summary']),
        confidence: _num(m['confidence']),
        warnings: _strList(m['warnings']),
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );
}

/// Case outcome states shown on the case card and summed on Home.
class OutcomeStatus {
  static const open = 'open';
  static const won = 'won';
  static const partial = 'partial';
  static const lost = 'lost';
  static const withdrawn = 'withdrawn';

  static String label(String s) => switch (s) {
        won => 'Won',
        partial => 'Partially won',
        lost => 'Lost',
        withdrawn => 'Withdrawn',
        _ => 'In progress',
      };
}
