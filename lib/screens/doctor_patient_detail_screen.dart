import 'package:flutter/material.dart';

import '../core/navigation/app_router.dart';
import '../core/errors/app_error_handler.dart';
import '../core/healthcare/healthcare_services_manager.dart';
import '../models/health_models.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/patient/patient_profile_card.dart';
import '../widgets/patient/patient_record_section.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final ProviderPatientRecord patient;

  const DoctorPatientDetailScreen({super.key, required this.patient});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final HealthcareServicesManager _services = HealthcareServicesManager();
  final FirestoreService _firestore = FirestoreService();

  late ProviderPatientRecord _patient;
  bool _isDeleting = false;
  bool _isSaving = false;

  String? _activeField;
  String? _activeSection;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _contactController;
  late TextEditingController _emailController;
  late TextEditingController _ehrIdController;
  late TextEditingController _lastVisitController;

  late String _gender;
  late String _bloodType;
  late List<String> _prescriptions;
  late List<String> _reports;
  late List<String> _foodAllergies;
  late List<String> _medicinalAllergies;
  late List<String> _medicalHistory;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _initControllersFromPatient(_patient);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _ehrIdController.dispose();
    _lastVisitController.dispose();
    super.dispose();
  }

  void _initControllersFromPatient(ProviderPatientRecord p) {
    _firstNameController = TextEditingController(text: p.firstName);
    _lastNameController = TextEditingController(text: p.lastName);
    _dateOfBirthController = TextEditingController(text: p.dateOfBirth);
    _contactController = TextEditingController(text: p.contactNumber);
    _emailController = TextEditingController(text: p.email);
    _ehrIdController = TextEditingController(text: p.ehrId);
    _lastVisitController = TextEditingController(text: p.lastVisitSummary);
    _syncListsFromPatient(p);
  }

  void _syncListsFromPatient(ProviderPatientRecord p) {
    _gender = p.gender.isEmpty ? 'Unknown' : p.gender;
    _bloodType = p.bloodType.isEmpty ? 'O+' : p.bloodType;
    _prescriptions = List.from(p.prescriptions);
    _reports = List.from(p.reports);
    _foodAllergies = List.from(p.foodAllergies);
    _medicinalAllergies = List.from(p.medicinalAllergies);
    _medicalHistory = List.from(p.medicalHistory);
  }

  void _syncControllersFromPatient(ProviderPatientRecord p) {
    _firstNameController.text = p.firstName;
    _lastNameController.text = p.lastName;
    _dateOfBirthController.text = p.dateOfBirth;
    _contactController.text = p.contactNumber;
    _emailController.text = p.email;
    _ehrIdController.text = p.ehrId;
    _lastVisitController.text = p.lastVisitSummary;
    _syncListsFromPatient(p);
  }

  Future<void> _activateField(String fieldKey) async {
    if (_activeField == fieldKey) return;
    await _saveActive();
    setState(() {
      _activeField = fieldKey;
      _activeSection = null;
    });
  }

  Future<void> _activateSection(String sectionId) async {
    if (_activeSection == sectionId) return;
    await _saveActive();
    setState(() {
      _activeSection = sectionId;
      _activeField = null;
      if (sectionId == PatientSectionIds.prescriptions && _prescriptions.isEmpty) {
        _prescriptions = [''];
      }
      if (sectionId == PatientSectionIds.reports && _reports.isEmpty) {
        _reports = [''];
      }
      if (sectionId == PatientSectionIds.foodAllergies && _foodAllergies.isEmpty) {
        _foodAllergies = [''];
      }
      if (sectionId == PatientSectionIds.medicinalAllergies && _medicinalAllergies.isEmpty) {
        _medicinalAllergies = [''];
      }
      if (sectionId == PatientSectionIds.medicalHistory && _medicalHistory.isEmpty) {
        _medicalHistory = [''];
      }
    });
  }

  Future<void> _saveActive() async {
    if (_activeField != null || _activeSection != null) {
      await _persistPatient(silent: true);
      if (mounted) {
        setState(() {
          _activeField = null;
          _activeSection = null;
        });
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final initial = DateTime.tryParse(_dateOfBirthController.text) ??
        DateTime(DateTime.now().year - 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: PatientDetailPalette.charcoal,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateOfBirthController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _persistPatient({bool silent = false}) async {
    if (_isSaving) return;

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = _patient.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim(),
        gender: _gender,
        bloodType: _bloodType,
        contactNumber: _contactController.text.trim(),
        email: email,
        ehrId: _ehrIdController.text.trim(),
        lastVisitSummary: _lastVisitController.text.trim(),
        prescriptions: _trimmedList(_prescriptions),
        reports: _trimmedList(_reports),
        foodAllergies: _trimmedList(_foodAllergies),
        medicinalAllergies: _trimmedList(_medicinalAllergies),
        medicalHistory: _trimmedList(_medicalHistory),
        updatedAt: DateTime.now(),
      );

      await _firestore.savePatientRecord(updated);
      if (!mounted) return;

      setState(() {
        _patient = updated;
        _syncControllersFromPatient(updated);
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved'),
            duration: Duration(seconds: 1),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> _trimmedList(List<String> items) =>
      items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _confirmAndDeletePatient() async {
    await _saveActive();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to delete ${_patient.fullName}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _services.deletePatientAndRecords(_patient);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _appBarTitle {
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    return name.isEmpty ? 'Patient Profile' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, color: PatientDetailPalette.charcoal),
        ),
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            tooltip: 'Delete Patient',
            icon: _isDeleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
            onPressed: _isDeleting ? null : _confirmAndDeletePatient,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PatientProfileCard(
              patient: _patient,
              activeField: _activeField,
              firstNameController: _firstNameController,
              lastNameController: _lastNameController,
              contactController: _contactController,
              emailController: _emailController,
              dateOfBirthController: _dateOfBirthController,
              gender: _gender,
              bloodType: _bloodType,
              onActivateField: _activateField,
              onSaveField: _saveActive,
              onGenderChanged: (v) => setState(() => _gender = v),
              onBloodTypeChanged: (v) => setState(() => _bloodType = v),
              onPickDateOfBirth: _pickDateOfBirth,
              onPatientUpdated: (u) => setState(() {
                _patient = u;
                _syncControllersFromPatient(u);
              }),
            ),

            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.ehrId,
                title: 'EHR Patient ID',
                icon: Icons.link,
                accent: PatientDetailPalette.ehr,
                values: [_patient.ehrId],
                emptyMessage: 'Tap to link an Epic FHIR patient ID',
                isActive: _activeSection == PatientSectionIds.ehrId,
                onTapSection: () => _activateSection(PatientSectionIds.ehrId),
                onSaveSection: _saveActive,
                editController: _ehrIdController,
                editMaxLines: 1,
              ),
            ),

            _sectionLabel('Quick Actions', PatientDetailPalette.gold),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
              child: Row(
                children: [
                  Expanded(
                    child: PatientQuickAction(
                      icon: Icons.mic_none_rounded,
                      label: 'Consultation',
                      accent: PatientDetailPalette.actionConsult,
                      onTap: () async {
                        await _saveActive();
                        if (!mounted) return;
                        Navigator.pushNamed(context, AppRouter.voiceAssistant,
                            arguments: {'patientId': _patient.id});
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: PatientQuickAction(
                      icon: Icons.note_alt_outlined,
                      label: 'Notes',
                      accent: PatientDetailPalette.actionNotes,
                      onTap: () async {
                        await _saveActive();
                        if (!mounted) return;
                        Navigator.pushNamed(context, AppRouter.clinicalNotes, arguments: _patient.id);
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: PatientQuickAction(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan Doc',
                      accent: PatientDetailPalette.actionScan,
                      onTap: () async {
                        await _saveActive();
                        if (!mounted) return;
                        Navigator.pushNamed(context, AppRouter.documentScanner, arguments: _patient.id);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),

            _sectionLabel('Clinical Records', PatientDetailPalette.slate),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.sm),
              child: Text(
                'Tap any section to edit',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ),

            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.lastVisit,
                title: 'Last Visit Summary',
                icon: Icons.history_edu_outlined,
                accent: PatientDetailPalette.visit,
                values: [_patient.lastVisitSummary],
                emptyMessage: 'Tap to add visit summary',
                isActive: _activeSection == PatientSectionIds.lastVisit,
                onTapSection: () => _activateSection(PatientSectionIds.lastVisit),
                onSaveSection: _saveActive,
                editController: _lastVisitController,
                editMaxLines: 4,
              ),
            ),
            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.prescriptions,
                title: 'Prescriptions',
                icon: Icons.medication_outlined,
                accent: PatientDetailPalette.prescription,
                values: _patient.prescriptions,
                emptyMessage: 'Tap to add prescriptions',
                isActive: _activeSection == PatientSectionIds.prescriptions,
                onTapSection: () => _activateSection(PatientSectionIds.prescriptions),
                onSaveSection: _saveActive,
                editList: _prescriptions,
                onListChanged: (v) => setState(() => _prescriptions = v),
              ),
            ),
            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.reports,
                title: 'Reports',
                icon: Icons.assignment_outlined,
                accent: PatientDetailPalette.report,
                values: _patient.reports,
                emptyMessage: 'Tap to add reports',
                isActive: _activeSection == PatientSectionIds.reports,
                onTapSection: () => _activateSection(PatientSectionIds.reports),
                onSaveSection: _saveActive,
                editList: _reports,
                onListChanged: (v) => setState(() => _reports = v),
              ),
            ),
            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.foodAllergies,
                title: 'Food Allergies',
                icon: Icons.restaurant_outlined,
                accent: PatientDetailPalette.foodAllergy,
                values: _patient.foodAllergies,
                emptyMessage: 'Tap to add food allergies',
                isActive: _activeSection == PatientSectionIds.foodAllergies,
                onTapSection: () => _activateSection(PatientSectionIds.foodAllergies),
                onSaveSection: _saveActive,
                editList: _foodAllergies,
                onListChanged: (v) => setState(() => _foodAllergies = v),
              ),
            ),
            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.medicinalAllergies,
                title: 'Medicinal Allergies',
                icon: Icons.vaccines_outlined,
                accent: PatientDetailPalette.medAllergy,
                values: _patient.medicinalAllergies,
                emptyMessage: 'Tap to add medicinal allergies',
                isActive: _activeSection == PatientSectionIds.medicinalAllergies,
                onTapSection: () => _activateSection(PatientSectionIds.medicinalAllergies),
                onSaveSection: _saveActive,
                editList: _medicinalAllergies,
                onListChanged: (v) => setState(() => _medicinalAllergies = v),
              ),
            ),
            PatientRecordSection(
              config: PatientRecordSectionConfig(
                sectionId: PatientSectionIds.medicalHistory,
                title: 'Medical History',
                icon: Icons.health_and_safety_outlined,
                accent: PatientDetailPalette.history,
                values: _patient.medicalHistory,
                emptyMessage: 'Tap to add medical history',
                isActive: _activeSection == PatientSectionIds.medicalHistory,
                onTapSection: () => _activateSection(PatientSectionIds.medicalHistory),
                onSaveSection: _saveActive,
                editList: _medicalHistory,
                onListChanged: (v) => setState(() => _medicalHistory = v),
              ),
            ),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, AppTheme.sm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: AppTheme.sm),
          Text(
            title,
            style: AppTheme.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: PatientDetailPalette.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
