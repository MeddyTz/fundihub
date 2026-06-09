import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/block_model.dart';

class BlockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'blocks';

  /// Block a user
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
    required String blockedName,
  }) async {
    // Check not already blocked
    final exists = await isBlocked(blockerId, blockedId);
    if (exists) return;

    final ref = _db.collection(_col).doc();
    final block = BlockModel(
      blockId: ref.id,
      blockerId: blockerId,
      blockedId: blockedId,
      blockedName: blockedName,
      createdAt: DateTime.now(),
    );
    await ref.set(block.toMap());
  }

  /// Unblock a user
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    final snap = await _db
        .collection(_col)
        .where('blockerId', isEqualTo: blockerId)
        .where('blockedId', isEqualTo: blockedId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// Check if blockerId has blocked blockedId
  Future<bool> isBlocked(String blockerId, String blockedId) async {
    final snap = await _db
        .collection(_col)
        .where('blockerId', isEqualTo: blockerId)
        .where('blockedId', isEqualTo: blockedId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Stream of all users blocked by [blockerId]
  Stream<List<BlockModel>> blockedUsersStream(String blockerId) =>
      _db
          .collection(_col)
          .where('blockerId', isEqualTo: blockerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => BlockModel.fromMap(d.data())).toList());
}