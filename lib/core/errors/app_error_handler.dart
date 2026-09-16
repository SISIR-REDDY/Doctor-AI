import 'package:flutter/material.dart';

import 'app_exception.dart';

class AppErrorHandler {
  static void showSnackBar(BuildContext context, Object error) {
    final message = _toMessage(error);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static String _toMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    final raw = error.toString();
    return raw.replaceFirst('Exception: ', '').trim();
  }
}

/// Runs a user-initiated action and surfaces any failure as a snackbar.
///
/// For taps that write to Firestore or schedule notifications: without this a
/// thrown error is swallowed by the framework and the tap simply appears to
/// do nothing — the single most common cause of "buttons don't work" reviews.
Future<void> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) AppErrorHandler.showSnackBar(context, error);
  }
}
