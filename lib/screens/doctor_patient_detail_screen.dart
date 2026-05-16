import 'package:flutter/material.dart';

import '../core/navigation/app_router.dart';
import '../core/errors/app_error_handler.dart';
import '../core/healthcare/healthcare_services_manager.dart';
import '../models/health_models.dart';
import '../theme/app_theme.dart';
import '../widgets/patient/patient_profile_card.dart';
import 'doctor_patient_create_edit_screen.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final ProviderPatientRecord patient;

  const DoctorPatientDetailScreen({super.key, required this.patient});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final HealthcareServicesManager _services = HealthcareServicesManager();
  late ProviderPatientRecord _patient;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  Future<void> _confirmAndDeletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to delete ${_patient.fullName}? '
          'This action cannot be undone and will also remove all associated records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientCreateEditScreen(patient: _patient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _patient.fullName.isEmpty ? 'Unknown Patient' : _patient.fullName;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Edit Patient',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
          ),
          IconButton(
            tooltip: 'Delete Patient',
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
              onPatientUpdated: (updated) => setState(() => _patient = updated),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.sm, AppTheme.lg, 0),
              child: Text('Quick Actions', style: AppTheme.labelLarge),
            ),
            const SizedBox(height: AppTheme.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.mic_none_rounded,
                      label: 'Consultation',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.voiceAssistant,
                        arguments: {'patientId': _patient.id},
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.note_alt_outlined,
                      label: 'Notes',
                      color: AppTheme.secondaryColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.clinicalNotes,
                        arguments: _patient.id,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan Doc',
                      color: AppTheme.warningColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.documentScanner,
                        arguments: _patient.id,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),

            _section('Last Visit Summary', [_patient.lastVisitSummary]),
            _section('Prescriptions', _patient.prescriptions),
            _section('Reports', _patient.reports),
            _section('Food Allergies', _patient.foodAllergies),
            _section('Medicinal Allergies', _patient.medicinalAllergies),
            _section('Medical History', _patient.medicalHistory),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.mediumRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: AppTheme.mediumRadius,
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<String> values) {
    final nonEmpty = values.where((v) => v.trim().isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          GlossyCard(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: nonEmpty.isEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppTheme.textTertiary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      Text(
                        'None recorded',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: nonEmpty
                        .map(
                          (value) => Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Text(
                                    value,
                                    style: AppTheme.bodyMedium.copyWith(height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: AppTheme.md),
        ],
      ),
    );
  }
}
