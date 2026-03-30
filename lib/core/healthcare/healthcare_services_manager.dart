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
