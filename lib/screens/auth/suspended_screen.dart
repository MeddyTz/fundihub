import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width:100,height:100,decoration:const BoxDecoration(color:AppColors.errorSurface,shape:BoxShape.circle),child:const Icon(Icons.block_rounded,size:52,color:AppColors.error)),
          const SizedBox(height: AppTheme.space3XL),
          Text('Account Suspended', style: AppTextStyles.displaySmall.copyWith(color: AppColors.error), textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spaceXL),
          Text('Your account has been suspended by FundiHub administrators.\n\nIf you believe this is a mistake, please contact our support team.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.space3XL),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXL),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusXL), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 36),
              const SizedBox(height: AppTheme.spaceMD),
              Text('Contact Support', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppTheme.spaceSM),
              Text('support@fundihub.co.tz', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
            ]),
          ),
          const SizedBox(height: AppTheme.space3XL),
          AppButton(label: 'Sign Out', type: AppButtonType.outline, onPressed: () => context.read<AuthProvider>().logout()),
        ]),
      )),
    );
  }
}