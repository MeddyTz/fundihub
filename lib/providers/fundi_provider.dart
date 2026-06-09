import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';

class FundiProvider extends ChangeNotifier {
  final WalletService _walletService;
  FundiProvider({required WalletService walletService})
      : _walletService = walletService;

  WalletModel? _wallet;
  StreamSubscription<WalletModel?>? _walletSub;
  int _selectedTabIndex = 0;

  WalletModel? get wallet => _wallet;
  int get selectedTabIndex => _selectedTabIndex;
  bool get isLocked => _wallet?.isLocked ?? false;
  String get lockedReason => _wallet?.lockedReason ?? 'none';

  void subscribeWallet(String fundiId) {
    _walletSub?.cancel();
    _walletSub = _walletService.walletStream(fundiId).listen((w) {
      _wallet = w;
      notifyListeners();
    });
  }

  void setTab(int index) { _selectedTabIndex = index; notifyListeners(); }

  @override
  void dispose() { _walletSub?.cancel(); super.dispose(); }
}
