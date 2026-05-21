import 'dart:developer' as developer;
import 'package:docpilot/services/chatbot_service.dart';
import 'deepgram_service.dart';

class GeminiService {
  final ChatbotService _chatbotService = ChatbotService();

  // ── Speaker Classification ──────────────────────────────────────────────

  /// Analyses a diarized transcript and returns a role map.
  /// e.g. {0: 'Doctor', 1: 'Patient'}
  ///
  /// Never assumes Speaker 0 = Doctor — lets the AI read the content.
  Future<Map<int, String>> classifySpeakers(
    List<SpeakerUtterance> utterances,
  ) async {
    if (utterances.isEmpty) return {};

    final speakerIds = utterances.map((u) => u.speakerId).toSet().toList()..sort();
    if (speakerIds.length == 1) {
      // Only one speaker — treat as Doctor (monologue mode)
      return {speakerIds.first: 'Doctor'};
    }

    // Build a short sample (max 30 utterances to keep prompt tight)
    final sample = utterances.take(30).toList();
    final sampleText = sample
        .map((u) => '[Speaker ${u.speakerId}]: ${u.text.trim()}')
        .join('\n');

    final prompt = '''
You are a medical conversation analyst.

Below is a transcript excerpt from a doctor-patient consultation.
Speakers are labelled with numeric IDs (e.g. [Speaker 0], [Speaker 1]).

Transcript:
$sampleText

Task:
1. Read every line carefully.
2. Identify WHICH speaker number is the Doctor and WHICH is the Patient.
   - Doctor: asks diagnostic questions, gives medical advice, mentions medications or tests, uses clinical terminology.
   - Patient: describes personal symptoms, answers questions about their own body, asks about their own health.
3. If there are more than 2 speakers, assign the most likely role to each.

CRITICAL RULES:
- Do NOT assume Speaker 0 is always the Doctor.
- Base your answer ONLY on what each speaker actually says.
- If you cannot determine a role with confidence, write "Unknown".

Respond with ONLY a JSON object — no explanation, no markdown.
Example for 2 speakers: {"0": "Patient", "1": "Doctor"}
Example for 3 speakers: {"0": "Doctor", "1": "Patient", "2": "Unknown"}

Your answer (JSON only):''';

    try {
      final raw = await _chatbotService.getGeminiResponse(prompt);
      return _parseSpeakerMap(raw, speakerIds);
    } catch (e) {
      developer.log('Speaker classification failed: $e');
      // Safe fallback — mark all as Unknown so UI doesn't mislabel
      return {for (final id in speakerIds) id: 'Unknown'};
    }
  }

  Map<int, String> _parseSpeakerMap(String raw, List<int> speakerIds) {
    // Extract the JSON object from the response
    final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(raw);
    if (jsonMatch == null) return {for (final id in speakerIds) id: 'Unknown'};

    try {
      final jsonStr = jsonMatch.group(0)!;
      // Manual key-value extraction (avoid dart:convert dependency issues)
      final result = <int, String>{};
      final pairs = RegExp(r'"(\d+)"\s*:\s*"([^"]+)"').allMatches(jsonStr);
      for (final m in pairs) {
        final id = int.tryParse(m.group(1) ?? '');
        final role = m.group(2) ?? 'Unknown';
        if (id != null) result[id] = role;
      }
      return result.isNotEmpty ? result : {for (final id in speakerIds) id: 'Unknown'};
    } catch (_) {
      return {for (final id in speakerIds) id: 'Unknown'};
    }
  }

  // ── Clinical Outputs ────────────────────────────────────────────────────

  Future<String> generateSummary(String transcript) async {
    if (transcript.trim().isEmpty) return '';
    final prompt = _buildSummaryPrompt(transcript);
    return _chatbotService.getGeminiResponse(prompt);
  }

  Future<String> generatePrescription(String transcript) async {
    if (transcript.trim().isEmpty) return '';
    final prompt = _buildPrescriptionPrompt(transcript);
    return _chatbotService.getGeminiResponse(prompt);
  }

  String _buildSummaryPrompt(String transcript) {
    return '''You are a senior clinician documenting a consultation. Produce complete, clinically useful SOAP notes.

TRANSCRIPT:
$transcript

SECTION RULES:
- Chief complaint + HPI: extract directly from transcript. Factual only.
- Assessment + Plan + Follow-up: use clinical reasoning based on the symptoms. Be thorough and genuinely useful — a doctor needs this to treat the patient.
- Safety flags: any allergies, red flags, drug risks, or urgent warning signs relevant to these symptoms.
- Findings/Observations: only include if physical exam findings were mentioned.

Use these headers exactly (plain text only — no #, no **):

Chief complaint:
HPI:
Findings/Observations:
Assessment:
Plan:
Safety flags:
Follow-up:

FORMAT:
- 2-4 bullets per section, each on its own line starting with -
- Use clinical shorthand (e.g. "SOB 3/7", "Paracetamol 500 mg TDS × 5/7")
- Assessment: include probable diagnoses with confidence (e.g. "- Likely gastritis (epigastric pain, no trauma hx)")
- Plan: include specific drugs with doses, investigations, referrals
- Never write "Not available", "Not documented", or placeholder text
- Omit only "Findings/Observations" if truly no exam was done''';
  }

  String _buildPrescriptionPrompt(String transcript) {
    return '''You are an experienced clinical prescriber. Generate a complete, safe treatment plan for this patient.

TRANSCRIPT:
$transcript

Generate ALL four sections. Use clinical knowledge to recommend evidence-based treatment for the reported symptoms.
Mark drugs that were explicitly prescribed as "Prescribed:" and AI-suggested options as "Suggested:".

Use these headers exactly (plain text — no #, no **):

Medications:
Tests and diagnostics:
Patient instructions:
Warnings:

FORMAT (use - bullets, plain text):
- Medications: Drug name · dose · route · frequency · duration — one drug per bullet
  OTC drugs: add (OTC) at the end
- Tests: investigation name [clinical reason] — one test per bullet
- Patient instructions: clear, actionable self-care for these specific symptoms
- Warnings: drug interactions, red flags, when to go to emergency
- Minimum 2 bullets per section
- If truly no clinical content in transcript: write only "Insufficient clinical content — please record a real consultation."''';
  }
}
