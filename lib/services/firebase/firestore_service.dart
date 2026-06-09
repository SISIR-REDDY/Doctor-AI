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

  /// Every per-user subcollection. Keep in sync when adding new data types so
  /// account deletion stays complete (App Store Guideline 5.1.1(v)).
  static const List<String> userSubcollections = [
    'symptoms',
    'medications',
    'medication_logs',
    'records',
    'insurance',
    'claims',
    'ai_chats',
    'chat_sessions',
    'reminders',
  ];

  /// Permanently deletes ALL of a user's data: every subcollection document and
  /// the user root document. Throws on failure so the caller can keep the auth
  /// account (and let the user retry) rather than orphaning data.
  Future<void> deleteAllUserData(String uid) async {
    if (!_isFirebaseAvailable) return;
    final db = _requireFirestore();
    for (final col in userSubcollections) {
      // Page through in batches so large collections don't exhaust a single
      // batch's 500-write limit.
      while (true) {
        final snap = await _sub(uid, col).limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) break;
      }
    }
    await _userDoc(uid).delete();
    // Drop any cached copies held in memory.
    _recordsCache.remove(uid);
    _policiesCache.remove(uid);
    _claimsCache.remove(uid);
  }

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
  // MEDICATION LOGS (adherence)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Logs for a single day (date as 'yyyy-MM-dd'). Sorted in memory.
  Stream<List<MedicationLog>> watchMedicationLogs(String uid, String date) {
    if (!_isFirebaseAvailable) return Stream.value(const []);
    return _sub(uid, 'medication_logs')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((s) {
      final list =
          s.docs.map((d) => MedicationLog.fromMap(d.data())).toList();
      list.sort((a, b) => a.time.compareTo(b.time));
      return list;
    });
  }

  /// Logs on or after [sinceDate] ('yyyy-MM-dd'); used for adherence stats.
  /// Date strings sort chronologically, so a single range filter suffices.
  Stream<List<MedicationLog>> watchRecentMedicationLogs(
      String uid, String sinceDate) {
    if (!_isFirebaseAvailable) return Stream.value(const []);
    return _sub(uid, 'medication_logs')
        .where('date', isGreaterThanOrEqualTo: sinceDate)
        .snapshots()
        .map((s) => s.docs.map((d) => MedicationLog.fromMap(d.data())).toList());
  }

  Future<void> saveMedicationLog(String uid, MedicationLog log) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'medication_logs').doc(log.id).set(log.toMap());
    } catch (e) {
      throw AppException(
          code: 'save-medlog-failed',
          message: 'Unable to save dose.',
          cause: e);
    }
  }

  Future<void> deleteMedicationLog(String uid, String logId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'medication_logs').doc(logId).delete();
    } catch (e) {
      throw AppException(
          code: 'delete-medlog-failed',
          message: 'Unable to update dose.',
          cause: e);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HEALTH REMINDERS (vaccination / appointment / custom)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<HealthReminder>> watchReminders(String uid) {
    if (!_isFirebaseAvailable) return Stream.value(const []);
    return _sub(uid, 'reminders')
        .orderBy('dateTime')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => HealthReminder.fromMap(d.data())).toList());
  }

  Future<void> saveReminder(String uid, HealthReminder reminder) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'reminders').doc(reminder.id).set(reminder.toMap());
    } catch (e) {
      throw AppException(
          code: 'save-reminder-failed',
          message: 'Unable to save reminder.',
          cause: e);
    }
  }

  Future<void> deleteReminder(String uid, String reminderId) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'reminders').doc(reminderId).delete();
    } catch (e) {
      throw AppException(
          code: 'delete-reminder-failed',
          message: 'Unable to delete reminder.',
          cause: e);
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
  // CHAT SESSIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<ChatSession>> watchChatSessions(String uid) {
    if (!_isFirebaseAvailable) return Stream.value([]);
    return _sub(uid, 'chat_sessions')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChatSession.fromMap(d.data())).toList());
  }

  Future<ChatSession?> loadLatestChatSession(String uid) async {
    if (!_isFirebaseAvailable) return null;
    try {
      final snap = await _sub(uid, 'chat_sessions')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return ChatSession.fromMap(snap.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChatSession(String uid, ChatSession session) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'chat_sessions').doc(session.id).set(session.toMap());
    } catch (e) {
      final str = e.toString().toLowerCase();
      final denied = str.contains('permission-denied') ||
          str.contains('permission_denied') ||
          str.contains('unauthorized');
      throw AppException(
        code: denied ? 'firestore-permission-denied' : 'save-session-failed',
        message: denied
            ? 'Chat session could not be saved — Firestore rules are blocking writes.'
            : 'Unable to save chat session.',
        cause: e,
      );
    }
  }

  Future<void> deleteChatSession(String uid, String sessionId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _sub(uid, 'chat_sessions').doc(sessionId).delete();
      await deleteChatThread(uid, sessionId);
    } catch (e) {
      throw AppException(
        code: 'delete-session-failed',
        message: 'Unable to delete chat session.',
        cause: e,
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // AI CHAT MESSAGES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Stream<List<AiChatMessage>> watchChatMessages(String uid, String threadId) {
    if (!_isFirebaseAvailable) return Stream.value([]);
    // Load all ai_chats ordered by timestamp and filter client-side.
    // This avoids requiring a composite (threadId + timestamp) Firestore index
    // while still supporting multiple sessions correctly.
    return _sub(uid, 'ai_chats')
        .orderBy('timestamp')
        .snapshots()
        .map((s) {
      return s.docs
          .map((d) => AiChatMessage.fromMap(d.data()))
          .where((m) => m.threadId == threadId)
          .toList();
    });
  }

  Future<void> saveChatMessage(String uid, AiChatMessage msg) async {
    _ensureFirebaseForWrite();
    try {
      await _sub(uid, 'ai_chats').doc(msg.id).set(msg.toMap());
    } catch (e) {
      final str = e.toString().toLowerCase();
      final denied = str.contains('permission-denied') ||
          str.contains('permission_denied') ||
          str.contains('unauthorized');
      throw AppException(
        code: denied ? 'firestore-permission-denied' : 'save-chat-failed',
        message: denied
            ? 'Chat could not be saved — Firestore rules are blocking writes. '
                'Open Firebase Console → Firestore → Rules and publish the '
                'rules from firestore.rules (allows users/{uid}/ai_chats).'
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
