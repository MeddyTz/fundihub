import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/payment_model.dart';
import '../models/subscription_model.dart';
import '../models/user_model.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _svc;
  PaymentProvider({required PaymentService paymentService}) : _svc = paymentService;

  List<PaymentModel> _payments = [];
  SubscriptionModel? _sub;
  bool _isLoading = false, _isSubmitting = false;
  String? _errorMessage;
  StreamSubscription<List<PaymentModel>>? _streamSub;

  List<PaymentModel> get payments => _payments;
  SubscriptionModel? get activeSubscription => _sub;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<PaymentModel> get pendingPayments =>
      _payments.where((p) => p.isSubmitted).toList();

  void subscribePayments(String fundiId) {
    _streamSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _streamSub = _svc.fundiPaymentsStream(fundiId).listen(
      (l) { _payments = l; _isLoading = false; notifyListeners(); },
      onError: (_) { _isLoading = false; notifyListeners(); },
    );
  }

  Future<void> loadSubscription(String fundiId) async {
    _sub = await _svc.getActiveSubscription(fundiId);
    notifyListeners();
  }

  Future<bool> submitJobFee({
    required UserModel fundi,
    required String referenceNumber,
    String? relatedBookingId,
  }) async {
    _isSubmitting = true; _errorMessage = null; notifyListeners();
    try {
      await _svc.submitJobFeePayment(
        fundi: fundi,
        referenceNumber: referenceNumber.trim(),
        relatedBookingId: relatedBookingId,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally { _isSubmitting = false; notifyListeners(); }
  }

  Future<bool> submitSubscription({
    required UserModel fundi,
    required String referenceNumber,
  }) async {
    _isSubmitting = true; _errorMessage = null; notifyListeners();
    try {
      await _svc.submitSubscriptionPayment(
          fundi: fundi, referenceNumber: referenceNumber.trim());
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally { _isSubmitting = false; notifyListeners(); }
  }

  Future<bool> submitPromotion({
    required UserModel fundi,
    required String referenceNumber,
    required int amount,
    required int durationDays,
  }) async {
    _isSubmitting = true; _errorMessage = null; notifyListeners();
    try {
      await _svc.submitPromotionPayment(
        fundi: fundi,
        referenceNumber: referenceNumber.trim(),
        amount: amount,
        durationDays: durationDays,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally { _isSubmitting = false; notifyListeners(); }
  }

  String paymentButtonLabelForType(String type) {
    switch (type) {
      case AppConstants.paymentJobFee: return 'Submit Payment Reference';
      case AppConstants.paymentSubscription: return 'Submit Payment Reference';
      case AppConstants.paymentPromotion: return 'Submit Payment Reference';
      default: return 'Submit Payment';
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }

  @override
  void dispose() { _streamSub?.cancel(); super.dispose(); }
}
