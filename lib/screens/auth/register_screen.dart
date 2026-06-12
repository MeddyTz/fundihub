import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _agreed = false;
  bool _busy = false;
  String _selectedRole = AppConstants.roleClient;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Show feedback ─────────────────────────────────────────────────────────
  void _msg(String text, {bool error = false, int secs = 4}) {
    if (!mounted) return;
    debugPrint('[Register] msg: $text (error=$error)');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 14)),
        backgroundColor: error ? AppColors.error : AppColors.grey900,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: secs),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ));
  }

  // ── Main registration flow ────────────────────────────────────────────────
  Future<void> _submit() async {
    // ── STEP 1: guard ─────────────────────────────────────────────────────
    debugPrint('[Register] STEP 1 – _submit() called, _busy=$_busy');
    if (_busy) {
      debugPrint('[Register] already busy, returning');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    // ── STEP 2: validate email ────────────────────────────────────────────
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    debugPrint('[Register] STEP 2 – email=$email');

    final emailErr = Validators.validateEmail(email);
    if (emailErr != null) {
      debugPrint('[Register] email invalid: $emailErr');
      _msg(emailErr, error: true);
      return;
    }

    // ── STEP 3: validate password ─────────────────────────────────────────
    debugPrint('[Register] STEP 3 – validate password');
    final passErr = Validators.validatePassword(password);
    if (passErr != null) {
      debugPrint('[Register] password invalid: $passErr');
      _msg(passErr, error: true);
      return;
    }

    // ── STEP 4: validate confirm ──────────────────────────────────────────
    debugPrint('[Register] STEP 4 – validate confirm');
    final confirmErr = Validators.validateConfirmPassword(confirm, password);
    if (confirmErr != null) {
      debugPrint('[Register] confirm invalid: $confirmErr');
      _msg(confirmErr, error: true);
      return;
    }

    // ── STEP 5: terms ─────────────────────────────────────────────────────
    debugPrint('[Register] STEP 5 – terms agreed=$_agreed');
    if (!_agreed) {
      _msg('Please agree to the Terms of Service and Privacy Policy.',
          error: true);
      return;
    }

    // ── STEP 6: set busy ──────────────────────────────────────────────────
    debugPrint('[Register] STEP 6 – setting busy=true, role=$_selectedRole');
    setState(() => _busy = true);

    try {
      // ── STEP 7: call register ─────────────────────────────────────────
      debugPrint('[Register] STEP 7 – calling auth.register()');
      final auth = context.read<AuthProvider>();

      final ok = await auth.register(
        email: email,
        password: password,
        role: _selectedRole,
      );

      debugPrint('[Register] STEP 8 – register returned ok=$ok '
          'status=${auth.status} error=${auth.errorMessage}');

      if (!mounted) {
        debugPrint('[Register] widget unmounted after register()');
        return;
      }

      // ── STEP 9: handle failure ─────────────────────────────────────────
      if (!ok) {
        final errMsg = auth.errorMessage ??
            'Failed to create account. Please try again.';
        debugPrint('[Register] STEP 9 – registration failed: $errMsg');
        _msg(errMsg, error: true, secs: 6);
        auth.clearError();
        return;
      }

      // ── STEP 10: navigate ─────────────────────────────────────────────
      debugPrint('[Register] STEP 10 – success, navigating. '
          'status=${auth.status}');

      _msg('Account created! Completing your profile...');

      // Small delay so the snackbar is visible before navigation
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final s = auth.status;
      if (s == AuthStatus.profileIncomplete) {
        debugPrint('[Register] going to /profile-completion');
        context.go('/profile-completion');
      } else if (s == AuthStatus.authenticated) {
        final u = auth.userModel;
        if (u == null) {
          context.go('/login');
        } else if (u.isAdmin) {
          context.go('/admin/dashboard');
        } else if (u.isFundi) {
          context.go('/fundi/dashboard');
        } else {
          context.go('/client/dashboard');
        }
      } else {
        // status may still be updating — force a refresh and navigate anyway
        debugPrint('[Register] status=$s — refreshing user then navigating');
        await auth.refreshUser();
        if (!mounted) return;
        context.go('/profile-completion');
      }
    } catch (e, st) {
      debugPrint('[Register] EXCEPTION: $e\n$st');
      if (!mounted) return;
      _msg('Error: ${e.toString()}', error: true, secs: 6);
    } finally {
      if (mounted) {
        debugPrint('[Register] finally – setting busy=false');
        setState(() => _busy = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      // NOTE: Button is inside the body scroll view, NOT in bottomNavigationBar.
      // This avoids any potential tap-blocking issues with SafeArea + bottomNavBar.
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.space3XL),

              // Back + language
              Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.grey100),
                  ),
                  const Spacer(),
                  const _LangToggle(),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXL),

              AuthHeader(
                title: l10n.createAccount,
                subtitle: l10n.createAccountSubtitle,
              ),
              const SizedBox(height: AppTheme.space3XL),

              // Email
              AppTextField(
                controller: _emailCtrl,
                label: l10n.emailAddress,
                hint: l10n.emailHint,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // Password
              AppTextField(
                controller: _passCtrl,
                label: l10n.password,
                hint: l10n.passwordMin,
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // Confirm password
              AppTextField(
                controller: _confirmCtrl,
                label: l10n.confirmPassword,
                hint: l10n.confirmPasswordHint,
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // Password hints
              _PasswordHints(password: _passCtrl.text),
              const SizedBox(height: AppTheme.spaceXL),

              // Account type
              Text(
                l10n.sw ? 'Aina ya akaunti' : 'Account type',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _RoleOption(
                selected: _selectedRole == AppConstants.roleClient,
                icon: Icons.person_search_rounded,
                title: l10n.sw ? 'Mteja' : 'Client',
                subtitle: l10n.sw
                    ? 'Tafuta na omba fundi kwa kazi yako.'
                    : 'Find and book trusted fundis.',
                onTap: _busy
                    ? null
                    : () => setState(
                          () => _selectedRole = AppConstants.roleClient,
                        ),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _RoleOption(
                selected: _selectedRole == AppConstants.roleFundi,
                icon: Icons.handyman_rounded,
                title: l10n.sw ? 'Fundi' : 'Fundi',
                subtitle: l10n.sw
                    ? 'Pokea kazi na kukuza biashara yako.'
                    : 'Receive jobs and grow your business.',
                onTap: _busy
                    ? null
                    : () => setState(
                          () => _selectedRole = AppConstants.roleFundi,
                        ),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // Terms
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
                      padding:
                          const EdgeInsets.only(top: AppTheme.spaceSM + 2),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodySmall,
                          children: [
                            TextSpan(
                              text: l10n.sw
                                  ? 'Nakubali '
                                  : "I agree to FundiHub's ",
                            ),
                            TextSpan(
                              text: l10n.sw
                                  ? 'Masharti ya Huduma'
                                  : 'Terms of Service',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: l10n.sw ? ' na ' : ' and '),
                            TextSpan(
                              text: l10n.sw
                                  ? 'Sera ya Faragha'
                                  : 'Privacy Policy',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                                text: l10n.sw ? ' za FundiHub' : ''),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXXL),

              // ── THE BUTTON — plain ElevatedButton, no custom widget ──────
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  // onPressed is NEVER null — always callable.
                  // _busy state is shown via the child widget, not by
                  // disabling the button (disabled buttons can't receive taps).
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.65),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: AppLoader(size: 24, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.sw
                                  ? 'Fungua Akaunti'
                                  : 'Create Account',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSM),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceMD),

              // Sign in link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.alreadyHaveAccount,
                      style: AppTextStyles.bodySmall),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.signIn,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.space3XL),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoleOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD),
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
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordHints extends StatelessWidget {
  final String password;
  const _PasswordHints({required this.password});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.passwordRequirements,
              style: AppTextStyles.labelMedium),
          const SizedBox(height: AppTheme.spaceSM),
          _Req(met: password.length >= 8, label: l10n.reqMinLength),
          _Req(
              met: password.contains(RegExp(r'[A-Z]')),
              label: l10n.reqUppercase),
          _Req(
              met: password.contains(RegExp(r'[0-9]')),
              label: l10n.reqNumber),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final bool met;
  final String label;
  const _Req({required this.met, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: met ? AppColors.success : AppColors.grey400,
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                    color: met ? AppColors.success : AppColors.textHint)),
          ],
        ),
      );
}

class _LangToggle extends StatelessWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangProvider>();
    return GestureDetector(
      onTap: () => context.read<LangProvider>().toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppTheme.spaceSM),
            Text(
              lang.isSwahili ? 'English' : 'Kiswahili',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Google Sign-Up button on register screen ─────────────────────────────────

class _RegisterGoogleButton extends StatefulWidget {
  @override
  State<_RegisterGoogleButton> createState() => _RegisterGoogleButtonState();
}

class _RegisterGoogleButtonState extends State<_RegisterGoogleButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok   = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage!),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: _busy ? null : _signIn,
        style: OutlinedButton.styleFrom(
          padding:     const EdgeInsets.symmetric(vertical: 14),
          side:        const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          backgroundColor: AppColors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _busy
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : Image.asset('assets/images/google_logo.png',
                    width: 20, height: 20,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 24, color: Colors.red)),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      );
}

