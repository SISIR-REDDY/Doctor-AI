import '../../models/health_models.dart';

/// Builds shareable triage handoff text and in-app deep link payloads.
abstract final class EmergencyTriageShare {
  static const String appScheme = 'docpilot';
  static const String webFallback = 'https://github.com/SISIR-REDDY/Doctor-AI';

  static String patientDeepLink(String patientId, {String? triageId}) {
    final base = '$appScheme://patient/$patientId';
    if (triageId != null && triageId.isNotEmpty) {
      return '$base?triage=$triageId';
    }
    return base;
  }

  static String triageDeepLink(String triageId) => '$appScheme://triage/$triageId';

  static String buildShareMessage({
    required EmergencyTriageRecord record,
    required String doctorName,
  }) {
    final buffer = StringBuffer()
      ..writeln('🚨 EMERGENCY TRIAGE HANDOFF')
      ..writeln('Priority: ${record.priorityLevel.isEmpty ? "Pending" : record.priorityLevel}'
          '${record.esiLevel > 0 ? " • ESI-${record.esiLevel}" : ""}')
      ..writeln()
      ..writeln('Patient: ${record.patientName}')
      ..writeln('Age/Gender: ${record.patientAge} yrs • ${record.patientGender}')
      ..writeln('Arrival: ${record.arrivalMode}')
      ..writeln()
      ..writeln('Chief complaint: ${record.chiefComplaint}')
      ..writeln('Vitals: ${record.vitalSignsSummary}')
      ..writeln('Pain: ${record.painLevel}/10')
      ..writeln('Symptoms: ${record.symptoms.isEmpty ? "—" : record.symptoms}');

    if (record.patientAllergies.isNotEmpty) {
      buffer.writeln('⚠️ Allergies: ${record.patientAllergies.join(", ")}');
    }
    if (record.patientMedicalHistory.isNotEmpty) {
      buffer.writeln('History: ${record.patientMedicalHistory.take(4).join(", ")}');
    }
    if (record.triageNotes.trim().isNotEmpty) {
      buffer.writeln('Notes: ${record.triageNotes.trim()}');
    }

    buffer
      ..writeln()
      ..writeln('— Open in Clinix AI —')
      ..writeln('Share code: ${record.shareCode}')
      ..writeln('Triage ID: ${record.id}');
    if (record.patientId.isNotEmpty) {
      buffer.writeln('Patient ID: ${record.patientId}');
    }
    buffer
      ..writeln('Link: ${triageDeepLink(record.id)}')
      ..writeln()
      ..writeln('In Clinix AI: Emergency Triage → Import Case → enter share code')
      ..writeln('Assessed by: $doctorName')
      ..writeln('Time: ${record.createdAt.toIso8601String()}');

    if (record.aiAssessment.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('--- AI Assessment (excerpt) ---')
        ..writeln(_excerpt(record.aiAssessment, 600));
    }

    return buffer.toString().trim();
  }

  static String _excerpt(String text, int maxLen) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}…';
  }
}
