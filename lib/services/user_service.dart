import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/user_model.dart';
import '../models/fundi_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> completeClientProfile({required String uid,required String fullName,required String phone,required String region,required String district,required String area,double? latitude,double? longitude,String detectedAddress='',String savedLocationPreference='manual'}) async {
    await _db.collection(FirestoreConstants.users).doc(uid).update({'fullName':fullName,'phone':phone,'region':region,'district':district,'area':area,'latitude':latitude,'longitude':longitude,'detectedAddress':detectedAddress,'savedLocationPreference':savedLocationPreference,'isProfileComplete':true,'accountStatus':AppConstants.statusActive,'updatedAt':Timestamp.fromDate(DateTime.now())});
  }

  Future<void> completeFundiProfile({
    required String uid, required String fullName, required String phone,
    required String category, String? otherCategoryName,
    required List<String> skills, required String experience,
    required String bio, required String region, required String district,
    required String area, double? latitude, double? longitude,
    String detectedAddress = '',
  }) async {
    final now = DateTime.now();

    // ── CRITICAL: update the user document ──────────────────────────────
    // This MUST succeed. It sets isProfileComplete=true which the router
    // checks. If this throws, the outer catch reports a real error.
    await _db.collection(FirestoreConstants.users).doc(uid).update({
      'fullName': fullName, 'phone': phone, 'category': category,
      'otherCategoryName': otherCategoryName, 'skills': skills,
      'experience': experience, 'bio': bio, 'region': region,
      'district': district, 'area': area, 'latitude': latitude,
      'longitude': longitude, 'detectedAddress': detectedAddress,
      'locationUpdatedAt': Timestamp.fromDate(now),
      'isProfileComplete': true,
      'accountStatus': AppConstants.statusActive,
      'updatedAt': Timestamp.fromDate(now),
    });

    // ── NON-FATAL: wallet init ────────────────────────────────────────────
    // A wallet write failure must NOT show the user a false error.
    // The profile is already saved above.
    try {
      await _db.collection(FirestoreConstants.wallets).doc(uid).set({
        'fundiId': uid, 'walletBalance': 0, 'totalFeesPaid': 0,
        'pendingJobFee': 0, 'feeStatus': AppConstants.feeNone,
        'lockedReason': AppConstants.lockNone,
        'subscriptionStatus': AppConstants.planFree,
        'promotionStatus': AppConstants.promotionInactive,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } catch (_) {}

    // ── NON-FATAL: other-category request ────────────────────────────────
    try {
      if (category == AppConstants.categoryOthers &&
          otherCategoryName != null && otherCategoryName.isNotEmpty) {
        final ref =
            _db.collection(FirestoreConstants.otherCategoryRequests).doc();
        await ref.set({'requestId': ref.id, 'fundiId': uid,
          'fundiName': fullName, 'phone': phone, 'region': region,
          'district': district, 'otherCategoryName': otherCategoryName,
          'submittedAt': Timestamp.fromDate(now), 'status': 'pending'});
      }
    } catch (_) {}
  }

  Future<UserModel?> getUserModel(String uid) async {
    try { final doc = await _db.collection(FirestoreConstants.users).doc(uid).get(); return doc.exists ? UserModel.fromMap(doc.data()!) : null; } catch (_) { return null; }
  }
  Future<FundiModel?> getFundiModel(String uid) async {
    try { final doc = await _db.collection(FirestoreConstants.users).doc(uid).get(); return doc.exists ? FundiModel.fromMap(doc.data()!) : null; } catch (_) { return null; }
  }
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    await _db.collection(FirestoreConstants.users).doc(uid).update({'profileImageUrl':imageUrl,'updatedAt':Timestamp.fromDate(DateTime.now())});
  }
}
