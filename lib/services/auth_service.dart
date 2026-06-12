import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Public version of _setRoleClaim for use by auth_provider.
  Future<void> setRoleClaimPublic(
      {required String uid, required String role}) =>
      _setRoleClaim(uid: uid, role: role);

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
      {required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    // Block soft-deleted accounts from signing in
    final uid = credential.user?.uid;
    if (uid != null) {
      final doc = await _db
          .collection(FirestoreConstants.users).doc(uid).get();
      final data = doc.data();
      if (data != null && (
          data['isDeleted'] == true ||
          data['accountStatus'] == 'deleted')) {
        await _auth.signOut();
        throw FirebaseAuthException(
            code: 'account-deleted',
            message: 'This account has been deleted.');
      }
    }
    return credential;
  }

  /// Signs in using Google.
  /// Returns (credential, isNewUser).
  /// isNewUser == true means no Firestore doc exists yet → role selection.
  Future<({UserCredential credential, bool isNewUser})>
      signInWithGoogle() async {
    // Trigger the Google authentication flow
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // User cancelled the picker — not an error
      throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final oauthCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(oauthCredential);
    final uid = userCred.user!.uid;

    // Check Firestore for existing user doc
    final doc = await _db
        .collection(FirestoreConstants.users).doc(uid).get();

    // Block soft-deleted accounts
    if (doc.exists && doc.data()?['accountStatus'] == 'deleted') {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      throw FirebaseAuthException(
          code: 'account-deleted',
          message: 'This account has been deleted.');
    }

    return (credential: userCred, isNewUser: !doc.exists);
  }

  Future<void> signOut() async {
    // Sign out from both Firebase Auth and GoogleSignIn.
    // Without GoogleSignIn.signOut() the user is automatically
    // re-authenticated on next Google sign-in attempt.
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

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
