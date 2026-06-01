import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_branding.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/enhanced_connection_provider.dart';
import 'core/providers/health_data_provider.dart';
import 'core/providers/theme_controller.dart';
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
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController()..load(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: AppBranding.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.themeMode,
            // Keep the brightness-aware design tokens in sync with whichever
            // theme MaterialApp actually resolved (handles system mode too).
            // This runs before the widget subtree below rebuilds, so screens
            // read the up-to-date colors on theme changes.
            builder: (context, child) {
              AppTheme.setBrightness(Theme.of(context).brightness);
              return child ?? const SizedBox.shrink();
            },
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const AuthGateScreen(),
          );
        },
      ),
    );
  }
}
