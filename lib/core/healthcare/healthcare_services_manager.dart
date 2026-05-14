import 'package:uuid/uuid.dart';

import '../../models/health_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/deepgram_service.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';

class HealthcareServicesManager {
  HealthcareServicesManager._internal();

  static final HealthcareServicesManager _instance =
      HealthcareServicesManager._internal();

  factory HealthcareServicesManager() => _instance;

  final AuthService auth = AuthService();
  final FirestoreService firestore = FirestoreService();
  final ChatbotService chatbot = ChatbotService();
  final DeepgramService deepgram = DeepgramService();
  final StorageService storage = StorageService();

  String get currentDoctorId => auth.currentUser?.uid ?? '';

  Future<bool> ensureApiKeysAvailable() async {
    await ApiCredentialsService.instance.preload();
    return ApiCredentialsService.instance.hasKeys();
  }

  Future<String?> uploadConsultationAudio({
    required String filePath,
    required String sessionId,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return null;
    return storage.uploadAudioFile(
      filePath: filePath,
      doctorId: doctorId,
      sessionId: sessionId,
    );
  }

  Future<void> persistConsultation({
    required ProviderPatientRecord patient,
    required String transcript,
    required String summary,
    required String prescription,
    required String source,
    String? audioUrl,
    int durationSeconds = 0,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return;

    final session = ConsultationSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      patientId: patient.id,
      patientName: patient.fullName,
      transcript: transcript,
      summary: summary,
      prescription: prescription,
      source: source,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    await firestore.saveConsultationSession(session);
  }

  String? suggestPatientNameFromTranscript(String transcript) {
    final text = transcript.replaceAll('\n', ' ');
    final patterns = <RegExp>[
      RegExp(r"\bmy name is\s+([A-Za-z][A-Za-z\s\-']{1,60})", caseSensitive: false),
      RegExp(r"\bi'?m\s+([A-Za-z][A-Za-z\s\-']{1,60})", caseSensitive: false),
      RegExp(r"\bi am\s+([A-Za-z][A-Za-z\s\-']{1,60})", caseSensitive: false),
      RegExp(r"\bthis is\s+([A-Za-z][A-Za-z\s\-']{1,60})", caseSensitive: false),
      RegExp(r"\bpatient name is\s+([A-Za-z][A-Za-z\s\-']{1,60})", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final rawName = match.group(1) ?? '';
        final normalized = _normalizeName(rawName);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return null;
  }

  Future<ProviderPatientRecord?> createPatientWithSession({
    required String patientName,
    required String transcript,
    required String summary,
    required String prescription,
    required String source,
    String? audioUrl,
    int durationSeconds = 0,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return null;

    final resolvedName = _normalizeName(patientName).trim();
    final safeName = resolvedName.isEmpty ? 'Unknown Patient' : resolvedName;
    final nameParts = _splitName(safeName);
    final now = DateTime.now();

    final patient = ProviderPatientRecord(
      id: const Uuid().v4(),
      doctorId: doctorId,
      firstName: nameParts.first,
      lastName: nameParts.last,
      lastVisitSummary: _firstLine(summary, fallback: transcript),
      prescriptions: _extractPrescriptionItems(prescription),
      reports: const <String>[],
      foodAllergies: const <String>[],
      medicinalAllergies: const <String>[],
      medicalHistory: const <String>[],
      createdAt: now,
      updatedAt: now,
    );

    await firestore.savePatientRecord(patient);

    final session = ConsultationSession(
      id: 'session_${now.microsecondsSinceEpoch}',
      doctorId: doctorId,
      patientId: patient.id,
      patientName: patient.fullName,
      transcript: transcript,
      summary: summary,
      prescription: prescription,
      source: source,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      createdAt: now,
    );

    await firestore.saveConsultationSession(session);

    if (summary.trim().isNotEmpty) {
      await saveClinicalNote(
        patientId: patient.id,
        title: 'Consultation Summary • ${_formatTimestamp(now)}',
        content: summary,
      );
    }

    return patient;
  }

  Future<void> deletePatientAndRecords(ProviderPatientRecord patient) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return;

    final sessions = await firestore.getConsultationSessionsForPatient(
      doctorId: doctorId,
      patientId: patient.id,
    );

    for (final session in sessions) {
      if (session.audioUrl != null && session.audioUrl!.trim().isNotEmpty) {
        await storage.deleteAudioFile(session.audioUrl!);
      }
      await firestore.deleteConsultationSession(session.id);
    }

    final notes = await firestore.getClinicalReports(patient.id);
    for (final note in notes) {
      await firestore.deleteClinicalReport(note.id);
    }

    final scans = await firestore.getDocumentScans(patient.id);
    for (final scan in scans) {
      await firestore.deleteDocumentScan(scan.id);
    }

    await firestore.deletePatientRecord(patient.id);
  }

  String _firstLine(String text, {String fallback = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return fallback.trim();
    }
    final line = trimmed.split(RegExp(r'\n+')).first.trim();
    if (line.length <= 140) return line;
    return '${line.substring(0, 140)}...';
  }

  String _normalizeName(String value) {
    final cleaned = value.replaceAll(RegExp(r"[^A-Za-z\s\-']"), ' ').trim();
    if (cleaned.isEmpty) return '';
    final words = cleaned.split(RegExp(r'\s+'));
    return words.map(_titleCaseWord).join(' ');
  }

  String _titleCaseWord(String word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  List<String> _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return ['Unknown', ''];
    final first = parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return [first, last];
  }

  List<String> _extractPrescriptionItems(String prescription) {
    final lines = prescription
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(8)
        .map((line) => line.replaceFirst(RegExp(r'^[\-*\d\.\)\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines;
  }

  String _formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $h:$m';
  }

  Future<void> saveClinicalNote({
    required String patientId,
    required String title,
    required String content,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return;

    final now = DateTime.now();
    final note = ClinicalNote(
      id: 'note_${now.microsecondsSinceEpoch}',
      patientId: patientId,
      doctorId: doctorId,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await firestore.saveClinicalReport(note);
  }

  Future<void> deleteConsultation(ConsultationSession session) async {
    if (session.audioUrl != null && session.audioUrl!.trim().isNotEmpty) {
      await storage.deleteAudioFile(session.audioUrl!);
    }
    await firestore.deleteConsultationSession(session.id);
  }
}
