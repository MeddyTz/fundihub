import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/fundi_model.dart';
import '../models/user_model.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService;

  BookingProvider({required BookingService bookingService})
      : _bookingService = bookingService;

  List<BookingModel> _bookings    = [];
  BookingModel?      _selectedBooking;
  bool               _isLoading   = false;
  bool               _isSubmitting = false;
  String?            _errorMessage;
  int                _pendingCount = 0;

  StreamSubscription<List<BookingModel>>? _bookingsSub;
  StreamSubscription<BookingModel?>?      _selectedSub;
  StreamSubscription<int>?                _pendingCountSub;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get activeBookings =>
      _bookings.where((b) => b.isActive).toList();
  List<BookingModel> get pendingBookings =>
      _bookings.where((b) => b.isPending).toList();
  List<BookingModel> get completedBookings =>
      _bookings.where((b) => b.isFinished).toList();

  BookingModel? get selectedBooking => _selectedBooking;
  bool          get isLoading        => _isLoading;
  bool          get isSubmitting     => _isSubmitting;
  String?       get errorMessage     => _errorMessage;
  int           get pendingCount     => _pendingCount;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  void subscribeClientBookings(String clientId) {
    _bookingsSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _bookingsSub = _bookingService.clientBookingsStream(clientId).listen(
      (l) { _bookings = l; _isLoading = false; notifyListeners(); },
      onError: (_) { _isLoading = false; notifyListeners(); },
    );
  }

  void subscribeFundiBookings(String fundiId) {
    _bookingsSub?.cancel();
    _pendingCountSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _bookingsSub = _bookingService.fundiBookingsStream(fundiId).listen(
      (l) { _bookings = l; _isLoading = false; notifyListeners(); },
      onError: (_) { _isLoading = false; notifyListeners(); },
    );

    _pendingCountSub =
        _bookingService.fundiPendingCountStream(fundiId).listen((c) {
      _pendingCount = c;
      notifyListeners();
    });
  }

  void subscribeBooking(String bookingId) {
    _selectedSub?.cancel();
    _selectedSub = _bookingService.bookingStream(bookingId).listen((b) {
      _selectedBooking = b;
      notifyListeners();
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<String?> createBooking({
    required UserModel  client,
    required FundiModel fundi,
    required String serviceDescription,
    String? agreedPrice,
    required String locationRegion,
    required String locationDistrict,
    required String locationArea,
    String? locationDetails,
    double? locationLat,
    double? locationLng,
    String? locationDetectedAddress,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final id = await _bookingService.createBooking(
        client:                  client,
        fundi:                   fundi,
        serviceDescription:      serviceDescription,
        locationRegion:          locationRegion,
        locationDistrict:        locationDistrict,
        locationArea:            locationArea,
        locationDetails:         locationDetails,
        locationLat:             locationLat,
        locationLng:             locationLng,
        locationDetectedAddress: locationDetectedAddress,
        agreedPrice:             agreedPrice,
      );
      return id;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> acceptBooking(String id) =>
      _action(() => _bookingService.acceptBooking(id));

  Future<bool> rejectBooking(String id, {String reason = ''}) =>
      _action(() => _bookingService.rejectBooking(id, reason: reason));

  Future<bool> cancelBooking(
    String id, {
    required String cancelledBy,
    String reason = '',
  }) =>
      _action(() => _bookingService.cancelBooking(
            id,
            cancelledBy: cancelledBy,
            reason:      reason,
          ));

  /// Legacy agreement — kept for old bookings
  Future<bool> clientAgree(String id) =>
      _action(() => _bookingService.clientAgree(id));

  /// Legacy agreement — kept for old bookings
  Future<bool> fundiAgree(String id) =>
      _action(() => _bookingService.fundiAgree(id));

  Future<bool> markInProgress(String id) =>
      _action(() => _bookingService.markInProgress(id));

  /// NEW: Fundi marks job done → sets Awaiting Client Confirmation
  Future<bool> requestCompletion(String id) =>
      _action(() => _bookingService.requestCompletion(id));

  /// NEW: Client confirms job is done → sets Completed + increments jobsDone
  Future<bool> clientConfirmCompletion(String id) =>
      _action(() => _bookingService.clientConfirmCompletion(id));

  /// NEW: Client disputes completion → sets Completion Disputed
  Future<bool> disputeCompletion(String id, {String reason = ''}) =>
      _action(() => _bookingService.disputeCompletion(id, reason: reason));

  /// LEGACY: kept so old code that calls markCompleted still compiles.
  /// Forwards to requestCompletion (fundi side) in new flow.
  Future<bool> markCompleted(String id) =>
      _action(() => _bookingService.requestCompletion(id));

  // ── Helper ────────────────────────────────────────────────────────────────
  Future<bool> _action(Future<void> Function() fn) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await fn();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _selectedSub?.cancel();
    _pendingCountSub?.cancel();
    super.dispose();
  }
}
