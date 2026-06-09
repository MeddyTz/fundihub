import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/booking_model.dart';
import '../models/report_model.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> hasReviewed(String bookingId, String clientId) async {
    final cleanBookingId = bookingId.trim();
    final cleanClientId  = clientId.trim();
    if (cleanBookingId.isEmpty || cleanClientId.isEmpty) return false;

    // Review doc ID == booking ID.
    // This prevents duplicate reviews and avoids compound Firestore indexes.
    final snap = await _db
        .collection(FirestoreConstants.reviews)
        .doc(cleanBookingId)
        .get();
    final data = snap.data();
    if (!snap.exists || data == null) return false;
    return (data['clientId'] ?? '').toString().trim() == cleanClientId;
  }

  Stream<bool> hasReviewedStream(String bookingId, String clientId) {
    final cleanBookingId = bookingId.trim();
    final cleanClientId  = clientId.trim();
    if (cleanBookingId.isEmpty || cleanClientId.isEmpty) {
      return Stream<bool>.value(false);
    }

    return _db
        .collection(FirestoreConstants.reviews)
        .doc(cleanBookingId)
        .snapshots()
        .map((snap) {
          final data = snap.data();
          if (!snap.exists || data == null) return false;
          return (data['clientId'] ?? '').toString().trim() == cleanClientId;
        });
  }

  Future<void> submitReview({
    required String bookingId,
    required String clientId,
    required String clientName,
    String? clientImageUrl,
    required String fundiId,
    required double rating,
    required String comment,   // FIX: comment is now optional (can be empty)
  }) async {
    final cleanBookingId = bookingId.trim();
    final cleanClientId  = clientId.trim();
    final cleanFundiId   = fundiId.trim();
    final cleanComment   = comment.trim();

    if (cleanBookingId.isEmpty || cleanClientId.isEmpty || cleanFundiId.isEmpty) {
      throw Exception(
          'Missing review details. Please reopen the booking and try again.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }
    // FIX: Removed 10-char minimum. Comment is optional — only rating required.

    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(cleanBookingId);
    final userRef    = _db.collection(FirestoreConstants.users).doc(cleanFundiId);
    final reviewRef  = _db.collection(FirestoreConstants.reviews).doc(cleanBookingId);
    final notifRef   = _db.collection(FirestoreConstants.notifications).doc();
    final now        = Timestamp.fromDate(DateTime.now());

    await _db.runTransaction((tx) async {
      // ── Read booking ────────────────────────────────────────────────────
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists || bookingSnap.data() == null) {
        throw Exception('Booking was not found.');
      }

      final booking = BookingModel.fromMap(bookingSnap.data()!);
      if (booking.clientId != cleanClientId) {
        throw Exception(
            'Only the client who created this booking can review it.');
      }
      if (booking.fundiId != cleanFundiId) {
        throw Exception(
            'This review does not match the fundi on the booking.');
      }
      if (!booking.isCompleted) {
        throw Exception(
            'You can only review after the job is completed.');
      }

      // ── Check for duplicate ─────────────────────────────────────────────
      final existingReviewSnap = await tx.get(reviewRef);
      if (existingReviewSnap.exists) {
        throw Exception('You have already reviewed this booking.');
      }

      // ── Read fundi doc for rating calculation ───────────────────────────
      final fundiSnap = await tx.get(userRef);
      final fundiData = fundiSnap.data() ?? <String, dynamic>{};
      final oldAverage = (fundiData['rating']       as num?)?.toDouble() ??
                         (fundiData['averageRating'] as num?)?.toDouble() ?? 0.0;
      final oldCount   = (fundiData['reviewCount']  as num?)?.toInt() ??
                         (fundiData['totalReviews'] as num?)?.toInt() ?? 0;
      final newCount   = oldCount + 1;
      final newAverage = double.parse(
        (((oldAverage * oldCount) + rating) / newCount).toStringAsFixed(1),
      );

      final review = ReviewModel(
        reviewId:       reviewRef.id,
        bookingId:      cleanBookingId,
        clientId:       cleanClientId,
        clientName:     clientName.trim().isEmpty ? 'Client' : clientName.trim(),
        clientImageUrl: clientImageUrl,
        fundiId:        cleanFundiId,
        comment:        cleanComment,   // stored as-is (may be empty)
        rating:         rating,
        createdAt:      now.toDate(),
      );

      // ── Write review doc ────────────────────────────────────────────────
      tx.set(reviewRef, review.toMap());

      // ── Update fundi rating on user doc ─────────────────────────────────
      // FIX: Use merge:true + only update rating/count fields.
      // The isRatingUpdate() rule in Firestore allows this from any auth user.
      tx.set(
        userRef,
        {
          'rating':         newAverage,
          'averageRating':  newAverage,
          'reviewCount':    newCount,
          'totalReviews':   newCount,
          'updatedAt':      now,
        },
        SetOptions(merge: true),
      );

      // ── Mark booking as reviewed ────────────────────────────────────────
      tx.set(
        bookingRef,
        {
          'reviewed':    true,
          'reviewId':    reviewRef.id,
          'reviewRating': rating,
          'reviewedAt':  now,
          'updatedAt':   now,
        },
        SetOptions(merge: true),
      );

      // ── Notify fundi ─────────────────────────────────────────────────────
      final displayName = clientName.trim().isEmpty ? 'A client' : clientName.trim();
      tx.set(notifRef, {
        'notificationId': notifRef.id,
        'notifId':        notifRef.id,
        'userId':         cleanFundiId,
        'receiverId':     cleanFundiId,
        'senderId':       cleanClientId,
        'title':          'New Review Received ⭐',
        'body':           '$displayName rated your job '
                          '${rating.toStringAsFixed(0)} star${rating == 1 ? '' : 's'}.',
        'message':        '$displayName rated your job '
                          '${rating.toStringAsFixed(0)} star${rating == 1 ? '' : 's'}.',
        'type':           'review_received',
        'relatedId':      cleanBookingId,
        'bookingId':      cleanBookingId,
        'isRead':         false,
        'read':           false,
        'createdAt':      now,
        'updatedAt':      now,
      });
    });
  }

  Stream<List<ReviewModel>> fundiReviewsStream(String fundiId) {
    final cleanFundiId = fundiId.trim();
    if (cleanFundiId.isEmpty) {
      return Stream<List<ReviewModel>>.value(const []);
    }

    return _db
        .collection(FirestoreConstants.reviews)
        .where('fundiId', isEqualTo: cleanFundiId)
        .snapshots()
        .map((snap) {
          final reviews = snap.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  Future<void> submitReport({
    required String reporterId,
    required String reporterName,
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    required String details,
    String? relatedBookingId,
  }) async {
    final ref = _db.collection(FirestoreConstants.reports).doc();
    final report = ReportModel(
      reportId:          ref.id,
      reporterId:        reporterId,
      reporterName:      reporterName,
      reportedUserId:    reportedUserId,
      reportedUserName:  reportedUserName,
      reason:            reason,
      details:           details,
      status:            AppConstants.statusPending,
      relatedBookingId:  relatedBookingId,
      createdAt:         DateTime.now(),
    );
    await ref.set(report.toMap());
  }
}
