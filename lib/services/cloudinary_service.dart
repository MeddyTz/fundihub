import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────────────────────
// CloudinaryService
//
// Uploads reel videos via unsigned multipart POST — no API secret required.
//
//   Cloud name   : da4vbrmuv
//   Upload preset: fundihub_reels  (must be "Unsigned" in Cloudinary dashboard)
//
// Security notes:
//   • Cloud name and preset are public identifiers — safe in client code.
//   • API Secret is NEVER used here. Deletion must be done via a
//     Cloud Function (call cloudinary.api.delete_resources from server side).
// ─────────────────────────────────────────────────────────────────────────────
class CloudinaryService {
  static const String _cloudName    = 'da4vbrmuv';
  static const String _uploadPreset = 'fundihub_reels';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload';

  static const int _maxBytes = 50 * 1024 * 1024; // 50 MB

  static const Set<String> _validExtensions = {'mp4', 'mov'};

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads [file] to Cloudinary.
  /// [onProgress] receives values 0.0 → 1.0.
  /// Throws [CloudinaryException] on any failure (never swallows errors).
  Future<CloudinaryUploadResult> uploadVideo({
    required File file,
    void Function(double progress)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    // ── Validate ────────────────────────────────────────────────────────────
    if (!await file.exists()) {
      throw CloudinaryException('Video file not found: ${file.path}');
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw CloudinaryException('Video file is empty.');
    }
    if (fileSize > _maxBytes) {
      final mb = (fileSize / 1024 / 1024).toStringAsFixed(1);
      throw CloudinaryException(
          'Video too large ($mb MB). Maximum is 50 MB.');
    }

    final rawExt = p.extension(file.path).toLowerCase().replaceAll('.', '');
    if (rawExt.isNotEmpty && !_validExtensions.contains(rawExt)) {
      throw CloudinaryException(
          'Unsupported format: .$rawExt  '
          'Supported: ${_validExtensions.join(', ')}');
    }
    final ext = rawExt.isEmpty ? 'mp4' : rawExt;

    dev.log(
      '[Cloudinary] upload start → '
      '${p.basename(file.path)} '
      '(${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      name: 'REEL',
    );

    // ── Build request ───────────────────────────────────────────────────────
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

    request.fields['upload_preset'] = _uploadPreset;
    request.fields['tags'] = 'fundihub,reel';
    // NOTE: eager/eager_async are signed-only parameters — do NOT add them.
    // Thumbnail is derived from publicId after upload (see below).

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'reel_${DateTime.now().millisecondsSinceEpoch}.$ext',
      ),
    );

    // ── Simulate progress ───────────────────────────────────────────────────
    // http.MultipartRequest doesn't expose byte-level progress.
    // We animate 0 → 0.95 with a timer; jump to 1.0 on success.
    onProgress?.call(0.0);
    double fake = 0.0;
    Timer? ticker;
    if (onProgress != null) {
      ticker = Timer.periodic(const Duration(milliseconds: 300), (_) {
        fake = fake + (0.95 - fake) * 0.10;
        onProgress(fake.clamp(0.0, 0.95));
      });
    }

    // ── Send ────────────────────────────────────────────────────────────────
    try {
      final streamed = await request.send().timeout(timeout);
      final body     = await streamed.stream.bytesToString();
      ticker?.cancel();

      dev.log('[Cloudinary] status=${streamed.statusCode}', name: 'REEL');

      if (streamed.statusCode != 200) {
        String msg = 'Upload failed (HTTP ${streamed.statusCode})';
        try {
          final err = (json.decode(body) as Map)['error'] as Map?;
          if (err?['message'] != null) msg = err!['message'].toString();
        } catch (_) {}
        dev.log('[Cloudinary] error body: $body', name: 'REEL');
        throw CloudinaryException(msg);
      }

      // ── Parse ─────────────────────────────────────────────────────────────
      final Map<String, dynamic> data;
      try {
        data = json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        throw CloudinaryException('Could not parse Cloudinary response: $e');
      }

      final secureUrl = (data['secure_url'] ?? '').toString();
      final publicId  = (data['public_id']  ?? '').toString();
      final duration  = (data['duration']   as num?)?.toDouble() ?? 0.0;
      final fmt       = (data['format']     ?? ext).toString();

      if (secureUrl.isEmpty) {
        throw CloudinaryException(
            'Cloudinary returned no URL. Body: $body');
      }

      // Thumbnail: Cloudinary generates this on-the-fly from the publicId.
      // No eager transform needed — works with unsigned uploads.
      final String thumbnailUrl = publicId.isNotEmpty
          ? 'https://res.cloudinary.com/$_cloudName/'
            'video/upload/w_400,h_300,c_pad,so_2.0,f_jpg/$publicId.jpg'
          : '';

      dev.log(
        '[Cloudinary] OK  publicId=$publicId  '
        'duration=${duration.toStringAsFixed(1)}s  '
        'thumb=${thumbnailUrl.isNotEmpty}',
        name: 'REEL',
      );

      onProgress?.call(1.0);

      return CloudinaryUploadResult(
        secureUrl:    secureUrl,
        thumbnailUrl: thumbnailUrl,
        publicId:     publicId,
        durationSecs: duration.round(),
        format:       fmt,
        bytes:        fileSize,
      );
    } on TimeoutException {
      ticker?.cancel();
      throw CloudinaryException(
          'Upload timed out. Check your connection and retry.');
    } on SocketException catch (e) {
      ticker?.cancel();
      throw CloudinaryException('No internet connection: ${e.message}');
    } on CloudinaryException {
      ticker?.cancel();
      rethrow;
    } catch (e) {
      ticker?.cancel();
      dev.log('[Cloudinary] unexpected: $e', name: 'REEL');
      throw CloudinaryException('Unexpected error during upload: $e');
    }
  }
  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD IMAGE  (profile pictures, portfolio photos)
  // Uses /auto/upload — Cloudinary detects image vs video automatically.
  // Max 5 MB. Returns secure_url to store in Firestore.
  // No API secret — unsigned preset only.
  // ─────────────────────────────────────────────────────────────────────────

  static const int _maxImageBytes = 5 * 1024 * 1024;  // 5 MB
  static const String _imageUploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  Future<CloudinaryUploadResult> uploadImage({
    required File file,
    String? folder,
    void Function(double progress)? onProgress,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!await file.exists()) {
      throw CloudinaryException('Image file not found: ${file.path}');
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw CloudinaryException('Image file is empty.');
    }
    if (fileSize > _maxImageBytes) {
      final mb = (fileSize / 1024 / 1024).toStringAsFixed(1);
      throw CloudinaryException('Image too large ($mb MB). Max 5 MB.');
    }

    final rawExt = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final ext    = rawExt.isEmpty ? 'jpg' : rawExt;

    const _allowedImg = {'jpg', 'jpeg', 'png', 'webp'};
    if (rawExt.isNotEmpty && !_allowedImg.contains(rawExt)) {
      throw CloudinaryException(
          'Unsupported image format: .$rawExt. Allowed: jpg, jpeg, png, webp.');
    }

    dev.log('[Cloudinary] uploadImage ${p.basename(file.path)} '
        '(${(fileSize / 1024).toStringAsFixed(0)} KB)', name: 'UPLOAD');

    final request = http.MultipartRequest('POST', Uri.parse(_imageUploadUrl));
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['tags']          = 'fundihub';
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    request.files.add(await http.MultipartFile.fromPath(
      'file', file.path,
      filename: 'img_${DateTime.now().millisecondsSinceEpoch}.$ext',
    ));

    onProgress?.call(0.0);
    double fake = 0.0;
    Timer? ticker;
    if (onProgress != null) {
      ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        fake = fake + (0.95 - fake) * 0.12;
        onProgress(fake.clamp(0.0, 0.95));
      });
    }

    try {
      final streamed = await request.send().timeout(timeout);
      final body     = await streamed.stream.bytesToString();
      ticker?.cancel();

      if (streamed.statusCode != 200) {
        String msg = 'Image upload failed (HTTP \${streamed.statusCode})';
        try {
          final err = (json.decode(body) as Map)['error'] as Map?;
          if (err?['message'] != null) msg = err!['message'].toString();
        } catch (_) {}
        throw CloudinaryException(msg);
      }

      final Map<String, dynamic> data;
      try {
        data = json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        throw CloudinaryException('Could not parse Cloudinary response: \$e');
      }

      final secureUrl = (data['secure_url'] ?? '').toString();
      final publicId  = (data['public_id']  ?? '').toString();
      if (secureUrl.isEmpty) {
        throw CloudinaryException('Cloudinary returned no URL.');
      }

      dev.log('[Cloudinary] image OK publicId=\$publicId', name: 'UPLOAD');
      onProgress?.call(1.0);

      return CloudinaryUploadResult(
        secureUrl:    secureUrl,
        thumbnailUrl: secureUrl,
        publicId:     publicId,
        durationSecs: 0,
        format:       ext,
        bytes:        fileSize,
      );
    } on TimeoutException {
      ticker?.cancel();
      throw CloudinaryException('Image upload timed out. Please retry.');
    } on SocketException catch (e) {
      ticker?.cancel();
      throw CloudinaryException('No internet connection: \${e.message}');
    } on CloudinaryException {
      ticker?.cancel();
      rethrow;
    } catch (e) {
      ticker?.cancel();
      throw CloudinaryException('Unexpected image upload error: \$e');
    }
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODEL
// ─────────────────────────────────────────────────────────────────────────────

class CloudinaryUploadResult {
  /// HTTPS URL of the uploaded video (use this as videoUrl in Firestore)
  final String secureUrl;
  /// HTTPS URL of the auto-generated thumbnail JPEG
  final String thumbnailUrl;
  /// Cloudinary public_id — store in storagePath for future server-side delete
  final String publicId;
  final int    durationSecs;
  final String format;
  final int    bytes;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.thumbnailUrl,
    required this.publicId,
    required this.durationSecs,
    required this.format,
    required this.bytes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EXCEPTION
// ─────────────────────────────────────────────────────────────────────────────

class CloudinaryException implements Exception {
  final String message;
  const CloudinaryException(this.message);
  @override
  String toString() => message;
}
