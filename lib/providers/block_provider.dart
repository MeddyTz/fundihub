import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/block_model.dart';
import '../services/block_service.dart';

class BlockProvider extends ChangeNotifier {
  final BlockService _svc;
  BlockProvider({required BlockService blockService}) : _svc = blockService;

  List<BlockModel> _blockedUsers = [];
  bool _isLoading = false;
  StreamSubscription<List<BlockModel>>? _sub;

  List<BlockModel> get blockedUsers => _blockedUsers;
  bool get isLoading => _isLoading;
  List<String> get blockedIds => _blockedUsers.map((b) => b.blockedId).toList();

  void subscribe(String userId) {
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();
    _sub = _svc.blockedUsersStream(userId).listen((list) {
      _blockedUsers = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<bool> isBlocked(String myId, String otherId) =>
      _svc.isBlocked(myId, otherId);

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
    required String blockedName,
  }) async {
    await _svc.blockUser(
      blockerId: blockerId,
      blockedId: blockedId,
      blockedName: blockedName,
    );
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _svc.unblockUser(blockerId: blockerId, blockedId: blockedId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}