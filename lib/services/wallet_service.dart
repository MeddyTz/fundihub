import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/wallet_model.dart';
class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<WalletModel?> walletStream(String fundiId) => _db.collection(FirestoreConstants.wallets).doc(fundiId).snapshots().map((doc) => doc.exists ? WalletModel.fromMap(doc.data()!) : null);
  Future<WalletModel?> getWallet(String fundiId) async {
    final doc = await _db.collection(FirestoreConstants.wallets).doc(fundiId).get();
    return doc.exists ? WalletModel.fromMap(doc.data()!) : null;
  }
}
