import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/config/firebase_config.dart';
import '../../core/providers/health_data_provider.dart';
import '../../features/home/home_dashboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../models/patient_models.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/push_notification_service.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool _isSignedIn = false;
  bool _needsOnboarding = false;
  bool _profileResolved = false;
  bool _scanFirst = false;
  PatientProfile? _existingProfile;
  String? _preloadedKeysForUid;

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    if (FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized) {
      _authSub = _authService.authStateChanges().listen(_onAuthChanged);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    final signedIn = user != null;
    if (user != null) {
      _handleSignedIn(user);
    } else {
      _handleSignedOut();
    }
    if (_isLoading || _isSignedIn != signedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSignedIn = signedIn;
        });
      }
    }
  }

  void _handleSignedIn(User user) {
    if (_preloadedKeysForUid == user.uid) return;
    _preloadedKeysForUid = user.uid;

    ApiCredentialsService.instance.preload().catchError((e) {
      if (kDebugMode) debugPrint('[AuthGate] API keys not ready: $e');
    });

    // Associate this device's FCM token with the signed-in user for push.
    PushNotificationService.instance.registerForUser(user.uid);

    // Bind purchases / Pro entitlement and analytics identity to this user.
    EntitlementService.instance.attachUser(user.uid);
    Analytics.setUser(user.uid);

    _firestoreService.loadPatientProfile(user.uid).then((profile) async {
      if (!mounted) return;
      await context.read<HealthDataProvider>().loadProfile();
      if (mounted) {
        setState(() {
          _existingProfile = profile;
          // New users AND legacy profiles (no country / old flow) go through
          // the short onboarding so region-dependent features work.
          _needsOnboarding =
              profile == null || profile.onboardingVersion < kOnboardingVersion;
          _profileResolved = true;
        });
      }
    }).catchError((_) async {
      if (!mounted) return;
      await context.read<HealthDataProvider>().loadProfile();
      if (mounted) {
        setState(() {
          _needsOnboarding = false;
          _profileResolved = true;
        });
      }
    });
  }

  void _handleSignedOut() {
    _preloadedKeysForUid = null;
    _needsOnboarding = false;
    _profileResolved = false;
    _existingProfile = null;
    _scanFirst = false;
    ApiCredentialsService.instance.clearCache();
    EntitlementService.instance.detachUser();
    Analytics.setUser(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseConfig.isEnabled) return const WelcomeScreen();

    if (_isLoading || (_isSignedIn && !_profileResolved)) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0078D4), Color(0xFF00BCB4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSignedIn) {
      if (_needsOnboarding) {
        return OnboardingScreen(
          existing: _existingProfile,
          onComplete: ({required bool scanFirst}) {
            if (mounted) {
              setState(() {
                _needsOnboarding = false;
                _scanFirst = scanFirst;
              });
            }
          },
        );
      }
      return HomeDashboardScreen(scanFirst: _scanFirst);
    }

    // Consent (terms, privacy, disclaimers) is captured on the sign-in step
    // of the welcome flow — the buttons stay disabled until it is given.
    return const WelcomeScreen();
  }
}
