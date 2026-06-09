import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class BookingModel {
  final String bookingId, clientId, clientName, clientPhone,
      fundiId, fundiName, fundiPhone, fundiCategory,
      serviceDescription, locationRegion, locationDistrict,
      locationArea, status;

  final String? clientProfileImage, fundiProfileImage,
      locationDetails, rejectionReason, cancellationReason,
      cancelledBy, chatId, locationDetectedAddress, agreedPrice,
      disputeReason;

  final double? locationLat, locationLng;

  final bool clientAgreed, fundiAgreed, jobFeeCharged, jobFeePaid,
      contactUnlocked;

  // ── New fields for the completion flow ───────────────────────────────────
  final bool completionRequested;
  final bool clientConfirmedCompletion;
  final bool completionDisputed;
  final bool jobsDoneCounted;
  final bool adminReviewRequired;

  final DateTime? acceptedAt, agreedAt, startedAt, completedAt,
      rejectedAt, cancelledAt, expiredAt,
      completionRequestedAt, completedByFundiAt,
      clientConfirmedCompletionAt, disputedAt;

  final DateTime createdAt, updatedAt;

  const BookingModel({
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.clientProfileImage,
    required this.fundiId,
    required this.fundiName,
    required this.fundiPhone,
    this.fundiProfileImage,
    required this.fundiCategory,
    required this.serviceDescription,
    required this.locationRegion,
    required this.locationDistrict,
    required this.locationArea,
    this.locationDetails,
    this.locationLat,
    this.locationLng,
    this.locationDetectedAddress,
    required this.status,
    this.rejectionReason,
    this.cancellationReason,
    this.cancelledBy,
    this.disputeReason,
    required this.clientAgreed,
    required this.fundiAgreed,
    this.acceptedAt,
    this.agreedAt,
    this.startedAt,
    this.completedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.expiredAt,
    this.completionRequestedAt,
    this.completedByFundiAt,
    this.clientConfirmedCompletionAt,
    this.disputedAt,
    required this.jobFeeCharged,
    required this.jobFeePaid,
    this.chatId,
    required this.contactUnlocked,
    this.agreedPrice,
    this.completionRequested         = false,
    this.clientConfirmedCompletion   = false,
    this.completionDisputed          = false,
    this.jobsDoneCounted             = false,
    this.adminReviewRequired         = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Status getters ────────────────────────────────────────────────────────
  bool get isPending              => status == AppConstants.bookingPending;
  bool get isAccepted             => status == AppConstants.bookingAccepted;
  bool get isAgreementConfirmed   => status == AppConstants.bookingAgreementConfirmed;
  bool get isInProgress           => status == AppConstants.bookingInProgress;
  bool get isAwaitingConfirmation => status == AppConstants.bookingAwaitingConfirmation;
  bool get isCompletionDisputed   => status == AppConstants.bookingCompletionDisputed;
  bool get isCompleted            => status == AppConstants.bookingCompleted;
  bool get isRejected             => status == AppConstants.bookingRejected;
  bool get isCancelled            => status == AppConstants.bookingCancelled;
  bool get isExpired              => status == AppConstants.bookingExpired;

  /// Active = anything the fundi is still working on
  bool get isActive =>
      isAccepted ||
      isAgreementConfirmed ||
      isInProgress ||
      isAwaitingConfirmation ||
      isCompletionDisputed;

  /// Finished = permanently closed
  bool get isFinished =>
      isCompleted || isRejected || isCancelled || isExpired;

  bool get bothAgreed => clientAgreed && fundiAgreed;

  // ── Contact visibility rule (new model) ───────────────────────────────────
  /// Contacts visible immediately after fundi accepts — no agreement required.
  bool get shouldShowContact => AppConstants.isContactUnlocked(status);

  /// Chat open while job is active.
  bool get shouldShowChat => AppConstants.isChatOpen(status);

  // ── Factory ───────────────────────────────────────────────────────────────
  factory BookingModel.fromMap(Map<String, dynamic> map) => BookingModel(
        bookingId:               _s(map['bookingId']),
        clientId:                _s(map['clientId']),
        clientName:              _s(map['clientName']),
        clientPhone:             _s(map['clientPhone']),
        clientProfileImage:      map['clientProfileImage']?.toString(),
        fundiId:                 _s(map['fundiId']),
        fundiName:               _s(map['fundiName']),
        fundiPhone:              _s(map['fundiPhone']),
        fundiProfileImage:       map['fundiProfileImage']?.toString(),
        fundiCategory:           _s(map['fundiCategory']),
        serviceDescription:      _s(map['serviceDescription']),
        locationRegion:          _s(map['locationRegion']),
        locationDistrict:        _s(map['locationDistrict']),
        locationArea:            _s(map['locationArea']),
        locationDetails:         map['locationDetails']?.toString(),
        locationLat:             (map['locationLat'] as num?)?.toDouble(),
        locationLng:             (map['locationLng'] as num?)?.toDouble(),
        locationDetectedAddress: map['locationDetectedAddress']?.toString(),
        status:                  _s(map['status'], AppConstants.bookingPending),
        rejectionReason:         map['rejectionReason']?.toString(),
        cancellationReason:      map['cancellationReason']?.toString(),
        cancelledBy:             map['cancelledBy']?.toString(),
        disputeReason:           map['disputeReason']?.toString(),
        clientAgreed:            map['clientAgreed'] == true,
        fundiAgreed:             map['fundiAgreed']  == true,
        acceptedAt:              _ts(map['acceptedAt']),
        agreedAt:                _ts(map['agreedAt']),
        startedAt:               _ts(map['startedAt']),
        completedAt:             _ts(map['completedAt']),
        rejectedAt:              _ts(map['rejectedAt']),
        cancelledAt:             _ts(map['cancelledAt']),
        expiredAt:               _ts(map['expiredAt']),
        completionRequestedAt:   _ts(map['completionRequestedAt']),
        completedByFundiAt:      _ts(map['completedByFundiAt']),
        clientConfirmedCompletionAt: _ts(map['clientConfirmedCompletionAt']),
        disputedAt:              _ts(map['disputedAt']),
        jobFeeCharged:           map['jobFeeCharged'] == true,
        jobFeePaid:              map['jobFeePaid']    == true,
        chatId:                  map['chatId']?.toString(),
        contactUnlocked:         map['contactUnlocked'] == true,
        agreedPrice:             map['agreedPrice']?.toString(),
        completionRequested:     map['completionRequested'] == true,
        clientConfirmedCompletion: map['clientConfirmedCompletion'] == true,
        completionDisputed:      map['completionDisputed'] == true,
        jobsDoneCounted:         map['jobsDoneCounted'] == true,
        adminReviewRequired:     map['adminReviewRequired'] == true,
        createdAt:               _ts(map['createdAt']) ?? DateTime.now(),
        updatedAt:               _ts(map['updatedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'bookingId':         bookingId,
        'clientId':          clientId,
        'clientName':        clientName,
        'clientPhone':       clientPhone,
        'clientProfileImage':clientProfileImage,
        'fundiId':           fundiId,
        'fundiName':         fundiName,
        'fundiPhone':        fundiPhone,
        'fundiProfileImage': fundiProfileImage,
        'fundiCategory':     fundiCategory,
        'serviceDescription':serviceDescription,
        'locationRegion':    locationRegion,
        'locationDistrict':  locationDistrict,
        'locationArea':      locationArea,
        'locationDetails':   locationDetails,
        'locationLat':       locationLat,
        'locationLng':       locationLng,
        'locationDetectedAddress': locationDetectedAddress,
        'status':            status,
        'rejectionReason':   rejectionReason,
        'cancellationReason':cancellationReason,
        'cancelledBy':       cancelledBy,
        'disputeReason':     disputeReason,
        'clientAgreed':      clientAgreed,
        'fundiAgreed':       fundiAgreed,
        'acceptedAt':        acceptedAt   != null ? Timestamp.fromDate(acceptedAt!)   : null,
        'agreedAt':          agreedAt     != null ? Timestamp.fromDate(agreedAt!)     : null,
        'startedAt':         startedAt    != null ? Timestamp.fromDate(startedAt!)    : null,
        'completedAt':       completedAt  != null ? Timestamp.fromDate(completedAt!)  : null,
        'rejectedAt':        rejectedAt   != null ? Timestamp.fromDate(rejectedAt!)   : null,
        'cancelledAt':       cancelledAt  != null ? Timestamp.fromDate(cancelledAt!)  : null,
        'expiredAt':         expiredAt    != null ? Timestamp.fromDate(expiredAt!)    : null,
        'completionRequestedAt': completionRequestedAt != null
            ? Timestamp.fromDate(completionRequestedAt!) : null,
        'completedByFundiAt': completedByFundiAt != null
            ? Timestamp.fromDate(completedByFundiAt!) : null,
        'clientConfirmedCompletionAt': clientConfirmedCompletionAt != null
            ? Timestamp.fromDate(clientConfirmedCompletionAt!) : null,
        'disputedAt':        disputedAt   != null ? Timestamp.fromDate(disputedAt!)   : null,
        'jobFeeCharged':     jobFeeCharged,
        'jobFeePaid':        jobFeePaid,
        'chatId':            chatId,
        'contactUnlocked':   contactUnlocked,
        'completionRequested':          completionRequested,
        'clientConfirmedCompletion':    clientConfirmedCompletion,
        'completionDisputed':           completionDisputed,
        'jobsDoneCounted':              jobsDoneCounted,
        'adminReviewRequired':          adminReviewRequired,
        if (agreedPrice != null && agreedPrice!.isNotEmpty) 'agreedPrice': agreedPrice,
        'createdAt':  Timestamp.fromDate(createdAt),
        'updatedAt':  Timestamp.fromDate(updatedAt),
      };

  static String   _s(dynamic v, [String d = '']) => v?.toString() ?? d;
  static DateTime? _ts(dynamic v) =>
      v is Timestamp ? v.toDate() : null;
}
