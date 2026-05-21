import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_error_handler.dart';
import '../core/healthcare/healthcare_services_manager.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../services/firebase/storage_service.dart';
import '../theme/app_animations.dart';
import '../widgets/patient/patient_avatar.dart';
import '../services/fhir/fhir_sync_service.dart';
import 'doctor_patient_create_edit_screen.dart';
import 'doctor_patient_detail_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final HealthcareServicesManager _services = HealthcareServicesManager();
  final FhirSyncService _fhirSyncService = FhirSyncService();
  final Set<String> _deletingPatientIds = {};
  final Set<String> _optimisticallyRemovedIds = {};
  bool _isSyncingEhr = false;

  String? get _doctorId => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    StorageService().warmPatientPhotosCache();
    _syncFromEhr(showSnackbar: false);
  }

  Future<void> _syncFromEhr({required bool showSnackbar}) async {
    final doctorId = _doctorId;
    if (doctorId == null || _isSyncingEhr) return;

    setState(() => _isSyncingEhr = true);
    try {
      final result = await _fhirSyncService.syncPatientsForDoctor(doctorId);
      if (!mounted) return;
      if (showSnackbar) {
        final message = result == null
            ? 'EHR sync not configured'
            : 'Synced ${result.patientsSynced} patients from EHR';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EHR sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingEhr = false);
    }
  }

  Future<void> _addQuickSamplePatient() async {
    final doctorId = _doctorId;
    if (doctorId == null) return;

    final now = DateTime.now();
    final newRecord = ProviderPatientRecord(
      id: const Uuid().v4(),
      doctorId: doctorId,
      firstName: 'New',
      lastName: 'Patient',
      dateOfBirth: '1985-04-12',
      gender: 'Female',
      bloodType: 'A+',
      contactNumber: '+1 000 000 0000',
      email: 'patient@hospital.org',
      lastVisitSummary:
          'Follow-up visit for chronic care review; vitals stable; continue current plan with 2-week review.',
      prescriptions: const ['Metformin 500 mg BID', 'Atorvastatin 10 mg nightly'],
      reports: const ['CBC: normal', 'Lipid profile: borderline high LDL'],
      foodAllergies: const ['Peanuts'],
      medicinalAllergies: const ['Penicillin'],
      medicalHistory: const ['Type 2 diabetes', 'Dyslipidemia'],
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _firestoreService.savePatientRecord(newRecord);
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    }
  }

  Future<void> _confirmDeletePatient(ProviderPatientRecord patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text(
          'Delete ${patient.fullName} and all related records? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_deletingPatientIds.contains(patient.id)) return;

    setState(() {
      _deletingPatientIds.add(patient.id);
      _optimisticallyRemovedIds.add(patient.id);
    });

    try {
      await _services.deletePatientAndRecords(patient);
      if (!mounted) return;
      setState(() => _optimisticallyRemovedIds.remove(patient.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient deleted'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _optimisticallyRemovedIds.remove(patient.id));
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _deletingPatientIds.remove(patient.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = _doctorId;

    if (doctorId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('My Patients'),
        ),
        body: const Center(
          child: Text('Sign in is required to access your patient list.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Patients'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sync from EHR',
            onPressed: _isSyncingEhr ? null : () => _syncFromEhr(showSnackbar: true),
            icon: _isSyncingEhr
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: ScaleAnimation(
        delay: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DoctorPatientCreateEditScreen(),
              ),
            );
          },
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
      ),
      body: StreamBuilder<List<ProviderPatientRecord>>(
        stream: _firestoreService.watchDoctorPatients(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Text(
                  'Unable to load patients. Please check Firebase connectivity.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium,
                ),
              ),
            );
          }

          final patients = (snapshot.data ?? const [])
              .where((p) => !_optimisticallyRemovedIds.contains(p.id))
              .toList(growable: false);
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_off, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: AppTheme.md),
                    Text('No patients found for this doctor.', style: AppTheme.bodyMedium),
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      'Add records in Firestore collection "patients" with your doctorId.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.lg),
                    IosButton(
                      label: 'Add Sample Patient',
                      onPressed: _addQuickSamplePatient,
                      icon: Icons.person_add,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.lg),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
            itemBuilder: (context, index) {
              final patient = patients[index];
              return AnimatedListItem(
                index: index,
                baseDelay: const Duration(milliseconds: 50),
                child: GlossyCard(
                  padding: const EdgeInsets.all(AppTheme.md),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorPatientDetailScreen(patient: patient),
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PatientAvatar.fromPatient(
                        patient,
                        size: 88,
                        borderRadius: 20,
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(patient.fullName, style: AppTheme.labelLarge),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatTime(patient.updatedAt)} • ${patient.lastVisitSummary}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Food allergies: ${patient.foodAllergies.length} • Medication allergies: ${patient.medicinalAllergies.length}',
                              style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Delete Patient',
                            icon: _deletingPatientIds.contains(patient.id)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_outline, color: AppTheme.dangerColor, size: 20),
                            onPressed: _deletingPatientIds.contains(patient.id)
                                ? null
                                : () => _confirmDeletePatient(patient),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final meridiem = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }
}
