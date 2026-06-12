import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

// TASK 7: Added 'guest' status so unauthenticated users can browse
// public pages (home, fundi list, fundi profile, categories).
enum AuthStatus {
  initial, loading, authenticated, unauthenticated,
  profileIncomplete, suspended, error,
  guest,  // browsing without an account
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;

  AuthProvider({required AuthService authService, required UserService userService})
      : _authService = authService, _userService = userService { _init(); }

  AuthStatus _status = AuthStatus.initial;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading = false;
  bool _suppressAuth = false;

  AuthStatus get status      => _status;
  UserModel? get userModel   => _userModel;
  String?    get errorMessage => _errorMessage;
  bool get isLoading         => _isLoading;
  bool get isAuthenticated   => _status == AuthStatus.authenticated;
  bool get isGuest           => _status == AuthStatus.guest;
  bool get isAdmin           => _userModel?.isAdmin ?? false;
  bool get isFundi           => _userModel?.isFundi ?? false;
  bool get isClient          => _userModel?.isClient ?? false;
  /// True when user authenticated via Google but hasn't chosen a role yet.
  bool get needsRoleSelection =>
      _status == AuthStatus.profileIncomplete &&
      (_userModel?.role == null || _userModel!.role.isEmpty);

  void _init() { _authService.authStateChanges.listen(_onAuthStateChanged); }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_suppressAuth) return;
    if (firebaseUser == null) {
      // TASK 7: Default to guest instead of fully unauthenticated,
      // so the router allows browsing public routes.
      _status = AuthStatus.guest;
      _userModel = null;
      notifyListeners();
      return;
    }
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      final userModel = await _authService.fetchUserModel(firebaseUser.uid);
      if (userModel == null) {
        _status = AuthStatus.unauthenticated; _userModel = null;
      } else if (userModel.accountStatus == 'deleted' ||
                 userModel.isDeleted) {
        // Deleted account — sign out silently, fall back to guest
        await _authService.signOut();
        _status = AuthStatus.guest; _userModel = null;
      } else if (userModel.isSuspended) {
        _status = AuthStatus.suspended; _userModel = userModel;
      } else if (!userModel.isProfileComplete) {
        // Guard: if we already have this user with a valid role in memory
        // (e.g. just set by assignGoogleRole), don't overwrite with a
        // stale Firestore doc that may still show role='' due to cache.
        final existingRole = _userModel?.uid == userModel.uid
            ? _userModel?.role ?? ''
            : '';
        if (existingRole.isNotEmpty && userModel.role.isEmpty) {
          // Keep existing in-memory model, just confirm status
          _status = AuthStatus.profileIncomplete;
        } else {
          _status = AuthStatus.profileIncomplete; _userModel = userModel;
        }
      } else {
        _status = AuthStatus.authenticated; _userModel = userModel;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true); _clearError();
    _suppressAuth = true;
    try {
      final credential = await _authService
          .registerWithEmail(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 30));
      final uid = credential.user?.uid;
      if (uid == null) {
        _errorMessage = 'Registration failed.'; notifyListeners(); return false;
      }
      await _authService
          .createUserDocument(uid: uid, email: email.trim(), role: role)
          .timeout(const Duration(seconds: 30));
      _suppressAuth = false;

      final userModel = await _authService
          .fetchUserModel(uid)
          .timeout(const Duration(seconds: 20));
      if (userModel != null) {
        _userModel = userModel;
        _status = userModel.isSuspended
            ? AuthStatus.suspended
            : !userModel.isProfileComplete
                ? AuthStatus.profileIncomplete
                : AuthStatus.authenticated;
      } else {
        _status = AuthStatus.profileIncomplete;
      }
      notifyListeners();
      return true;
    } on TimeoutException {
      _suppressAuth = false;
      _errorMessage = 'Network timeout. Check your connection and try again.';
      notifyListeners(); return false;
    } on FirebaseAuthException catch (e) {
      _suppressAuth = false;
      _errorMessage = AuthService.getErrorMessage(e);
      notifyListeners(); return false;
    } catch (e) {
      _suppressAuth = false;
      _errorMessage = 'Registration failed: ${e.toString()}';
      notifyListeners(); return false;
    } finally { _suppressAuth = false; _setLoading(false); }
  }

  /// Signs in with Google. Existing users route by role.
  /// New users go to role selection / profile completion.
  /// Assigns a role to a Google user who has no role yet.
  /// Updates Firestore, refreshes local model, triggers profileIncomplete
  /// router so the correct completion screen is shown.
  /// Assigns a role to a Google-authenticated user who has no role yet.
  /// Role MUST be 'client' or 'fundi'. Admin cannot be self-assigned.
  /// Uses set(merge:true): safe for both new and existing docs.
  /// Returns the role string on success, null on failure.
  Future<String?> assignGoogleRole(String role) async {
    // Security: only client or fundi may be self-assigned
    if (role != 'client' && role != 'fundi') {
      dev.log('[AuthProvider] assignGoogleRole: invalid role "$role"',
          name: 'AUTH');
      _errorMessage = 'Invalid role selected.';
      notifyListeners();
      return null;
    }

    final uid  = _authService.currentUserId;
    final user = _authService.currentUser;
    if (uid == null || user == null) {
      dev.log('[AuthProvider] assignGoogleRole: no current user',
          name: 'AUTH');
      _errorMessage = 'Not signed in. Please sign in again.';
      notifyListeners();
      return null;
    }

    dev.log('[AuthProvider] assignGoogleRole: uid=$uid role=$role',
        name: 'AUTH');
    _suppressAuth = true;  // prevent token-refresh from overwriting model
    _setLoading(true); _clearError();

    try {
      final now = DateTime.now();

      // Use set(merge:true) — creates doc if missing, patches if present.
      // The Firestore rule isGoogleRoleAssignment() allows this write:
      //   myUid() == userId AND role in ['client','fundi'] AND authProvider=='google'
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid':               uid,
        'email':             user.email ?? '',
        'fullName':          user.displayName ?? '',
        'photoUrl':          user.photoURL ?? '',
        'role':              role,
        'accountStatus':     'active',
        'isDeleted':         false,
        'isActive':          true,
        'isProfileComplete': false,
        'authProvider':      'google',
        'updatedAt':         Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      dev.log('[AuthProvider] assignGoogleRole: Firestore write OK',
          name: 'AUTH');

      // Non-fatal: set Auth custom claim for Firestore rule token checks.
      try {
        await _authService.setRoleClaimPublic(uid: uid, role: role);
        dev.log('[AuthProvider] assignGoogleRole: claim set OK',
            name: 'AUTH');
      } catch (claimErr) {
        dev.log('[AuthProvider] assignGoogleRole: claim failed '
            '(non-fatal): $claimErr', name: 'AUTH');
      }

      // Update _userModel in memory with the new role immediately.
      // Do NOT re-fetch from Firestore — the write just completed and
      // Firestore may return stale data on the next read, causing
      // needsRoleSelection to remain true and looping back here.
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(role: role);
      } else {
        // Fallback: fetch once (new install / unusual state)
        _userModel = await _authService.fetchUserModel(uid);
        // If still null, build minimal model from Auth user
        _userModel ??= UserModel(
          uid:               uid,
          email:             user.email ?? '',
          role:              role,
          fullName:          user.displayName ?? '',
          phone:             '',
          region:            '',
          district:          '',
          area:              '',
          detectedAddress:   '',
          savedLocationPreference: 'manual',
          profileImageUrl:   user.photoURL,
          bio:               '',
          category:          '',
          experience:        '',
          plan:              'free',
          portfolioImages:   [],
          accountStatus:     'active',
          isProfileComplete: false,
          createdAt:         DateTime.now(),
          updatedAt:         DateTime.now(),
        );
      }

      // Status stays profileIncomplete so router routes to completion
      _status = AuthStatus.profileIncomplete;
      notifyListeners();

      dev.log('[AuthProvider] assignGoogleRole: _userModel.role='
          '${_userModel?.role}, status=$_status — returning role',
          name: 'AUTH');
      return role;

    } catch (e) {
      dev.log('[AuthProvider] assignGoogleRole ERROR: $e', name: 'AUTH');
      _errorMessage =
          'Failed to save role. Check your connection and try again.';
      notifyListeners();
      return null;
    } finally {
      _suppressAuth = false;
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true); _clearError();
    _suppressAuth = true;
    try {
      final result = await _authService.signInWithGoogle();
      final uid   = result.credential.user!.uid;
      final email = result.credential.user!.email ?? '';
      if (result.isNewUser) {
        // Brand-new Google user — create placeholder doc
        await _authService.createUserDocument(
            uid: uid, email: email, role: '');
      }
      _suppressAuth = false;
      final userModel = await _authService.fetchUserModel(uid);
      if (userModel != null) {
        _userModel = userModel;
        _status = userModel.isSuspended
            ? AuthStatus.suspended
            : !userModel.isProfileComplete
                ? AuthStatus.profileIncomplete
                : AuthStatus.authenticated;
      } else {
        _status = AuthStatus.profileIncomplete;
      }
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _suppressAuth = false;
      if (e.code == 'google-sign-in-cancelled') {
        _setLoading(false); return false;
      }
      _errorMessage = AuthService.getErrorMessage(e);
      notifyListeners(); return false;
    } catch (e) {
      _suppressAuth = false;
      _errorMessage = 'Google sign-in failed. Please try again.';
      notifyListeners(); return false;
    } finally { _suppressAuth = false; _setLoading(false); }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true); _clearError();
    try {
      await _authService.loginWithEmail(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = AuthService.getErrorMessage(e);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = 'Login failed.'; notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  Future<void> logout() async {
    await _authService.signOut();
    // After logout, user becomes guest (can still browse)
    _status = AuthStatus.guest;
    _userModel = null;
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true); _clearError();
    try {
      await _authService.sendPasswordResetEmail(email); return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = AuthService.getErrorMessage(e);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email.';
      notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  Future<bool> completeClientProfile({
    required String fullName, required String phone, required String region,
    required String district, required String area, double? latitude,
    double? longitude, String detectedAddress = '',
    String savedLocationPreference = 'manual',
  }) async {
    final uid = _authService.currentUserId;
    if (uid == null) return false;
    _setLoading(true); _clearError();
    try {
      await _userService.completeClientProfile(
        uid: uid, fullName: fullName, phone: phone, region: region,
        district: district, area: area, latitude: latitude,
        longitude: longitude, detectedAddress: detectedAddress,
        savedLocationPreference: savedLocationPreference,
      );
      final updated = await _authService.fetchUserModel(uid);
      if (updated != null) {
        _userModel = updated; _status = AuthStatus.authenticated; notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save profile.'; notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  Future<bool> completeFundiProfile({
    required String fullName, required String phone, required String category,
    String? otherCategoryName, required List<String> skills,
    required String experience, required String bio, required String region,
    required String district, required String area, double? latitude,
    double? longitude, String detectedAddress = '',
  }) async {
    final uid = _authService.currentUserId;
    if (uid == null) return false;
    _isLoading = true; _clearError();  // silent — no notify before async
    try {
      await _userService.completeFundiProfile(
        uid: uid, fullName: fullName, phone: phone, category: category,
        otherCategoryName: otherCategoryName, skills: skills,
        experience: experience, bio: bio, region: region,
        district: district, area: area, latitude: latitude,
        longitude: longitude, detectedAddress: detectedAddress,
      );
      _clearError();
      // Set _isLoading false BEFORE the single notifyListeners so the
      // router redirect fires exactly once with both changes together.
      // A separate finally block would fire a second notifyListeners
      // (via _setLoading) after the router starts navigating, which can
      // trigger a FlutterError caught by the exception handler, causing
      // the false 'Failed to save' message.
      _isLoading = false;
      try {
        final updated = await _authService.fetchUserModel(uid);
        if (updated != null) {
          _userModel = updated;
          _status    = AuthStatus.authenticated;
        }
      } catch (_) {}
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _isLoading    = false;
      _errorMessage = 'Failed to save profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Soft-deletes the account in Firestore then signs the user out.
  /// Returns null on success or an error string on failure.
  Future<String?> deleteAccount() async {
    final uid = _authService.currentUserId;
    if (uid == null) return 'Not signed in';
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).update({
        'isDeleted':     true,
        'isActive':      false,
        'deletedAt':     FieldValue.serverTimestamp(),
        'accountStatus': 'deleted',
      });
      await _authService.signOut();
      _userModel = null;
      _status    = AuthStatus.unauthenticated;
      notifyListeners();
      return null;
    } catch (e) {
      dev.log('[AuthProvider] deleteAccount: $e', name: 'AUTH');
      return 'Failed to delete account. Please try again.';
    }
  }

  Future<void> refreshUser() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    final updated = await _authService.fetchUserModel(uid);
    if (updated != null) {
      _userModel = updated;
      _status = updated.isSuspended
          ? AuthStatus.suspended
          : !updated.isProfileComplete
              ? AuthStatus.profileIncomplete
              : AuthStatus.authenticated;
      notifyListeners();
    }
  }

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _clearError() => _errorMessage = null;
  void clearError() { _errorMessage = null; notifyListeners(); }
}
