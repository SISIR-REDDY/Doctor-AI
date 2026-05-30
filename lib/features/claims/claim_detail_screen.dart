import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
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

      final prompt = '''You are an expert insurance claims advisor and consumer rights attorney in India. Analyze this rejected insurance claim and provide a comprehensive fight strategy.

Claim Details:
- Patient: ${profile?.fullName ?? 'Patient'}
- Insurance Company: ${_claim.insurer}
- Policy Number: ${_claim.policyNumber}
- Hospital: ${_claim.hospitalName}
- Diagnosis: ${_claim.diagnosis}
- Claim Amount: ₹${_claim.claimAmount.toInt()}
- Rejection Reason: ${reason.isEmpty ? _claim.rejectionReason : reason}

Please provide:
1. Analysis of the rejection grounds (is it valid or disputable?)
2. Your rights as a policyholder under IRDAI regulations
3. Step-by-step escalation strategy:
   a. Internal appeal to the insurer
   b. Insurance Ombudsman complaint
   c. Consumer Forum / NCDRC option
   d. IRDAI Grievance Cell
4. Key legal provisions and policy clauses to cite
5. Evidence and documents to gather
6. Timeline and deadlines to follow
7. Probability of success assessment

Use clear, actionable language. Be specific about relevant IRDAI regulations and consumer rights laws.''';

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

      final prompt = '''Write a formal insurance claim appeal letter for the following rejected claim. The letter should be professionally written and ready to send to the insurance company.

Details:
- Policyholder: ${profile?.fullName ?? 'The Policyholder'}
- Insurance Company: ${_claim.insurer}
- Policy Number: ${_claim.policyNumber}
- Hospital: ${_claim.hospitalName}
- Admission to Discharge: ${_claim.admissionDate} to ${_claim.dischargeDate}
- Diagnosis: ${_claim.diagnosis}
- Rejected Claim Amount: ₹${_claim.claimAmount.toInt()}
- Rejection Reason: ${_claim.rejectionReason}

Write a formal appeal letter that:
1. Clearly identifies the claim and rejection
2. Professionally disputes the rejection grounds
3. Cites relevant policy terms and IRDAI regulations
4. Requests reconsideration with urgency
5. States intention to escalate if not resolved
6. Is firm but professional in tone

Format as a proper business letter with proper salutation, body paragraphs, and closing.''';

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
                        '₹${NumberFormat('#,##,###').format(_claim.claimAmount.toInt())}',
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
            _InfoRow(Icons.local_hospital_outlined, 'Hospital',
                _claim.hospitalName),
            _InfoRow(Icons.medical_information_outlined, 'Diagnosis',
                _claim.diagnosis),
            _InfoRow(Icons.numbers_rounded, 'Policy Number',
                _claim.policyNumber.isEmpty ? '—' : _claim.policyNumber),
            if (_claim.admissionDate.isNotEmpty)
              _InfoRow(Icons.calendar_today_outlined, 'Admission',
                  _claim.admissionDate),
            if (_claim.dischargeDate.isNotEmpty)
              _InfoRow(Icons.event_available_outlined, 'Discharge',
                  _claim.dischargeDate),
            _InfoRow(Icons.schedule_rounded, 'Filed On',
                DateFormat('dd MMM yyyy').format(_claim.createdAt)),
          ]),
          const SizedBox(height: AppTheme.lg),

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
                  const Text(
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
                icon: const Icon(Icons.copy_rounded,
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
