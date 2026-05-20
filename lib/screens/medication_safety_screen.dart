import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_error_handler.dart';
import '../core/navigation/app_router.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import '../widgets/patient/patient_log_selector.dart';

class MedicationSafetyScreen extends StatefulWidget {
  final String? patientId;

  const MedicationSafetyScreen({
    super.key,
    this.patientId,
  });

  @override
  State<MedicationSafetyScreen> createState() => _MedicationSafetyScreenState();
}

class _MedicationSafetyScreenState extends State<MedicationSafetyScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  ProviderPatientRecord? _selectedPatient;
  final List<ProviderPatientRecord> _patients = [];
  StreamSubscription<List<ProviderPatientRecord>>? _patientsSubscription;
  bool _isLoadingPatients = true;

  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final FocusNode _medicationFocus = FocusNode();
  final List<String> _currentMedications = [];

  // Common medications for quick selection
  final List<String> _commonMedications = [
    'Aspirin',
    'Metformin',
    'Lisinopril',
    'Atorvastatin',
    'Amlodipine',
    'Metoprolol',
    'Omeprazole',
    'Simvastatin',
    'Hydrochlorothiazide',
    'Losartan',
    'Gabapentin',
    'Prednisone',
    'Albuterol',
    'Warfarin',
    'Clopidogrel',
    'Furosemide',
    'Tramadol',
    'Ibuprofen',
    'Acetaminophen',
    'Sertraline'
  ];

  bool _isAnalyzing = false;
  bool _isSaving = false;
  String _analysisResult = '';
  Map<String, String> _severityResults = {}; // Track severity levels for interactions

  // Dosage calculator state
  bool _showDosageCalculator = false;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedMedForDosage = '';
  String _calculatedDosage = '';

  // Common medication dosage data (mg per kg per dose)
  final Map<String, Map<String, dynamic>> _dosageData = {
    'Acetaminophen': {
      'pediatric': {'min': 10.0, 'max': 15.0, 'unit': 'mg/kg', 'frequency': 'q4-6h', 'maxDaily': 75.0},
      'adult': {'dose': '325-1000 mg', 'frequency': 'q4-6h', 'maxDaily': '4000 mg'},
    },
    'Ibuprofen': {
      'pediatric': {'min': 5.0, 'max': 10.0, 'unit': 'mg/kg', 'frequency': 'q6-8h', 'maxDaily': 40.0},
      'adult': {'dose': '400-800 mg', 'frequency': 'q6-8h', 'maxDaily': '2400 mg'},
    },
    'Amoxicillin': {
      'pediatric': {'min': 25.0, 'max': 50.0, 'unit': 'mg/kg', 'frequency': 'q8-12h', 'maxDaily': 100.0},
      'adult': {'dose': '500-875 mg', 'frequency': 'q8-12h', 'maxDaily': '2625 mg'},
    },
    'Prednisolone': {
      'pediatric': {'min': 1.0, 'max': 2.0, 'unit': 'mg/kg/day', 'frequency': 'daily-bid', 'maxDaily': 60.0},
      'adult': {'dose': '5-60 mg', 'frequency': 'daily', 'maxDaily': '80 mg'},
    },
    'Albuterol': {
      'pediatric': {'dose': '2.5 mg', 'frequency': 'q4-6h prn', 'route': 'nebulizer'},
      'adult': {'dose': '2.5-5 mg', 'frequency': 'q4-6h prn', 'route': 'nebulizer'},
    },
  };

  @override
  void initState() {
    super.initState();
    StorageService().warmPatientPhotosCache();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadInitialPatient();
    _watchPatients();
  }

  void _watchPatients() {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) {
      setState(() => _isLoadingPatients = false);
      return;
    }
    _patientsSubscription?.cancel();
    _patientsSubscription = _firestoreService.watchDoctorPatients(doctorId).listen((list) {
      if (!mounted) return;
      setState(() {
        _patients
          ..clear()
          ..addAll(list);
        if (_selectedPatient != null) {
          for (final p in list) {
            if (p.id == _selectedPatient!.id) {
              _selectedPatient = p;
              break;
            }
          }
        }
      });
    });
    setState(() => _isLoadingPatients = false);
  }

  Future<void> _loadInitialPatient() async {
    final id = widget.patientId?.trim();
    if (id == null || id.isEmpty) return;
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) return;
    try {
      final list = await _firestoreService.getDoctorPatients(doctorId);
      for (final p in list) {
        if (p.id == id) {
          if (mounted) _applyPatient(p, importChartMeds: true);
          break;
        }
      }
    } catch (_) {}
  }

  void _applyPatient(ProviderPatientRecord p, {bool importChartMeds = false}) {
    setState(() {
      _selectedPatient = p;
      _ageController.text = p.age > 0 ? '${p.age}' : '';
      if (importChartMeds && p.prescriptions.isNotEmpty) {
        for (final rx in p.prescriptions) {
          final trimmed = rx.trim();
          if (trimmed.isNotEmpty && !_currentMedications.contains(trimmed)) {
            _currentMedications.add(trimmed);
          }
        }
      }
    });
  }

  void _importChartMedications() {
    final p = _selectedPatient;
    if (p == null || p.prescriptions.isEmpty) return;
    setState(() {
      for (final rx in p.prescriptions) {
        final trimmed = rx.trim();
        if (trimmed.isNotEmpty && !_currentMedications.contains(trimmed)) {
          _currentMedications.add(trimmed);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imported medications from patient chart')),
    );
  }

  List<String> get _quickMedicationChips {
    final chips = <String>{};
    if (_selectedPatient != null) {
      chips.addAll(_selectedPatient!.prescriptions.map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    chips.addAll(_commonMedications);
    return chips.take(14).toList();
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _medicationController.dispose();
    _doseController.dispose();
    _medicationFocus.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _addMedication() {
    final med = _medicationController.text.trim();
    final dose = _doseController.text.trim();

    if (med.isEmpty) {
      _medicationFocus.requestFocus();
      return;
    }

    final medWithDose = dose.isEmpty ? med : '$med ($dose)';
    setState(() {
      _currentMedications.add(medWithDose);
      _medicationController.clear();
      _doseController.clear();
    });
    HapticFeedback.lightImpact();
    _medicationFocus.requestFocus();
  }

  void _removeMedication(int index) {
    setState(() {
      _currentMedications.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _analyzeMedicationSafety() async {
    if (_currentMedications.isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        Exception('Please add at least one medication to check'),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final prompt = '''
As a clinical pharmacist, analyze the following medications for drug interactions, contraindications, and safety concerns:

**Medications to Analyze:**
${_currentMedications.map((med) => '• $med').join('\n')}

${_selectedPatient != null ? '''
**Patient Context:**
- Name: ${_selectedPatient!.fullName}
- Age: ${_selectedPatient!.age}
- Medical History: ${_selectedPatient!.medicalHistory.isEmpty ? 'No documented conditions' : _selectedPatient!.medicalHistory.join(', ')}
- Known Allergies: ${_selectedPatient!.allergies.isEmpty ? 'None documented' : _selectedPatient!.allergies.join(', ')}
- Current prescriptions on file: ${_selectedPatient!.prescriptions.isEmpty ? 'None' : _selectedPatient!.prescriptions.join(', ')}
''' : ''}

Please provide a comprehensive safety analysis with the following structured format:

## INTERACTION SEVERITY ASSESSMENT
For each interaction found, specify:
- CRITICAL (life-threatening, contraindicated)
- HIGH (significant risk, requires monitoring)
- MODERATE (caution advised, may need adjustment)
- LOW (minimal risk, awareness sufficient)

## DRUG-DRUG INTERACTIONS
List all significant interactions with severity levels and clinical significance

## CONTRAINDICATIONS & WARNINGS
Patient-specific contraindications based on age, conditions, and allergies

## MONITORING RECOMMENDATIONS
- Laboratory tests needed
- Clinical parameters to monitor
- Frequency of monitoring

## DOSING CONSIDERATIONS
Age-appropriate dosing and renal/hepatic adjustments if applicable

## PATIENT EDUCATION POINTS
Key safety information the patient should know

## ALTERNATIVE SUGGESTIONS
Safer alternative medications if high-risk interactions are found

Format each section clearly with severity indicators (🔴 CRITICAL, 🟠 HIGH, 🟡 MODERATE, 🟢 LOW)
''';

      final result = await _chatbotService.getGeminiResponse(prompt);

      if (!mounted) return;

      // Extract severity information
      _extractSeverityInfo(result);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  void _extractSeverityInfo(String analysisText) {
    _severityResults.clear();
    final lines = analysisText.toLowerCase().split('\n');

    for (final line in lines) {
      if (line.contains('critical') || line.contains('🔴')) {
        _severityResults['overall'] = 'CRITICAL';
        break;
      } else if (line.contains('high') || line.contains('🟠')) {
        _severityResults['overall'] = 'HIGH';
      } else if (line.contains('moderate') || line.contains('🟡') && !_severityResults.containsKey('overall')) {
        _severityResults['overall'] = 'MODERATE';
      } else if (line.contains('low') || line.contains('🟢') && !_severityResults.containsKey('overall')) {
        _severityResults['overall'] = 'LOW';
      }
    }

    // Default to LOW if no severity found
    _severityResults['overall'] ??= 'LOW';
  }

  Future<void> _saveMedicationAnalysisToNotes() async {
    if (_analysisResult.isEmpty) return;

    final patientId = _selectedPatient?.id;
    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a patient from your log to save this analysis'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final severity = _severityResults['overall'] ?? 'LOW';
      final doctorId = _authService.currentUser?.uid ?? '';
      final now = DateTime.now();
      final note = ClinicalNote(
        id: 'note_${_uuid.v4()}',
        patientId: patientId,
        doctorId: doctorId,
        title: 'Medication Safety Analysis - $severity Risk',
        content: '''Medications Analyzed: ${_currentMedications.join(', ')}

--- MEDICATION SAFETY ANALYSIS ---

$_analysisResult''',
        diagnosis: 'Medication Safety Review - $severity Risk Level',
        treatments: [],
        followUpItems: [
          'Monitor for drug interactions',
          'Review medication list regularly',
          'Patient education provided'
        ],
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
        noteType: 'ai',
        createdAt: now,
        updatedAt: now,
      );

      await _firestoreService.saveClinicalReport(note);

      if (_selectedPatient != null) {
        final updated = _selectedPatient!.copyWith(
          prescriptions: List<String>.from(_currentMedications),
          updatedAt: now,
        );
        await _firestoreService.savePatientRecord(updated);
        _selectedPatient = updated;
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Medication analysis saved to clinical notes'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _clearAll() {
    setState(() {
      _currentMedications.clear();
      _analysisResult = '';
      _medicationController.clear();
      _doseController.clear();
    });
  }

  void _calculateDosage() {
    final weight = double.tryParse(_weightController.text);
    final age = int.tryParse(_ageController.text);

    if (weight == null || _selectedMedForDosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter weight and select medication'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (!_dosageData.containsKey(_selectedMedForDosage)) {
      setState(() {
        _calculatedDosage = 'Dosage data not available for $_selectedMedForDosage';
      });
      return;
    }

    final medData = _dosageData[_selectedMedForDosage]!;
    final isPediatric = age != null && age < 18;
    String result = '';

    if (isPediatric && medData.containsKey('pediatric')) {
      final pedData = medData['pediatric'];
      if (pedData.containsKey('min') && pedData.containsKey('max')) {
        final minDose = (weight * pedData['min']).round();
        final maxDose = (weight * pedData['max']).round();
        final maxDailyDose = (weight * pedData['maxDaily']).round();

        result = '''
📊 Pediatric Dosing for $_selectedMedForDosage
Weight: ${weight}kg, Age: ${age}y

💊 Dose per administration:
   ${minDose} - ${maxDose} mg ${pedData['frequency']}

📅 Maximum daily dose:
   ${maxDailyDose} mg/day

⚠️ Always verify with current pediatric dosing guidelines
        ''';
      } else {
        result = '''
📊 Pediatric Dosing for $_selectedMedForDosage
Weight: ${weight}kg, Age: ${age}y

💊 Standard Dose: ${pedData['dose']}
📅 Frequency: ${pedData['frequency']}
${pedData.containsKey('route') ? '🎯 Route: ${pedData['route']}' : ''}

⚠️ Always verify with current pediatric dosing guidelines
        ''';
      }
    } else if (medData.containsKey('adult')) {
      final adultData = medData['adult'];
      result = '''
📊 Adult Dosing for $_selectedMedForDosage
Weight: ${weight}kg${age != null ? ', Age: ${age}y' : ''}

💊 Standard Dose: ${adultData['dose']}
📅 Frequency: ${adultData['frequency']}
📊 Maximum daily: ${adultData['maxDaily']}

⚠️ Adjust for renal/hepatic impairment as needed
      ''';
    }

    setState(() {
      _calculatedDosage = result;
    });
    HapticFeedback.mediumImpact();
  }

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.sm),
        child: Text(
          title.toUpperCase(),
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _sectionDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: Divider(height: 1, color: AppTheme.dividerColor),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SlideUpAnimation(child: _buildUnifiedMedicationCard()),
                  if (_analysisResult.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.lg),
                    FadeInAnimation(child: _buildAnalysisCard()),
                  ],
                  const SizedBox(height: AppTheme.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMedicationCard() {
    final severity = _severityResults['overall'];
    final severityColor = severity != null ? _getSeverityColor(severity) : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: AppTheme.md),
            color: const Color(0xFFFFF7ED),
            child: Row(
              children: [
                Icon(Icons.medication_outlined, color: Colors.orange.shade800, size: 22),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    'Drug interaction check',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                if (_currentMedications.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentMedications.length} meds',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                if (severity != null && severityColor != null) ...[
                  const SizedBox(width: AppTheme.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: severityColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Patient'),
                PatientLogSelector(
                  patients: _patients,
                  selectedPatient: _selectedPatient,
                  isLoading: _isLoadingPatients,
                  onSelected: (p) {
                    if (p != null) _applyPatient(p, importChartMeds: true);
                    else setState(() => _selectedPatient = null);
                  },
                  onRefresh: _loadInitialPatient,
                ),
                if (_selectedPatient != null && _selectedPatient!.prescriptions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.sm),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _importChartMedications,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Import meds from chart'),
                      ),
                    ),
                  ),
                _sectionDivider(),
                _sectionLabel('Add medication'),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _medicationController,
                        focusNode: _medicationFocus,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Medication name',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FB),
                          prefixIcon: const Icon(Icons.medication_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addMedication(),
                      ),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _doseController,
                        decoration: InputDecoration(
                          hintText: 'Dose',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addMedication(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add to list'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  _selectedPatient != null ? 'Quick add (chart + common)' : 'Common medications',
                  style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: AppTheme.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickMedicationChips.map((med) {
                    final fromChart = _selectedPatient?.prescriptions.contains(med) ?? false;
                    return ActionChip(
                      label: Text(med, style: const TextStyle(fontSize: 12)),
                      avatar: fromChart
                          ? Icon(Icons.assignment_outlined, size: 14, color: AppTheme.primaryColor)
                          : null,
                      onPressed: () {
                        _medicationController.text = med;
                        _addMedication();
                      },
                    );
                  }).toList(),
                ),
                if (_currentMedications.isNotEmpty) ...[
                  _sectionDivider(),
                  _sectionLabel('Medication list (${_currentMedications.length})'),
                  ...List.generate(_currentMedications.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.sm),
                      child: Material(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.medication, color: Colors.orange.shade700, size: 20),
                          title: Text(_currentMedications[index], style: AppTheme.bodyMedium),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeMedication(index),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppTheme.lg),
                  _buildCheckSafetyButton(),
                  const SizedBox(height: AppTheme.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showDosageCalculator = !_showDosageCalculator);
                      if (_showDosageCalculator && _selectedPatient != null) {
                        _ageController.text = '${_selectedPatient!.age}';
                      }
                    },
                    icon: Icon(_showDosageCalculator ? Icons.expand_less : Icons.calculate_outlined),
                    label: Text(_showDosageCalculator ? 'Hide dosage calculator' : 'Dosage calculator'),
                  ),
                  if (_showDosageCalculator) ...[
                    const SizedBox(height: AppTheme.md),
                    _buildDosageCalculatorCard(),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.xl),
                    child: Text(
                      'Select a patient and add medications to run interaction analysis.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.orange.shade700,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.orange.shade700,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medication Safety',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Drug Interaction Analysis',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_currentMedications.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.medication_outlined,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentMedications.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      actions: [
        if (_currentMedications.isNotEmpty || _analysisResult.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
      ],
    );
  }


  Widget _buildCheckSafetyButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeMedicationSafety,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.shield_outlined),
        label: Text(_isAnalyzing ? 'Analyzing interactions…' : 'Check drug interactions'),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final severity = _severityResults['overall'] ?? 'LOW';
    final severityColor = _getSeverityColor(severity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: severityColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Severity Indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  severityColor.withValues(alpha: 0.08),
                  severityColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSeverityIcon(severity),
                        color: severityColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safety Analysis Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: severityColor,
                            ),
                          ),
                          Text(
                            '${_currentMedications.length} medications analyzed',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy analysis',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _analysisResult));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analysis copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Severity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: severityColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSeverityIcon(severity),
                        color: severityColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$severity RISK LEVEL',
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _analysisResult,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
          // Footer with Save Button
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify with a clinical pharmacist before prescribing.',
                  style: AppTheme.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Wrap(
                  spacing: AppTheme.sm,
                  runSpacing: AppTheme.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    if (_selectedPatient != null)
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRouter.patientDetail,
                          arguments: _selectedPatient,
                        ),
                        icon: const Icon(Icons.person_outline, size: 18),
                        label: const Text('Patient chart'),
                      ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveMedicationAnalysisToNotes,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSaving ? 'Saving…' : 'Save to notes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return AppTheme.dangerColor;
      case 'HIGH':
        return AppTheme.warningColor;
      case 'MODERATE':
        return AppTheme.primaryColor;
      case 'LOW':
      default:
        return AppTheme.successColor;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Icons.warning_amber_rounded;
      case 'HIGH':
        return Icons.error_outline;
      case 'MODERATE':
        return Icons.info_outline;
      case 'LOW':
      default:
        return Icons.check_circle_outline;
    }
  }


  Widget _buildDosageCalculatorCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pediatric & Adult Dosage Calculator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Patient Info Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 70.5',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (y)',
                    hintText: 'e.g. 25',
                    suffixText: 'years',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // Medication Selection
          DropdownButtonFormField<String>(
            value: _selectedMedForDosage.isEmpty ? null : _selectedMedForDosage,
            decoration: const InputDecoration(
              labelText: 'Select Medication',
              border: OutlineInputBorder(),
            ),
            items: _dosageData.keys.map((String medication) {
              return DropdownMenuItem<String>(
                value: medication,
                child: Text(medication),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedMedForDosage = newValue ?? '';
                _calculatedDosage = '';
              });
            },
          ),
          const SizedBox(height: AppTheme.lg),

          // Calculate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _calculateDosage,
              icon: const Icon(Icons.calculate),
              label: const Text(
                'Calculate Dosage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Results
          if (_calculatedDosage.isNotEmpty) ...[
            const SizedBox(height: AppTheme.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Calculated Dosage',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _calculatedDosage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppTheme.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppTheme.warningColor,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Always verify dosage with current clinical guidelines and consider patient-specific factors',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
