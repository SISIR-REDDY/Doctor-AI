import 'package:flutter/material.dart';

class LogoutUtils {
  static Future<void> performSafeLogout({
    required BuildContext context,
    required Future<void> Function() onLogout,
    required void Function(Object error) onError,
    required VoidCallback onSuccess,
  }) async {
    try {
      await onLogout();
      onSuccess();
    } catch (error) {
      onError(error);
    }
  }
}
