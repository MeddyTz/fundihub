import 'dart:async';
import 'dart:math' as math;
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/comment_model.dart';
import '../models/reel_model.dart';
import '../services/cloudinary_service.dart';
import '../services/reel_service.dart';
// StorageService import kept so the ChangeNotifierProxyProvider2 in
// main.dart compiles without change. It is NOT used for uploads.
import '../services/storage_service.dart';

enum ReelUploadState {
  idle,
  picking,
  preparing,
  uploading,
  saving,
  done,
  error,
}

class ReelProvider extends ChangeNotifier {
  final ReelService       _reelService;
  // ignore: unused_field  (kept for main.dart provider signature)
  final StorageService    _storageService;
  final CloudinaryService _cloudinary = CloudinaryService();

  ReelProvider({
    required ReelService    reelService,
    required StorageService storageService,
  })  : _reelService    = reelService,
        _storageService = storageService;

  // ── Feed ──────────────────────────────────────────────────────────────────
  List<ReelModel> _approvedReels      = [];
  List<ReelModel> _approvedAdminReels = [];  // admin: no isActive filter

  // ── Viewed-reel tracking for personalised feed order ─────────────────
  final Set<String> _viewedReelIds = {};
  bool              _viewedLoaded  = false;
  List<ReelModel> _fundiReels         = [];
  List<ReelModel> _pendingReels       = [];
  List<ReelModel> _rejectedReels      = [];
  List<ReelModel> _allAdminReels      = [];
  List<ReelModel> _deletedReels       = [];  // admin Deleted tab
  bool _hasMore     = true;
  bool _loadingMore = false;

  StreamSubscription<List<ReelModel>>? _approvedSub;
  StreamSubscription<List<ReelModel>>? _approvedAdminSub;
  StreamSubscription<List<ReelModel>>? _fundiSub;
  StreamSubscription<List<ReelModel>>? _pendingSub;
  StreamSubscription<List<ReelModel>>? _rejectedSub;
  StreamSubscription<List<ReelModel>>? _allAdminSub;
  StreamSubscription<List<ReelModel>>? _deletedSub;

  List<ReelModel> get approvedReels      => List.unmodifiable(_approvedReels);
  List<ReelModel> get approvedAdminReels => List.unmodifiable(_approvedAdminReels);
  List<ReelModel> get fundiReels         => List.unmodifiable(_fundiReels);
  List<ReelModel> get pendingReels       => List.unmodifiable(_pendingReels);
  List<ReelModel> get rejectedReels      => List.unmodifiable(_rejectedReels);
  List<ReelModel> get allAdminReels      => List.unmodifiable(_allAdminReels);
  List<ReelModel> get deletedReels       => List.unmodifiable(_deletedReels);
  bool get hasMore     => _hasMore;
  bool get loadingMore => _loadingMore;

  // ── Reels-tab visibility flag ─────────────────────────────────────────────
  bool _reelsTabActive = false;
  bool get reelsTabActive => _reelsTabActive;

  void setReelsTabActive(bool active) {
    if (_reelsTabActive == active) return;
    _reelsTabActive = active;
    notifyListeners();
  }

  // ── Like / save sets ──────────────────────────────────────────────────────
  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  bool isLiked(String id) => _likedIds.contains(id);
  bool isSaved(String id) => _savedIds.contains(id);

  // ── Upload state ──────────────────────────────────────────────────────────
  ReelUploadState _uploadState    = ReelUploadState.idle;
  double          _uploadProgress = 0.0;
  String?         _uploadError;
  File?           _pickedVideoFile;
  Uint8List?      _thumbnailBytes;
  Duration?       _videoDuration;
  bool            _cancelled = false;

  ReelUploadState get uploadState     => _uploadState;
  double          get uploadProgress  => _uploadProgress;
  String?         get uploadError     => _uploadError;
  File?           get pickedVideoFile => _pickedVideoFile;
  Uint8List?      get thumbnailBytes  => _thumbnailBytes;
  Duration?       get videoDuration   => _videoDuration;

  bool get isUploading =>
      _uploadState == ReelUploadState.uploading ||
      _uploadState == ReelUploadState.saving    ||
      _uploadState == ReelUploadState.preparing;

  // ── Subscriptions ─────────────────────────────────────────────────────────

  // ── Personalised feed ordering ────────────────────────────────────────────

  /// Fetch the user's viewed-reel IDs from Firestore once per session,
  /// then re-sort the feed so unviewed reels appear first.
  /// Safe to call multiple times — runs only on first call per session.
  Future<void> loadViewedReels(String userId) async {
    if (_viewedLoaded || userId.isEmpty) return;
    _viewedLoaded = true;
    final ids = await _reelService.fetchViewedReelIds(userId);
    _viewedReelIds.addAll(ids);
    if (_approvedReels.isNotEmpty) {
      _approvedReels = _prioritisedShuffle(_approvedReels);
      notifyListeners();
    }
  }

  /// Shuffle [src] with unseen reels first, then seen ones.
  /// Both groups are independently shuffled for variety on each open.
  List<ReelModel> _prioritisedShuffle(List<ReelModel> src) {
    final rng    = math.Random();
    final unseen = src.where((r) => !_viewedReelIds.contains(r.reelId)).toList()
        ..shuffle(rng);
    final seen   = src.where((r) =>  _viewedReelIds.contains(r.reelId)).toList()
        ..shuffle(rng);
    // If all reels have been seen, merge and shuffle freely so the feed
    // never gets stuck showing the same order.
    if (unseen.isEmpty) return [...seen]..shuffle(rng);
    return [...unseen, ...seen];
  }

  void subscribeApprovedReels() {
    _approvedSub?.cancel();
    _approvedSub = _reelService.approvedReelsStream().listen(
      (reels) {
        // Apply personalised shuffle — unviewed first, then seen.
        _approvedReels = _prioritisedShuffle(reels);
        _hasMore = reels.length >= 10;
        notifyListeners();
      },
      onError: (e) =>
          dev.log('[ReelProvider] approvedReels error: $e', name: 'REEL'),
    );
  }

  void subscribeApprovedAdminReels() {
    _approvedAdminSub?.cancel();
    _approvedAdminSub = _reelService.approvedAdminStream().listen(
      (reels) { _approvedAdminReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] approvedAdmin error: $e', name: 'REEL'),
    );
  }

  void subscribeFundiReels(String fundiId) {
    _fundiSub?.cancel();
    _fundiSub = _reelService.fundiReelsStream(fundiId).listen(
      (reels) { _fundiReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] fundiReels error: $e', name: 'REEL'),
    );
  }

  void subscribePendingReels() {
    _pendingSub?.cancel();
    _pendingSub = _reelService.pendingReelsStream().listen(
      (reels) { _pendingReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] pendingReels error: $e', name: 'REEL'),
    );
  }

  void subscribeRejectedReels() {
    _rejectedSub?.cancel();
    _rejectedSub = _reelService.rejectedReelsStream().listen(
      (reels) { _rejectedReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] rejectedReels error: $e', name: 'REEL'),
    );
  }

  void subscribeAllAdminReels() {
    _allAdminSub?.cancel();
    _allAdminSub = _reelService.allReelsAdminStream().listen(
      (reels) { _allAdminReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] allAdminReels error: $e', name: 'REEL'),
    );
  }

  void subscribeDeletedReels() {
    _deletedSub?.cancel();
    _deletedSub = _reelService.deletedReelsStream().listen(
      (reels) { _deletedReels = reels; notifyListeners(); },
      onError: (e) =>
          dev.log('[ReelProvider] deletedReels error: $e', name: 'REEL'),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Future<void> loadMoreReels() async {
    if (_loadingMore || !_hasMore || _approvedReels.isEmpty) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final lastSnap =
          await _reelService.getReelSnapshot(_approvedReels.last.reelId);
      if (lastSnap == null) {
        _hasMore = false;
      } else {
        final more = await _reelService.fetchNextPage(lastDoc: lastSnap);
        if (more.isEmpty) {
          _hasMore = false;
        } else {
          _approvedReels = [..._approvedReels, ...more];
        }
      }
    } catch (e) {
      dev.log('[ReelProvider] loadMoreReels error: $e', name: 'REEL');
      _hasMore = false;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  // ── Pick video ────────────────────────────────────────────────────────────

  Future<bool> pickVideo() async {
    _set(ReelUploadState.picking);
    _uploadError = null;

    try {
      final xfile = await ImagePicker().pickVideo(
        source:      ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (xfile == null) {
        _set(ReelUploadState.idle);
        return false;
      }

      final file = File(xfile.path);
      if (!await file.exists()) {
        _uploadError = 'Selected video file could not be read.';
        _set(ReelUploadState.error);
        return false;
      }
      final fileSize = await file.length();
      if (fileSize == 0) {
        _uploadError = 'Selected video file is empty.';
        _set(ReelUploadState.error);
        return false;
      }

      _pickedVideoFile = file;
      _thumbnailBytes  = null;

      dev.log(
        '[ReelProvider] picked video: ${xfile.path} '
        '(${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
        name: 'REEL',
      );

      // Read duration — non-fatal
      _set(ReelUploadState.preparing);
      try {
        final ctrl = VideoPlayerController.file(file);
        await ctrl.initialize().timeout(const Duration(seconds: 8));
        _videoDuration = ctrl.value.duration;
        dev.log('[ReelProvider] duration: $_videoDuration', name: 'REEL');
        await ctrl.dispose();
      } catch (e) {
        dev.log('[ReelProvider] duration read failed (non-fatal): $e',
            name: 'REEL');
        _videoDuration = null;
      }

      // Duration: max 60 seconds
      if (_videoDuration != null && _videoDuration!.inSeconds > 60) {
        _uploadError =
            'Video too long (${_videoDuration!.inSeconds}s). Maximum is 60 seconds.';
        _pickedVideoFile = null;
        _set(ReelUploadState.error);
        return false;
      }

      // Size: max 50 MB
      if (fileSize > 50 * 1024 * 1024) {
        final mb = (fileSize / 1024 / 1024).toStringAsFixed(1);
        _uploadError = 'Video too large ($mb MB). Maximum is 50 MB.';
        _pickedVideoFile = null;
        _set(ReelUploadState.error);
        return false;
      }

      _set(ReelUploadState.idle);
      return true;
    } catch (e) {
      dev.log('[ReelProvider] pickVideo error: $e', name: 'REEL');
      _uploadError = 'Could not open video: ${_clean(e)}';
      _set(ReelUploadState.error);
      return false;
    }
  }

  void clearPickedVideo() {
    _pickedVideoFile = null;
    _thumbnailBytes  = null;
    _videoDuration   = null;
    _uploadError     = null;
    _uploadProgress  = 0.0;
    _set(ReelUploadState.idle);
  }

  Future<void> cancelUpload() async {
    dev.log('[ReelProvider] cancelUpload', name: 'REEL');
    _cancelled      = true;
    _uploadError    = 'Upload cancelled.';
    _uploadProgress = 0.0;
    _set(ReelUploadState.error);
  }

  // ── CLOUDINARY UPLOAD ─────────────────────────────────────────────────────

  Future<String?> uploadReelViaCloudinary({
    required String fundiId,
    required String fundiName,
    required String fundiProfileImage,
    required String category,
    required String caption,
    required String location,
    required double rating,
    required int    jobsDone,
  }) async {
    if (_pickedVideoFile == null) {
      _uploadError = 'No video selected.';
      _set(ReelUploadState.error);
      return null;
    }
    if (!await _pickedVideoFile!.exists()) {
      _uploadError = 'Video file is no longer available. Please pick it again.';
      _set(ReelUploadState.error);
      return null;
    }

    _cancelled   = false;
    _uploadError = null;

    try {
      _set(ReelUploadState.uploading, progress: 0.0);

      final result = await _cloudinary.uploadVideo(
        file: _pickedVideoFile!,
        onProgress: (p) {
          if (_cancelled) return;
          _uploadProgress = p;
          notifyListeners();
        },
        timeout: const Duration(minutes: 10),
      );

      if (_cancelled) return null;

      _set(ReelUploadState.saving, progress: 1.0);

      final String reelId;
      try {
        reelId = await _reelService.createReelDocument(
          fundiId:           fundiId,
          fundiName:         fundiName,
          fundiProfileImage: fundiProfileImage,
          category:          category,
          caption:           caption,
          videoUrl:          result.secureUrl,
          thumbnailUrl:      result.thumbnailUrl,
          storagePath:       result.publicId,
          thumbnailPath:     '',
          location:          location,
          rating:            rating,
          jobsDone:          jobsDone,
          durationSeconds:
              _videoDuration?.inSeconds ?? result.durationSecs,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
              'Firestore save timed out. Check your connection.'),
        );
      } on TimeoutException catch (e) {
        _uploadError = e.message ?? 'Saving timed out. Please retry.';
        _set(ReelUploadState.error);
        return null;
      } on FirebaseException catch (e) {
        _uploadError = _friendlyFirebaseError(e);
        _set(ReelUploadState.error);
        return null;
      }

      dev.log('[ReelProvider] reel doc created: $reelId', name: 'REEL');
      _set(ReelUploadState.done, progress: 1.0);
      return reelId;
    } catch (e) {
      dev.log('[ReelProvider] unexpected error: $e', name: 'REEL');
      _uploadError = _cancelled ? 'Upload cancelled.' : _clean(e);
      _set(ReelUploadState.error);
      return null;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void resetUpload() {
    _cancelled        = false;
    _pickedVideoFile  = null;
    _thumbnailBytes   = null;
    _videoDuration    = null;
    _uploadError      = null;
    _uploadProgress   = 0.0;
    _set(ReelUploadState.idle, silent: true);
  }

  // ── Feed interactions ─────────────────────────────────────────────────────

  Future<void> toggleLike(String reelId) async {
    final was = _likedIds.contains(reelId);
    was ? _likedIds.remove(reelId) : _likedIds.add(reelId);
    notifyListeners();
    try {
      await _reelService.toggleLike(reelId, liked: !was);
    } catch (_) {
      was ? _likedIds.add(reelId) : _likedIds.remove(reelId);
      notifyListeners();
    }
  }

  Future<void> toggleSave(String reelId) async {
    final was = _savedIds.contains(reelId);
    was ? _savedIds.remove(reelId) : _savedIds.add(reelId);
    notifyListeners();
    try {
      await _reelService.toggleSave(reelId, saved: !was);
    } catch (_) {
      was ? _savedIds.add(reelId) : _savedIds.remove(reelId);
      notifyListeners();
    }
  }

  /// Saves/unsaves reel and also writes to users/{uid}/savedReels subcollection.
  Future<void> toggleSaveWithStorage(
      String reelId, String userId, bool save) async {
    final was = _savedIds.contains(reelId);
    save ? _savedIds.add(reelId) : _savedIds.remove(reelId);
    notifyListeners();
    try {
      await _reelService.saveReel(
          userId: userId, reelId: reelId, saved: save);
    } catch (_) {
      was ? _savedIds.add(reelId) : _savedIds.remove(reelId);
      notifyListeners();
    }
  }

  Future<void> incrementView(String reelId) async {
    _viewedReelIds.add(reelId);  // mark locally so re-order is instant
    try { await _reelService.incrementView(reelId); } catch (_) {}
  }

  /// Persist viewed status to Firestore (called once per reel per session).
  Future<void> markReelViewedRemote(String userId, String reelId) async {
    _viewedReelIds.add(reelId);
    await _reelService.markReelViewed(userId, reelId);
  }

  Future<void> reportReel({
    required String reelId,
    required String reporterId,
    required String reason,
  }) async {
    await _reelService.reportReel(
        reelId: reelId, reporterId: reporterId, reason: reason);
  }

  Future<void> deleteReel({
    required String reelId,
    required String storagePath,
    required String thumbnailPath,
  }) async {
    await _reelService.deleteReel(
        reelId: reelId,
        storagePath: storagePath,
        thumbnailPath: thumbnailPath);
    _removeFromAllLocalLists(reelId);
    notifyListeners();
  }

  /// Fundi soft-delete: sets isDeleted=true, isActive=false.
  /// Removes from all local feed lists instantly.
  Future<void> softDeleteReel(String reelId, String userId) async {
    await _reelService.softDeleteReel(reelId, userId);
    _removeFromAllLocalLists(reelId);
    notifyListeners();
  }

  /// Admin hard-delete: calls Cloud Function to wipe Cloudinary + Firestore.
  /// Returns null on success, or an error string on failure.
  Future<String?> hardDeleteReel(String reelId) async {
    try {
      final res = await _reelService.hardDeleteReel(reelId);
      if (res['success'] == true) {
        _removeFromAllLocalLists(reelId);
        notifyListeners();
        return null;
      }
      return 'Cloud Function returned failure: ${res['cloudinaryError'] ?? 'unknown'}';
    } catch (e) {
      dev.log('[ReelProvider] hardDeleteReel error: $e', name: 'REEL');
      return e.toString();
    }
  }

  Future<void> approveReel(String reelId,
      {String approvedBy = ''}) async {
    await _reelService.approveReel(reelId, approvedBy: approvedBy);
    // Instantly remove from pending so admin sees change immediately.
    // The Firestore streams will re-sync and confirm.
    _pendingReels = _pendingReels
        .where((r) => r.reelId != reelId)
        .toList();
    // Update in allAdminReels and approvedAdminReels
    final orig = _allAdminReels
        .where((r) => r.reelId == reelId)
        .firstOrNull;
    if (orig != null) {
      final updated = orig.copyWith(
          status: 'approved', isActive: true);
      _allAdminReels = _allAdminReels
          .map((r) => r.reelId == reelId ? updated : r)
          .toList();
      _approvedAdminReels = [
        updated,
        ..._approvedAdminReels.where((r) => r.reelId != reelId),
      ];
    }
    notifyListeners();
  }

  Future<void> rejectReel(String reelId,
      {String reason = '', String rejectedBy = ''}) async {
    await _reelService.rejectReel(reelId,
        reason: reason, rejectedBy: rejectedBy);
    // Instantly remove from pending.
    _pendingReels = _pendingReels
        .where((r) => r.reelId != reelId)
        .toList();
    // Remove from approved if it was there
    _approvedAdminReels = _approvedAdminReels
        .where((r) => r.reelId != reelId)
        .toList();
    final orig = _allAdminReels
        .where((r) => r.reelId == reelId)
        .firstOrNull;
    if (orig != null) {
      final updated = orig.copyWith(
          status: 'rejected', isActive: false,
          rejectionReason: reason);
      _allAdminReels = _allAdminReels
          .map((r) => r.reelId == reelId ? updated : r)
          .toList();
      _rejectedReels = [
        updated,
        ..._rejectedReels.where((r) => r.reelId != reelId),
      ];
    }
    notifyListeners();
  }

  // ── Saved reels ───────────────────────────────────────────────────────────
  List<ReelModel> _savedReels = [];
  StreamSubscription<List<ReelModel>>? _savedSub;
  List<ReelModel> get savedReels => List.unmodifiable(_savedReels);

  void subscribeSavedReels(String userId) {
    _savedSub?.cancel();
    _savedSub = _reelService.savedReelsStream(userId).listen(
      (reels) {
        _savedReels = reels;
        _savedIds
          ..clear()
          ..addAll(reels.map((r) => r.reelId));
        notifyListeners();
      },
      onError: (e) =>
          dev.log('[ReelProvider] savedReels error: $e', name: 'REEL'),
    );
  }

  void cancelSavedReelsSub() => _savedSub?.cancel();

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<String?> addComment({
    required String reelId,
    required String userId,
    required String userName,
    required String userPhoto,
    required String text,
  }) async {
    try {
      final id = await _reelService.addComment(
        reelId:    reelId,
        userId:    userId,
        userName:  userName,
        userPhoto: userPhoto,
        text:      text,
      );
      _updateLocalCommentCount(reelId, 1);
      return id;
    } catch (e) {
      dev.log('[ReelProvider] addComment error: $e', name: 'REEL');
      return null;
    }
  }

  Stream<List<CommentModel>> commentsStream(String reelId) =>
      _reelService.commentsStream(reelId);

  Future<void> editComment({
    required String reelId,
    required String commentId,
    required String newText,
  }) async {
    try {
      await _reelService.editComment(
          reelId: reelId, commentId: commentId, newText: newText);
    } catch (e) {
      dev.log('[ReelProvider] editComment error: $e', name: 'REEL');
    }
  }

  Future<void> deleteComment({
    required String reelId,
    required String commentId,
  }) async {
    try {
      await _reelService.deleteComment(
          reelId: reelId, commentId: commentId);
      _updateLocalCommentCount(reelId, -1);
    } catch (e) {
      dev.log('[ReelProvider] deleteComment error: $e', name: 'REEL');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Removes [reelId] from every local list so UI updates
  /// before the Firestore stream emits the change.
  void _removeFromAllLocalLists(String reelId) {
    bool keep(ReelModel r) => r.reelId != reelId;
    _approvedReels      = _approvedReels.where(keep).toList();
    _approvedAdminReels = _approvedAdminReels.where(keep).toList();
    _fundiReels         = _fundiReels.where(keep).toList();
    _pendingReels       = _pendingReels.where(keep).toList();
    _rejectedReels      = _rejectedReels.where(keep).toList();
    _allAdminReels      = _allAdminReels.where(keep).toList();
  }

  /// Increments or decrements [reelId]'s commentsCount in local lists.
  void _updateLocalCommentCount(String reelId, int delta) {
    ReelModel bump(ReelModel r) {
      if (r.reelId != reelId) return r;
      final n = (r.commentsCount + delta).clamp(0, 999999).toInt();
      return r.copyWith(commentsCount: n);
    }
    _approvedReels      = _approvedReels.map(bump).toList();
    _approvedAdminReels = _approvedAdminReels.map(bump).toList();
    _fundiReels         = _fundiReels.map(bump).toList();
    _allAdminReels      = _allAdminReels.map(bump).toList();
    notifyListeners();
  }

  void _set(ReelUploadState state, {double? progress, bool silent = false}) {
    _uploadState = state;
    if (progress != null) _uploadProgress = progress;
    if (!silent) notifyListeners();
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  String _friendlyFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Please sign out and back in, then retry.';
      case 'unavailable':
        return 'Firestore is temporarily unavailable. Please retry.';
      case 'deadline-exceeded':
        return 'Request timed out. Check your connection and retry.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Firestore error (${e.code}). Please retry.';
    }
  }

  @override
  void dispose() {
    _approvedSub?.cancel();
    _approvedAdminSub?.cancel();
    _fundiSub?.cancel();
    _pendingSub?.cancel();
    _rejectedSub?.cancel();
    _allAdminSub?.cancel();
    _savedSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }
}
