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
    return '''You are a clinical documentation assistant.
Summarize the following doctor-patient conversation in a concise, structured format.

Format:
- Chief complaint
- HPI (1-2 sentences)
- Findings/Observations
- Assessment
- Plan/Next steps

Conversation:
$transcript
''';
  }

  String _buildPrescriptionPrompt(String transcript) {
    return '''You are a clinical assistant.
Based on the conversation below, draft a prescription plan or recommendations.
If information is insufficient, state "Insufficient data" and list missing details.
Use bullet points.

Conversation:
$transcript
''';
  }
}
