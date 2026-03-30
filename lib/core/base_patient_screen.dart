import 'package:flutter/material.dart';

import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';

mixin BasePatientScreen<T extends StatefulWidget> on State<T> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  ProviderPatientRecord? patient;

  bool get hasPatient => patient != null;

  String getPatientDisplayName() {
    return patient?.fullName.trim().isNotEmpty == true
        ? patient!.fullName
        : 'Unknown Patient';
  }

  String getPatientInfo() {
    if (patient == null) return 'No patient selected';
    return '${patient!.age} yrs • ${patient!.gender}';
  }

  @protected
  void onPatientLoaded(ProviderPatientRecord loadedPatient) {}

  @protected
  Future<void> loadPatientData(String? patientId) async {
    final id = patientId?.trim() ?? '';
    if (id.isEmpty) return;

    try {
      final doctorId = _authService.currentUser?.uid ?? '';
      if (doctorId.isEmpty) return;

      final patients = await _firestoreService.getDoctorPatients(doctorId);
      final loadedPatient = patients.where((p) => p.id == id).firstOrNull;
      if (loadedPatient == null || !mounted) return;

      setState(() {
        patient = loadedPatient;
      });
      onPatientLoaded(loadedPatient);
    } catch (_) {
      // Keep screen usable even if patient context fails to load.
    }
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
