import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import '../widgets/clinical/clinical_voice_input.dart';
import '../widgets/patient/patient_log_selector.dart';
import '../screens/doctor_patient_create_edit_screen.dart';

class WardRoundsScreen extends StatefulWidget {
  final String? patientId;

  const WardRoundsScreen({super.key, this.patientId});

  @override
  State<WardRoundsScreen> createState() => _WardRoundsScreenState();
}

class _WardRoundsScreenState extends State<WardRoundsScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  final TextEditingController _progressNotesController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _ordersController = TextEditingController();

  bool _isGenerating = false;
  bool _isSaving = false;
  String _roundsSummary = '';

  final List<ProviderPatientRecord> _patients = [];
  ProviderPatientRecord? _selectedPatient;
  bool _isLoadingPatients = true;
  StreamSubscription<List<ProviderPatientRecord>>? _patientsSubscription;

  List<ClinicalNote> _previousRounds = [];
  bool _isLoadingHistory = false;

  /// Patients marked done during today's round session.
  final Set<String> _completedRoundIds = {};

  @override
  void initState() {
    super.initState();
    StorageService().warmPatientPhotosCache();
    _bootstrap();
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _progressNotesController.dispose();
    _planController.dispose();
    _ordersController.dispose();
    super.dispose();
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
    if (id == null || id.isEmpty || id == 'no-patient') return;
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) return;
    try {
      final list = await _firestoreService.getDoctorPatients(doctorId);
      for (final p in list) {
        if (p.id == id) {
          if (mounted) _applyPatient(p);
          break;
        }
      }
    } catch (_) {}
  }

  String _displayName(ProviderPatientRecord p) {
    final name = p.fullName.trim();
    if (name.isNotEmpty) return name;
    if (p.id.isNotEmpty) return 'Patient ${p.id.length > 6 ? p.id.substring(0, 6) : p.id}';
    return 'Unnamed patient';
  }

  void _applyPatient(ProviderPatientRecord p, {bool clearForm = true}) {
    setState(() {
      _selectedPatient = p;
      _roundsSummary = '';
      if (clearForm) {
        _progressNotesController.clear();
        _planController.clear();
        _ordersController.clear();
      }
      _previousRounds = [];
    });
    _loadPreviousRounds().then((_) {
      if (mounted) _prefillFromChartAndHistory();
    });
  }

  void _prefillFromChartAndHistory() {
    final p = _selectedPatient;
    if (p == null) return;

    if (_progressNotesController.text.trim().isEmpty) {
      final parts = <String>[];
      if (p.lastVisitSummary.trim().isNotEmpty) {
        parts.add('Last visit: ${p.lastVisitSummary.trim()}');
      }
      if (_previousRounds.isNotEmpty) {
        final snippet = _extractSection(_previousRounds.first.content, 'Progress Notes');
        if (snippet.isNotEmpty) {
          parts.add('Prior round: $snippet');
        }
      }
      if (parts.isNotEmpty) {
        _progressNotesController.text = parts.join('\n\n');
      }
    }

    if (_ordersController.text.trim().isEmpty && p.prescriptions.isNotEmpty) {
      _ordersController.text = 'Current meds: ${p.prescriptions.join(', ')}';
    }
  }

  String _extractSection(String content, String label) {
    final marker = '$label:';
    final idx = content.indexOf(marker);
    if (idx < 0) return '';
    var rest = content.substring(idx + marker.length).trim();
    final nextMarkers = ['Treatment Plan', 'New Orders', '--- AI'];
    var end = rest.length;
    for (final m in nextMarkers) {
      final i = rest.indexOf(m);
      if (i > 0 && i < end) end = i;
    }
    rest = rest.substring(0, end).trim();
    if (rest.length > 280) return '${rest.substring(0, 277)}…';
    return rest;
  }

  Future<void> _loadPreviousRounds() async {
    if (_selectedPatient == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final allNotes = await _firestoreService.getClinicalReports(_selectedPatient!.id);
      final rounds = allNotes.where((note) {
        final t = note.title.toLowerCase();
        return t.contains('ward rounds') || note.noteType == 'ward_rounds';
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _previousRounds = rounds;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _openVoiceFor(TextEditingController controller, String fieldLabel) async {
    if (_selectedPatient == null) {
      AppErrorHandler.showSnackBar(context, 'Select a patient first');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClinicalVoiceInput(
        onCancel: () => Navigator.pop(ctx),
        onTranscriptReady: (transcript) {
          Navigator.pop(ctx);
          final existing = controller.text.trim();
          controller.text = existing.isEmpty ? transcript : '$existing\n$transcript';
          setState(() {});
        },
      ),
    );
  }

  Future<void> _generateRoundsSummary() async {
    if (_selectedPatient == null) {
      AppErrorHandler.showSnackBar(context, 'Select a patient from your log');
      return;
    }

    setState(() => _isGenerating = true);
    final p = _selectedPatient!;

    try {
      final allergies = p.allergies.isEmpty ? 'None documented' : p.allergies.join(', ');
      final meds = p.prescriptions.isEmpty ? 'None on chart' : p.prescriptions.join(', ');
      final history = p.medicalHistory.isEmpty ? 'None documented' : p.medicalHistory.join(', ');

      final prompt = '''
As an attending physician conducting ward rounds, create a comprehensive patient summary for:

**Patient:** ${_displayName(p)}, Age ${p.age > 0 ? p.age : 'not documented'}, ${p.gender}
**Allergies:** $allergies
**Current medications:** $meds
**Medical History:** $history

**Current Progress Notes:** ${_progressNotesController.text.trim().isEmpty ? 'No specific notes provided' : _progressNotesController.text.trim()}
**Treatment Plan Updates:** ${_planController.text.trim().isEmpty ? 'No updates provided' : _planController.text.trim()}
**New Orders/Medications:** ${_ordersController.text.trim().isEmpty ? 'No new orders' : _ordersController.text.trim()}

Provide a structured ward rounds summary:

## SUBJECTIVE
- Patient's reported symptoms and concerns
- Review of systems findings

## OBJECTIVE
- Current vital signs and physical exam findings
- Laboratory and diagnostic results (if available)
- Progress since last assessment

## ASSESSMENT
- Current clinical status and stability
- Response to current treatment
- Any changes in condition or new concerns

## PLAN
- Medication adjustments or new prescriptions
- Diagnostic tests or procedures needed
- Goals for next 24-48 hours
- Discharge planning considerations (if applicable)

## FOLLOW-UP ACTIONS
- Specific monitoring parameters
- When to reassess
- Communication needed with patient/family

Format each section with bullet points for bedside reading.
''';

      final response = await _chatbotService.getGeminiResponse(prompt);
      if (mounted) {
        setState(() {
          _roundsSummary = response;
          _isGenerating = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _saveRoundsToClinicalNotes() async {
    if (_roundsSummary.isEmpty || _selectedPatient == null) return;

    setState(() => _isSaving = true);
    final doctorId = _authService.currentUser?.uid ?? '';
    final now = DateTime.now();

    try {
      final note = ClinicalNote(
        id: 'note_${_uuid.v4()}',
        patientId: _selectedPatient!.id,
        doctorId: doctorId,
        title: 'Ward Rounds - ${DateFormat('MMM d, y').format(now)}',
        content: '''Progress Notes: ${_progressNotesController.text.trim().isEmpty ? 'Not provided' : _progressNotesController.text.trim()}

Treatment Plan Updates: ${_planController.text.trim().isEmpty ? 'No updates provided' : _planController.text.trim()}

New Orders/Medications: ${_ordersController.text.trim().isEmpty ? 'No new orders' : _ordersController.text.trim()}

--- AI SOAP SUMMARY ---

$_roundsSummary''',
        diagnosis: 'Ward Rounds Summary',
        treatments: [],
        followUpItems: ['Continue monitoring', 'Reassess at next rounds'],
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
        noteType: 'ward_rounds',
        createdAt: now,
        updatedAt: now,
      );

      await _firestoreService.saveClinicalReport(note);

      final summarySnippet = _roundsSummary.length > 400
          ? '${_roundsSummary.substring(0, 397)}…'
          : _roundsSummary;
      final updatedPatient = _selectedPatient!.copyWith(
        lastVisitSummary: summarySnippet,
        updatedAt: now,
      );
      await _firestoreService.savePatientRecord(updatedPatient);
      _selectedPatient = updatedPatient;

      if (mounted) {
        setState(() {
          _isSaving = false;
          _completedRoundIds.add(_selectedPatient!.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ward rounds saved to clinical notes'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Next patient',
              textColor: Colors.white,
              onPressed: _advanceToNextPatient,
            ),
          ),
        );
        _loadPreviousRounds();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _advanceToNextPatient() {
    if (_patients.isEmpty) return;
    final currentIdx = _selectedPatient == null
        ? -1
        : _patients.indexWhere((p) => p.id == _selectedPatient!.id);

    for (var i = 1; i <= _patients.length; i++) {
      final next = _patients[(currentIdx + i) % _patients.length];
      if (!_completedRoundIds.contains(next.id)) {
        _applyPatient(next);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All patients marked complete for this session')),
    );
  }

  void _clearSummary() {
    setState(() {
      _roundsSummary = '';
      _progressNotesController.clear();
      _planController.clear();
      _ordersController.clear();
    });
  }

  void _loadPriorRoundIntoForm(ClinicalNote round) {
    setState(() {
      _progressNotesController.text = _extractSection(round.content, 'Progress Notes');
      _planController.text = _extractSection(round.content, 'Treatment Plan Updates');
      _ordersController.text = _extractSection(round.content, 'New Orders');
      _roundsSummary = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded prior round into form — update and regenerate')),
    );
  }

  Future<void> _showRoundListSheet() async {
    if (_patients.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (_, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Row(
                  children: [
                    Expanded(child: Text("Today's round list", style: AppTheme.headingSmall)),
                    Text(
                      '${_completedRoundIds.length}/${_patients.length} done',
                      style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: _patients.length,
                  itemBuilder: (_, i) {
                    final p = _patients[i];
                    final done = _completedRoundIds.contains(p.id);
                    final selected = _selectedPatient?.id == p.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: done
                            ? AppTheme.successColor.withValues(alpha: 0.2)
                            : AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Icon(
                          done ? Icons.check : Icons.person_outline,
                          color: done ? AppTheme.successColor : AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(_displayName(p)),
                      subtitle: Text(
                        p.age > 0 ? '${p.age} yrs' : 'Age not set',
                        style: AppTheme.bodySmall,
                      ),
                      trailing: selected ? const Icon(Icons.arrow_forward, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyPatient(p);
                      },
                      onLongPress: () {
                        setState(() {
                          if (done) {
                            _completedRoundIds.remove(p.id);
                          } else {
                            _completedRoundIds.add(p.id);
                          }
                        });
                        setSheetState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text(
                  'Long-press to toggle done · Tap to select',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPatients() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) return;
    try {
      final list = await _firestoreService.getDoctorPatients(doctorId);
      if (mounted) {
        setState(() {
          _patients
            ..clear()
            ..addAll(list);
        });
      }
    } catch (_) {}
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
                  if (_patients.isEmpty && !_isLoadingPatients)
                    FadeInAnimation(child: _buildEmptyState())
                  else ...[
                    SlideUpAnimation(child: _buildUnifiedRoundsCard()),
                    if (_roundsSummary.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.lg),
                      FadeInAnimation(child: _buildRoundsSummaryCard()),
                    ],
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

  Widget _buildSliverAppBar() {
    final doneCount = _completedRoundIds.length;
    final total = _patients.length;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF60A5FA),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: const Color(0xFF60A5FA),
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
                      child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ward Rounds',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _patients.isEmpty ? null : _showRoundListSheet,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            total == 0 ? 'No patients' : '$doneCount/$total done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
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
        if (_roundsSummary.isNotEmpty)
          IconButton(
            onPressed: _clearSummary,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'New round',
          ),
      ],
    );
  }

  Widget _buildUnifiedRoundsCard() {
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
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: Colors.blue.shade800, size: 22),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    'Bedside documentation',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                if (_selectedPatient != null && _previousRounds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_previousRounds.length} prior',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
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
                PatientLogSelector(
                  patients: _patients,
                  selectedPatient: _selectedPatient,
                  isLoading: _isLoadingPatients,
                  onSelected: (p) {
                    if (p != null) {
                      _applyPatient(p);
                    } else {
                      setState(() => _selectedPatient = null);
                    }
                  },
                  onRefresh: _refreshPatients,
                ),
                if (_selectedPatient != null) ...[
                  const SizedBox(height: AppTheme.sm),
                  Wrap(
                    spacing: AppTheme.sm,
                    children: [
                      TextButton.icon(
                        onPressed: _prefillFromChartAndHistory,
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Prefill from chart'),
                      ),
                      if (_patients.length > 1)
                        TextButton.icon(
                          onPressed: _advanceToNextPatient,
                          icon: const Icon(Icons.skip_next, size: 18),
                          label: const Text('Next patient'),
                        ),
                    ],
                  ),
                  if (_isLoadingHistory)
                    const Padding(
                      padding: EdgeInsets.only(top: AppTheme.sm),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (_previousRounds.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    ..._previousRounds.take(2).map((round) => Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.xs),
                          child: Material(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => _loadPriorRoundIntoForm(round),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.sm),
                                child: Row(
                                  children: [
                                    Icon(Icons.history, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: AppTheme.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            round.title,
                                            style: AppTheme.labelSmall.copyWith(fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _formatDate(round.createdAt),
                                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Load',
                                      style: AppTheme.labelSmall.copyWith(color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                  _sectionDivider(),
                  _sectionLabel('Documentation'),
                  _buildFormField(
                    label: 'Progress notes',
                    icon: Icons.note_alt_outlined,
                    controller: _progressNotesController,
                    hint: 'Status, symptoms, response to treatment…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.md),
                  _buildFormField(
                    label: 'Treatment plan updates',
                    icon: Icons.healing_outlined,
                    controller: _planController,
                    hint: 'Plan changes, goals, discharge planning…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.md),
                  _buildFormField(
                    label: 'New orders / medications',
                    icon: Icons.medication_outlined,
                    controller: _ordersController,
                    hint: 'New meds, labs, diagnostics…',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isGenerating || _selectedPatient == null ? null : _generateRoundsSummary,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 20),
                      label: Text(_isGenerating ? 'Generating SOAP…' : 'Generate SOAP summary'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else if (!_isLoadingPatients) ...[
                  _sectionDivider(),
                  Text(
                    'Select a patient from your log to document rounds.',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              onPressed: () => _openVoiceFor(controller, label),
              icon: const Icon(Icons.mic_none, size: 20),
              tooltip: 'Dictate $label',
              visualDensity: VisualDensity.compact,
              color: AppTheme.primaryColor,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundsSummaryCard() {
    final patientName = _selectedPatient != null ? _displayName(_selectedPatient!) : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            color: AppTheme.successColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOAP summary',
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.successColor),
                      ),
                      if (patientName.isNotEmpty)
                        Text(patientName, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _roundsSummary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied'), duration: Duration(seconds: 2)),
                    );
                  },
                  tooltip: 'Copy',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: SelectableText(
              _roundsSummary,
              style: AppTheme.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            color: const Color(0xFFF8F9FB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Review before saving. AI output requires clinical verification.',
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
                    if (_patients.length > 1)
                      OutlinedButton.icon(
                        onPressed: _advanceToNextPatient,
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Next patient'),
                      ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveRoundsToClinicalNotes,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSaving ? 'Saving…' : 'Save to notes'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    return DateFormat('MMM d, y').format(date);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.local_hospital_outlined, size: 48, color: AppTheme.primaryColor),
          const SizedBox(height: AppTheme.lg),
          Text('No patients in your log', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Add patients to conduct ward rounds and save SOAP summaries to their chart.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.lg),
          FilledButton.icon(
            onPressed: () async {
              final created = await Navigator.push<ProviderPatientRecord>(
                context,
                MaterialPageRoute(builder: (_) => const DoctorPatientCreateEditScreen()),
              );
              await _refreshPatients();
              if (created != null) _applyPatient(created);
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add first patient'),
          ),
        ],
      ),
    );
  }
}
