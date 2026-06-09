import 'package:flutter/material.dart';
class AppColors {
  AppColors._();
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primarySurface = Color(0xFFE3F2FD);
  static const Color secondary = Color(0xFFFF6F00);
  static const Color secondaryLight = Color(0xFFFF8F00);
  static const Color secondarySurface = Color(0xFFFFF8E1);
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF43A047);
  static const Color successSurface = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57F17);
  static const Color warningSurface = Color(0xFFFFFDE7);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFE53935);
  static const Color errorSurface = Color(0xFFFFEBEE);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = Color(0xFF1565C0);
  static const Color chatBubbleSent = Color(0xFF1565C0);
  static const Color chatBubbleReceived = Color(0xFFF1F3F4);
  static const Color chatBackground = Color(0xFFF0F4FF);
  static const Color statusPending = Color(0xFFF57F17);
  static const Color statusAccepted = Color(0xFF1565C0);
  static const Color statusActive = Color(0xFF2E7D32);
  static const Color statusCompleted = Color(0xFF1B5E20);
  static const Color statusRejected = Color(0xFFC62828);
  static const Color statusCancelled = Color(0xFF757575);
  static const Color premium = Color(0xFFFFB300);
  static const Color premiumSurface = Color(0xFFFFF8E1);
  static const Color promoted = Color(0xFF7B1FA2);
  static const Color promotedSurface = Color(0xFFF3E5F5);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}