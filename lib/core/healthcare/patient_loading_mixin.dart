import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import 'healthcare_services_manager.dart';

mixin PatientLoadingMixin<T extends StatefulWidget> on State<T> {
  final HealthcareServicesManager _services = HealthcareServicesManager();

  ProviderPatientRecord? patient;
  List<ProviderPatientRecord> patients = <ProviderPatientRecord>[];
  StreamSubscription<List<ProviderPatientRecord>>? _patientsSubscription;

  Future<void> loadPatientData(String? patientId) async {
    final id = patientId?.trim() ?? '';
    if (id.isEmpty) return;

    final doctorId = _services.currentDoctorId;
    if (doctorId.isEmpty) return;

    final loaded = await _services.firestore.getDoctorPatients(doctorId);
    patients = loaded;
    final selected = loaded.where((p) => p.id == id).firstOrNull;
    if (mounted) {
      setState(() {
        patient = selected;
      });
    }
  }

  void startWatchingPatients() {
    final doctorId = _services.currentDoctorId;
    if (doctorId.isEmpty) return;

    _patientsSubscription?.cancel();
    _patientsSubscription = _services.firestore.watchDoctorPatients(doctorId).listen(
      (records) {
        if (!mounted) return;
        setState(() {
          patients = records;
          if (patient != null) {
            patient = findPatientById(patient!.id);
          }
        });
      },
    );
  }

  ProviderPatientRecord? findPatientById(String? id) {
    final key = id?.trim() ?? '';
    if (key.isEmpty) return null;
    return patients.where((p) => p.id == key).firstOrNull;
  }

  void setPatient(ProviderPatientRecord? value) {
    if (!mounted) return;
    setState(() {
      patient = value;
    });
  }

  Future<ProviderPatientRecord?> showPatientSelector() {
    return showModalBottomSheet<ProviderPatientRecord>(
      context: context,
      builder: (ctx) => SafeArea(
        child: patients.isEmpty
            ? const SizedBox(
                height: 220,
                child: Center(child: Text('No patients available')),
              )
            : ListView.separated(
                itemCount: patients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final p = patients[index];
                  return ListTile(
                    title: Text(p.fullName),
                    subtitle: Text('${p.age} yrs • ${p.gender}'),
                    onTap: () => Navigator.of(ctx).pop(p),
                  );
                },
              ),
      ),
    );
  }

  Widget buildPatientContextWidget({
    required VoidCallback onTap,
    required VoidCallback onAdd,
  }) {
    if (patient == null) {
      return Card(
        child: ListTile(
          title: const Text('Select patient'),
          subtitle: const Text('Choose a patient for contextual AI output'),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(onPressed: onTap, icon: const Icon(Icons.person_search)),
              IconButton(onPressed: onAdd, icon: const Icon(Icons.person_add)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        title: Text(patient!.fullName),
        subtitle: Text('${patient!.age} yrs • ${patient!.gender}'),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(onPressed: onTap, icon: const Icon(Icons.swap_horiz)),
            IconButton(onPressed: onAdd, icon: const Icon(Icons.person_add)),
          ],
        ),
      ),
    );
  }

  @mustCallSuper
  void disposePatientLoadingMixin() {
    _patientsSubscription?.cancel();
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
