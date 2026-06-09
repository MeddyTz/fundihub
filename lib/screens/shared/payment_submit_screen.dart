import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading_overlay.dart';
import '../../widgets/common/app_text_field.dart';

enum PaymentSubmitType { jobFee, subscription, promotion }

class PaymentSubmitScreen extends StatefulWidget {
  final PaymentSubmitType type;
  final int? amount;
  final int? durationDays;
  final String? relatedBookingId;

  const PaymentSubmitScreen({
    super.key,
    required this.type,
    this.amount,
    this.durationDays,
    this.relatedBookingId,
  });

  @override
  State<PaymentSubmitScreen> createState() => _PaymentSubmitScreenState();
}

class _PaymentSubmitScreenState extends State<PaymentSubmitScreen> {
  final _refCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int get _amount {
    if (widget.amount != null) return widget.amount!;
    switch (widget.type) {
      case PaymentSubmitType.jobFee: return AppConstants.jobCompletionFee;
      case PaymentSubmitType.subscription: return AppConstants.premiumSubscriptionFee;
      case PaymentSubmitType.promotion: return widget.amount ?? 15000;
    }
  }

  String get _title {
    switch (widget.type) {
      case PaymentSubmitType.jobFee: return 'Pay Job Completion Fee';
      case PaymentSubmitType.subscription: return 'Subscribe to Premium';
      case PaymentSubmitType.promotion: return 'Boost Your Profile';
    }
  }

  String get _typeConst {
    switch (widget.type) {
      case PaymentSubmitType.jobFee: return AppConstants.paymentJobFee;
      case PaymentSubmitType.subscription: return AppConstants.paymentSubscription;
      case PaymentSubmitType.promotion: return AppConstants.paymentPromotion;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case PaymentSubmitType.jobFee: return Icons.receipt_long_rounded;
      case PaymentSubmitType.subscription: return Icons.star_rounded;
      case PaymentSubmitType.promotion: return Icons.rocket_launch_rounded;
    }
  }

  Color get _color {
    switch (widget.type) {
      case PaymentSubmitType.jobFee: return AppColors.primary;
      case PaymentSubmitType.subscription: return AppColors.premium;
      case PaymentSubmitType.promotion: return AppColors.promoted;
    }
  }

  String get _nextStepText {
    switch (widget.type) {
      case PaymentSubmitType.jobFee:
        return 'After admin confirms, your account will be unlocked automatically.';
      case PaymentSubmitType.subscription:
        return 'After admin confirms, Premium will be activated for 30 days.';
      case PaymentSubmitType.promotion:
        return 'After admin confirms, your profile boost will go live.';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final prov = context.read<PaymentProvider>();
    final fundi = auth.userModel;
    if (fundi == null) {
      AppUtils.showSnackBar(context, 'Please login again.', isError: true);
      return;
    }

    bool ok = false;
    switch (widget.type) {
      case PaymentSubmitType.jobFee:
        ok = await prov.submitJobFee(
          fundi: fundi,
          referenceNumber: _refCtrl.text.trim(),
          relatedBookingId: widget.relatedBookingId,
        );
        break;
      case PaymentSubmitType.subscription:
        ok = await prov.submitSubscription(
          fundi: fundi,
          referenceNumber: _refCtrl.text.trim(),
        );
        break;
      case PaymentSubmitType.promotion:
        ok = await prov.submitPromotion(
          fundi: fundi,
          referenceNumber: _refCtrl.text.trim(),
          amount: _amount,
          durationDays: widget.durationDays ?? 7,
        );
        break;
    }

    if (!mounted) return;

    if (ok) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Payment Submitted ✅'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.warning, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Your reference has been submitted. Please wait for admin confirmation.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_nextStepText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 10),
              Text('Amount: ${AppUtils.formatCurrency(_amount)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.canPop()) context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      AppUtils.showSnackBar(
        context,
        prov.errorMessage ?? 'Failed to submit. Please try again.',
        isError: true,
      );
    }
  }

  @override
  void dispose() { _refCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PaymentProvider>();

    return AppLoadingOverlay(
      isLoading: prov.isSubmitting,
      message: 'Submitting...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_title),
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount card
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXXL),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(color: _color.withOpacity(0.2)),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: _color.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Icon(_icon, color: _color, size: 36),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    Text(AppUtils.formatCurrency(_amount),
                        style: AppTextStyles.displaySmall.copyWith(
                            color: _color, fontWeight: FontWeight.w700)),
                    if (widget.type == PaymentSubmitType.subscription)
                      Text('/month', style: AppTextStyles.bodySmall),
                    if (widget.type == PaymentSubmitType.promotion &&
                        widget.durationDays != null)
                      Text('for ${widget.durationDays} days',
                          style: AppTextStyles.bodySmall),
                  ]),
                ),
                const SizedBox(height: AppTheme.spaceXXL),

                // Payment instructions
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.phone_in_talk_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('How to Pay',
                            style: AppTextStyles.titleSmall
                                .copyWith(color: AppColors.primary)),
                      ]),
                      const SizedBox(height: AppTheme.spaceMD),
                      Text(
                          '1. Open your M-Pesa / Tigo / Airtel Money app.',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                          '2. Send ${AppUtils.formatCurrency(_amount)} to:',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(const ClipboardData(
                              text: AppConstants.companyPaymentNumber));
                          AppUtils.showSnackBar(context, 'Number copied!');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              '${AppConstants.companyPaymentNumberLabel}: ${AppConstants.companyPaymentNumber}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.primary),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          '3. Copy the reference number from your SMS.',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Text('4. Paste it below and tap Submit.',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXXL),

                // Reference input
                Text('Payment Reference Number',
                    style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.spaceSM),
                AppTextField(
                  controller: _refCtrl,
                  label: 'Enter transaction reference number',
                  keyboardType: TextInputType.text,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Reference number is required';
                    if (v.trim().length < 4)
                      return 'Reference number is too short';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  'Enter the reference/transaction ID from your mobile money confirmation SMS.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppTheme.spaceXXL),

                // What happens next
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What happens next?',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppTheme.spaceMD),
                      _Step(n: '1', text: 'Submit your reference number.'),
                      _Step(
                          n: '2',
                          text: 'Admin verifies your payment (usually within a few hours).'),
                      _Step(n: '3', text: _nextStepText),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space3XL),

                AppButton(
                  label: prov.paymentButtonLabelForType(_typeConst),
                  leadingIcon: Icons.send_rounded,
                  onPressed: _submit,
                  isLoading: prov.isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n, text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: Center(
                child: Text(n,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
          ],
        ),
      );
}
