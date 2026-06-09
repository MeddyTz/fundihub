import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_constants.dart';

/// NotificationProvider — Fixed Edition
///
/// PROBLEMS FIXED:
///
/// 1. MISSING SUBSCRIBE CALL
///    subscribe(uid) was never called on app start if the user was already
///    authenticated (e.g. hot restart, reopening app). Fixed in main.dart by
///    checking ap.isAuthenticated immediately in initState AND in addListener.
///
/// 2. RECEIVERID NOT QUERIED
///    Old notification docs may only have `receiverId`, not `userId`.
///    We now run FOUR parallel Firestore queries and union their results:
///      Q1: userId     == uid  AND  isRead == false
///      Q2: userId     == uid  AND  read   == false
///      Q3: receiverId == uid  AND  isRead == false
///      Q4: receiverId == uid  AND  read   == false
///    All four streams feed into one deduplicated counter.
///
/// 3. MISSING UNSUBSCRIBE ON LOGOUT
///    unsubscribe() is now called from main.dart's addListener when the user
///    transitions to unauthenticated/suspended/error status.
class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Four parallel stream subscriptions
  StreamSubscription<QuerySnapshot>? _sub1; // userId   + isRead==false
  StreamSubscription<QuerySnapshot>? _sub2; // userId   + read==false
  StreamSubscription<QuerySnapshot>? _sub3; // receiverId + isRead==false
  StreamSubscription<QuerySnapshot>? _sub4; // receiverId + read==false

  // Deduplicated sets keyed by Firestore doc ID
  final Set<String> _ids1 = {};
  final Set<String> _ids2 = {};
  final Set<String> _ids3 = {};
  final Set<String> _ids4 = {};

  // Counts
  int _totalUnread   = 0;
  int _bookingUnread = 0;
  int _chatUnread    = 0;
  int _reelUnread    = 0;

  String? _subscribedUid;

  int get totalUnread   => _totalUnread;
  int get bookingUnread => _bookingUnread;
  int get chatUnread    => _chatUnread;
  int get reelUnread    => _reelUnread;

  // Track type-to-docId mapping for category counts
  final Map<String, String> _docTypes = {}; // docId -> type

  // ─────────────────────────────────────────────────────────────────────────
  // SUBSCRIBE
  // Safe to call multiple times with the same uid — idempotent.
  // Call this immediately after authentication, and on every auth state change.
  // ─────────────────────────────────────────────────────────────────────────
  void subscribe(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    // Re-subscribe even for same uid to ensure streams are live
    // (handles edge case where streams were cancelled without unsubscribing)
    if (uid == _subscribedUid &&
        _sub1 != null && _sub2 != null &&
        _sub3 != null && _sub4 != null) {
      dev.log('[NotifProvider] Already subscribed uid=$uid, skipping', name: 'NOTIF');
      return;
    }

    _cancelAll();
    _clearAll();
    _subscribedUid = uid;

    dev.log('[NotifProvider] Subscribing uid=$uid (4 queries)', name: 'NOTIF');

    // ── Q1: userId + isRead == false ─────────────────────────────────────
    _sub1 = _db
        .collection(FirestoreConstants.notifications)
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen(
          (snap) => _onSnap(snap, _ids1, 'Q1_userId_isRead'),
          onError: (e) => dev.log('[NotifProvider] Q1 error: $e', name: 'NOTIF'),
        );

    // ── Q2: userId + read == false ────────────────────────────────────────
    _sub2 = _db
        .collection(FirestoreConstants.notifications)
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen(
          (snap) => _onSnap(snap, _ids2, 'Q2_userId_read'),
          onError: (e) => dev.log('[NotifProvider] Q2 error: $e', name: 'NOTIF'),
        );

    // ── Q3: receiverId + isRead == false ──────────────────────────────────
    _sub3 = _db
        .collection(FirestoreConstants.notifications)
        .where('receiverId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen(
          (snap) => _onSnap(snap, _ids3, 'Q3_receiverId_isRead'),
          onError: (e) => dev.log('[NotifProvider] Q3 error: $e', name: 'NOTIF'),
        );

    // ── Q4: receiverId + read == false ────────────────────────────────────
    _sub4 = _db
        .collection(FirestoreConstants.notifications)
        .where('receiverId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen(
          (snap) => _onSnap(snap, _ids4, 'Q4_receiverId_read'),
          onError: (e) => dev.log('[NotifProvider] Q4 error: $e', name: 'NOTIF'),
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNSUBSCRIBE — call on logout
  // ─────────────────────────────────────────────────────────────────────────
  void unsubscribe() {
    dev.log('[NotifProvider] Unsubscribing uid=$_subscribedUid', name: 'NOTIF');
    _cancelAll();
    _clearAll();
    _subscribedUid = null;
    _totalUnread = _bookingUnread = _chatUnread = _reelUnread = 0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNAL: handle snapshot from any of the 4 queries
  // ─────────────────────────────────────────────────────────────────────────
  void _onSnap(QuerySnapshot snap, Set<String> targetSet, String label) {
    targetSet.clear();

    for (final doc in snap.docs) {
      final docId = doc.id;
      targetSet.add(docId);

      // Track the type for category-counting
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = (data['type'] ?? '').toString().toLowerCase();
      if (type.isNotEmpty) {
        _docTypes[docId] = type;
      }
    }

    dev.log('[NotifProvider] $label → ${targetSet.length} docs', name: 'NOTIF');
    _recompute();
  }

  void _recompute() {
    // Union of all four sets — deduplication by Firestore doc ID
    final allUnread = <String>{..._ids1, ..._ids2, ..._ids3, ..._ids4};
    final total = allUnread.length;

    int booking = 0, chat = 0, reel = 0;
    for (final docId in allUnread) {
      final t = _docTypes[docId] ?? '';
      if (_isBookingType(t))      booking++;
      else if (_isChatType(t))    chat++;
      else if (_isReelType(t))    reel++;
    }

    final changed = _totalUnread != total   ||
                    _bookingUnread != booking ||
                    _chatUnread != chat       ||
                    _reelUnread != reel;

    _totalUnread   = total;
    _bookingUnread = booking;
    _chatUnread    = chat;
    _reelUnread    = reel;

    dev.log('[NotifProvider] Counter → total=$total '
        'booking=$booking chat=$chat reel=$reel', name: 'NOTIF');

    if (changed) notifyListeners();
  }

  bool _isBookingType(String t) =>
      t.contains('booking')   || t.contains('job')       ||
      t.contains('agreement') || t.contains('accepted')  ||
      t.contains('rejected')  || t.contains('cancelled') ||
      t.contains('completed') || t.contains('request')   ||
      t.contains('started')   || t.contains('expired')   ||
      t.contains('review')    || t.contains('pending');

  bool _isChatType(String t) =>
      t.contains('message') || t.contains('chat');

  bool _isReelType(String t) =>
      t.contains('reel')     || t.contains('approved') ||
      t.contains('rejected_reel');

  void _cancelAll() {
    _sub1?.cancel(); _sub1 = null;
    _sub2?.cancel(); _sub2 = null;
    _sub3?.cancel(); _sub3 = null;
    _sub4?.cancel(); _sub4 = null;
  }

  void _clearAll() {
    _ids1.clear(); _ids2.clear();
    _ids3.clear(); _ids4.clear();
    _docTypes.clear();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }
}
