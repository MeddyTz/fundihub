import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String userId;
  final String title;
  final String body;
  final String type; // booking_request | booking_accepted | booking_rejected |
  //                    booking_cancelled | job_completed | agreement | payment |
  //                    message | chat | system | boost | premium
  final String? relatedId;
  final String? chatId;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.notifId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.chatId,
    this.bookingId,
    required this.isRead,
    required this.createdAt,
  });

  /// Derived: best available linked ID for navigation.
  String? get navigationId =>
      relatedId?.trim().isNotEmpty == true
          ? relatedId
          : chatId?.trim().isNotEmpty == true
              ? chatId
              : bookingId?.trim().isNotEmpty == true
                  ? bookingId
                  : null;

  bool get isBookingType {
    final t = type.toLowerCase();
    return t.contains('booking') ||
        t.contains('job') ||
        t.contains('agreement') ||
        t.contains('accepted') ||
        t.contains('rejected') ||
        t.contains('cancelled') ||
        t.contains('completed') ||
        t.contains('in_progress') ||
        t.contains('started') ||
        t.contains('completion_requested') ||
        t.contains('awaiting') ||
        t.contains('disputed') ||
        t.contains('review');
  }

  bool get isChatType {
    final t = type.toLowerCase();
    return t.contains('message') || t.contains('chat');
  }

  bool get isPaymentType {
    final t = type.toLowerCase();
    return t.contains('payment') ||
        t.contains('fee') ||
        t.contains('wallet') ||
        t.contains('boost') ||
        t.contains('premium');
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final rawRelated = (map['relatedId'] ?? '').toString().trim();
    final rawChat = (map['chatId'] ?? '').toString().trim();
    final rawBooking = (map['bookingId'] ?? '').toString().trim();

    // Best single relatedId: prefer explicit relatedId, then chatId, then bookingId
    final bestRelated = rawRelated.isNotEmpty
        ? rawRelated
        : rawChat.isNotEmpty
            ? rawChat
            : rawBooking.isNotEmpty
                ? rawBooking
                : null;

    return NotificationModel(
      notifId: (map['notifId'] ?? map['notificationId'] ?? map['id'] ?? '')
          .toString(),
      userId:
          (map['userId'] ?? map['receiverId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? map['message'] ?? '').toString(),
      type: (map['type'] ?? 'system').toString(),
      relatedId: bestRelated,
      chatId: rawChat.isNotEmpty ? rawChat : null,
      bookingId: rawBooking.isNotEmpty ? rawBooking : null,
      isRead: map['isRead'] == true || map['read'] == true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'notifId': notifId,
        'userId': userId,
        'title': title,
        'body': body,
        'message': body,
        'type': type,
        'relatedId': relatedId,
        if (chatId != null) 'chatId': chatId,
        if (bookingId != null) 'bookingId': bookingId,
        'isRead': isRead,
        'read': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
