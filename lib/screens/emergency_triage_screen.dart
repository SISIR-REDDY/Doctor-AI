import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_error_handler.dart';
import '../core/healthcare/emergency_triage_share.dart';
import '../core/navigation/app_router.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import '../widgets/emergency/emergency_patient_panel.dart';

class EmergencyTriageScreen extends StatefulWidget {
  final String? patientId;
  final String? initialTriageId;

  const EmergencyTriageScreen({
    super.key,
    this.patientId,
    this.initialTriageId,
  });

  @override
  State<EmergencyTriageScreen> createState() => _EmergencyTriageScreenState();
}

class _EmergencyTriageScreenState extends State<EmergencyTriageScreen>
    with SingleTickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _triageNotesController = TextEditingController();

  // Structured Vital Signs Controllers
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _heartRateController = TextEditingController();
  final TextEditingController _respRateController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _o2SatController = TextEditingController();

  late AnimationController _pulseController;

  bool _isAssessing = false;
  bool _isSaving = false;
  String _triageAssessment = '';
  String _priorityLevel = '';
  int _esiLevel = 0; // Emergency Severity Index (1-5)
  Color _priorityColor = AppTheme.primaryColor;
  IconData _priorityIcon = Icons.info;

  ProviderPatientRecord? _currentPatient;
  final List<ProviderPatientRecord> _patients = [];
  StreamSubscription<List<ProviderPatientRecord>>? _patientsSubscription;
  bool _isLoadingPatient = true;
  String _arrivalMode = 'walk-in';
  String? _savedTriageId;
  EmergencyTriageRecord? _lastSavedRecord;

  int _painLevel = 0;

  // Quick complaint templates for common emergencies
  final List<Map<String, dynamic>> _quickComplaintTemplates = [
    {
      'name': 'Chest Pain',
      'icon': Icons.favorite,
      'color': Color(0xFFDC2626),
      'complaint': 'Chest pain',
      'symptoms': 'Onset, location, radiation, quality (crushing/sharp), associated symptoms (shortness of breath, diaphoresis, nausea)',
    },
    {
      'name': 'SOB',
      'icon': Icons.air,
      'color': Color(0xFF2563EB),
      'complaint': 'Shortness of breath',
      'symptoms': 'Onset, severity, associated cough, wheezing, orthopnea, PND, leg swelling',
    },
    {
      'name': 'Stroke',
      'icon': Icons.psychology,
      'color': Color(0xFF7C3AED),
      'complaint': 'Suspected stroke - FAST positive',
      'symptoms': 'Facial droop, arm weakness, speech difficulty, time of onset',
    },
    {
      'name': 'Abdominal',
      'icon': Icons.sick,
      'color': Color(0xFFF59E0B),
      'complaint': 'Abdominal pain',
      'symptoms': 'Location, onset, character, radiation, associated nausea/vomiting, fever, bowel changes',
    },
    {
      'name': 'Trauma',
      'icon': Icons.personal_injury,
      'color': Color(0xFFEF4444),
      'complaint': 'Trauma / Injury',
      'symptoms': 'Mechanism of injury, location, deformity, neurovascular status, bleeding',
    },
    {
      'name': 'Altered Mental',
      'icon': Icons.psychology_alt,
      'color': Color(0xFF8B5CF6),
      'complaint': 'Altered mental status',
      'symptoms': 'Baseline mental status, onset, fluctuation, associated symptoms, medication/drug use',
    },
    {
      'name': 'Fever',
      'icon': Icons.thermostat,
      'color': Color(0xFFEA580C),
      'complaint': 'Fever / Infection',
      'symptoms': 'Duration, max temperature, source symptoms (cough, dysuria, wound), immunocompromised status',
    },
    {
      'name': 'Syncope',
      'icon': Icons.airline_seat_flat,
      'color': Color(0xFF0891B2),
      'complaint': 'Syncope / Near-syncope',
      'symptoms': 'Prodrome, witnesses, duration of LOC, post-event confusion, cardiac history',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    StorageService().warmPatientPhotosCache();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadPatientData();
    _watchPatients();
    final triageId = widget.initialTriageId?.trim();
    if (triageId != null && triageId.isNotEmpty) {
      await _importTriageById(triageId);
    }
  }

  void _watchPatients() {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) return;
    _patientsSubscription?.cancel();
    _patientsSubscription = _firestoreService.watchDoctorPatients(doctorId).listen((list) {
      if (!mounted) return;
      setState(() => _patients..clear()..addAll(list));
      if (_currentPatient != null) {
        ProviderPatientRecord? updated;
        for (final p in list) {
          if (p.id == _currentPatient!.id) {
            updated = p;
            break;
          }
        }
        if (updated != null) _currentPatient = updated;
      }
    });
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _pulseController.dispose();
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _triageNotesController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _respRateController.dispose();
    _tempController.dispose();
    _o2SatController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    final id = widget.patientId?.trim();
    if (id == null || id.isEmpty || id == 'no-patient') {
      setState(() => _isLoadingPatient = false);
      return;
    }

    try {
      final doctorId = _authService.currentUser?.uid;
      if (doctorId == null) {
        setState(() => _isLoadingPatient = false);
        return;
      }

      final patients = await _firestoreService.getDoctorPatients(doctorId);
      ProviderPatientRecord? patient;
      for (final p in patients) {
        if (p.id == id) {
          patient = p;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _currentPatient = patient;
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatient = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _onPatientSelected(ProviderPatientRecord? patient) {
    setState(() => _currentPatient = patient);
  }

  Future<void> _importTriageById(String idOrCode) async {
    setState(() => _isLoadingPatient = true);
    try {
      EmergencyTriageRecord? record =
          await _firestoreService.getEmergencyTriageById(idOrCode);
      record ??= await _firestoreService.findEmergencyTriageByShareCode(idOrCode);
      if (record == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Triage case not found. Check the share code.')),
          );
        }
        return;
      }
      _applyImportedRecord(record);
      if (record.patientId.isNotEmpty && _patients.isNotEmpty) {
        ProviderPatientRecord? linked;
        for (final p in _patients) {
          if (p.id == record.patientId) {
            linked = p;
            break;
          }
        }
        if (linked != null) _currentPatient = linked;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded triage case ${record.shareCode}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoadingPatient = false);
    }
  }

  void _applyImportedRecord(EmergencyTriageRecord record) {
    setState(() {
      _chiefComplaintController.text = record.chiefComplaint;
      _symptomsController.text = record.symptoms;
      _triageNotesController.text = record.triageNotes;
      _painLevel = record.painLevel;
      _arrivalMode = record.arrivalMode;
      _triageAssessment = record.aiAssessment;
      _priorityLevel = record.priorityLevel;
      _esiLevel = record.esiLevel;
      _savedTriageId = record.id;
      _lastSavedRecord = record;
      if (record.priorityLevel.isNotEmpty) _applyPriorityStyle(record.priorityLevel);
    });
  }

  void _applyPriorityStyle(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        _priorityColor = AppTheme.dangerColor;
        _priorityIcon = Icons.warning_rounded;
      case 'HIGH':
        _priorityColor = AppTheme.warningColor;
        _priorityIcon = Icons.priority_high_rounded;
      case 'MEDIUM':
        _priorityColor = AppTheme.primaryColor;
        _priorityIcon = Icons.info_rounded;
      default:
        _priorityColor = AppTheme.successColor;
        _priorityIcon = Icons.check_circle_rounded;
    }
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import shared case'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Share code or Triage ID',
            hintText: 'e.g. A1B2C3D4',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) await _importTriageById(code);
  }

  Future<EmergencyTriageRecord?> _buildTriageRecord() async {
    final doctorId = _authService.currentUser?.uid ?? '';
    if (doctorId.isEmpty) return null;

    final patient = _currentPatient;
    final id = _savedTriageId ?? 'triage_${_uuid.v4()}';

    if (patient != null) {
      return EmergencyTriageRecord.fromPatient(
        id: id,
        doctorId: doctorId,
        patient: patient,
        chiefComplaint: _chiefComplaintController.text.trim(),
        symptoms: _symptomsController.text.trim(),
        vitalSignsSummary: _buildVitalSignsString(),
        painLevel: _painLevel,
        arrivalMode: _arrivalMode,
        triageNotes: _triageNotesController.text.trim(),
        esiLevel: _esiLevel,
        priorityLevel: _priorityLevel,
        aiAssessment: _triageAssessment,
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
      );
    }

    return EmergencyTriageRecord(
      id: id,
      doctorId: doctorId,
      patientId: '',
      patientName: 'Unknown patient',
      chiefComplaint: _chiefComplaintController.text.trim(),
      symptoms: _symptomsController.text.trim(),
      vitalSignsSummary: _buildVitalSignsString(),
      painLevel: _painLevel,
      arrivalMode: _arrivalMode,
      triageNotes: _triageNotesController.text.trim(),
      esiLevel: _esiLevel,
      priorityLevel: _priorityLevel,
      aiAssessment: _triageAssessment,
      createdBy: _authService.currentUser?.displayName ?? 'Clinician',
    );
  }

  Future<void> _persistTriageRecord() async {
    final record = await _buildTriageRecord();
    if (record == null) return;
    await _firestoreService.saveEmergencyTriage(record);
    setState(() {
      _savedTriageId = record.id;
      _lastSavedRecord = record;
    });
  }

  Future<void> _shareTriageHandoff() async {
    if (_triageAssessment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run triage assessment before sharing')),
      );
      return;
    }
    if (_currentPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a patient from your log to share with full details')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _persistTriageRecord();
      final record = _lastSavedRecord;
      if (record == null) return;

      final message = EmergencyTriageShare.buildShareMessage(
        record: record,
        doctorName: _authService.currentUser?.displayName ?? 'Clinician',
      );
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Emergency Triage — ${record.patientName} (${record.priorityLevel})',
        ),
      );
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildVitalSignsString() {
    final parts = <String>[];
    if (_bpSystolicController.text.isNotEmpty && _bpDiastolicController.text.isNotEmpty) {
      parts.add('BP: ${_bpSystolicController.text}/${_bpDiastolicController.text} mmHg');
    }
    if (_heartRateController.text.isNotEmpty) {
      parts.add('HR: ${_heartRateController.text} bpm');
    }
    if (_respRateController.text.isNotEmpty) {
      parts.add('RR: ${_respRateController.text}/min');
    }
    if (_tempController.text.isNotEmpty) {
      parts.add('Temp: ${_tempController.text}°F');
    }
    if (_o2SatController.text.isNotEmpty) {
      parts.add('SpO2: ${_o2SatController.text}%');
    }
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  Future<void> _performTriageAssessment() async {
    if (_chiefComplaintController.text.trim().isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        'Please enter the chief complaint to proceed with triage assessment.',
      );
      return;
    }

    setState(() => _isAssessing = true);

    try {
      final vitalSigns = _buildVitalSignsString();
      final prompt = '''
As an experienced emergency medicine physician, perform a triage assessment using the Emergency Severity Index (ESI) 5-level system:

ESI Level Guide:
- ESI-1: Immediate life-threatening (requires immediate intervention)
- ESI-2: Emergent (high risk, confused/lethargic, severe pain)
- ESI-3: Urgent (needs multiple resources, stable)
- ESI-4: Less Urgent (needs one resource)
- ESI-5: Non-urgent (no resources needed)

**Chief Complaint:** ${_chiefComplaintController.text.trim()}
**Vital Signs:** $vitalSigns
**Symptoms:** ${_symptomsController.text.trim().isEmpty ? 'Not provided' : _symptomsController.text.trim()}
**Pain Level (0-10):** $_painLevel

${_currentPatient != null ? '''
**Patient Information:**
- Name: ${_currentPatient!.fullName}
- Age: ${_currentPatient!.age}
- Medical History: ${_currentPatient!.medicalHistory.isEmpty ? 'None documented' : _currentPatient!.medicalHistory.join(', ')}
- Allergies: ${_currentPatient!.allergies.isEmpty ? 'None known' : _currentPatient!.allergies.join(', ')}
''' : ''}

Please provide a structured assessment:

## ESI LEVEL
State the ESI level (1-5) with clear justification

## TRIAGE PRIORITY
(CRITICAL/HIGH/MEDIUM/LOW) based on ESI level

## IMMEDIATE ACTIONS
Steps to take within the first 15 minutes

## CLINICAL ASSESSMENT
Key observations and differential diagnoses to consider

## RECOMMENDED WORKUP
Diagnostic tests and procedures needed

## RED FLAGS
Warning signs requiring immediate escalation

## DISPOSITION RECOMMENDATION
Suggested next steps (admit, observe, discharge with follow-up)
''';

      final response = await _chatbotService.getGeminiResponse(prompt);

      if (mounted) {
        setState(() {
          _triageAssessment = response;
          _determinePriorityFromResponse(response);
          _isAssessing = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssessing = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _determinePriorityFromResponse(String response) {
    final lowercaseResponse = response.toLowerCase();

    // Extract ESI Level — handles: "ESI-2", "ESI 2", "ESI Level 2", "ESI-Level-2", "level 2"
    final esiMatch = RegExp(r'esi[\s\-]?(?:level[\s\-]?)?(\d)|esi[\s\-](\d)').firstMatch(lowercaseResponse);
    if (esiMatch != null) {
      final raw = esiMatch.group(1) ?? esiMatch.group(2) ?? '';
      final parsed = int.tryParse(raw) ?? 0;
      if (parsed >= 1 && parsed <= 5) _esiLevel = parsed;
    }

    if (lowercaseResponse.contains('critical') || lowercaseResponse.contains('emergent') || _esiLevel == 1) {
      _priorityLevel = 'CRITICAL';
      _priorityColor = AppTheme.dangerColor;
      _priorityIcon = Icons.warning_rounded;
      if (_esiLevel == 0) _esiLevel = 1;
    } else if (lowercaseResponse.contains('high') || lowercaseResponse.contains('urgent') || _esiLevel == 2) {
      _priorityLevel = 'HIGH';
      _priorityColor = AppTheme.warningColor;
      _priorityIcon = Icons.priority_high_rounded;
      if (_esiLevel == 0) _esiLevel = 2;
    } else if (lowercaseResponse.contains('medium') || lowercaseResponse.contains('moderate') || _esiLevel == 3) {
      _priorityLevel = 'MEDIUM';
      _priorityColor = AppTheme.primaryColor;
      _priorityIcon = Icons.info_rounded;
      if (_esiLevel == 0) _esiLevel = 3;
    } else {
      _priorityLevel = 'LOW';
      _priorityColor = AppTheme.successColor;
      _priorityIcon = Icons.check_circle_rounded;
      if (_esiLevel == 0) _esiLevel = 4;
    }
  }

  Future<void> _saveTriageToClinicalNotes() async {
    if (_triageAssessment.isEmpty) return;

    final patientId = _currentPatient?.id ?? widget.patientId;
    if (patientId == null || patientId.isEmpty || patientId == 'no-patient') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a patient from your log to save the triage assessment'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _persistTriageRecord();

      final doctorId = _authService.currentUser?.uid ?? '';
      final now = DateTime.now();
      final note = ClinicalNote(
        id: 'note_${_uuid.v4()}',
        patientId: patientId,
        doctorId: doctorId,
        title: 'Emergency Triage - $_priorityLevel (ESI-$_esiLevel)',
        content: '''Chief Complaint: ${_chiefComplaintController.text.trim()}
Arrival: $_arrivalMode
Vital Signs: ${_buildVitalSignsString()}
Pain Level: $_painLevel/10
Symptoms: ${_symptomsController.text.trim().isEmpty ? 'Not provided' : _symptomsController.text.trim()}
Handoff notes: ${_triageNotesController.text.trim().isEmpty ? '—' : _triageNotesController.text.trim()}

--- AI TRIAGE ASSESSMENT ---

$_triageAssessment''',
        diagnosis: 'Emergency Triage - $_priorityLevel Priority',
        treatments: [],
        followUpItems: ['Monitor vitals', 'Reassess as needed'],
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
        noteType: 'ai',
        createdAt: now,
        updatedAt: now,
      );

      await _firestoreService.saveClinicalReport(note);

      if (_currentPatient != null) {
        final updated = _currentPatient!.copyWith(
          lastVisitSummary: 'Emergency triage: ${_chiefComplaintController.text.trim()}',
          updatedAt: now,
        );
        await _firestoreService.savePatientRecord(updated);
        _currentPatient = updated;
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Triage saved to clinical notes'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
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

  void _clearAssessment() {
    setState(() {
      _triageAssessment = '';
      _priorityLevel = '';
      _esiLevel = 0;
      _priorityColor = AppTheme.primaryColor;
      _chiefComplaintController.clear();
      _symptomsController.clear();
      _bpSystolicController.clear();
      _bpDiastolicController.clear();
      _heartRateController.clear();
      _respRateController.clear();
      _tempController.clear();
      _o2SatController.clear();
      _painLevel = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoadingPatient
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Professional Gradient App Bar
                _buildSliverAppBar(),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SlideUpAnimation(child: _buildUnifiedTriageCard()),
                        if (_triageAssessment.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.lg),
                          FadeInAnimation(child: _buildAssessmentResults()),
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

  Widget _sectionLabel(String title) {
    return Padding(
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
  }

  Widget _sectionDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: Divider(height: 1, color: AppTheme.dividerColor),
      );

  Widget _buildUnifiedTriageCard() {
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
            color: const Color(0xFFFEF2F2),
            child: Row(
              children: [
                Icon(Icons.emergency, color: AppTheme.dangerColor, size: 22),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    'Triage assessment',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                ),
                if (_priorityLevel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_priorityIcon, size: 14, color: _priorityColor),
                        const SizedBox(width: 4),
                        Text(
                          _esiLevel > 0 ? 'ESI-$_esiLevel · $_priorityLevel' : _priorityLevel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Patient'),
                EmergencyTriagePatientSection(
                  patients: _patients,
                  selectedPatient: _currentPatient,
                  isLoading: _isLoadingPatient,
                  onPatientSelected: _onPatientSelected,
                  onRefresh: _loadPatientData,
                  triageNotesController: _triageNotesController,
                  arrivalMode: _arrivalMode,
                  onArrivalModeChanged: (m) => setState(() => _arrivalMode = m),
                ),
                _sectionDivider(),
                _sectionLabel('Quick templates'),
                _buildQuickComplaintTemplates(compact: true),
                _sectionDivider(),
                _sectionLabel('Chief complaint & vitals'),
                _buildFormField(
                  label: 'Chief complaint',
                  required: true,
                  icon: Icons.report_problem_outlined,
                  controller: _chiefComplaintController,
                  hint: 'Primary reason for visit',
                  maxLines: 2,
                ),
                const SizedBox(height: AppTheme.md),
                _buildVitalSignsSection(),
                const SizedBox(height: AppTheme.md),
                _buildFormField(
                  label: 'Symptoms',
                  icon: Icons.medical_information_outlined,
                  controller: _symptomsController,
                  hint: 'Onset, duration, severity',
                  maxLines: 2,
                ),
                _sectionDivider(),
                _sectionLabel('Pain level'),
                _buildPainLevelInline(),
                const SizedBox(height: AppTheme.lg),
                _buildAssessButton(),
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
      backgroundColor: Colors.red.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.red.shade300,
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
                          Icons.emergency,
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
                              'Emergency Triage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI-Powered Priority Assessment',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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
        IconButton(
          onPressed: _showImportDialog,
          icon: const Icon(Icons.download_outlined, color: Colors.white),
          tooltip: 'Import shared case',
        ),
        if (_triageAssessment.isNotEmpty) ...[
          IconButton(
            onPressed: _isSaving ? null : _shareTriageHandoff,
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Share handoff',
          ),
          IconButton(
            onPressed: _clearAssessment,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'New Assessment',
          ),
        ],
      ],
    );
  }

  Widget _buildQuickComplaintTemplates({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Icon(Icons.flash_on, size: 16, color: AppTheme.warningColor),
              const SizedBox(width: 6),
              Text(
                'Quick templates',
                style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
        ],
        _buildEsiQuickReference(),
        const SizedBox(height: AppTheme.sm),
        SizedBox(
          height: compact ? 76 : 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickComplaintTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
            itemBuilder: (context, index) {
              final template = _quickComplaintTemplates[index];
              final color = template['color'] as Color;
              return GestureDetector(
                onTap: () => _applyQuickTemplate(template),
                child: _buildQuickTemplateChip(
                  template: template,
                  color: color,
                  compact: compact,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTemplateChip({
    required Map<String, dynamic> template,
    required Color color,
    required bool compact,
  }) {
    final iconSize = compact ? 18.0 : 20.0;
    final iconPad = compact ? 6.0 : 8.0;
    final outerPad = compact ? 6.0 : AppTheme.sm;
    final labelSize = compact ? 10.0 : 11.0;

    return Container(
      width: compact ? 76 : 85,
      padding: EdgeInsets.all(outerPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(iconPad),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              template['icon'] as IconData,
              color: color,
              size: iconSize,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            template['name'] as String,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEsiQuickReference() {
    const levels = [
      (1, 'Immediate', Color(0xFFDC2626)),
      (2, 'Emergent', Color(0xFFEA580C)),
      (3, 'Urgent', Color(0xFFF59E0B)),
      (4, 'Less urgent', Color(0xFF2563EB)),
      (5, 'Non-urgent', Color(0xFF059669)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: levels.map((e) {
          final (level, label, color) = e;
          return Container(
            margin: const EdgeInsets.only(right: AppTheme.sm),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              'ESI-$level $label',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _applyQuickTemplate(Map<String, dynamic> template) {
    setState(() {
      _chiefComplaintController.text = template['complaint'] as String;
      _symptomsController.text = template['symptoms'] as String;
    });
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${template['name']} template'),
        duration: const Duration(seconds: 1),
        backgroundColor: template['color'] as Color,
      ),
    );
  }

  Widget _buildVitalSignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monitor_heart_outlined, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Vital Signs',
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            // Vital Signs Legend
            _buildVitalLegend(),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Blood Pressure Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _bpSystolicController,
                hint: 'Systolic',
                suffix: 'mmHg',
                normalMin: 90,
                normalMax: 140,
                criticalMin: 70,
                criticalMax: 180,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: AppTheme.headingSmall),
            ),
            Expanded(
              child: _buildVitalTextField(
                controller: _bpDiastolicController,
                hint: 'Diastolic',
                normalMin: 60,
                normalMax: 90,
                criticalMin: 40,
                criticalMax: 110,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Heart Rate, Resp Rate Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _heartRateController,
                hint: 'Heart Rate',
                suffix: 'bpm',
                normalMin: 60,
                normalMax: 100,
                criticalMin: 40,
                criticalMax: 150,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _buildVitalTextField(
                controller: _respRateController,
                hint: 'Resp Rate',
                suffix: '/min',
                normalMin: 12,
                normalMax: 20,
                criticalMin: 8,
                criticalMax: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Temp, O2 Sat Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _tempController,
                hint: 'Temp',
                suffix: '°F',
                normalMin: 97.0,
                normalMax: 99.5,
                criticalMin: 95.0,
                criticalMax: 104.0,
                isDecimal: true,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _buildVitalTextField(
                controller: _o2SatController,
                hint: 'SpO2',
                suffix: '%',
                normalMin: 95,
                normalMax: 100,
                criticalMin: 88,
                criticalMax: 100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Normal', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.warningColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Abnormal', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.dangerColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Critical', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildVitalTextField({
    required TextEditingController controller,
    required String hint,
    String? suffix,
    required double normalMin,
    required double normalMax,
    required double criticalMin,
    required double criticalMax,
    bool isDecimal = false,
  }) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        Color getBorderColor() {
          final text = controller.text.trim();
          if (text.isEmpty) return AppTheme.dividerColor;

          final value = double.tryParse(text);
          if (value == null) return AppTheme.dividerColor;

          if (value < criticalMin || value > criticalMax) {
            return AppTheme.dangerColor;
          } else if (value < normalMin || value > normalMax) {
            return AppTheme.warningColor;
          }
          return AppTheme.successColor;
        }

        Color getIndicatorColor() {
          final text = controller.text.trim();
          if (text.isEmpty) return Colors.transparent;

          final value = double.tryParse(text);
          if (value == null) return Colors.transparent;

          if (value < criticalMin || value > criticalMax) {
            return AppTheme.dangerColor;
          } else if (value < normalMin || value > normalMax) {
            return AppTheme.warningColor;
          }
          return AppTheme.successColor;
        }

        final borderColor = getBorderColor();
        final indicatorColor = getIndicatorColor();

        return Stack(
          children: [
            TextField(
              controller: controller,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              onChanged: (_) => setLocalState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                suffixText: suffix,
                suffixStyle: AppTheme.bodySmall,
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor, width: borderColor == AppTheme.dividerColor ? 1 : 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor == AppTheme.dividerColor ? AppTheme.dangerColor : borderColor, width: 2),
                ),
              ),
            ),
            if (indicatorColor != Colors.transparent)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool required = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.dangerColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md,
              vertical: AppTheme.sm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPainLevelInline() {
    return Column(
      children: [
        Row(
          children: [
            Text(_getPainDescription(), style: AppTheme.labelMedium.copyWith(color: _getPainColor())),
            const Spacer(),
            Text(
              '$_painLevel / 10',
              style: TextStyle(color: _getPainColor(), fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _getPainColor(),
            inactiveTrackColor: _getPainColor().withValues(alpha: 0.15),
            thumbColor: _getPainColor(),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
          ),
          child: Slider(
            value: _painLevel.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (value) {
              setState(() => _painLevel = value.toInt());
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }

  Color _getPainColor() {
    if (_painLevel <= 3) return AppTheme.successColor;
    if (_painLevel <= 6) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  String _getPainDescription() {
    if (_painLevel == 0) return 'None';
    if (_painLevel <= 3) return 'Mild';
    if (_painLevel <= 6) return 'Moderate';
    if (_painLevel <= 8) return 'Severe';
    return 'Extreme';
  }

  Widget _buildAssessButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isAssessing ? null : _performTriageAssessment,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.dangerColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _isAssessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.medical_services_outlined),
        label: Text(_isAssessing ? 'Analyzing…' : 'Run AI triage assessment'),
      ),
    );
  }

  Widget _buildAssessmentResults() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: _priorityColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _priorityColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_information, color: _priorityColor, size: 24),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Triage Assessment Results',
                        style: AppTheme.headingSmall.copyWith(color: _priorityColor),
                      ),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _triageAssessment));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assessment copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: SelectableText(
              _triageAssessment,
              style: AppTheme.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          // Footer with Save Button
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AI-generated. Clinical judgment required.',
                  style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: AppTheme.sm),
                Wrap(
                  spacing: AppTheme.sm,
                  runSpacing: AppTheme.sm,
                  children: [
                TextButton.icon(
                  onPressed: _currentPatient == null
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.patientDetail,
                            arguments: _currentPatient,
                          );
                        },
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Patient chart'),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _shareTriageHandoff,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveTriageToClinicalNotes,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.successColor),
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
}
