import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class NewClaimScreen extends StatefulWidget {
  const NewClaimScreen({super.key});

  @override
  State<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends State<NewClaimScreen> {
  final _db = FirestoreService();
  bool _saving = false;
  bool _generatingReport = false;
  String _claimReport = '';

  final _policyNumCtrl = TextEditingController();
  final _insurerCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _admissionDate;
  DateTime? _dischargeDate;
  String? _selectedPolicyId;

  @override
  void dispose() {
    _policyNumCtrl.dispose();
    _insurerCtrl.dispose();
    _hospitalCtrl.dispose();
    _diagnosisCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isAdmission) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() =>
          isAdmission ? _admissionDate = d : _dischargeDate = d);
    }
  }

  Future<void> _generateReport() async {
    if (_insurerCtrl.text.isEmpty || _diagnosisCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fill in insurer and diagnosis first.')));
      return;
    }
    setState(() => _generatingReport = true);
    try {
      final profile = context.read<HealthDataProvider>().profile;

      final prompt = '''Generate a formal insurance claim report for the following case:

Patient: ${profile?.fullName ?? 'Patient'}
Age: ${profile?.age ?? 'Unknown'} years
Insurance Company: ${_insurerCtrl.text.trim()}
Policy Number: ${_policyNumCtrl.text.trim()}
Hospital: ${_hospitalCtrl.text.trim()}
Admission: ${_admissionDate != null ? DateFormat('dd MMM yyyy').format(_admissionDate!) : 'Not specified'}
Discharge: ${_dischargeDate != null ? DateFormat('dd MMM yyyy').format(_dischargeDate!) : 'Not specified'}
Diagnosis: ${_diagnosisCtrl.text.trim()}
Claim Amount: ₹${_amountCtrl.text.trim()}
Additional Notes: ${_notesCtrl.text.trim()}

Please generate a formal, professional claim report that includes:
1. Patient details and case summary
2. Medical necessity statement
3. Itemized treatment summary
4. Claim justification
5. Request for reimbursement

Use professional language suitable for submission to the insurer.''';

      final response =
          await ChatbotService().getGeminiResponse(prompt);
      if (mounted) setState(() => _claimReport = response);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Future<void> _save() async {
    if (_insurerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insurer name is required.')));
      return;
    }
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final claim = InsuranceClaim(
        id: const Uuid().v4(),
        userId: uid,
        policyId: _selectedPolicyId ?? '',
        policyNumber: _policyNumCtrl.text.trim(),
        insurer: _insurerCtrl.text.trim(),
        hospitalName: _hospitalCtrl.text.trim(),
        admissionDate: _admissionDate != null
            ? DateFormat('dd MMM yyyy').format(_admissionDate!)
            : '',
        dischargeDate: _dischargeDate != null
            ? DateFormat('dd MMM yyyy').format(_dischargeDate!)
            : '',
        diagnosis: _diagnosisCtrl.text.trim(),
        claimAmount: double.tryParse(_amountCtrl.text) ?? 0,
        claimStatus: 'pending',
        claimReport: _claimReport,
      );
      await _db.saveClaim(uid, claim);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<HealthDataProvider>().uid;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('File a Claim'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          _Card(children: [
            const Text('Policy Details', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            if (uid != null)
              StreamBuilder<List<InsurancePolicy>>(
                stream: _db.watchPolicies(uid),
                builder: (context, snap) {
                  final policies = snap.data ?? [];
                  if (policies.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.md),
                      child: Text(
                        'No saved policies. Add one under Insurance, or enter details below.',
                        style: AppTheme.bodySmall,
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.md),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPolicyId != null &&
                              policies.any((p) => p.id == _selectedPolicyId)
                          ? _selectedPolicyId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Link to saved policy',
                      ),
                      items: policies
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.insurer} · ${p.policyNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final policy =
                            policies.firstWhere((p) => p.id == id);
                        setState(() {
                          _selectedPolicyId = id;
                          _insurerCtrl.text = policy.insurer;
                          _policyNumCtrl.text = policy.policyNumber;
                        });
                      },
                    ),
                  );
                },
              ),
            _TF('Insurance Company *', _insurerCtrl,
                hint: 'e.g. Star Health'),
            const SizedBox(height: AppTheme.md),
            _TF('Policy Number', _policyNumCtrl,
                hint: 'e.g. HLT-123456789'),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            const Text('Hospitalization Details',
                style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF('Hospital Name', _hospitalCtrl,
                hint: 'Hospital where you were treated',
                capitalization: TextCapitalization.words),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Admission Date',
                    date: _admissionDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Discharge Date',
                    date: _dischargeDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            _TF('Diagnosis / Reason', _diagnosisCtrl,
                hint: 'Main diagnosis or reason for hospitalization',
                capitalization: TextCapitalization.sentences),
            const SizedBox(height: AppTheme.md),
            _TF('Claim Amount (₹)', _amountCtrl,
                hint: 'Total amount claimed',
                keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            _TF('Additional Notes', _notesCtrl,
                hint: 'Any relevant details...',
                maxLines: 3,
                capitalization: TextCapitalization.sentences),
          ]),
          const SizedBox(height: AppTheme.lg),

          // AI Report Generation
          OutlinedButton.icon(
            onPressed: _generatingReport ? null : _generateReport,
            icon: _generatingReport
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor))
                : const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primaryColor),
            label: Text(
              _generatingReport
                  ? 'Generating Report...'
                  : 'Generate AI Claim Report',
              style: const TextStyle(color: AppTheme.primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              side:
                  const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.md, horizontal: AppTheme.lg),
              shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius),
            ),
          ),

          if (_claimReport.isNotEmpty) ...[
            const SizedBox(height: AppTheme.lg),
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_rounded,
                          color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      const Text('AI-Generated Claim Report',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(_claimReport,
                      style: AppTheme.bodySmall.copyWith(height: 1.6)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.xl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
              shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Submit Claim',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );
}

class _TF extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final TextCapitalization capitalization;

  const _TF(this.label, this.ctrl,
      {this.hint,
      this.keyboardType,
      this.maxLines = 1,
      this.capitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: capitalization,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select date',
            suffixIcon:
                const Icon(Icons.calendar_today_rounded, size: 16),
          ),
          controller: TextEditingController(
              text: date != null
                  ? DateFormat('dd MMM yyyy').format(date!)
                  : ''),
        ),
      ),
    );
  }
}
