import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/navigation/app_router.dart';
import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios_dropdown.dart';
import '../../theme/ios_pickers.dart';
import 'add_expense_screen.dart';

/// Builds an insurance *case*: a country, an optional linked policy, clinical
/// context, and a set of itemized bills that roll up into a claim total.
class NewClaimScreen extends StatefulWidget {
  const NewClaimScreen({super.key});

  @override
  State<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends State<NewClaimScreen> {
  final _db = FirestoreService();
  bool _saving = false;

  final _titleCtrl = TextEditingController();
  final _policyNumCtrl = TextEditingController();
  final _insurerCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _country = kDefaultRegion.code;
  String _currencyCode = kDefaultRegion.currencyCode;
  String _caseType = 'inpatient'; // inpatient | outpatient
  DateTime? _admissionDate;
  DateTime? _dischargeDate;
  String? _selectedPolicyId;
  final List<CaseExpense> _expenses = [];

  bool get _isInpatient => _caseType == 'inpatient';
  double get _total => _expenses.fold<double>(0, (s, e) => s + e.amount);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _policyNumCtrl.dispose();
    _insurerCtrl.dispose();
    _hospitalCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isAdmission) async {
    final d = await showIosDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => isAdmission ? _admissionDate = d : _dischargeDate = d);
    }
  }

  Future<void> _addOrEditExpense([CaseExpense? existing]) async {
    final uid = context.read<HealthDataProvider>().uid ?? '';
    final result = await Navigator.push<CaseExpense>(
      context,
      CupertinoPageRoute(
        builder: (_) => AddExpenseScreen(
          uid: uid,
          currencyCode: _currencyCode,
          existing: existing,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final idx = _expenses.indexWhere((e) => e.id == result.id);
      if (idx >= 0) {
        _expenses[idx] = result;
      } else {
        _expenses.add(result);
      }
    });
  }

  void _removeExpense(CaseExpense e) =>
      setState(() => _expenses.removeWhere((x) => x.id == e.id));

  Future<void> _save() async {
    if (_insurerCtrl.text.trim().isEmpty) {
      _snack('Insurer name is required.');
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
        title: _titleCtrl.text.trim(),
        country: _country,
        currencyCode: _currencyCode,
        caseType: _caseType,
        hospitalName: _hospitalCtrl.text.trim(),
        admissionDate: _admissionDate != null
            ? DateFormat('dd MMM yyyy').format(_admissionDate!)
            : '',
        dischargeDate: _isInpatient && _dischargeDate != null
            ? DateFormat('dd MMM yyyy').format(_dischargeDate!)
            : '',
        diagnosis: _diagnosisCtrl.text.trim(),
        claimAmount: _total,
        expenses: List<CaseExpense>.from(_expenses),
        claimStatus: 'pending',
      );
      await _db.saveClaim(uid, claim);
      if (!mounted) return;
      // Land in the case itself — that is where the audit, letters and
      // deadlines live.
      final nav = Navigator.of(context);
      nav.pop();
      nav.pushNamed(AppRouter.claimDetail, arguments: claim);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<HealthDataProvider>().uid;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('New Case'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator())
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
          // Case basics
          _Card(children: [
            Text('Case', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF('Title', _titleCtrl,
                hint: 'e.g. Knee surgery – Apr 2026',
                capitalization: TextCapitalization.sentences),
            const SizedBox(height: AppTheme.md),
            IosDropdownFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(labelText: 'Country'),
              items: kInsuranceRegions
                  .map((r) => DropdownMenuItem(
                        value: r.code,
                        child: Text('${r.flag}  ${r.name} (${r.currencyCode})'),
                      ))
                  .toList(),
              onChanged: (code) {
                if (code == null) return;
                setState(() {
                  _country = code;
                  _currencyCode = regionByCode(code).currencyCode;
                });
              },
            ),
            const SizedBox(height: AppTheme.md),
            _CaseTypeToggle(
              value: _caseType,
              onChanged: (v) => setState(() => _caseType = v),
            ),
          ]),
          const SizedBox(height: AppTheme.lg),

          // Policy link
          _Card(children: [
            Text('Policy Details', style: AppTheme.headingSmall),
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
                    child: IosDropdownFormField<String>(
                      initialValue: _selectedPolicyId != null &&
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
                        final policy = policies.firstWhere((p) => p.id == id);
                        setState(() {
                          _selectedPolicyId = id;
                          _insurerCtrl.text = policy.insurer;
                          _policyNumCtrl.text = policy.policyNumber;
                          if (policy.country.isNotEmpty) {
                            _country = policy.country;
                          }
                          if (policy.currencyCode.isNotEmpty) {
                            _currencyCode = policy.currencyCode;
                          } else if (policy.country.isNotEmpty) {
                            _currencyCode =
                                regionByCode(policy.country).currencyCode;
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            _TF('Insurance Company *', _insurerCtrl, hint: 'e.g. Aetna, Bupa'),
            const SizedBox(height: AppTheme.md),
            _TF('Policy Number', _policyNumCtrl, hint: 'Your policy number'),
          ]),
          const SizedBox(height: AppTheme.lg),

          // Clinical context
          _Card(children: [
            Text(_isInpatient ? 'Hospitalization Details' : 'Visit Details',
                style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.lg),
            _TF(_isInpatient ? 'Hospital Name' : 'Clinic / Provider',
                _hospitalCtrl,
                hint: _isInpatient
                    ? 'Hospital where you were treated'
                    : 'Clinic or provider name',
                capitalization: TextCapitalization.words),
            const SizedBox(height: AppTheme.md),
            if (_isInpatient)
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
              )
            else
              _DateField(
                label: 'Visit Date',
                date: _admissionDate,
                onTap: () => _pickDate(true),
              ),
            const SizedBox(height: AppTheme.md),
            _TF('Diagnosis / Reason', _diagnosisCtrl,
                hint: 'Main diagnosis or reason',
                capitalization: TextCapitalization.sentences),
          ]),
          const SizedBox(height: AppTheme.lg),

          // Bills / expenses
          _ExpensesCard(
            expenses: _expenses,
            currencyCode: _currencyCode,
            total: _total,
            onAdd: () => _addOrEditExpense(),
            onEdit: _addOrEditExpense,
            onRemove: _removeExpense,
          ),
          const SizedBox(height: AppTheme.lg),

          _Card(children: [
            _TF('Additional Notes', _notesCtrl,
                hint: 'Any relevant details...',
                maxLines: 3,
                capitalization: TextCapitalization.sentences),
          ]),
          const SizedBox(height: AppTheme.lg),

          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.sparkles, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Once saved, scan the itemized bill or denial letter into this case — '
                    'Clinix audits the charges, drafts the letters and tracks the deadlines.',
                    style: AppTheme.bodySmall.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.xl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Case',
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

class _CaseTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CaseTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label, IconData icon) {
      final sel = value == v;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppTheme.surfaceColor : Colors.transparent,
              borderRadius: AppTheme.smallRadius,
              boxShadow: sel ? AppTheme.cardShadow : null,
              border: sel
                  ? Border.all(color: AppTheme.glassBorder, width: 0.8)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color:
                        sel ? AppTheme.primaryColor : AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        color: sel
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Row(
        children: [
          seg('inpatient', 'Inpatient', CupertinoIcons.building_2_fill),
          seg('outpatient', 'Outpatient', CupertinoIcons.staroflife),
        ],
      ),
    );
  }
}

class _ExpensesCard extends StatelessWidget {
  final List<CaseExpense> expenses;
  final String currencyCode;
  final double total;
  final VoidCallback onAdd;
  final ValueChanged<CaseExpense> onEdit;
  final ValueChanged<CaseExpense> onRemove;

  const _ExpensesCard({
    required this.expenses,
    required this.currencyCode,
    required this.total,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      Row(
        children: [
          Expanded(child: Text('Bills', style: AppTheme.headingSmall)),
          if (expenses.isNotEmpty)
            Text(formatMoney(total, currencyCode),
                style: AppTheme.headingSmall
                    .copyWith(color: AppTheme.primaryColor)),
        ],
      ),
      const SizedBox(height: AppTheme.sm),
      if (expenses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
          child: Text(
            'Add each bill — hospital, pharmacy, lab, etc. You can scan a receipt and the details fill in automatically.',
            style: AppTheme.bodySmall,
          ),
        )
      else
        ...expenses.map((e) => _ExpenseRow(
              expense: e,
              currencyCode: currencyCode,
              onTap: () => onEdit(e),
              onRemove: () => onRemove(e),
            )),
      const SizedBox(height: AppTheme.sm),
      OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(CupertinoIcons.add, color: AppTheme.primaryColor),
        label: const Text('Add bill',
            style: TextStyle(color: AppTheme.primaryColor)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryColor),
          padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
        ),
      ),
    ]);
  }
}

class _ExpenseRow extends StatelessWidget {
  final CaseExpense expense;
  final String currencyCode;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ExpenseRow({
    required this.expense,
    required this.currencyCode,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.smallRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                kExpenseCategoryIcons[expense.category] ??
                    CupertinoIcons.doc_plaintext,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.vendor.isEmpty
                        ? (kExpenseCategories[expense.category] ?? 'Bill')
                        : expense.vendor,
                    style: AppTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      kExpenseCategories[expense.category] ?? expense.category,
                      if (expense.date.isNotEmpty) expense.date,
                      if (expense.aiExtracted) 'scanned',
                    ].join(' · '),
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Text(formatMoney(expense.amount, currencyCode),
                style: AppTheme.labelLarge),
            IconButton(
              icon: const Icon(CupertinoIcons.xmark, size: 18),
              color: AppTheme.textTertiary,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

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
  final int? maxLines;
  final TextCapitalization capitalization;

  const _TF(this.label, this.ctrl,
      {this.hint,
      this.maxLines = 1,
      this.capitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
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
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select date',
            suffixIcon: const Icon(CupertinoIcons.calendar, size: 16),
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
