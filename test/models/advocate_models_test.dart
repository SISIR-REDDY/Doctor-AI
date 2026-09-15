import 'package:docpilot/core/config/insurance_regions.dart';
import 'package:docpilot/models/advocate_models.dart';
import 'package:docpilot/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillLineItem', () {
    test('derives unit price and defaults quantity from AI json', () {
      final li = BillLineItem.fromMap({
        'code': '99213',
        'description': 'Office visit',
        'quantity': 0,
        'unitPrice': 0,
        'amount': 250,
        'category': '',
      });
      expect(li.quantity, 1);
      expect(li.unitPrice, 250);
      expect(li.category, 'other');
      expect(li.asText, contains('[99213]'));
    });

    test('round-trips through toMap/fromMap', () {
      const li = BillLineItem(code: '85025', description: 'CBC', quantity: 2, unitPrice: 46, amount: 92, category: 'lab');
      final back = BillLineItem.fromMap(li.toMap());
      expect(back.code, '85025');
      expect(back.quantity, 2);
      expect(back.amount, 92);
    });
  });

  group('AuditReport', () {
    final report = AuditReport.fromMap({
      'summary': 'Two issues found.',
      'overallRisk': 'high',
      'findings': [
        {'id': 'F1', 'type': 'duplicate', 'severity': 'high', 'title': 'Duplicate CBC', 'amountAtIssue': 92, 'estimatedSavingLow': 46, 'estimatedSavingHigh': 92},
        {'id': 'F2', 'type': 'overpriced', 'severity': 'medium', 'title': 'CT 5x', 'amountAtIssue': 1850, 'estimatedSavingLow': 900, 'estimatedSavingHigh': 1400, 'status': 'dismissed'},
        {'id': 'F3', 'type': 'quantity', 'severity': 'low', 'title': 'Qty', 'amountAtIssue': 50, 'estimatedSavingLow': 10, 'estimatedSavingHigh': 50, 'status': 'resolved', 'recoveredAmount': 40},
      ],
      'totalSavingLow': 956,
      'totalSavingHigh': 1542,
      'nextSteps': ['Request itemized bill'],
    }, currency: 'USD');

    test('parses findings and defaults status to open', () {
      expect(report.findings.length, 3);
      expect(report.findings.first.status, FindingStatus.open);
      expect(report.currency, 'USD');
    });

    test('open savings exclude dismissed and resolved findings', () {
      expect(report.openFindings.map((f) => f.id), ['F1']);
      expect(report.openSavingHigh, 92);
      expect(report.openSavingLow, 46);
      expect(report.recovered, 40);
    });

    test('copyWith preserves report meta while replacing findings', () {
      final updated = report.copyWith(findings: [report.findings.first.copyWith(status: FindingStatus.disputed)]);
      expect(updated.summary, report.summary);
      expect(updated.findings.single.status, FindingStatus.disputed);
      expect(updated.findings.single.isOpen, isTrue);
    });
  });

  group('DenialInfo / DenialExplanation', () {
    test('parses dates and deadlines', () {
      final d = DenialInfo.fromMap({
        'insurerName': 'Acme Health',
        'reasonCategory': 'medical_necessity',
        'reasonText': 'Not medically necessary',
        'denialDate': '2026-09-01',
        'appealDeadline': '2027-02-28',
        'currency': 'USD',
        'amountDenied': '1200.50',
      });
      expect(d.denialDateTime, DateTime(2026, 9, 1));
      expect(d.appealDeadlineDate, DateTime(2027, 2, 28));
      expect(d.amountDenied, 1200.50);
      expect(DenialInfo.reasonLabel(d.reasonCategory), 'Not medically necessary');
    });

    test('explanation steps round-trip', () {
      final x = DenialExplanation.fromMap({
        'plainSummary': 'Denied because…',
        'isDisputable': true,
        'strength': 'strong',
        'arguments': [
          {'title': 'Policy covers it', 'detail': 'Section 4.2'},
        ],
        'steps': [
          {'stage': 'Internal appeal', 'action': 'Send letter', 'deadline': '180 days', 'daysFromDenial': 180},
        ],
      });
      final back = DenialExplanation.fromMap(x.toMap());
      expect(back.steps.single.daysFromDenial, 180);
      expect(back.arguments.single.title, 'Policy covers it');
      expect(back.strength, 'strong');
    });
  });

  group('InsuranceClaim advocate fields', () {
    InsuranceClaim base() => InsuranceClaim(id: 'c1', userId: 'u', title: 'ER visit', country: 'US', currencyCode: 'USD');

    test('nextAction prioritises denial → explanation → appeal → drafts → audit', () {
      expect(base().nextAction, 'Add a bill or letter');

      final withBill = base().copyWith(expenses: [const CaseExpense(id: 'e1', amount: 100)]);
      expect(withBill.nextAction, 'Run the bill audit');

      final withDenial = base().copyWith(denial: const DenialInfo(insurerName: 'Acme'));
      expect(withDenial.nextAction, 'Review the denial');

      final explained = withDenial.copyWith(denialExplanation: DenialExplanation(plainSummary: 'x'));
      expect(explained.nextAction, 'Draft the appeal');

      final drafted = explained.copyWith(letters: [GeneratedLetter(id: 'l1', kind: LetterKind.appeal)]);
      expect(drafted.nextAction, 'Send your letter');

      final sent = explained.copyWith(letters: [GeneratedLetter(id: 'l1', kind: LetterKind.appeal, status: 'sent')]);
      expect(sent.nextAction, 'Track the outcome');

      final closed = base().copyWith(outcomeStatus: OutcomeStatus.won, recoveredAmount: 300);
      expect(closed.nextAction, 'Won');
      expect(closed.isClosed, isTrue);
      expect(closed.totalRecovered, 300);
    });

    test('potentialSaving and totalRecovered derive from the audit', () {
      final audit = AuditReport(findings: const [
        AuditFinding(id: 'F1', estimatedSavingHigh: 120, estimatedSavingLow: 60),
        AuditFinding(id: 'F2', estimatedSavingHigh: 80, status: FindingStatus.resolved, recoveredAmount: 75),
      ]);
      final c = base().copyWith(audit: audit);
      expect(c.potentialSaving, 120);
      expect(c.totalRecovered, 75);
      expect(c.hasAudit, isTrue);
    });

    test('serialises and restores nested engine data', () {
      final c = base().copyWith(
        audit: AuditReport(summary: 's', findings: const [AuditFinding(id: 'F1', title: 'Dup', estimatedSavingHigh: 10)]),
        denial: const DenialInfo(insurerName: 'Acme', reasonCategory: 'not_covered'),
        letters: [GeneratedLetter(id: 'l1', kind: LetterKind.dispute, body: 'Dear…')],
        documentIds: const ['d1'],
        eob: const {'totalBilled': 500},
        outcomeStatus: OutcomeStatus.partial,
        recoveredAmount: 42,
      );
      final back = InsuranceClaim.fromMap(c.toMap());
      expect(back.audit!.findings.single.title, 'Dup');
      expect(back.denial!.reasonCategory, 'not_covered');
      expect(back.letters.single.kind, LetterKind.dispute);
      expect(back.documentIds, ['d1']);
      expect(back.eob['totalBilled'], 500);
      expect(back.outcomeStatus, OutcomeStatus.partial);
      expect(back.recoveredAmount, 42);
    });

    test('legacy claim maps without engine fields still parse', () {
      final back = InsuranceClaim.fromMap({'id': 'old', 'insurer': 'X', 'claimAmount': 10});
      expect(back.audit, isNull);
      expect(back.denial, isNull);
      expect(back.letters, isEmpty);
      expect(back.outcomeStatus, OutcomeStatus.open);
      expect(back.effectiveAmount, 10);
    });
  });

  group('CaseExpense structured items', () {
    test('isItemized recognises structured items or legacy text', () {
      expect(const CaseExpense(id: 'e').isItemized, isFalse);
      expect(const CaseExpense(id: 'e', lineItems: 'CBC — 92').isItemized, isTrue);
      expect(const CaseExpense(id: 'e', items: [BillLineItem(description: 'CBC', amount: 92)]).isItemized, isTrue);
    });

    test('round-trips items and documentId', () {
      const e = CaseExpense(id: 'e1', amount: 92, items: [BillLineItem(code: '85025', description: 'CBC', amount: 92)], documentId: 'doc9');
      final back = CaseExpense.fromMap(e.toMap());
      expect(back.items.single.code, '85025');
      expect(back.documentId, 'doc9');
    });
  });

  group('CaseDeadline', () {
    test('daysLeft / isOverdue', () {
      final future = CaseDeadline(id: 'd', caseId: 'c', title: 't', dueDate: DateTime.now().add(const Duration(days: 10)));
      final past = CaseDeadline(id: 'd', caseId: 'c', title: 't', dueDate: DateTime.now().subtract(const Duration(days: 2)));
      expect(future.daysLeft, inInclusiveRange(9, 10));
      expect(future.isOverdue, isFalse);
      expect(past.isOverdue, isTrue);
      expect(past.copyWith(completed: true).isOverdue, isFalse);
    });
  });

  group('PatientProfile onboarding fields', () {
    test('round-trips country, goals, familyMode, onboardingVersion', () {
      final p = PatientProfile(id: 'u', firstName: 'A', country: 'GB', goals: const ['denial'], familyMode: true, onboardingVersion: 2);
      final back = PatientProfile.fromMap(p.toMap());
      expect(back.country, 'GB');
      expect(back.goals, ['denial']);
      expect(back.familyMode, isTrue);
      expect(back.onboardingVersion, 2);
      expect(back.hasCountry, isTrue);
    });

    test('legacy profiles default to onboardingVersion 0', () {
      expect(PatientProfile.fromMap({'id': 'u'}).onboardingVersion, 0);
    });
  });

  group('Region appeal stages', () {
    test('every launch region has stages with reminder days', () {
      for (final code in ['US', 'GB', 'CA', 'AU', 'EU', 'IN']) {
        final r = regionByCode(code);
        expect(r.appealStages, isNotEmpty, reason: code);
        expect(r.appealStages.any((s) => s.daysFromDenial > 0), isTrue, reason: code);
        expect(r.billingNote, isNotEmpty, reason: code);
      }
    });
  });
}
