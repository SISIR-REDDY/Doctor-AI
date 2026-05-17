import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Result of saving a patient photo locally (Firestore stores [fileName] only).
class PatientPhotoSaveResult {
  final String fileName;
  final String localPath;

  const PatientPhotoSaveResult({
    required this.fileName,
    required this.localPath,
  });
}

/// Local storage service for audio files
/// Uses device storage instead of Firebase Storage (works with free plan)
class StorageService {
  static String? _cachedPatientPhotosDir;

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
      return PatientPhotoSaveResult(fileName: fileName, localPath: destinationPath);
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

      final audioDir = await _getAudioDirectory();
      final fileName = 'consultation_${sessionId}.m4a';
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
}
