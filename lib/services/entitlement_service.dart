import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase/firebase_bootstrap_service.dart';

/// Source of truth for "is this user Pro?".
///
/// Resolution order (any true → Pro):
///   1. RevenueCat entitlement `pro` active on this device (instant after purchase).
///   2. Firestore `users/{uid}/private/entitlement.plan == 'pro'` (written by
///      the RevenueCat webhook — survives reinstalls and is what the backend
///      uses for quotas).
///   3. Remote Config `everyone_pro` (beta switch; must also be set in
///      `app_runtime/config.everyonePro` for the backend to agree).
///   4. Debug builds are always Pro so every feature can be tested.
///
/// RevenueCat keys are supplied at build time:
///   --dart-define=RC_ANDROID_KEY=goog_xxx --dart-define=RC_IOS_KEY=appl_xxx
/// or via Remote Config `rc_android_key` / `rc_ios_key`. Without a key the
/// service degrades gracefully (free tier, paywall shows "coming soon").
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  static const String entitlementId = 'pro';
  static const String _envAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');
  static const String _envIosKey = String.fromEnvironment('RC_IOS_KEY');

  bool _rcConfigured = false;
  bool _rcPro = false;
  bool _firestorePro = false;
  bool _remotePro = false;
  DateTime? _expiresAt;
  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _entSub;
  Offerings? _offerings;

  bool get isConfigured => _rcConfigured;
  Offerings? get offerings => _offerings;
  DateTime? get expiresAt => _expiresAt;

  bool get isPro {
    if (kDebugMode && _debugForcePro) return true;
    return _rcPro || _firestorePro || _remotePro;
  }

  /// Debug-only override so the paywall itself can be tested on a debug build.
  static bool _debugForcePro = true;
  static void setDebugForcePro(bool value) {
    _debugForcePro = value;
    instance.notifyListeners();
  }

  String get planLabel => isPro ? 'Pro' : 'Free';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _readRemoteFlags();
    final key = _apiKey();
    if (key.isEmpty) {
      debugPrint('[Entitlements] RevenueCat key not set — purchases disabled.');
      return;
    }
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(key));
      _rcConfigured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('[Entitlements] RevenueCat init failed: $e');
    }
  }

  /// Binds purchases and entitlement streams to the signed-in Firebase user.
  Future<void> attachUser(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _watchFirestore(uid);
    if (_rcConfigured) {
      try {
        final result = await Purchases.logIn(uid);
        _onCustomerInfo(result.customerInfo);
      } catch (e) {
        debugPrint('[Entitlements] logIn failed: $e');
      }
    }
  }

  Future<void> detachUser() async {
    _uid = null;
    await _entSub?.cancel();
    _entSub = null;
    _firestorePro = false;
    _rcPro = false;
    _expiresAt = null;
    if (_rcConfigured) {
      try {
        await Purchases.logOut();
      } catch (_) {}
    }
    notifyListeners();
  }

  // ── Purchases ─────────────────────────────────────────────────────────────

  Future<Offerings?> loadOfferings() async {
    if (!_rcConfigured) return null;
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
      return _offerings;
    } catch (e) {
      debugPrint('[Entitlements] getOfferings failed: $e');
      return null;
    }
  }

  /// Returns true when the purchase completed and Pro is now active.
  Future<bool> purchase(Package package) async {
    if (!_rcConfigured) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfo(result.customerInfo);
      return _rcPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  Future<bool> restore() async {
    if (!_rcConfigured) return false;
    final info = await Purchases.restorePurchases();
    _onCustomerInfo(info);
    return _rcPro;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  String _apiKey() {
    final rc = _remoteConfig();
    if (Platform.isIOS || Platform.isMacOS) {
      return _envIosKey.isNotEmpty ? _envIosKey : (rc?.getString('rc_ios_key') ?? '');
    }
    return _envAndroidKey.isNotEmpty ? _envAndroidKey : (rc?.getString('rc_android_key') ?? '');
  }

  FirebaseRemoteConfig? _remoteConfig() {
    if (!FirebaseBootstrapService.isInitialized) return null;
    try {
      return FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }

  void _readRemoteFlags() {
    try {
      _remotePro = _remoteConfig()?.getBool('everyone_pro') ?? false;
    } catch (_) {
      _remotePro = false;
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    final ent = info.entitlements.active[entitlementId];
    final wasPro = isPro;
    _rcPro = ent != null;
    if (ent?.expirationDate != null) {
      _expiresAt = DateTime.tryParse(ent!.expirationDate!);
    }
    if (wasPro != isPro) notifyListeners();
  }

  void _watchFirestore(String uid) {
    _entSub?.cancel();
    if (!FirebaseBootstrapService.isInitialized) return;
    _entSub = FirebaseFirestore.instance
        .doc('users/$uid/private/entitlement')
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final wasPro = isPro;
      if (data == null) {
        _firestorePro = false;
      } else {
        final expires = data['expiresAt'];
        final notExpired = expires is! Timestamp || expires.toDate().isAfter(DateTime.now());
        _firestorePro = data['plan'] == 'pro' && notExpired;
        if (expires is Timestamp) _expiresAt = expires.toDate();
      }
      if (wasPro != isPro) notifyListeners();
    }, onError: (e) => debugPrint('[Entitlements] watch failed: $e'));
  }
}
