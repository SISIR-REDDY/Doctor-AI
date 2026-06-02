import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/firebase_config.dart';
import 'firebase_bootstrap_service.dart';

/// Result of saving a patient photo locally (Firestore stores [fileName] only).
class PatientPhotoSaveResult {
  final String fileName;
  final String localPath;
  final String? remoteUrl;

  const PatientPhotoSaveResult({
    required this.fileName,
    required this.localPath,
    this.remoteUrl,
  });
}

/// Local storage service for audio files
/// Uses device storage instead of Firebase Storage (works with free plan)
class StorageService {
  static String? _cachedPatientPhotosDir;

  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  FirebaseStorage? get _storage =>
      _isFirebaseAvailable ? FirebaseStorage.instance : null;

  /// Warms the local photos directory cache so list avatars can resolve paths synchronously.
  Future<void> warmPatientPhotosCache() async {
    await _getPatientPhotosDirectory();
  }

  /// Resolves a patient photo path from Firestore filename, legacy path, or patient id.
  String? resolvePatientPhotoPathSync({
    required String photoUrl,
    required String photoFileName,
    required String patientId,
  }) {
    final dir = _cachedPatientPhotosDir;

    final fileName = photoFileName.trim();
    if (fileName.isNotEmpty && dir != null) {
      final byName = '$dir${Platform.pathSeparator}$fileName';
      if (_fileExistsSync(byName)) return byName;
    }

    final trimmed = photoUrl.trim();
    if (trimmed.isNotEmpty && _fileExistsSync(trimmed)) {
      return trimmed;
    }

    if (dir == null || patientId.trim().isEmpty) return null;

    for (final ext in const ['jpg', 'jpeg', 'png', 'webp']) {
      final candidate = '$dir${Platform.pathSeparator}patient_${patientId.trim()}.$ext';
      if (_fileExistsSync(candidate)) return candidate;
    }
    return null;
  }

  bool _fileExistsSync(String path) {
    if (path.isEmpty) return false;
    if (File(path).existsSync()) return true;
    final normalized = path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
    if (normalized != path && File(normalized).existsSync()) {
      return true;
    }
    return false;
  }

  Future<Directory> _getPatientPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/patient_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    _cachedPatientPhotosDir = photosDir.path;
    return photosDir;
  }

  /// Saves a compressed photo locally. Firestore should store [PatientPhotoSaveResult.fileName] only.
  Future<PatientPhotoSaveResult?> savePatientPhoto({
    required String sourcePath,
    required String patientId,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final photosDir = await _getPatientPhotosDirectory();
      const safeExt = 'jpg';
      final fileName = 'patient_${patientId.trim()}.$safeExt';
      final destinationPath = '${photosDir.path}${Platform.pathSeparator}$fileName';

      final destination = File(destinationPath);
      if (await destination.exists()) {
        await destination.delete();
      }
      await sourceFile.copy(destinationPath);

      String? remoteUrl;
      final storage = _storage;
      if (storage != null) {
        try {
          final ref = storage.ref().child('patient_photos/$fileName');
          await ref.putFile(
            destination,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          remoteUrl = await ref.getDownloadURL();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[StorageService] Firebase photo upload failed: $e');
          }
        }
      }

      return PatientPhotoSaveResult(
        fileName: fileName,
        localPath: destinationPath,
        remoteUrl: remoteUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to save patient photo: $e');
      }
      return null;
    }
  }

  Future<void> deletePatientPhoto(String photoPath) async {
    if (photoPath.isEmpty) return;
    try {
      if (_isRemoteUrl(photoPath)) {
        await _deleteRemoteFile(photoPath);
        return;
      }
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to delete patient photo: $e');
      }
    }
  }

  /// Get the local audio storage directory
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/consultations');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Save audio file to local storage
  /// Returns the local file path of the saved audio
  Future<String?> uploadAudioFile({
    required String filePath,
    required String doctorId,
    required String sessionId,
  }) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final storage = _storage;
      if (storage != null) {
        try {
          final ref = storage.ref().child('consultations/$doctorId/consultation_$sessionId.m4a');
          await ref.putFile(
            sourceFile,
            SettableMetadata(contentType: 'audio/m4a'),
          );
          return await ref.getDownloadURL();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[StorageService] Firebase audio upload failed: $e');
          }
        }
      }

      final audioDir = await _getAudioDirectory();
      final fileName = 'consultation_$sessionId.m4a';
      final destinationPath = '${audioDir.path}/$fileName';

      // Copy file to permanent storage
      await sourceFile.copy(destinationPath);

      return destinationPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to upload audio file: $e');
      }
      return null;
    }
  }

  /// Delete audio file from local storage
  Future<void> deleteAudioFile(String audioPath) async {
    if (audioPath.isEmpty) return;

    try {
      if (_isRemoteUrl(audioPath)) {
        await _deleteRemoteFile(audioPath);
        return;
      }
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to delete audio file at $audioPath: $e');
      }
    }
  }

  /// Get all stored audio files size (for storage management)
  Future<int> getStorageUsedBytes() async {
    try {
      final audioDir = await _getAudioDirectory();
      if (!await audioDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in audioDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to calculate storage used: $e');
      }
      return 0;
    }
  }

  /// Clear all stored audio files
  Future<void> clearAllAudio() async {
    try {
      final audioDir = await _getAudioDirectory();
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to clear all audio files: $e');
      }
    }
  }

  /// Returns MIME type + storage extension for a given local file path.
  static ({String mime, String ext}) _mimeFor(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return (mime: 'image/png', ext: 'png');
    if (lower.endsWith('.gif')) return (mime: 'image/gif', ext: 'gif');
    if (lower.endsWith('.webp')) return (mime: 'image/webp', ext: 'webp');
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return (mime: 'image/heic', ext: 'heic');
    }
    return (mime: 'image/jpeg', ext: 'jpg');
  }

  /// Uploads a single document page to Firebase Storage.
  /// Returns the download URL, or null if Firebase is unavailable or the
  /// file does not exist. Throws on any other error so the caller can
  /// distinguish "no Firebase" from "real upload failure".
  Future<String?> uploadDocumentImage({
    required String filePath,
    required String patientId,
    required String scanId,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      debugPrint('[StorageService] File not found: $filePath');
      return null;
    }

    final storage = _storage;
    if (storage == null) {
      debugPrint('[StorageService] Firebase Storage not available');
      return null;
    }

    final (:mime, :ext) = _mimeFor(filePath);
    final ref =
        storage.ref().child('document_scans/$patientId/$scanId.$ext');
    await ref.putFile(sourceFile, SettableMetadata(contentType: mime));
    return await ref.getDownloadURL();
  }

  /// Uploads all pages of a multi-page document scan in parallel.
  ///
  /// Returns a list of successfully uploaded URLs (same length as [filePaths]
  /// minus any that failed). Each page is stored at:
  ///   `document_scans/{patientId}/{recordId}_page_{i}.{ext}`
  ///
  /// Failures are logged individually; the method does NOT throw — it returns
  /// whatever URLs succeeded so the caller can save a partial record.
  Future<List<String>> uploadDocumentImages({
    required List<String> filePaths,
    required String patientId,
    required String recordId,
  }) async {
    final futures = <Future<String?>>[];

    for (int i = 0; i < filePaths.length; i++) {
      futures.add(
        uploadDocumentImage(
          filePath: filePaths[i],
          patientId: patientId,
          scanId: '${recordId}_page_$i',
        ).catchError((Object e) {
          debugPrint('[StorageService] Page $i upload failed: $e');
          return null;
        }),
      );
    }

    final results = await Future.wait(futures);
    return results.whereType<String>().where((u) => u.isNotEmpty).toList();
  }

  bool _isRemoteUrl(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  Future<void> _deleteRemoteFile(String url) async {
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.refFromURL(url).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Firebase delete failed: $e');
      }
    }
  }
}
