import 'package:flutter_test/flutter_test.dart';
import 'package:docpilot/models/patient_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // InsurancePolicy
  // ═══════════════════════════════════════════════════════════════════════════

  group('InsurancePolicy', () {
    // ── Defaults ──────────────────────────────────────────────────────────────

    test('default values are correct', () {
      final p = InsurancePolicy();
      expect(p.id, '');
      expect(p.userId, '');
      expect(p.insurer, '');
      expect(p.policyNumber, '');
      expect(p.policyType, 'health');
      expect(p.country, '');
      expect(p.currencyCode, '');
      expect(p.coverageAmount, 0.0);
      expect(p.premiumAmount, 0.0);
      expect(p.premiumFrequency, 'annual');
      expect(p.startDate, '');
      expect(p.renewalDate, '');
      expect(p.nomineeName, '');
      expect(p.nomineeRelation, '');
      expect(p.documentUrl, '');
      expect(p.isActive, true);
      expect(p.notes, '');
    });

    // ── toMap / fromMap ───────────────────────────────────────────────────────

    test('toMap produces all expected keys', () {
      final p = _samplePolicy();
      final map = p.toMap();
      expect(map['id'], 'pol-1');
      expect(map['insurer'], 'HDFC Ergo');
      expect(map['policyType'], 'health');
      expect(map['coverageAmount'], 500000.0);
      expect(map['premiumAmount'], 12000.0);
      expect(map['premiumFrequency'], 'annual');
      expect(map['isActive'], true);
      expect(map['country'], 'IN');
      expect(map['currencyCode'], 'INR');
      expect(map['nomineeName'], 'Jane Doe');
      expect(map['nomineeRelation'], 'Spouse');
    });

    test('fromMap restores all fields correctly', () {
      final original = _samplePolicy();
      final restored = InsurancePolicy.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.insurer, original.insurer);
      expect(restored.policyType, original.policyType);
      expect(restored.coverageAmount, original.coverageAmount);
      expect(restored.premiumAmount, original.premiumAmount);
      expect(restored.premiumFrequency, original.premiumFrequency);
      expect(restored.isActive, original.isActive);
      expect(restored.country, original.country);
      expect(restored.currencyCode, original.currencyCode);
      expect(restored.nomineeName, original.nomineeName);
      expect(restored.nomineeRelation, original.nomineeRelation);
    });

    test('fromMap with empty map uses safe defaults', () {
      final p = InsurancePolicy.fromMap({});
      expect(p.id, '');
      expect(p.policyType, 'health');
      expect(p.coverageAmount, 0.0);
      expect(p.premiumAmount, 0.0);
      expect(p.premiumFrequency, 'annual');
      expect(p.isActive, true);
    });

    test('fromMap: coverageAmount coerced from int', () {
      final p = InsurancePolicy.fromMap({'coverageAmount': 500000});
      expect(p.coverageAmount, 500000.0);
    });

    test('fromMap: coverageAmount coerced from string', () {
      final p = InsurancePolicy.fromMap({'coverageAmount': '750000.5'});
      expect(p.coverageAmount, 750000.5);
    });

    test('fromMap: coverageAmount is 0 for invalid string', () {
      final p = InsurancePolicy.fromMap({'coverageAmount': 'not-a-number'});
      expect(p.coverageAmount, 0.0);
    });

    test('fromMap: premiumAmount coerced from string', () {
      final p = InsurancePolicy.fromMap({'premiumAmount': '12000'});
      expect(p.premiumAmount, 12000.0);
    });

    test('fromMap: isActive is true when key is absent (default)', () {
      final p = InsurancePolicy.fromMap({});
      expect(p.isActive, true);
    });

    test('fromMap: isActive is false when explicitly false', () {
      final p = InsurancePolicy.fromMap({'isActive': false});
      expect(p.isActive, false);
    });

    test('fromMap: isActive is true when explicitly true', () {
      final p = InsurancePolicy.fromMap({'isActive': true});
      expect(p.isActive, true);
    });

    test('fromMap: policyType defaults to "health" when missing', () {
      final p = InsurancePolicy.fromMap({});
      expect(p.policyType, 'health');
    });

    test('fromMap: premiumFrequency defaults to "annual" when missing', () {
      final p = InsurancePolicy.fromMap({});
      expect(p.premiumFrequency, 'annual');
    });

    test('fromMap: all valid policyTypes are preserved', () {
      for (final type in ['health', 'term', 'critical_illness', 'accidental', 'other']) {
        final p = InsurancePolicy.fromMap({'policyType': type});
        expect(p.policyType, type);
      }
    });

    test('fromMap: all valid premiumFrequencies are preserved', () {
      for (final freq in ['monthly', 'quarterly', 'annual']) {
        final p = InsurancePolicy.fromMap({'premiumFrequency': freq});
        expect(p.premiumFrequency, freq);
      }
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    test('copyWith changes only specified fields', () {
      final original = _samplePolicy();
      final copy = original.copyWith(coverageAmount: 1000000, isActive: false);
      expect(copy.coverageAmount, 1000000.0);
      expect(copy.isActive, false);
      expect(copy.id, original.id);
      expect(copy.insurer, original.insurer);
      expect(copy.policyType, original.policyType);
    });

    test('copyWith: nomineeName can be cleared', () {
      final original = _samplePolicy();
      final copy = original.copyWith(nomineeName: '');
      expect(copy.nomineeName, '');
      expect(copy.nomineeRelation, original.nomineeRelation);
    });

    // ── Coverage total calculation ────────────────────────────────────────────

    test('two policies coverage amounts sum correctly (external code)', () {
      final p1 = InsurancePolicy(coverageAmount: 500000);
      final p2 = InsurancePolicy(coverageAmount: 300000);
      final total = p1.coverageAmount + p2.coverageAmount;
      expect(total, 800000.0);
    });

    test('fractional coverage amounts round-trip correctly', () {
      final p = InsurancePolicy(coverageAmount: 123456.78);
      final restored = InsurancePolicy.fromMap(p.toMap());
      expect(restored.coverageAmount, closeTo(123456.78, 0.001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CaseExpense
  // ═══════════════════════════════════════════════════════════════════════════

  group('CaseExpense', () {
    // ── Defaults ──────────────────────────────────────────────────────────────

    test('default values are correct', () {
      const e = CaseExpense();
      expect(e.id, '');
      expect(e.category, 'other');
      expect(e.vendor, '');
      expect(e.date, '');
      expect(e.amount, 0.0);
      expect(e.documentUrl, '');
      expect(e.imagePath, '');
      expect(e.note, '');
      expect(e.lineItems, '');
      expect(e.aiExtracted, false);
    });

    // ── toMap / fromMap ───────────────────────────────────────────────────────

    test('toMap produces all expected keys', () {
      final e = _sampleExpense();
      final map = e.toMap();
      expect(map['id'], 'exp-1');
      expect(map['category'], 'hospital');
      expect(map['vendor'], 'City Hospital');
      expect(map['amount'], 5000.0);
      expect(map['aiExtracted'], true);
    });

    test('fromMap restores all fields correctly', () {
      final original = _sampleExpense();
      final restored = CaseExpense.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.category, original.category);
      expect(restored.vendor, original.vendor);
      expect(restored.amount, original.amount);
      expect(restored.aiExtracted, original.aiExtracted);
      expect(restored.lineItems, original.lineItems);
    });

    test('fromMap with empty map uses safe defaults', () {
      final e = CaseExpense.fromMap({});
      expect(e.id, '');
      expect(e.category, 'other');
      expect(e.amount, 0.0);
      expect(e.aiExtracted, false);
    });

    test('fromMap: amount coerced from int', () {
      final e = CaseExpense.fromMap({'amount': 5000});
      expect(e.amount, 5000.0);
    });

    test('fromMap: amount coerced from string', () {
      final e = CaseExpense.fromMap({'amount': '1234.50'});
      expect(e.amount, 1234.50);
    });

    test('fromMap: amount is 0 for invalid string', () {
      final e = CaseExpense.fromMap({'amount': 'free'});
      expect(e.amount, 0.0);
    });

    test('fromMap: aiExtracted false when absent', () {
      final e = CaseExpense.fromMap({});
      expect(e.aiExtracted, false);
    });

    test('fromMap: aiExtracted true when explicitly true', () {
      final e = CaseExpense.fromMap({'aiExtracted': true});
      expect(e.aiExtracted, true);
    });

    test('fromMap: category defaults to "other" when missing', () {
      final e = CaseExpense.fromMap({});
      expect(e.category, 'other');
    });

    test('fromMap: all valid categories are preserved', () {
      for (final cat in ['hospital', 'pharmacy', 'lab', 'consultation', 'imaging', 'procedure', 'other']) {
        final e = CaseExpense.fromMap({'category': cat});
        expect(e.category, cat, reason: 'Failed for category: $cat');
      }
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    test('copyWith changes only specified fields', () {
      final original = _sampleExpense();
      final copy = original.copyWith(amount: 9999, category: 'pharmacy');
      expect(copy.amount, 9999.0);
      expect(copy.category, 'pharmacy');
      expect(copy.id, original.id);
      expect(copy.vendor, original.vendor);
    });

    test('copyWith: lineItems can be updated', () {
      const e = CaseExpense();
      final copy = e.copyWith(lineItems: 'MRI — 8500\nRoom — 3000');
      expect(copy.lineItems, 'MRI — 8500\nRoom — 3000');
    });

    // ── Edge cases ───────────────────────────────────────────────────────────

    test('zero amount expense is valid', () {
      const e = CaseExpense(amount: 0);
      expect(e.amount, 0.0);
      final restored = CaseExpense.fromMap(e.toMap());
      expect(restored.amount, 0.0);
    });

    test('very large amount round-trips correctly', () {
      const e = CaseExpense(amount: 9999999.99);
      final restored = CaseExpense.fromMap(e.toMap());
      expect(restored.amount, closeTo(9999999.99, 0.001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // InsuranceClaim
  // ═══════════════════════════════════════════════════════════════════════════

  group('InsuranceClaim', () {
    // ── Defaults ──────────────────────────────────────────────────────────────

    test('default values are correct', () {
      final c = InsuranceClaim();
      expect(c.id, '');
      expect(c.userId, '');
      expect(c.claimStatus, 'pending');
      expect(c.claimAmount, 0.0);
      expect(c.caseType, 'inpatient');
      expect(c.expenses, isEmpty);
      expect(c.documentUrls, isEmpty);
      expect(c.fightAnalysis, '');
      expect(c.appealLetter, '');
      expect(c.auditReport, '');
      expect(c.disputeLetter, '');
    });

    // ── Computed getters ──────────────────────────────────────────────────────

    test('isRejected: true when claimStatus is "rejected"', () {
      final c = InsuranceClaim(claimStatus: 'rejected');
      expect(c.isRejected, true);
    });

    test('isRejected: false for "pending"', () {
      final c = InsuranceClaim(claimStatus: 'pending');
      expect(c.isRejected, false);
    });

    test('isRejected: false for "approved"', () {
      final c = InsuranceClaim(claimStatus: 'approved');
      expect(c.isRejected, false);
    });

    test('isRejected: false for "under_review"', () {
      final c = InsuranceClaim(claimStatus: 'under_review');
      expect(c.isRejected, false);
    });

    test('isApproved: true when claimStatus is "approved"', () {
      final c = InsuranceClaim(claimStatus: 'approved');
      expect(c.isApproved, true);
    });

    test('isApproved: false for non-approved statuses', () {
      for (final status in ['pending', 'rejected', 'under_review']) {
        final c = InsuranceClaim(claimStatus: status);
        expect(c.isApproved, false, reason: 'Failed for status: $status');
      }
    });

    test('hasFightAnalysis: true when fightAnalysis is non-empty', () {
      final c = InsuranceClaim(fightAnalysis: 'You can appeal because...');
      expect(c.hasFightAnalysis, true);
    });

    test('hasFightAnalysis: false when fightAnalysis is empty', () {
      final c = InsuranceClaim(fightAnalysis: '');
      expect(c.hasFightAnalysis, false);
    });

    test('hasFightAnalysis: false for whitespace-only (empty string)', () {
      final c = InsuranceClaim(fightAnalysis: '');
      expect(c.hasFightAnalysis, false);
    });

    // ── totalExpenses ─────────────────────────────────────────────────────────

    test('totalExpenses is 0 when no expenses', () {
      final c = InsuranceClaim(expenses: []);
      expect(c.totalExpenses, 0.0);
    });

    test('totalExpenses sums one expense correctly', () {
      final c = InsuranceClaim(expenses: [
        const CaseExpense(amount: 5000),
      ]);
      expect(c.totalExpenses, 5000.0);
    });

    test('totalExpenses sums multiple expenses correctly', () {
      final c = InsuranceClaim(expenses: [
        const CaseExpense(amount: 5000),
        const CaseExpense(amount: 3000),
        const CaseExpense(amount: 1500.50),
      ]);
      expect(c.totalExpenses, closeTo(9500.50, 0.001));
    });

    test('totalExpenses handles fractional amounts', () {
      final c = InsuranceClaim(expenses: [
        const CaseExpense(amount: 1.10),
        const CaseExpense(amount: 2.20),
        const CaseExpense(amount: 3.30),
      ]);
      expect(c.totalExpenses, closeTo(6.60, 0.001));
    });

    test('totalExpenses handles zero-amount expenses', () {
      final c = InsuranceClaim(expenses: [
        const CaseExpense(amount: 0),
        const CaseExpense(amount: 1000),
      ]);
      expect(c.totalExpenses, 1000.0);
    });

    // ── effectiveAmount ───────────────────────────────────────────────────────

    test('effectiveAmount returns claimAmount when expenses list is empty', () {
      final c = InsuranceClaim(claimAmount: 25000, expenses: []);
      expect(c.effectiveAmount, 25000.0);
    });

    test('effectiveAmount returns totalExpenses when expenses exist', () {
      final c = InsuranceClaim(
        claimAmount: 99999, // should be ignored
        expenses: [
          const CaseExpense(amount: 5000),
          const CaseExpense(amount: 3000),
        ],
      );
      expect(c.effectiveAmount, 8000.0);
    });

    test('effectiveAmount uses totalExpenses even when total is 0 (with expenses)', () {
      final c = InsuranceClaim(
        claimAmount: 50000,
        expenses: [const CaseExpense(amount: 0)],
      );
      // expenses list is non-empty, so totalExpenses (0) wins over claimAmount
      expect(c.effectiveAmount, 0.0);
    });

    test('effectiveAmount with single expense equals that expense amount', () {
      final c = InsuranceClaim(
        claimAmount: 0,
        expenses: [const CaseExpense(amount: 12345.67)],
      );
      expect(c.effectiveAmount, closeTo(12345.67, 0.001));
    });

    // ── fromMap / toMap ───────────────────────────────────────────────────────

    test('toMap produces all expected keys', () {
      final c = _sampleClaim();
      final map = c.toMap();
      expect(map['id'], 'claim-1');
      expect(map['claimStatus'], 'pending');
      expect(map['caseType'], 'inpatient');
      expect(map['title'], 'Knee Surgery Apr 2026');
      expect(map['country'], 'IN');
      expect(map['currencyCode'], 'INR');
      expect(map['expenses'], isA<List>());
    });

    test('fromMap restores all top-level fields', () {
      final original = _sampleClaim();
      final restored = InsuranceClaim.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.claimStatus, original.claimStatus);
      expect(restored.caseType, original.caseType);
      expect(restored.title, original.title);
      expect(restored.country, original.country);
      expect(restored.insurer, original.insurer);
      expect(restored.hospitalName, original.hospitalName);
      expect(restored.diagnosis, original.diagnosis);
    });

    test('fromMap restores nested expenses', () {
      final original = InsuranceClaim(
        id: 'c1',
        expenses: [
          const CaseExpense(id: 'e1', vendor: 'Pharmacy', amount: 500, category: 'pharmacy'),
          const CaseExpense(id: 'e2', vendor: 'Lab', amount: 1200, category: 'lab'),
        ],
      );
      final restored = InsuranceClaim.fromMap(original.toMap());
      expect(restored.expenses.length, 2);
      expect(restored.expenses[0].vendor, 'Pharmacy');
      expect(restored.expenses[0].amount, 500.0);
      expect(restored.expenses[1].vendor, 'Lab');
      expect(restored.expenses[1].amount, 1200.0);
    });

    test('fromMap with null/missing expenses returns empty list', () {
      final c = InsuranceClaim.fromMap({});
      expect(c.expenses, isEmpty);
    });

    test('fromMap with empty map uses safe defaults', () {
      final c = InsuranceClaim.fromMap({});
      expect(c.claimStatus, 'pending');
      expect(c.caseType, 'inpatient');
      expect(c.claimAmount, 0.0);
    });

    test('fromMap: claimAmount coerced from int', () {
      final c = InsuranceClaim.fromMap({'claimAmount': 50000});
      expect(c.claimAmount, 50000.0);
    });

    test('fromMap: claimAmount coerced from string', () {
      final c = InsuranceClaim.fromMap({'claimAmount': '35000.75'});
      expect(c.claimAmount, 35000.75);
    });

    test('fromMap: documentUrls restored from list', () {
      final c = InsuranceClaim.fromMap({
        'documentUrls': ['https://url1.com', 'https://url2.com'],
      });
      expect(c.documentUrls.length, 2);
      expect(c.documentUrls[0], 'https://url1.com');
    });

    test('fromMap: documentUrls is empty list when missing', () {
      final c = InsuranceClaim.fromMap({});
      expect(c.documentUrls, isEmpty);
    });

    test('fromMap: all valid claimStatuses preserved', () {
      for (final status in ['pending', 'approved', 'rejected', 'under_review']) {
        final c = InsuranceClaim.fromMap({'claimStatus': status});
        expect(c.claimStatus, status, reason: 'Failed for status: $status');
      }
    });

    test('fromMap: all valid caseTypes preserved', () {
      for (final ct in ['inpatient', 'outpatient']) {
        final c = InsuranceClaim.fromMap({'caseType': ct});
        expect(c.caseType, ct, reason: 'Failed for caseType: $ct');
      }
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    test('copyWith changes only specified fields', () {
      final original = _sampleClaim();
      final copy = original.copyWith(claimStatus: 'approved', fightAnalysis: 'Fight this!');
      expect(copy.claimStatus, 'approved');
      expect(copy.fightAnalysis, 'Fight this!');
      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.insurer, original.insurer);
    });

    test('copyWith: expenses list can be replaced', () {
      final original = _sampleClaim();
      final copy = original.copyWith(expenses: [const CaseExpense(amount: 999)]);
      expect(copy.expenses.length, 1);
      expect(copy.expenses[0].amount, 999.0);
    });

    test('copyWith: AI fields can be updated independently', () {
      final original = _sampleClaim();
      final copy = original.copyWith(
        auditReport: 'Audit done.',
        disputeLetter: 'Dear Billing...',
        appealLetter: 'Dear Insurer...',
      );
      expect(copy.auditReport, 'Audit done.');
      expect(copy.disputeLetter, 'Dear Billing...');
      expect(copy.appealLetter, 'Dear Insurer...');
      expect(copy.claimStatus, original.claimStatus);
    });

    // ── Full roundtrip with expenses ──────────────────────────────────────────

    test('full roundtrip with multiple expenses preserves effectiveAmount', () {
      final original = InsuranceClaim(
        id: 'c-rt',
        claimAmount: 0,
        expenses: [
          const CaseExpense(amount: 10000, category: 'hospital'),
          const CaseExpense(amount: 5000, category: 'pharmacy'),
          const CaseExpense(amount: 2500, category: 'lab'),
        ],
      );
      final restored = InsuranceClaim.fromMap(original.toMap());
      expect(restored.effectiveAmount, 17500.0);
      expect(restored.totalExpenses, 17500.0);
    });

    test('rejected claim with fight data roundtrips correctly', () {
      final original = InsuranceClaim(
        id: 'c-fight',
        claimStatus: 'rejected',
        rejectionReason: 'Pre-existing condition',
        fightAnalysis: 'You can appeal under IRDAI regulations...',
        appealLetter: 'Dear HDFC Ergo, I write to appeal...',
      );
      final restored = InsuranceClaim.fromMap(original.toMap());
      expect(restored.isRejected, true);
      expect(restored.hasFightAnalysis, true);
      expect(restored.rejectionReason, 'Pre-existing condition');
      expect(restored.fightAnalysis, contains('IRDAI'));
      expect(restored.appealLetter, contains('HDFC Ergo'));
    });
  });
}

// ── Sample fixtures ───────────────────────────────────────────────────────────

InsurancePolicy _samplePolicy() => InsurancePolicy(
      id: 'pol-1',
      userId: 'user-1',
      insurer: 'HDFC Ergo',
      policyNumber: 'HE-2026-001',
      policyType: 'health',
      country: 'IN',
      currencyCode: 'INR',
      coverageAmount: 500000,
      premiumAmount: 12000,
      premiumFrequency: 'annual',
      startDate: '2026-01-01',
      renewalDate: '2027-01-01',
      nomineeName: 'Jane Doe',
      nomineeRelation: 'Spouse',
      isActive: true,
      notes: 'Family floater plan',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

CaseExpense _sampleExpense() => const CaseExpense(
      id: 'exp-1',
      category: 'hospital',
      vendor: 'City Hospital',
      date: '01 Jun 2026',
      amount: 5000,
      documentUrl: 'https://storage.example.com/bill.jpg',
      imagePath: '/local/bill.jpg',
      note: 'Room charges',
      lineItems: 'Room — 3000\nNursing — 2000',
      aiExtracted: true,
    );

InsuranceClaim _sampleClaim() => InsuranceClaim(
      id: 'claim-1',
      userId: 'user-1',
      policyId: 'pol-1',
      policyNumber: 'HE-2026-001',
      insurer: 'HDFC Ergo',
      hospitalName: 'City Hospital',
      admissionDate: '01 Apr 2026',
      dischargeDate: '05 Apr 2026',
      diagnosis: 'Knee ligament repair',
      claimAmount: 0,
      claimStatus: 'pending',
      title: 'Knee Surgery Apr 2026',
      country: 'IN',
      currencyCode: 'INR',
      caseType: 'inpatient',
      expenses: [
        const CaseExpense(id: 'e1', amount: 10000, category: 'hospital', vendor: 'City Hospital'),
        const CaseExpense(id: 'e2', amount: 2000, category: 'pharmacy', vendor: 'MedPlus'),
      ],
      createdAt: DateTime(2026, 4, 5),
      updatedAt: DateTime(2026, 4, 5),
    );
