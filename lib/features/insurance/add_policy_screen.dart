import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class AddPolicyScreen extends StatefulWidget {
  final InsurancePolicy? existingPolicy;
  const AddPolicyScreen({super.key, this.existingPolicy});

  @override
  State<AddPolicyScreen> createState() => _AddPolicyScreenState();
}

class _AddPolicyScreenState extends State<AddPolicyScreen> {
  final _db = FirestoreService();
  bool _saving = false;

  late TextEditingController _insurerCtrl;
  late TextEditingController _policyNumCtrl;
  late TextEditingController _coverageCtrl;
  late TextEditingController _premiumCtrl;
  late TextEditingController _nomineeNameCtrl;
  late TextEditingController _nomineeRelCtrl;
  late TextEditingController _notesCtrl;

  String _policyType = 'health';
  String _frequency = 'annual';
  DateTime? _startDate;
  DateTime? _renewalDate;
  bool _isActive = true;

  final _policyTypes = [
    'health',
    'term',
    'critical_illness',
    'accidental',
    'other'
  ];
  final _frequencies = ['monthly', 'quarterly', 'annual'];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPolicy;
    _insurerCtrl = TextEditingController(text: p?.insurer ?? '');
    _policyNumCtrl = TextEditingController(text: p?.policyNumber ?? '');
    _coverageCtrl = TextEditingController(
        text: p != null && p.coverageAmount > 0
            ? '${p.coverageAmount.toInt()}'
            : '');
    _premiumCtrl = TextEditingController(
        text: p != null && p.premiumAmount > 0
            ? '${p.premiumAmount.toInt()}'
            : '');
    _nomineeNameCtrl =
        TextEditingController(text: p?.nomineeName ?? '');
    _nomineeRelCtrl =
        TextEditingController(text: p?.nomineeRelation ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _policyType = p?.policyType ?? 'health';
    _frequency = p?.premiumFrequency ?? 'annual';
    _isActive = p?.isActive ?? true;
    _startDate = p != null && p.startDate.isNotEmpty
        ? DateTime.tryParse(p.startDate)
        : null;
    _renewalDate = p != null && p.renewalDate.isNotEmpty
        ? DateTime.tryParse(p.renewalDate)
        : null;
  }

  @override
  void dispose() {
    _insurerCtrl.dispose();
    _policyNumCtrl.dispose();
    _coverageCtrl.dispose();
    _premiumCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _nomineeRelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
    if (d != null) setState(() => isStart ? _startDate = d : _renewalDate = d);
  }

  Future<void> _save() async {
    if (_insurerCtrl.text.trim().isEmpty ||
        _policyNumCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Insurer name and policy number are required.')));
      return;
    }
    final uid = context.read<HealthDataProvider>().uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final policy = InsurancePolicy(
        id: widget.existingPolicy?.id ?? const Uuid().v4(),
        userId: uid,
        insurer: _insurerCtrl.text.trim(),
        policyNumber: _policyNumCtrl.text.trim(),
        policyType: _policyType,
        coverageAmount: double.tryParse(_coverageCtrl.text) ?? 0,
        premiumAmount: double.tryParse(_premiumCtrl.text) ?? 0,
        premiumFrequency: _frequency,
        startDate:
            _startDate != null ? _startDate!.toIso8601String().split('T').first : '',
        renewalDate: _renewalDate != null
            ? _renewalDate!.toIso8601String().split('T').first
            : '',
        nomineeName: _nomineeNameCtrl.text.trim(),
        nomineeRelation: _nomineeRelCtrl.text.trim(),
        isActive: _isActive,
        notes: _notesCtrl.text.trim(),
        createdAt: widget.existingPolicy?.createdAt,
      );
      await _db.savePolicy(uid, policy);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPolicy != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Policy' : 'Add Policy'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
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
            const Text('Policy Details',
                style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF('Insurance Company *', _insurerCtrl,
                hint: 'e.g. HDFC ERGO, Star Health'),
            const SizedBox(height: AppTheme.md),
            _TF('Policy Number *', _policyNumCtrl,
                hint: 'e.g. HLT-123456789'),
            const SizedBox(height: AppTheme.md),
            _DD<String>(
              label: 'Policy Type',
              value: _policyType,
              items: _policyTypes,
              display: (t) => _typeLabel(t),
              onChanged: (v) => setState(() => _policyType = v!),
            ),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            const Text('Coverage & Premium',
                style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF('Coverage Amount (₹)', _coverageCtrl,
                hint: 'e.g. 500000',
                keyboardType: TextInputType.number),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                Expanded(
                  child: _TF('Premium Amount (₹)', _premiumCtrl,
                      hint: 'e.g. 12000',
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DD<String>(
                    label: 'Frequency',
                    value: _frequency,
                    items: _frequencies,
                    display: (f) => f[0].toUpperCase() + f.substring(1),
                    onChanged: (v) =>
                        setState(() => _frequency = v!),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            const Text('Dates', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Renewal Date',
                    date: _renewalDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            const Text('Nominee', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF('Nominee Name', _nomineeNameCtrl,
                hint: 'Full name',
                capitalization: TextCapitalization.words),
            const SizedBox(height: AppTheme.md),
            _TF('Relationship', _nomineeRelCtrl,
                hint: 'e.g. Spouse, Child',
                capitalization: TextCapitalization.words),
          ]),
          const SizedBox(height: AppTheme.lg),
          _Card(children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Policy',
                          style: AppTheme.bodyMedium),
                      Text('Is this policy currently active?',
                          style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: AppTheme.successColor,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            _TF('Notes', _notesCtrl,
                hint: 'Any additional notes...',
                maxLines: 2,
                capitalization: TextCapitalization.sentences),
          ]),
          const SizedBox(height: AppTheme.xxl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
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
                : Text(isEdit ? 'Update Policy' : 'Add Policy',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'health': 'Health Insurance',
      'term': 'Term Life',
      'critical_illness': 'Critical Illness',
      'accidental': 'Accidental',
      'other': 'Other',
    };
    return labels[type] ?? type;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children),
    );
  }
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

class _DD<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) display;
  final ValueChanged<T?> onChanged;

  const _DD({
    required this.label,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) =>
                DropdownMenuItem(value: i, child: Text(display(i))))
            .toList(),
        onChanged: onChanged,
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
