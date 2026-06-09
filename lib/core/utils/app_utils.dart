import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class AppUtils {
  AppUtils._();

  static String formatCurrency(int amount) =>
      'Tsh ${NumberFormat('#,###', 'en_US').format(amount)}';

  static String formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, HH:mm').format(date);

  static String formatTime(DateTime date) => DateFormat('HH:mm').format(date);

  static String formatRelativeTime(DateTime date) =>
      timeago.format(date, locale: 'en');

  static String formatChatDate(DateTime date) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(date.year, date.month, date.day);
    if (d == today)     return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^\d+]'), '');

  static bool containsPhoneNumber(String text) {
    final n = text.replaceAll(RegExp(r'[^\d+]'), '');
    return _phoneRegex.hasMatch(n);
  }

  static String? extractPhoneNumber(String text) {
    final n = text.replaceAll(RegExp(r'[^\d+]'), '');
    return _phoneRegex.firstMatch(n)?.group(0);
  }

  static final _phoneRegex =
      RegExp(r'(\+?255\d{9}|0[67]\d{8}|0\d{9})');

  static String formatWhatsAppUrl(String phone) {
    String n = normalizePhone(phone);
    if (n.startsWith('0'))  n = '255${n.substring(1)}';
    else if (n.startsWith('+')) n = n.substring(1);
    return 'https://wa.me/$n';
  }

  static void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg:             message,
      toastLength:     Toast.LENGTH_LONG,
      gravity:         ToastGravity.BOTTOM,
      backgroundColor: isError ? AppColors.error : AppColors.grey900,
      textColor:       AppColors.white,
    );
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError             = false,
    Duration duration        = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.grey900,
      duration:        duration,
      action:          action,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(16),
    ));
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText  = 'Cancel',
    bool   isDanger    = false,
  }) {
    return showDialog<bool>(
      context:           context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title:   Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:     Text(cancelText)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isDanger ? AppColors.error : null),
            onPressed: () => Navigator.pop(ctx, true),
            child:     Text(confirmText),
          ),
        ],
      ),
    );
  }

  static void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSnackBar(context, 'Copied to clipboard');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKING STATUS DISPLAY — includes new statuses
  // ─────────────────────────────────────────────────────────────────────────
  static String getBookingStatusDisplay(String status) {
    switch (status) {
      case AppConstants.bookingPending:              return 'Pending';
      case AppConstants.bookingAccepted:             return 'Accepted';
      case AppConstants.bookingAgreementConfirmed:   return 'Agreement Confirmed';
      case AppConstants.bookingInProgress:           return 'In Progress';
      case AppConstants.bookingAwaitingConfirmation: return 'Awaiting Confirmation';
      case AppConstants.bookingCompletionDisputed:   return 'Completion Disputed';
      case AppConstants.bookingCompleted:            return 'Completed';
      case AppConstants.bookingRejected:             return 'Rejected';
      case AppConstants.bookingCancelled:            return 'Cancelled';
      case AppConstants.bookingExpired:              return 'Expired';
      default: return status;
    }
  }

  static Color getBookingStatusColor(String status) {
    switch (status) {
      case AppConstants.bookingPending:              return AppColors.statusPending;
      case AppConstants.bookingAccepted:             return AppColors.statusAccepted;
      case AppConstants.bookingAgreementConfirmed:   return AppColors.statusAccepted;
      case AppConstants.bookingInProgress:           return AppColors.statusActive;
      case AppConstants.bookingAwaitingConfirmation: return AppColors.secondary;
      case AppConstants.bookingCompletionDisputed:   return AppColors.warning;
      case AppConstants.bookingCompleted:            return AppColors.statusCompleted;
      case AppConstants.bookingRejected:             return AppColors.statusRejected;
      case AppConstants.bookingCancelled:            return AppColors.statusRejected;
      default:                                       return AppColors.grey500;
    }
  }

  static String getPaymentStatusDisplay(String status) {
    switch (status) {
      case 'pending':   return 'Pending';
      case 'submitted': return 'Awaiting Admin Confirmation';
      case 'confirmed': return 'Confirmed';
      case 'rejected':  return 'Rejected';
      default:          return status;
    }
  }

  static Color getPaymentStatusColor(String status) {
    switch (status) {
      case 'submitted': return AppColors.statusAccepted;
      case 'confirmed': return AppColors.statusCompleted;
      case 'rejected':  return AppColors.statusRejected;
      default:          return AppColors.statusPending;
    }
  }

  // Lock reason display — kept for DB compat but no longer shown in UI
  static String getLockReasonDisplay(String reason, {bool sw = false}) {
    switch (reason) {
      case 'active_job':
        return sw
            ? 'Una kazi inayoendelea.'
            : 'You have an active job.';
      case 'job_fee_unpaid':
        return sw
            ? 'Kuna ada iliyobaki kulipwa.'
            : 'There is an outstanding fee.';
      default:
        return sw ? 'Akaunti yako imefungwa kwa muda.'
                  : 'Your account is temporarily locked.';
    }
  }

  static bool isImageSizeValid(int bytes) => bytes <= 5 * 1024 * 1024;
}
