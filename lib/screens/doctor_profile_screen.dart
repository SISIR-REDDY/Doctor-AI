import 'package:flutter/material.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';

class DoctorProfileScreen extends StatefulWidget {
  final DoctorProfile? initialProfile;

  const DoctorProfileScreen({super.key, this.initialProfile});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late DoctorProfile _profile;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;

  // Controllers
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _yearsExpCtrl;
  late TextEditingController _specialtyCtrl;
  late TextEditingController _subSpecialtyCtrl;
  late TextEditingController _hospitalCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _licenseCtrl;
  late TextEditingController _registrationCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _avgPatientsCtrl;

  String? _selectedDegree;
  String? _selectedCountry;
  String? _selectedCouncil;
  String? _selectedPracticeType;
  String? _selectedEmrSystem;
  Set<String> _selectedLanguages = {};

  // ─── Static option lists (must match onboarding_screen.dart) ─────────────
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
  static const _countries = [
    'India','United States','United Kingdom','Australia','Canada','Germany',
    'France','Italy','Spain','Netherlands','Saudi Arabia','UAE','Qatar',
    'Kuwait','Bahrain','Oman','Singapore','Malaysia','Thailand','Indonesia',
    'Philippines','South Africa','Nigeria','Kenya','Egypt','New Zealand',
    'Ireland','Pakistan','Bangladesh','Sri Lanka','Nepal','Other',
  ];
  static const _councils = [
    'NMC — India','GMC — UK','ABMS — USA','AMC — Australia','CFPC — Canada',
    'HPCSA — South Africa','SCFHS — Saudi Arabia','DHA — Dubai','MOH — UAE',
    'MOH — Singapore','MCM — Malaysia','NZMC — New Zealand','Other',
  ];
  static const _practiceTypes = [
    'Government Hospital','Private Hospital','Teaching / Academic Hospital',
    'Private Clinic','Polyclinic / Health Centre','Telemedicine','Research Institute',
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

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile ??
        DoctorProfile(
          id: _authService.currentUser?.uid ?? '',
          firstName: '',
          lastName: '',
          licenseNumber: '',
          specialty: '',
          hospitalName: '',
          contactNumber: '',
          email: _authService.currentUser?.email ?? '',
        );
    _initControllers();
    _loadSavedProfile();
  }

  void _initControllers() {
    _firstNameCtrl    = TextEditingController(text: _profile.firstName);
    _lastNameCtrl     = TextEditingController(text: _profile.lastName);
    _yearsExpCtrl     = TextEditingController(text: _profile.yearsOfExperience?.toString() ?? '');
    _specialtyCtrl    = TextEditingController(text: _profile.specialty);
    _subSpecialtyCtrl = TextEditingController(text: _profile.subSpecialty ?? '');
    _hospitalCtrl     = TextEditingController(text: _profile.hospitalName);
    _departmentCtrl   = TextEditingController(text: _profile.departmentName ?? '');
    _licenseCtrl      = TextEditingController(text: _profile.licenseNumber);
    _registrationCtrl = TextEditingController(text: _profile.registrationNumber ?? '');
    _emailCtrl        = TextEditingController(text: _profile.email);
    _phoneCtrl        = TextEditingController(text: _profile.contactNumber);
    _avgPatientsCtrl  = TextEditingController(text: _profile.avgPatientsPerDay?.toString() ?? '');
    _selectedDegree        = _profile.degree;
    _selectedCountry       = _profile.country;
    _selectedCouncil       = _profile.medicalCouncil;
    _selectedPracticeType  = _profile.practiceType;
    _selectedEmrSystem     = _profile.emrSystem;
    _selectedLanguages     = Set.from(_profile.languages);
    if (_selectedLanguages.isEmpty) _selectedLanguages.add('English');
  }

  void _syncControllers() {
    _firstNameCtrl.text    = _profile.firstName;
    _lastNameCtrl.text     = _profile.lastName;
    _yearsExpCtrl.text     = _profile.yearsOfExperience?.toString() ?? '';
    _specialtyCtrl.text    = _profile.specialty;
    _subSpecialtyCtrl.text = _profile.subSpecialty ?? '';
    _hospitalCtrl.text     = _profile.hospitalName;
    _departmentCtrl.text   = _profile.departmentName ?? '';
    _licenseCtrl.text      = _profile.licenseNumber;
    _registrationCtrl.text = _profile.registrationNumber ?? '';
    _emailCtrl.text        = _profile.email;
    _phoneCtrl.text        = _profile.contactNumber;
    _avgPatientsCtrl.text  = _profile.avgPatientsPerDay?.toString() ?? '';
    _selectedDegree        = _profile.degree;
    _selectedCountry       = _profile.country;
    _selectedCouncil       = _profile.medicalCouncil;
    _selectedPracticeType  = _profile.practiceType;
    _selectedEmrSystem     = _profile.emrSystem;
    _selectedLanguages     = Set.from(_profile.languages);
    if (_selectedLanguages.isEmpty) _selectedLanguages.add('English');
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _yearsExpCtrl, _specialtyCtrl,
      _subSpecialtyCtrl, _hospitalCtrl, _departmentCtrl, _licenseCtrl,
      _registrationCtrl, _emailCtrl, _phoneCtrl, _avgPatientsCtrl,
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // loadDoctorProfile is now cache-first — returns instantly from memory
      // or SharedPreferences if available, then refreshes from Firestore in
      // the background. So this is basically free after the first load.
      final saved = await _firestoreService.loadDoctorProfile(uid);
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _profile = saved;
          _isLoading = false;
        });
        _syncControllers();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final updated = _profile.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        degree: _selectedDegree,
        yearsOfExperience: int.tryParse(_yearsExpCtrl.text.trim()),
        specialty: _specialtyCtrl.text.trim(),
        subSpecialty: _subSpecialtyCtrl.text.trim().isEmpty
            ? null
            : _subSpecialtyCtrl.text.trim(),
        hospitalName: _hospitalCtrl.text.trim(),
        departmentName: _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
        registrationNumber: _registrationCtrl.text.trim().isEmpty
            ? null
            : _registrationCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        contactNumber: _phoneCtrl.text.trim(),
        country: _selectedCountry,
        medicalCouncil: _selectedCouncil,
        practiceType: _selectedPracticeType,
        emrSystem: _selectedEmrSystem,
        avgPatientsPerDay: int.tryParse(_avgPatientsCtrl.text.trim()),
        languages: _selectedLanguages.toList(),
      );
      // saveDoctorProfile writes to cache first, then Firestore — UI feels
      // instant even on slow connections.
      await _firestoreService.saveDoctorProfile(updated);
      if (mounted) {
        setState(() {
          _profile = updated;
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    _syncControllers();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? _buildEditForm()
              : _buildViewMode(),
    );
  }

  // ─── View Mode ────────────────────────────────────────────────────────────

  Widget _buildViewMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar & name
          Center(
            child: Column(
              children: [
                _avatar(80),
                const SizedBox(height: 12),
                Text(_profile.fullName.isEmpty ? 'Your Profile' : _profile.fullName,
                    style: AppTheme.headingMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    if (_profile.degree?.isNotEmpty == true) _profile.degree!,
                    if (_profile.specialty.isNotEmpty) _profile.specialty,
                  ].join(' · '),
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (_profile.country?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(_profile.country!,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textTertiary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader('Personal'),
          _infoTile('First Name', _profile.firstName, Icons.person_outline),
          _infoTile('Last Name', _profile.lastName, Icons.person_outline),
          _infoTile('Medical Degree', _profile.degree ?? '—', Icons.school_outlined),
          _infoTile(
            'Years of Experience',
            _profile.yearsOfExperience != null
                ? '${_profile.yearsOfExperience} years'
                : '—',
            Icons.timeline_outlined,
          ),

          const SizedBox(height: 16),
          _sectionHeader('Practice'),
          _infoTile('Specialty', _profile.specialty.isEmpty ? '—' : _profile.specialty,
              Icons.medical_services_outlined),
          _infoTile('Sub-specialty', _profile.subSpecialty ?? '—', Icons.biotech_outlined),
          _infoTile('Hospital / Institution', _profile.hospitalName.isEmpty ? '—' : _profile.hospitalName,
              Icons.local_hospital_outlined),
          _infoTile('Department', _profile.departmentName ?? '—', Icons.business_outlined),
          _infoTile('Practice Type', _profile.practiceType ?? '—',
              Icons.account_balance_outlined),
          _infoTile('Country of Practice', _profile.country ?? '—', Icons.public_outlined),

          const SizedBox(height: 16),
          _sectionHeader('Verification'),
          _infoTile('License / Certificate Number',
              _profile.licenseNumber.isEmpty ? '—' : _profile.licenseNumber,
              Icons.badge_outlined),
          _infoTile('Medical Council', _profile.medicalCouncil ?? '—',
              Icons.verified_user_outlined),
          _infoTile('Registration No.', _profile.registrationNumber ?? '—',
              Icons.numbers_outlined),

          const SizedBox(height: 16),
          _sectionHeader('Workflow'),
          _infoTile('EMR / EHR System', _profile.emrSystem ?? '—',
              Icons.computer_outlined),
          _infoTile(
            'Avg patients per day',
            _profile.avgPatientsPerDay != null
                ? '${_profile.avgPatientsPerDay} patients'
                : '—',
            Icons.group_outlined,
          ),

          const SizedBox(height: 16),
          _sectionHeader('Contact'),
          _infoTile('Email', _profile.email.isEmpty ? '—' : _profile.email,
              Icons.email_outlined),
          _infoTile('Phone',
              _profile.contactNumber.isEmpty ? '—' : _profile.contactNumber,
              Icons.phone_outlined),

          if (_profile.languages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader('Languages with patients'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _profile.languages
                  .map((l) => Chip(
                        label: Text(l, style: const TextStyle(fontSize: 13)),
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.3)),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Edit Form ────────────────────────────────────────────────────────────

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _avatar(60)),
          const SizedBox(height: 20),

          _sectionHeader('Personal'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _tf(_firstNameCtrl, 'First Name', Icons.person_outline)),
            const SizedBox(width: 12),
            Expanded(child: _tf(_lastNameCtrl, 'Last Name', Icons.person_outline)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dd<String>(
              label: 'Medical Degree',
              icon: Icons.school_outlined,
              value: _selectedDegree,
              items: _degrees,
              onChanged: (v) => setState(() => _selectedDegree = v),
            )),
            const SizedBox(width: 12),
            Expanded(child: _tf(_yearsExpCtrl, 'Years Exp.',
                Icons.timeline_outlined,
                keyboardType: TextInputType.number)),
          ]),

          const SizedBox(height: 20),
          _sectionHeader('Practice'),
          const SizedBox(height: 10),
          _ac(controller: _specialtyCtrl, label: 'Specialty',
              icon: Icons.medical_services_outlined, suggestions: _specialties),
          const SizedBox(height: 12),
          _ac(controller: _subSpecialtyCtrl, label: 'Sub-specialty (Optional)',
              icon: Icons.biotech_outlined, suggestions: _specialties),
          const SizedBox(height: 12),
          _tf(_hospitalCtrl, 'Hospital / Institution',
              Icons.local_hospital_outlined),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _tf(_departmentCtrl, 'Department',
                Icons.business_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _dd<String>(
              label: 'Practice Type',
              icon: Icons.account_balance_outlined,
              value: _selectedPracticeType,
              items: _practiceTypes,
              onChanged: (v) => setState(() => _selectedPracticeType = v),
            )),
          ]),
          const SizedBox(height: 12),
          _dd<String>(
            label: 'Country of Practice',
            icon: Icons.public_outlined,
            value: _selectedCountry,
            items: _countries,
            onChanged: (v) => setState(() => _selectedCountry = v),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Verification'),
          const SizedBox(height: 10),
          _tf(_licenseCtrl, 'License / Certificate Number',
              Icons.badge_outlined),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 3, child: _dd<String>(
              label: 'Medical Council',
              icon: Icons.verified_user_outlined,
              value: _selectedCouncil,
              items: _councils,
              onChanged: (v) => setState(() => _selectedCouncil = v),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _tf(_registrationCtrl, 'Reg. No.',
                Icons.numbers_outlined)),
          ]),

          const SizedBox(height: 20),
          _sectionHeader('Workflow'),
          const SizedBox(height: 10),
          _dd<String>(
            label: 'EMR / EHR System',
            icon: Icons.computer_outlined,
            value: _selectedEmrSystem,
            items: _emrSystems,
            onChanged: (v) => setState(() => _selectedEmrSystem = v),
          ),
          const SizedBox(height: 12),
          _tf(_avgPatientsCtrl, 'Avg patients per day (Optional)',
              Icons.group_outlined, keyboardType: TextInputType.number),

          const SizedBox(height: 20),
          _sectionHeader('Contact'),
          const SizedBox(height: 10),
          _tf(_emailCtrl, 'Email', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _tf(_phoneCtrl, 'Phone Number (Optional)', Icons.phone_outlined,
              keyboardType: TextInputType.phone),

          const SizedBox(height: 20),
          _sectionHeader('Languages with patients'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languages.map((lang) {
              final selected = _selectedLanguages.contains(lang);
              return FilterChip(
                label: Text(lang, style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedLanguages.add(lang);
                  } else if (_selectedLanguages.length > 1) {
                    _selectedLanguages.remove(lang);
                  }
                }),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primaryColor,
                side: BorderSide(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor),
                labelStyle: TextStyle(
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
                backgroundColor: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _cancelEdit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _avatar(double size) {
    final initials =
        '${_profile.firstName.isNotEmpty ? _profile.firstName[0] : ''}${_profile.lastName.isNotEmpty ? _profile.lastName[0] : ''}'
            .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTheme.labelSmall.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTheme.labelSmall),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                style: AppTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tf(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: AppTheme.bodyMedium,
      decoration: _fieldDecoration(label, icon),
    );
  }

  /// Autocomplete field — matches onboarding's `_ac` exactly.
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
            style: AppTheme.bodyMedium,
            decoration: _fieldDecoration(label, icon));
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
                    title: Text(o, style: const TextStyle(fontSize: 14)),
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
      borderRadius: BorderRadius.circular(10),
      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
      decoration: _fieldDecoration(label, icon),
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString())))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      filled: true,
      fillColor: AppTheme.surfaceColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
