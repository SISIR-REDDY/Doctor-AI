import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../features/deadlines/deadlines_screen.dart' show DeadlineScheduler;
import '../../models/advocate_models.dart';
import '../../models/patient_models.dart';
import '../ai/ai_service.dart';
import '../analytics_service.dart';
import '../firebase/firestore_service.dart';

/// Orchestrates the advocate engine for one case: audit → findings,
/// denial → explanation + deadlines, letters. Every method persists the
/// updated case and returns it.
class AdvocateService {
  AdvocateService({FirestoreService? db, AiService? ai})
      : _db = db ?? FirestoreService(),
        _ai = ai ?? AiService.instance;

  final FirestoreService _db;
  final AiService _ai;
  final _uuid = const Uuid();

  // ── Audit ──────────────────────────────────────────────────────────────────

  Future<InsuranceClaim> runAudit({
    required String uid,
    required InsuranceClaim claim,
    PatientProfile? profile,
    List<InsurancePolicy> policies = const [],
    String userNotes = '',
  }) async {
    final region = regionByCode(claim.country.isNotEmpty ? claim.country : profile?.country);
    final currency = claim.currencyCode.isNotEmpty ? claim.currencyCode : region.currencyCode;
    final policy = _matchPolicy(claim, policies);

    final payload = {
      'region': region.code,
      'currency': currency,
      'caseType': claim.caseType,
      'diagnosis': claim.diagnosis,
      'providerName': claim.hospitalName,
      'setting': claim.caseType == 'inpatient' ? 'hospital' : 'unknown',
      'expenses': [
        for (final e in claim.expenses)
          {
            'id': e.id,
            'vendor': e.vendor,
            'date': e.date,
            'category': e.category,
            'amount': e.amount,
            'note': e.note,
            'lineItems': e.items.map((i) => i.toMap()).toList(),
            'lineItemsText': e.items.isEmpty ? e.lineItems : '',
          },
      ],
      if (claim.eob.isNotEmpty) 'eob': claim.eob,
      if (policy != null) 'policy': _policySummary(policy),
      'userNotes': userNotes,
    };

    final res = await _ai.auditBills(payload);
    final report = AuditReport.fromMap(
      Map<String, dynamic>.from(res['report'] as Map? ?? const {}),
      currency: '${res['currency'] ?? currency}',
      model: '${res['model'] ?? ''}',
      promptVersion: '${res['promptVersion'] ?? ''}',
    );

    // Carry over lifecycle state for findings the user already acted on.
    final previous = {for (final f in claim.audit?.findings ?? const <AuditFinding>[]) f.title.toLowerCase(): f};
    final merged = report.findings.map((f) {
      final old = previous[f.title.toLowerCase()];
      return old == null ? f : f.copyWith(status: old.status, recoveredAmount: old.recoveredAmount);
    }).toList();

    final updated = claim.copyWith(
      audit: report.copyWith(findings: merged),
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    Analytics.auditRun(findings: merged.length, risk: report.overallRisk);
    return updated;
  }

  Future<InsuranceClaim> updateFinding({
    required String uid,
    required InsuranceClaim claim,
    required String findingId,
    String? status,
    double? recoveredAmount,
  }) async {
    final audit = claim.audit;
    if (audit == null) return claim;
    final findings = audit.findings
        .map((f) => f.id == findingId ? f.copyWith(status: status, recoveredAmount: recoveredAmount) : f)
        .toList();
    final updated = claim.copyWith(audit: audit.copyWith(findings: findings), updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    if (status == FindingStatus.resolved && (recoveredAmount ?? 0) > 0) {
      Analytics.outcomeRecorded('finding_resolved', amountBucket: _bucket(recoveredAmount!));
    }
    return updated;
  }

  // ── Denial ─────────────────────────────────────────────────────────────────

  Future<InsuranceClaim> explainDenial({
    required String uid,
    required InsuranceClaim claim,
    PatientProfile? profile,
    List<InsurancePolicy> policies = const [],
    String userNotes = '',
  }) async {
    final denial = claim.denial;
    if (denial == null) return claim;
    final region = regionByCode(claim.country.isNotEmpty ? claim.country : profile?.country);
    final policy = _matchPolicy(claim, policies);
    final res = await _ai.explainDenial({
      'region': region.code,
      'denial': denial.toMap(),
      if (policy != null) 'policy': _policySummary(policy),
      'userNotes': userNotes,
    });
    final explanation = DenialExplanation.fromMap(Map<String, dynamic>.from(res['explanation'] as Map? ?? const {}));
    final updated = claim.copyWith(denialExplanation: explanation, updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    Analytics.denialExplained(explanation.strength);
    return updated;
  }

  /// Creates deadlines from the denial letter date + region/explanation steps.
  /// Returns the deadlines created (already saved and scheduled).
  Future<List<CaseDeadline>> createDeadlines({
    required String uid,
    required InsuranceClaim claim,
    PatientProfile? profile,
  }) async {
    final denial = claim.denial;
    if (denial == null) return const [];
    final existing = await _db.watchDeadlines(uid).first;
    final already = existing.where((d) => d.caseId == claim.id).map((d) => d.title.toLowerCase()).toSet();
    final base = denial.denialDateTime ?? DateTime.now();
    final title = claim.title.isNotEmpty ? claim.title : (claim.insurer.isNotEmpty ? claim.insurer : 'Case');
    final created = <CaseDeadline>[];

    Future<void> add(String label, DateTime due, String stage) async {
      if (already.contains(label.toLowerCase())) return;
      if (due.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return;
      final d = CaseDeadline(
        id: _uuid.v4(),
        caseId: claim.id,
        caseTitle: title,
        title: label,
        stage: stage,
        dueDate: due,
        source: 'denial',
      );
      await _db.saveDeadline(uid, d);
      await DeadlineScheduler.schedule(d);
      created.add(d);
      already.add(label.toLowerCase());
    }

    // 1. Explicit deadline printed on the letter wins.
    final printed = denial.appealDeadlineDate;
    if (printed != null) {
      await add('Appeal deadline (from letter)', printed, 'Internal appeal');
    }
    // 2. Steps from the AI plan with concrete day counts.
    final steps = claim.denialExplanation?.steps ?? const <DenialStep>[];
    for (final s in steps) {
      if (s.daysFromDenial <= 0) continue;
      if (printed != null && s.stage.toLowerCase().contains('internal') && s.daysFromDenial >= 150) continue;
      await add(s.stage, base.add(Duration(days: s.daysFromDenial)), s.stage);
    }
    // 3. Region defaults when nothing else exists.
    if (created.isEmpty && printed == null) {
      final region = regionByCode(claim.country.isNotEmpty ? claim.country : profile?.country);
      for (final s in region.appealStages) {
        if (s.daysFromDenial > 0) {
          await add('${s.stage} — ${s.deadline}', base.add(Duration(days: s.daysFromDenial)), s.stage);
        }
      }
    }
    if (created.isNotEmpty) Analytics.log('deadlines_created', {'count': created.length});
    return created;
  }

  // ── Letters ────────────────────────────────────────────────────────────────

  Future<InsuranceClaim> draftLetter({
    required String uid,
    required InsuranceClaim claim,
    required String kind,
    PatientProfile? profile,
    List<AuditFinding> findings = const [],
    List<String> argumentsToUse = const [],
    List<String> evidenceAvailable = const [],
    int householdSize = 0,
    double annualIncome = 0,
    String extraInstructions = '',
  }) async {
    final region = regionByCode(claim.country.isNotEmpty ? claim.country : profile?.country);
    final currency = claim.currencyCode.isNotEmpty ? claim.currencyCode : region.currencyCode;
    final denial = claim.denial;
    final amount = switch (kind) {
      LetterKind.appeal => denial?.amountDenied ?? claim.effectiveAmount,
      LetterKind.dispute => findings.fold<double>(0, (s, f) => s + f.amountAtIssue),
      _ => claim.effectiveAmount,
    };
    final res = await _ai.draftLetter({
      'region': region.code,
      'kind': kind,
      'context': {
        'patientName': profile?.fullName ?? '',
        'policyholderName': profile?.fullName ?? '',
        'insurerName': claim.insurer.isNotEmpty ? claim.insurer : (denial?.insurerName ?? ''),
        'providerName': claim.hospitalName.isNotEmpty ? claim.hospitalName : (denial?.providerName ?? ''),
        'policyNumber': claim.policyNumber,
        'memberId': denial?.memberId ?? claim.policyNumber,
        'claimNumber': denial?.claimNumber ?? '',
        'accountNumber': claim.expenses.map((e) => e.note).firstWhere((n) => n.startsWith('Account'), orElse: () => ''),
        'dateOfService': denial?.dateOfService.isNotEmpty == true ? denial!.dateOfService : claim.admissionDate,
        'denialDate': denial?.denialDate ?? '',
        'diagnosis': claim.diagnosis,
        'serviceDescription': denial?.serviceDescription ?? '',
        'amount': amount,
        'currency': currency,
        'denialReasonCategory': denial?.reasonCategory ?? '',
        'denialReasonText': denial?.reasonText.isNotEmpty == true ? denial!.reasonText : claim.rejectionReason,
        'policyClausesCited': denial?.policyClausesCited ?? const [],
        'findings': findings.map((f) => f.toMap()).toList(),
        'argumentsToUse': argumentsToUse,
        'evidenceAvailable': evidenceAvailable,
        'householdSize': householdSize,
        'annualIncome': annualIncome,
        'extraInstructions': extraInstructions,
      },
    });
    final l = Map<String, dynamic>.from(res['letter'] as Map? ?? const {});
    final letter = GeneratedLetter(
      id: _uuid.v4(),
      kind: kind,
      subject: '${l['subject'] ?? ''}',
      recipientBlock: '${l['recipientBlock'] ?? ''}',
      body: '${l['body'] ?? ''}',
      checklist: (l['checklist'] is List) ? (l['checklist'] as List).map((e) => '$e').toList() : const [],
      sendingTips: (l['sendingTips'] is List) ? (l['sendingTips'] as List).map((e) => '$e').toList() : const [],
      deadlineNote: '${l['deadlineNote'] ?? ''}',
    );
    // Findings included in a dispute letter move to "disputed".
    var audit = claim.audit;
    if (kind == LetterKind.dispute && audit != null && findings.isNotEmpty) {
      final ids = findings.map((f) => f.id).toSet();
      audit = audit.copyWith(
        findings: audit.findings
            .map((f) => ids.contains(f.id) && f.status == FindingStatus.open ? f.copyWith(status: FindingStatus.disputed) : f)
            .toList(),
      );
    }
    final updated = claim.copyWith(
      letters: [...claim.letters, letter],
      audit: audit,
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    Analytics.letterDrafted(kind);
    return updated;
  }

  Future<InsuranceClaim> updateLetter({
    required String uid,
    required InsuranceClaim claim,
    required GeneratedLetter letter,
    bool addFollowUp = false,
  }) async {
    final letters = claim.letters.map((l) => l.id == letter.id ? letter : l).toList();
    final updated = claim.copyWith(letters: letters, updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    if (addFollowUp && letter.status == 'sent') {
      final d = CaseDeadline(
        id: _uuid.v4(),
        caseId: claim.id,
        caseTitle: claim.title.isNotEmpty ? claim.title : claim.insurer,
        title: 'Follow up on ${LetterKind.label(letter.kind).toLowerCase()}',
        stage: 'follow_up',
        dueDate: DateTime.now().add(const Duration(days: 30)),
        source: 'manual',
      );
      await _db.saveDeadline(uid, d);
      await DeadlineScheduler.schedule(d);
    }
    return updated;
  }

  Future<InsuranceClaim> deleteLetter({required String uid, required InsuranceClaim claim, required String letterId}) async {
    final updated = claim.copyWith(letters: claim.letters.where((l) => l.id != letterId).toList(), updatedAt: DateTime.now());
    await _db.saveClaim(uid, updated);
    return updated;
  }

  // ── Outcome ────────────────────────────────────────────────────────────────

  Future<InsuranceClaim> setOutcome({
    required String uid,
    required InsuranceClaim claim,
    required String status,
    double recoveredAmount = 0,
    String note = '',
  }) async {
    final updated = claim.copyWith(
      outcomeStatus: status,
      recoveredAmount: recoveredAmount,
      outcomeNote: note,
      claimStatus: status == OutcomeStatus.won
          ? 'approved'
          : status == OutcomeStatus.lost
              ? 'rejected'
              : claim.claimStatus,
      updatedAt: DateTime.now(),
    );
    await _db.saveClaim(uid, updated);
    if (status != OutcomeStatus.open) {
      Analytics.outcomeRecorded(status, amountBucket: _bucket(recoveredAmount));
    }
    return updated;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  InsurancePolicy? _matchPolicy(InsuranceClaim claim, List<InsurancePolicy> policies) {
    if (policies.isEmpty) return null;
    if (claim.policyId.isNotEmpty) {
      final byId = policies.where((p) => p.id == claim.policyId).firstOrNull;
      if (byId != null) return byId;
    }
    final insurer = claim.insurer.toLowerCase();
    if (insurer.isNotEmpty) {
      final byName = policies.where((p) => p.insurer.toLowerCase().contains(insurer) || insurer.contains(p.insurer.toLowerCase())).firstOrNull;
      if (byName != null) return byName;
    }
    return policies.where((p) => p.policyType == 'health' && p.isActive).firstOrNull;
  }

  Map<String, dynamic> _policySummary(InsurancePolicy p) => {
        'insurer': p.insurer,
        'policyNumber': p.policyNumber,
        'policyType': p.policyType,
        'country': p.country,
        'currency': p.currencyCode,
        'coverageAmount': p.coverageAmount,
        'notes': p.notes,
      };

  static double _bucket(double amount) {
    if (amount <= 0) return 0;
    if (amount < 100) return 100;
    if (amount < 500) return 500;
    if (amount < 1000) return 1000;
    if (amount < 5000) return 5000;
    return 10000;
  }
}
