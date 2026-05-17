import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../screens/doctor_patient_create_edit_screen.dart';
import '../../screens/doctor_patient_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../patient/patient_avatar.dart';

/// Inline patient block for the unified triage card (no outer card chrome).
class EmergencyTriagePatientSection extends StatelessWidget {
  final List<ProviderPatientRecord> patients;
  final ProviderPatientRecord? selectedPatient;
  final bool isLoading;
  final ValueChanged<ProviderPatientRecord?> onPatientSelected;
  final VoidCallback onRefresh;
  final TextEditingController triageNotesController;
  final String arrivalMode;
  final ValueChanged<String> onArrivalModeChanged;

  const EmergencyTriagePatientSection({
    super.key,
    required this.patients,
    required this.selectedPatient,
    required this.isLoading,
    required this.onPatientSelected,
    required this.onRefresh,
    required this.triageNotesController,
    required this.arrivalMode,
    required this.onArrivalModeChanged,
  });

  static const arrivalModes = ['walk-in', 'ambulance', 'wheelchair', 'transfer'];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPatientPicker(context),
        if (selectedPatient != null) ...[
          const SizedBox(height: AppTheme.md),
          _buildPatientSummary(selectedPatient!),
        ],
        const SizedBox(height: AppTheme.md),
        _buildArrivalMode(),
        const SizedBox(height: AppTheme.md),
        TextField(
          controller: triageNotesController,
          maxLines: 2,
          style: AppTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: 'Handoff notes',
            hintText: 'Isolation, escort, interpreter…',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientPicker(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: patients.isEmpty ? null : () => _showPatientPicker(context),
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
          onPressed: () => _openCreatePatient(context),
          icon: const Icon(Icons.person_add_alt_1),
          tooltip: 'Add patient',
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.textPrimary,
            foregroundColor: Colors.white,
          ),
        ),
        if (selectedPatient != null)
          IconButton(
            onPressed: () => _openPatientDetail(context, selectedPatient!),
            icon: const Icon(Icons.open_in_new_outlined),
            tooltip: 'Patient chart',
          ),
      ],
    );
  }

  Widget _buildPatientSummary(ProviderPatientRecord patient) {
    final hasAllergies = patient.allergies.isNotEmpty;
    return Row(
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
              if (hasAllergies)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '⚠ ${patient.allergies.join(", ")}',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalMode() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: arrivalModes.map((mode) {
        final selected = arrivalMode == mode;
        final label = mode.replaceAll('-', ' ');
        return FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) => onArrivalModeChanged(mode),
          showCheckmark: false,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          selectedColor: AppTheme.dangerColor.withValues(alpha: 0.12),
          side: BorderSide(
            color: selected ? AppTheme.dangerColor.withValues(alpha: 0.5) : AppTheme.dividerColor,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showPatientPicker(BuildContext context) async {
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
    if (picked != null) onPatientSelected(picked);
  }

  Future<void> _openCreatePatient(BuildContext context) async {
    final created = await Navigator.push<ProviderPatientRecord>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorPatientCreateEditScreen()),
    );
    onRefresh();
    if (created != null) onPatientSelected(created);
  }

  void _openPatientDetail(BuildContext context, ProviderPatientRecord patient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorPatientDetailScreen(patient: patient)),
    ).then((_) => onRefresh());
  }
}

/// @deprecated Use [EmergencyTriagePatientSection] inside the unified triage card.
typedef EmergencyPatientPanel = EmergencyTriagePatientSection;
