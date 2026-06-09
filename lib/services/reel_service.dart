import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/comment_model.dart';
import '../models/reel_model.dart';
import 'storage_service.dart';

class ReelService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService    _storage;

  ReelService({StorageService? storageService})
      : _storage = storageService ?? StorageService();

  static const int _pageSize = 10;

  // ── Create ────────────────────────────────────────────────────────────────

  Future<String> createReelDocument({
    required String fundiId,
    required String fundiName,
    required String fundiProfileImage,
    required String category,
    required String caption,
    required String videoUrl,
    required String thumbnailUrl,
    required String storagePath,
    required String thumbnailPath,
    required String location,
    required double rating,
    required int    jobsDone,
    required int    durationSeconds,
  }) async {
    final ref  = _db.collection(FirestoreConstants.reels).doc();
    final reel = ReelModel(
      reelId:            ref.id,
      fundiId:           fundiId,
      fundiName:         fundiName,
      fundiProfileImage: fundiProfileImage,
      category:          category,
      caption:           caption,
      videoUrl:          videoUrl,
      thumbnailUrl:      thumbnailUrl,
      storagePath:       storagePath,
      thumbnailPath:     thumbnailPath,
      createdAt:         DateTime.now(),
      status:            AppConstants.reelPendingApproval,
      location:          location,
      rating:            rating,
      jobsDone:          jobsDone,
      durationSeconds:   durationSeconds,
      isActive:          false,   // not active until approved
    );
    await ref.set(reel.toMap());
    return ref.id;
  }

  // ── Approved reels (public feed) ──────────────────────────────────────────

  Stream<List<ReelModel>> approvedReelsStream({int limit = _pageSize}) =>
      _db
          .collection(FirestoreConstants.reels)
          .where('status',    isEqualTo: AppConstants.reelApproved)
          .where('isActive',  isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  /// Category-filtered approved stream for the user-facing feed.
  Stream<List<ReelModel>> approvedByCategoryStream(
    String category, {
    int limit = _pageSize,
  }) {
    var q = _db
        .collection(FirestoreConstants.reels)
        .where('status',   isEqualTo: AppConstants.reelApproved)
        .where('isActive', isEqualTo: true);
    if (category.isNotEmpty) {
      q = q.where('category', isEqualTo: category);
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Future<List<ReelModel>> fetchNextPage({
    required DocumentSnapshot lastDoc,
    int limit = _pageSize,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.reels)
        .where('status',   isEqualTo: AppConstants.reelApproved)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();
    return snap.docs.map((d) => ReelModel.fromMap(d.data())).toList();
  }

  Future<DocumentSnapshot?> getReelSnapshot(String reelId) async {
    try {
      return await _db.collection(FirestoreConstants.reels).doc(reelId).get();
    } catch (_) {
      return null;
    }
  }

  // ── Category stream ───────────────────────────────────────────────────────

  Stream<List<ReelModel>> reelsByCategoryStream(String category,
          {int limit = 20}) =>
      _db
          .collection(FirestoreConstants.reels)
          .where('status',   isEqualTo: AppConstants.reelApproved)
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  // ── Fundi's own reels (excludes deleted so fundi profile is accurate) ──────

  Stream<List<ReelModel>> fundiReelsStream(String fundiId) =>
      _db
          .collection(FirestoreConstants.reels)
          .where('fundiId',   isEqualTo: fundiId)
          .where('isActive',  isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  // ── Admin streams (all statuses) ──────────────────────────────────────────

  Stream<List<ReelModel>> pendingReelsStream() =>
      _db
          .collection(FirestoreConstants.reels)
          .where('status',    isEqualTo: AppConstants.reelPendingApproval)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  Stream<List<ReelModel>> approvedAdminStream() =>
      _db
          .collection(FirestoreConstants.reels)
          .where('status',    isEqualTo: AppConstants.reelApproved)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  Stream<List<ReelModel>> rejectedReelsStream() =>
      _db
          .collection(FirestoreConstants.reels)
          .where('status',    isEqualTo: AppConstants.reelRejected)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  Stream<List<ReelModel>> allReelsAdminStream() =>
      _db
          .collection(FirestoreConstants.reels)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  /// Admin Deleted tab: shows only reels the fundi has soft-deleted.
  Stream<List<ReelModel>> deletedReelsStream() =>
      _db
          .collection(FirestoreConstants.reels)
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map((d) => ReelModel.fromMap(d.data())).toList());

  // ── Admin: approve ────────────────────────────────────────────────────────

  Future<void> approveReel(String reelId, {String approvedBy = ''}) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'status':     AppConstants.reelApproved,
      'isActive':   true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': approvedBy,
      // Clear any previous rejection data
      'rejectedAt':      null,
      'rejectedBy':      '',
      'rejectionReason': '',
    });
  }

  // ── Admin: reject ─────────────────────────────────────────────────────────

  Future<void> rejectReel(
    String reelId, {
    String reason = '',
    String rejectedBy = '',
  }) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'status':           AppConstants.reelRejected,
      'isActive':         false,
      'rejectedAt':       FieldValue.serverTimestamp(),
      'rejectedBy':       rejectedBy,
      'rejectionReason':  reason,
    });
  }

  // ── Like / Save / View ────────────────────────────────────────────────────

  Future<void> toggleLike(String reelId, {required bool liked}) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'likesCount': FieldValue.increment(liked ? 1 : -1),
    });
  }

  Future<void> toggleSave(String reelId, {required bool saved}) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'savesCount': FieldValue.increment(saved ? 1 : -1),
    });
  }

  Future<void> incrementView(String reelId) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'viewsCount': FieldValue.increment(1),
    });
  }

  // ── Saved reels ───────────────────────────────────────────────────────────

  /// Streams reels saved by [userId].
  /// Saved reel IDs are stored in users/{userId}/savedReels/{reelId}.
  Stream<List<ReelModel>> savedReelsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('savedReels')
        .orderBy('savedAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          if (ids.isEmpty) return <ReelModel>[];
          final reels = <ReelModel>[];
          for (var i = 0; i < ids.length; i += 10) {
            final end   = (i + 10 > ids.length) ? ids.length : i + 10;
            final batch = ids.sublist(i, end);
            final q = await _db
                .collection(FirestoreConstants.reels)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            reels.addAll(q.docs.map((d) => ReelModel.fromMap(d.data())));
          }
          return reels;
        });
  }

  Future<void> saveReel({
    required String userId,
    required String reelId,
    required bool   saved,
  }) async {
    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('savedReels')
        .doc(reelId);
    if (saved) {
      await ref.set({'savedAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
    await toggleSave(reelId, saved: saved);
  }

  // ── Report ────────────────────────────────────────────────────────────────

  Future<void> reportReel({
    required String reelId,
    required String reporterId,
    required String reason,
  }) async {
    final batch = _db.batch();
    batch.update(
      _db.collection(FirestoreConstants.reels).doc(reelId),
      {'reportCount': FieldValue.increment(1)},
    );
    final reportRef = _db.collection('reel_reports').doc();
    batch.set(reportRef, {
      'reportId':   reportRef.id,
      'reelId':     reelId,
      'reporterId': reporterId,
      'reason':     reason,
      'createdAt':  FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Fundi soft-delete: sets isDeleted=true + isActive=false.
  /// The document is kept so admin can audit in the Deleted tab.
  Future<void> softDeleteReel(String reelId, String userId) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).update({
      'isActive':  false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
    });
  }

  Future<void> deleteReel({
    required String reelId,
    required String storagePath,
    required String thumbnailPath,
  }) async {
    await _db.collection(FirestoreConstants.reels).doc(reelId).delete();
    await Future.wait([
      _storage.deleteByPath(storagePath),
      _storage.deleteByPath(thumbnailPath),
    ]);
  }

  // ── Admin hard-delete via Cloud Function ───────────────────────────────────

  /// Calls the 'hardDeleteReel' Cloud Function.
  /// The Function deletes the Cloudinary video (using the API secret
  /// stored server-side) then removes the Firestore doc + comments.
  /// Returns the raw result map from the Function.
  Future<Map<String, dynamic>> hardDeleteReel(String reelId) async {
    final fn     = FirebaseFunctions.instance.httpsCallable('hardDeleteReel');
    final result = await fn.call<Map<String, dynamic>>({'reelId': reelId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ── Viewed-reels tracking ─────────────────────────────────────────────────

  /// Write a lightweight timestamp so the feed can deprioritise seen reels.
  /// Fire-and-forget — non-fatal if it fails.
  Future<void> markReelViewed(String userId, String reelId) async {
    if (userId.isEmpty || reelId.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('viewedReels')
          .doc(reelId)
          .set({'seenAt': FieldValue.serverTimestamp()},
               SetOptions(merge: true));
    } catch (_) {}
  }

  /// Returns the set of reelIds the user has already seen (up to 500).
  Future<Set<String>> fetchViewedReelIds(String userId) async {
    if (userId.isEmpty) return {};
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('viewedReels')
          .limit(500)
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Comments subcollection ────────────────────────────────────────────────

  Future<String> addComment({
    required String reelId,
    required String userId,
    required String userName,
    required String userPhoto,
    required String text,
  }) async {
    // Create the comment document reference first
    final ref = _db
        .collection(FirestoreConstants.reels)
        .doc(reelId)
        .collection('comments')
        .doc();
    final comment = CommentModel(
      commentId: ref.id,
      reelId:    reelId,
      userId:    userId,
      userName:  userName,
      userPhoto: userPhoto,
      text:      text.trim(),
      createdAt: DateTime.now(),
    );
    // Atomic batch: comment write + commentsCount increment together
    final writeBatch = _db.batch();
    writeBatch.set(ref, comment.toMap());
    writeBatch.update(
      _db.collection(FirestoreConstants.reels).doc(reelId),
      {'commentsCount': FieldValue.increment(1)},
    );
    await writeBatch.commit();
    return ref.id;
  }

  Stream<List<CommentModel>> commentsStream(String reelId) => _db
      .collection(FirestoreConstants.reels)
      .doc(reelId)
      .collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => CommentModel.fromMap(d.data())).toList());

  Future<void> editComment({
    required String reelId,
    required String commentId,
    required String newText,
  }) async {
    await _db
        .collection(FirestoreConstants.reels)
        .doc(reelId)
        .collection('comments')
        .doc(commentId)
        .update({
      'text':     newText.trim(),
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment({
    required String reelId,
    required String commentId,
  }) async {
    // Atomic batch: delete comment + decrement counter together
    final writeBatch = _db.batch();
    writeBatch.delete(
      _db
          .collection(FirestoreConstants.reels)
          .doc(reelId)
          .collection('comments')
          .doc(commentId),
    );
    writeBatch.update(
      _db.collection(FirestoreConstants.reels).doc(reelId),
      {'commentsCount': FieldValue.increment(-1)},
    );
    await writeBatch.commit();
  }
}
