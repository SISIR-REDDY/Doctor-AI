import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/insurance_regions.dart';
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
  late TextEditingController _planNameCtrl;
  late TextEditingController _memberIdCtrl;
  late TextEditingController _deductibleCtrl;
  late TextEditingController _deductibleFamilyCtrl;
  late TextEditingController _oopCtrl;
  late TextEditingController _oopFamilyCtrl;
  late TextEditingController _copayPcpCtrl;
  late TextEditingController _copaySpecialistCtrl;
  late TextEditingController _copayErCtrl;
  late TextEditingController _coinsuranceCtrl;
  late TextEditingController _networkCtrl;

  String _policyType = 'health';
  String _frequency = 'annual';
  String _country = kDefaultRegion.code;
  DateTime? _startDate;
  DateTime? _renewalDate;
  bool _isActive = true;

  InsuranceRegion get _region => regionByCode(_country);
  final _countryCodes = kInsuranceRegions.map((r) => r.code).toList();
  static const _frequencies = ['monthly', 'quarterly', 'annual'];

  static const _policyTypes = [
    ('health', 'Health', Icons.favorite_rounded, Color(0xFFFF3B30)),
    ('term', 'Term Life', Icons.shield_rounded, Color(0xFF007AFF)),
    ('critical_illness', 'Critical Illness', Icons.warning_rounded, Color(0xFFFF9500)),
    ('accidental', 'Accidental', Icons.bolt_rounded, Color(0xFF5856D6)),
    ('other', 'Other', Icons.more_horiz_rounded, Color(0xFF8E8E93)),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPolicy;
    _insurerCtrl = TextEditingController(text: p?.insurer ?? '');
    _policyNumCtrl = TextEditingController(text: p?.policyNumber ?? '');
    _coverageCtrl = TextEditingController(
        text: p != null && p.coverageAmount > 0 ? '${p.coverageAmount.toInt()}' : '');
    _premiumCtrl = TextEditingController(
        text: p != null && p.premiumAmount > 0 ? '${p.premiumAmount.toInt()}' : '');
    _nomineeNameCtrl = TextEditingController(text: p?.nomineeName ?? '');
    _nomineeRelCtrl = TextEditingController(text: p?.nomineeRelation ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    String money(double v) => v > 0 ? (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)) : '';
    _planNameCtrl = TextEditingController(text: p?.planName ?? '');
    _memberIdCtrl = TextEditingController(text: p?.memberId ?? '');
    _deductibleCtrl = TextEditingController(text: money(p?.deductibleIndividual ?? 0));
    _deductibleFamilyCtrl = TextEditingController(text: money(p?.deductibleFamily ?? 0));
    _oopCtrl = TextEditingController(text: money(p?.outOfPocketMaxIndividual ?? 0));
    _oopFamilyCtrl = TextEditingController(text: money(p?.outOfPocketMaxFamily ?? 0));
    _copayPcpCtrl = TextEditingController(text: money(p?.copayPrimaryCare ?? 0));
    _copaySpecialistCtrl = TextEditingController(text: money(p?.copaySpecialist ?? 0));
    _copayErCtrl = TextEditingController(text: money(p?.copayEmergency ?? 0));
    _coinsuranceCtrl = TextEditingController(text: money(p?.coinsurancePercent ?? 0));
    _networkCtrl = TextEditingController(text: p?.networkType ?? '');
    _policyType = p?.policyType ?? 'health';
    _frequency = p?.premiumFrequency ?? 'annual';
    _country = (p != null && p.country.isNotEmpty)
        ? p.country
        : (p != null && p.currencyCode.isNotEmpty)
            ? regionByCurrency(p.currencyCode).code
            : kDefaultRegion.code;
    _isActive = p?.isActive ?? true;
    _startDate = p != null && p.startDate.isNotEmpty ? DateTime.tryParse(p.startDate) : null;
    _renewalDate =
        p != null && p.renewalDate.isNotEmpty ? DateTime.tryParse(p.renewalDate) : null;
  }

  @override
  void dispose() {
    for (final c in [
      _insurerCtrl, _policyNumCtrl, _coverageCtrl, _premiumCtrl,
      _nomineeNameCtrl, _nomineeRelCtrl, _notesCtrl, _planNameCtrl,
      _memberIdCtrl, _deductibleCtrl, _deductibleFamilyCtrl, _oopCtrl,
      _oopFamilyCtrl, _copayPcpCtrl, _copaySpecialistCtrl, _copayErCtrl,
      _coinsuranceCtrl, _networkCtrl,
    ]) {
      c.dispose();
    }
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
    if (_insurerCtrl.text.trim().isEmpty || _policyNumCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insurer name and policy number are required.')),
      );
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
        country: _country,
        currencyCode: _region.currencyCode,
        coverageAmount: double.tryParse(_coverageCtrl.text) ?? 0,
        premiumAmount: double.tryParse(_premiumCtrl.text) ?? 0,
        premiumFrequency: _frequency,
        startDate: _startDate != null ? _startDate!.toIso8601String().split('T').first : '',
        renewalDate:
            _renewalDate != null ? _renewalDate!.toIso8601String().split('T').first : '',
        nomineeName: _nomineeNameCtrl.text.trim(),
        nomineeRelation: _nomineeRelCtrl.text.trim(),
        isActive: _isActive,
        notes: _notesCtrl.text.trim(),
        planName: _planNameCtrl.text.trim(),
        memberId: _memberIdCtrl.text.trim(),
        groupNumber: widget.existingPolicy?.groupNumber ?? '',
        deductibleIndividual: _n(_deductibleCtrl),
        deductibleFamily: _n(_deductibleFamilyCtrl),
        outOfPocketMaxIndividual: _n(_oopCtrl),
        outOfPocketMaxFamily: _n(_oopFamilyCtrl),
        copayPrimaryCare: _n(_copayPcpCtrl),
        copaySpecialist: _n(_copaySpecialistCtrl),
        copayEmergency: _n(_copayErCtrl),
        coinsurancePercent: _n(_coinsuranceCtrl),
        networkType: _networkCtrl.text.trim(),
        exclusions: widget.existingPolicy?.exclusions ?? const [],
        waitingPeriods: widget.existingPolicy?.waitingPeriods ?? const [],
        documentId: widget.existingPolicy?.documentId ?? '',
        createdAt: widget.existingPolicy?.createdAt,
      );
      await _db.savePolicy(uid, policy);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPolicy != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _saving
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : TextButton(
                        onPressed: _save,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Save',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroBar(isEdit: isEdit),
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─ Policy Details ─
                _Section(
                  icon: Icons.policy_rounded,
                  title: 'Policy Details',
                  color: AppTheme.primaryColor,
                  children: [
                    _field(
                      controller: _insurerCtrl,
                      label: 'Insurance Company *',
                      hint: 'e.g. Aetna, Bupa, Star Health',
                      icon: Icons.business_rounded,
                      color: AppTheme.primaryColor,
                      capitalize: TextCapitalization.words,
                    ),
                    _field(
                      controller: _policyNumCtrl,
                      label: 'Policy Number *',
                      hint: 'e.g. HLT-123456789',
                      icon: Icons.numbers_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    // Country dropdown — inline, no icon Row
                    DropdownButtonFormField<String>(
                      initialValue: _country,
                      isExpanded: true,
                      decoration: _dec(
                        'Country',
                        Icons.public_rounded,
                        AppTheme.primaryColor,
                      ),
                      selectedItemBuilder: (_) => _countryCodes.map((c) {
                        final r = regionByCode(c);
                        return Text(
                          '${r.flag}  ${r.name} (${r.currencyCode})',
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList(),
                      items: _countryCodes.map((c) {
                        final r = regionByCode(c);
                        return DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${r.flag}  ${r.name} (${r.currencyCode})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _country = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Policy Type ─
                _Section(
                  icon: Icons.category_rounded,
                  title: 'Policy Type',
                  color: AppTheme.secondaryColor,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.4,
                      children: _policyTypes.map((t) {
                        final (id, label, icon, color) = t;
                        final sel = _policyType == id;
                        return GestureDetector(
                          onTap: () => setState(() => _policyType = id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: sel
                                  ? color.withValues(alpha: 0.15)
                                  : AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? color : AppTheme.dividerColor,
                                width: sel ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon,
                                    color: sel ? color : AppTheme.textTertiary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: sel ? color : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Coverage & Premium ─
                _Section(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Coverage & Premium',
                  color: AppTheme.successColor,
                  children: [
                    _field(
                      controller: _coverageCtrl,
                      label: 'Coverage Amount (${_region.currencySymbol})',
                      hint: 'e.g. 500000',
                      icon: Icons.shield_rounded,
                      color: AppTheme.successColor,
                      keyboardType: TextInputType.number,
                    ),
                    _field(
                      controller: _premiumCtrl,
                      label: 'Premium Amount (${_region.currencySymbol})',
                      hint: 'e.g. 12000',
                      icon: Icons.payments_rounded,
                      color: AppTheme.successColor,
                      keyboardType: TextInputType.number,
                    ),
                    // Frequency segmented control
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Payment Frequency',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.textSecondary)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: _frequencies.map((f) {
                              final sel = _frequency == f;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _frequency = f),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppTheme.successColor
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      boxShadow: sel
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.successColor
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      f[0].toUpperCase() + f.substring(1),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Dates ─
                _Section(
                  icon: Icons.date_range_rounded,
                  title: 'Policy Dates',
                  color: AppTheme.accentColor,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Start Date',
                            date: _startDate,
                            color: AppTheme.successColor,
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            icon: Icons.refresh_rounded,
                            label: 'Renewal Date',
                            date: _renewalDate,
                            color: AppTheme.accentColor,
                            onTap: () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Cost sharing (what you pay) ─
                _Section(
                  icon: Icons.pie_chart_rounded,
                  title: 'What you pay',
                  color: AppTheme.warningColor,
                  children: [
                    _field(
                      controller: _planNameCtrl,
                      label: 'Plan name',
                      hint: 'e.g. Silver PPO 3000',
                      icon: Icons.badge_rounded,
                      color: AppTheme.warningColor,
                      capitalize: TextCapitalization.words,
                    ),
                    _field(
                      controller: _memberIdCtrl,
                      label: 'Member ID',
                      hint: 'As printed on your card',
                      icon: Icons.credit_card_rounded,
                      color: AppTheme.warningColor,
                    ),
                    Row(children: [
                      Expanded(
                        child: _field(
                          controller: _deductibleCtrl,
                          label: 'Deductible (${_region.currencySymbol})',
                          hint: 'individual',
                          icon: Icons.remove_circle_outline_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _deductibleFamilyCtrl,
                          label: 'Family',
                          hint: 'optional',
                          icon: Icons.group_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: _field(
                          controller: _oopCtrl,
                          label: 'Out-of-pocket max',
                          hint: 'individual',
                          icon: Icons.vertical_align_top_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _oopFamilyCtrl,
                          label: 'Family',
                          hint: 'optional',
                          icon: Icons.group_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: _field(
                          controller: _copayPcpCtrl,
                          label: 'Copay: GP',
                          hint: '0',
                          icon: Icons.medical_services_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _copaySpecialistCtrl,
                          label: 'Specialist',
                          hint: '0',
                          icon: Icons.person_search_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _copayErCtrl,
                          label: 'ER',
                          hint: '0',
                          icon: Icons.emergency_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: _field(
                          controller: _coinsuranceCtrl,
                          label: 'Coinsurance %',
                          hint: 'e.g. 20',
                          icon: Icons.percent_rounded,
                          color: AppTheme.warningColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _networkCtrl,
                          label: 'Network',
                          hint: 'PPO / HMO / …',
                          icon: Icons.hub_rounded,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Nominee / Beneficiary ─
                _Section(
                  icon: Icons.person_pin_rounded,
                  title: _region.beneficiaryTerm,
                  color: AppTheme.neurologyColor,
                  children: [
                    _field(
                      controller: _nomineeNameCtrl,
                      label: '${_region.beneficiaryTerm} Name',
                      hint: 'Full name',
                      icon: Icons.person_rounded,
                      color: AppTheme.neurologyColor,
                      capitalize: TextCapitalization.words,
                    ),
                    _field(
                      controller: _nomineeRelCtrl,
                      label: 'Relationship',
                      hint: 'e.g. Spouse, Child',
                      icon: Icons.family_restroom_rounded,
                      color: AppTheme.neurologyColor,
                      capitalize: TextCapitalization.words,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─ Settings ─
                _Section(
                  icon: Icons.tune_rounded,
                  title: 'Settings',
                  color: AppTheme.infoColor,
                  children: [
                    // Active toggle card
                    GestureDetector(
                      onTap: () => setState(() => _isActive = !_isActive),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isActive
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isActive
                                ? AppTheme.successColor.withValues(alpha: 0.4)
                                : AppTheme.dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: _isActive
                                  ? AppTheme.successColor
                                  : AppTheme.textTertiary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isActive
                                    ? 'Active policy'
                                    : 'Inactive policy',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _isActive
                                      ? AppTheme.successColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (v) =>
                                  setState(() => _isActive = v),
                              activeTrackColor:
                                  AppTheme.successColor.withValues(alpha: 0.4),
                              activeThumbColor: AppTheme.successColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _notesCtrl,
                      label: 'Notes (optional)',
                      hint: 'Any additional notes…',
                      icon: Icons.notes_rounded,
                      color: AppTheme.infoColor,
                      maxLines: 2,
                      capitalize: TextCapitalization.sentences,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─ Save button ─
                _GradientSaveButton(
                  label: isEdit ? 'Update Policy' : 'Add Policy',
                  icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  loading: _saving,
                  onTap: _save,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Builds a consistent TextField with icon prefix
  static double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization capitalize = TextCapitalization.none,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: capitalize,
        decoration: _dec(label, icon, color, hint: hint),
      );

  // Builds a consistent InputDecoration with a coloured circle prefix icon
  InputDecoration _dec(String label, IconData icon, Color color,
      {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
      );
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _HeroBar extends StatelessWidget {
  final bool isEdit;
  const _HeroBar({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0055E5), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Policy' : 'New Policy',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        isEdit
                            ? 'Update your insurance details'
                            : 'Add your insurance coverage',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coloured header band
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.04),
              ]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                left: BorderSide(color: color, width: 3),
                bottom: BorderSide(
                    color: color.withValues(alpha: 0.15), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Body — each child separated by a thin divider
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 20,
                      thickness: 0.5,
                      color: AppTheme.dividerColor,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date tile ─────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;
  final Color color;
  final VoidCallback onTap;

  const _DateTile({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDate ? color.withValues(alpha: 0.08) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate ? color.withValues(alpha: 0.4) : AppTheme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: hasDate ? color : AppTheme.textTertiary, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasDate ? color : AppTheme.textTertiary,
                  )),
            ]),
            const SizedBox(height: 5),
            Text(
              hasDate ? DateFormat('dd MMM yyyy').format(date!) : 'Tap to set',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasDate ? FontWeight.w700 : FontWeight.w400,
                color: hasDate ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient save button ──────────────────────────────────────────────────────

class _GradientSaveButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _GradientSaveButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: loading
              ? LinearGradient(
                  colors: [AppTheme.dividerColor, AppTheme.dividerColor])
              : const LinearGradient(
                  colors: [Color(0xFF0055E5), Color(0xFF5856D6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}
