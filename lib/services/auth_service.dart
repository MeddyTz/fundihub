import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> registerWithEmail(
          {required String email, required String password}) =>
      _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);

  Future<void> createUserDocument(
      {required String uid,
      required String email,
      required String role}) async {
    final now = DateTime.now();
    await _db.collection(FirestoreConstants.users).doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role,
      'fullName': '',
      'phone': '',
      'region': '',
      'district': '',
      'area': '',
      'latitude': null,
      'longitude': null,
      'detectedAddress': '',
      'savedLocationPreference': 'manual',
      'profileImageUrl': null,
      'accountStatus': AppConstants.statusActive,
      'isProfileComplete': false,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (role == AppConstants.roleFundi) ...{
        'category': '',
        'otherCategoryName': null,
        'skills': [],
        'experience': '',
        'bio': '',
        'rating': 0.0,
        'reviewCount': 0,
        'plan': AppConstants.planFree,
        'promotionStatus': AppConstants.promotionInactive,
        'locationUpdatedAt': null,
      },
    });
    // Set Auth custom claim so Firestore rules can read role from token.
    await _setRoleClaim(uid: uid, role: role);
  }

  /// Calls setUserRoleClaim Cloud Function to write role into Auth token.
  /// Best-effort: if it fails, rules fall back gracefully.
  Future<void> _setRoleClaim(
      {required String uid, required String role}) async {
    try {
      await _functions
          .httpsCallable('setUserRoleClaim')
          .call({'uid': uid, 'role': role});
      // Force token refresh so the new claim is immediately available.
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}
  }

  Future<UserCredential> loginWithEmail(
          {required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<UserModel?> fetchUserModel(String uid) async {
    try {
      final doc =
          await _db.collection(FirestoreConstants.users).doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<UserModel?> userModelStream(String uid) =>
      _db.collection(FirestoreConstants.users).doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);

  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return e.message ?? 'An error occurred.';
    }
  }
}
