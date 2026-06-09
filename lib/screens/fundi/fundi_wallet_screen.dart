import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/cards/payment_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';

/// FundiWalletScreen — Phase 2 (Growth Edition)
///
/// Monetization gates (premium lock, fee banners, upgrade CTAs) removed.
/// Screen now shows payment history only, plus boost CTA for growth.
class FundiWalletScreen extends StatefulWidget {
  const FundiWalletScreen({super.key});

  @override
  State<FundiWalletScreen> createState() => _State();
}

class _State extends State<FundiWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context.read<PaymentProvider>().subscribePayments(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PaymentProvider>();
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.sw ? 'Historia ya Malipo' : 'Payment History',
          style: AppTextStyles.titleMedium
              .copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(AppTheme.spaceXXL),
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded,
                      color: AppColors.white, size: 22),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sw
                            ? 'Tangaza Wasifu Wako'
                            : 'Boost Your Profile',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.sw
                            ? 'Onekana juu zaidi kwenye matokeo ya utafutaji'
                            : 'Appear higher in search results',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/fundi/promotion'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.white.withOpacity(0.18),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    l10n.sw ? 'Tangaza' : 'Boost',
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Payment history
          Expanded(
            child: pp.isLoading
                ? _shimmer()
                : pp.payments.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: l10n.noPaymentsYet,
                        subtitle:
                            l10n.sw
                                ? 'Historia yako ya malipo itaonekana hapa.'
                                : 'Your payment history will appear here.',
                        iconColor: AppColors.grey400,
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(AppTheme.spaceXXL),
                        itemCount: pp.payments.length,
                        itemBuilder: (_, i) =>
                            PaymentCard(payment: pp.payments[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer() => ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        itemCount: 4,
        itemBuilder: (_, __) => AppShimmer(
          child: Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
          ),
        ),
      );
}
