import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permission helpers for camera capture.
///
/// Because the app declares the `CAMERA` permission in its Android manifest
/// (needed for `image_picker` camera capture on many devices), Android requires
/// it to be granted at runtime before launching the camera.
class MediaPermissions {
  /// Ensures camera access. Returns true if granted. Shows a small dialog with
  /// a shortcut to app settings when the user has permanently denied it.
  static Future<bool> ensureCamera(BuildContext context) async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Camera access needed'),
          content: const Text(
              'Allow camera access in Settings to scan bills and documents.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings')),
          ],
        ),
      );
      if (open == true) await openAppSettings();
    }
    return false;
  }

  /// Photo-library access is handled by the OS picker on Android 13+ and by
  /// the system photo picker on iOS, so this only prompts where the platform
  /// still requires an explicit runtime grant.
  static Future<bool> ensurePhotos(BuildContext context) async {
    var status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.photos.request();
    }
    if (status.isGranted || status.isLimited) return true;
    // On Android < 13 the plugin may report "denied" for READ_MEDIA_IMAGES yet
    // the picker still works via the storage permission — do not block.
    return !status.isPermanentlyDenied;
  }
}
