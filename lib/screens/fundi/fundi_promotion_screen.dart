import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/lang_provider.dart';

/// FundiPromotionScreen — Growth Edition
///
/// Monetization removed. Screen now shows a "free growth phase" message.
/// All imports and routes that reference this file still compile cleanly.
class FundiPromotionScreen extends StatelessWidget {
  const FundiPromotionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           Text(l10n.sw ? 'Boresha Wasifu' : 'Grow Your Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space3XL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppTheme.space3XL),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(0.3),
                    blurRadius: 24,
                    offset:     const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 52),
            ),
            const SizedBox(height: AppTheme.space3XL),
            Text(
              l10n.sw
                  ? 'FundiHub ni Bure Kabisa!'
                  : 'FundiHub is 100% Free!',
              style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color:      AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              l10n.sw
                  ? 'Tunakua pamoja nawe. Hakuna ada, hakuna vikwazo. '
                    'Pokea kazi nyingi unavyotaka bila malipo.'
                  : 'We are growing together with you. No fees, no limits. '
                    'Accept as many jobs as you want — completely free.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color:  AppColors.textSecondary,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space3XL),
            _Feature(
              icon:  Icons.check_circle_rounded,
              color: AppColors.success,
              text:  l10n.sw
                  ? 'Kazi zisizo na ukomo — bila ada'
                  : 'Unlimited jobs — no per-job fee',
            ),
            _Feature(
              icon:  Icons.check_circle_rounded,
              color: AppColors.success,
              text:  l10n.sw
                  ? 'Onyesha kazi yako kupitia Reels'
                  : 'Showcase your work via Reels',
            ),
            _Feature(
              icon:  Icons.check_circle_rounded,
              color: AppColors.success,
              text:  l10n.sw
                  ? 'Mazungumzo na wateja moja kwa moja'
                  : 'Direct chat with clients',
            ),
            _Feature(
              icon:  Icons.check_circle_rounded,
              color: AppColors.success,
              text:  l10n.sw
                  ? 'Wasifu wako unaonekana na wateja wote'
                  : 'Your profile visible to all clients',
            ),
            const SizedBox(height: AppTheme.space3XL),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color:        AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border:       Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Text(
                    l10n.sw
                        ? 'Huduma za ziada zitaongezwa baadaye. '
                          'Kwa sasa, furahia FundiHub bure.'
                        : 'Premium features are coming soon. '
                          'For now, enjoy FundiHub completely free.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppTheme.space3XL),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _Feature({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ]),
      );
}
