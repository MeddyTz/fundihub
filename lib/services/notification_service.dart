import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants/firestore_constants.dart';
import '../models/notification_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background: Firestore doc already written by app/services/functions.
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _initializedUserId;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<String?> initialize(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return null;
    if (_initializedUserId == uid) return _fcm.getToken();

    _initializedUserId = uid;

    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
    } catch (_) {}

    String? token;
    try {
      token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }
    } catch (_) {}

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((token) async {
      if (_initializedUserId == uid) {
        await _saveToken(uid, token);
      }
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((msg) async {
      if (_initializedUserId != uid) return;

      final title = msg.notification?.title ??
          msg.data['title']?.toString() ??
          '';
      final body = msg.notification?.body ??
          msg.data['body']?.toString() ??
          '';
      final type = msg.data['type']?.toString() ?? 'system';
      final relatedId = msg.data['relatedId']?.toString() ??
          msg.data['bookingId']?.toString() ??
          msg.data['chatId']?.toString();

      if (title.trim().isEmpty && body.trim().isEmpty) return;

      if (relatedId != null && relatedId.isNotEmpty) {
        final safeType = type.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final stableId = '${uid}_${safeType}_$relatedId';

        try {
          final existing = await _db
              .collection(FirestoreConstants.notifications)
              .doc(stableId)
              .get();

          if (existing.exists) {
            dev.log(
              '[NotifService] Skipping duplicate push notif: $stableId',
              name: 'NOTIF',
            );
            return;
          }
        } catch (_) {}
      }

      await createNotification(
        userId: uid,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
      );
    });

    return token;
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection(FirestoreConstants.users).doc(uid).set(
        {
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? senderId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      final cleanRelated = relatedId?.trim();
      final safeType = type.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

      final ref = cleanRelated != null && cleanRelated.isNotEmpty
          ? _db
              .collection(FirestoreConstants.notifications)
              .doc('${uid}_${safeType}_$cleanRelated')
          : _db.collection(FirestoreConstants.notifications).doc();

      final notificationId = ref.id;
      final normalizedType = type.toLowerCase();

      dev.log(
        '[NotifService] createNotification $notificationId → $uid type=$type',
        name: 'NOTIF',
      );

      await ref.set(
        {
          'notificationId': notificationId,
          'notifId': notificationId,
          'userId': uid,
          'receiverId': uid,
          if (senderId != null && senderId.isNotEmpty) 'senderId': senderId,
          'title': title,
          'body': body,
          'message': body,
          'type': type,
          'relatedId': cleanRelated,
          if (cleanRelated != null && cleanRelated.isNotEmpty)
            ..._extraFields(normalizedType, cleanRelated),
          'isRead': false,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      dev.log('[NotifService] createNotification error: $e', name: 'NOTIF');
    }
  }

  Map<String, dynamic> _extraFields(String type, String relatedId) {
    final isBooking = type.contains('booking') ||
        type.contains('job') ||
        type.contains('agreement') ||
        type.contains('payment') ||
        type.contains('review') ||
        type.contains('expired') ||
        type.contains('started') ||
        type.contains('completed') ||
        type.contains('cancelled') ||
        type.contains('rejected') ||
        type.contains('accepted') ||
        type.contains('pending');

    final isChat = type.contains('chat') || type.contains('message');

    return {
      if (isBooking) 'bookingId': relatedId,
      if (isChat) 'chatId': relatedId,
    };
  }

  Stream<List<NotificationModel>> notificationsStream(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return Stream.value(const []);
    }

    return _db
        .collection(FirestoreConstants.notifications)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) {
            final data = doc.data();
            data['notificationId'] ??= doc.id;
            data['notifId'] ??= doc.id;
            return NotificationModel.fromMap(data);
          })
          .where((n) => n.notifId.isNotEmpty)
          .toList();
    }).handleError((e) {
      dev.log('[NotifService] notificationsStream error: $e', name: 'NOTIF');
      return <NotificationModel>[];
    });
  }

  // Backward-compatible alias used by nearby_fundis_screen.dart.
  Stream<int> notificationStream(String userId) {
    return unreadCountStream(userId);
  }

  // Main unread counter stream.
  Stream<int> unreadCountStream(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return Stream.value(0);
    }

    return _db
        .collection(FirestoreConstants.notifications)
        .where('userId', isEqualTo: uid)
        .limit(200)
        .snapshots()
        .map((snap) {
      var count = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final isRead = data['isRead'];
        final read = data['read'];

        final unreadByIsRead = isRead == false;
        final unreadByRead = read == false;
        final missingBoth = !data.containsKey('isRead') && !data.containsKey('read');

        if (unreadByIsRead || unreadByRead || missingBoth) {
          count++;
        }
      }

      return count;
    }).handleError((e) {
      dev.log('[NotifService] unreadCountStream error: $e', name: 'NOTIF');
      return 0;
    });
  }

  Future<void> markOneRead(String notifId) async {
    final id = notifId.trim();
    if (id.isEmpty) return;

    try {
      dev.log('[NotifService] markOneRead $id', name: 'NOTIF');

      await _db.collection(FirestoreConstants.notifications).doc(id).set(
        {
          'isRead': true,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      dev.log('[NotifService] markOneRead error: $e', name: 'NOTIF');
    }
  }

  Future<void> markAllRead(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      final snap = await _db
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: uid)
          .limit(300)
          .get();

      if (snap.docs.isEmpty) return;

      const batchSize = 450;

      for (var i = 0; i < snap.docs.length; i += batchSize) {
        final batch = _db.batch();
        final now = FieldValue.serverTimestamp();

        for (final doc in snap.docs.skip(i).take(batchSize)) {
          batch.set(
            doc.reference,
            {
              'isRead': true,
              'read': true,
              'readAt': now,
              'updatedAt': now,
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }

      dev.log(
        '[NotifService] markAllRead: marked ${snap.docs.length} docs for $uid',
        name: 'NOTIF',
      );
    } catch (e) {
      dev.log('[NotifService] markAllRead error: $e', name: 'NOTIF');
    }
  }

  Future<void> markBookingNotificationsRead({
    required String userId,
    required String bookingId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      Query<Map<String, dynamic>> query = _db
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: uid);

      if (bookingId.trim().isNotEmpty) {
        query = query.where('relatedId', isEqualTo: bookingId.trim());
      }

      final snap = await query.limit(50).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final doc in snap.docs) {
        batch.set(
          doc.reference,
          {
            'isRead': true,
            'read': true,
            'readAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      dev.log(
        '[NotifService] markBookingNotificationsRead error: $e',
        name: 'NOTIF',
      );
    }
  }

  Future<void> markChatRead({
    required String chatId,
    required String userId,
  }) async {
    final uid = userId.trim();
    final cid = chatId.trim();

    if (uid.isEmpty || cid.isEmpty) return;

    try {
      final snap = await _db
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: uid)
          .where('relatedId', isEqualTo: cid)
          .limit(50)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final doc in snap.docs) {
        batch.set(
          doc.reference,
          {
            'isRead': true,
            'read': true,
            'readAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      dev.log('[NotifService] markChatRead error: $e', name: 'NOTIF');
    }
  }

  Future<void> markChatNotificationsRead({
    required String userId,
    required String chatId,
  }) {
    return markChatRead(chatId: chatId, userId: userId);
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
  }
}