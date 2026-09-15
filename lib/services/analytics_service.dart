import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase/firebase_bootstrap_service.dart';

/// Product analytics — the funnel and value metrics an investor (and you)
/// will ask for: activation (first scan), audits run, letters drafted,
/// money recovered, paywall conversion.
///
/// Never log health content, amounts tied to identity, or free text — only
/// event names and coarse, non-identifying parameters.
class Analytics {
  Analytics._();

  static FirebaseAnalytics? get _fa {
    if (!FirebaseBootstrapService.isInitialized) return null;
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUser(String? uid, {String? plan, String? region}) async {
    final fa = _fa;
    if (fa == null) return;
    await fa.setUserId(id: uid);
    if (plan != null) await fa.setUserProperty(name: 'plan', value: plan);
    if (region != null) await fa.setUserProperty(name: 'region', value: region);
  }

  static Future<void> log(String name, [Map<String, Object>? params]) async {
    final fa = _fa;
    if (kDebugMode) debugPrint('[Analytics] $name ${params ?? ''}');
    if (fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] $name failed: $e');
    }
  }

  static Future<void> screen(String name) async {
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logScreenView(screenName: name);
    } catch (_) {}
  }

  // ── Named events (keep this list in sync with your dashboard) ────────────
  static Future<void> onboardingStep(String step) => log('onboarding_step', {'step': step});
  static Future<void> onboardingComplete(String region) => log('onboarding_complete', {'region': region});
  static Future<void> scanStarted(String docType) => log('scan_started', {'doc_type': docType});
  static Future<void> scanCompleted(String docType, {required bool success, int pages = 1}) =>
      log('scan_completed', {'doc_type': docType, 'success': success ? 1 : 0, 'pages': pages});
  static Future<void> auditRun({required int findings, required String risk}) =>
      log('audit_run', {'findings': findings, 'risk': risk});
  static Future<void> letterDrafted(String kind) => log('letter_drafted', {'kind': kind});
  static Future<void> denialExplained(String strength) => log('denial_explained', {'strength': strength});
  static Future<void> pdfExported(String kind) => log('pdf_exported', {'kind': kind});
  static Future<void> outcomeRecorded(String status, {required double amountBucket}) =>
      log('outcome_recorded', {'status': status, 'amount_bucket': amountBucket});
  static Future<void> paywallShown(String trigger) => log('paywall_shown', {'trigger': trigger});
  static Future<void> purchaseStarted(String productId) => log('purchase_started', {'product': productId});
  static Future<void> purchaseCompleted(String productId) => log('purchase', {'product': productId});
  static Future<void> quotaHit(String op) => log('quota_hit', {'op': op});
}
