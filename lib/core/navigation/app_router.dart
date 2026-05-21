import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../screens/clinical_notes_screen.dart';
import '../../screens/document_scanner_screen.dart';
import '../../screens/doctor_patient_detail_screen.dart';
import '../../screens/emergency_triage_screen.dart';
import '../../screens/voice_assistant_screen.dart';

class AppRouter {
  static const String voiceAssistant = '/voiceAssistant';
  static const String clinicalNotes = '/clinicalNotes';
  static const String documentScanner = '/documentScanner';
  static const String emergencyTriage = '/emergencyTriage';
  static const String patientDetail = '/patient';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case voiceAssistant:
        final args = settings.arguments;
        String patientId = 'new';
        String? initialPrompt;

        if (args is Map) {
          final dynamic id = args['patientId'];
          final dynamic prompt = args['initialPrompt'];
          if (id is String && id.trim().isNotEmpty) {
            patientId = id;
          }
          if (prompt is String && prompt.trim().isNotEmpty) {
            initialPrompt = prompt;
          }
        }

        return MaterialPageRoute<void>(
          builder: (_) => InteractiveVoiceAssistantScreen(
            patientId: patientId,
            initialPrompt: initialPrompt,
          ),
          settings: settings,
        );

      case clinicalNotes:
        final args = settings.arguments;
        final patientId = args is String && args.trim().isNotEmpty
            ? args
            : 'new';
        return MaterialPageRoute<void>(
          builder: (_) => ClinicalNotesScreen(patientId: patientId),
          settings: settings,
        );

      case documentScanner:
        final args = settings.arguments;
        final patientId = args is String && args.trim().isNotEmpty
            ? args
            : 'new';
        return MaterialPageRoute<void>(
          builder: (_) => DocumentScannerScreen(patientId: patientId),
          settings: settings,
        );

      case emergencyTriage:
        final args = settings.arguments;
        String? patientId;
        String? triageId;
        if (args is Map) {
          patientId = args['patientId']?.toString();
          triageId = args['triageId']?.toString();
        } else if (args is String) {
          patientId = args;
        }
        return MaterialPageRoute<void>(
          builder: (_) => EmergencyTriageScreen(
            patientId: patientId,
            initialTriageId: triageId,
          ),
          settings: settings,
        );

      case patientDetail:
        final args = settings.arguments;
        if (args is ProviderPatientRecord) {
          return MaterialPageRoute<void>(
            builder: (_) => DoctorPatientDetailScreen(patient: args),
            settings: settings,
          );
        }
        if (args is Map && args['patient'] is ProviderPatientRecord) {
          return MaterialPageRoute<void>(
            builder: (_) => DoctorPatientDetailScreen(
              patient: args['patient'] as ProviderPatientRecord,
            ),
            settings: settings,
          );
        }
        return null;
    }
    return null;
  }

  /// Parses docpilot:// deep links from share handoffs.
  static Route<dynamic>? routeFromDeepLink(Uri uri) {
    if (uri.scheme != 'docpilot') return null;
    final host = uri.host;
    final segments = uri.pathSegments;

    if (host == 'triage' && segments.isNotEmpty) {
      return onGenerateRoute(RouteSettings(
        name: emergencyTriage,
        arguments: {'triageId': segments.first},
      ));
    }
    if (host == 'patient' && segments.isNotEmpty) {
      return onGenerateRoute(RouteSettings(
        name: emergencyTriage,
        arguments: {
          'patientId': segments.first,
          'triageId': uri.queryParameters['triage'],
        },
      ));
    }
    return null;
  }
}
