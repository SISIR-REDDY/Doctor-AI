import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/remote_config_service.dart';
import '../theme/app_theme.dart';

/// Full-screen, non-dismissible gate shown when the installed build is below
/// the `min_build_number` from Remote Config. Forces the user to update.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openStore() async {
    final url = RemoteConfigService.instance.updateUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = RemoteConfigService.instance.updateUrl.trim().isNotEmpty;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: AppTheme.xl),
                  Text('Update required',
                      style: AppTheme.headingLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    RemoteConfigService.instance.updateMessage,
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.xxl),
                  if (hasUrl)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openStore,
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppTheme.md),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.mediumRadius),
                        ),
                        child: const Text('Update now',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Text(
                      'Please update Clinix AI from your app store.',
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
