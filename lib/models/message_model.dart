import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String senderName;
  final String type;
  final String? text;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDurationMs;
  final String? locationLabel;
  final double? locationLat;
  final double? locationLng;
  final bool isSeen;
  final bool isDelivered;
  final bool isDeleted;
  final DateTime createdAt;

  const MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.text,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDurationMs,
    this.locationLat,
    this.locationLng,
    this.locationLabel,
    required this.isSeen,
    required this.isDelivered,
    required this.isDeleted,
    required this.createdAt,
  });

  bool get isText => type == AppConstants.msgText;
  bool get isImage => type == AppConstants.msgImage;
  bool get isVoice => type == AppConstants.msgVoice;
  bool get isLocation => type == AppConstants.msgLocation;

  MessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? senderName,
    String? type,
    String? text,
    String? imageUrl,
    String? voiceUrl,
    int? voiceDurationMs,
    double? locationLat,
    double? locationLng,
    String? locationLabel,
    bool? isSeen,
    bool? isDelivered,
    bool? isDeleted,
    DateTime? createdAt,
  }) =>
      MessageModel(
        messageId: messageId ?? this.messageId,
        chatId: chatId ?? this.chatId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        type: type ?? this.type,
        text: text ?? this.text,
        imageUrl: imageUrl ?? this.imageUrl,
        voiceUrl: voiceUrl ?? this.voiceUrl,
        voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
        locationLat: locationLat ?? this.locationLat,
        locationLng: locationLng ?? this.locationLng,
        locationLabel: locationLabel ?? this.locationLabel,
        isSeen: isSeen ?? this.isSeen,
        isDelivered: isDelivered ?? this.isDelivered,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
      );

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        messageId: _str(map['messageId'] ?? map['id']),
        chatId: _str(map['chatId']),
        senderId: _str(map['senderId']),
        senderName: _str(map['senderName']),
        type: _str(map['type']).isEmpty ? AppConstants.msgText : _str(map['type']),
        text: _nullableStr(map['text']),
        imageUrl: _nullableStr(map['imageUrl']),
        voiceUrl: _nullableStr(map['voiceUrl']),
        voiceDurationMs: (map['voiceDurationMs'] as num?)?.toInt(),
        locationLat: (map['locationLat'] as num?)?.toDouble(),
        locationLng: (map['locationLng'] as num?)?.toDouble(),
        locationLabel: _nullableStr(map['locationLabel']),
        isSeen: map['isSeen'] == true,
        isDelivered: map['isDelivered'] != false,
        isDeleted: map['isDeleted'] == true,
        createdAt: _date(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'type': type,
        'text': text,
        'imageUrl': imageUrl,
        'voiceUrl': voiceUrl,
        'voiceDurationMs': voiceDurationMs,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'locationLabel': locationLabel,
        'isSeen': isSeen,
        'isDelivered': isDelivered,
        'isDeleted': isDeleted,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─────────────────────────────────────────────────────────
// ChatSummary
// ─────────────────────────────────────────────────────────

class ChatSummary {
  final String chatId;
  final String bookingId;
  final String clientId;
  final String clientName;
  final String fundiId;
  final String fundiName;
  final String lastMessage;
  final String lastMessageType;
  final String lastSenderId;
  final String? clientImageUrl;
  final String? fundiImageUrl;
  final DateTime lastMessageAt;
  final int unreadCount;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> lastReadAt;
  final bool contactUnlocked;
  final String bookingStatus;
  final bool chatLocked;
  final String? chatLockedReason;

  const ChatSummary({
    required this.chatId,
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    this.clientImageUrl,
    required this.fundiId,
    required this.fundiName,
    this.fundiImageUrl,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    required this.contactUnlocked,
    required this.bookingStatus,
    required this.chatLocked,
    this.chatLockedReason,
  });

  ChatSummary copyWith({
    String? chatId,
    String? bookingId,
    String? clientId,
    String? clientName,
    String? fundiId,
    String? fundiName,
    String? lastMessage,
    String? lastMessageType,
    String? lastSenderId,
    String? clientImageUrl,
    String? fundiImageUrl,
    DateTime? lastMessageAt,
    int? unreadCount,
    Map<String, int>? unreadCounts,
    Map<String, DateTime>? lastReadAt,
    bool? contactUnlocked,
    String? bookingStatus,
    bool? chatLocked,
    String? chatLockedReason,
  }) =>
      ChatSummary(
        chatId: chatId ?? this.chatId,
        bookingId: bookingId ?? this.bookingId,
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        clientImageUrl: clientImageUrl ?? this.clientImageUrl,
        fundiId: fundiId ?? this.fundiId,
        fundiName: fundiName ?? this.fundiName,
        fundiImageUrl: fundiImageUrl ?? this.fundiImageUrl,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageType: lastMessageType ?? this.lastMessageType,
        lastSenderId: lastSenderId ?? this.lastSenderId,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        contactUnlocked: contactUnlocked ?? this.contactUnlocked,
        bookingStatus: bookingStatus ?? this.bookingStatus,
        chatLocked: chatLocked ?? this.chatLocked,
        chatLockedReason: chatLockedReason ?? this.chatLockedReason,
      );

  bool get isChatOpen {
    final s = bookingStatus.toLowerCase().trim();
    return !chatLocked &&
        (s == AppConstants.bookingAccepted ||
            s == AppConstants.bookingAgreementConfirmed ||
            s == AppConstants.bookingInProgress ||
            s == 'active' ||
            s == 'direct');
  }

  String get lockMessage {
    if (chatLockedReason != null && chatLockedReason!.trim().isNotEmpty) {
      return chatLockedReason!;
    }
    switch (bookingStatus.toLowerCase().trim()) {
      case AppConstants.bookingCompleted:
        return 'Conversation closed because this job is completed.';
      case AppConstants.bookingCancelled:
        return 'Conversation closed because this booking was cancelled.';
      case AppConstants.bookingRejected:
        return 'Conversation closed because this booking was rejected.';
      case AppConstants.bookingExpired:
        return 'Conversation closed because this booking expired.';
      case AppConstants.bookingPending:
        return 'Chat opens after the fundi accepts this booking.';
      default:
        return 'Chat is closed for this booking.';
    }
  }

  /// Returns the unread count for [userId] using the most reliable source.
  ///
  /// This method is intentionally defensive because older chat documents in
  /// FundiHub were created before the `unreadCounts.{uid}` map existed. In
  /// those legacy cases, a new message notification can exist while the chat
  /// row still has `unreadCounts[uid] == 0` or no unread map at all. The final
  /// fallback therefore treats the last message as unread when it was sent by
  /// the other user and the current user has not read after that timestamp.
  int unreadCountFor(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return 0;

    final lastRead = lastReadAt[uid];
    final lastMessageFromOther = lastSenderId.isNotEmpty && lastSenderId != uid;
    final notReadAfterLastMessage =
        lastRead == null || lastMessageAt.isAfter(lastRead);

    // Primary: explicit per-user unreadCounts map.
    // IMPORTANT: when a chat is opened we set unreadCounts.{uid} = 0.
    // Once that key exists we must TRUST it, otherwise the legacy fallback can
    // keep showing a badge after the user has already read the message.
    if (unreadCounts.containsKey(uid)) {
      final val = unreadCounts[uid] ?? 0;
      return val < 0 ? 0 : val;
    }

    // Legacy fallback: numeric unreadCount with time check.
    if (lastMessageFromOther && unreadCount > 0 && notReadAfterLastMessage) {
      return unreadCount;
    }

    // Final fallback: last message from the other person and no read timestamp.
    if (lastMessageFromOther && notReadAfterLastMessage) return 1;

    return 0;
  }

  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    final rawId = _str(map['id'] ?? map['chatId']);
    final bookingId = _str(map['bookingId']);
    // chatId: prefer explicit field, fall back to doc id, then bookingId.
    final chatId =
        rawId.isNotEmpty ? rawId : (bookingId.isNotEmpty ? bookingId : '');

    final rawStatus =
        _str(map['bookingStatus'] ?? map['booking_status'] ?? map['status']);
    // Treat 'active' and 'direct' as an open status.
    final normalizedStatus = (rawStatus == 'active' ||
            rawStatus == 'direct' ||
            rawStatus.isEmpty)
        ? AppConstants.bookingAccepted
        : rawStatus;

    return ChatSummary(
      chatId: chatId,
      bookingId: bookingId.isNotEmpty ? bookingId : chatId,
      clientId: _str(map['clientId'] ?? map['clientUserId'] ?? map['userId']),
      clientName: _str(map['clientName'] ?? map['userName']).isEmpty
          ? 'Client'
          : _str(map['clientName'] ?? map['userName']),
      clientImageUrl:
          _nullableStr(map['clientImageUrl'] ?? map['clientProfileImage']),
      fundiId: _str(map['fundiId'] ?? map['fundiUserId']),
      fundiName:
          _str(map['fundiName']).isEmpty ? 'Fundi' : _str(map['fundiName']),
      fundiImageUrl:
          _nullableStr(map['fundiImageUrl'] ?? map['fundiProfileImage']),
      lastMessage: _str(map['lastMessage']),
      lastMessageType:
          _str(map['lastMessageType']).isEmpty
              ? AppConstants.msgText
              : _str(map['lastMessageType']),
      lastSenderId: _str(map['lastSenderId']),
      lastMessageAt:
          _date(map['lastMessageAt'] ?? map['updatedAt'] ?? map['createdAt']),
      unreadCount:
          (map['unreadCount'] is num) ? (map['unreadCount'] as num).toInt() : 0,
      unreadCounts: _mergedUnreadCounts(map),
      lastReadAt: _dateMap(map['lastReadAt']),
      contactUnlocked: map['contactUnlocked'] == true,
      bookingStatus: normalizedStatus,
      chatLocked: map['chatLocked'] == true,
      chatLockedReason: _nullableStr(map['chatLockedReason']),
    );
  }

  Map<String, dynamic> toMap() => {
        'chatId': chatId,
        'bookingId': bookingId,
        'clientId': clientId,
        'clientUserId': clientId,
        'clientName': clientName,
        'clientImageUrl': clientImageUrl,
        'fundiId': fundiId,
        'fundiUserId': fundiId,
        'fundiName': fundiName,
        'fundiImageUrl': fundiImageUrl,
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastSenderId': lastSenderId,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'unreadCount': unreadCount,
        'unreadCounts': unreadCounts,
        'lastReadAt': lastReadAt
            .map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
        'contactUnlocked': contactUnlocked,
        'bookingStatus': bookingStatus,
        'chatLocked': chatLocked,
        'chatLockedReason': chatLockedReason,
      };

  String otherPersonName(String myId) {
    if (myId == clientId) return fundiName;
    if (myId == fundiId) return clientName;
    return fundiName.isNotEmpty ? fundiName : clientName;
  }

  String? otherPersonImage(String myId) {
    if (myId == clientId) return fundiImageUrl;
    if (myId == fundiId) return clientImageUrl;
    return fundiImageUrl ?? clientImageUrl;
  }

  String otherPersonId(String myId) {
    if (myId == clientId) return fundiId;
    if (myId == fundiId) return clientId;
    return fundiId.isNotEmpty ? fundiId : clientId;
  }
}

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

Map<String, int> _mergedUnreadCounts(Map<String, dynamic> map) {
  final merged = <String, int>{};

  void add(dynamic value) {
    if (value is! Map) return;
    value.forEach((key, val) {
      merged[key.toString()] =
          (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
    });
  }

  add(map['unreadCounts']);
  // Do NOT merge the legacy numeric unreadCount into the map to avoid double-counting.
  return merged;
}

Map<String, DateTime> _dateMap(dynamic value) {
  if (value is! Map) return const {};
  final out = <String, DateTime>{};
  value.forEach((key, val) {
    if (val is Timestamp) out[key.toString()] = val.toDate();
    if (val is DateTime) out[key.toString()] = val;
  });
  return out;
}

String _str(dynamic value) => (value ?? '').toString().trim();

String? _nullableStr(dynamic value) {
  final s = _str(value);
  return s.isEmpty ? null : s;
}

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
