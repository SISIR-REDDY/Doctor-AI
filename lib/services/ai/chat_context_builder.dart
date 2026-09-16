import '../../core/config/insurance_regions.dart';
import '../../models/patient_models.dart';
import '../firebase/firestore_service.dart';

/// Builds the grounding context for coverage chat from the user's own data:
/// open cases (bills, audits, denials, deadlines), policies and recent
/// scanned documents. Kept compact (≈10k chars) and free of raw images.
class ChatContextBuilder {
  final FirestoreService db;
  ChatContextBuilder(this.db);

  static const int _maxChars = 14000;

  Future<String> build(String uid) async {
    final buf = StringBuffer();
    try {
      final claims = await db.watchClaims(uid).first;
      if (claims.isNotEmpty) {
        buf.writeln('CASES (${claims.length}):');
        for (final c in claims.take(8)) {
          final cur = c.currencyCode;
          buf.writeln('- Case "${c.title.isNotEmpty ? c.title : c.hospitalName}" · status ${c.isClosed ? c.outcomeStatus : 'open'} · '
              'insurer ${c.insurer.isEmpty ? 'n/a' : c.insurer} · provider ${c.hospitalName.isEmpty ? 'n/a' : c.hospitalName} · '
              'billed ${formatMoney(c.effectiveAmount, cur)} · next: ${c.nextAction}');
          for (final e in c.expenses.take(6)) {
            buf.writeln('   bill: ${e.vendor} ${e.date} ${formatMoney(e.amount, cur)}'
                '${e.items.isNotEmpty ? ' · ${e.items.length} line items: ${e.items.take(8).map((i) => '${i.code.isNotEmpty ? '[${i.code}] ' : ''}${i.description} ${i.amount.toStringAsFixed(2)}').join('; ')}' : ''}');
          }
          if (c.audit != null) {
            buf.writeln('   audit: ${c.audit!.summary} Potential saving ${formatMoney(c.audit!.totalSavingLow, cur)}–${formatMoney(c.audit!.totalSavingHigh, cur)}. '
                'Findings: ${c.audit!.findings.take(6).map((f) => '${f.title} (${formatMoney(f.estimatedSavingHigh, cur)}, ${f.status})').join('; ')}');
          }
          if (c.denial != null) {
            final d = c.denial!;
            buf.writeln('   denial: ${d.insurerName} denied ${d.serviceDescription} on ${d.denialDate} for "${d.reasonText}" (${d.reasonCategory}); '
                'amount ${formatMoney(d.amountDenied, cur)}; appeal deadline ${d.appealDeadline.isNotEmpty ? d.appealDeadline : d.appealDeadlineText}');
          }
          if (c.denialExplanation != null) {
            buf.writeln('   analysis: ${c.denialExplanation!.plainSummary} Strength: ${c.denialExplanation!.strength}.');
          }
          if (c.eob.isNotEmpty) {
            buf.writeln('   EOB: billed ${c.eob['totalBilled']}, allowed ${c.eob['totalAllowed']}, plan paid ${c.eob['totalPlanPaid']}, '
                'patient owes ${c.eob['totalPatientResponsibility']}; network ${c.eob['networkStatus']}; reasons ${c.eob['denialReasons']}');
          }
          for (final l in c.letters.take(4)) {
            buf.writeln('   letter: ${l.kind} (${l.status}) — ${l.subject}');
          }
        }
      }
    } catch (_) {}

    try {
      final deadlines = await db.watchDeadlines(uid).first;
      final open = deadlines.where((d) => !d.completed).take(8);
      if (open.isNotEmpty) {
        buf.writeln('DEADLINES:');
        for (final d in open) {
          buf.writeln('- ${d.title} for "${d.caseTitle}" due ${d.dueDate.toIso8601String().split('T').first} (${d.daysLeft} days left)');
        }
      }
    } catch (_) {}

    try {
      final policies = await db.watchPolicies(uid).first;
      if (policies.isNotEmpty) {
        buf.writeln('POLICIES:');
        for (final p in policies.take(5)) {
          buf.writeln('- ${p.insurer}${p.planName.isNotEmpty ? ' ${p.planName}' : ''} · ${p.policyType} · policy ${p.policyNumber} · country ${p.country} · '
              'coverage ${formatMoney(p.coverageAmount, p.currencyCode)} · premium ${formatMoney(p.premiumAmount, p.currencyCode)}/${p.premiumFrequency} · renewal ${p.renewalDate}');
          if (p.hasCostSharing) {
            buf.writeln('   cost sharing: deductible ${p.deductibleIndividual}/${p.deductibleFamily} · OOP max ${p.outOfPocketMaxIndividual}/${p.outOfPocketMaxFamily} · '
                'copays PCP ${p.copayPrimaryCare} specialist ${p.copaySpecialist} ER ${p.copayEmergency} · coinsurance ${p.coinsurancePercent}% · network ${p.networkType}');
          }
          if (p.exclusions.isNotEmpty) buf.writeln('   exclusions: ${p.exclusions.join('; ')}');
          if (p.waitingPeriods.isNotEmpty) buf.writeln('   waiting periods: ${p.waitingPeriods.join('; ')}');
          if (p.notes.isNotEmpty) buf.writeln('   notes: ${p.notes.replaceAll('\n', ' | ')}');
        }
      }
    } catch (_) {}

    try {
      final docs = await db.watchDocuments(uid).first;
      if (docs.isNotEmpty) {
        buf.writeln('RECENT DOCUMENTS:');
        for (final d in docs.take(6)) {
          buf.writeln('- ${d.docType}: ${d.title} — ${d.summary}');
        }
      }
    } catch (_) {}

    // Lab history as a per-marker series, newest first, so the assistant can
    // compare today's reading with earlier ones by date rather than guessing.
    try {
      final records = await db.watchMedicalRecords(uid).first;
      final labs = records.where((r) => r.labMarkers.isNotEmpty).toList()
        ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
      if (labs.isNotEmpty) {
        buf.writeln('LAB HISTORY (newest first; status per the lab’s own range):');
        final series = <String, List<String>>{};
        final label = <String, String>{};
        for (final r in labs.take(8)) {
          final d = r.recordDate.toIso8601String().split('T').first;
          for (final m in r.labMarkers) {
            label.putIfAbsent(m.key, () => m.name);
            (series[m.key] ??= []).add('${m.value}${m.unit.isEmpty ? '' : ' ${m.unit}'} on $d [${m.status.name}${m.refText.isEmpty ? '' : ', ref ${m.refText}'}]');
          }
        }
        for (final e in series.entries.take(40)) {
          buf.writeln('- ${label[e.key]}: ${e.value.take(4).join(' ← ')}');
        }
      }
    } catch (_) {}

    try {
      final meds = await db.watchMedications(uid).first;
      final active = meds.where((m) => m.isActive).take(12);
      if (active.isNotEmpty) {
        buf.writeln('ACTIVE MEDICATIONS:');
        for (final m in active) {
          buf.writeln('- ${m.name} ${m.dosage} ${m.frequency}${m.purpose.isEmpty ? '' : ' for ${m.purpose}'}');
        }
      }
    } catch (_) {}

    final text = buf.toString();
    return text.length > _maxChars ? '${text.substring(0, _maxChars)}\n…(truncated)' : text;
  }

  static String profileSummary(PatientProfile? p) {
    if (p == null) return '';
    return [
      if (p.age > 0) 'age ${p.age}',
      if (p.gender.isNotEmpty) p.gender,
      if (p.allAllergies.isNotEmpty) 'allergies: ${p.allAllergies.join(', ')}',
      if (p.chronicConditions.isNotEmpty) 'conditions: ${p.chronicConditions.join(', ')}',
      if (p.pastDiseases.isNotEmpty) 'history: ${p.pastDiseases.join(', ')}',
    ].join('; ');
  }
}
