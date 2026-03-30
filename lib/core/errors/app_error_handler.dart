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
