import '../data/deepgram_service.dart';

class TranscriptionModel {
  /// Plain text transcript (no speaker labels).
  final String rawTranscript;

  /// Formatted transcript with AI-classified speaker labels.
  /// e.g. "[Doctor]: What brings you in today?\n[Patient]: I have chest pain."
  final String diarizedTranscript;

  /// Deepgram utterances (raw speaker IDs before AI classification).
  final List<SpeakerUtterance> utterances;

  /// Maps Deepgram speaker ID → role ('Doctor' | 'Patient' | 'Unknown').
  /// e.g. {0: 'Doctor', 1: 'Patient'}
  final Map<int, String> speakerRoles;

  final String summary;
  final String prescription;

  const TranscriptionModel({
    this.rawTranscript = '',
    this.diarizedTranscript = '',
    this.utterances = const [],
    this.speakerRoles = const {},
    this.summary = '',
    this.prescription = '',
  });

  /// Returns true when AI has classified at least one speaker as Doctor.
  bool get hasSpeakerClassification => speakerRoles.values.contains('Doctor');

  /// The speaker ID classified as Doctor (-1 if not yet classified).
  int get doctorSpeakerId =>
      speakerRoles.entries
          .where((e) => e.value == 'Doctor')
          .map((e) => e.key)
          .firstOrNull ??
      -1;

  /// The speaker ID classified as Patient (-1 if not yet classified).
  int get patientSpeakerId =>
      speakerRoles.entries
          .where((e) => e.value == 'Patient')
          .map((e) => e.key)
          .firstOrNull ??
      -1;

  /// The transcript the AI received for summary/prescription generation.
  /// Prefers diarized (speaker-labeled) if available, falls back to raw.
  String get transcriptForAI =>
      diarizedTranscript.isNotEmpty ? diarizedTranscript : rawTranscript;

  TranscriptionModel copyWith({
    String? rawTranscript,
    String? diarizedTranscript,
    List<SpeakerUtterance>? utterances,
    Map<int, String>? speakerRoles,
    String? summary,
    String? prescription,
  }) {
    return TranscriptionModel(
      rawTranscript: rawTranscript ?? this.rawTranscript,
      diarizedTranscript: diarizedTranscript ?? this.diarizedTranscript,
      utterances: utterances ?? this.utterances,
      speakerRoles: speakerRoles ?? this.speakerRoles,
      summary: summary ?? this.summary,
      prescription: prescription ?? this.prescription,
    );
  }
}
