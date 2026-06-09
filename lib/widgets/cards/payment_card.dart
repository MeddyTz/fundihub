import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/payment_model.dart';

class PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  const PaymentCard({super.key, required this.payment});

  Color get _tColor {
    switch (payment.paymentType) {
      case 'job_fee':
        return AppColors.primary;
      case 'subscription':
        return AppColors.premium;
      case 'promotion':
        return AppColors.promoted;
      default:
        return AppColors.grey500;
    }
  }

  IconData get _tIcon {
    switch (payment.paymentType) {
      case 'job_fee':
        return Icons.receipt_long_rounded;
      case 'subscription':
        return Icons.star_rounded;
      case 'promotion':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Future<void> _openCheckout(BuildContext context) async {
    final url = payment.checkoutUrl;
    if (url == null || url.trim().isEmpty) return;
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppUtils.showSnackBar(context, 'Could not open payment link', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = AppUtils.getPaymentStatusColor(payment.status);
    final refLabel = payment.isSelcom ? 'Selcom Order' : 'Ref Number';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _tColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(_tIcon, color: _tColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.typeLabel, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${payment.provider.toUpperCase()} • ${AppUtils.formatRelativeTime(payment.submittedAt)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  AppUtils.getPaymentStatusDisplay(payment.status),
                  style: AppTextStyles.caption.copyWith(color: sc, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount', style: AppTextStyles.caption),
                    Text(
                      AppUtils.formatCurrency(payment.amount),
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(refLabel, style: AppTextStyles.caption),
                    Text(
                      payment.referenceNumber.isEmpty ? '-' : payment.referenceNumber,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (payment.providerStatus?.isNotEmpty == true) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Text('Provider status: ${payment.providerStatus}', style: AppTextStyles.caption),
          ],
          if (payment.canOpenCheckout && !payment.isConfirmed) ...[
            const SizedBox(height: AppTheme.spaceMD),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openCheckout(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Continue Selcom Payment'),
              ),
            ),
          ],
          if (payment.isRejected && payment.rejectionReason?.isNotEmpty == true) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: Text(
                      payment.rejectionReason!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (payment.isConfirmed && payment.confirmedAt != null) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'Confirmed: ${AppUtils.formatDateTime(payment.confirmedAt!)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.success),
            ),
          ],
        ],
      ),
    );
  }
}
