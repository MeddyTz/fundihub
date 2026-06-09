import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/booking_model.dart';
import '../models/fundi_model.dart';
import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATUS NORMALIZER  (legacy capitalised → canonical lowercase)
// ─────────────────────────────────────────────────────────────────────────────
String _normStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'pending':                                    return AppConstants.bookingPending;
    case 'accepted':                                   return AppConstants.bookingAccepted;
    case 'agreement_confirmed':
    case 'agreementconfirmed':                         return AppConstants.bookingAgreementConfirmed;
    case 'in_progress':
    case 'inprogress':
    case 'in progress':                                return AppConstants.bookingInProgress;
    case 'awaiting_confirmation':
    case 'awaitingconfirmation':
    case 'awaiting confirmation':
    case 'awaiting client confirmation':               return AppConstants.bookingAwaitingConfirmation;
    case 'completion_disputed':
    case 'completiondisputed':
    case 'disputed':                                   return AppConstants.bookingCompletionDisputed;
    case 'completed':                                  return AppConstants.bookingCompleted;
    case 'rejected':                                   return AppConstants.bookingRejected;
    case 'cancelled':
    case 'canceled':                                   return AppConstants.bookingCancelled;
    case 'expired':                                    return AppConstants.bookingExpired;
    default: return raw.trim().isEmpty
        ? AppConstants.bookingPending
        : raw.trim().toLowerCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT OPEN STATUSES  (chat stays open while any active work is in progress)
// ─────────────────────────────────────────────────────────────────────────────
const _chatOpenStatuses = {
  AppConstants.bookingAccepted,
  AppConstants.bookingAgreementConfirmed,
  AppConstants.bookingInProgress,
  AppConstants.bookingAwaitingConfirmation,   // FIX: chat stays open during confirmation
  AppConstants.bookingCompletionDisputed,     // FIX: chat stays open during dispute
};

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION WRITE  (stable idempotent ID, both isRead + read fields)
  // ─────────────────────────────────────────────────────────────────────────
  void _batchNotif({
    required WriteBatch batch,
    required String receiverId,
    required String senderId,
    required String title,
    required String body,
    required String type,
    required String bookingId,
  }) {
    if (receiverId.trim().isEmpty) return;
    final notifId  = '${receiverId}_${type}_$bookingId';
    final notifRef = _db.collection(FirestoreConstants.notifications).doc(notifId);
    dev.log('[BookingService] queuing notif $notifId', name: 'NOTIF');
    batch.set(notifRef, {
      'notificationId': notifId,
      'notifId':        notifId,
      'userId':         receiverId,   // primary field for NotificationProvider Q1/Q2
      'receiverId':     receiverId,   // alias for Q3/Q4
      'senderId':       senderId,
      'title':          title,
      'body':           body,
      'message':        body,
      'type':           type,
      'relatedId':      bookingId,
      'bookingId':      bookingId,
      'isRead':         false,
      'read':           false,
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    });
    // Note: plain batch.set (no merge) → overwrites any stale doc so counter
    // always reflects the latest unread event for this booking+type pair.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. CREATE BOOKING
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> createBooking({
    required UserModel  client,
    required FundiModel fundi,
    required String serviceDescription,
    required String locationRegion,
    required String locationDistrict,
    required String locationArea,
    String?  locationDetails,
    double?  locationLat,
    double?  locationLng,
    String?  locationDetectedAddress,
    String?  agreedPrice,
  }) async {
    if (await _isBlocked(client.uid, fundi.uid)) {
      throw Exception('You cannot book this user.');
    }

    final ref = _db.collection(FirestoreConstants.bookings).doc();
    final ts  = FieldValue.serverTimestamp();

    dev.log('[BookingService] createBooking id=${ref.id} fundiId=${fundi.uid}',
        name: 'BOOKING');

    final batch = _db.batch();

    batch.set(ref, {
      'bookingId':          ref.id,
      'clientId':           client.uid,
      'clientName':         client.fullName,
      'clientPhone':        client.phone,
      'clientProfileImage': client.profileImageUrl,
      'fundiId':            fundi.uid,
      'fundiName':          fundi.fullName,
      'fundiPhone':         fundi.phone,
      'fundiProfileImage':  fundi.profileImageUrl,
      'fundiCategory':      fundi.displayCategory,
      'serviceDescription': serviceDescription,
      'locationRegion':     locationRegion,
      'locationDistrict':   locationDistrict,
      'locationArea':       locationArea,
      'locationDetails':    locationDetails,
      'locationLat':        locationLat,
      'locationLng':        locationLng,
      'locationDetectedAddress': locationDetectedAddress,
      'status':             AppConstants.bookingPending,
      'clientAgreed':       false,
      'fundiAgreed':        false,
      'jobFeeCharged':      false,
      'jobFeePaid':         false,
      'chatId':             ref.id,
      'contactUnlocked':    false,
      // Completion flow fields
      'completionRequested':       false,
      'clientConfirmedCompletion': false,
      'completionDisputed':        false,
      'jobsDoneCounted':           false, // idempotency flag — NEVER increment twice
      'adminReviewRequired':       false,
      'reviewed':  false,
      'reviewId':  null,
      if (agreedPrice != null && agreedPrice.isNotEmpty) 'agreedPrice': agreedPrice,
      'createdAt': ts,
      'updatedAt': ts,
    });

    _batchNotif(
      batch:      batch,
      receiverId: fundi.uid,
      senderId:   client.uid,
      title:      'New Booking Request 📋',
      body:       '${client.fullName} sent you a new booking request.',
      type:       'booking_request',
      bookingId:  ref.id,
    );

    await batch.commit();
    dev.log('[BookingService] createBooking committed id=${ref.id}', name: 'BOOKING');
    return ref.id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. ACCEPT
  // contactUnlocked = true immediately on accept — no agreement required.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> acceptBooking(String bookingId) async {
    dev.log('[BookingService] acceptBooking $bookingId', name: 'BOOKING');

    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? clientId, clientName, fundiId, fundiName;

    await _db.runTransaction((txn) async {
      final snap   = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data   = snap.data()!;
      final status = _normStatus((data['status'] ?? '').toString());
      if (status != AppConstants.bookingPending) {
        throw Exception('Booking is no longer pending (status: $status).');
      }
      clientId   = (data['clientId']   ?? '').toString();
      clientName = (data['clientName'] ?? 'Client').toString();
      fundiId    = (data['fundiId']    ?? '').toString();
      fundiName  = (data['fundiName']  ?? 'Fundi').toString();
      txn.update(bookingRef, {
        'status':          AppConstants.bookingAccepted,
        'acceptedAt':      ts,
        'updatedAt':       ts,
        'contactUnlocked': true,
        'chatUnlocked':    true,
      });
    });

    dev.log('[BookingService] accept → contactUnlocked=true', name: 'BOOKING');

    if (clientId != null && clientId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: clientId!,
        senderId:   fundiId ?? '',
        title:      'Booking Accepted ✅',
        body:       '$fundiName accepted your booking. You can now call, WhatsApp, and chat!',
        type:       'booking_accepted',
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    try { await _initChat(bookingId, clientId!, fundiId!, clientName!, fundiName!); }
    catch (e) { dev.log('[BookingService] _initChat non-fatal: $e'); }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. REJECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> rejectBooking(String bookingId, {String reason = ''}) async {
    dev.log('[BookingService] rejectBooking $bookingId', name: 'BOOKING');
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? clientId, fundiId, fundiName;

    await _db.runTransaction((txn) async {
      final snap = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data = snap.data()!;
      clientId  = (data['clientId']  ?? '').toString();
      fundiId   = (data['fundiId']   ?? '').toString();
      fundiName = (data['fundiName'] ?? 'Fundi').toString();
      txn.update(bookingRef, {
        'status':          AppConstants.bookingRejected,
        'rejectionReason': reason,
        'rejectedAt':      ts,
        'updatedAt':       ts,
      });
    });

    if (clientId != null && clientId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: clientId!,
        senderId:   fundiId ?? '',
        title:      'Booking Rejected',
        body:       '${fundiName ?? 'Fundi'} rejected your booking request.',
        type:       'booking_rejected',
        bookingId:  bookingId,
      );
      await batch.commit();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. CANCEL
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> cancelBooking(
    String bookingId, {
    required String cancelledBy,
    String reason = '',
  }) async {
    dev.log('[BookingService] cancelBooking $bookingId by=$cancelledBy',
        name: 'BOOKING');
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? clientId, fundiId, clientName, fundiName;

    await _db.runTransaction((txn) async {
      final snap = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data = snap.data()!;
      clientId   = (data['clientId']   ?? '').toString();
      fundiId    = (data['fundiId']    ?? '').toString();
      clientName = (data['clientName'] ?? 'Client').toString();
      fundiName  = (data['fundiName']  ?? 'Fundi').toString();
      txn.update(bookingRef, {
        'status':             AppConstants.bookingCancelled,
        'cancelledBy':        cancelledBy,
        'cancellationReason': reason,
        'cancelledAt':        ts,
        'updatedAt':          ts,
      });
    });

    final byClient = cancelledBy == clientId ||
        cancelledBy.toLowerCase() == 'client';
    final actor    = byClient ? clientName!  : fundiName!;
    final receiver = byClient ? (fundiId ?? '') : (clientId ?? '');
    final sender   = byClient ? (clientId ?? '') : (fundiId ?? '');

    if (receiver.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: receiver,
        senderId:   sender,
        title:      'Booking Cancelled',
        body:       '$actor cancelled the booking.',
        type:       'booking_cancelled',
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    await _updateChatStatus(bookingId, AppConstants.bookingCancelled);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. START JOB
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> markInProgress(String bookingId) async {
    dev.log('[BookingService] markInProgress $bookingId', name: 'BOOKING');
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? clientId, fundiId, fundiName;

    await _db.runTransaction((txn) async {
      final snap = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data = snap.data()!;
      clientId  = (data['clientId']  ?? '').toString();
      fundiId   = (data['fundiId']   ?? '').toString();
      fundiName = (data['fundiName'] ?? 'Fundi').toString();
      txn.update(bookingRef, {
        'status':    AppConstants.bookingInProgress,
        'startedAt': ts,
        'updatedAt': ts,
      });
    });

    if (clientId != null && clientId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: clientId!,
        senderId:   fundiId ?? '',
        title:      'Job Started 🔧',
        body:       '${fundiName ?? 'Fundi'} has started the job.',
        type:       'job_started',
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    await _updateChatStatus(bookingId, AppConstants.bookingInProgress);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. FUNDI MARKS JOB DONE  →  Awaiting Client Confirmation
  //    IMPORTANT: Does NOT increment jobsDone. Does NOT set status=completed.
  //    jobsDone is ONLY incremented in clientConfirmCompletion().
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestCompletion(String bookingId) async {
    dev.log('[BookingService] requestCompletion $bookingId', name: 'BOOKING');
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? clientId, fundiId, fundiName;

    await _db.runTransaction((txn) async {
      final snap   = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data   = snap.data()!;
      final status = _normStatus((data['status'] ?? '').toString());

      // Allow from in_progress or accepted (fundi might have skipped Start Job)
      if (status != AppConstants.bookingInProgress &&
          status != AppConstants.bookingAccepted &&
          status != AppConstants.bookingAgreementConfirmed) {
        throw Exception('Cannot mark done from status: $status');
      }

      clientId  = (data['clientId']  ?? '').toString();
      fundiId   = (data['fundiId']   ?? '').toString();
      fundiName = (data['fundiName'] ?? 'Fundi').toString();

      txn.update(bookingRef, {
        'status':              AppConstants.bookingAwaitingConfirmation,
        'completionRequested': true,
        'completionRequestedAt': ts,
        'completedByFundiAt':  ts,
        'updatedAt':           ts,
        // IMPORTANT: jobsDoneCounted is NOT touched here.
        // It is only set to true in clientConfirmCompletion().
      });
    });

    // Notify client — IMPORTANT: type = 'completion_requested' so notifications
    // screen navigates to booking detail where client can confirm/dispute.
    if (clientId != null && clientId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: clientId!,
        senderId:   fundiId ?? '',
        title:      'Job Done — Please Confirm ✅',
        body:       '${fundiName ?? 'Fundi'} marked the job as done. Tap to confirm or report a problem.',
        type:       'completion_requested',   // ← navigates to /booking/detail
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    // Keep chat OPEN during awaiting confirmation
    await _updateChatStatus(bookingId, AppConstants.bookingAwaitingConfirmation);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7. CLIENT CONFIRMS COMPLETION
  //    ONLY place where jobsDone increments.
  //    Protected by jobsDoneCounted flag — cannot increment twice.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> clientConfirmCompletion(String bookingId) async {
    dev.log('[BookingService] clientConfirmCompletion $bookingId', name: 'BOOKING');

    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();

    String? fundiId, fundiName, clientId, clientName;
    bool alreadyCounted = false;

    // ── STEP 1: Mark booking completed ──────────────────────────────────
    await _db.runTransaction((txn) async {
      final snap   = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data   = snap.data()!;
      final status = _normStatus((data['status'] ?? '').toString());

      if (status != AppConstants.bookingAwaitingConfirmation &&
          status != AppConstants.bookingCompletionDisputed) {
        throw Exception('Cannot confirm completion from status: $status');
      }

      fundiId          = (data['fundiId']    ?? '').toString();
      fundiName        = (data['fundiName']  ?? 'Fundi').toString();
      clientId         = (data['clientId']   ?? '').toString();
      clientName       = (data['clientName'] ?? 'Client').toString();
      // Read idempotency flag BEFORE updating
      alreadyCounted   = data['jobsDoneCounted'] == true;

      txn.update(bookingRef, {
        'status':                    AppConstants.bookingCompleted,
        'clientConfirmedCompletion': true,
        'clientConfirmedCompletionAt': ts,
        'completedAt':               ts,
        'jobFeeCharged':             false,   // growth phase — never charge
        // Set flag to true so we never increment jobsDone twice
        if (!alreadyCounted) 'jobsDoneCounted': true,
        'updatedAt':                 ts,
      });
    });

    dev.log('[BookingService] booking set to completed; alreadyCounted=$alreadyCounted',
        name: 'BOOKING');

    // ── STEP 2: Increment jobsDone ONLY if not already counted ──────────
    // Uses its own transaction so it cannot race with anything else.
    if (!alreadyCounted && fundiId != null && fundiId!.isNotEmpty) {
      try {
        await _db.runTransaction((txn) async {
          final fundiRef  = _db.collection(FirestoreConstants.users).doc(fundiId!);
          final fundiSnap = await txn.get(fundiRef);
          if (!fundiSnap.exists) return;
          final d       = fundiSnap.data()!;
          final currJobs = (d['jobsDone']           as num?)?.toInt() ?? 0;
          final currComp = (d['completedJobsCount']  as num?)?.toInt() ?? 0;
          txn.update(fundiRef, {
            'jobsDone':           currJobs + 1,
            'completedJobsCount': currComp + 1,
            'updatedAt':          FieldValue.serverTimestamp(),
          });
          dev.log('[BookingService] jobsDone ${currJobs} → ${currJobs + 1}',
              name: 'BOOKING');
        });
      } catch (e) {
        dev.log('[BookingService] jobsDone increment failed (non-fatal): $e',
            name: 'BOOKING');
      }
    } else if (alreadyCounted) {
      dev.log('[BookingService] jobsDone already counted — skipping', name: 'BOOKING');
    }

    // ── STEP 3: Notify fundi ─────────────────────────────────────────────
    if (fundiId != null && fundiId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: fundiId!,
        senderId:   clientId ?? '',
        title:      'Job Completed ✅',
        body:       '${clientName ?? 'Client'} confirmed the job is complete. Great work!',
        type:       'job_completed',
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    // Lock chat on completion
    await _updateChatStatus(bookingId, AppConstants.bookingCompleted);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 8. CLIENT DISPUTES COMPLETION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disputeCompletion(String bookingId, {String reason = ''}) async {
    dev.log('[BookingService] disputeCompletion $bookingId', name: 'BOOKING');
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    final ts         = FieldValue.serverTimestamp();
    String? fundiId, fundiName, clientId, clientName;

    await _db.runTransaction((txn) async {
      final snap   = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data   = snap.data()!;
      final status = _normStatus((data['status'] ?? '').toString());
      if (status != AppConstants.bookingAwaitingConfirmation) {
        throw Exception('Can only dispute from awaiting_confirmation.');
      }
      fundiId    = (data['fundiId']    ?? '').toString();
      fundiName  = (data['fundiName']  ?? 'Fundi').toString();
      clientId   = (data['clientId']   ?? '').toString();
      clientName = (data['clientName'] ?? 'Client').toString();
      txn.update(bookingRef, {
        'status':              AppConstants.bookingCompletionDisputed,
        'completionDisputed':  true,
        'disputeReason':       reason,
        'disputedAt':          ts,
        'adminReviewRequired': true,
        'updatedAt':           ts,
      });
    });

    if (fundiId != null && fundiId!.isNotEmpty) {
      final batch = _db.batch();
      _batchNotif(
        batch:      batch,
        receiverId: fundiId!,
        senderId:   clientId ?? '',
        title:      'Completion Disputed ⚠️',
        body:       '${clientName ?? 'Client'} reported a problem with the job completion.',
        type:       'completion_disputed',
        bookingId:  bookingId,
      );
      await batch.commit();
    }

    // Keep chat OPEN during dispute
    await _updateChatStatus(bookingId, AppConstants.bookingCompletionDisputed);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY: agreement methods (kept so old bookings still work)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> clientAgree(String bookingId) async {
    final ts         = FieldValue.serverTimestamp();
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    bool fundiAlreadyAgreed = false;
    String? fundiId, fundiName, clientId, clientName;

    await _db.runTransaction((txn) async {
      final snap = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data = snap.data()!;
      fundiAlreadyAgreed = data['fundiAgreed'] == true;
      fundiId    = (data['fundiId']    ?? '').toString();
      fundiName  = (data['fundiName']  ?? 'Fundi').toString();
      clientId   = (data['clientId']   ?? '').toString();
      clientName = (data['clientName'] ?? 'Client').toString();
      txn.update(bookingRef, {'clientAgreed': true, 'updatedAt': ts});
    });

    if (fundiAlreadyAgreed) {
      await _onBothAgreed(bookingId, clientId!, fundiId!, clientName!, fundiName!);
    }
  }

  Future<void> fundiAgree(String bookingId) async {
    final ts         = FieldValue.serverTimestamp();
    final bookingRef = _db.collection(FirestoreConstants.bookings).doc(bookingId);
    bool clientAlreadyAgreed = false;
    String? fundiId, fundiName, clientId, clientName;

    await _db.runTransaction((txn) async {
      final snap = await txn.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found.');
      final data = snap.data()!;
      clientAlreadyAgreed = data['clientAgreed'] == true;
      fundiId    = (data['fundiId']    ?? '').toString();
      fundiName  = (data['fundiName']  ?? 'Fundi').toString();
      clientId   = (data['clientId']   ?? '').toString();
      clientName = (data['clientName'] ?? 'Client').toString();
      txn.update(bookingRef, {'fundiAgreed': true, 'updatedAt': ts});
    });

    if (clientAlreadyAgreed) {
      await _onBothAgreed(bookingId, clientId!, fundiId!, clientName!, fundiName!);
    }
  }

  Future<void> _onBothAgreed(String bookingId, String clientId, String fundiId,
      String clientName, String fundiName) async {
    final batch = _db.batch();
    batch.update(
      _db.collection(FirestoreConstants.bookings).doc(bookingId),
      {
        'status':               AppConstants.bookingAgreementConfirmed,
        'agreementConfirmedAt': FieldValue.serverTimestamp(),
        'contactUnlocked':      true,
        'updatedAt':            FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    await _updateChatStatus(bookingId, AppConstants.bookingAgreementConfirmed,
        contactUnlocked: true);
  }

  // LEGACY: markCompleted → forwards to requestCompletion
  Future<void> markCompleted(String bookingId) => requestCompletion(bookingId);

  // ─────────────────────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────────────────────
  Stream<List<BookingModel>> clientBookingsStream(String clientId) => _db
      .collection(FirestoreConstants.bookings)
      .where('clientId', isEqualTo: clientId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BookingModel.fromMap(_normalizeDoc(d.data())))
          .toList());

  Stream<List<BookingModel>> fundiBookingsStream(String fundiId) => _db
      .collection(FirestoreConstants.bookings)
      .where('fundiId', isEqualTo: fundiId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BookingModel.fromMap(_normalizeDoc(d.data())))
          .toList());

  Stream<BookingModel?> bookingStream(String bookingId) => _db
      .collection(FirestoreConstants.bookings)
      .doc(bookingId)
      .snapshots()
      .map((d) =>
          d.exists ? BookingModel.fromMap(_normalizeDoc(d.data()!)) : null);

  Future<BookingModel?> getBooking(String bookingId) async {
    final d = await _db
        .collection(FirestoreConstants.bookings)
        .doc(bookingId)
        .get();
    return d.exists ? BookingModel.fromMap(_normalizeDoc(d.data()!)) : null;
  }

  Stream<int> fundiPendingCountStream(String fundiId) => _db
      .collection(FirestoreConstants.bookings)
      .where('fundiId', isEqualTo: fundiId)
      .where('status',  isEqualTo: AppConstants.bookingPending)
      .snapshots()
      .map((s) => s.docs.length);

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _normalizeDoc(Map<String, dynamic> data) {
    final raw        = data['status']?.toString() ?? '';
    final normalised = _normStatus(raw);
    if (normalised != raw) {
      dev.log('[BookingService] normalising "$raw" → "$normalised"', name: 'BOOKING');
      return {...data, 'status': normalised};
    }
    return data;
  }

  Future<void> _initChat(String bookingId, String clientId, String fundiId,
      String clientName, String fundiName) async {
    final ts = FieldValue.serverTimestamp();
    await _db.collection(FirestoreConstants.chats).doc(bookingId).set({
      'chatId':          bookingId,
      'bookingId':       bookingId,
      'clientId':        clientId,
      'fundiId':         fundiId,
      'clientName':      clientName,
      'fundiName':       fundiName,
      'participants':    [clientId, fundiId],
      'unreadCounts':    {clientId: 0, fundiId: 0},
      'unreadCount':     0,
      'lastMessage':     'Chat opened',
      'lastMessageType': 'text',
      'lastMessageAt':   ts,
      'lastSenderId':    '',
      'contactUnlocked': true,
      'chatLocked':      false,
      'bookingStatus':   AppConstants.bookingAccepted,
      'type':            'booking',
      'createdAt':       ts,
      'updatedAt':       ts,
    }, SetOptions(merge: true));
  }

  Future<void> _updateChatStatus(
    String bookingId,
    String status, {
    bool? contactUnlocked,
  }) async {
    try {
      final locked   = !_chatOpenStatuses.contains(status);
      final lockMsg  = locked ? _lockMessage(status) : null;
      await _db.collection(FirestoreConstants.chats).doc(bookingId).set({
        'bookingStatus':    status,
        'chatLocked':       locked,
        'chatLockedReason': lockMsg,
        if (contactUnlocked != null) 'contactUnlocked': contactUnlocked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _lockMessage(String status) {
    switch (status) {
      case AppConstants.bookingCompleted:  return 'Job completed.';
      case AppConstants.bookingCancelled:  return 'Booking cancelled.';
      case AppConstants.bookingRejected:   return 'Booking rejected.';
      case AppConstants.bookingExpired:    return 'Booking expired.';
      case AppConstants.bookingPending:    return 'Chat opens after the fundi accepts.';
      default:                             return 'Chat is closed.';
    }
  }

  Future<bool> _isBlocked(String a, String b) async {
    try {
      final q1 = await _db.collection('blocks')
          .where('blockerId', isEqualTo: a)
          .where('blockedId',  isEqualTo: b)
          .limit(1).get();
      if (q1.docs.isNotEmpty) return true;
      final q2 = await _db.collection('blocks')
          .where('blockerId', isEqualTo: b)
          .where('blockedId',  isEqualTo: a)
          .limit(1).get();
      return q2.docs.isNotEmpty;
    } catch (_) { return false; }
  }
}
