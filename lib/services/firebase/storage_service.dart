import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/firebase_config.dart';
import 'firebase_bootstrap_service.dart';

/// Document storage: durable on-device copies first, cloud backup second.
///
/// Every scanned page (bill, EOB, denial letter, policy, record — image or
/// PDF) is copied into the app-documents folder before anything else, so a
/// failed upload can never lose the user's document. Cloud paths are always
/// `document_scans/{uid}/…`, which is what the Storage rules and the Cloud
/// Functions ownership check expect.
class StorageService {
  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  FirebaseStorage? get _storage =>
      _isFirebaseAvailable ? FirebaseStorage.instance : null;

  // ── MIME helpers ───────────────────────────────────────────────────────────

  static ({String mime, String ext}) mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return (mime: 'image/png', ext: 'png');
    if (lower.endsWith('.webp')) return (mime: 'image/webp', ext: 'webp');
    if (lower.endsWith('.heic')) return (mime: 'image/heic', ext: 'heic');
    if (lower.endsWith('.heif')) return (mime: 'image/heif', ext: 'heif');
    if (lower.endsWith('.pdf')) return (mime: 'application/pdf', ext: 'pdf');
    return (mime: 'image/jpeg', ext: 'jpg');
  }

  static bool isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  // ── Cloud upload ───────────────────────────────────────────────────────────

  /// Uploads a single page. Returns the download URL, or null if Firebase is
  /// unavailable or the file does not exist. Throws on real upload failures.
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
    if (storage == null) return null;

    final (:mime, :ext) = mimeFor(filePath);
    final ref = storage.ref().child('document_scans/$patientId/$scanId.$ext');
    await ref.putFile(sourceFile, SettableMetadata(contentType: mime));
    return await ref.getDownloadURL();
  }

  /// Uploads all pages in parallel; returns the URLs that succeeded (never
  /// throws, so callers can save a partial record and retry later).
  Future<List<String>> uploadDocumentImages({
    required List<String> filePaths,
    required String patientId,
    required String recordId,
  }) async {
    final futures = <Future<String?>>[
      for (int i = 0; i < filePaths.length; i++)
        uploadDocumentImage(
          filePath: filePaths[i],
          patientId: patientId,
          scanId: '${recordId}_page_$i',
        ).catchError((Object e) {
          debugPrint('[StorageService] Page $i upload failed: $e');
          return null;
        }),
    ];
    final results = await Future.wait(futures);
    return results.whereType<String>().where((u) => u.isNotEmpty).toList();
  }

  // ── Durable local storage ──────────────────────────────────────────────────

  Future<Directory> _recordImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/record_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies each picked page into persistent app storage and returns the
  /// durable paths (same order; failed copies dropped).
  Future<List<String>> persistDocumentImages({
    required List<String> filePaths,
    required String recordId,
  }) async {
    final dir = await _recordImagesDirectory();
    final out = <String>[];
    for (int i = 0; i < filePaths.length; i++) {
      try {
        final src = File(filePaths[i]);
        if (!await src.exists()) continue;
        final (:mime, :ext) = mimeFor(filePaths[i]);
        final dest = '${dir.path}${Platform.pathSeparator}${recordId}_page_$i.$ext';
        await src.copy(dest);
        out.add(dest);
      } catch (e) {
        if (kDebugMode) debugPrint('[StorageService] persist page $i failed: $e');
      }
    }
    return out;
  }

  /// Persists locally AND uploads; the local copies always outlive the
  /// session, the remote list may be shorter if offline (retry later).
  Future<({List<String> localPaths, List<String> remoteUrls})>
      saveDocumentImages({
    required List<String> filePaths,
    required String patientId,
    required String recordId,
  }) async {
    final localPaths = await persistDocumentImages(
      filePaths: filePaths,
      recordId: recordId,
    );
    final sources = localPaths.isNotEmpty ? localPaths : filePaths;
    final remoteUrls = await uploadDocumentImages(
      filePaths: sources,
      patientId: patientId,
      recordId: recordId,
    );
    return (localPaths: localPaths, remoteUrls: remoteUrls);
  }

  /// Re-attempts cloud upload for pages that live only locally.
  Future<List<String>> retryUpload({
    required List<String> localPaths,
    required String patientId,
    required String recordId,
  }) =>
      uploadDocumentImages(
        filePaths: localPaths,
        patientId: patientId,
        recordId: recordId,
      );

  /// Deletes a remote file by download URL; never throws.
  Future<void> deleteRemoteFile(String url) async {
    final storage = _storage;
    if (storage == null || !url.startsWith('http')) return;
    try {
      await storage.refFromURL(url).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[StorageService] delete failed: $e');
    }
  }

  /// Deletes durable local copies; never throws.
  Future<void> deleteLocalFiles(Iterable<String> paths) async {
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
