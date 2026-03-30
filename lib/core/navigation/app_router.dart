import 'package:flutter/material.dart';

import '../../screens/clinical_notes_screen.dart';
import '../../screens/document_scanner_screen.dart';
import '../../screens/voice_assistant_screen.dart';

class AppRouter {
  static const String voiceAssistant = '/voiceAssistant';
  static const String clinicalNotes = '/clinicalNotes';
  static const String documentScanner = '/documentScanner';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case voiceAssistant:
        final args = settings.arguments;
        String patientId = 'demo-patient';
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
            : 'demo-patient';
        return MaterialPageRoute<void>(
          builder: (_) => ClinicalNotesScreen(patientId: patientId),
          settings: settings,
        );

      case documentScanner:
        final args = settings.arguments;
        final patientId = args is String && args.trim().isNotEmpty
            ? args
            : 'demo-patient';
        return MaterialPageRoute<void>(
          builder: (_) => DocumentScannerScreen(patientId: patientId),
          settings: settings,
        );
    }
    return null;
  }
}
