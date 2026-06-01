import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_branding.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/enhanced_connection_provider.dart';
import 'core/providers/health_data_provider.dart';
import 'screens/auth/auth_gate_screen.dart';
import 'services/firebase/firebase_bootstrap_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await FirebaseBootstrapService.initialize();

      runApp(const ClinixAIApp());
    },
    (error, stackTrace) {
      debugPrint('Unhandled error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

class ClinixAIApp extends StatelessWidget {
  const ClinixAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EnhancedConnectionProvider>(
          create: (_) => EnhancedConnectionProvider()..initialize(),
        ),
        ChangeNotifierProvider<HealthDataProvider>(
          create: (_) => HealthDataProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppBranding.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const AuthGateScreen(),
      ),
    );
  }
}
