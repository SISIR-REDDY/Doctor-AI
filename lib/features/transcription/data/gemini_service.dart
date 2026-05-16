import 'package:docpilot/services/chatbot_service.dart';

class GeminiService {
  final ChatbotService _chatbotService = ChatbotService();

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
    return '''You are a clinical documentation assistant. Analyze this consultation transcript.

Transcript:
$transcript

Respond using EXACTLY these section headers (one per line, with bullets under each):

Chief complaint:
- ...

HPI:
- ...

Findings/Observations:
- ...

Assessment:
- ...

Plan:
- ...

Safety flags:
- ... (or "None noted")

Follow-up:
- ...

Rules:
- Use only facts from the transcript. If unknown, write "Not available from transcript".
- No markdown headers (#). No placeholders like [Insert name].
- Keep each section concise and clinically useful.''';
  }

  String _buildPrescriptionPrompt(String transcript) {
    return '''You are a clinical prescribing assistant. Based on this consultation transcript:

$transcript

Respond using EXACTLY these section headers:

Medications:
- drug name, dose, frequency, duration (only if supported by transcript)

Tests and diagnostics:
- labs/imaging to order (only if clinically indicated)

Patient education:
- self-care, lifestyle, when to return

Warnings and cautions:
- allergies, interactions, red flags

Missing details:
- list any critical missing info for a safe prescription

Rules:
- Separate OTC suggestions under Medications with "(OTC)" prefix.
- Do not put medication advice under Tests.
- If insufficient data, say so under Missing details.
- No markdown # headers. No placeholders.''';
  }
}
