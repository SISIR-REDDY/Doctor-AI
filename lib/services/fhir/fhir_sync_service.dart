import 'package:flutter/foundation.dart';

import '../../models/health_models.dart';
import '../firebase/firestore_service.dart';
import 'fhir_client.dart';
import 'fhir_config_service.dart';

class FhirSyncResult {
  final int patientsSynced;
  final int patientsFailed;
  final String source;

  const FhirSyncResult({
    required this.patientsSynced,
    required this.patientsFailed,
    required this.source,
  });
}

class FhirSyncService {
  final FhirConfigService _configService = FhirConfigService();
  final FirestoreService _firestore = FirestoreService();

  Future<FhirSyncResult?> syncPatientsForDoctor(
    String doctorId, {
    int maxPatients = 25,
    bool includeDetails = true,
  }) async {
    final config = await _configService.load();
    if (config == null || !config.isConfigured) return null;

    final client = FhirClient(config);
    final patients = await client.search(
      'Patient',
      query: {
        '_count': '$maxPatients',
      },
    );

    int synced = 0;
    int failed = 0;

    for (final patient in patients) {
      try {
        var record = _mapPatient(patient, doctorId);
        if (record.id.trim().isEmpty) {
          failed++;
          continue;
        }
        if (includeDetails) {
          final ehrId = record.ehrId;
          final meds = await _fetchMedications(client, ehrId);
          final allergies = await _fetchAllergies(client, ehrId);
          final conditions = await _fetchConditions(client, ehrId);
          record = record.copyWith(
            prescriptions: meds,
            medicinalAllergies: allergies,
            medicalHistory: conditions,
            updatedAt: DateTime.now(),
          );
        }
        await _firestore.savePatientRecord(record);
        synced++;
      } catch (e) {
        failed++;
        if (kDebugMode) {
          debugPrint('[FhirSyncService] Patient sync failed: $e');
        }
      }
    }

    return FhirSyncResult(
      patientsSynced: synced,
      patientsFailed: failed,
      source: config.source,
    );
  }

  ProviderPatientRecord _mapPatient(Map<String, dynamic> resource, String doctorId) {
    final id = (resource['id'] ?? '').toString();
    final name = _readName(resource['name']);
    final telecom = _readTelecom(resource['telecom']);
    final birthDate = (resource['birthDate'] ?? '').toString();
    final gender = _normalizeGender((resource['gender'] ?? '').toString());
    final photoUrl = _readPhotoUrl(resource['photo']);

    return ProviderPatientRecord(
      id: id.isNotEmpty ? 'ehr_$id' : '',
      doctorId: doctorId,
      firstName: name.first,
      lastName: name.last,
      dateOfBirth: birthDate,
      gender: gender,
      contactNumber: telecom.phone,
      email: telecom.email,
      ehrId: id,
      ehrSource: 'epic_fhir',
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  _NameParts _readName(Object? nameField) {
    if (nameField is! List || nameField.isEmpty) {
      return const _NameParts(first: '', last: '');
    }
    final entry = nameField.first;
    if (entry is! Map<String, dynamic>) {
      return const _NameParts(first: '', last: '');
    }
    final family = (entry['family'] ?? '').toString();
    final given = entry['given'];
    String first = '';
    if (given is List && given.isNotEmpty) {
      first = given.first.toString();
    }
    return _NameParts(first: first, last: family);
  }

  _TelecomParts _readTelecom(Object? telecomField) {
    String phone = '';
    String email = '';
    if (telecomField is List) {
      for (final entry in telecomField) {
        if (entry is! Map<String, dynamic>) continue;
        final system = (entry['system'] ?? '').toString();
        final value = (entry['value'] ?? '').toString();
        if (system == 'phone' && phone.isEmpty) phone = value;
        if (system == 'email' && email.isEmpty) email = value;
      }
    }
    return _TelecomParts(phone: phone, email: email);
  }

  String _readPhotoUrl(Object? photoField) {
    if (photoField is! List || photoField.isEmpty) return '';
    final entry = photoField.first;
    if (entry is! Map<String, dynamic>) return '';
    final url = (entry['url'] ?? '').toString();
    return url.trim();
  }

  String _normalizeGender(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'male') return 'Male';
    if (value == 'female') return 'Female';
    if (value == 'other') return 'Other';
    return value.isEmpty ? 'Unknown' : value;
  }

  Future<List<String>> _fetchMedications(FhirClient client, String ehrId) async {
    if (ehrId.isEmpty) return const [];
    final requests = await client.search('MedicationRequest', query: {'patient': ehrId, '_count': '25'});
    final statements = await client.search('MedicationStatement', query: {'patient': ehrId, '_count': '25'});
    final meds = <String>{};

    for (final res in [...requests, ...statements]) {
      final code = _readCodeableText(res['medicationCodeableConcept']);
      if (code.isNotEmpty) meds.add(code);
    }

    return meds.toList();
  }

  Future<List<String>> _fetchAllergies(FhirClient client, String ehrId) async {
    if (ehrId.isEmpty) return const [];
    final allergies = await client.search('AllergyIntolerance', query: {'patient': ehrId, '_count': '25'});
    final results = <String>{};
    for (final res in allergies) {
      final code = _readCodeableText(res['code']);
      if (code.isNotEmpty) results.add(code);
    }
    return results.toList();
  }

  Future<List<String>> _fetchConditions(FhirClient client, String ehrId) async {
    if (ehrId.isEmpty) return const [];
    final conditions = await client.search('Condition', query: {'patient': ehrId, '_count': '25'});
    final results = <String>{};
    for (final res in conditions) {
      final code = _readCodeableText(res['code']);
      if (code.isNotEmpty) results.add(code);
    }
    return results.toList();
  }

  String _readCodeableText(Object? field) {
    if (field is Map<String, dynamic>) {
      final text = (field['text'] ?? '').toString();
      if (text.trim().isNotEmpty) return text.trim();
      final coding = field['coding'];
      if (coding is List && coding.isNotEmpty) {
        final first = coding.first;
        if (first is Map<String, dynamic>) {
          final display = (first['display'] ?? '').toString();
          if (display.trim().isNotEmpty) return display.trim();
          final code = (first['code'] ?? '').toString();
          if (code.trim().isNotEmpty) return code.trim();
        }
      }
    }
    return '';
  }
}

class _NameParts {
  final String first;
  final String last;

  const _NameParts({required this.first, required this.last});
}

class _TelecomParts {
  final String phone;
  final String email;

  const _TelecomParts({required this.phone, required this.email});
}
