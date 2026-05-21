import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../models/health_models.dart';
import 'firebase_bootstrap_service.dart';

class FirestoreService {
  static final Map<String, List<ProviderPatientRecord>> _patientsCacheByDoctor = {};
  static final Map<String, List<ClinicalNote>> _clinicalCacheByPatient = {};
  static final Map<String, List<ConsultationSession>> _consultationCacheByKey = {};
  static final Map<String, List<DocumentScan>> _documentScansCacheByPatient = {};
  // In-memory doctor profile cache by doctorId; mirrored to SharedPreferences
  // so loads after app restart are instant (no network spinner).
  static final Map<String, DoctorProfile> _doctorProfileCache = {};

  static const String _kDoctorProfilePrefsPrefix = 'cached_doctor_profile_';

  /// Clears all static caches. Call this on user logout to prevent data leakage.
  static Future<void> clearAllCaches() async {
    _patientsCacheByDoctor.clear();
    _clinicalCacheByPatient.clear();
    _consultationCacheByKey.clear();
    _documentScansCacheByPatient.clear();
    _doctorProfileCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((k) => k.startsWith(_kDoctorProfilePrefsPrefix))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // Best-effort: never block logout on cache cleanup failure.
    }
  }

  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  bool get isFirebaseAvailable => _isFirebaseAvailable;

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore _requireFirestore() {
    final firestore = _firestore;
    if (firestore == null) {
      throw AppException(
        code: 'firestore-not-configured',
        message: 'Firestore is not configured yet.',
      );
    }
    return firestore;
  }

  CollectionReference<Map<String, dynamic>> get _clinicalReportsCollection =>
      _requireFirestore().collection('clinical_reports');

  CollectionReference<Map<String, dynamic>> get _patientsCollection =>
      _requireFirestore().collection('patients');

  CollectionReference<Map<String, dynamic>> get _doctorsCollection =>
      _requireFirestore().collection('doctors');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _requireFirestore().collection('users');

  CollectionReference<Map<String, dynamic>> get _consultationSessionsCollection =>
      _requireFirestore().collection('consultation_sessions');

  CollectionReference<Map<String, dynamic>> get _documentScansCollection =>
      _requireFirestore().collection('document_scans');

  CollectionReference<Map<String, dynamic>> get _emergencyTriageCollection =>
      _requireFirestore().collection('emergency_triage');

  String _consultationCacheKey(String doctorId, String? patientId) {
    final patientSegment = (patientId ?? '').trim();
    return '$doctorId::$patientSegment';
  }

  Future<void> saveClinicalReport(ClinicalNote note) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _clinicalReportsCollection.doc(note.id).set(note.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-clinical-report-failed',
        message: 'Unable to save clinical report to cloud.',
        cause: error,
      );
    }
  }

  Future<void> updateClinicalReport(ClinicalNote note) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _clinicalReportsCollection.doc(note.id).update(note.toMap());
    } catch (error) {
      throw AppException(
        code: 'update-clinical-report-failed',
        message: 'Unable to update clinical report in cloud.',
        cause: error,
      );
    }
  }

  Stream<List<ClinicalNote>> watchClinicalReports(String patientId) {
    if (!_isFirebaseAvailable) {
      final cached = _clinicalCacheByPatient[patientId] ?? const [];
      return Stream.value(List<ClinicalNote>.from(cached));
    }

    return _clinicalReportsCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) {
            final notes = snapshot.docs
              .map((doc) => ClinicalNote.fromMap(doc.data()))
              .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _clinicalCacheByPatient[patientId] =
                List<ClinicalNote>.from(notes);
            return List<ClinicalNote>.from(notes);
          },
        );
  }

  Stream<List<ClinicalNote>> watchClinicalReportsForDoctor(String doctorId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(const []);
    }

    return _clinicalReportsCollection
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map(
          (snapshot) {
            final notes = snapshot.docs
                .map((doc) => ClinicalNote.fromMap(doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return List<ClinicalNote>.from(notes);
          },
        );
  }

  Future<List<ClinicalNote>> getClinicalReports(String patientId) async {
    if (!_isFirebaseAvailable) {
      final cached = _clinicalCacheByPatient[patientId] ?? const [];
      return List<ClinicalNote>.from(cached);
    }

    try {
      final snapshot = await _clinicalReportsCollection
          .where('patientId', isEqualTo: patientId)
          .get(const GetOptions(source: Source.serverAndCache));
      final notes = snapshot.docs
          .map((doc) => ClinicalNote.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _clinicalCacheByPatient[patientId] = List<ClinicalNote>.from(notes);
      return List<ClinicalNote>.from(notes);
    } catch (_) {
      final cached = _clinicalCacheByPatient[patientId] ?? const [];
      return List<ClinicalNote>.from(cached);
    }
  }

  Future<List<ClinicalNote>> getClinicalReportsForDoctor(String doctorId) async {
    if (!_isFirebaseAvailable) return const [];

    try {
      final snapshot = await _clinicalReportsCollection
          .where('doctorId', isEqualTo: doctorId)
          .get(const GetOptions(source: Source.serverAndCache));
      final notes = snapshot.docs
          .map((doc) => ClinicalNote.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List<ClinicalNote>.from(notes);
    } catch (_) {
      return const [];
    }
  }

  Future<List<DocumentScan>> getDocumentScans(String patientId) async {
    if (!_isFirebaseAvailable) {
      return _documentScansCacheByPatient[patientId] ?? const [];
    }

    try {
      final snapshot = await _documentScansCollection
          .where('patientId', isEqualTo: patientId)
          .get(const GetOptions(source: Source.serverAndCache));
      final scans = snapshot.docs
          .map((doc) => DocumentScan.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.dateScanned.compareTo(a.dateScanned));
      _documentScansCacheByPatient[patientId] = scans;
      return scans;
    } catch (_) {
      return _documentScansCacheByPatient[patientId] ?? const [];
    }
  }

  Future<List<ConsultationSession>> getConsultationSessionsForPatient({
    required String doctorId,
    required String patientId,
  }) async {
    if (!_isFirebaseAvailable) {
      return const [];
    }

    try {
      final snapshot = await _consultationSessionsCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .get(const GetOptions(source: Source.serverAndCache));
      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDeviceToken({
    required String userId,
    required String token,
  }) async {
    if (!_isFirebaseAvailable) return;

    await _usersCollection.doc(userId).set(
      {
        'fcmToken': token,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Removes a patient from in-memory caches without mutating lists the UI may be iterating.
  static void evictPatientFromCache(String patientId) {
    for (final key in _patientsCacheByDoctor.keys.toList()) {
      final current = _patientsCacheByDoctor[key];
      if (current == null) continue;
      _patientsCacheByDoctor[key] =
          current.where((p) => p.id != patientId).toList(growable: false);
    }
  }

  static void _evictClinicalNoteFromCache(String reportId) {
    for (final key in _clinicalCacheByPatient.keys.toList()) {
      final current = _clinicalCacheByPatient[key];
      if (current == null) continue;
      _clinicalCacheByPatient[key] =
          current.where((r) => r.id != reportId).toList(growable: false);
    }
  }

  static void _evictConsultationFromCache(String sessionId) {
    for (final key in _consultationCacheByKey.keys.toList()) {
      final current = _consultationCacheByKey[key];
      if (current == null) continue;
      _consultationCacheByKey[key] =
          current.where((s) => s.id != sessionId).toList(growable: false);
    }
  }

  static void _evictDocumentScanFromCache(String scanId) {
    for (final key in _documentScansCacheByPatient.keys.toList()) {
      final current = _documentScansCacheByPatient[key];
      if (current == null) continue;
      _documentScansCacheByPatient[key] =
          current.where((s) => s.id != scanId).toList(growable: false);
    }
  }

  Stream<List<ProviderPatientRecord>> watchDoctorPatients(String doctorId) {
    if (!_isFirebaseAvailable) {
      final cached = _patientsCacheByDoctor[doctorId] ?? const [];
      return Stream.value(List<ProviderPatientRecord>.from(cached));
    }

    return _patientsCollection
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map(
          (snapshot) {
            final patients = snapshot.docs
                .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            _patientsCacheByDoctor[doctorId] =
                List<ProviderPatientRecord>.from(patients);
            return List<ProviderPatientRecord>.from(patients);
          },
        );
  }

  Future<List<ProviderPatientRecord>> getDoctorPatients(String doctorId) async {
    if (!_isFirebaseAvailable) {
      final cached = _patientsCacheByDoctor[doctorId] ?? const [];
      return List<ProviderPatientRecord>.from(cached);
    }

    try {
      final snapshot = await _patientsCollection
          .where('doctorId', isEqualTo: doctorId)
          .get();
      final patients = snapshot.docs
          .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _patientsCacheByDoctor[doctorId] = List<ProviderPatientRecord>.from(patients);
      return List<ProviderPatientRecord>.from(patients);
    } catch (_) {
      final cached = _patientsCacheByDoctor[doctorId] ?? const [];
      return List<ProviderPatientRecord>.from(cached);
    }
  }

  Future<void> savePatientRecord(ProviderPatientRecord record) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _patientsCollection.doc(record.id).set(record.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-patient-record-failed',
        message: 'Unable to save patient record to cloud.',
        cause: error,
      );
    }
  }

  /// Delete a patient record from Firestore
  Future<void> deletePatientRecord(String patientId) async {
    evictPatientFromCache(patientId);

    if (!_isFirebaseAvailable) return;

    try {
      await _patientsCollection.doc(patientId).delete();
    } catch (error) {
      throw AppException(
        code: 'delete-patient-record-failed',
        message: 'Unable to delete patient record from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a clinical report from Firestore
  Future<void> deleteClinicalReport(String reportId) async {
    if (!_isFirebaseAvailable) return;

    try {
      _evictClinicalNoteFromCache(reportId);
      await _clinicalReportsCollection.doc(reportId).delete();
    } catch (error) {
      throw AppException(
        code: 'delete-clinical-report-failed',
        message: 'Unable to delete clinical report from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a consultation session from Firestore
  Future<void> deleteConsultationSession(String sessionId) async {
    if (!_isFirebaseAvailable) return;

    try {
      _evictConsultationFromCache(sessionId);
      await _consultationSessionsCollection.doc(sessionId).delete();
    } catch (error) {
      throw AppException(
        code: 'delete-consultation-session-failed',
        message: 'Unable to delete consultation session from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a document scan from Firestore
  Future<void> deleteDocumentScan(String scanId) async {
    if (!_isFirebaseAvailable) return;

    try {
      _evictDocumentScanFromCache(scanId);
      await _documentScansCollection.doc(scanId).delete();
    } catch (error) {
      throw AppException(
        code: 'delete-document-scan-failed',
        message: 'Unable to delete document scan from cloud.',
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>?> loadRuntimeApiConfig() async {
    if (!_isFirebaseAvailable) return null;
    final snapshot = await _requireFirestore()
        .collection(FirebaseConfig.apiKeysCollection)
        .doc(FirebaseConfig.apiKeysDocument)
        .get();
    return snapshot.data();
  }

  /// Save doctor profile to Firestore 'doctors' collection AND to local cache
  /// (in-memory + SharedPreferences). Write-through so next load is instant.
  Future<void> saveDoctorProfile(DoctorProfile profile) async {
    // Write to local cache first so UI feels instant even if network is slow.
    _writeProfileToCache(profile);

    if (!_isFirebaseAvailable) return;

    try {
      await _doctorsCollection.doc(profile.id).set(
        {
          ...profile.toMap(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      throw AppException(
        code: 'save-doctor-profile-failed',
        message: 'Unable to save doctor profile to cloud.',
        cause: error,
      );
    }
  }

  /// Cache-first load. Strategy:
  ///   1. Check in-memory cache → return immediately
  ///   2. Check SharedPreferences → return if found, refresh from Firestore in
  ///      background
  ///   3. Hit Firestore → cache the result
  /// This makes the profile screen feel instant on subsequent opens / restarts.
  Future<DoctorProfile?> loadDoctorProfile(String doctorId) async {
    // 1. In-memory hit
    final memHit = _doctorProfileCache[doctorId];
    if (memHit != null) {
      // Refresh from Firestore in background so cache stays fresh.
      // Errors are silently ignored — we already have a usable profile.
      // ignore: discarded_futures
      _refreshProfileFromFirestore(doctorId);
      return memHit;
    }

    // 2. Disk hit (SharedPreferences)
    final diskHit = await _readProfileFromDisk(doctorId);
    if (diskHit != null) {
      _doctorProfileCache[doctorId] = diskHit;
      // ignore: discarded_futures
      _refreshProfileFromFirestore(doctorId);
      return diskHit;
    }

    // 3. Network — first ever load on this device
    if (!_isFirebaseAvailable) return null;
    try {
      final snapshot = await _doctorsCollection.doc(doctorId).get();
      if (!snapshot.exists) return null;
      final profile = DoctorProfile.fromMap(snapshot.data() ?? {});
      _writeProfileToCache(profile);
      return profile;
    } catch (error) {
      throw AppException(
        code: 'load-doctor-profile-failed',
        message: 'Unable to load doctor profile from cloud.',
        cause: error,
      );
    }
  }

  /// Background refresh: pulls latest from Firestore and updates cache.
  /// Silently swallows errors — this is a cache-warming pass.
  Future<void> _refreshProfileFromFirestore(String doctorId) async {
    if (!_isFirebaseAvailable) return;
    try {
      final snapshot = await _doctorsCollection.doc(doctorId).get();
      if (!snapshot.exists) return;
      final fresh = DoctorProfile.fromMap(snapshot.data() ?? {});
      _writeProfileToCache(fresh);
    } catch (_) {
      // Offline / transient errors are fine — keep using cached value.
    }
  }

  void _writeProfileToCache(DoctorProfile profile) {
    _doctorProfileCache[profile.id] = profile;
    // Fire-and-forget disk write so UI stays responsive.
    // ignore: discarded_futures
    _persistProfileToDisk(profile);
  }

  Future<void> _persistProfileToDisk(DoctorProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(profile.toMap());
      await prefs.setString('$_kDoctorProfilePrefsPrefix${profile.id}', json);
    } catch (_) {
      // SharedPreferences failures are non-fatal — in-memory cache still works.
    }
  }

  Future<DoctorProfile?> _readProfileFromDisk(String doctorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kDoctorProfilePrefsPrefix$doctorId');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return DoctorProfile.fromMap(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Watch doctor profile changes in real-time
  /// Returns a stream of doctor profile updates
  Stream<DoctorProfile?> watchDoctorProfile(String doctorId) {
    if (!_isFirebaseAvailable) {
      return const Stream<DoctorProfile?>.empty();
    }

    return _doctorsCollection.doc(doctorId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return null;
        return DoctorProfile.fromMap(snapshot.data() ?? {});
      },
    );
  }

  Future<void> saveConsultationSession(ConsultationSession session) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _consultationSessionsCollection.doc(session.id).set(session.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-consultation-session-failed',
        message: 'Unable to save consultation session to cloud.',
        cause: error,
      );
    }
  }

  Stream<List<ConsultationSession>> watchConsultationHistory({
    required String doctorId,
    String? patientId,
    int limit = 20,
  }) {
    final cacheKey = _consultationCacheKey(doctorId, patientId);
    if (!_isFirebaseAvailable) {
      return Stream.value(_consultationCacheByKey[cacheKey] ?? const []);
    }

    Query<Map<String, dynamic>> query =
      _consultationSessionsCollection.where('doctorId', isEqualTo: doctorId);

    if (patientId != null && patientId.isNotEmpty) {
      query = query.where('patientId', isEqualTo: patientId);
    }

    return query.snapshots().map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final mapped = sessions.take(limit).toList();
      _consultationCacheByKey[cacheKey] = mapped;
      return mapped;
    });
  }

  Future<List<ConsultationSession>> getConsultationHistory({
    required String doctorId,
    String? patientId,
    int limit = 20,
  }) async {
    final cacheKey = _consultationCacheKey(doctorId, patientId);
    if (!_isFirebaseAvailable) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }

    Query<Map<String, dynamic>> query =
      _consultationSessionsCollection.where('doctorId', isEqualTo: doctorId);

    if (patientId != null) {
      query = query.where('patientId', isEqualTo: patientId);
    }

    try {
      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final mapped = sessions.take(limit).toList();
      _consultationCacheByKey[cacheKey] = mapped;
      return mapped;
    } catch (_) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }
  }

  Future<void> saveDocumentScan(DocumentScan scan) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _documentScansCollection.doc(scan.id).set(scan.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-document-scan-failed',
        message: 'Unable to save document scan to cloud.',
        cause: error,
      );
    }
  }

  Stream<List<DocumentScan>> watchDocumentScans(String patientId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_documentScansCacheByPatient[patientId] ?? const []);
    }

    return _documentScansCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) {
            final scans = snapshot.docs
              .map((doc) => DocumentScan.fromMap(doc.data()))
              .toList()
              ..sort((a, b) => b.dateScanned.compareTo(a.dateScanned));
            _documentScansCacheByPatient[patientId] = scans;
      return scans;
    });
  }

  Future<void> saveEmergencyTriage(EmergencyTriageRecord record) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _emergencyTriageCollection.doc(record.id).set(record.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-emergency-triage-failed',
        message: 'Unable to save emergency triage to cloud.',
        cause: error,
      );
    }
  }

  Future<EmergencyTriageRecord?> getEmergencyTriageById(String triageId) async {
    if (!_isFirebaseAvailable || triageId.trim().isEmpty) return null;
    try {
      final doc = await _emergencyTriageCollection.doc(triageId.trim()).get();
      if (!doc.exists || doc.data() == null) return null;
      return EmergencyTriageRecord.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<EmergencyTriageRecord?> findEmergencyTriageByShareCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || !_isFirebaseAvailable) return null;

    try {
      final snapshot = await _emergencyTriageCollection
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      for (final doc in snapshot.docs) {
        final record = EmergencyTriageRecord.fromMap(doc.data());
        if (record.shareCode == normalized || record.id.toUpperCase().endsWith(normalized)) {
          return record;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Stream<List<EmergencyTriageRecord>> watchEmergencyTriageForDoctor(String doctorId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(const []);
    }
    return _emergencyTriageCollection
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map(
          (snapshot) {
            final records = snapshot.docs
                .map((doc) => EmergencyTriageRecord.fromMap(doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return List<EmergencyTriageRecord>.from(records);
          },
        );
  }
}
