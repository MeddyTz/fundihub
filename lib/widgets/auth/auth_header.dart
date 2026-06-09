import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../common/fundi_hub_logo.dart';
class AuthHeader extends StatelessWidget {
  final String title, subtitle;
  const AuthHeader({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const FundiHubLogo(size: 72, showText: false),
      const SizedBox(height: AppTheme.spaceXL),
      Text(title, style: AppTextStyles.displaySmall),
      const SizedBox(height: AppTheme.spaceSM),
      Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]);
  }
}