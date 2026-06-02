import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'firebase/firestore_service.dart';
import 'notification_service.dart';

/// Background FCM handler. Must be a top-level function annotated with
/// `vm:entry-point` so it survives tree-shaking and can run in its own isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Background isolate init best-effort; the OS still shows `notification`
    // payloads on Android regardless.
  }
}

/// Firebase Cloud Messaging: permission, device-token sync to Firestore, and
/// surfacing foreground pushes through the local-notification channel.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FirestoreService _db = FirestoreService();

  String? _uid;
  String? _token;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Show a notification while the app is in the foreground.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          NotificationService.instance.showNow(
            title: n.title ?? 'Clinix AI',
            body: n.body ?? '',
          );
        }
      });

      // Keep the stored token fresh.
      _fm.onTokenRefresh.listen((token) {
        _token = token;
        _persistToken();
      });

      _token = await _fm.getToken();
      _ready = true;
      _persistToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotificationService] init failed: $e');
    }
  }

  /// Associates the current device token with [uid]; call when a user signs in.
  Future<void> registerForUser(String uid) async {
    _uid = uid;
    try {
      _token ??= await _fm.getToken();
    } catch (_) {}
    await _persistToken();
  }

  Future<void> _persistToken() async {
    final uid = _uid;
    final token = _token;
    if (uid == null || uid.isEmpty || token == null || token.isEmpty) return;
    try {
      await _db.saveDeviceToken(userId: uid, token: token);
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotificationService] token save: $e');
    }
  }
}
