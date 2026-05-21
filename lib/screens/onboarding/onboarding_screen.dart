import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home_dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final PageController _pageController = PageController();

  int _page = 0;
  bool _isSaving = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _firstNameCtrl    = TextEditingController();
  final _lastNameCtrl     = TextEditingController();
  final _yearsExpCtrl     = TextEditingController();
  final _specialtyCtrl    = TextEditingController();
  final _subCtrl          = TextEditingController();
  final _hospitalCtrl     = TextEditingController();
  final _deptCtrl         = TextEditingController();
  final _licenseCtrl      = TextEditingController();
  final _regCtrl          = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _phoneCtrl        = TextEditingController();
  final _avgPatientsCtrl  = TextEditingController();

  String? _degree;
  String? _country;
  String? _council;
  String? _practiceType;
  String? _emrSystem;
  final Set<String> _langs = {'English'};

  // ─── Static data ─────────────────────────────────────────────────────────
  static const _degrees = [
    'MBBS','MD','MS','BDS','MDS','DO','DM','MCh','DNB','FRCS','FRCP','MBChB','BMBS','PhD',
  ];
  static const _specialties = [
    'General Medicine','General Surgery','Cardiology','Neurology','Orthopedics',
    'Pediatrics','Gynecology & Obstetrics','Dermatology','Psychiatry','Radiology',
    'Anesthesiology','Oncology','Nephrology','Gastroenterology','Pulmonology',
    'Endocrinology','Rheumatology','Emergency Medicine','Critical Care','Ophthalmology',
    'ENT','Urology','Hematology','Infectious Disease','Family Medicine',
    'Geriatrics','Palliative Care','Sports Medicine','Plastic Surgery',
    'Vascular Surgery','Cardiothoracic Surgery','Neurosurgery',
  ];
  static const _practiceTypes = [
    'Government Hospital','Private Hospital','Teaching / Academic Hospital',
    'Private Clinic','Polyclinic / Health Centre','Telemedicine','Research Institute',
  ];
  static const _councils = [
    'NMC — India','GMC — UK','ABMS — USA','AMC — Australia','CFPC — Canada',
    'HPCSA — South Africa','SCFHS — Saudi Arabia','DHA — Dubai','MOH — UAE',
    'MOH — Singapore','MCM — Malaysia','NZMC — New Zealand','Other',
  ];
  static const _countries = [
    'India','United States','United Kingdom','Australia','Canada','Germany',
    'France','Italy','Spain','Netherlands','Saudi Arabia','UAE','Qatar',
    'Kuwait','Bahrain','Oman','Singapore','Malaysia','Thailand','Indonesia',
    'Philippines','South Africa','Nigeria','Kenya','Egypt','New Zealand',
    'Ireland','Pakistan','Bangladesh','Sri Lanka','Nepal','Other',
  ];
  static const _emrSystems = [
    'Epic','Cerner / Oracle Health','Athenahealth','Allscripts','eClinicalWorks',
    'NextGen','MEDITECH','Practo','Lybrate','Halemind','Other','None / Paper records',
  ];
  static const _languages = [
    'English','Hindi','Arabic','French','Spanish','German','Portuguese',
    'Italian','Russian','Mandarin','Japanese','Korean','Tamil','Telugu',
    'Kannada','Malayalam','Bengali','Marathi','Gujarati','Punjabi','Urdu',
    'Swahili','Dutch','Polish','Turkish','Indonesian','Malay',
  ];

  static const _blue = Color(0xFF1D4ED8);
  static const int _total = 2;

  static const _titles = [
    'Identity & Practice',
    'Credentials & Workflow',
  ];
  static const _subtitles = [
    'Who you are and where you work',
    'How we verify and reach you',
  ];

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = _auth.currentUser?.email ?? '';
    final name = _auth.currentUser?.displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) _lastNameCtrl.text = parts.sublist(1).join(' ');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _yearsExpCtrl, _specialtyCtrl,
      _subCtrl, _hospitalCtrl, _deptCtrl, _licenseCtrl, _regCtrl,
      _emailCtrl, _phoneCtrl, _avgPatientsCtrl,
    ]) c.dispose();
    super.dispose();
  }

  bool _validate() {
    switch (_page) {
      case 0:
        return _firstNameCtrl.text.trim().isNotEmpty &&
            _lastNameCtrl.text.trim().isNotEmpty &&
            _degree != null &&
            _specialtyCtrl.text.trim().isNotEmpty &&
            _hospitalCtrl.text.trim().isNotEmpty &&
            _country != null;
      case 1:
        return _licenseCtrl.text.trim().isNotEmpty &&
            _emailCtrl.text.trim().isNotEmpty &&
            _langs.isNotEmpty;
      default:
        return true;
    }
  }

  static const _errors = [
    'Please fill: first name, last name, degree, specialty, hospital and country.',
    'Please fill: license number, email and select at least one language.',
  ];

  void _next() {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_errors[_page]),
        backgroundColor: AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_page < _total - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final profile = DoctorProfile(
        id: _auth.currentUser!.uid,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        degree: _degree,
        yearsOfExperience: int.tryParse(_yearsExpCtrl.text.trim()),
        country: _country,
        specialty: _specialtyCtrl.text.trim(),
        subSpecialty: _subCtrl.text.trim().isEmpty ? null : _subCtrl.text.trim(),
        hospitalName: _hospitalCtrl.text.trim(),
        departmentName: _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
        practiceType: _practiceType,
        medicalCouncil: _council,
        licenseNumber: _licenseCtrl.text.trim(),
        registrationNumber: _regCtrl.text.trim().isEmpty ? null : _regCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        contactNumber: _phoneCtrl.text.trim(),
        languages: _langs.toList(),
        emrSystem: _emrSystem,
        avgPatientsPerDay: int.tryParse(_avgPatientsCtrl.text.trim()),
      );
      await _firestore.saveDoctorProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()));
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [_step1(), _step2()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Clinix AI',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_page + 1} / $_total',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_total, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 5),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= _page
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Column(
              key: ValueKey(_page),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titles[_page],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(_subtitles[_page],
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Step 1: Identity & Practice ─────────────────────────────────────────
  Widget _step1() {
    return _sheet([
      _sectionLabel('Personal'),
      Row(children: [
        Expanded(child: _tf(_firstNameCtrl, 'First Name *', Icons.person_outline)),
        const SizedBox(width: 12),
        Expanded(child: _tf(_lastNameCtrl, 'Last Name *', Icons.person_outline)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _dd<String>(
          label: 'Medical Degree *',
          icon: Icons.school_outlined,
          value: _degree,
          items: _degrees,
          onChanged: (v) => setState(() => _degree = v),
        )),
        const SizedBox(width: 12),
        Expanded(child: _tf(_yearsExpCtrl, 'Years Exp.',
            Icons.timeline_outlined, type: TextInputType.number)),
      ]),
      const SizedBox(height: 20),
      _sectionLabel('Practice'),
      _ac(controller: _specialtyCtrl, label: 'Specialty *',
          icon: Icons.medical_services_outlined, suggestions: _specialties),
      const SizedBox(height: 12),
      _ac(controller: _subCtrl, label: 'Sub-specialty (Optional)',
          icon: Icons.biotech_outlined, suggestions: _specialties),
      const SizedBox(height: 12),
      _tf(_hospitalCtrl, 'Hospital / Institution *',
          Icons.local_hospital_outlined),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _tf(_deptCtrl, 'Department', Icons.business_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _dd<String>(
          label: 'Practice Type',
          icon: Icons.account_balance_outlined,
          value: _practiceType,
          items: _practiceTypes,
          onChanged: (v) => setState(() => _practiceType = v),
        )),
      ]),
      const SizedBox(height: 12),
      _dd<String>(
        label: 'Country of Practice *',
        icon: Icons.public_outlined,
        value: _country,
        items: _countries,
        onChanged: (v) => setState(() => _country = v),
      ),
      const SizedBox(height: 14),
      _infoBox(Icons.auto_awesome_outlined,
          'Your specialty, country and practice type help Clinix AI tailor AI '
          'responses, drug dosing protocols, and clinical report formatting.'),
    ]);
  }

  // ─── Step 2: Credentials & Workflow ──────────────────────────────────────
  Widget _step2() {
    return _sheet([
      _sectionLabel('Verification'),
      _tf(_licenseCtrl, 'License / Certificate Number *',
          Icons.badge_outlined),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(flex: 3, child: _dd<String>(
          label: 'Medical Council',
          icon: Icons.verified_user_outlined,
          value: _council,
          items: _councils,
          onChanged: (v) => setState(() => _council = v),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _tf(_regCtrl, 'Reg. No.',
            Icons.numbers_outlined)),
      ]),
      const SizedBox(height: 20),
      _sectionLabel('Workflow'),
      _dd<String>(
        label: 'EMR / EHR System',
        icon: Icons.computer_outlined,
        value: _emrSystem,
        items: _emrSystems,
        onChanged: (v) => setState(() => _emrSystem = v),
      ),
      const SizedBox(height: 12),
      _tf(_avgPatientsCtrl, 'Avg patients per day (Optional)',
          Icons.group_outlined, type: TextInputType.number),
      const SizedBox(height: 20),
      _sectionLabel('Contact'),
      _tf(_emailCtrl, 'Email *', Icons.email_outlined,
          type: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _tf(_phoneCtrl, 'Phone Number (Optional)', Icons.phone_outlined,
          type: TextInputType.phone),
      const SizedBox(height: 20),
      _sectionLabel('Languages with patients *'),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _languages.map((lang) {
          final sel = _langs.contains(lang);
          return FilterChip(
            label: Text(lang, style: TextStyle(
                fontSize: 12,
                color: sel ? _blue : AppTheme.textSecondary,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            selected: sel,
            onSelected: (v) => setState(() {
              if (v) _langs.add(lang);
              else if (_langs.length > 1) _langs.remove(lang);
            }),
            selectedColor: _blue.withValues(alpha: 0.12),
            checkmarkColor: _blue,
            side: BorderSide(color: sel ? _blue : AppTheme.dividerColor),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      _infoBox(Icons.lock_outline,
          'Data stored securely in Firebase. Clinix AI never shares your '
          'information with third parties.'),
    ]);
  }

  // ─── Shared ───────────────────────────────────────────────────────────────

  /// Sheet layout: scrolling fields up top, button pinned at the bottom.
  /// No artificial Spacer — content is dense enough to fill the screen on
  /// both steps now.
  Widget _sheet(List<Widget> fields) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: fields,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _btn(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Color(0xFF6B7280)),
      ),
    );
  }

  Widget _btn() {
    final isLast = _page == _total - 1;
    return Row(children: [
      if (_page > 0) ...[
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _blue),
              foregroundColor: _blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  isLast ? 'Get Started' : 'Continue',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
        ),
      ),
    ]);
  }

  Widget _tf(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: _dec(label, icon),
    );
  }

  Widget _ac({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (v) => v.text.isEmpty
          ? const []
          : suggestions
              .where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: (s) => controller.text = s,
      fieldViewBuilder: (ctx, ctrl, fn, _) {
        ctrl.text = controller.text;
        ctrl.addListener(() => controller.text = ctrl.text);
        return TextFormField(
            controller: ctrl,
            focusNode: fn,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
            decoration: _dec(label, icon));
      },
      optionsViewBuilder: (ctx, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 320),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: opts.length,
              itemBuilder: (_, i) {
                final o = opts.elementAt(i);
                return ListTile(
                    dense: true,
                    title: Text(o,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => onSel(o));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _dd<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: _dec(label, icon),
      items: items
          .map((i) => DropdownMenuItem<T>(value: i, child: Text(i.toString())))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _infoBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blue.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: _blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.textSecondary, height: 1.4)),
        ),
      ]),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      prefixIcon: Icon(icon, color: _blue, size: 19),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
    );
  }
}
