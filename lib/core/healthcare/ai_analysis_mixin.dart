import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../services/chatbot_service.dart';

mixin AIAnalysisMixin<T extends StatefulWidget> on State<T> {
  final ChatbotService _chatbotService = ChatbotService();

  bool isAnalyzing = false;

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

      if (onSuccess != null) {
        onSuccess(result);
      }
      return result;
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
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
