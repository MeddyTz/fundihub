import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/payment_model.dart';
import '../models/subscription_model.dart';
import '../models/user_model.dart';

/// PaymentService — Phase 1 Production-Safe Version
///
/// ALL three payment types now go through the same flow:
///   1. Flutter creates a payment doc with status = "submitted".
///   2. Admin confirms/rejects in the admin panel.
///   3. onPaymentWrite Cloud Function applies unlocks after confirmation.
///
/// Removed:
///   - Auto-confirm promotion (MOCK BOOST MODE bypass).
///   - Client-side wallet writes (blocked by new Firestore rules).
///   - Client-side user.plan writes for subscription (done by CF).
class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────
  // INTERNAL: create a payment doc with status = submitted.
  // Deduplicates — returns existing payment ID if one is already pending.
  // ─────────────────────────────────────────────────────────

  Future<String> _createPayment({
    required UserModel fundi,
    required String type,
    required int amount,
    required String ref,
    String? bookingId,
    int? durationDays,
  }) async {
    // Prevent duplicate pending payments for the same type.
    final existing = await getPendingSubmittedPayment(fundi.uid, type);
    if (existing != null) return existing.paymentId;

    final r = _db.collection(FirestoreConstants.payments).doc();
    final now = DateTime.now();

    final safeRef = ref.trim().isEmpty
        ? 'PENDING-${now.millisecondsSinceEpoch}'
        : ref.trim();

    final p = PaymentModel(
      paymentId: r.id,
      fundiId: fundi.uid,
      fundiName: fundi.fullName,
      fundiPhone: fundi.phone,
      paymentType: type,
      amount: amount,
      referenceNumber: safeRef,
      status: AppConstants.paymentSubmitted,
      relatedBookingId: bookingId,
      provider: 'manual',
      submittedAt: now,
      updatedAt: now,
    );

    final data = p.toMap();
    if (durationDays != null) data['durationDays'] = durationDays;
    await r.set(data);
    return r.id;
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC SUBMIT METHODS
  // ─────────────────────────────────────────────────────────

  Future<String> submitJobFeePayment({
    required UserModel fundi,
    required String referenceNumber,
    String? relatedBookingId,
  }) =>
      _createPayment(
        fundi: fundi,
        type: AppConstants.paymentJobFee,
        amount: AppConstants.jobCompletionFee,
        ref: referenceNumber,
        bookingId: relatedBookingId,
      );

  Future<String> submitSubscriptionPayment({
    required UserModel fundi,
    required String referenceNumber,
  }) =>
      _createPayment(
        fundi: fundi,
        type: AppConstants.paymentSubscription,
        amount: AppConstants.premiumSubscriptionFee,
        ref: referenceNumber,
      );

  /// Promotion: goes to submitted — admin must confirm before boost activates.
  Future<String> submitPromotionPayment({
    required UserModel fundi,
    required String referenceNumber,
    required int amount,
    required int durationDays,
  }) =>
      _createPayment(
        fundi: fundi,
        type: AppConstants.paymentPromotion,
        amount: amount,
        ref: referenceNumber,
        durationDays: durationDays,
      );

  // ─────────────────────────────────────────────────────────
  // ADMIN CONFIRM / REJECT
  // Updates payment doc status — onPaymentWrite CF handles the rest.
  // ─────────────────────────────────────────────────────────

  Future<void> confirmJobFeePayment({
    required String paymentId,
    required String fundiId,
    required String adminUid,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _db.collection(FirestoreConstants.payments).doc(paymentId).update({
      'status': AppConstants.paymentConfirmed,
      'confirmedBy': adminUid,
      'confirmedAt': now,
      'updatedAt': now,
    });
    // Wallet unlock done by onPaymentWrite Cloud Function.
  }

  Future<void> confirmSubscriptionPayment({
    required String paymentId,
    required String fundiId,
    required String fundiName,
    required String adminUid,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _db.collection(FirestoreConstants.payments).doc(paymentId).update({
      'status': AppConstants.paymentConfirmed,
      'confirmedBy': adminUid,
      'confirmedAt': now,
      'updatedAt': now,
    });
    // Premium activation done by onPaymentWrite Cloud Function.
  }

  Future<void> confirmPromotionPayment({
    required String paymentId,
    required String fundiId,
    required String adminUid,
    required int durationDays,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _db.collection(FirestoreConstants.payments).doc(paymentId).update({
      'status': AppConstants.paymentConfirmed,
      'durationDays': durationDays,
      'confirmedBy': adminUid,
      'confirmedAt': now,
      'updatedAt': now,
    });
    // Promotion activation done by onPaymentWrite Cloud Function.
  }

  Future<void> rejectPayment({
    required String paymentId,
    required String fundiId,
    required String adminUid,
    required String reason,
    required String paymentType,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _db.collection(FirestoreConstants.payments).doc(paymentId).update({
      'status': AppConstants.paymentRejected,
      'rejectionReason': reason,
      'confirmedBy': adminUid,
      'updatedAt': now,
    });
  }

  // ─────────────────────────────────────────────────────────
  // STREAMS / QUERIES
  // ─────────────────────────────────────────────────────────

  Stream<List<PaymentModel>> fundiPaymentsStream(String fundiId) => _db
      .collection(FirestoreConstants.payments)
      .where('fundiId', isEqualTo: fundiId)
      .orderBy('submittedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentModel.fromMap(d.data())).toList());

  Stream<List<PaymentModel>> allPendingPaymentsStream() => _db
      .collection(FirestoreConstants.payments)
      .where('status', whereIn: [
        AppConstants.paymentPending,
        AppConstants.paymentSubmitted,
      ])
      .orderBy('submittedAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentModel.fromMap(d.data())).toList());

  Future<PaymentModel?> getPendingSubmittedPayment(
      String fundiId, String type) async {
    final s = await _db
        .collection(FirestoreConstants.payments)
        .where('fundiId', isEqualTo: fundiId)
        .where('paymentType', isEqualTo: type)
        .where('status', whereIn: [
          AppConstants.paymentPending,
          AppConstants.paymentSubmitted,
        ])
        .limit(1)
        .get();
    return s.docs.isEmpty ? null : PaymentModel.fromMap(s.docs.first.data());
  }

  Future<SubscriptionModel?> getActiveSubscription(String fundiId) async {
    final s = await _db
        .collection(FirestoreConstants.subscriptions)
        .where('fundiId', isEqualTo: fundiId)
        .where('isActive', isEqualTo: true)
        .orderBy('endDate', descending: true)
        .limit(1)
        .get();
    return s.docs.isEmpty
        ? null
        : SubscriptionModel.fromMap(s.docs.first.data());
  }
}
