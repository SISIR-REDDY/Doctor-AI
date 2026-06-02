import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import 'add_expense_screen.dart' show kExpenseCategories, kExpenseCategoryIcons;
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class ClaimDetailScreen extends StatefulWidget {
  final InsuranceClaim claim;
  const ClaimDetailScreen({super.key, required this.claim});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  late InsuranceClaim _claim;
  bool _generatingFight = false;
  bool _generatingAppeal = false;
  bool _generatingAudit = false;
  bool _generatingDispute = false;
  final _db = FirestoreService();
  final _rejectionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _claim = widget.claim;
  }

  @override
  void dispose() {
    _rejectionCtrl.dispose();
    super.dispose();
  }

  static const _statusColors = <String, Color>{
    'pending': AppTheme.warningColor,
    'approved': AppTheme.successColor,
    'rejected': AppTheme.dangerColor,
    'under_review': AppTheme.infoColor,
  };

  Future<void> _analyzeRejection() async {
    final reason = _rejectionCtrl.text.trim();
    setState(() => _generatingFight = true);
    final profile = context.read<HealthDataProvider>().profile;
    final uid = context.read<HealthDataProvider>().uid;
    try {
      final region = regionByCode(_claim.country);
      final steps = region.escalationSteps.isEmpty
          ? '   (use the standard internal-appeal → ombudsman → regulator path)'
          : region.escalationSteps
              .asMap()
              .entries
              .map((e) => '   ${e.key + 1}. ${e.value}')
              .join('\n');

      final prompt =
          '''You are an expert insurance claims advisor and consumer-rights advocate for ${region.name}. Analyze this rejected health insurance claim and give a comprehensive, country-specific strategy to fight it.

Claim Details:
- Patient: ${profile?.fullName ?? 'Patient'}
- Insurer: ${_claim.insurer}
- Policy Number: ${_claim.policyNumber}
- Provider/Hospital: ${_claim.hospitalName}
- Diagnosis: ${_claim.diagnosis}
- Claim Amount: ${formatMoney(_claim.effectiveAmount, _claim.currencyCode)}
- Rejection Reason: ${reason.isEmpty ? _claim.rejectionReason : reason}

Country context — ${region.name} (use this, do NOT give advice for other countries):
- Regulator: ${region.regulator}
- Independent dispute body: ${region.ombudsman}
- Key consumer protections: ${region.keyRights}
- Typical escalation path:
$steps

Please provide:
1. Whether the rejection grounds are valid or disputable, and why
2. The policyholder's rights in ${region.name}
3. A step-by-step escalation strategy specific to ${region.name} (reference the regulator, ombudsman and laws above, with deadlines)
4. Key policy clauses and legal provisions to cite
5. Evidence and documents to gather
6. Timelines and deadlines to watch
7. A realistic probability-of-success assessment

Be specific and accurate for ${region.name}. Use clear, actionable language.''';

      final response =
          await ChatbotService().getGeminiResponse(prompt);

      if (uid != null) {
        final updated = _claim.copyWith(
          fightAnalysis: response,
          rejectionReason: reason.isNotEmpty ? reason : _claim.rejectionReason,
          claimStatus: 'rejected',
          updatedAt: DateTime.now(),
        );
        await _db.saveClaim(uid, updated);
        if (mounted) setState(() => _claim = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _generatingFight = false);
    }
  }

  Future<void> _generateAppealLetter() async {
    setState(() => _generatingAppeal = true);
    final profile = context.read<HealthDataProvider>().profile;
    final uid2 = context.read<HealthDataProvider>().uid;
    try {
      final region = regionByCode(_claim.country);

      final prompt =
          '''Write a formal insurance claim appeal letter for a policyholder in ${region.name}, ready to send to the insurer.

Details:
- Policyholder: ${profile?.fullName ?? 'The Policyholder'}
- Insurer: ${_claim.insurer}
- Policy Number: ${_claim.policyNumber}
- Provider/Hospital: ${_claim.hospitalName}
- Service dates: ${_claim.admissionDate}${_claim.dischargeDate.isNotEmpty ? ' to ${_claim.dischargeDate}' : ''}
- Diagnosis: ${_claim.diagnosis}
- Rejected Claim Amount: ${formatMoney(_claim.effectiveAmount, _claim.currencyCode)}
- Rejection Reason: ${_claim.rejectionReason}

The letter must:
1. Clearly identify the claim and the rejection
2. Professionally dispute the rejection grounds
3. Cite relevant policy terms and ${region.name} protections (${region.keyRights})
4. Reference the right to escalate to ${region.ombudsman} and ${region.regulator} if unresolved
5. Request written reconsideration within a clear, reasonable deadline
6. Be firm but professional

Format as a proper business letter (sender block, date, recipient, subject line, salutation, body paragraphs, closing). Use ${region.currencyCode} for amounts. Output only the letter.''';

      final response =
          await ChatbotService().getGeminiResponse(prompt);

      if (uid2 != null) {
        final updated = _claim.copyWith(
          appealLetter: response,
          updatedAt: DateTime.now(),
        );
        await _db.saveClaim(uid2, updated);
        if (mounted) setState(() => _claim = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _generatingAppeal = false);
    }
  }

  Future<void> _auditBills() async {
    if (_claim.expenses.isEmpty) {
      _snack('Add itemized bills first, then run the audit.');
      return;
    }
    setState(() => _generatingAudit = true);
    final uid = context.read<HealthDataProvider>().uid;
    try {
      final region = regionByCode(_claim.country);
      final itemized = _claim.expenses.map((e) {
        final header =
            '- ${kExpenseCategories[e.category] ?? e.category}: ${e.vendor.isEmpty ? 'Unknown provider' : e.vendor} — ${formatMoney(e.amount, _claim.currencyCode)}${e.date.isEmpty ? '' : ' (${e.date})'}';
        final items = e.lineItems.trim();
        if (items.isEmpty) return header;
        final detail = items
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => '    • ${l.trim()}')
            .join('\n');
        return '$header\n$detail';
      }).join('\n');

      final prompt =
          '''You are a medical-billing auditor and patient advocate for ${region.name}. Review these itemized medical bills for likely billing errors and overcharges the patient can dispute to save money. Be rigorous but do not invent charges that are not listed.

Case: ${_claim.caseType == 'outpatient' ? 'Outpatient' : 'Inpatient'}
Diagnosis/Reason: ${_claim.diagnosis.isEmpty ? 'Not specified' : _claim.diagnosis}
Provider: ${_claim.hospitalName.isEmpty ? 'Not specified' : _claim.hospitalName}
Currency: ${_claim.currencyCode.isEmpty ? region.currencyCode : _claim.currencyCode}
Total billed: ${formatMoney(_claim.totalExpenses, _claim.currencyCode)}

Itemized bills:
$itemized

Analyze and report:
1. Likely billing ERRORS — duplicate charges, unbundling, upcoding, or services unrelated to the diagnosis.
2. Charges that look ABOVE typical/fair rates in ${region.name} — flag them with a reasonable expected range.
3. Items that SHOULD be covered or waived (and why), given ${region.keyRights}.
4. Surprise / balance-billing red flags under ${region.name} rules.
5. For EACH flagged item: the estimated potential saving and the exact step to dispute it.
6. A clear TOTAL estimated potential saving (a range is fine).

If a charge looks reasonable, say so briefly. Use clear headings and ${region.currencyCode} amounts. End with a one-line summary of total potential savings.''';

      final response = await ChatbotService().getGeminiResponse(prompt);
      if (uid != null) {
        final updated =
            _claim.copyWith(auditReport: response, updatedAt: DateTime.now());
        await _db.saveClaim(uid, updated);
        if (mounted) setState(() => _claim = updated);
      } else if (mounted) {
        setState(() => _claim = _claim.copyWith(auditReport: response));
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _generatingAudit = false);
    }
  }

  Future<void> _generateDisputeLetter() async {
    if (_claim.auditReport.isEmpty) {
      _snack('Run the bill audit first, then draft the dispute letter.');
      return;
    }
    setState(() => _generatingDispute = true);
    final profile = context.read<HealthDataProvider>().profile;
    final uid = context.read<HealthDataProvider>().uid;
    try {
      final region = regionByCode(_claim.country);
      final prompt =
          '''Write a formal medical-bill DISPUTE letter addressed to the billing department of the healthcare provider (not the insurer), for a patient in ${region.name}. The patient is contesting specific overcharges and billing errors found in an audit.

Patient: ${profile?.fullName ?? 'The Patient'}
Provider: ${_claim.hospitalName.isEmpty ? 'the provider' : _claim.hospitalName}
Account/Policy ref: ${_claim.policyNumber.isEmpty ? 'N/A' : _claim.policyNumber}
Total billed: ${formatMoney(_claim.totalExpenses, _claim.currencyCode)} (${_claim.currencyCode.isEmpty ? region.currencyCode : _claim.currencyCode})

Audit findings to base the dispute on:
${_claim.auditReport}

The letter must:
1. Request a fully itemized bill and the medical records/codes if not already provided.
2. List each disputed charge and clearly state why it is incorrect or excessive (use the audit findings).
3. Reference the patient's rights in ${region.name} (${region.keyRights}) and the option to escalate to ${region.ombudsman}.
4. Request correction/refund of the specific amounts and a written response within a reasonable deadline.
5. Be firm, factual, and professional.

Format as a proper business letter (sender block, date, recipient billing department, subject line, salutation, body, closing). Use ${region.currencyCode} for amounts. Output only the letter.''';

      final response = await ChatbotService().getGeminiResponse(prompt);
      if (uid != null) {
        final updated = _claim.copyWith(
            disputeLetter: response, updatedAt: DateTime.now());
        await _db.saveClaim(uid, updated);
        if (mounted) setState(() => _claim = updated);
      } else if (mounted) {
        setState(() => _claim = _claim.copyWith(disputeLetter: response));
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _generatingDispute = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _statusColors[_claim.claimStatus] ?? AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Claim Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.all(AppTheme.xl),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: AppTheme.largeRadius,
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _claim.isApproved
                        ? Icons.check_circle_rounded
                        : _claim.isRejected
                            ? Icons.cancel_rounded
                            : Icons.schedule_rounded,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(_claim.claimStatus),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        formatMoney(_claim.effectiveAmount, _claim.currencyCode),
                        style: AppTheme.headingMedium,
                      ),
                      Text(_claim.insurer, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.lg),

          // Claim info
          _InfoSection(title: 'Claim Information', rows: [
            if (_claim.hospitalName.isNotEmpty)
              _InfoRow(Icons.local_hospital_outlined,
                  _claim.caseType == 'outpatient' ? 'Provider' : 'Hospital',
                  _claim.hospitalName),
            if (_claim.diagnosis.isNotEmpty)
              _InfoRow(Icons.medical_information_outlined, 'Diagnosis',
                  _claim.diagnosis),
            _InfoRow(Icons.numbers_rounded, 'Policy Number',
                _claim.policyNumber.isEmpty ? '—' : _claim.policyNumber),
            if (_claim.admissionDate.isNotEmpty)
              _InfoRow(Icons.calendar_today_outlined,
                  _claim.caseType == 'outpatient' ? 'Visit' : 'Admission',
                  _claim.admissionDate),
            if (_claim.dischargeDate.isNotEmpty)
              _InfoRow(Icons.event_available_outlined, 'Discharge',
                  _claim.dischargeDate),
            _InfoRow(Icons.schedule_rounded, 'Filed On',
                DateFormat('dd MMM yyyy').format(_claim.createdAt)),
          ]),
          const SizedBox(height: AppTheme.lg),

          // Itemized bills
          if (_claim.expenses.isNotEmpty) ...[
            _BillsSection(
                expenses: _claim.expenses, currencyCode: _claim.currencyCode),
            const SizedBox(height: AppTheme.lg),
          ],

          // Bill overcharge audit
          if (_claim.expenses.isNotEmpty) ...[
            _AuditCard(
              loading: _generatingAudit,
              hasReport: _claim.auditReport.isNotEmpty,
              onRun: _generatingAudit ? null : _auditBills,
            ),
            if (_claim.auditReport.isNotEmpty) ...[
              const SizedBox(height: AppTheme.lg),
              _ContentCard(
                title: 'Bill Audit — potential savings',
                icon: Icons.savings_rounded,
                color: AppTheme.successColor,
                content: _claim.auditReport,
                onCopy: () => _copy(_claim.auditReport),
              ),
              const SizedBox(height: AppTheme.md),
              OutlinedButton.icon(
                onPressed:
                    _generatingDispute ? null : _generateDisputeLetter,
                icon: _generatingDispute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.successColor))
                    : const Icon(Icons.edit_document,
                        color: AppTheme.successColor, size: 18),
                label: Text(
                  _generatingDispute
                      ? 'Drafting dispute letter…'
                      : _claim.disputeLetter.isEmpty
                          ? 'Generate dispute letter'
                          : 'Regenerate dispute letter',
                  style: const TextStyle(color: AppTheme.successColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.successColor),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius),
                ),
              ),
              if (_claim.disputeLetter.isNotEmpty) ...[
                const SizedBox(height: AppTheme.md),
                _ContentCard(
                  title: 'Dispute Letter (to provider billing)',
                  icon: Icons.mail_outline_rounded,
                  color: AppTheme.successColor,
                  content: _claim.disputeLetter,
                  onCopy: () => _copy(_claim.disputeLetter),
                ),
              ],
            ],
            const SizedBox(height: AppTheme.lg),
          ],

          // Claim report
          if (_claim.claimReport.isNotEmpty) ...[
            _ContentCard(
              title: 'Claim Report',
              icon: Icons.description_rounded,
              color: AppTheme.infoColor,
              content: _claim.claimReport,
              onCopy: () => _copy(_claim.claimReport),
            ),
            const SizedBox(height: AppTheme.lg),
          ],

          // REJECTION FIGHT SECTION
          if (_claim.isRejected) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.05),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                    color: AppTheme.dangerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded,
                          color: AppTheme.dangerColor, size: 20),
                      SizedBox(width: 8),
                      Text('Claim Rejection — Fight Back',
                          style: TextStyle(
                              color: AppTheme.dangerColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                      'Don\'t give up. Our AI will analyze the rejection and give you a step-by-step legal strategy.',
                      style: AppTheme.bodySmall),
                  const SizedBox(height: AppTheme.md),
                  TextField(
                    controller: _rejectionCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason (from insurer)',
                      hintText:
                          'Paste the rejection reason from the letter...',
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _generatingFight ? null : _analyzeRejection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerColor,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.mediumRadius),
                      ),
                      icon: _generatingFight
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 18),
                      label: Text(
                        _generatingFight
                            ? 'Analyzing...'
                            : 'Analyze & Get Fight Strategy',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],

          // Fight analysis
          if (_claim.fightAnalysis.isNotEmpty) ...[
            _ContentCard(
              title: 'AI Fight Strategy',
              icon: Icons.gavel_rounded,
              color: AppTheme.dangerColor,
              content: _claim.fightAnalysis,
              onCopy: () => _copy(_claim.fightAnalysis),
              extra: Padding(
                padding: const EdgeInsets.only(top: AppTheme.md),
                child: OutlinedButton.icon(
                  onPressed: _generatingAppeal ? null : _generateAppealLetter,
                  icon: _generatingAppeal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor))
                      : const Icon(Icons.description_outlined,
                          color: AppTheme.primaryColor),
                  label: Text(
                    _generatingAppeal
                        ? 'Generating...'
                        : 'Generate Appeal Letter',
                    style: const TextStyle(color: AppTheme.primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.sm,
                        horizontal: AppTheme.lg),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.mediumRadius),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],

          // Appeal letter
          if (_claim.appealLetter.isNotEmpty) ...[
            _ContentCard(
              title: 'Appeal Letter',
              icon: Icons.mail_outline_rounded,
              color: AppTheme.primaryColor,
              content: _claim.appealLetter,
              onCopy: () => _copy(_claim.appealLetter),
            ),
            const SizedBox(height: AppTheme.lg),
          ],

          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    const l = {
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'under_review': 'Under Review',
    };
    return l[s] ?? s;
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall.copyWith(fontSize: 15)),
          const SizedBox(height: AppTheme.md),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySmall),
              Text(value,
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String content;
  final VoidCallback onCopy;
  final Widget? extra;

  const _ContentCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    required this.onCopy,
    this.extra,
  });

  @override
  State<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<_ContentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.content.length > 300
        ? '${widget.content.substring(0, 300)}...'
        : widget.content;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.05),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
            color: widget.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded,
                    size: 18, color: AppTheme.textSecondary),
                onPressed: widget.onCopy,
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            _expanded ? widget.content : preview,
            style: AppTheme.bodySmall.copyWith(height: 1.6),
          ),
          if (widget.content.length > 300)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (widget.extra != null) widget.extra!,
        ],
      ),
    );
  }
}

class _BillsSection extends StatelessWidget {
  final List<CaseExpense> expenses;
  final String currencyCode;
  const _BillsSection({required this.expenses, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Bills (${expenses.length})',
                    style: AppTheme.headingSmall.copyWith(fontSize: 15)),
              ),
              Text(formatMoney(total, currencyCode),
                  style: AppTheme.headingSmall
                      .copyWith(fontSize: 15, color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          for (final e in expenses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    kExpenseCategoryIcons[e.category] ??
                        Icons.receipt_long_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.vendor.isEmpty
                              ? (kExpenseCategories[e.category] ?? 'Bill')
                              : e.vendor,
                          style: AppTheme.bodyMedium
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            kExpenseCategories[e.category] ?? e.category,
                            if (e.date.isNotEmpty) e.date,
                          ].join(' · '),
                          style: AppTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Text(formatMoney(e.amount, currencyCode),
                      style: AppTheme.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Call-to-action card that runs the AI bill-overcharge audit.
class _AuditCard extends StatelessWidget {
  final bool loading;
  final bool hasReport;
  final VoidCallback? onRun;

  const _AuditCard({
    required this.loading,
    required this.hasReport,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderRadius: AppTheme.mediumRadius,
        border:
            Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded,
                  color: AppTheme.successColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Find overcharges & billing errors',
                    style: AppTheme.headingSmall.copyWith(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'AI reviews every bill for duplicate charges, inflated rates, and items that should be covered — and tells you exactly how to dispute them.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRun,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.mediumRadius),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded,
                      color: Colors.white, size: 18),
              label: Text(
                loading
                    ? 'Auditing bills…'
                    : hasReport
                        ? 'Re-run bill audit'
                        : 'Audit my bills',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
