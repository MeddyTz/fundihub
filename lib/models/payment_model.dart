import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class PaymentModel {
  final String paymentId;
  final String fundiId;
  final String fundiName;
  final String fundiPhone;
  final String paymentType;
  final int amount;
  final String referenceNumber;
  final String status;

  final String? rejectionReason;
  final String? adminNote;
  final String? confirmedBy;
  final String? relatedBookingId;

  // Selcom / provider metadata. These are optional so old manual records still work.
  final String provider;
  final String? providerStatus;
  final String? providerOrderId;
  final String? providerTransactionId;
  final String? checkoutUrl;
  final String? paymentMethod;
  final String? channel;
  final String? customerPhone;
  final String? callbackReference;

  final DateTime submittedAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? expiresAt;

  const PaymentModel({
    required this.paymentId,
    required this.fundiId,
    required this.fundiName,
    required this.fundiPhone,
    required this.paymentType,
    required this.amount,
    required this.referenceNumber,
    required this.status,
    this.rejectionReason,
    this.adminNote,
    this.confirmedBy,
    this.relatedBookingId,
    this.provider = 'manual',
    this.providerStatus,
    this.providerOrderId,
    this.providerTransactionId,
    this.checkoutUrl,
    this.paymentMethod,
    this.channel,
    this.customerPhone,
    this.callbackReference,
    required this.submittedAt,
    this.confirmedAt,
    this.expiresAt,
    required this.updatedAt,
  });

  bool get isPending => status == AppConstants.paymentPending;
  bool get isSubmitted => status == AppConstants.paymentSubmitted;
  bool get isConfirmed => status == AppConstants.paymentConfirmed;
  bool get isRejected => status == AppConstants.paymentRejected;
  bool get isSelcom => provider.toLowerCase() == 'selcom';
  bool get canOpenCheckout => checkoutUrl != null && checkoutUrl!.trim().isNotEmpty;

  String get typeLabel {
    switch (paymentType) {
      case AppConstants.paymentJobFee:
        return 'Job Completion Fee';
      case AppConstants.paymentSubscription:
        return 'Premium Subscription';
      case AppConstants.paymentPromotion:
        return 'Profile Promotion';
      default:
        return paymentType;
    }
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['paymentId'] ?? '',
      fundiId: map['fundiId'] ?? '',
      fundiName: map['fundiName'] ?? '',
      fundiPhone: map['fundiPhone'] ?? '',
      paymentType: map['paymentType'] ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      referenceNumber: map['referenceNumber'] ?? map['providerOrderId'] ?? '',
      status: map['status'] ?? AppConstants.paymentSubmitted,
      rejectionReason: map['rejectionReason'],
      adminNote: map['adminNote'],
      confirmedBy: map['confirmedBy'],
      relatedBookingId: map['relatedBookingId'],
      provider: map['provider'] ?? 'manual',
      providerStatus: map['providerStatus'],
      providerOrderId: map['providerOrderId'],
      providerTransactionId: map['providerTransactionId'],
      checkoutUrl: map['checkoutUrl'] ?? map['paymentUrl'],
      paymentMethod: map['paymentMethod'],
      channel: map['channel'],
      customerPhone: map['customerPhone'],
      callbackReference: map['callbackReference'],
      submittedAt: map['submittedAt'] is Timestamp
          ? (map['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
      confirmedAt: map['confirmedAt'] is Timestamp
          ? (map['confirmedAt'] as Timestamp).toDate()
          : null,
      expiresAt: map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'fundiId': fundiId,
      'fundiName': fundiName,
      'fundiPhone': fundiPhone,
      'paymentType': paymentType,
      'amount': amount,
      'referenceNumber': referenceNumber,
      'status': status,
      'rejectionReason': rejectionReason,
      'adminNote': adminNote,
      'confirmedBy': confirmedBy,
      'relatedBookingId': relatedBookingId,
      'provider': provider,
      'providerStatus': providerStatus,
      'providerOrderId': providerOrderId,
      'providerTransactionId': providerTransactionId,
      'checkoutUrl': checkoutUrl,
      'paymentMethod': paymentMethod,
      'channel': channel,
      'customerPhone': customerPhone,
      'callbackReference': callbackReference,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
