import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config/firebase_config.dart';
import '../../features/auth/patient_onboarding_screen.dart';
import '../../features/home/home_dashboard_screen.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../../services/firebase/firestore_service.dart';
import 'sign_in_screen.dart';

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

    _firestoreService.loadPatientProfile(user.uid).then((profile) {
      if (mounted) setState(() => _needsOnboarding = profile == null);
    }).catchError((_) {
      if (mounted) setState(() => _needsOnboarding = false);
    });
  }

  void _handleSignedOut() {
    _preloadedKeysForUid = null;
    _needsOnboarding = false;
    ApiCredentialsService.instance.clearCache();
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseConfig.isEnabled) return const SignInScreen();

    if (_isLoading) {
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
        return PatientOnboardingScreen(
          onComplete: () {
            if (mounted) setState(() => _needsOnboarding = false);
          },
        );
      }
      return const HomeDashboardScreen();
    }

    return const SignInScreen();
  }
}
