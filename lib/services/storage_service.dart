import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxImageBytes = 5   * 1024 * 1024;  //   5 MB
  static const int maxVoiceBytes = 10  * 1024 * 1024;  //  10 MB
  static const int maxVideoBytes = 200 * 1024 * 1024;  // 200 MB

  // ─────────────────────────────────────────────────────────────────────────
  // REEL VIDEO UPLOAD
  // Flow: validate → build ref → create UploadTask → await TaskSnapshot
  //       → call getDownloadURL() on the snapshot's ref (guaranteed uploaded)
  // ─────────────────────────────────────────────────────────────────────────
  Future<ReelUploadResult> uploadReelVideo({
    required String   userId,
    required File     videoFile,
    void Function(double progress)? onProgress,
    void Function(UploadTask task)? onTaskCreated,
  }) async {
    // 1. Verify the local file exists and is readable
    if (!await videoFile.exists()) {
      throw Exception('Video file not found: ${videoFile.path}');
    }
    final fileSize = await videoFile.length();
    if (fileSize == 0) {
      throw Exception('Video file is empty (0 bytes).');
    }
    if (fileSize > maxVideoBytes) {
      throw Exception(
          'Video is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Max 200 MB.');
    }

    // 2. Build a unique, safe storage path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext       = _ext(videoFile.path, fallback: 'mp4');
    final filename  = '${timestamp}_reel.$ext';
    final storagePath = 'reels/$userId/$filename';

    dev.log('[StorageService] Starting upload → $storagePath '
        '(${(fileSize / 1024).toStringAsFixed(0)} KB)', name: 'REEL');

    // 3. Create the storage reference
    final ref = _storage.ref(storagePath);

    // 4. Create the UploadTask
    final task = ref.putFile(
      videoFile,
      SettableMetadata(
        contentType: 'video/$ext',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    // 5. Give caller the task handle immediately (for cancel)
    onTaskCreated?.call(task);

    // 6. Listen to progress events
    final progressSub = task.snapshotEvents.listen(
      (snapshot) {
        if (snapshot.totalBytes > 0 && onProgress != null) {
          final pct = snapshot.bytesTransferred / snapshot.totalBytes;
          dev.log('[StorageService] Upload progress: ${(pct * 100).toInt()}%',
              name: 'REEL');
          onProgress(pct.clamp(0.0, 1.0));
        }
      },
      onError: (e) {
        dev.log('[StorageService] Progress listener error: $e', name: 'REEL');
      },
    );

    // 7. Await the TaskSnapshot — this is the canonical "upload done" signal
    TaskSnapshot snapshot;
    try {
      snapshot = await task;
    } on FirebaseException catch (e) {
      await progressSub.cancel();
      dev.log('[StorageService] FirebaseException during upload: '
          'code=${e.code} msg=${e.message}', name: 'REEL');
      rethrow; // let caller handle with real message
    } finally {
      await progressSub.cancel();
    }

    dev.log('[StorageService] Upload complete. State: ${snapshot.state}  '
        'bytes: ${snapshot.bytesTransferred}', name: 'REEL');

    // 8. Verify the upload actually succeeded
    if (snapshot.state != TaskState.success) {
      throw Exception(
          'Upload did not complete successfully (state: ${snapshot.state}).');
    }

    // 9. Get the download URL from the snapshot's own reference
    //    This is the only safe way — avoids any path mismatch
    final downloadUrl = await snapshot.ref.getDownloadURL();

    dev.log('[StorageService] Download URL obtained: $downloadUrl',
        name: 'REEL');

    return ReelUploadResult(
      videoUrl:    downloadUrl,
      storagePath: storagePath,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE IMAGE
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> uploadProfileImage({
    required String userId,
    required File   file,
  }) async {
    await _assertFile(file, maxImageBytes, 'Profile image');
    final ext = _ext(file.path, fallback: 'jpg');
    final ref = _storage.ref('profiles/$userId/avatar.$ext');
    final snap = await ref.putFile(
        file, SettableMetadata(contentType: 'image/$ext'));
    return snap.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PORTFOLIO IMAGE
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> uploadPortfolioImage({
    required String fundiId,
    required File   file,
  }) async {
    await _assertFile(file, maxImageBytes, 'Portfolio image');
    final ext  = _ext(file.path, fallback: 'jpg');
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final ref  = _storage.ref('users/$fundiId/portfolio/${ts}_photo.$ext');
    final snap = await ref.putFile(
        file, SettableMetadata(contentType: 'image/$ext'));
    return snap.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHAT IMAGE
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> uploadChatImage({
    required String chatId,
    required File   file,
  }) async {
    await _assertFile(file, maxImageBytes, 'Chat image');
    final ext  = _ext(file.path, fallback: 'jpg');
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final ref  = _storage.ref('chats/$chatId/${ts}_img.$ext');
    final snap = await ref.putFile(
        file, SettableMetadata(contentType: 'image/$ext'));
    return snap.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOICE NOTE
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> uploadVoiceNote({
    required String chatId,
    required File   file,
  }) async {
    await _assertFile(file, maxVoiceBytes, 'Voice note');
    final ext  = _ext(file.path, fallback: 'aac');
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final ref  = _storage.ref('chats/$chatId/${ts}_voice.$ext');
    final snap = await ref.putFile(
        file, SettableMetadata(contentType: 'audio/$ext'));
    return snap.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> deleteByUrl(String downloadUrl) async {
    if (downloadUrl.isEmpty) return;
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (e) {
      dev.log('[StorageService] deleteByUrl failed: $e', name: 'STORAGE');
    }
  }

  Future<void> deleteByPath(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref(storagePath).delete();
    } catch (e) {
      dev.log('[StorageService] deleteByPath failed: $e', name: 'STORAGE');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _assertFile(File file, int maxBytes, String label) async {
    if (!await file.exists()) {
      throw Exception('$label file not found.');
    }
    final size = await file.length();
    if (size == 0)         throw Exception('$label file is empty.');
    if (size > maxBytes)   throw Exception(
        '$label too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB).');
  }

  String _ext(String filePath, {required String fallback}) {
    final raw = p.extension(filePath).replaceAll('.', '').toLowerCase().trim();
    // Only allow safe video/image extensions
    const allowed = {
      'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp',
      'jpg', 'jpeg', 'png', 'webp', 'heic',
      'aac', 'm4a', 'mp3',
    };
    return allowed.contains(raw) ? raw : fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result
// ─────────────────────────────────────────────────────────────────────────────
class ReelUploadResult {
  final String videoUrl;
  final String storagePath;

  const ReelUploadResult({
    required this.videoUrl,
    required this.storagePath,
  });
}
