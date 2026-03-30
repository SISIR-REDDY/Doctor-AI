import '../models/health_models.dart';

class AIPromptBuilder {
  static String buildHandoffPrompt({
    required Map<String, String> sections,
    ProviderPatientRecord? patient,
  }) {
    final patientContext = patient == null
        ? 'No patient context selected.'
        : '''
Patient Context:
- Name: ${patient.fullName}
- Age: ${patient.age}
- Gender: ${patient.gender}
- Medical History: ${patient.medicalHistory.join(', ')}
- Allergies: ${patient.allergies.join(', ')}
''';

    return '''
Create a concise but complete clinical shift handoff using the supplied details.

$patientContext
Input Sections:
- Patient Summary: ${sections['patientSummary'] ?? ''}
- Overnight Events: ${sections['overnightEvents'] ?? ''}
- Pending Tasks: ${sections['pendingTasks'] ?? ''}
- Key Issues: ${sections['keyIssues'] ?? ''}

Output format:
1. Situation
2. Background
3. Assessment
4. Recommendation
5. Safety watchouts
''';
  }
}
