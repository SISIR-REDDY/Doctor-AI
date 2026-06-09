import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/health_data_provider.dart';
import '../../models/patient_models.dart';
import '../../theme/app_theme.dart';

class PatientOnboardingScreen extends StatefulWidget {
  /// Called after the patient profile is saved successfully so the host
  /// (AuthGate) can move the user on to the home screen.
  final VoidCallback? onComplete;

  const PatientOnboardingScreen({super.key, this.onComplete});

  @override
  State<PatientOnboardingScreen> createState() =>
      _PatientOnboardingScreenState();
}

class _PatientOnboardingScreenState extends State<PatientOnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _saving = false;

  // Page 1 — basic info
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Male';
  String _bloodGroup = 'Unknown';

  // Page 2 — body metrics + emergency contact
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  String _emergencyRelation = 'Spouse';

  final _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown'
  ];
  final _relations = [
    'Spouse', 'Parent', 'Sibling', 'Child', 'Friend', 'Other'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _next() {
    if (_page == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) {
        _showError('Please enter your first name');
        return;
      }
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      setState(() => _page = 1);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final provider = context.read<HealthDataProvider>();

    setState(() => _saving = true);
    try {
      final profile = PatientProfile(
        id: user.uid,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dateOfBirth: _dob?.toIso8601String().split('T').first ?? '',
        gender: _gender,
        bloodGroup: _bloodGroup,
        height: double.tryParse(_heightCtrl.text) ?? 0,
        weight: double.tryParse(_weightCtrl.text) ?? 0,
        contactNumber: _phoneCtrl.text.trim(),
        email: user.email ?? '',
        emergencyContactName: _emergencyNameCtrl.text.trim(),
        emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
        emergencyContactRelation: _emergencyRelation,
      );
      await provider.saveProfile(profile);
      if (mounted) setState(() => _saving = false);
      // Profile saved — hand control back to AuthGate to show the home screen.
      widget.onComplete?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.dangerColor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _Header(page: _page),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Page1(
                    firstNameCtrl: _firstNameCtrl,
                    lastNameCtrl: _lastNameCtrl,
                    dob: _dob,
                    gender: _gender,
                    bloodGroup: _bloodGroup,
                    genders: _genders,
                    bloodGroups: _bloodGroups,
                    onPickDob: _pickDob,
                    onGenderChanged: (v) => setState(() => _gender = v!),
                    onBloodGroupChanged: (v) =>
                        setState(() => _bloodGroup = v!),
                  ),
                  _Page2(
                    heightCtrl: _heightCtrl,
                    weightCtrl: _weightCtrl,
                    phoneCtrl: _phoneCtrl,
                    emergencyNameCtrl: _emergencyNameCtrl,
                    emergencyPhoneCtrl: _emergencyPhoneCtrl,
                    emergencyRelation: _emergencyRelation,
                    relations: _relations,
                    onRelationChanged: (v) =>
                        setState(() => _emergencyRelation = v!),
                  ),
                ],
              ),
            ),
            _Footer(
              page: _page,
              saving: _saving,
              onBack: _page == 0
                  ? null
                  : () {
                      _pageController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut);
                      setState(() => _page = 0);
                    },
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int page;
  const _Header({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Clinix AI',
                  style: AppTheme.headingSmall
                      .copyWith(color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: AppTheme.xl),
          Text(
            page == 0 ? 'Tell us about\nyourself' : 'A few more\ndetails',
            style: AppTheme.headingLarge.copyWith(height: 1.1),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            page == 0
                ? 'Step 1 of 2 — Basic information'
                : 'Step 2 of 2 — Health metrics & emergency contact',
            style:
                AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.lg),
          ClipRRect(
            borderRadius: AppTheme.smallRadius,
            child: LinearProgressIndicator(
              value: page == 0 ? 0.5 : 1.0,
              backgroundColor: AppTheme.dividerColor,
              color: AppTheme.primaryColor,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 1 ────────────────────────────────────────────────────────────────────

class _Page1 extends StatelessWidget {
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final DateTime? dob;
  final String gender;
  final String bloodGroup;
  final List<String> genders;
  final List<String> bloodGroups;
  final VoidCallback onPickDob;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onBloodGroupChanged;

  const _Page1({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.dob,
    required this.gender,
    required this.bloodGroup,
    required this.genders,
    required this.bloodGroups,
    required this.onPickDob,
    required this.onGenderChanged,
    required this.onBloodGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _field('First Name', firstNameCtrl,
                    hint: 'e.g. Rahul'),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child:
                    _field('Last Name', lastNameCtrl, hint: 'e.g. Sharma'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          GestureDetector(
            onTap: onPickDob,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: dob == null
                      ? 'Tap to select'
                      : '${dob!.day}/${dob!.month}/${dob!.year}',
                  suffixIcon: const Icon(Icons.calendar_today_rounded,
                      size: 18),
                ),
                controller: TextEditingController(
                  text: dob == null
                      ? ''
                      : '${dob!.day}/${dob!.month}/${dob!.year}',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          _Dropdown<String>(
            label: 'Gender',
            value: gender,
            items: genders,
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: AppTheme.lg),
          _Dropdown<String>(
            label: 'Blood Group',
            value: bloodGroup,
            items: bloodGroups,
            onChanged: onBloodGroupChanged,
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint}) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, hintText: hint),
        textCapitalization: TextCapitalization.words,
      );
}

// ── Page 2 ────────────────────────────────────────────────────────────────────

class _Page2 extends StatelessWidget {
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emergencyNameCtrl;
  final TextEditingController emergencyPhoneCtrl;
  final String emergencyRelation;
  final List<String> relations;
  final ValueChanged<String?> onRelationChanged;

  const _Page2({
    required this.heightCtrl,
    required this.weightCtrl,
    required this.phoneCtrl,
    required this.emergencyNameCtrl,
    required this.emergencyPhoneCtrl,
    required this.emergencyRelation,
    required this.relations,
    required this.onRelationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    hintText: 'cm',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: TextFormField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    hintText: 'kg',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Your Phone Number',
              hintText: 'Phone number (with country code)',
              prefixIcon: Icon(Icons.phone_rounded, size: 18),
            ),
          ),
          const SizedBox(height: AppTheme.xxl),
          Text('Emergency Contact',
              style: AppTheme.headingSmall.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('We will only use this in case of an emergency',
              style: AppTheme.bodySmall),
          const SizedBox(height: AppTheme.lg),
          TextFormField(
            controller: emergencyNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Contact Name',
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppTheme.lg),
          TextFormField(
            controller: emergencyPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact Phone',
              hintText: 'Phone number (with country code)',
              prefixIcon: Icon(Icons.call_outlined, size: 18),
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          _Dropdown<String>(
            label: 'Relationship',
            value: emergencyRelation,
            items: relations,
            onChanged: onRelationChanged,
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int page;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const _Footer({
    required this.page,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.dividerColor),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.lg, vertical: AppTheme.md),
                shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.mediumRadius),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: AppTheme.md),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: saving ? null : onNext,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.md + 2),
                shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.mediumRadius),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      page == 0 ? 'Next' : 'Get Started',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Dropdown ───────────────────────────────────────────────────────────

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((i) => DropdownMenuItem<T>(
                value: i,
                child: Text(i.toString()),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
