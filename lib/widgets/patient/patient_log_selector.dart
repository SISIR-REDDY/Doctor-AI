import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../screens/doctor_patient_create_edit_screen.dart';
import '../../screens/doctor_patient_detail_screen.dart';
import '../../theme/app_theme.dart';
import 'patient_avatar.dart';

/// Compact patient picker synced with the doctor's Firestore patient log.
class PatientLogSelector extends StatelessWidget {
  final List<ProviderPatientRecord> patients;
  final ProviderPatientRecord? selectedPatient;
  final bool isLoading;
  final ValueChanged<ProviderPatientRecord?> onSelected;
  final VoidCallback onRefresh;
  final bool showSummary;

  const PatientLogSelector({
    super.key,
    required this.patients,
    required this.selectedPatient,
    required this.isLoading,
    required this.onSelected,
    required this.onRefresh,
    this.showSummary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Material(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: patients.isEmpty ? null : () => _pickPatient(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 20,
                          color: selectedPatient != null ? AppTheme.primaryColor : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppTheme.sm),
                        Expanded(
                          child: Text(
                            selectedPatient?.fullName ?? 'Select patient from log',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: selectedPatient != null ? FontWeight.w600 : FontWeight.w500,
                              color: selectedPatient != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 20, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            IconButton(
              onPressed: () => _addPatient(context),
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Add patient',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
              ),
            ),
            if (selectedPatient != null)
              IconButton(
                onPressed: () => _openChart(context, selectedPatient!),
                icon: const Icon(Icons.open_in_new_outlined),
                tooltip: 'Patient chart',
              ),
          ],
        ),
        if (showSummary && selectedPatient != null) ...[
          const SizedBox(height: AppTheme.md),
          _PatientSummary(patient: selectedPatient!),
        ],
      ],
    );
  }

  Future<void> _pickPatient(BuildContext context) async {
    final picked = await showModalBottomSheet<ProviderPatientRecord>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Text('Patient log', style: AppTheme.headingSmall),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: patients.length,
                itemBuilder: (_, i) {
                  final p = patients[i];
                  return ListTile(
                    leading: PatientAvatar.fromPatient(p, size: 44, borderRadius: 12),
                    title: Text(p.fullName),
                    subtitle: Text('${p.age} yrs · ${p.gender}'),
                    trailing: p.allergies.isNotEmpty
                        ? Icon(Icons.warning_amber, color: AppTheme.dangerColor, size: 18)
                        : null,
                    onTap: () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }

  Future<void> _addPatient(BuildContext context) async {
    final created = await Navigator.push<ProviderPatientRecord>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorPatientCreateEditScreen()),
    );
    onRefresh();
    if (created != null) onSelected(created);
  }

  void _openChart(BuildContext context, ProviderPatientRecord patient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorPatientDetailScreen(patient: patient)),
    ).then((_) => onRefresh());
  }
}

class _PatientSummary extends StatelessWidget {
  final ProviderPatientRecord patient;

  const _PatientSummary({required this.patient});

  @override
  Widget build(BuildContext context) {
    final hasAllergies = patient.allergies.isNotEmpty;
    final hasMeds = patient.prescriptions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PatientAvatar.fromPatient(patient, size: 48, borderRadius: 12),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.fullName, style: AppTheme.labelLarge),
                  Text(
                    '${patient.age} yrs · ${patient.gender}'
                    '${patient.bloodType.isNotEmpty ? " · ${patient.bloodType}" : ""}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasAllergies) ...[
          const SizedBox(height: AppTheme.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.sm),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              'Allergies: ${patient.allergies.join(", ")}',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.dangerColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (hasMeds) ...[
          const SizedBox(height: AppTheme.sm),
          Text(
            'On chart: ${patient.prescriptions.take(4).join(" · ")}${patient.prescriptions.length > 4 ? "…" : ""}',
            style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
