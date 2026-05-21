import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_error_handler.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false;
  bool _isLoadingApple = false;

  Future<void> _signInWithGoogle() async {
    if (_isLoadingGoogle) return;
    setState(() => _isLoadingGoogle = true);

    try {
      final credential = await _authService.signInWithGoogle();
      await credential.user?.getIdToken(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await ApiCredentialsService.instance.preload();
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      _isLoadingGoogle = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_isLoadingApple) return;
    setState(() => _isLoadingApple = true);

    try {
      await _authService.signInWithApple();
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      _isLoadingApple = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirebaseConfigured =
        FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.xl,
                vertical: AppTheme.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppTheme.md),
                        _BrandHeader(),
                        const SizedBox(height: AppTheme.xl),
                        const _CapabilityGrid(),
                        const SizedBox(height: AppTheme.lg),
                        const _TrustStrip(),
                        const SizedBox(height: AppTheme.lg),
                        _SignInBlock(
                          isFirebaseConfigured: isFirebaseConfigured,
                          isLoadingGoogle: _isLoadingGoogle,
                          isLoadingApple: _isLoadingApple,
                          onGoogle: _signInWithGoogle,
                          onApple: _signInWithApple,
                        ),
                        const SizedBox(height: AppTheme.md),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/docpilot_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppTheme.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Clinix',
              style: TextStyle(
                fontSize: 32,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Clinical command center for modern physicians',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.4,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  static const _items = <_Capability>[
    _Capability(
      icon: Icons.mic_none_rounded,
      title: 'Voice Notes',
      subtitle: 'Dictate SOAP & Rx',
      accent: AppTheme.primaryColor,
    ),
    _Capability(
      icon: Icons.local_hospital_rounded,
      title: 'Triage',
      subtitle: 'ESI-aligned AI',
      accent: AppTheme.emergencyColor,
    ),
    _Capability(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Ward Rounds',
      subtitle: 'Live patient lists',
      accent: AppTheme.secondaryColor,
    ),
    _Capability(
      icon: Icons.medication_liquid_rounded,
      title: 'Med Safety',
      subtitle: 'Interactions & dosing',
      accent: AppTheme.surgeryColor,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.lg,
        AppTheme.lg,
        AppTheme.lg,
        AppTheme.md,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'BUILT FOR CLINICIANS',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.6,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CapabilityTile(item: _items[0])),
                const SizedBox(width: AppTheme.sm),
                Expanded(child: _CapabilityTile(item: _items[1])),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CapabilityTile(item: _items[2])),
                const SizedBox(width: AppTheme.sm),
                Expanded(child: _CapabilityTile(item: _items[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Capability {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  const _Capability({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

class _CapabilityTile extends StatelessWidget {
  final _Capability item;
  const _CapabilityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.md,
        vertical: AppTheme.md,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 17, color: item.accent),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: AppTheme.labelLarge.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.25,
              fontSize: 11.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(Icons.shield_outlined, 'Encrypted'),
        Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: AppTheme.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        chip(Icons.cloud_done_outlined, 'Secure cloud sync'),
        Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: AppTheme.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        chip(Icons.verified_user_outlined, 'Clinician-only'),
      ],
    );
  }
}

class _SignInBlock extends StatelessWidget {
  final bool isFirebaseConfigured;
  final bool isLoadingGoogle;
  final bool isLoadingApple;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const _SignInBlock({
    required this.isFirebaseConfigured,
    required this.isLoadingGoogle,
    required this.isLoadingApple,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosButton(
          label: 'Continue with Google',
          iconWidget: Image.asset(
            'assets/images/google_logo.png',
            height: 20,
            width: 20,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.g_mobiledata,
                size: 22,
                color: Colors.black54,
              );
            },
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          isLoading: isLoadingGoogle,
          onPressed: onGoogle,
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: AppTheme.sm),
          IosButton(
            label: 'Continue with Apple',
            icon: Icons.apple,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            isLoading: isLoadingApple,
            onPressed: onApple,
          ),
        ],
        const SizedBox(height: AppTheme.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFirebaseConfigured
                  ? Icons.lock_outline
                  : Icons.warning_amber_rounded,
              size: 13,
              color: isFirebaseConfigured
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                isFirebaseConfigured
                    ? 'HIPAA-aware handling · Secure sync active'
                    : 'Firebase setup required before sign-in is available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isFirebaseConfigured
                      ? AppTheme.textSecondary
                      : AppTheme.warningColor,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'By continuing you agree to secure handling of clinical content.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: AppTheme.textTertiary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
