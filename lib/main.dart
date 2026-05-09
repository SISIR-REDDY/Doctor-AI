import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_router.dart';
import 'core/providers/enhanced_connection_provider.dart';
import 'core/providers/patient_provider.dart';
import 'screens/auth/auth_gate_screen.dart';
import 'services/firebase/firebase_bootstrap_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: .env file not found or failed to load: $e');
  }

  await FirebaseBootstrapService.initialize();

  runZonedGuarded(
    () => runApp(const DocPilotApp()),
    (error, stackTrace) {
      debugPrint('Unhandled app error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

class DocPilotApp extends StatelessWidget {
  const DocPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EnhancedConnectionProvider>(
          create: (_) => EnhancedConnectionProvider()..initialize(),
        ),
        ChangeNotifierProvider<PatientProvider>(
          create: (_) => PatientProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'DocPilot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const AuthGateScreen(),
      ),
    );
  }
}
