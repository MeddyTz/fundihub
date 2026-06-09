import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../core/utils/app_utils.dart';
import '../models/booking_model.dart';
import '../models/message_model.dart';
import 'storage_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();

  static const Set<String> _openStatuses = {
    AppConstants.bookingAccepted,
    AppConstants.bookingAgreementConfirmed,
    AppConstants.bookingInProgress,
    AppConstants.bookingAwaitingConfirmation,
    AppConstants.bookingCompletionDisputed,
  };

  // ─────────────────────────────────────────────────────────
  // CHAT INITIALIZATION
  // ─────────────────────────────────────────────────────────

  Future<void> initializeChatFromBooking(BookingModel booking) async {
    final chatId =
        _chatIdFromParticipants(booking.clientId, booking.fundiId);
    final byBookingRef =
        _db.collection(FirestoreConstants.chats).doc(booking.bookingId);
    final canonicalRef =
        _db.collection(FirestoreConstants.chats).doc(chatId);

    final canonicalSnap = await canonicalRef.get();
    final ref = canonicalSnap.exists ? canonicalRef : byBookingRef;

    final existing =
        ref == canonicalRef ? canonicalSnap : await byBookingRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    final now = DateTime.now();
    final locked = !_openStatuses.contains(booking.status);

    final unreadCounts = _normalizedUnreadCounts(
      data: existingData,
      clientId: booking.clientId,
      fundiId: booking.fundiId,
    );

    final data = <String, dynamic>{
      'chatId': ref.id,
      'bookingId': booking.bookingId,
      'bookingIds': FieldValue.arrayUnion([booking.bookingId]),
      'clientId': booking.clientId,
      'clientUserId': booking.clientId,
      'clientName': booking.clientName,
      'clientImageUrl': booking.clientProfileImage,
      'clientProfileImage': booking.clientProfileImage,
      'fundiId': booking.fundiId,
      'fundiUserId': booking.fundiId,
      'fundiName': booking.fundiName,
      'fundiImageUrl': booking.fundiProfileImage,
      'fundiProfileImage': booking.fundiProfileImage,
      'participants': [booking.clientId, booking.fundiId],
      'lastMessage':
          existing.exists ? (existingData['lastMessage'] ?? '') : 'Chat started',
      'lastMessageType': existing.exists
          ? (existingData['lastMessageType'] ?? AppConstants.msgText)
          : AppConstants.msgText,
      'lastMessageAt': existing.exists
          ? (existingData['lastMessageAt'] ?? Timestamp.fromDate(now))
          : Timestamp.fromDate(now),
      'lastSenderId':
          existing.exists ? (existingData['lastSenderId'] ?? '') : '',
      'unreadCounts': unreadCounts,
      'unreadCount': 0,
      'contactUnlocked': booking.contactUnlocked,
      'status': 'active',
      'bookingStatus': booking.status,
      'chatLocked': locked,
      'chatLockedReason':
          locked ? _lockedMessageForStatus(booking.status) : null,
      'type': 'booking',
      '${booking.clientId}_typing': false,
      '${booking.fundiId}_typing': false,
      'updatedAt': Timestamp.fromDate(now),
    };

    if (!existing.exists) {
      await ref.set({...data, 'createdAt': Timestamp.fromDate(now)});
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }

  Future<String> getOrCreateDirectChat({
    required String userId1,
    required String userId2,
    required String user1Name,
    required String user2Name,
    String? user1Image,
    String? user2Image,
  }) async {
    final chatId = _chatIdFromParticipants(userId1, userId2);
    final ref = _db.collection(FirestoreConstants.chats).doc(chatId);
    final snap = await ref.get();

    if (!snap.exists) {
      final now = DateTime.now();
      await ref.set({
        'chatId': chatId,
        'bookingId': '',
        'participants': [userId1, userId2],
        'clientId': userId1,
        'clientUserId': userId1,
        'clientName': user1Name,
        'clientImageUrl': user1Image ?? '',
        'fundiId': userId2,
        'fundiUserId': userId2,
        'fundiName': user2Name,
        'fundiImageUrl': user2Image ?? '',
        'lastMessage': '',
        'lastMessageType': AppConstants.msgText,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastSenderId': '',
        'unreadCounts': {userId1: 0, userId2: 0},
        'unreadCount': 0,
        'contactUnlocked': true,
        'status': 'active',
        'bookingStatus': AppConstants.bookingAccepted,
        'chatLocked': false,
        'chatLockedReason': null,
        'type': 'direct',
        '${userId1}_typing': false,
        '${userId2}_typing': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    return chatId;
  }

  // ─────────────────────────────────────────────────────────
  // SENDING MESSAGES
  // ─────────────────────────────────────────────────────────

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required String otherUserId,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final chatData =
        await _assertCanSend(chatId: chatId, senderId: senderId);
    final contactUnlocked =
        chatData['contactUnlocked'] as bool? ?? false;

    if (!contactUnlocked && AppUtils.containsPhoneNumber(cleaned)) {
      throw Exception(
          'Phone numbers cannot be shared before both parties agree to the job.');
    }

    final resolvedOther = otherUserId.isNotEmpty
        ? otherUserId
        : _otherUserIdFromChat(chatData, senderId);

    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      otherUserId: resolvedOther,
      type: AppConstants.msgText,
      lastMessage: cleaned.length > 60
          ? '${cleaned.substring(0, 60)}...'
          : cleaned,
      message: MessageModel(
        messageId: '',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        type: AppConstants.msgText,
        text: cleaned,
        isSeen: false,
        isDelivered: true,
        isDeleted: false,
        createdAt: DateTime.now(),
      ),
      notificationTitle: senderName,
      notificationBody:
          cleaned.length > 100 ? '${cleaned.substring(0, 100)}...' : cleaned,
    );
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File imageFile,
    String? otherUserId,
  }) async {
    final chatData =
        await _assertCanSend(chatId: chatId, senderId: senderId);
    final targetUserId =
        (otherUserId != null && otherUserId.isNotEmpty)
            ? otherUserId
            : _otherUserIdFromChat(chatData, senderId);
    final url =
        await _storage.uploadChatImage(chatId: chatId, file: imageFile);

    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      otherUserId: targetUserId,
      type: AppConstants.msgImage,
      lastMessage: '📷 Photo',
      message: MessageModel(
        messageId: '',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        type: AppConstants.msgImage,
        imageUrl: url,
        isSeen: false,
        isDelivered: true,
        isDeleted: false,
        createdAt: DateTime.now(),
      ),
      notificationTitle: senderName,
      notificationBody: 'Sent you a photo 📷',
    );
  }

  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File voiceFile,
    int? voiceDurationMs,
    String? otherUserId,
  }) async {
    final chatData =
        await _assertCanSend(chatId: chatId, senderId: senderId);
    final targetUserId =
        (otherUserId != null && otherUserId.isNotEmpty)
            ? otherUserId
            : _otherUserIdFromChat(chatData, senderId);
    final url =
        await _storage.uploadVoiceNote(chatId: chatId, file: voiceFile);

    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      otherUserId: targetUserId,
      type: AppConstants.msgVoice,
      lastMessage: '🎤 Voice note',
      message: MessageModel(
        messageId: '',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        type: AppConstants.msgVoice,
        voiceUrl: url,
        voiceDurationMs: voiceDurationMs,
        isSeen: false,
        isDelivered: true,
        isDeleted: false,
        createdAt: DateTime.now(),
      ),
      notificationTitle: senderName,
      notificationBody: 'Sent you a voice note 🎤',
    );
  }

  Future<void> sendLocationMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required double lat,
    required double lng,
    String? label,
  }) async {
    final chatData =
        await _assertCanSend(chatId: chatId, senderId: senderId);
    final otherUserId = _otherUserIdFromChat(chatData, senderId);

    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      otherUserId: otherUserId,
      type: AppConstants.msgLocation,
      lastMessage: '📍 Location',
      message: MessageModel(
        messageId: '',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        type: AppConstants.msgLocation,
        locationLat: lat,
        locationLng: lng,
        locationLabel: label ?? 'Shared Location',
        isSeen: false,
        isDelivered: true,
        isDeleted: false,
        createdAt: DateTime.now(),
      ),
      notificationTitle: senderName,
      notificationBody: 'Shared their location 📍',
    );
  }

  Future<void> _sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String otherUserId,
    required String type,
    required String lastMessage,
    required MessageModel message,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final msgRef = _db
        .collection(FirestoreConstants.chats)
        .doc(chatId)
        .collection(FirestoreConstants.messages)
        .doc();
    final chatRef =
        _db.collection(FirestoreConstants.chats).doc(chatId);
    final now = DateTime.now();

    final msg = message.copyWith(messageId: msgRef.id, createdAt: now);

    final chatUpdate = <String, dynamic>{
      'lastMessage': lastMessage,
      'lastMessageType': type,
      'lastMessageAt': Timestamp.fromDate(now),
      'lastSenderId': senderId,
      'updatedAt': Timestamp.fromDate(now),
    };

    if (otherUserId.isNotEmpty && otherUserId != senderId) {
      // FIX: Increment receiver unread, reset sender to 0.
      // This is the canonical source of truth for unread badges.
      chatUpdate['unreadCounts.$otherUserId'] = FieldValue.increment(1);
      chatUpdate['unreadCounts.$senderId'] = 0;
    }

    chatUpdate['participants'] =
        FieldValue.arrayUnion([senderId, otherUserId]);
    chatUpdate['type'] = chatUpdate['type'] ?? 'booking';

    final batch = _db.batch();
    batch.set(msgRef, msg.toMap());
    batch.set(chatRef, chatUpdate, SetOptions(merge: true));
    await batch.commit();

    // FIX: Create/update notification for receiver.
    // Errors are now LOGGED, not silently swallowed.
    if (otherUserId.isNotEmpty && otherUserId != senderId) {
      await _upsertMessageNotification(
        receiverId:   otherUserId,
        senderId:     senderId,
        title:        notificationTitle,
        body:         notificationBody,
        type:         type == AppConstants.msgText ? 'message' : 'message_$type',
        chatId:       chatId,
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // READ / UNREAD MANAGEMENT
  // ─────────────────────────────────────────────────────────

  /// Called ONLY when receiver opens a specific chat.
  /// Resets their unread counter and marks individual messages seen.
  /// Do NOT call this on tab open — only on chat detail open.
  Future<void> markMessagesSeen({
    required String chatId,
    required String myId,
  }) async {
    final uid = myId.trim();
    final cid = chatId.trim();
    if (uid.isEmpty || cid.isEmpty) return;

    final chatRef = _db.collection(FirestoreConstants.chats).doc(cid);

    // FIX: Reset unread counter only for this specific chat.
    // Also record lastReadAt for read receipts.
    await chatRef.set(
      {
        'unreadCounts.$uid': 0,
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'participants': FieldValue.arrayUnion([uid]),
      },
      SetOptions(merge: true),
    );

    // Mark individual message docs as seen.
    // FIX: This now correctly uses sender != myId filter so receiver
    // can mark the sender's messages seen.
    try {
      final snap = await chatRef
          .collection(FirestoreConstants.messages)
          .where('senderId', isNotEqualTo: uid)
          .where('isSeen', isEqualTo: false)
          .limit(150)
          .get();

      if (snap.docs.isEmpty) return;

      var batch = _db.batch();
      var ops = 0;
      for (final doc in snap.docs) {
        batch.set(
          doc.reference,
          {
            'isSeen': true,
            'seenAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        ops++;
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      // Log but don't fail — unread counter reset above is more important
      dev.log('[ChatService] markMessagesSeen batch error: $e', name: 'CHAT');
    }
  }

  /// Bulk clear — used only by the explicit "Mark all read" button.
  /// NOT called on tab navigation.
  Future<void> markAllUserChatsSeen({
    required String userId,
    required bool isClient,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      final snap = await _db
          .collection(FirestoreConstants.chats)
          .where('participants', arrayContains: uid)
          .get();

      if (snap.docs.isEmpty) return;

      var batch = _db.batch();
      var ops = 0;
      for (final doc in snap.docs) {
        batch.set(
          doc.reference,
          {
            'unreadCounts.$uid': 0,
            'lastReadAt.$uid': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        ops++;
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      dev.log('[ChatService] markAllUserChatsSeen error: $e', name: 'CHAT');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // PRESENCE / TYPING
  // ─────────────────────────────────────────────────────────

  Future<void> setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    if (userId.isEmpty || chatId.isEmpty) return;
    try {
      await _db
          .collection(FirestoreConstants.chats)
          .doc(chatId)
          .set(
            {
              '${userId}_typing': isTyping,
              'typingBy': isTyping ? userId : '',
              'typingAt':
                  isTyping ? FieldValue.serverTimestamp() : null,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Future<void> setOnline({
    required String chatId,
    required String userId,
    required bool isOnline,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      await _db.collection(FirestoreConstants.users).doc(uid).set(
            {
              'isOnline': isOnline,
              'online': isOnline,
              'lastSeenAt': FieldValue.serverTimestamp(),
              'presenceUpdatedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (_) {}

    if (chatId.trim().isEmpty) return;
    try {
      await _db
          .collection(FirestoreConstants.chats)
          .doc(chatId)
          .set(
            {
              '${uid}_online': isOnline,
              '${uid}_lastSeenAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  // MESSAGE OPERATIONS
  // ─────────────────────────────────────────────────────────

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _db
        .collection(FirestoreConstants.chats)
        .doc(chatId)
        .collection(FirestoreConstants.messages)
        .doc(messageId)
        .update({
      'isDeleted': true,
      'text': 'This message was deleted',
    });
  }

  // ─────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _db
        .collection(FirestoreConstants.chats)
        .doc(chatId)
        .collection(FirestoreConstants.messages)
        .orderBy('createdAt', descending: false)
        .limitToLast(AppConstants.chatMessagePageSize)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  Stream<ChatSummary?> chatSummaryStream(String chatId) {
    return _db
        .collection(FirestoreConstants.chats)
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists
            ? ChatSummary.fromMap({'id': doc.id, ...?doc.data()})
            : null);
  }

  Stream<List<ChatSummary>> userChatsStream(String userId, bool isClient) {
    final uid = userId.trim();
    if (uid.isEmpty) return Stream<List<ChatSummary>>.value(const []);

    final primaryStream = _db
        .collection(FirestoreConstants.chats)
        .where('participants', arrayContains: uid)
        .snapshots();

    final clientStream = _db
        .collection(FirestoreConstants.chats)
        .where('clientId', isEqualTo: uid)
        .snapshots();

    final fundiStream = _db
        .collection(FirestoreConstants.chats)
        .where('fundiId', isEqualTo: uid)
        .snapshots();

    return Rx.combineLatest3<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<ChatSummary>>(
      primaryStream,
      clientStream,
      fundiStream,
      (primary, byClient, byFundi) {
        final seen = <String>{};
        final chats = <ChatSummary>[];

        void addDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
          for (final doc in docs) {
            final data = doc.data();
            final summary =
                ChatSummary.fromMap({'id': doc.id, ...data});
            final key =
                summary.chatId.isNotEmpty ? summary.chatId : doc.id;
            if (seen.contains(key)) continue;
            seen.add(key);
            if (summary.clientId != uid && summary.fundiId != uid) continue;
            chats.add(summary);
          }
        }

        addDocs(primary.docs);
        addDocs(byClient.docs);
        addDocs(byFundi.docs);

        chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        return chats;
      },
    );
  }

  Stream<int> totalUnreadStream(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return Stream<int>.value(0);

    final primaryStream = _db
        .collection(FirestoreConstants.chats)
        .where('participants', arrayContains: uid)
        .snapshots();

    final clientStream = _db
        .collection(FirestoreConstants.chats)
        .where('clientId', isEqualTo: uid)
        .snapshots();

    final fundiStream = _db
        .collection(FirestoreConstants.chats)
        .where('fundiId', isEqualTo: uid)
        .snapshots();

    return Rx.combineLatest3<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        int>(
      primaryStream,
      clientStream,
      fundiStream,
      (primary, byClient, byFundi) {
        final seen = <String>{};
        int total = 0;

        void sumDocs(
            List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
          for (final doc in docs) {
            if (seen.contains(doc.id)) continue;
            seen.add(doc.id);
            final data = doc.data();

            final unreadCounts = data['unreadCounts'];
            if (unreadCounts is Map && unreadCounts.containsKey(uid)) {
              final val = unreadCounts[uid];
              if (val is num && val > 0) {
                total += val.toInt();
                continue;
              }
            }

            // Legacy fallback
            final lastSenderId =
                (data['lastSenderId'] ?? '').toString().trim();
            if (lastSenderId != uid && lastSenderId.isNotEmpty) {
              final count = data['unreadCount'];
              if (count is num && count > 0) {
                total += count.toInt();
              }
            }
          }
        }

        sumDocs(primary.docs);
        sumDocs(byClient.docs);
        sumDocs(byFundi.docs);
        return total;
      },
    );
  }

  Stream<bool> otherTypingStream(String chatId, String otherUserId) {
    return _db
        .collection(FirestoreConstants.chats)
        .doc(chatId)
        .snapshots()
        .map((doc) =>
            doc.data()?['${otherUserId}_typing'] as bool? ?? false);
  }

  Stream<bool> otherOnlineStream(String chatId, String otherUserId) {
    final uid = otherUserId.trim();
    if (uid.isEmpty) return Stream<bool>.value(false);

    return _db
        .collection(FirestoreConstants.users)
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return false;
      return data['isOnline'] == true || data['online'] == true;
    });
  }

  Stream<DateTime?> otherLastSeenStream(
      String chatId, String otherUserId) {
    final uid = otherUserId.trim();
    if (uid.isEmpty) return Stream<DateTime?>.value(null);

    return _db
        .collection(FirestoreConstants.users)
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final v = data['lastSeenAt'] ??
          data['lastSeen'] ??
          data['presenceUpdatedAt'];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    });
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _assertCanSend({
    required String chatId,
    required String senderId,
  }) async {
    final chatRef =
        _db.collection(FirestoreConstants.chats).doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat not found.');

    final data = chatDoc.data() ?? {};
    final bookingId = (data['bookingId'] ?? '').toString().trim();
    String status =
        (data['bookingStatus'] ?? data['status'] ?? '').toString();

    if (bookingId.isNotEmpty && bookingId != chatId) {
      try {
        final bookingDoc = await _db
            .collection(FirestoreConstants.bookings)
            .doc(bookingId)
            .get();
        if (bookingDoc.exists) {
          status = (bookingDoc.data()?['status'] ?? status).toString();
        }
      } catch (_) {}
    }

    final type = (data['type'] ?? 'booking').toString();
    final locked = type == 'direct'
        ? false
        : (data['chatLocked'] == true ||
            !_openStatuses.contains(status));

    if (bookingId.isNotEmpty && type != 'direct') {
      try {
        await chatRef.set(
          {
            'bookingStatus': status,
            'chatLocked': locked,
            'chatLockedReason':
                locked ? _lockedMessageForStatus(status) : null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    if (locked) throw Exception(_lockedMessageForStatus(status));

    final clientId =
        (data['clientId'] ?? data['clientUserId'] ?? '').toString();
    final fundiId =
        (data['fundiId'] ?? data['fundiUserId'] ?? '').toString();
    final otherId = senderId == clientId ? fundiId : clientId;

    if (otherId.isNotEmpty &&
        await _isEitherBlocked(senderId, otherId)) {
      throw Exception('Messaging is blocked between these users.');
    }

    return {...data, 'bookingStatus': status, 'chatLocked': locked};
  }

  Future<bool> _isEitherBlocked(String a, String b) async {
    try {
      final q1 = await _db
          .collection('blocks')
          .where('blockerId', isEqualTo: a)
          .where('blockedId', isEqualTo: b)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) return true;

      final q2 = await _db
          .collection('blocks')
          .where('blockerId', isEqualTo: b)
          .where('blockedId', isEqualTo: a)
          .limit(1)
          .get();
      return q2.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _otherUserIdFromChat(
      Map<String, dynamic> data, String senderId) {
    final clientId =
        (data['clientId'] ?? data['clientUserId'] ?? '').toString();
    final fundiId =
        (data['fundiId'] ?? data['fundiUserId'] ?? '').toString();
    return senderId == clientId ? fundiId : clientId;
  }

  String _chatIdFromParticipants(String uid1, String uid2) {
    final sorted = [uid1.trim(), uid2.trim()]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static String _lockedMessageForStatus(String status) {
    switch (status.toLowerCase().trim()) {
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
        return 'Chat is currently unavailable.';
    }
  }

  Map<String, dynamic> _normalizedUnreadCounts({
    required Map<String, dynamic> data,
    required String clientId,
    required String fundiId,
  }) {
    final merged = <String, dynamic>{};
    final existing = data['unreadCounts'];
    if (existing is Map) {
      existing.forEach((key, value) {
        final k = key.toString();
        if (k.isNotEmpty) merged[k] = value;
      });
    }
    if (clientId.trim().isNotEmpty) {
      merged.putIfAbsent(clientId, () => 0);
    }
    if (fundiId.trim().isNotEmpty) {
      merged.putIfAbsent(fundiId, () => 0);
    }
    return merged;
  }

  // ─────────────────────────────────────────────────────────
  // MESSAGE NOTIFICATION
  //
  // FIX: Use a stable per-chat notification ID: "{receiverId}_message_{chatId}"
  // When a new message arrives in the same chat, we UPDATE the existing
  // notification doc (body = new preview, isRead = false again).
  // This means:
  //   • Notification stays visible in the notifications screen
  //   • Bell counter increments correctly
  //   • No notification flood from rapid messages
  //   • Errors are LOGGED, not silently ignored
  // ─────────────────────────────────────────────────────────
  Future<void> _upsertMessageNotification({
    required String receiverId,
    required String senderId,
    required String title,
    required String body,
    required String type,
    required String chatId,
  }) async {
    if (receiverId.trim().isEmpty) return;

    // Stable ID: one doc per receiver per chat.
    // New messages in the same chat overwrite this doc so notification
    // stays fresh and isRead resets to false.
    final safeCid  = chatId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeType = type.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final notifId  = '${receiverId}_${safeType}_$safeCid';

    dev.log(
      '[ChatService] upsert message notif: $notifId receiver=$receiverId',
      name: 'CHAT',
    );

    try {
      // Use set (not setOptions merge: true for isRead) so we always
      // reset isRead/read to false even if user had read a previous
      // message notification for this chat.
      await _db
          .collection(FirestoreConstants.notifications)
          .doc(notifId)
          .set(
        {
          'notificationId': notifId,
          'notifId':        notifId,
          'userId':         receiverId,
          'receiverId':     receiverId,
          'senderId':       senderId,
          'title':          title,
          'body':           body,
          'message':        body,
          'type':           type,
          'chatId':         chatId,
          'relatedId':      chatId,
          'isRead':         false,  // always reset — new message = unread
          'read':           false,
          'createdAt':      FieldValue.serverTimestamp(),
          'updatedAt':      FieldValue.serverTimestamp(),
        },
        // NO merge: true — we want to overwrite isRead every time
      );
    } catch (e) {
      // Log the error so it's visible in console — do NOT silently ignore
      dev.log(
        '[ChatService] _upsertMessageNotification FAILED: $e '
        '(notifId=$notifId, receiver=$receiverId)',
        name: 'CHAT',
        error: e,
      );
      // Re-throw so caller can surface in UI if needed
      rethrow;
    }
  }
}

/// Minimal Rx.combineLatest3 implementation — avoids rxdart dependency.
class Rx {
  static Stream<R> combineLatest3<A, B, C, R>(
    Stream<A> a,
    Stream<B> b,
    Stream<C> c,
    R Function(A, B, C) combiner,
  ) {
    final controller = StreamController<R>();

    A? lastA;
    B? lastB;
    C? lastC;
    bool hasA = false, hasB = false, hasC = false;
    bool done = false;
    int completed = 0;

    void tryEmit() {
      if (hasA && hasB && hasC && !done) {
        try {
          controller.add(combiner(lastA as A, lastB as B, lastC as C));
        } catch (e, s) {
          controller.addError(e, s);
        }
      }
    }

    void onDone() {
      completed++;
      if (completed == 3) {
        done = true;
        controller.close();
      }
    }

    late StreamSubscription<A> subA;
    late StreamSubscription<B> subB;
    late StreamSubscription<C> subC;

    controller.onListen = () {
      subA = a.listen(
        (v) { lastA = v; hasA = true; tryEmit(); },
        onError: controller.addError,
        onDone: onDone,
      );
      subB = b.listen(
        (v) { lastB = v; hasB = true; tryEmit(); },
        onError: controller.addError,
        onDone: onDone,
      );
      subC = c.listen(
        (v) { lastC = v; hasC = true; tryEmit(); },
        onError: controller.addError,
        onDone: onDone,
      );
    };

    controller.onCancel = () async {
      await Future.wait([subA.cancel(), subB.cancel(), subC.cancel()]);
      done = true;
    };

    return controller.stream;
  }
}
