import 'dart:async';
import 'package:flutter/foundation.dart';
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
      } else if (userModel.isSuspended) {
        _status = AuthStatus.suspended; _userModel = userModel;
      } else if (!userModel.isProfileComplete) {
        _status = AuthStatus.profileIncomplete; _userModel = userModel;
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
    _setLoading(true); _clearError();
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
