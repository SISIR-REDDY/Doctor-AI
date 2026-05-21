import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../services/chatbot_service.dart';

mixin AIAnalysisMixin<T extends StatefulWidget> on State<T> {
  final ChatbotService _chatbotService = ChatbotService();

  bool isAnalyzing = false;

  /// Runs a Gemini prompt and returns the response, or null on failure.
  ///
  /// Treats any response shaped like an error sentence (e.g. starts with
  /// "Error:" or mentions a Gemini exception) as a failure too — so we
  /// never persist a stack-trace string into a patient record even if an
  /// older build leaked one through.
  Future<String?> performAIAnalysis({
    required String prompt,
    ProviderPatientRecord? patient,
    void Function(String result)? onSuccess,
  }) async {
    if (isAnalyzing) return null;

    try {
      if (mounted) {
        setState(() {
          isAnalyzing = true;
        });
      }

      final enrichedPrompt = _withPatientContext(prompt, patient);
      final result = await _chatbotService.getGeminiResponse(enrichedPrompt);

      if (_looksLikeAiError(result)) {
        debugPrint('[AIAnalysisMixin] AI returned error-shaped response, discarding.');
        return null;
      }

      if (onSuccess != null) {
        onSuccess(result);
      }
      return result;
    } catch (e) {
      debugPrint('[AIAnalysisMixin] AI request failed: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
  }

  /// True if the AI response is actually an error message (legacy
  /// `getGeminiResponse` used to return strings starting with "Error:").
  bool _looksLikeAiError(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower.startsWith('error:') ||
        lower.contains('could not connect to gemini') ||
        lower.contains('model gemini-') && lower.contains('not found') ||
        lower.contains('exception: model') ||
        lower.contains('gemini api key is invalid') ||
        lower.contains('rate limit reached');
  }

  String _withPatientContext(String prompt, ProviderPatientRecord? patient) {
    if (patient == null) return prompt;

    return '''
$prompt

Patient context:
- Name: ${patient.fullName}
- Age: ${patient.age}
- Gender: ${patient.gender}
- Medical history: ${patient.medicalHistory.join(', ')}
- Allergies: ${patient.allergies.join(', ')}
''';
  }
}
