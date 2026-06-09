import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<PaymentService>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: svc.allPendingPaymentsStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const AppLoaderCenter();
          final payments = snap.data!;
          if (payments.isEmpty) {
            return const AppEmptyState(
              icon: Icons.check_circle_outline,
              title: 'All Caught Up',
              subtitle: 'No pending Selcom or manual payment submissions.',
              iconColor: AppColors.success,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spaceXXL),
            itemCount: payments.length,
            itemBuilder: (_, i) => _PaymentItem(payment: payments[i]),
          );
        },
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final svc = context.read<PaymentService>();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.fundiName, style: AppTextStyles.titleSmall),
                    Text(
                      '${payment.typeLabel} • ${payment.provider.toUpperCase()}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Text(
                AppUtils.formatCurrency(payment.amount),
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text('Phone: ${payment.fundiPhone}', style: AppTextStyles.bodySmall),
          Text('Order/Ref: ${payment.referenceNumber}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          if (payment.providerStatus?.isNotEmpty == true)
            Text('Provider status: ${payment.providerStatus}', style: AppTextStyles.bodySmall),
          Text('Submitted: ${AppUtils.formatDateTime(payment.submittedAt)}', style: AppTextStyles.caption),
          if (payment.isSelcom)
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spaceSM),
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Text(
                'Selcom payments should normally be confirmed automatically by webhook. Manual confirm is kept as an admin fallback while testing.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Reject Payment?'),
                        content: const Text('This will reject the payment and notify the fundi.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await svc.rejectPayment(
                        paymentId: payment.paymentId,
                        fundiId: payment.fundiId,
                        adminUid: auth.userModel!.uid,
                        reason: 'Payment could not be verified',
                        paymentType: payment.paymentType,
                      );
                    }
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (payment.paymentType == AppConstants.paymentJobFee) {
                      await svc.confirmJobFeePayment(
                        paymentId: payment.paymentId,
                        fundiId: payment.fundiId,
                        adminUid: auth.userModel!.uid,
                      );
                    } else if (payment.paymentType == AppConstants.paymentSubscription) {
                      await svc.confirmSubscriptionPayment(
                        paymentId: payment.paymentId,
                        fundiId: payment.fundiId,
                        fundiName: payment.fundiName,
                        adminUid: auth.userModel!.uid,
                      );
                    } else if (payment.paymentType == AppConstants.paymentPromotion) {
                      await svc.confirmPromotionPayment(
                        paymentId: payment.paymentId,
                        fundiId: payment.fundiId,
                        adminUid: auth.userModel!.uid,
                        durationDays: 14,
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
