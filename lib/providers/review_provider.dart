import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/review_model.dart';
import '../models/user_model.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _svc;
  ReviewProvider({required ReviewService reviewService}) : _svc = reviewService;

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  StreamSubscription<List<ReviewModel>>? _sub;

  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void subscribeReviews(String fundiId) {
    _sub?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _sub = _svc.fundiReviewsStream(fundiId).listen(
      (reviews) {
        _reviews = reviews;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> hasReviewed(String bookingId, String clientId) {
    return _svc.hasReviewed(bookingId, clientId);
  }

  Stream<bool> hasReviewedStream(String bookingId, String clientId) {
    return _svc.hasReviewedStream(bookingId, clientId);
  }

  Future<bool> submitReview({
    required String bookingId,
    required UserModel client,
    required String fundiId,
    required double rating,
    required String comment,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _svc.submitReview(
        bookingId: bookingId,
        clientId: client.uid,
        clientName: client.fullName,
        clientImageUrl: client.profileImageUrl,
        fundiId: fundiId,
        rating: rating,
        comment: comment,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitReport({
    required String reporterId,
    required String reporterName,
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    required String details,
    String? relatedBookingId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _svc.submitReport(
        reporterId: reporterId,
        reporterName: reporterName,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        reason: reason,
        details: details,
        relatedBookingId: relatedBookingId,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
