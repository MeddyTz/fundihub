import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'app_loader.dart';

/// Premium loading overlay — blurred background + branded card.
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final String loaderType;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.loaderType = 'default',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              color: AppColors.black.withOpacity(0.52),
              child: Center(
                child: _PremiumLoadingCard(
                    message: message, loaderType: loaderType),
              ),
            ),
          ),
      ],
    );
  }
}

class _PremiumLoadingCard extends StatelessWidget {
  final String? message;
  final String loaderType;

  const _PremiumLoadingCard({this.message, required this.loaderType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: message != null ? 40 : 32,
        vertical: message != null ? 36 : 30,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.22),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 60,
            offset: const Offset(0, 0),
          ),
        ],
        border: Border.all(
          color: AppColors.border.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: _loaderWidget(loaderType, message),
    );
  }

  Widget _loaderWidget(String type, String? msg) {
    switch (type) {
      case 'booking':
        return BookingLoader(message: msg);
      case 'technical':
        return TechnicalLoader(
            message: msg ?? LoadingMessages.connectingService, size: 54);
      case 'chat':
        return PulseLoader(
          message: msg ?? LoadingMessages.settingUpChat,
          size: 54,
          color: AppColors.primary,
        );
      case 'radar':
        return RadarLoader(
          message: msg ?? LoadingMessages.findingFundis,
          size: 76,
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoader(size: 48),
            if (msg != null) ...[
              const SizedBox(height: 20),
              Text(
                msg,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
    }
  }
}

typedef LoadingOverlay = AppLoadingOverlay;
