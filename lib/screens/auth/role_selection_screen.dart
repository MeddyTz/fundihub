import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/fundi_hub_logo.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String email, password;
  const RoleSelectionScreen({super.key, required this.email, required this.password});
  @override State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}
class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _role;

  Future<void> _register() async {
    final l10n = AppL10n.of(context);

    if (_role == null) {
      AppUtils.showSnackBar(
        context,
        l10n.sw ? 'Tafadhali chagua aina ya akaunti.' : 'Please select your account type.',
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: widget.email.trim(),
      password: widget.password,
      role: _role!,
    );

    if (!mounted) return;

    if (!ok) {
      AppUtils.showSnackBar(
        context,
        auth.errorMessage ??
            (l10n.sw ? 'Imeshindwa kufungua akaunti.' : 'Registration failed.'),
        isError: true,
      );
      auth.clearError();
      return;
    }

    AppUtils.showSnackBar(
      context,
      l10n.sw
          ? 'Akaunti imefunguliwa. Kamilisha taarifa zako.'
          : 'Account created. Complete your profile.',
    );

    // AuthProvider will also redirect, but this makes the transition immediate.
    context.go('/profile-completion');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXXL),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: AppTheme.space3XL),
          Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else { context.go('/register'); } }, icon: const Icon(Icons.arrow_back_rounded), style: IconButton.styleFrom(backgroundColor: AppColors.grey100))),
          const SizedBox(height: AppTheme.spaceXL),
          const Center(child: FundiHubLogo(size: 64)),
          const SizedBox(height: AppTheme.space3XL),
          Text(l10n.roleSelectionTitle, style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spaceSM),
          Text(l10n.roleSelectionSubtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.space3XL),
          _RoleCard(role: AppConstants.roleClient, selected: _role, icon: Icons.person_search_rounded, title: l10n.roleClient, subtitle: l10n.clientSubtitle, features: const ['Search for fundis near you','Book services easily','Secure chat with fundis','Leave reviews after jobs'], onTap: () => setState(() => _role = AppConstants.roleClient)),
          const SizedBox(height: AppTheme.spaceXL),
          _RoleCard(role: AppConstants.roleFundi, selected: _role, icon: Icons.handyman_rounded, title: l10n.roleFundi, subtitle: l10n.fundiSubtitle, features: const ['Receive job bookings','Manage your work schedule','Build your reputation','Grow your business'], onTap: () => setState(() => _role = AppConstants.roleFundi)),
          const SizedBox(height: AppTheme.space3XL),
          AppButton(label: l10n.createMyAccount, isLoading: auth.isLoading, onPressed: _register),
          const SizedBox(height: AppTheme.spaceXL),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            child: Row(children: [const Icon(Icons.info_outline, size: 18, color: AppColors.primary), const SizedBox(width: AppTheme.spaceSM), Expanded(child: Text(l10n.roleWarning, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)))]),
          ),
          const SizedBox(height: AppTheme.space3XL),
        ]),
      )),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role, title, subtitle;
  final String? selected;
  final IconData icon;
  final List<String> features;
  final VoidCallback onTap;
  const _RoleCard({required this.role, required this.selected, required this.icon, required this.title, required this.subtitle, required this.features, required this.onTap});
  bool get isSel => selected == role;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spaceXL),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: isSel ? AppColors.primary : AppColors.border, width: isSel ? 2 : 1),
          boxShadow: [BoxShadow(color: isSel ? AppColors.primary.withOpacity(0.1) : AppColors.black.withOpacity(0.04), blurRadius: isSel ? 12 : 4, offset: const Offset(0,2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width:56,height:56,decoration:BoxDecoration(color:isSel?AppColors.primary:AppColors.grey100,borderRadius:BorderRadius.circular(AppTheme.radiusMD)),child:Icon(icon,size:28,color:isSel?AppColors.white:AppColors.grey600)),
            const SizedBox(width: AppTheme.spaceLG),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.headlineSmall), const SizedBox(height: 2), Text(subtitle, style: AppTextStyles.bodySmall)])),
            if (isSel) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
          ]),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(),
          const SizedBox(height: AppTheme.spaceMD),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
            child: Row(children: [Icon(Icons.check_rounded, size: 16, color: isSel ? AppColors.primary : AppColors.success), const SizedBox(width: AppTheme.spaceSM), Text(f, style: AppTextStyles.bodySmall)]),
          )),
        ]),
      ),
    );
  }
}