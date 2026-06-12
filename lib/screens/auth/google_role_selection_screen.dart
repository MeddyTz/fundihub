import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../profile/fundi_profile_completion_screen.dart';
import '../profile/client_profile_completion_screen.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/fundi_hub_logo.dart';

/// Shown when a user signs in via Google but has no role yet.
/// Pattern copied exactly from register_screen.dart which is known to work:
///  - local _busy state (not auth.isLoading)
///  - ElevatedButton onPressed is NEVER null
///  - explicit context.go() after success
class GoogleRoleSelectionScreen extends StatefulWidget {
  const GoogleRoleSelectionScreen({super.key});

  @override
  State<GoogleRoleSelectionScreen> createState() =>
      _GoogleRoleSelectionScreenState();
}

class _GoogleRoleSelectionScreenState
    extends State<GoogleRoleSelectionScreen> {
  bool _busy    = false;
  bool _agreed  = false;
  String _selectedRole = AppConstants.roleClient;

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    debugPrint('[GoogleRole] msg: $text (error=$error)');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 14)),
        backgroundColor: error ? AppColors.error : AppColors.grey900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ));
  }

  Future<void> _confirm() async {
    debugPrint('[GoogleRole] _confirm() called, _busy=$_busy role=$_selectedRole');
    if (_busy) return;

    FocusManager.instance.primaryFocus?.unfocus();

    if (!_agreed) {
      _msg('Please agree to the Terms of Service and Privacy Policy.',
          error: true);
      return;
    }

    setState(() => _busy = true);

    try {
      final auth = context.read<AuthProvider>();
      debugPrint('[GoogleRole] calling assignGoogleRole($_selectedRole)');
      final assignedRole = await auth.assignGoogleRole(_selectedRole);
      debugPrint('[GoogleRole] assignGoogleRole returned: $assignedRole');

      if (!mounted) return;

      if (assignedRole == null) {
        final msg = auth.errorMessage ?? 'Failed to save role. Please try again.';
        debugPrint('[GoogleRole] FAILED: $msg');
        _msg(msg, error: true);
        auth.clearError();
        return;
      }

      debugPrint('[GoogleRole] success — navigating directly to completion screen');
      _msg('Role saved! Completing your profile...');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // Navigate directly to the correct completion screen.
      // We bypass the /profile-completion router builder which can
      // loop back to this screen if _onAuthStateChanged fires with
      // stale Firestore data before the route evaluates.
      final isFundi = assignedRole == 'fundi';
      debugPrint('[GoogleRole] pushing '
          '${isFundi ? 'FundiProfileCompletionScreen' : 'ClientProfileCompletionScreen'}');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isFundi
              ? const FundiProfileCompletionScreen()
              : const ClientProfileCompletionScreen(),
        ),
        (route) => false, // remove all previous routes
      );

    } catch (e, st) {
      debugPrint('[GoogleRole] EXCEPTION: $e\n$st');
      if (!mounted) return;
      _msg('Error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space3XL),
              const Center(child: FundiHubLogo(size: 64)),
              const SizedBox(height: AppTheme.spaceXL),
              Text(
                l10n.sw ? 'Karibu FundiHub' : 'Welcome to FundiHub',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                l10n.sw
                    ? 'Chagua aina ya akaunti yako kuendelea.'
                    : 'Choose your account type to continue.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space3XL),
              Text(
                l10n.sw ? 'Aina ya akaunti' : 'Account type',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: AppTheme.spaceMD),
              _RoleOption(
                selected: _selectedRole == AppConstants.roleClient,
                icon:     Icons.person_search_rounded,
                title:    l10n.sw ? 'Mteja' : 'Client',
                subtitle: l10n.sw
                    ? 'Tafuta na omba fundi kwa kazi yako.'
                    : 'Find and book trusted fundis.',
                onTap: _busy ? null
                    : () => setState(() => _selectedRole = AppConstants.roleClient),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              _RoleOption(
                selected: _selectedRole == AppConstants.roleFundi,
                icon:     Icons.handyman_rounded,
                title:    l10n.sw ? 'Fundi' : 'Fundi',
                subtitle: l10n.sw
                    ? 'Pokea kazi na kukuza biashara yako.'
                    : 'Receive jobs and grow your business.',
                onTap: _busy ? null
                    : () => setState(() => _selectedRole = AppConstants.roleFundi),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // ── Terms agreement ────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _agreed = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(TextSpan(
                        style: AppTextStyles.bodySmall,
                        children: const [
                          TextSpan(text: "I agree to FundiHub's "),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color:      AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color:      AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXXL),

              // ── Continue — onPressed NEVER null (register_screen pattern) ──
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation:   4,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: AppLoader(size: 24, color: Colors.white))
                      : Text(
                          l10n.sw ? 'Endelea' : 'Continue',
                          style: AppTextStyles.buttonLarge
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: Text(l10n.roleWarning,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary)),
                  ),
                ]),
              ),
              const SizedBox(height: AppTheme.space3XL),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role option — identical to register_screen._RoleOption ───────────────────

class _RoleOption extends StatelessWidget {
  final bool      selected;
  final IconData  icon;
  final String    title, subtitle;
  final VoidCallback? onTap;

  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.grey50,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(icon,
                  color: selected ? AppColors.white : AppColors.primary),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.grey400,
            ),
          ]),
        ),
      );
}
