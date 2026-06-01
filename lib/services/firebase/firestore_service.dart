import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../models/patient_models.dart';
import 'firebase_bootstrap_service.dart';

class FirestoreService {
  // ── In-memory caches ────────────────────────────────────────────────────────
  static PatientProfile? _profileCache;
  static final Map<String, List<SymptomEntry>> _symptomsCache = {};
  static final Map<String, List<Medication>> _medicationsCache = {};
  static final Map<String, List<MedicalRecord>> _recordsCache = {};
  static final Map<String, List<InsurancePolicy>> _policiesCache = {};
  static final Map<String, List<InsuranceClaim>> _claimsCache = {};

  static const String _kProfilePrefsKey = 'cached_patient_profile';

  static Future<void> clearAllCaches() async {
    _profileCache = null;
    _symptomsCache.clear();
    _medicationsCache.clear();
    _recordsCache.clear();
    _policiesCache.clear();
    _claimsCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kProfilePrefsKey);
    } catch (_) {}
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
    final db = _firestore;
    if (db == null) {
      throw AppException(
        code: 'firestore-not-configured',
        message: 'Firestore is not configured yet.',
      );
    }
    return db;
  }

  void _ensureFirebaseForWrite() {
    if (!_isFirebaseAvailable) {
      throw AppException(
        code: 'firebase-not-configured',
        message:
            'Cloud sync is unavailable. Check your internet connection and try again.',
      );
    }
  }

  // ── Collection helpers ────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _requireFirestore().collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sub(String uid, String col) =>
      _userDoc(uid).collection(col);

  // ── Runtime API config ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadRuntimeApiConfig() async {
    if (!_isFirebaseAvailable) return null;
    final snapshot = await _requireFirestore()
        .collection(FirebaseConfig.apiKeysCollection)
        .doc(FirebaseConfig.apiKeysDocument)
        .get();
    return snapshot.data();
  }

  // ── Device token ───────────────────────────────────────────────────────────

  Future<void> saveDeviceToken({
    required String userId,
    required String token,
  }) async {
    if (!_isFirebaseAvailable) return;
    await _userDoc(userId).set(
      {'fcmToken': token, 'updatedAt': DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PATIENT PROFILE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> savePatientProfile(PatientProfile profile) async {
    _profileCache = profile;
    _persistProfileToDisk(profile);
    if (!_isFirebaseAvailable) return;
    try {
      await _userDoc(profile.id).set(
        {...profile.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw AppException(
        code: 'save-profile-failed',
        message: 'Unable to save profile.',
        cause: e,
      );
    }
  }

  Future<PatientProfile?> loadPatientProfile(String uid) async {
    if (_profileCache != null && _profileCache!.id == uid) {
      _refreshProfileFromFirestore(uid);
      return _profileCache;
    }
    final disk = await _readProfileFromDisk();
    if (disk != null && disk.id == uid) {
      _profileCache = disk;
      _refreshProfileFromFirestore(uid);
      return disk;
    }
    if (!_isFirebaseAvailable) return null;
    try {
      final snap = await _userDoc(uid).get();
      if (!snap.exists || snap.data() == null) return null;
      final profile = PatientProfile.fromMap(snap.data()!);
      _profileCache = profile;
      _persistProfileToDisk(profile);
      return profile;
    } catch (e) {
      throw AppException(
        code: 'load-profile-failed',
        message: 'Unable to load profile.',
        cause: e,
      );
    }
  }

  Future<void> _refreshProfileFromFirestore(String uid) async {
    if (!_isFirebaseAvailable) return;
    try {
      final snap = await _userDoc(uid).get();
      if (!snap.exists || snap.data() == null) return;
      final fresh = PatientProfile.fromMap(snap.data()!);
      _profileCache = fresh;
      _persistProfileToDisk(fresh);
    } catch (_) {}
  }

  void _persistProfileToDisk(PatientProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProfilePrefsKey, jsonEncode(profile.toMap()));
    } catch (_) {}
  }

  Future<PatientProfile?> _readProfileFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfilePrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return PatientProfile.fromMap(map);
    } catch (_) {}
    return null;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SYMPTOM JOURNAL
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<SymptomEntry>> watchSymptoms(String uid) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_symptomsCache[uid] ?? []);
    }
    return _sub(uid, 'symptoms')
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => SymptomEntry.fromMap(d.data()))
          .toList();
      _symptomsCache[uid] = list;
      return list;
    });
  }

  Future<void> saveSymptom(String uid, SymptomEntry entry) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'symptoms').doc(entry.id).set(entry.toMap());
    } catch (e) {
      throw AppException(code: 'save-symptom-failed', message: 'Unable to save symptom.', cause: e);
    }
  }

  Future<void> deleteSymptom(String uid, String symptomId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'symptoms').doc(symptomId).delete();
    } catch (e) {
      throw AppException(code: 'delete-symptom-failed', message: 'Unable to delete symptom.', cause: e);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MEDICATIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<Medication>> watchMedications(String uid) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_medicationsCache[uid] ?? []);
    }
    return _sub(uid, 'medications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Medication.fromMap(d.data())).toList();
      _medicationsCache[uid] = list;
      return list;
    });
  }

  Future<void> saveMedication(String uid, Medication med) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'medications').doc(med.id).set(med.toMap());
    } catch (e) {
      throw AppException(code: 'save-medication-failed', message: 'Unable to save medication.', cause: e);
    }
  }

  Future<void> deleteMedication(String uid, String medId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'medications').doc(medId).delete();
    } catch (e) {
      throw AppException(code: 'delete-medication-failed', message: 'Unable to delete medication.', cause: e);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MEDICAL RECORDS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<MedicalRecord>> watchMedicalRecords(String uid) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_recordsCache[uid] ?? []);
    }
    return _sub(uid, 'records')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => MedicalRecord.fromMap(d.data())).toList();
      _recordsCache[uid] = list;
      return list;
    });
  }

  Future<void> saveMedicalRecord(String uid, MedicalRecord record) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'records').doc(record.id).set(record.toMap());
    } catch (e) {
      throw AppException(code: 'save-record-failed', message: 'Unable to save record.', cause: e);
    }
  }

  Future<void> deleteMedicalRecord(String uid, String recordId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'records').doc(recordId).delete();
    } catch (e) {
      throw AppException(code: 'delete-record-failed', message: 'Unable to delete record.', cause: e);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // AI CHAT MESSAGES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<AiChatMessage>> watchChatMessages(String uid, String threadId) {
    if (!_isFirebaseAvailable) return Stream.value([]);
    return _sub(uid, 'ai_chats')
        .orderBy('timestamp')
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => AiChatMessage.fromMap(d.data()))
          .where((m) => m.threadId == threadId)
          .toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  Future<void> saveChatMessage(String uid, AiChatMessage msg) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'ai_chats').doc(msg.id).set(msg.toMap());
    } catch (e) {
      final denied = e.toString().contains('PERMISSION_DENIED');
      throw AppException(
        code: denied ? 'firestore-permission-denied' : 'save-chat-failed',
        message: denied
            ? 'Chat could not be saved. In Firebase Console → Firestore → Rules, publish the rules from firestore.rules in this project (allows users/{uid}/ai_chats).'
            : 'Unable to save message.',
        cause: e,
      );
    }
  }

  Future<void> deleteChatThread(String uid, String threadId) async {
    if (!_isFirebaseAvailable) return;
    final snap = await _sub(uid, 'ai_chats')
        .where('threadId', isEqualTo: threadId)
        .get();
    final batch = _requireFirestore().batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INSURANCE POLICIES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<InsurancePolicy>> watchPolicies(String uid) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_policiesCache[uid] ?? []);
    }
    return _sub(uid, 'insurance')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => InsurancePolicy.fromMap(d.data())).toList();
      _policiesCache[uid] = list;
      return list;
    });
  }

  Future<void> savePolicy(String uid, InsurancePolicy policy) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'insurance').doc(policy.id).set(policy.toMap());
    } catch (e) {
      throw AppException(code: 'save-policy-failed', message: 'Unable to save policy.', cause: e);
    }
  }

  Future<void> deletePolicy(String uid, String policyId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'insurance').doc(policyId).delete();
    } catch (e) {
      throw AppException(code: 'delete-policy-failed', message: 'Unable to delete policy.', cause: e);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INSURANCE CLAIMS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<InsuranceClaim>> watchClaims(String uid) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_claimsCache[uid] ?? []);
    }
    return _sub(uid, 'claims')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => InsuranceClaim.fromMap(d.data())).toList();
      _claimsCache[uid] = list;
      return list;
    });
  }

  Future<void> saveClaim(String uid, InsuranceClaim claim) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'claims').doc(claim.id).set(claim.toMap());
    } catch (e) {
      throw AppException(code: 'save-claim-failed', message: 'Unable to save claim.', cause: e);
    }
  }

  Future<void> deleteClaim(String uid, String claimId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'claims').doc(claimId).delete();
    } catch (e) {
      throw AppException(code: 'delete-claim-failed', message: 'Unable to delete claim.', cause: e);
    }
  }
}
