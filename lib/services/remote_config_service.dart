import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Firebase Remote Config gate used to force users off unsupported app builds.
///
/// Set `min_build_number` in the Firebase console to the lowest build the
/// backend still supports. Any install with a lower build number is blocked
/// behind a force-update screen. Optionally set `update_url` (store link) and
/// `update_message`.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  FirebaseRemoteConfig? _rc;
  int _currentBuild = 0;

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults(const {
        'min_build_number': 0,
        'update_url': '',
        'update_message':
            'A newer version of Clinix AI is required to continue.',
        // Beta switch: every signed-in user gets Pro (mirror it in Firestore
        // `app_runtime/config.everyonePro` so the backend agrees).
        'everyone_pro': false,
        // RevenueCat public SDK keys (alternative to --dart-define).
        'rc_android_key': '',
        'rc_ios_key': '',
        // Pricing copy shown on the paywall before offerings load.
        'pro_monthly_price': r'$9.99',
        'pro_yearly_price': r'$79.99',
      });
      await rc.fetchAndActivate();
      _rc = rc;
    } catch (e) {
      if (kDebugMode) debugPrint('[RemoteConfigService] init failed: $e');
    }
  }

  int get _minBuild => _rc?.getInt('min_build_number') ?? 0;
  String get updateUrl => _rc?.getString('update_url') ?? '';
  String get updateMessage =>
      _rc?.getString('update_message') ??
      'A newer version of Clinix AI is required to continue.';

  /// True when this install's build is older than the required minimum.
  bool get updateRequired => _currentBuild > 0 && _currentBuild < _minBuild;

  /// Generic string accessor with a fallback when the value is unset/empty.
  String string(String key, String fallback) {
    final v = _rc?.getString(key) ?? '';
    return v.isEmpty ? fallback : v;
  }
}
