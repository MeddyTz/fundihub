import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_constants.dart';

/// App-wide presence service.
///
/// This keeps the current user's online/last-seen state on the user document,
/// so the status is not limited to one chat screen. ChatService still mirrors
/// presence on the chat document for older chat UI compatibility.
class PresenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> setOnline(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      await _db.collection(FirestoreConstants.users).doc(uid).set(
        {
          'isOnline': true,
          'online': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'presenceUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Presence must never break app startup/navigation.
    }
  }

  Future<void> setOffline(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      await _db.collection(FirestoreConstants.users).doc(uid).set(
        {
          'isOnline': false,
          'online': false,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'presenceUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best effort only.
    }
  }

  Stream<bool> onlineStream(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return Stream<bool>.value(false);

    return _db.collection(FirestoreConstants.users).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return false;
      return data['isOnline'] == true || data['online'] == true;
    });
  }

  Stream<DateTime?> lastSeenStream(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return Stream<DateTime?>.value(null);

    return _db.collection(FirestoreConstants.users).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final value = data['lastSeenAt'] ?? data['lastSeen'] ?? data['presenceUpdatedAt'];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    });
  }
}
