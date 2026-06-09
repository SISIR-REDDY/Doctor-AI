import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/legal_content.dart';

/// Persists the user's acceptance of the Terms, Privacy Policy, and disclaimers.
///
/// Acceptance is stored with the [AppLegal.consentVersion] so that when the
/// terms materially change you can bump the version and re-prompt everyone.
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  static const _key = 'accepted_consent_version';

  /// True when the user has accepted the current consent version.
  Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) == AppLegal.consentVersion;
  }

  /// Records acceptance of the current consent version.
  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, AppLegal.consentVersion);
  }

  /// Clears acceptance (e.g. for testing or on account deletion).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
